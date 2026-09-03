-----------------------------------added time for checking----------------------------------------------------------------------
import json
import logging
import random
import string
import time
from collections import defaultdict
from copy import deepcopy
from datetime import datetime
from decimal import ROUND_HALF_UP, Decimal
from typing import List
from zoneinfo import ZoneInfo

from fastapi import BackgroundTasks, Request
from psycopg import AsyncCursor
from psycopg.rows import DictRow
from psycopg_pool import AsyncConnectionPool
from pydantic import ValidationError

from src.api.books.expense.models import ExpenseCreateRequest
from src.api.books.expense.repository import ExpenseRepository
from src.api.books.expense.service import ExpenseService
from src.api.books.transactions.repository import TransactionRepository
from src.api.customer.advance.code_generator import generate_customer_advance_code
from src.api.customer.advance.constants import (
    AdvanceType,
    get_advance_expire_mature_date,
    get_advance_prefix,
    get_advance_type,
    get_advance_weight_type,
)
from src.api.customer.advance.service import (
    update_customer_advance_status,
)
from src.api.file.service import upload_file
from src.api.invoice.draft.constants import (
    ProductChartOfAccounts,
    RepurchaseProductChartAccounts,
)
from src.api.invoice.draft.models import (
    Address,
    CollectionReminder,
    Customer,
    CustomerAdvance,
    Invoice,
    LineItem,
    Material,
    MaterialRate,
    PaymentMethod,
    PaymentMethodToCoaType,
    RefundMethod,
    Repurchase,
    RepurchaseLineItem,
    RepurchaseMaterial,
    RepurchaseRefundMethod,
    SalesReturn,
    SalesReturnDiscount,
    SalesReturnDraft,
    SalesReturnProduct,
)

# TokenAdvance,
from src.api.invoice.draft.request_models import (
    CreateAdvanceRequest,
    CustomerSaleRequest,
    InvoiceInsertPlanRequest,
    ProductSplitRequest,
    RefundMethodRequest,
    RepurchaseRequest,
    RequestLineItem,
    UpdateAdvanceRequest,
    UpdateLineItemRate,
    UpdateSalesVa,
)
from src.api.invoice.insurance.constants import (
    INVOICE_PDF_FOLDER,
    MIN_TAXABLE_VALUE,
)
from src.api.invoice.insurance.service import (
    build_invoice_proposal,
    invoice_gold_weight,
    is_affinity_configured,
    issue_or_fetch_coi,
    store_invoice_coi,
)
from src.api.invoice.service import generate_sales_bill_pdf
from src.api.offline_feedback.service import (
    OFFLINE_FEEDBACK_STATUS_SALES,
    mark_offline_feedback_status,
)
from src.api.product.model import (
    MaterialTransferData,
)
from src.api.repurchase.draft.models import RepurchaseDraft
from src.api.repurchase.draft.service import (
    fetch_product_template_attributes,
    get_product_creation_code,
    insert_product_attribute_value,
    raise_if_missing_fields,
)
from src.api.repurchase.model import Repurchase as RepurchaseCreation
from src.api.repurchase.model import RepurchaseLineItem as RepurchaseLineItemCreation
from src.api.repurchase.model import RepurchaseMaterial as RepurchaseMaterialCreation
from src.api.repurchase.service import _move_repurchase_line_items
from src.api.user.model import UserJWTPayload
from src.config import get_config
from src.shared.collection import (
    generate_collection_code,
    generate_customer_payment_code,
    get_customer_chart_id,
)
from src.shared.custom_exceptions import BadRequestException, ResourceNotFoundException
from src.shared.dependency import has_otp
from src.shared.query_gnerator import generate_insert_query
from src.shared.transaction import (
    get_advance_chart_of_account_id,
    get_customer_chart_of_account_id,
    insert_into_customer_payment,
    insert_into_invoice_collection,
    insert_into_transaction,
)
from src.shared.types import ADVANCELIST, SCHEMELIST
from src.utils.customer_transaction_amount import (
    CustomerCashBalance,
    check_daily_cash_refund_limit,
)
from src.utils.document_code import (
    REPURCHASE_CODE_CONFIG,
    SALES_INVOICE_B2B_CODE_CONFIG,
    SALES_INVOICE_B2C_CODE_CONFIG,
    SALES_RETURN_CODE_CONFIG,
    generate_document_code,
)
from src.utils.sms_gateway import send_sms_background

logger = logging.getLogger(__name__)

MC_CONFIG_KEY = "mc_config"


async def get_region_mc_adjustment(
    cur: AsyncCursor[DictRow],
    branch_id: int,
    product_type: str | None = None,
) -> float:
    """Signed percentage by which the branch's region adjusts a product's maximum MC.

    The region is the state code on the branch address. Within a region the
    adjustment is set per product type (the TYP attribute value). A type without
    an entry — or a product with no type — gets no adjustment (0).

    Returns 0 when the mc_config row is missing, the region has no entry, or the
    type is not configured, so the product's own maximum MC is used as is.
    """
    get_region_config = """
    SELECT
        uc.value -> 'regions' -> a.state_code AS region_config
    FROM
        branch b
    JOIN
        address a ON a.id = b.address_id
    LEFT JOIN
        ui_config uc ON uc.key = %(mc_config_key)s
    WHERE
        b.id = %(branch_id)s
    """
    await cur.execute(
        get_region_config,
        {"branch_id": branch_id, "mc_config_key": MC_CONFIG_KEY},
    )
    row = await cur.fetchone()
    region_config = row["region_config"] if row else None
    if not isinstance(region_config, dict) or product_type is None:
        return 0
    adjustment = region_config.get(product_type)
    if adjustment is None:
        return 0
    return float(adjustment)


def adjust_maximum_va_percentage(sales_va_percentage, adjustment_percentage: float):
    """Apply the region adjustment to a product's maximum MC.

    The adjustment is relative to the MC itself and not in percentage points: a
    product with 10% VA in a -5 region becomes 9.5%, so a 1000 metal value
    carries 95 MC instead of 100 and the product value is 1095 instead of 1100.
    """
    if sales_va_percentage is None or not adjustment_percentage:
        return sales_va_percentage
    return round(float(sales_va_percentage) * (1 + adjustment_percentage / 100), 2)


async def generate_sales_return_code(cur, location_id: int):
    return await generate_document_code(
        cur, SALES_RETURN_CODE_CONFIG, location_id=location_id
    )


def _clubbed_sales_return_cash_args(invoice) -> tuple[int | None, float | None]:
    """For a sales return clubbed (exchanged) into this invoice, return
    (original_invoice_id, clubbed_value) so the cash counted on the original
    invoice can be reversed against the customer's cash limit. Returns
    (None, None) when there is no clubbed return, or when it is refunded in
    cash (a separate outflow, not a value clubbed into this invoice)."""
    sales_return = getattr(invoice, "sales_return", None)
    if not sales_return:
        return None, None
    data = sales_return.draft_sales_return_data
    if data.refund_method == "CASH":
        return None, None
    return data.invoice_id, data.total_sales_return_value


async def get_employee_id(cur: AsyncCursor[DictRow], user_id: int):
    search_query = """
    SELECT
        id
    FROM
        employee        
    WHERE
        user_id = %(user_id)s
    """
    await cur.execute(search_query, {"user_id": user_id})
    data = await cur.fetchone()
    if not data:
        raise BadRequestException("Employee doesn't Exist")
    return data["id"]


async def create_draft_invoice_function(
    cur: AsyncCursor[DictRow], user: UserJWTPayload
):
    location_id = user.branch_id
    employee_id = await get_employee_id(cur, user.user_id)
    get_metal_rate_query = """
    SELECT
        material_code as code,
        rate
    FROM 
        material_rate mr
    JOIN material m ON
        m.id = mr.material_id
    WHERE
        mr.end_time = '2100-01-01 00:00:00+00'
        and location_id = %(location_id)s
    """

    await cur.execute(get_metal_rate_query, {"location_id": location_id})
    material_rates = await cur.fetchall()

    get_state_code_query = """
    SELECT 
        ad.state_code
    FROM 
        branch
    LEFT JOIN 
        address ad on ad.id = branch.address_id
    WHERE
        branch.id = %(location_id)s
    """
    await cur.execute(get_state_code_query, {"location_id": location_id})
    address = await cur.fetchone()
    state_code = address["state_code"]

    invoice = Invoice(
        created_by_employee_id=employee_id,
        current_material_rates=[
            MaterialRate(**material_rate) for material_rate in material_rates
        ],
        location={"state": state_code, "location_id": location_id},
    )

    model_json = invoice.model_dump_json()

    insert_json_query = """
    INSERT INTO draft_form
    (
        json_data,
        form_type
    )
    VALUES
    (
        %(json_data)s,
        'INVOICE'
    )
    RETURNING id
    """

    await cur.execute(
        insert_json_query,
        {"json_data": model_json},
    )

    data = await cur.fetchone()

    return {"id": data["id"], "invoice_data": invoice.model_dump()}


async def create_draft_invoice(async_pool: AsyncConnectionPool, user: UserJWTPayload):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            return await create_draft_invoice_function(cur, user)


async def add_line_item_to_draft(
    async_pool: AsyncConnectionPool,
    draft_id: int,
    request: UserJWTPayload,
    line_item: RequestLineItem | None = None,
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            scanned_product_id = None
            reservation_warning = None
            draft_invoice = await get_draft_invoice(draft_id=draft_id, cur=cur)
            if not draft_invoice:
                raise ResourceNotFoundException("Draft does not exist")
            invoice_obj = Invoice.model_validate(draft_invoice["json_data"])
            invoice_obj.add_line_item()
            index = len(invoice_obj.line_items) - 1
            if line_item:
                if line_item.product_code:
                    get_product_data = """
                    SELECT
                        p.id,
                        p.product_name,
                        p.product_code,
                        p.minimum_va_percentage,
                        p.sales_va_percentage,
                        p.piece_count,
                        p.is_box,
                        p.mrp_amount,
                        p.touch_percentage,
                        p.is_barcoded,
                        MAX(typ.value) AS product_type_code,
                        (SELECT SUM(pmw.weight)
                        FROM product_material pm 
                        LEFT JOIN
                        product_material_weight pmw on pmw.product_material_id = pm.id
                        WHERE pm.product_id = p.id) AS total_weight,
                        json_agg(
                            json_build_object(
                                'code', sub.material_code,
                                'type', sub.type,
                                'weight', sub.total_weight,
                                'quantity', sub.total_quantity,
                                'rate', sub.rate,
                                'sale_rate', sub.sale_rate,
                                'material_rate', sub.material_rate,
                                'product_material_id', sub.product_material_id,
                                'sale_rate_offset', sub.sale_rate_offset
                            )
                        ) AS material_details,
                        (
                        SELECT JSON_BUILD_OBJECT(
                            'code', rb.reservation_code,
                            'customer_name', cust.full_name,
                            'due_date', rb.due_date
                        )
                        FROM reservation_box_product rbp
                        JOIN reservation_box rb ON rb.id = rbp.reservation_id
                        JOIN customer cust ON cust.id = rb.customer_id
                        WHERE rbp.product_id = p.id
                        LIMIT 1
                    ) AS reservation_info
                    FROM 
                        product p
                    LEFT JOIN (
                        SELECT 
                            pm.product_id,
                            m.material_code,
                            m.type,
                            SUM(pmw.weight) AS total_weight,
                            SUM(pmw.quantity) AS total_quantity,
                            AVG(mr.rate) AS rate,
                            AVG(pm.sale_rate) AS sale_rate,
                            AVG(
                                CASE 
                                    WHEN pm.sale_rate IS NOT NULL THEN pm.sale_rate
                                    ELSE mr.rate
                                END + COALESCE(pm.sale_rate_offset, 0)
                            ) AS material_rate,
                            pm.id AS product_material_id,
                            pm.sale_rate_offset
                        FROM
                            product_material pm
                        JOIN
                            material m ON m.id = pm.material_id
                        LEFT JOIN
                            product_material_weight pmw on pmw.product_material_id = pm.id
                        LEFT JOIN
                            material_rate mr ON mr.material_id = m.id AND mr.end_time = '2100-01-01 00:00:00+00' AND mr.location_id = %(branch_id)s
                        GROUP BY
                            pm.product_id, m.material_code, m.type, pm.id
                    ) sub ON sub.product_id = p.id
                    LEFT JOIN (
					    SELECT
					        pav.product_id,
					        pev.value
					    FROM
					        product_attribute_value pav
					    LEFT JOIN product_attribute_enum_value pev
					        ON pev.id = pav.product_attribute_enum_value_id
					    WHERE
					        pav.attribute_id = (
					            SELECT id FROM product_attribute
					            WHERE attribute_code = 'TYP'
					        )
					) typ ON typ.product_id = p.id
                    WHERE
                        p.product_code = %(product_code)s
                    AND EXISTS (
                        SELECT 1 FROM product_location pl 
                        WHERE pl.product_id = p.id AND pl.location_id = %(branch_id)s AND pl.end_time = '2100-01-01 00:00:00+00'
                    )
                    GROUP BY
                        p.id, p.product_name, p.sales_va_percentage, p.piece_count;
                    """

                    await cur.execute(
                        get_product_data,
                        {
                            "product_code": line_item.product_code,
                            "branch_id": request.branch_id,
                        },
                    )
                    product_data = await cur.fetchone()

                    if not product_data:
                        raise BadRequestException(
                            "Product code does not belong to this branch or sold"
                        )

                    # Handle Reservation Warning
                    reservation = product_data.get("reservation_info")
                    if reservation:
                        reservation_warning = (
                            f"Warning: Product {product_data['product_code']} is already reserved in Box {reservation['code']} "
                            f"(Valid until {reservation['due_date']})."
                        )

                    is_box = product_data["is_box"]
                    if is_box:
                        raise BadRequestException("Please select a non box product")
                    if not is_box:
                        mc_adjustment = await get_region_mc_adjustment(
                            cur,
                            request.branch_id,
                            product_data["product_type_code"],
                        )
                        maximum_va_percentage = adjust_maximum_va_percentage(
                            product_data["sales_va_percentage"], mc_adjustment
                        )
                        material_list = []
                        piece_count = product_data["piece_count"]
                        # -- Commenting to solve issue with mrp products with weight
                        # if product_data["mrp_amount"] is None:
                        material_details_list = product_data["material_details"]

                        if material_details_list[0]["code"]:
                            for material in material_details_list:
                                material_code = material["code"]

                                # OTS has no usable branch fallback: with sale_rate
                                # unset the line item would silently bill the generic
                                # branch OTS rate instead of the rate the stone was
                                # barcoded at. Block the scan instead.
                                if (
                                    material_code == "OTS"
                                    and material["sale_rate"] is None
                                ):
                                    raise BadRequestException(
                                        "Sale rate for OTS is missing, please connect "
                                        "with the purchase department"
                                    )

                                # Only an unset sale_rate falls back to the branch
                                # rate. A stored 0 is a deliberate price and is
                                # billed as 0.
                                if material["sale_rate"] is None:
                                    material_rate = next(
                                        (
                                            i.rate
                                            for i in invoice_obj.current_material_rates
                                            if i.code == material_code
                                        ),
                                        material["rate"],
                                    )
                                else:
                                    material_rate = material["sale_rate"]

                                material_obj = Material(
                                    product_material_id=material["product_material_id"],
                                    type=material["type"],
                                    rate=material_rate,
                                    code=material_code,
                                    weight=material["weight"],
                                    quantity=material["quantity"],
                                )

                                material_list.append(material_obj)

                        line_item_data = {
                            "is_box": is_box,
                            "is_barcoded": product_data["is_barcoded"],
                            "materials": material_list,
                            "product_type_code": product_data["product_type_code"],
                            "product_id": product_data["id"],
                            "product_name": product_data["product_name"],
                            "mrp_amount": product_data["mrp_amount"]
                            if product_data["mrp_amount"]
                            else None,
                            "piece_count": piece_count,
                            "product_code": line_item.product_code,
                            "minimum_va_percentage": product_data[
                                "minimum_va_percentage"
                            ],
                            "sales_va_percentage": maximum_va_percentage,
                            "maximum_va_percentage": maximum_va_percentage,
                            "touch_percentage": product_data["touch_percentage"],
                            "gross_weight": product_data["total_weight"]
                            if material_details_list[0]["code"]
                            else 0,
                        }
                        line_item_obj = LineItem(**line_item_data)

                        if line_item_obj.mrp_amount is not None:
                            sales_va_amount = 0
                        elif line_item_obj.sales_va_percentage is None:
                            sales_va_amount = 0
                        else:
                            sales_va_amount = round(
                                sum(
                                    (
                                        (material.rate * material.weight)
                                        * (line_item_obj.sales_va_percentage / 100)
                                        for material in line_item_obj.materials
                                        if material.type == "METAL"
                                    ),
                                    0,
                                ),
                                2,
                            )
                        line_item_obj.sales_va_amount = sales_va_amount
                        invoice_obj.update_line_item(index, line_item_obj)
                        scanned_product_id = product_data["id"]

            invoice_obj = Invoice.model_validate(invoice_obj)

            data = await invoice_draft_check(cur, draft_invoice_id=draft_id)

            if data:
                raise BadRequestException(
                    "Can't edit the data. Invoice already created."
                )

            if scanned_product_id is not None and invoice_obj.customer:
                scanned_by_employee_id = await get_employee_id(cur, request.user_id)
                await insert_product_scan_log(
                    cur=cur,
                    product_id=scanned_product_id,
                    branch_id=request.branch_id,
                    scanned_by_employee_id=scanned_by_employee_id,
                    customer_id=invoice_obj.customer.customer_id,
                )

            update_invoice_data_query = """
            UPDATE 
                draft_form
            SET
                json_data = %(json_data)s
            WHERE
                id = %(draft_id)s AND form_type='INVOICE'
            RETURNING json_data
            """

            await cur.execute(
                update_invoice_data_query,
                {"json_data": invoice_obj.model_dump_json(), "draft_id": draft_id},
            )
            updated_data = await cur.fetchone()
            return {
                "json_data": updated_data["json_data"],
                "warning": reservation_warning,
                "message": "Line item added successfully",
            }


async def get_allowed_materials(cur: AsyncCursor[DictRow], product_id: int):
    get_product_materials_query = """
    SELECT m.material_code
    FROM product
    JOIN product_material pm ON pm.product_id = product.id
    JOIN material m ON m.id = pm.material_id
    WHERE product.id = %(product_id)s
    """
    await cur.execute(get_product_materials_query, {"product_id": product_id})
    materials = await cur.fetchall()
    return [material["material_code"] for material in materials]


async def update_line_item(
    async_pool: AsyncConnectionPool,
    draft_id: int,
    line_item_index: int,
    line_item_request: RequestLineItem,
    request: UserJWTPayload,
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            branch_id = request.branch_id
            draft_invoice = await get_draft_invoice(draft_id=draft_id, cur=cur)
            if not draft_invoice:
                raise BadRequestException("Draft invoice id not found")
            draft_invoice = draft_invoice["json_data"]
            invoice_obj = Invoice.model_validate(draft_invoice)
            if line_item_request.product_code:
                product_code = line_item_request.product_code
                if not draft_invoice:
                    raise BadRequestException("Draft invoice id not found")
                product_data = await get_product_details(cur, product_code, branch_id)
                if not product_data:
                    raise BadRequestException(
                        "Product code does not belong to this branch or sold"
                    )

                is_box = product_data["is_box"]
                if not is_box and line_item_request.material_details:
                    raise BadRequestException("Not Box Product")

                if not is_box:
                    material_details_list = product_data["material_details"]
                    piece_count = product_data["piece_count"]
                    material_list = []
                    for material in material_details_list:
                        material_code = material["code"]

                        if not material["sale_rate"]:
                            material_rate = next(
                                (
                                    i.rate
                                    for i in invoice_obj.current_material_rates
                                    if i.code == material_code
                                ),
                                material["rate"],
                            )
                        else:
                            material_rate = material["sale_rate"]

                        material_obj = Material(
                            product_material_id=material["product_material_id"],
                            type=material["type"],
                            rate=material_rate,
                            code=material_code,
                            weight=material["weight"],
                            quantity=material["quantity"],
                        )

                        material_list.append(material_obj)

                    line_item_data = {
                        "is_box": is_box,
                        "is_barcoded": product_data["is_barcoded"],
                        "minimum_va_percentage": product_data["minimum_va_percentage"],
                        "sales_va_percentage": product_data["sales_va_percentage"],
                        "maximum_va_percentage": product_data["sales_va_percentage"],
                        "product_type_code": product_data["product_type_code"],
                        "materials": material_list,
                        "product_id": product_data["id"],
                        "product_name": product_data["product_name"],
                        "mrp_amount": product_data["mrp_amount"]
                        if product_data["mrp_amount"]
                        else None,
                        "piece_count": piece_count,
                        "product_code": product_code,
                        "touch_percentage": product_data["touch_percentage"],
                    }
                    invoice_obj.update_line_item(
                        line_item_index, LineItem(**line_item_data)
                    )
                else:
                    invoice_obj.add_product_code(
                        line_item_index,
                        product_data["id"],
                        product_code,
                        product_data["touch_percentage"],
                        product_data["sales_va_percentage"],
                        product_data["product_type_code"],
                        is_box,
                    )
                    invoice_obj.add_product_name(
                        line_item_index, product_data["product_name"]
                    )
                    for i in product_data["material_details"]:
                        if i["type"] == "METAL":
                            code = i["code"]
                            rate = next(
                                (
                                    mr.rate
                                    for mr in invoice_obj.current_material_rates
                                    if mr.code == code
                                ),
                                i["rate"],
                            )
                            type = i["type"]
                    invoice_obj.add_material_data(line_item_index, code, type, rate)
                    invoice_obj.add_allowed_materials(
                        line_item_index,
                        await get_allowed_materials(cur, product_data["id"]),
                    )

            if line_item_request.gross_weight:
                invoice_obj.add_gross_weight(
                    line_item_index, line_item_request.gross_weight
                )

            if line_item_request.quantity:
                invoice_obj.add_quantity(line_item_index, line_item_request.quantity)

            if line_item_request.piece_count:
                invoice_obj.add_piece_count(
                    line_item_index, line_item_request.piece_count
                )

            if line_item_request.sales_va_percentage:
                invoice_obj.add_sales_va_percentage(
                    line_item_index, line_item_request.sales_va_percentage
                )

            if line_item_request.sales_va_amount:
                invoice_obj.add_sales_va_amount(
                    line_item_index, line_item_request.sales_va_amount
                )

            if line_item_request.discount_amount != None:
                invoice_obj.add_discount_amount(
                    line_item_index, line_item_request.discount_amount
                )

            if line_item_request.material_details:
                product_data = await get_product_details(
                    cur, invoice_obj.line_items[line_item_index].product_code, branch_id
                )

                if (
                    sum(m.weight for m in line_item_request.material_details)
                    > product_data["total_product_material"]
                ):
                    raise BadRequestException(
                        "Total material weights cannot the exceed the material weights included in the box item"
                    )
                existing_codes = [m["code"] for m in product_data["material_details"]]
                incoming_codes = [m.code for m in line_item_request.material_details]
                new_codes = list(set(incoming_codes) - set(existing_codes))
                if new_codes:
                    raise BadRequestException(
                        f"The product contains only materials: {', '.join(existing_codes)}"
                    )
                invoice_obj.add_materials(
                    line_item_index, line_item_request.material_details
                )

            Invoice.model_validate(invoice_obj)
            invoice_json_str = invoice_obj.model_dump_json()

            data = await invoice_draft_check(cur, draft_invoice_id=draft_id)

            if data:
                raise BadRequestException(
                    "Can't edit the data. Invoice already created."
                )

            update_invoice_data_query = """
            UPDATE 
                draft_form
            SET
                json_data = %(json_data)s
            WHERE
                id = %(draft_id)s AND form_type='INVOICE'
            RETURNING json_data
            """

            await cur.execute(
                update_invoice_data_query,
                {"json_data": invoice_json_str, "draft_id": draft_id},
            )
            updated_data = await cur.fetchone()
            return updated_data["json_data"]


async def get_draft_invoice(draft_id: int, cur: AsyncCursor[DictRow]):
    query = """
    SELECT json_data FROM draft_form
    WHERE id = %(draft_id)s AND form_type='INVOICE'
    LIMIT 1
    """
    await cur.execute(query, {"draft_id": draft_id})
    return await cur.fetchone()


async def club_advance(
    async_pool: AsyncConnectionPool,
    draft_id: int,
    advance_request: CreateAdvanceRequest,
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            get_customer_id = """
            SELECT
                json_data
            FROM
                draft_form
            WHERE
                id= %(draft_id)s AND form_type='INVOICE'
            """
            await cur.execute(get_customer_id, {"draft_id": draft_id})
            result = await cur.fetchone()

            customer_id = result["json_data"]["customer"]["customer_id"]
            invoice_data = result["json_data"]
            invoice_obj = Invoice.model_validate(invoice_data)

            if not customer_id:
                raise BadRequestException(
                    "Customer ID not found for the given draft ID"
                )

            advance_ids = [i.advance_id for i in advance_request.advance]
            check_customer_advance_query = """
            SELECT json_agg(id) as advance_ids
            FROM customer_advance
            WHERE customer_id = %(customer_id)s AND id = ANY(%(advance_ids)s::integer[])
            """
            await cur.execute(
                check_customer_advance_query,
                {"customer_id": customer_id, "advance_ids": advance_ids},
            )
            advance_data = await cur.fetchone()
            advance_ids = advance_data["advance_ids"]
            if not advance_ids:
                raise BadRequestException("Customer does not have an advance plan")

            # Check if all the incoming ids are active
            if not await check_advance_active(async_pool, advance_ids):
                raise BadRequestException("Some advance ids are not active")

            # Check if all the incoming ids are past due date
            # if not await check_advance_past_due(advance_ids):
            #     raise BadRequestException("Some advance ids are past due date")

            if not await if_line_item_exists(async_pool, draft_id):
                raise BadRequestException("Invoice line item does not exist")

            # Check if advance already added
            if await if_advance_already_added(invoice_obj, advance_ids):
                raise BadRequestException(
                    "Advance already added to the current invoice"
                )

            advance_data = await generate_advance_data(async_pool, advance_request)

            fetch_query = "SELECT json_data FROM draft_form WHERE id = %(invoice_id)s AND form_type='INVOICE';"
            await cur.execute(fetch_query, {"invoice_id": draft_id})
            current_data_row = await cur.fetchone()
            current_data = current_data_row["json_data"] if current_data_row else None

            if current_data:
                if isinstance(current_data, str):
                    data = json.loads(current_data)
                else:
                    data = current_data
                advance_data = json.loads(advance_data)
                existing_advance = {
                    advance["id"]: advance for advance in data.get("advance", [])
                }
                new_advances = {
                    advance["advance_id"]: advance for advance in advance_data
                }

                updated_advances = {**existing_advance, **new_advances}

                updated_advances = list(updated_advances.values())

                if "advance" in data:
                    advance = updated_advances
                else:
                    advance = advance_data

                invoice_obj = Invoice.model_validate(invoice_data)
                for i in advance:
                    customer_advance = CustomerAdvance(**i, is_advance=True)
                    partially_clubbed_once = any(
                        installment["invoice_id"] is not None
                        for installment in i["installments"]
                    )
                    invoice_obj.add_customer_advance(
                        customer_advance, partially_clubbed_once
                    )

                invoice_json_str = invoice_obj.model_dump_json()

                data = await invoice_draft_check(cur, draft_invoice_id=draft_id)

                if data:
                    raise BadRequestException(
                        "Can't edit the data. Invoice already created."
                    )

                update_invoice_data_query = """
                UPDATE 
                    draft_form
                SET
                    json_data = %(json_data)s
                WHERE
                    id = %(draft_id)s AND form_type='INVOICE'
                RETURNING json_data
                """

                await cur.execute(
                    update_invoice_data_query,
                    {"json_data": invoice_json_str, "draft_id": draft_id},
                )
                updated_data = await cur.fetchone()

                return updated_data


async def check_advance_active(async_pool: AsyncConnectionPool, customer_advance_ids):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            placeholders = ", ".join(["%s"] * len(customer_advance_ids))
            fetch_status_query = f"""
                SELECT customer_advance_id
                FROM customer_advance_status
                WHERE customer_advance_id IN ({placeholders})
                AND end_time = '2100-01-01 00:00:00+00'
                AND status = 'ACTIVE'
            """
            await cur.execute(fetch_status_query, customer_advance_ids)
            result = await cur.fetchall()
            if len(result) != len(customer_advance_ids):
                return False
            return True


async def check_advance_past_due(async_pool: AsyncConnectionPool, customer_advance_ids):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            placeholders = ", ".join(["%s"] * len(customer_advance_ids))
            fetch_status_query = f"""
            SELECT id
            FROM customer_advance
            WHERE id IN ({placeholders})
            AND expires_at >= CURRENT_DATE
            """
            await cur.execute(fetch_status_query, customer_advance_ids)
            result = await cur.fetchall()
            if len(result) != len(customer_advance_ids):
                return False
            return True


async def generate_advance_data(
    async_pool: AsyncConnectionPool, advance_request: CreateAdvanceRequest
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            advance_codes = []
            for advance in advance_request.advance:
                fetch_advance_advance_query = """
                SELECT 
                ca.id, 
                ca.customer_advance_code,  
                ca.reference_user_id,
                cat.term_amount,
                cat.weight,
                cat.advance_type,
                ca.advance_type AS weight_type,
                ca.joined_at,
                cas.status,
                (
                SELECT json_agg(
                    json_build_object(
                        'rate', mr.rate, 
                        'material_name', m.material_name,
                        'code', m.material_code
                    )
                )
                FROM material_rate mr
                JOIN material m ON m.id = mr.material_id
                WHERE 
                    ca.joined_at > mr.start_time 
                    AND ca.joined_at < mr.end_time
                    AND mr.location_id = ca.location_id
                ) AS material_rates,
                json_build_object(
                    'location_id', b.id,
                    'state', ad.state_code
                ) AS location,
                (
                    SELECT json_agg(
                        json_build_object(
                            'weight', cai.weight,
                            'amount', cai.amount,
                            'rate', cai.g22_rate,
                            'expires_at', cai.expires_at,
                            'maturity_date', cai.mature_at,
                            'weight_type', cai.weight_type,
                            'invoice_id', icai.invoice_id
                        ) ORDER BY cai.id
                    )
                    FROM customer_advance_installment cai
                    LEFT JOIN invoice_customer_advance_installment icai ON icai.customer_advance_installment_id = cai.id
                    WHERE cai.customer_advance_id = ca.id
                ) AS installments
                FROM customer_advance ca
                JOIN (
                SELECT
                    agg.customer_advance_id,
                    agg.term_amount,
                    li.g22_rate AS g22_rate,
                    agg.weight,
                    li.weight_type AS advance_type,
                    li.expires_at AS expires_at,
                    li.mature_at AS matures_at
                FROM (
                    SELECT
                        customer_advance_id,
                        SUM(amount) AS term_amount,
                        MAX(id) AS latest_installment_id,
                        SUM(weight) AS weight
                    FROM
                        customer_advance_installment
                    GROUP BY
                        customer_advance_id
                ) agg
                JOIN customer_advance_installment li
                    ON li.id = agg.latest_installment_id
                ) cat ON cat.customer_advance_id = ca.id
                JOIN branch b ON b.id = ca.location_id
                JOIN address ad ON ad.id = b.address_id
                JOIN customer_advance_status cas ON cas.customer_advance_id = ca.id AND end_time = '2100-01-01 00:00:00+00'
                WHERE ca.id = %(customer_advance_id)s
                """
                await cur.execute(
                    fetch_advance_advance_query,
                    {
                        "customer_advance_id": advance.advance_id,
                    },
                )
                result = await cur.fetchone()
                if advance.partial_clubbing:
                    amount = result["term_amount"]
                    weight = result["weight"]
                    if result["weight_type"] == "SRK":
                        if advance.weight < round(weight * 0.5, 3):
                            raise BadRequestException(
                                "Clubbing SRK needs atleast 50% of the alloted weight"
                            )
                    if advance.amount > amount:
                        raise BadRequestException(
                            "Amount cannot exceed actual amount alloted for advance"
                        )
                    if advance.weight > weight:
                        raise BadRequestException(
                            "Weight cannot exceed actual weight alloted for advance"
                        )

                    if advance.amount == amount and advance.weight == weight:
                        raise BadRequestException(
                            "Partial advance cannot have the full amount and weight. Please provide values less than the total advance."
                        )

                    advance_codes.append(
                        {
                            "reference_user_id": result["reference_user_id"],
                            "joined_at": result["joined_at"].isoformat(),
                            "advance_code": result["customer_advance_code"],
                            "advance_id": result["id"],
                            "type": result["weight_type"],
                            "location": result["location"],
                            "partial_amount": advance.amount,
                            "partial_weight": advance.weight,
                            "partial_clubbing": True,
                            "status": result["status"],
                            "installments": result["installments"],
                        }
                    )

                else:
                    advance_codes.append(
                        {
                            "reference_user_id": result["reference_user_id"],
                            "joined_at": result["joined_at"].isoformat(),
                            "advance_code": result["customer_advance_code"],
                            "advance_id": result["id"],
                            "type": result["weight_type"],
                            "location": result["location"],
                            "amount": result["term_amount"],
                            "weight": result["weight"],
                            "partial_clubbing": False,
                            "status": result["status"],
                            "installments": result["installments"],
                        }
                    )

            advance_id_codes_list = json.dumps(advance_codes)
            return advance_id_codes_list


async def get_draft(async_pool: AsyncConnectionPool, draft_id: int):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            get_invoice_query = """
                SELECT
                    json_data
                FROM 
                    draft_form
                WHERE 
                    id = %(draft_id)s AND form_type = 'INVOICE'
            """
            await cur.execute(get_invoice_query, {"draft_id": draft_id})
            invoice = await cur.fetchone()
            if not invoice:
                raise BadRequestException("Draft Invoice Not Found")

            invoice = Invoice.model_validate(invoice["json_data"])
            if invoice.customer:
                sr_invoice_id, sr_value = _clubbed_sales_return_cash_args(invoice)
                invoice.customer_cash_balance = await CustomerCashBalance(
                    cur,
                    invoice.customer.customer_id,
                    location_id=invoice.location.location_id,
                    clubbed_document_codes=[
                        advance.advance_code for advance in invoice.customer_advances
                    ],
                    sales_return_invoice_id=sr_invoice_id,
                    sales_return_value=sr_value,
                ).get_cash_balance()
            result = json.loads(invoice.model_dump_json())
            return result


async def get_invoice_drafts(
    async_pool: AsyncConnectionPool, user: UserJWTPayload, query: str | None = None
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            get_invoice_query = """
                SELECT
                    draft_invoice.draft_id,
                    c.full_name as customer_name,
                    draft_invoice.total_amount,
                    draft_invoice.total_weight
                FROM 
                    (
                        SELECT
                            id as draft_id,
                            (json_data -> 'customer' ->> 'customer_id')::NUMERIC AS customer_id,
                            COALESCE((json_data ->> 'total_amount')::NUMERIC, 0) as total_amount,
                            COALESCE((json_data ->> 'total_weight')::NUMERIC, 0) AS total_weight,
                            (json_data -> 'location' ->> 'location_id')::NUMERIC AS location_id,
                            created_at
                        FROM
                            draft_form 
                        WHERE form_type='INVOICE'
                    
                    ) as draft_invoice
                LEFT JOIN
                    customer c ON c.id = draft_invoice.customer_id
                WHERE
                   (1=1)
            """
            params = {"branch_id": user.branch_id}
            get_invoice_query += "AND  (draft_invoice.location_id = %(branch_id)s)"
            if query:
                get_invoice_query += "AND ((c.full_name ILIKE %(query)s) OR (c.phone_primary ILIKE %(query)s)) "
                params["query"] = f"%{query}%"
            else:
                get_invoice_query += (
                    "AND (draft_invoice.created_at::date = CURRENT_DATE)"
                )
            get_invoice_query += " ORDER BY draft_invoice.created_at DESC"
            await cur.execute(get_invoice_query, params)
            invoices = await cur.fetchall()

            return invoices


async def remove_line_item(
    async_pool: AsyncConnectionPool, draft_invoice_id: int, line_item_index: int
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            fetch_invoice_data_query = """
            SELECT
                json_data
            FROM
                draft_form
            WHERE
                id= %(draft_id)s AND form_type='INVOICE'
            """
            await cur.execute(fetch_invoice_data_query, {"draft_id": draft_invoice_id})
            result = await cur.fetchone()
            if not result:
                raise BadRequestException("Draft id not found")
            invoice_data = result["json_data"]
            if len(invoice_data["line_items"]) <= 1:
                invoice_data["repurchase_amount"] = 0

            try:
                invoice_data = Invoice.model_validate(invoice_data)
                invoice_data.remove_line_item(line_item_index)
            except Exception as error:
                raise BadRequestException(str(error))

            if len(invoice_data.line_items) == 0:
                invoice_data.payment_methods = []

            data = await invoice_draft_check(cur, draft_invoice_id)

            if data:
                raise BadRequestException(
                    "Can't edit the data. Invoice already created."
                )

            update_invoice_data = """
            UPDATE draft_form
            SET json_data=%(json_data)s
            WHERE 
                id =%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                update_invoice_data,
                {
                    "json_data": invoice_data.model_dump_json(),
                    "draft_invoice_id": draft_invoice_id,
                },
            )

            return {"message": "Line Item Deleted Successfully"}


# ---------------------Actual Invoice Creation---------------------------------------


async def check_employee_id(cur: AsyncCursor[DictRow], employee_id: int):
    search_query = """
    SELECT
        id
    FROM
        employee        
    WHERE
        id = %(employee_id)s
    """
    await cur.execute(search_query, {"employee_id": employee_id})
    data = await cur.fetchone()

    if not data:
        raise BadRequestException("Employee doesn't Exist")
    return data["id"]


async def check_user_id(cur: AsyncCursor[DictRow], user_id: int):
    search_query = """
    SELECT
        id
    FROM
        app_user        
    WHERE
        id = %(user_id)s
    """
    await cur.execute(search_query, {"user_id": user_id})
    data = await cur.fetchone()

    if not data:
        raise BadRequestException("User Doesnt Exist")
    return data["id"]


async def check_customer_id(cur: AsyncCursor[DictRow], customer_id: int):
    search_query = """
    SELECT
        id
    FROM
        customer        
    WHERE
        id = %(customer_id)s
    """
    await cur.execute(search_query, {"customer_id": customer_id})
    data = await cur.fetchone()

    if not data:
        raise BadRequestException("Customer Doesnt Exist")
    return data["id"]


async def repurchase_amount_calculate(
    cur: AsyncCursor[DictRow], repurchase: RepurchaseRequest
):
    if repurchase.repurchase_id:
        get_repurchase_query = """
            SELECT
                r.id as repurchase_id,
                rli.line_items
            FROM
                repurchase r
            LEFT JOIN
                repurchase_status rs ON rs.repurchase_id = r.id
            LEFT JOIN (
                SELECT
                    rli.repurchase_id,
                    JSONb_AGG(
                        JSONb_BUILD_OBJECT('box_item_product_id',rli.box_item_product_id,'line_item_name',rli.line_item_name,'materials', materials.materials)

                    ) AS line_items
                FROM
                    repurchase_line_item rli
                LEFT JOIN (
                    SELECT
                        rlim.repurchase_line_item_id,
                        JSON_AGG(
                            JSON_BUILD_OBJECT(
                                'material_code', m.material_code,
                                'weight', pmw.weight,
                                'type', m.type,
                                'quantity', pmw.quantity,
                                'rate', rlim.rate,
                                -- 'bias', rlim.weight_adjustment_bias,
                                'touch', rlim.touch
                            )
                        ) AS materials
                    FROM
                        repurchase_line_item_material rlim
                    LEFT JOIN
                        product_material pm ON pm.id = rlim.product_material_id
                    LEFT JOIN
                        product_material_weight pmw ON pm.id = pmw.product_material_id
                    LEFT JOIN
                        material m ON m.id = pm.material_id
                    GROUP BY
                        rlim.repurchase_line_item_line_id
                ) AS materials ON materials.repurchase_line_item_line_id = rli.id
                GROUP BY
                    rli.repurchase_id
            ) rli ON rli.repurchase_id = r.id
            WHERE
                r.id = %(repurchase_id)s AND rs.end_time = '2100-01-01 00:00:00+00' AND rs.status IN ('UNPAID','PARTIAL_PAID')
            GROUP BY
                r.id,rli.line_items;

        """
        await cur.execute(
            get_repurchase_query, {"repurchase_id": repurchase.repurchase_id}
        )
        data = await cur.fetchone()
        if not data:
            raise BadRequestException("Repurchase Not Found Or Already Paid")
        repurchase_line_items = [
            RepurchaseLineItem.model_validate(
                {
                    **item,
                    "materials": [
                        RepurchaseMaterial.model_validate(material)
                        for material in item["materials"]
                    ],
                }
            )
            for item in data["line_items"]
        ]
        get_payment_methods_query = """
            SELECT
                JSON_BUILD_ARRAY(tr.cash_value, tr.neft_value) as payment_methods
            FROM
                    repurchase r
                LEFT JOIN
                (	SELECT
                        rtg.repurchase_id,
                        COALESCE(SUM(CASE WHEN tg.transaction_mode = 'OTHER' AND t.amount >= 0 THEN t.amount ELSE 0 END), 0) AS total_value,
                        COALESCE(SUM(CASE WHEN tg.transaction_mode = 'CASH' AND t.amount >= 0 THEN t.amount ELSE 0 END), 0) AS cash_value,
                        COALESCE(SUM(CASE WHEN tg.transaction_mode = 'NEFT' AND t.amount >= 0 THEN t.amount ELSE 0 END), 0) AS neft_value,
                        COALESCE(SUM(CASE WHEN tg.transaction_mode = 'OTHER' AND t.amount >= 0 THEN t.amount ELSE 0 END), 0)
                        - COALESCE(SUM(CASE WHEN tg.transaction_mode = 'CASH' AND t.amount >= 0 THEN t.amount ELSE 0 END), 0)
                        - COALESCE(SUM(CASE WHEN tg.transaction_mode = 'NEFT' AND t.amount >= 0 THEN t.amount ELSE 0 END), 0) AS balance,
 					MAX(tg.transaction_number) AS transaction_number
                    FROM
                        repurchase_transaction_group rtg
                    LEFT JOIN
                        transaction_group tg ON tg.id = rtg.transaction_group_id
                    LEFT JOIN
                        transaction t ON t.transaction_group_id = tg.id
                    WHERE
                        tg.transaction_mode IN ('CASH', 'NEFT', 'OTHER') 
                    GROUP BY
                        rtg.repurchase_id
                    ) as tr ON tr.repurchase_id = r.id
                    WHERE
                        r.id = %(repurchase_id)s
        """
        await cur.execute(
            get_payment_methods_query, {"repurchase_id": repurchase.repurchase_id}
        )
        payment_methods = await cur.fetchone()
        if not payment_methods:
            repurchase_refund_methods = [RepurchaseRefundMethod(amount=0)]
        else:
            repurchase_refund_methods = [
                RepurchaseRefundMethod(amount=amount)
                for amount in payment_methods["payment_methods"]
            ]
        repurchase = Repurchase(
            repurchase_id=data["repurchase_id"],
            line_items=repurchase_line_items,
            refund_methods=repurchase_refund_methods,
        )

        return repurchase
    get_line_item_names = """
        SELECT
            id,
            product_name as line_item_name
        FROM
            product
        WHERE
            id = ANY(%(box_item_product_ids)s) AND is_box = 'true'
    """
    product_ids = [item.box_item_product_id for item in repurchase.line_items]
    await cur.execute(get_line_item_names, {"box_item_product_ids": product_ids})
    line_item_name_map = {
        row["id"]: row["line_item_name"] for row in await cur.fetchall()
    }
    repurchase_line_items = []
    for item in repurchase.line_items:
        line_item_name = line_item_name_map.get(item.box_item_product_id)
        if not line_item_name:
            raise BadRequestException(
                f"Box Product Not Found for ID: {item.box_item_product_id}"
            )

        materials = [
            RepurchaseMaterial(**{**material.model_dump(), "bias": material.bias})
            for material in item.materials
        ]
        repurchase_line_items.append(
            RepurchaseLineItem(
                box_item_product_id=item.box_item_product_id,
                line_item_name=line_item_name,
                materials=materials,
            )
        )

    return Repurchase(
        line_items=repurchase_line_items,
        refund_methods=[RepurchaseRefundMethod(amount=0)],
    )


async def fetch_repurchase_amount_from_draft(
    cur: AsyncCursor[DictRow], repurchase_request: RepurchaseRequest
):
    fetch_repurchase_data = """
    SELECT json_data from draft_form WHERE form_type='REPURCHASE' and id =%(draft_repurchase_id)s
    """
    await cur.execute(
        fetch_repurchase_data,
        {"draft_repurchase_id": repurchase_request.repurchase_draft_id},
    )
    repurchase_data = await cur.fetchone()
    if not repurchase_data:
        raise BadRequestException("Repurchase Not Found")
    repurchase = RepurchaseDraft.model_validate(repurchase_data["json_data"])

    if repurchase.total_repurchase_value <= 0:
        raise BadRequestException("Cannot add repurchase with amount 0")

    if (
        repurchase_request.benefit_amount is not None
        and repurchase_request.benefit_amount < 0
    ):
        raise BadRequestException("Repurchase benefit amount cannot be less than zero")

    return Repurchase(
        benefit_amount=repurchase_request.benefit_amount,
        total_amount=repurchase.total_repurchase_value,
        repurchase_id=repurchase_request.repurchase_draft_id,
    )


async def sales_return_draft_fetch(
    cur: AsyncCursor[DictRow], draft_sales_return_id: int
):
    fetch_draft_sales_return_data = """
    SELECT 
        json_data
    FROM 
        draft_form
    WHERE id=%(draft_sales_return_id)s and form_type='SALES_RETURN'
    """
    await cur.execute(
        fetch_draft_sales_return_data, {"draft_sales_return_id": draft_sales_return_id}
    )
    data = await cur.fetchone()
    return SalesReturn.model_validate(data["json_data"])


async def add_sales_return_plan_rate_difference(
    cur: AsyncCursor[DictRow],
    original_invoice_id: int,
    invoice_data: Invoice,
):
    """Carry over any customer plan *or* customer advance that was clubbed on the
    original invoice of a sales return as a zero (amount=0, weight=0)
    rate-difference entry on the current invoice draft.

    Plans live in ``invoice_customer_plan`` -> ``customer_plan`` (REG/ILL);
    advances live in ``invoice_customer_advance_installment`` /
    ``invoice_customer_advance_redeemed`` -> ``customer_advance`` (SRK/SYM/TAV/
    AKT/ING/...). Both are carried, so an original invoice whose benefit came from
    an advance shows a rate-difference row here too.

    The rate-difference entry is created if and only if the original invoice had
    at least one line item with an MC benefit tied to it (``MCB_AMT`` stored in
    ``invoice_line_item_component_value``). If that condition does not hold, any
    previously carried-over plan/advance is removed.

    Each entry is added to ``customer_advances`` with empty installments so it
    contributes nothing to the benefit, and is flagged ``is_sales_return_plan``
    so finalize does not re-link it / re-redeem it.
    """
    # Start clean: drop any previously carried-over sales-return plan so this is
    # idempotent across repeated calls / changed source invoices.
    invoice_data.customer_advances = [
        ca for ca in invoice_data.customer_advances if not ca.is_sales_return_plan
    ]

    # Gate: the original invoice must have had a line item with MC benefit.
    fetch_has_mc_benefit = """
        SELECT EXISTS (
            SELECT 1
            FROM invoice_line_item ili
            JOIN invoice_line_item_component_value ilicv
                ON ilicv.invoice_line_item_id = ili.id
            JOIN line_item_component lic
                ON lic.id = ilicv.line_item_component_id
            WHERE ili.invoice_id = %(invoice_id)s
                AND lic.line_item_component_code = 'MCB_AMT'
                AND ilicv.value <> 0
        ) AS has_mc_benefit
    """
    await cur.execute(fetch_has_mc_benefit, {"invoice_id": original_invoice_id})
    mc_benefit_row = await cur.fetchone()
    if not mc_benefit_row or not mc_benefit_row["has_mc_benefit"]:
        return

    fetch_clubbed_plans = """
        SELECT
            cp.id AS advance_id,
            cp.customer_plan_code AS advance_code,
            cp.type::TEXT AS type,
            cp.joined_at,
            cp.referral_user_id
        FROM invoice_customer_plan icp
        JOIN customer_plan cp ON cp.id = icp.customer_plan_id
        WHERE icp.invoice_id = %(invoice_id)s
    """
    await cur.execute(fetch_clubbed_plans, {"invoice_id": original_invoice_id})
    clubbed_plans = await cur.fetchall()

    existing_advance_ids = {ca.advance_id for ca in invoice_data.customer_advances}

    for plan in clubbed_plans:
        if plan["advance_id"] in existing_advance_ids:
            continue
        plan_advance = CustomerAdvance(
            advance_code=plan["advance_code"],
            advance_id=plan["advance_id"],
            joined_at=plan["joined_at"],
            referral_user_id=plan["referral_user_id"],
            location=invoice_data.location,
            status="ACTIVE",
            type=plan["type"],
            installments=[],
            is_advance=False,
            is_sales_return_plan=True,
        )
        invoice_data.customer_advances.append(plan_advance)

    ##- Same carry-over for customer *advances* clubbed on the original invoice.
    ##- An advance can be linked either through its installments or through the
    ##- rate-difference row, so both are considered.
    fetch_clubbed_advances = """
        SELECT DISTINCT
            ca.id AS advance_id,
            ca.customer_advance_code AS advance_code,
            ca.advance_type::TEXT AS type,
            ca.joined_at,
            ca.reference_user_id
        FROM customer_advance ca
        WHERE ca.advance_type IS NOT NULL
            AND ca.id IN (
                SELECT cai.customer_advance_id
                FROM invoice_customer_advance_installment icai
                JOIN customer_advance_installment cai
                    ON cai.id = icai.customer_advance_installment_id
                WHERE icai.invoice_id = %(invoice_id)s
                UNION
                SELECT icar.customer_advance_id
                FROM invoice_customer_advance_redeemed icar
                WHERE icar.invoice_id = %(invoice_id)s
            )
    """
    await cur.execute(fetch_clubbed_advances, {"invoice_id": original_invoice_id})
    clubbed_advances = await cur.fetchall()

    existing_advance_ids = {ca.advance_id for ca in invoice_data.customer_advances}

    for advance in clubbed_advances:
        if advance["advance_id"] in existing_advance_ids:
            continue
        carried_advance = CustomerAdvance(
            advance_code=advance["advance_code"],
            advance_id=advance["advance_id"],
            joined_at=advance["joined_at"],
            reference_user_id=advance["reference_user_id"],
            location=invoice_data.location,
            status="ACTIVE",
            type=advance["type"],
            installments=[],
            is_advance=True,
            is_sales_return_plan=True,
        )
        invoice_data.customer_advances.append(carried_advance)


async def update_invoice(
    async_pool: AsyncConnectionPool,
    draft_id: int,
    customer_sale_request: CustomerSaleRequest,
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            get_customer_id = """
            SELECT
                json_data
            FROM
                draft_form
            WHERE
                id= %(draft_id)s
            """
            await cur.execute(get_customer_id, {"draft_id": draft_id})
            result = await cur.fetchone()
            invoice_data = Invoice.model_validate(result["json_data"])
            if customer_sale_request.customer_id:
                customer_address_query = """
                    SELECT 
                        a.state_code,
                        a.address_line1,
                        a.address_line2,
                        a.pin,
                        a.town,
                        a.district_id,
                        a.area_id
                    FROM customer c
                    JOIN address a ON a.id = c.primary_address_id
                    WHERE c.id = %(customer_id)s
                """
                await cur.execute(
                    customer_address_query,
                    {"customer_id": customer_sale_request.customer_id},
                )
                customer_address = await cur.fetchone()

                if not customer_address:
                    raise ValueError(
                        f"Customer {customer_sale_request.customer_id} has no primary address"
                    )

                if (
                    invoice_data.customer_advances
                    and invoice_data.customer is not None
                    and invoice_data.customer.customer_id
                    != customer_sale_request.customer_id
                ):
                    raise BadRequestException(
                        "Cannot change the customer while advances or plans are "
                        "attached to this invoice. Please remove the clubbed "
                        "advances/plans first, then change the customer."
                    )

                # Create/update customer in one go
                invoice_data.customer = Customer(
                    customer_id=customer_sale_request.customer_id,
                    address=Address(
                        address_line1=customer_address["address_line1"],
                        address_line2=customer_address["address_line2"],
                        state_code=customer_address["state_code"],
                        pin=customer_address["pin"],
                        town=customer_address["town"],
                        district_id=customer_address["district_id"],
                        area_id=customer_address["area_id"],
                    ),
                )
            if customer_sale_request.sales_person_employee_id:
                invoice_data.sales_person_employee_id = (
                    customer_sale_request.sales_person_employee_id
                )
            if customer_sale_request.manager_employee_id:
                invoice_data.manager_employee_id = (
                    customer_sale_request.manager_employee_id
                )
            if customer_sale_request.manual_referral_user_id != None:
                invoice_data.manual_referral_user_id = (
                    customer_sale_request.manual_referral_user_id
                )
            if customer_sale_request.round_off_amount != None:
                invoice_data.round_off_amount = customer_sale_request.round_off_amount

            if customer_sale_request.notes:
                invoice_data.notes = customer_sale_request.notes

            if customer_sale_request.is_insured is not None:
                # Record it as the user's explicit choice; invoice.is_insured is computed
                # from this and the taxable value.
                invoice_data.is_insured_choice = customer_sale_request.is_insured

            if customer_sale_request.sales_return:
                if customer_sale_request.sales_return.sales_return_draft_id:
                    sales_return_draft_model_data = await sales_return_draft_fetch(
                        cur, customer_sale_request.sales_return.sales_return_draft_id
                    )
                    sales_return_request = SalesReturnDraft(
                        draft_sales_return_id=customer_sale_request.sales_return.sales_return_draft_id,
                        draft_sales_return_data=sales_return_draft_model_data,
                    )
                    invoice_data.sales_return = sales_return_request

                    # If the original invoice of this sales return had a customer
                    # plan clubbed, carry it over as a zero rate-difference entry.
                    if sales_return_draft_model_data.invoice_id:
                        await add_sales_return_plan_rate_difference(
                            cur,
                            sales_return_draft_model_data.invoice_id,
                            invoice_data,
                        )
                else:
                    invoice_data.sales_return = None
                    # Drop any plan carried over from a previously attached sales return
                    invoice_data.customer_advances = [
                        ca
                        for ca in invoice_data.customer_advances
                        if not ca.is_sales_return_plan
                    ]

            if customer_sale_request.repurchase:
                if invoice_data.repurchase:
                    if not customer_sale_request.repurchase.repurchase_draft_id:
                        invoice_data.repurchase = None
                    else:
                        repurchase = await fetch_repurchase_amount_from_draft(
                            cur, customer_sale_request.repurchase
                        )
                        invoice_data.repurchase = repurchase
                else:
                    if customer_sale_request.repurchase.repurchase_draft_id:
                        repurchase = await fetch_repurchase_amount_from_draft(
                            cur, customer_sale_request.repurchase
                        )
                        invoice_data.repurchase = repurchase

            if customer_sale_request.sales_return_discount:
                invoice_data.sales_return_discount = SalesReturnDiscount.model_validate(
                    customer_sale_request.sales_return_discount.model_dump()
                )

            if customer_sale_request.invoice_discount:
                invoice_data.invoice_discount = customer_sale_request.invoice_discount

            data = await invoice_draft_check(cur, draft_invoice_id=draft_id)
            if data:
                raise BadRequestException(
                    "Can't edit the data. Invoice already created."
                )

            update_invoice_data = """
            UPDATE draft_form
            SET json_data=%(json_data)s
            WHERE 
                id =%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                update_invoice_data,
                {
                    "json_data": invoice_data.model_dump_json(),
                    "draft_invoice_id": draft_id,
                },
            )

            return json.loads(invoice_data.model_dump_json())


async def remove_customer(async_pool: AsyncConnectionPool, draft_id: int):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            get_customer_id = """
            SELECT
                json_data
            FROM
                draft_form
            WHERE
                id= %(draft_id)s
            """
            await cur.execute(get_customer_id, {"draft_id": draft_id})
            result = await cur.fetchone()

            serialized_invoice = Invoice.model_validate(result["json_data"])
            serialized_invoice.customer = None
            serialized_invoice.customer_advances = []
            serialized_invoice.sales_return = None
            serialized_invoice.repurchase = None

            data = await invoice_draft_check(cur, draft_invoice_id=draft_id)

            if data:
                raise BadRequestException(
                    "Can't edit the data. Invoice already created."
                )

            update_invoice_data = """
            UPDATE draft_form
            SET json_data=%(json_data)s
            WHERE 
                id =%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                update_invoice_data,
                {
                    "json_data": serialized_invoice.model_dump_json(),
                    "draft_invoice_id": draft_id,
                },
            )

            return json.loads(serialized_invoice.model_dump_json())


async def update_advance(
    async_pool: AsyncConnectionPool,
    draft_id: int,
    advance_id: int,
    advance_request: UpdateAdvanceRequest,
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            get_customer_id = """
            SELECT
                json_data
            FROM
                draft_form
            WHERE
                id= %(draft_id)s
            """
            await cur.execute(get_customer_id, {"draft_id": draft_id})
            result = await cur.fetchone()

            serialized_invoice = Invoice.model_validate(result["json_data"])
            for i in serialized_invoice.customer_advances:
                if i.advance_id == advance_id:
                    i.mc_benefit = advance_request.mc_benefit
            data = await invoice_draft_check(cur, draft_invoice_id=draft_id)

            if data:
                raise BadRequestException(
                    "Can't edit the data. Invoice already created."
                )
            update_invoice_data = """
            UPDATE draft_form
            SET json_data=%(json_data)s
            WHERE 
                id =%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                update_invoice_data,
                {
                    "json_data": serialized_invoice.model_dump_json(),
                    "draft_invoice_id": draft_id,
                },
            )

            return json.loads(serialized_invoice.model_dump_json())


async def payment_method_user_check(
    cur: AsyncCursor[DictRow],
    payload: Invoice,
    current_employee_id: int,
):
    """
    Performs mandatory checks on the payload of the draft invoice.
    Ensures payment methods are not duplicated except for card, created_by_employee_id matches the current employee id,
    salesperson_employee_id is valid, and referral_user_id is also valid if present.
    """

    if payload.payment_methods:
        methods = [payment.payment_type for payment in payload.payment_methods]
        cash = methods.count("CASH")
        if cash > 1:
            raise BadRequestException("Only one cash payment method is allowed.")

        if payload.created_by_employee_id != current_employee_id:
            raise BadRequestException("Employee id mismatch in creation")

        if payload.sales_person_employee_id != await check_employee_id(
            cur, payload.sales_person_employee_id
        ):
            raise BadRequestException("Salesman ID mismatch")

        if getattr(
            payload, "referral_user_id", None
        ):  # Check if the optional key exists
            if payload.referral_user_id != await check_user_id(
                cur, payload.referral_user_id
            ):
                raise BadRequestException("Referral ID mismatch")

    else:
        raise BadRequestException("Payment method is required.")


async def get_chart_of_account_id(
    cur: AsyncCursor[DictRow], chart_of_account_name: str
):
    get_chart_of_account_id_query = """
    SELECT
        id
    FROM
        chart_of_account
    WHERE
        account_name = %(chart_of_account_name)s
    """
    await cur.execute(
        get_chart_of_account_id_query, {"chart_of_account_name": chart_of_account_name}
    )
    data = await cur.fetchone()
    if not data:
        raise BadRequestException(f"No Account Found : {chart_of_account_name}")
    return data["id"]


async def make_customer_advance_without_payment(
    cur: AsyncCursor[DictRow],
    request: RefundMethod,
    invoice: Invoice,
    # transaction_group: List[int],
    location_id: int,
    # customer_chart_of_account_id: int,
    async_pool=None,
):
    advance_code = await generate_customer_advance_code(
        get_advance_prefix(request.advance_type),
        location_id,
        "SHOP",
        cur,
    )

    # get customer address
    get_customer_address_query = """
                SELECT 
                    primary_address_id,phone_primary
                FROM
                    customer
                WHERE  
                    id = %(customer_id)s
                """
    await cur.execute(
        get_customer_address_query, {"customer_id": invoice.customer.customer_id}
    )
    customer_address = await cur.fetchone()

    params = {
        "customer_advance_code": advance_code,
        "customer_id": invoice.customer.customer_id,
        "location_id": invoice.location.location_id,
        "note": request.note,
        "advance_type": get_advance_type(request.advance_type),
        "reference_user_id": request.reference_user_id
        if request.reference_user_id != 0
        else None,
    }

    if invoice.sales_person_employee_id:
        get_sales_person_query = """
                    SELECT
                        id
                    FROM
                        employee
                    where 
                    id = %(employee_id)s
                    """

    await cur.execute(
        get_sales_person_query,
        {"employee_id": invoice.sales_person_employee_id},
    )
    sales_person_id = await cur.fetchone()
    if sales_person_id:
        params.update({"sales_person_employee_id": invoice.sales_person_employee_id})
    else:
        raise ResourceNotFoundException("Sales person does not exist")

    query = generate_insert_query("customer_advance", params)
    await cur.execute(
        query,
        params,
    )

    customer_advance_id = await cur.fetchone()
    insert_advance_status_draft = """
            INSERT INTO customer_advance_status (customer_advance_id,status)
            VALUES (%(customer_advance_id)s,'DRAFT')
            """
    await cur.execute(
        insert_advance_status_draft,
        {"customer_advance_id": customer_advance_id["id"]},
    )
    get_gold_rate_query = """
                    SELECT
                        g.rate
                    FROM
                        material_rate g
                    LEFT JOIN 
                        material m ON m.id = g.material_id
                    WHERE
                        g.location_id = %(branch_id)s
                        AND g.end_time = '2100-01-01 00:00:00+00' AND m.material_code IN ('G22')
                """
    await cur.execute(get_gold_rate_query, {"branch_id": invoice.location.location_id})
    gold_rate = await cur.fetchone()
    weight = None
    if request.advance_type == "SR":
        weight = round(((request.amount + request.additional_amount) * 0.004), 3)
    elif request.advance_type in ["RL", "SW"]:
        weight = request.weight
    elif request.advance_type == "TA":
        weight = 0
    if not weight and request.advance_type != "TA":
        raise BadRequestException("Weight Required")

    params = {
        "customer_advance_id": customer_advance_id["id"],
        "weight": weight,
        "amount": round(request.amount + request.additional_amount, 2),
        "weight_type": get_advance_weight_type(request.advance_type),
        "g22_rate": gold_rate["rate"],
        "mature_at": None,
        "expires_at": None,
    }
    params.update(
        await get_advance_expire_mature_date(
            cur, request.advance_type, request.due_date, invoice.location.location_id
        )
    )

    insert_into_customer_advance_transaction = """
    INSERT INTO customer_advance_installment
    (
        customer_advance_id,
        weight,
        amount,
        weight_type,
        g22_rate,
        mature_at,
        expires_at
    )
    VALUES
    (
        %(customer_advance_id)s,
        %(weight)s,
        %(amount)s,
        %(weight_type)s,
        %(g22_rate)s,
        %(mature_at)s,
        %(expires_at)s
    )
    RETURNING ID;
    """
    await cur.execute(insert_into_customer_advance_transaction, params)
    customer_advance_installment_id = (await cur.fetchone())["id"]

    # insert_into_customer_advance_installment_transaction_group = """
    #             INSERT INTO customer_advance_installment_transaction_group
    #             (
    #                 customer_advance_installment_id,
    #                 transaction_group_id
    #             )
    #             VALUES
    #             (
    #                 %(customer_advance_installment_id)s,
    #                 %(transaction_group_id)s
    #             )
    #         """

    # for i in transaction_group:
    #     await cur.execute(
    #         insert_into_customer_advance_installment_transaction_group,
    #         {
    #             "customer_advance_installment_id": customer_advance_installment_id,
    #             "transaction_group_id": i,
    #         },
    #     )
    await update_customer_advance_status(cur, customer_advance_id["id"], "ACTIVE")

    background_tasks = BackgroundTasks()
    if request.advance_type in ["RL", "TA"]:
        rs_amount = f"INR {int(request.amount)}.00"
        expires_at = request.due_date.strftime("%d-%b-%Y")
        sms = f"We have successfully processed your payment of {rs_amount} for Advance Booking {advance_code}. Please note that your due date is {expires_at}. Thank you for choosing Regal Jewellers!"
        background_tasks.add_task(
            send_sms_background,
            async_pool,
            customer_address["phone_primary"],
            sms,
            "1107173026330934323",
        )
    elif request.advance_type == "SR":
        plan = "Swarna Raksha"
        rs_amount = f"INR {int(request.amount)}.00"
        sms = f"You have successfully made a payment of {rs_amount} for the {plan} plan ({advance_code}). Thank you for choosing Regal Jewellers!"
        background_tasks.add_task(
            send_sms_background,
            async_pool,
            customer_address["phone_primary"],
            sms,
            "1107174946921369132",
        )

    return customer_advance_id["id"], customer_advance_installment_id


async def make_customer_advance_without_payment_for_partial_clubbing(
    cur: AsyncCursor[DictRow],
    advance_type: str,
    weight: float,
    amount: float,
    invoice: Invoice,
    transaction_group: List[int],
    due_date: datetime.date,
    rate: float,
    send_message: bool,
    parent_id: int,
    sales_person_employee_id: int,
    mature_at: datetime.date,
    joined_at: datetime,
    # customer_chart_of_account_id: int,
    async_pool=None,
):
    advance_type = AdvanceType(advance_type)

    advance_code = await generate_customer_advance_code(
        get_advance_prefix(advance_type.name),
        invoice.location.location_id,
        "SHOP",
        cur,
    )

    # get customer address
    get_customer_address_query = """
                SELECT 
                    primary_address_id,phone_primary
                FROM
                    customer
                WHERE  
                    id = %(customer_id)s
                """
    await cur.execute(
        get_customer_address_query, {"customer_id": invoice.customer.customer_id}
    )
    customer_address = await cur.fetchone()

    params = {
        "customer_advance_code": advance_code,
        "customer_id": invoice.customer.customer_id,
        "location_id": invoice.location.location_id,
        "term_amount": amount,
        "note": "",
        "advance_type": advance_type.value,
        "parent_customer_advance_id": parent_id,
        "expires_at": due_date,
        "mature_at": mature_at,
        "joined_at": joined_at,
    }
    # params.update(
    #     await get_advance_expire_mature_date(
    #         cur, advance_type.name, due_date, invoice.location.location_id
    #     )
    # )

    if invoice.sales_person_employee_id:
        get_sales_person_query = """
        SELECT
            id
        FROM
            employee
        where 
        id = %(employee_id)s
        """

    await cur.execute(
        get_sales_person_query,
        {"employee_id": invoice.sales_person_employee_id},
    )
    sales_person_id = await cur.fetchone()
    if sales_person_id:
        params.update({"sales_person_employee_id": sales_person_employee_id})
    else:
        raise ResourceNotFoundException("Sales person does not exist")

    query = generate_insert_query("customer_advance", params)
    await cur.execute(
        query,
        params,
    )

    customer_advance_id = await cur.fetchone()
    insert_advance_status_draft = """
            INSERT INTO customer_advance_status (customer_advance_id,status)
            VALUES (%(customer_advance_id)s,'DRAFT')
            """
    await cur.execute(
        insert_advance_status_draft,
        {"customer_advance_id": customer_advance_id["id"]},
    )

    ##- Taking gold rate from the parent customer advance
    # get_gold_rate_query = """
    #     SELECT
    #         g.rate
    #     FROM
    #         material_rate g
    #     LEFT JOIN
    #         material m ON m.id = g.material_id
    #     WHERE
    #         g.location_id = %(branch_id)s
    #         AND g.end_time = '2100-01-01 00:00:00+00' AND m.material_code IN ('G22')
    # """
    # await cur.execute(get_gold_rate_query, {"branch_id": invoice.location.location_id})
    # gold_rate = await cur.fetchone()
    # weight = None
    # if advance_type.name == "SR":
    #     weight = round((request.total_amount * 0.004), 3)
    # elif request.advance_type in ["RL", "SW"]:
    #     weight = request.weight
    # elif request.advance_type == "TA":
    #     weight = 0

    ##- Overriding existing weight managment flow for advance as this is created based on the remainig weight from actual advance
    # if not weight and advance_type.name != "TA":
    #     raise BadRequestException("Weight Required")

    insert_into_customer_advance_transaction = """
        INSERT INTO customer_advance_installment
        (   
            customer_advance_id,
            weight,
            amount,
            weight_type,
            g22_rate,
            transaction_source_type
        )
        VALUES
        (   
            %(customer_advance_id)s,
            %(weight)s,
            %(amount)s,
            %(weight_type)s,
            %(g22_rate)s,
            %(transaction_source_type)s
        )
        RETURNING ID;
    """
    await cur.execute(
        insert_into_customer_advance_transaction,
        {
            "customer_advance_id": customer_advance_id["id"],
            "weight": weight,
            "amount": amount,
            "weight_type": get_advance_weight_type(advance_type.name),
            "g22_rate": rate,
            "transaction_source_type": "INVOICE",
        },
    )
    customer_advance_installment_id = (await cur.fetchone())["id"]
    # insert_document_transaction_query = """
    #             INSERT INTO transaction_group_document
    #             (
    #                 transaction_group_id,
    #                 document_id,
    #                 document_code,
    #                 document_type
    #             )
    #             VALUES
    #             (
    #                 %(transaction_group_id)s,
    #                 %(document_id)s,
    #                 %(document_code)s,
    #                 %(document_type)s

    #             )
    #             """
    insert_into_customer_advance_installment_transaction_group = """
                INSERT INTO customer_advance_installment_transaction_group
                (   
                    customer_advance_installment_id,
                    transaction_group_id
                )
                VALUES
                (   
                    %(customer_advance_installment_id)s,
                    %(transaction_group_id)s
                )
            """

    for i in transaction_group:
        await cur.execute(
            insert_into_customer_advance_installment_transaction_group,
            {
                "customer_advance_installment_id": customer_advance_installment_id,
                "transaction_group_id": i,
            },
        )
    await update_customer_advance_status(cur, customer_advance_id["id"], "ACTIVE")

    if send_message:
        background_tasks = BackgroundTasks()
        if advance_type.name in ["RL", "TA"]:
            rs_amount = f"INR {int(amount)}.00"
            expires_at = due_date.strftime("%d-%b-%Y")
            sms = f"We have successfully processed your payment of {rs_amount} for Advance Booking {advance_code}. Please note that your due date is {expires_at}. Thank you for choosing Regal Jewellers!"
            background_tasks.add_task(
                send_sms_background,
                async_pool,
                customer_address["phone_primary"],
                sms,
                "1107173026330934323",
            )
        elif advance_type.name == "SR":
            plan = "Swarna Raksha"
            rs_amount = f"INR {int(amount)}.00"
            sms = f"You have successfully made a payment of {rs_amount} for the {plan} plan ({advance_code}). Thank you for choosing Regal Jewellers!"
            background_tasks.add_task(
                send_sms_background,
                async_pool,
                customer_address["phone_primary"],
                sms,
                "1107174946921369132",
            )

    return customer_advance_id["id"]


# TODO customer check for 2 lakh per day has to be checked
async def create_payment_for_invoice(
    cur: AsyncCursor[DictRow],
    invoice: Invoice,
    total_rate: float,
    invoice_id: int,
    invoice_code: str,
    customer_id: int,
    branch_id: int | None = None,
    repurchase_id: int | None = None,
    sales_return_id: int | None = None,
    async_pool=None,
):
    branch_code = await get_branch_code(cur, branch_id)
    refunded_customer_advance_installment_id = None
    await if_cash_limit_exceeded(cur, customer_id, total_rate)

    refunded_customer_advance_id = None
    sales_return_deduction = (
        invoice.sales_return.draft_sales_return_data.total_sales_return_value
        if invoice.sales_return
        and invoice.sales_return.draft_sales_return_data
        and invoice.sales_return.draft_sales_return_data.total_sales_return_value
        else 0
    )
    customer_id = invoice.customer.customer_id
    transaction_group_ids = []
    chart_of_account_id_of_customer = await get_customer_chart_of_account_id(
        cur, customer_id
    )

    # Enforce the cash limit on this invoice's cash payment WITH clubbing
    # context: cash paid earlier on clubbed advances/plans and on the original
    # invoice of a clubbed sales return counts against the customer's limit for
    # the period this invoice falls in. The generic per-transaction check in
    # insert_into_transaction has no clubbing context, so it is checked here.
    cash_payment_total = sum(
        payment.amount
        for payment in invoice.payment_methods
        if payment.payment_method == "CASH"
    )
    if cash_payment_total > 0:
        sr_invoice_id, sr_value = _clubbed_sales_return_cash_args(invoice)
        now_ref = datetime.now()
        cash_balance = CustomerCashBalance(
            cur,
            customer_id,
            location_id=branch_id,
            clubbed_document_codes=[
                advance.advance_code for advance in invoice.customer_advances
            ],
            sales_return_invoice_id=sr_invoice_id,
            sales_return_value=sr_value,
        )
        await cash_balance.check_cash_kyc(cash_payment_total, now_ref)
        await cash_balance.check_monthly_cash_limit(cash_payment_total, now_ref)
        await cash_balance.check_fy_cash_limit(cash_payment_total, now_ref)

    if invoice.invoice_discount and invoice.invoice_discount.amount > 0:
        x, y, transaction_group_id = await insert_into_transaction(
            cur,
            invoice.invoice_discount.chart_of_account_id,
            chart_of_account_id_of_customer,
            invoice.invoice_discount.amount,
            "INVOICE",
            invoice_id,
            invoice_code,
        )
        transaction_group_ids.append(transaction_group_id)

    if invoice.sales_return_benefit:
        get_sales_return_code_query = """
        SELECT
            sales_return_code
        FROM
            sales_return
        WHERE
            id = %(sales_return_id)s
        """
        await cur.execute(
            get_sales_return_code_query, {"sales_return_id": sales_return_id}
        )
        sales_return_code = await cur.fetchone()
        sales_return_code = sales_return_code["sales_return_code"]
        x, y, transaction_group_id = await insert_into_transaction(
            cur,
            await get_chart_of_account_id(
                cur, f"{branch_code} - Sales Return Rate Difference"
            ),
            chart_of_account_id_of_customer,
            invoice.sales_return_benefit,
            "INVOICE",
            invoice_id,
            invoice_code,
        )
        transaction_group_ids.append(transaction_group_id)

    if invoice.rate_difference:
        for benefit in invoice.rate_difference:
            if benefit.amount != 0:
                x, y, transaction_group_id = await insert_into_transaction(
                    cur,
                    await get_chart_of_account_id(
                        cur, f"{branch_code} - Advance And Scheme RD"
                    ),
                    chart_of_account_id_of_customer,
                    benefit.amount,
                    "INVOICE",
                    invoice_id,
                    invoice_code,
                    "N/A",
                    benefit.customer_advance.advance_code,
                )
                transaction_group_ids.append(transaction_group_id)

    for advance in invoice.customer_advances:
        if advance.mc_benefit != 0:
            x, y, transaction_group_id = await insert_into_transaction(
                cur,
                await get_chart_of_account_id(
                    cur, f"{branch_code} - Advance And Scheme MC Benefit"
                ),
                chart_of_account_id_of_customer,
                advance.mc_benefit,
                "INVOICE",
                invoice_id,
                invoice_code,
                "N/A",
                advance.advance_code,
            )
            transaction_group_ids.append(transaction_group_id)

    if sales_return_deduction > 0:
        get_sales_return_code_query = """
        SELECT
            sales_return_code
        FROM
            sales_return
        WHERE
            id = %(sales_return_id)s
        """
        await cur.execute(
            get_sales_return_code_query, {"sales_return_id": sales_return_id}
        )
        sales_return_code = await cur.fetchone()
        sales_return_code = sales_return_code["sales_return_code"]
        transactions_group_sales_return = []
        sales_return_draft = invoice.sales_return.draft_sales_return_data

        x, y, transaction_group_id = await insert_into_transaction(
            cur,
            await get_chart_of_account_id(cur, f"{branch_code} - Sales Return"),
            chart_of_account_id_of_customer,
            sales_return_draft.sales_return_taxable_value,
            "SALES_RETURN",
            sales_return_id,
            sales_return_code,
        )
        transactions_group_sales_return.append(transaction_group_id)
        if sales_return_draft.igst:
            (
                _,
                _,
                transaction_group_id_to_sales_return_tax_igst,
            ) = await insert_into_transaction(
                cur,
                await get_chart_of_account_id(
                    cur, f"{branch_code} - Output Tax IGST 3%"
                ),
                chart_of_account_id_of_customer,
                sales_return_draft.igst_amount,
                "SALES_RETURN",
                sales_return_id,
                sales_return_code,
            )
            transactions_group_sales_return.append(
                transaction_group_id_to_sales_return_tax_igst
            )

        else:
            (
                _,
                _,
                transaction_group_id_to_sales_return_tax_cgst,
            ) = await insert_into_transaction(
                cur,
                await get_chart_of_account_id(
                    cur, f"{branch_code} - Output Tax CGST 1.5%"
                ),
                chart_of_account_id_of_customer,
                sales_return_draft.cgst_amount,
                "SALES_RETURN",
                sales_return_id,
                sales_return_code,
            )
            transactions_group_sales_return.append(
                transaction_group_id_to_sales_return_tax_cgst
            )

            (
                _,
                _,
                transaction_group_id_to_sales_return_tax_sgst,
            ) = await insert_into_transaction(
                cur,
                await get_chart_of_account_id(
                    cur, f"{branch_code} - Output Tax SGST 1.5%"
                ),
                chart_of_account_id_of_customer,
                sales_return_draft.sgst_amount,
                "SALES_RETURN",
                sales_return_id,
                sales_return_code,
            )
            transactions_group_sales_return.append(
                transaction_group_id_to_sales_return_tax_sgst
            )
        await insert_into_sr_transaction_group(
            cur, sales_return_id, transactions_group_sales_return
        )
        # advance_refund_transaction_groups.append(transaction_group_id)

    branch_code = await get_branch_code(cur, branch_id)
    if invoice.round_off_amount:
        x, y, transaction_group_id = await insert_into_transaction(
            cur,
            await get_chart_of_account_id(
                cur, f"{branch_code} - B2C Sales Rounding Off"
            ),
            chart_of_account_id_of_customer,
            abs(invoice.round_off_amount)
            if invoice.round_off_amount < 0
            else -(invoice.round_off_amount),
            "INVOICE",
            invoice_id,
            invoice_code,
        )
        transaction_group_ids.append(transaction_group_id)
        # advance_refund_transaction_groups.append(transaction_group_id)

    # if total_benefit_amount:
    #     x, y, transaction_group_id = await insert_into_transaction(
    #         cur,
    #         await get_chart_of_account_id(cur, f"{branch_code} - Benefits"),
    #         chart_of_account_id_of_customer,
    #         total_benefit_amount,
    #         "INVOICE",
    #         invoice_id,
    #         invoice_code,
    #     )
    #     transaction_group_ids.append(transaction_group_id)

    # Grouping product value based on product type
    grouped_types = defaultdict(int)
    for line_item in invoice.line_items:
        product_type = line_item.product_type_code
        amount = line_item.actual_product_value
        grouped_types[product_type] += amount

    # Insert negative entry to invoice product type
    grouped_types = dict(grouped_types)
    for product_type_data in grouped_types:
        product_type = product_type_data.replace(" ", "_").upper()
        sales_product_type = getattr(ProductChartOfAccounts, product_type)

        sales_product = f"{branch_code} - {sales_product_type}"

        x, y, transaction_group_id = await insert_into_transaction(
            cur,
            chart_of_account_id_of_customer,
            await get_chart_of_account_id(cur, sales_product),
            grouped_types[product_type_data],
            "INVOICE",
            invoice_id,
            invoice_code,
        )
        transaction_group_ids.append(transaction_group_id)
        # advance_refund_transaction_groups.append(transaction_group_id)

    customer_paid = 0
    for payment in invoice.payment_methods:
        if payment.payment_method == "EXPENSE":
            config = get_config()
            expense_repo = ExpenseRepository(conn=cur.connection)
            transaction_repo = TransactionRepository(conn=cur.connection)
            expense_service = ExpenseService(config, expense_repo, transaction_repo)
            get_user_id_of_employee_query = """
            SELECT user_id
            FROM employee
            WHERE id = %(employee_id)s
            """
            await cur.execute(
                get_user_id_of_employee_query,
                {"employee_id": invoice.created_by_employee_id},
            )
            user_id_of_employee = await cur.fetchone()
            created_by_user_id = user_id_of_employee["user_id"]
            expense_ids = await expense_service.create_expense(
                created_by_user_id,
                branch_id,
                ExpenseCreateRequest(
                    to_chart_of_account_id=payment.chart_of_account_id,
                    from_chart_of_account_id=chart_of_account_id_of_customer,
                    amount=payment.amount,
                    transaction_date=datetime.now(),
                    note=payment.reference,
                ),
            )

            insert_into_invoice_expense_query = """
            INSERT INTO invoice_expense
            (
                invoice_id,
                expense_id
            )
            VALUES
            (
                %(invoice_id)s,
                %(expense_id)s
            )
            """
            for i in expense_ids:
                await cur.execute(
                    insert_into_invoice_expense_query,
                    {"invoice_id": invoice_id, "expense_id": i["expense_id"]},
                )

        else:
            collection_code = await generate_collection_code(cur, branch_id)
            x, y, transaction_group_id = await insert_into_transaction(
                cur,
                payment.chart_of_account_id,
                chart_of_account_id_of_customer,
                payment.amount,
                "COLLECTION",
                invoice_id,
                collection_code,
                payment.payment_method,
                None,
                None,
                payment.reference,
                branch_id,
                getattr(payment, "account_holder_name", None),
                getattr(payment, "file_ids", None),
            )
            collection_id = await insert_into_invoice_collection(
                cur,
                invoice_id,
                customer_id,
                transaction_group_id,
                collection_code,
                "INVOICE",
                invoice_code,
            )

            update_transaction_group_query = """
            UPDATE transaction_group_document
            SET document_id = %(collection_id)s
            WHERE document_code = %(collection_code)s
            """
            await cur.execute(
                update_transaction_group_query,
                {"collection_id": collection_id, "collection_code": collection_code},
            )
            # advance_refund_transaction_groups.append(transaction_group_id)
        customer_paid += payment.amount

    # Round to paise before comparing: customer_paid accumulates float noise
    # (e.g. 551165.18 sums to 551165.1799999999), which would otherwise read as
    # an underpayment and wrongly demand a remaining-amount due date.
    if round(customer_paid, 2) < round(invoice.net_amount, 2):
        if not invoice.collection_reminder or not invoice.collection_reminder.due_date:
            raise BadRequestException("Please fill the remaining amount due date")
        insert_into_collection_reminder_query = """
        INSERT INTO customer_collection_reminder 
        (customer_id, due_date, amount)
        VALUES
        (%(customer_id)s, %(due_date)s, %(amount)s)
        returning ID
        """
        await cur.execute(
            insert_into_collection_reminder_query,
            {
                "customer_id": customer_id,
                "due_date": invoice.collection_reminder.due_date,
                "amount": (invoice.net_amount - customer_paid),
            },
        )
        customer_collection_reminder_id = await cur.fetchone()

        insert_into_invoice_collection_reminder_query = """
        INSERT INTO invoice_customer_collection_reminder 
        (customer_collection_reminder_id, invoice_id)
        VALUES
        (%(customer_collection_reminder_id)s, %(invoice_id)s)
        """
        await cur.execute(
            insert_into_invoice_collection_reminder_query,
            {
                "customer_collection_reminder_id": customer_collection_reminder_id[
                    "id"
                ],
                "invoice_id": invoice_id,
            },
        )

    if invoice.sales_return_discount and invoice.sales_return_discount.amount:
        sales_migration = f"{branch_code} - Sales Return Migration"

        x, y, transaction_group_id = await insert_into_transaction(
            cur,
            await get_chart_of_account_id(cur, sales_migration),
            chart_of_account_id_of_customer,
            invoice.sales_return_discount.amount,
            "INVOICE",
            invoice_id,
            invoice_code,
        )
        # advance_refund_transaction_groups.append(transaction_group_id)

    # This handles refund when the total value is -ve
    refund_transaction_groups = []
    if invoice.refund_methods:
        payment_methods = invoice.refund_methods

        get_location_chart_of_account_query = """
        SELECT chart_of_account_id
        FROM location_chart_of_account
        WHERE location_id = %(location_id)s AND account_type = 'CASH'
        """
        await cur.execute(
            get_location_chart_of_account_query, {"location_id": branch_id}
        )
        location_chart_id = await cur.fetchone()
        location_chart_id = location_chart_id["chart_of_account_id"]

        for method in payment_methods:
            # inserting payment based on payment method into transaction
            if method.method == "CASH":
                await check_daily_cash_refund_limit(cur, customer_id, method.amount)
                customer_chart_id = await get_customer_chart_id(cur, customer_id)
                customer_payment_code = await generate_customer_payment_code(
                    cur, branch_id
                )
                x, y, transaction_group_id = await insert_into_transaction(
                    cur,
                    customer_chart_id,
                    location_chart_id,
                    method.amount,
                    "CUSTOMER_PAYMENT",
                    invoice_id,
                    customer_payment_code,
                    "CASH",
                    method.note,
                    None,
                    method.transaction_number,
                )
                customer_payment_id = await insert_into_customer_payment(
                    cur,
                    customer_id,
                    transaction_group_id,
                    customer_payment_code,
                    invoice.created_by_employee_id,
                    "INVOICE",
                    invoice_code,
                    invoice_id,
                )
                insert_into_customer_payment_query = """ 
                INSERT INTO
                    invoice_customer_payment
                (
                    invoice_id,
                    customer_payment_id
                )
                VALUES
                (
                    %(invoice_id)s,
                    %(customer_payment_id)s
                )
                RETURNING id;
                """
                await cur.execute(
                    insert_into_customer_payment_query,
                    {
                        "invoice_id": invoice_id,
                        "customer_payment_id": customer_payment_id,
                    },
                )

                update_transaction_group_query = """
                UPDATE transaction_group_document
                SET document_id = %(customer_payment_id)s
                WHERE document_code = %(customer_payment_code)s
                """
                await cur.execute(
                    update_transaction_group_query,
                    {
                        "customer_payment_id": customer_payment_id,
                        "customer_payment_code": customer_payment_code,
                    },
                )
                refund_transaction_groups.append(transaction_group_id)

            if method.amount > 0 and method.method == "NEFT":
                for i in invoice.refund_methods:
                    if i.method == "NEFT":
                        await insert_into_refund_remainder(
                            cur,
                            i,
                            invoice_id,
                            method.amount,
                            invoice_code,
                            invoice.customer.customer_id,
                        )

            if method.method == "ADVANCE":
                (
                    refunded_customer_advance_id,
                    refunded_customer_advance_installment_id,
                ) = await make_customer_advance_without_payment(
                    cur,
                    method,
                    invoice,
                    # advance_refund_transaction_groups,
                    invoice.location.location_id,
                    async_pool=async_pool,
                )
    return (
        transaction_group_ids,
        # advance_refund_transaction_groups,
        refunded_customer_advance_id,
        refund_transaction_groups,
        refunded_customer_advance_installment_id,
    )


async def update_product_status(cur: AsyncCursor[DictRow], product_id: int):
    update_product_location_query = """
    UPDATE
            product_location
        SET
            end_time = now(),
            product_out_reason = 'SALES_B2C'
        WHERE
            product_id = %(product_id)s
            AND end_time='2100-01-01 00:00:00+00' 
    """

    await cur.execute(update_product_location_query, {"product_id": product_id})

    insert_into_product_location = """
    INSERT INTO product_location
    (
        product_id,
        location_id,
        end_time
    )
    VALUES
    (
        %(product_id)s,
        %(location_id)s,
        '2100-01-01 00:00:00+00'
    )
    """

    await cur.execute(
        insert_into_product_location,
        {
            "product_id": product_id,
            "location_id": None,
        },
    )


async def create_product(
    cur: AsyncCursor[DictRow],
    product: LineItem,
    invoice_id: int,
    branch_id: int,
    igst_bill: bool,
):
    # check if any metal is present for a product
    if not any(material.type == "METAL" for material in product.materials):
        raise BadRequestException(
            "At least one material of type 'METAL' is required for the product."
        )
    ##--fetching existing attributes from parent box item--##
    fetch_parent_product_attribute_values = """
    SELECT
        attribute_id,
        product_attribute_enum_value_id,
        type,
        value
    FROM
        product_attribute_value
    WHERE
        product_id=%(parent_product_id)s
    """
    await cur.execute(
        fetch_parent_product_attribute_values, {"parent_product_id": product.product_id}
    )
    parent_product_attributes = await cur.fetchall()

    create_product_query = """
                INSERT INTO product
                (
                    product_code,
                    product_name,
                    sales_va_percentage,
                    is_box,
                    piece_count,
                    touch_percentage,
                    is_barcoded,
                    parent_product_id
                    )
                VALUES
                (
                    %(product_code)s,
                    %(product_name)s,
                    %(sales_va_percentage)s,
                    FALSE,
                    %(piece_count)s,
                    %(touch_percentage)s,
                    FALSE,
                    %(parent_product_id)s
                )
                RETURNING ID;
                """
    product_code = "BOX_" + "".join(
        random.choices(string.ascii_uppercase + string.digits, k=8)
    )
    await cur.execute(
        create_product_query,
        {
            "product_code": product_code,
            "product_name": product.product_name,
            "sales_va_percentage": product.sales_va_percentage,
            "touch_percentage": product.touch_percentage,
            "parent_product_id": product.product_id,
            "piece_count": product.piece_count,
        },
    )
    product_id = await cur.fetchone()

    update_piece_count_query = """
        UPDATE product
        SET piece_count = piece_count - %(deduct_count)s
        WHERE id = %(product_id)s;
    """

    await cur.execute(
        update_piece_count_query,
        {"deduct_count": product.piece_count, "product_id": product.product_id},
    )

    insert_into_invoice_line_item_query = """
    INSERT INTO invoice_line_item
    (
        invoice_id,
        product_id,
        sales_va_percentage,
        product_value,
        discount_amount
    )
    VALUES
    (
        %(invoice_id)s,
        %(product_id)s,
        %(sales_va_percentage)s,
        %(product_value)s,
        %(discount_amount)s
    )
    RETURNING id
    """

    await cur.execute(
        insert_into_invoice_line_item_query,
        {
            "invoice_id": invoice_id,
            "product_id": product_id["id"],
            "sales_va_percentage": product.sales_va_percentage,
            "product_value": product.product_value,
            "discount_amount": product.discount_amount,
        },
    )
    created_invoice_line_item_id = await cur.fetchone()

    ##--Inserting components
    insert_into_invoice_line_component_value = """
    INSERT INTO invoice_line_item_component_value (invoice_line_item_id,line_item_component_id,value)
    VALUES (
        %(invoice_line_item_id)s,
        (SELECT id FROM line_item_component WHERE line_item_component_code=%(component_code)s),
        %(value)s
    )
    """
    ##--Inserting product value
    await cur.execute(
        insert_into_invoice_line_component_value,
        {
            "invoice_line_item_id": created_invoice_line_item_id["id"],
            "component_code": "PRV",
            "value": product.product_value,
        },
    )
    ##--Inserting discount value
    if product.discount_amount and product.discount_amount > 0:
        await cur.execute(
            insert_into_invoice_line_component_value,
            {
                "invoice_line_item_id": created_invoice_line_item_id["id"],
                "component_code": "DST",
                "value": product.discount_amount,
            },
        )

    ##--Inserting SR benefit
    if product.sales_return_benefit_amount and product.sales_return_benefit_amount != 0:
        await cur.execute(
            insert_into_invoice_line_component_value,
            {
                "invoice_line_item_id": created_invoice_line_item_id["id"],
                "component_code": "SRB_AMT",
                "value": product.sales_return_benefit_amount,
            },
        )

    ##--Inserting tax amounts
    if igst_bill:
        await cur.execute(
            insert_into_invoice_line_component_value,
            {
                "invoice_line_item_id": created_invoice_line_item_id["id"],
                "component_code": "IGST_AMT",
                "value": product.igst_amount,
            },
        )
    else:
        await cur.execute(
            insert_into_invoice_line_component_value,
            {
                "invoice_line_item_id": created_invoice_line_item_id["id"],
                "component_code": "SGST_AMT",
                "value": product.cgst_amount,
            },
        )
        await cur.execute(
            insert_into_invoice_line_component_value,
            {
                "invoice_line_item_id": created_invoice_line_item_id["id"],
                "component_code": "CGST_AMT",
                "value": product.sgst_amount,
            },
        )
    ##-- Inserting RD benefit
    if product.rd_benefit_amount and product.rd_benefit_amount != 0:
        await cur.execute(
            insert_into_invoice_line_component_value,
            {
                "invoice_line_item_id": created_invoice_line_item_id["id"],
                "component_code": "RDB_AMT",
                "value": product.rd_benefit_amount,
            },
        )

    ##-- Inserting MC benefit
    if product.mc_benefit_amount and product.mc_benefit_amount != 0:
        await cur.execute(
            insert_into_invoice_line_component_value,
            {
                "invoice_line_item_id": created_invoice_line_item_id["id"],
                "component_code": "MCB_AMT",
                "value": product.mc_benefit_amount,
            },
        )

    insert_into_invoice_line_item_material = """
    INSERT INTO invoice_line_item_material
    (
        invoice_line_item_id,
        product_material_id,
        rate
    )
    VALUES
    (
        %(invoice_line_item_id)s,
        %(product_material_id)s,
        %(rate)s
    )
    """

    insert_into_product_material_weight = """
    INSERT INTO product_material_weight
    (
        product_material_id,
        weight,
        quantity
        
    )
    VALUES
    (
        %(product_material_id)s,
        %(weight)s,
        %(quantity)s
    )
    RETURNING id
    """

    insert_weight_into_product_material_query = """
     INSERT INTO product_material
    (
        product_id,
        material_id
        
    )
    VALUES
    (
        %(product_id)s,
        %(material_id)s
    )
    Returning id
    """

    for material in product.materials:
        if material.weight == 0:
            raise BadRequestException("Material weight cannot be zero")
        get_material_id_from_code = """
        SELECT
            id
        FROM
            material
        WHERE
            material_code = %(material_code)s
        """
        await cur.execute(get_material_id_from_code, {"material_code": material.code})
        material_id = await cur.fetchone()

        await cur.execute(
            insert_weight_into_product_material_query,
            {
                "product_id": product_id["id"],
                "material_id": material_id["id"],
            },
        )
        product_material_id = await cur.fetchone()

        get_product_material_id_query = """
        SELECT
            id
        FROM
            product_material
        WHERE
            product_id = %(product_id)s
        AND
            material_id = %(material_id)s
        """
        await cur.execute(
            get_product_material_id_query,
            {"material_id": material_id["id"], "product_id": product.product_id},
        )
        old_product_material_id = await cur.fetchone()

        await cur.execute(
            insert_into_product_material_weight,
            {
                "product_material_id": old_product_material_id["id"],
                "weight": -material.weight,
                "quantity": -material.quantity,
            },
        )

        await cur.execute(
            insert_into_product_material_weight,
            {
                "product_material_id": product_material_id["id"],
                "weight": material.weight,
                "quantity": material.quantity,
            },
        )

        await cur.execute(
            insert_into_invoice_line_item_material,
            {
                "invoice_line_item_id": created_invoice_line_item_id["id"],
                "product_material_id": product_material_id["id"],
                "rate": material.rate,
            },
        )

    insert_into_product_location_previous_time = """
    INSERT INTO product_location
    (
        product_id,
        location_id,
        start_time,
        end_time,
        product_in_reason,
        product_out_reason
    )
    VALUES
    (
        %(product_id)s,
        %(location_id)s,
        %(time_start)s,
        %(time_end)s,
        'CONVERSION',
        'SALES_B2C'
    )
    """
    await cur.execute(
        insert_into_product_location_previous_time,
        {
            "product_id": product_id["id"],
            "location_id": branch_id,
            "time_start": datetime.now(),
            "time_end": datetime.now(),
        },
    )

    insert_into_product_location = """
    INSERT INTO product_location
    (
        product_id,
        location_id,
        end_time
    )
    VALUES
    (
        %(product_id)s,
        %(location_id)s,
        '2100-01-01 00:00:00+00'
    )
    """
    await cur.execute(
        insert_into_product_location,
        {"product_id": product_id["id"], "location_id": None},
    )

    insert_product_attribute_value = """
    INSERT INTO product_attribute_value (product_id,attribute_id,product_attribute_enum_value_id,type,value)
    VALUES (
        %(product_id)s,
        %(attribute_id)s,
        %(product_attribute_enum_value_id)s,
        %(type)s,
        %(value)s
        )
    """
    ##--inserting parent product attributes for new product--##
    if parent_product_attributes:
        params = []
        for attribute in parent_product_attributes:
            params.append(
                {
                    "product_id": product_id["id"],
                    "attribute_id": attribute["attribute_id"],
                    "product_attribute_enum_value_id": attribute[
                        "product_attribute_enum_value_id"
                    ],
                    "type": attribute["type"],
                    "value": attribute["value"],
                }
            )
        await cur.executemany(insert_product_attribute_value, params)
    else:
        raise BadRequestException(
            "Box item does not have required attributes to infer for inserting new product"
        )

    return created_invoice_line_item_id["id"]


async def check_product_weight_match_with_invoice_draft(
    cur: AsyncCursor[DictRow], payload: Invoice
):
    for product in payload.line_items:
        if not product.product_id:
            raise BadRequestException("Please complete the product")
        get_product_weight = """
            SELECT 
                SUM(pmw.weight) as total_weight
            FROM 
                product_material pm
            LEFT JOIN
                product_material_weight pmw on pmw.product_material_id = pm.id
            WHERE
                pm.product_id = %(product_id)s
            """
        await cur.execute(get_product_weight, {"product_id": product.product_id})
        product_weight = await cur.fetchone()
        product_weight = product_weight["total_weight"]
        total_weight_in_invoice = 0
        for weight in product.materials:
            total_weight_in_invoice += weight.weight
        if product.is_box:
            if product_weight < round(total_weight_in_invoice, 3):
                raise BadRequestException("Not enough Product weight found in box item")


async def check_product_exist_and_get_data(
    cur: AsyncCursor[DictRow], product_id: int, location_id: int
):
    get_product_data = """
    SELECT
        p.id,
        p.product_name,
        p.sales_va_percentage,
        p.piece_count,
        p.is_box,
        json_agg(
            json_build_object(
                'code', sub.material_code,
                'type', sub.type,
                'weight', sub.total_weight,
                'quantity', sub.total_quantity,
                'rate', sub.rate,
                'product_weight_id', sub.product_weight_id
            )
        ) AS material_details
    FROM 
        product p
    LEFT JOIN (
        SELECT 
            pw.product_id,
            m.material_code,
            m.type,
            SUM(pw.total_weight) AS total_weight,
            SUM(pw.quantity) AS total_quantity,
            AVG(mr.rate) AS rate,
            pw.id AS product_weight_id
        FROM
            product_weight pw
        LEFT JOIN
            material_rate mr ON mr.material_id = pw.material_id AND mr.end_time = '2100-01-01 00:00:00+00'
        LEFT JOIN 
            material m ON m.id = pw.material_id
        WHERE
            mr.location_id = %(branch_id)s
        GROUP BY
            pw.product_id, m.material_code, m.type, pw.id
    ) sub ON sub.product_id = p.id
    LEFT JOIN 
        product_location pl ON p.id = pl.product_id
    WHERE 
        p.id = %(product_id)s
    AND 
        pl.location_id = %(branch_id)s AND pl.end_time = '2100-01-01 00:00:00+00'
    GROUP BY
        p.id, p.product_name, p.sales_va_percentage, p.piece_count;
    """
    await cur.execute(
        get_product_data, {"product_id": product_id, "branch_id": location_id}
    )
    product = await cur.fetchone()
    if not product:
        raise BadRequestException("Product does not exist")
    else:
        return product


async def check_product_exist(cur: AsyncCursor[DictRow], product_id: int):
    check_product_exist_query = """
    SELECT
        p.id
    FROM
        product p
    LEFT JOIN
        product_location pl on pl.product_id = p.id AND pl.end_time = '2100-01-01 00:00:00+00'
    WHERE
        p.id = %(product_id)s AND pl.location_id IS NOT NULL
    """
    await cur.execute(check_product_exist_query, {"product_id": product_id})
    product = await cur.fetchone()
    if not product:
        raise BadRequestException("Product does not exist")
    else:
        return product


async def insert_invoice_line_items(
    cur: AsyncCursor[DictRow],
    payload: Invoice,
    invoice_id: int,
    branch_id: int,
    igst_bill: bool,
):
    insert_into_line = """
                INSERT INTO invoice_line_item
                (
                    invoice_id,
                    product_id,
                    sales_va_percentage,
                    product_value,
                    discount_amount
                )
                VALUES
                (
                    %(invoice_id)s,
                    %(product_id)s,
                    %(sales_va_percentage)s,
                    %(product_value)s,
                    %(discount_amount)s

                )
                RETURNING ID
            """
    products = payload.line_items

    await check_product_weight_match_with_invoice_draft(cur, payload)

    for product in products:
        # ---  Clear reservation for product ID ---
        await cur.execute(
            "DELETE FROM reservation_box_product WHERE product_id = %s",
            (product.product_id,),
        )

        # await check_product_is_in_transfer(cur, product.product_id)
        await check_product_exist(cur, product.product_id)
        # product_data = await check_product_exist_and_get_data(
        #     cur, product.product_id, payload.location.location_id
        # )
        if not product.is_box:
            await cur.execute(
                insert_into_line,
                {
                    "invoice_id": invoice_id,
                    "product_id": product.product_id,
                    "sales_va_percentage": product.sales_va_percentage,
                    "product_value": product.product_value,
                    "discount_amount": product.discount_amount,
                },
            )
            line_item_id = await cur.fetchone()

            ##--Inserting components
            insert_into_invoice_line_component_value = """
            INSERT INTO invoice_line_item_component_value (invoice_line_item_id,line_item_component_id,value)
            VALUES (
                %(invoice_line_item_id)s,
                (SELECT id FROM line_item_component WHERE line_item_component_code=%(component_code)s),
                %(value)s
            )
            """
            ##--Inserting product value
            await cur.execute(
                insert_into_invoice_line_component_value,
                {
                    "invoice_line_item_id": line_item_id["id"],
                    "component_code": "PRV",
                    "value": product.product_value,
                },
            )
            ##--Inserting discount value
            if product.discount_amount and product.discount_amount > 0:
                await cur.execute(
                    insert_into_invoice_line_component_value,
                    {
                        "invoice_line_item_id": line_item_id["id"],
                        "component_code": "DST",
                        "value": product.discount_amount
                        + product.invoice_discount.amount,
                    },
                )

            ##--Inserting SR benefit
            if (
                product.sales_return_benefit_amount
                and product.sales_return_benefit_amount != 0
            ):
                await cur.execute(
                    insert_into_invoice_line_component_value,
                    {
                        "invoice_line_item_id": line_item_id["id"],
                        "component_code": "SRB_AMT",
                        "value": product.sales_return_benefit_amount,
                    },
                )

            ##-- Inserting RD benefit
            if product.rd_benefit_amount and product.rd_benefit_amount != 0:
                await cur.execute(
                    insert_into_invoice_line_component_value,
                    {
                        "invoice_line_item_id": line_item_id["id"],
                        "component_code": "RDB_AMT",
                        "value": product.rd_benefit_amount,
                    },
                )

            ##-- Inserting MC benefit
            if product.mc_benefit_amount and product.mc_benefit_amount != 0:
                await cur.execute(
                    insert_into_invoice_line_component_value,
                    {
                        "invoice_line_item_id": line_item_id["id"],
                        "component_code": "MCB_AMT",
                        "value": product.mc_benefit_amount,
                    },
                )
            ##--Inserting tax amounts
            if igst_bill:
                await cur.execute(
                    insert_into_invoice_line_component_value,
                    {
                        "invoice_line_item_id": line_item_id["id"],
                        "component_code": "IGST_AMT",
                        "value": product.igst_amount,
                    },
                )
            else:
                await cur.execute(
                    insert_into_invoice_line_component_value,
                    {
                        "invoice_line_item_id": line_item_id["id"],
                        "component_code": "SGST_AMT",
                        "value": product.cgst_amount,
                    },
                )
                await cur.execute(
                    insert_into_invoice_line_component_value,
                    {
                        "invoice_line_item_id": line_item_id["id"],
                        "component_code": "CGST_AMT",
                        "value": product.sgst_amount,
                    },
                )

            insert_into_line_item_material = """
                INSERT INTO invoice_line_item_material
                (
                    invoice_line_item_id,
                    product_material_id,
                    rate
                
                )
                VALUES
                (
                    %(invoice_line_item_id)s,
                    %(product_material_id)s,
                    %(rate)s
                )
                """

            await update_product_status(cur, product.product_id)

            line_items = product.materials
            for line_item_info in line_items:
                await cur.execute(
                    insert_into_line_item_material,
                    {
                        "invoice_line_item_id": line_item_id["id"],
                        "product_material_id": line_item_info.product_material_id,
                        "rate": line_item_info.rate,
                    },
                )
            line_item_id = line_item_id["id"]
        else:
            if product.is_box:
                line_item_id = await create_product(
                    cur, product, invoice_id, branch_id, igst_bill
                )

        insert_into_invoice_line_item_discount_query = """
        INSERT INTO invoice_line_item_discount
        (
            invoice_line_item_id,
            amount,
            discount_chart_of_account_id
        )
        VALUES
        (
            %(invoice_line_item_id)s,
            %(amount)s,
            %(discount_chart_of_account_id)s
        )
        """
        if product.invoice_discount.amount:
            await cur.execute(
                insert_into_invoice_line_item_discount_query,
                {
                    "invoice_line_item_id": line_item_id,
                    "amount": product.invoice_discount.amount
                    if product.invoice_discount
                    else 0,
                    "discount_chart_of_account_id": payload.invoice_discount.chart_of_account_id
                    if payload.invoice_discount and payload.invoice_discount
                    else None,
                },
            )


async def insert_and_check_plans(
    cur: AsyncCursor[DictRow],
    invoice_id: int,
    customer_advances: List[CustomerAdvance],
    branch_id: int,
    payload: Invoice,
):
    check_customer_plan_query = """
            SELECT NOT EXISTS (
                SELECT 1
                FROM customer_plan_status
                WHERE customer_plan_id = ANY(%(customer_plan_ids)s)
                AND status != 'CLOSED' 
                AND end_time = '2100-01-01 00:00:00+00'
            )as all_present;
            """
    customer_plan_ids = [
        i.advance_id
        for i in customer_advances
        if i.type in SCHEMELIST and not i.is_sales_return_plan
    ]
    if len(customer_plan_ids) > 0:
        await cur.execute(
            check_customer_plan_query, {"customer_plan_ids": customer_plan_ids}
        )
        check_plan = await cur.fetchone()

        if not check_plan["all_present"]:
            raise BadRequestException("Customer Plans Doesnt Exist  Or Not Closed")

    # Verify each plan's code in the draft still matches the DB before redeeming,
    # so a stale or mismatched plan id cannot silently redeem the wrong customer_plan.
    verify_plan_code_query = """
        SELECT customer_plan_code
        FROM customer_plan
        WHERE id = %(customer_plan_id)s
    """
    for plan in payload.customer_advances:
        if plan.type in SCHEMELIST and not plan.is_sales_return_plan:
            await cur.execute(
                verify_plan_code_query, {"customer_plan_id": plan.advance_id}
            )
            plan_code_row = await cur.fetchone()
            if plan_code_row is None:
                raise BadRequestException(
                    f"Customer Plan does not exist for id {plan.advance_id}"
                )
            if plan_code_row["customer_plan_code"] != plan.advance_code:
                raise BadRequestException(
                    f"Customer Plan code mismatch for id {plan.advance_id}: "
                    f"draft has {plan.advance_code}, "
                    f"database has {plan_code_row['customer_plan_code']}"
                )

    for plan in payload.customer_advances:
        if plan.type in SCHEMELIST and not plan.is_sales_return_plan:
            insert_into_customer_plan_query = """
                    INSERT INTO invoice_customer_plan
                    (
                        invoice_id,
                        customer_plan_id
                    )
                    VALUES
                    (
                        %(invoice_id)s,
                        %(customer_plan_id)s
                    )
                    """

            if plan.status == "MATURED":
                await cur.execute(
                    insert_into_customer_plan_query,
                    {"invoice_id": invoice_id, "customer_plan_id": plan.advance_id},
                )
            else:
                await cur.execute(
                    insert_into_customer_plan_query,
                    {"invoice_id": invoice_id, "customer_plan_id": plan.advance_id},
                )

            change_end_time_plan = """
                UPDATE
                    customer_plan_status
                SET
                    end_time = now()
                    
                WHERE
                    customer_plan_id = %(customer_plan_id)s
                    AND end_time='2100-01-01 00:00:00+00'

            """

            await cur.execute(
                change_end_time_plan, {"customer_plan_id": plan.advance_id}
            )
            update_customer_plan_status_query = """
                INSERT INTO customer_plan_status
                (
                    customer_plan_id,
                    status,
                    location_id
                    
                    
                )
                VALUES
                (   
                    %(customer_plan_id)s,
                    %(status)s,
                    %(location_id)s
                    
                    
                )
                            """

            await cur.execute(
                update_customer_plan_status_query,
                {
                    "customer_plan_id": plan.advance_id,
                    "status": "BILLED",
                    "location_id": branch_id,
                },
            )

    # update_invoice_scheme_amount_and_benefit_amounts = """
    # UPDATE invoice
    # SET
    #     scheme_amount=%(scheme_amount)s,
    #     scheme_benefit_amount=%(scheme_benefit_amount)s
    # WHERE
    #     id=%(invoice_id)s
    # """
    # await cur.execute(
    #     update_invoice_scheme_amount_and_benefit_amounts,
    #     {
    #         "invoice_id": invoice_id,
    #         "scheme_amount": payload.total_scheme_amount
    #         if payload.total_scheme_amount
    #         else 0,
    #         "scheme_benefit_amount": payload.customer_plan_benefit_amount
    #         if payload.customer_plan_benefit_amount
    #         else 0,
    #     },
    # )


async def insert_and_check_advance(
    cur: AsyncCursor[DictRow], customer_plan_advances: List[CustomerAdvance]
):
    check_customer_advance_query = """
            SELECT EXISTS (
                SELECT 1
                FROM customer_advance_status
                WHERE customer_advance_id = ANY(%(customer_plan_advance_ids)s)
                AND status != 'BILLED' 
                AND end_time = '2100-01-01 00:00:00+00'
            ) AS all_present;
            """
    customer_plan_ids = [
        i.advance_id
        for i in customer_plan_advances
        if i.is_advance and i.type in ADVANCELIST and not i.is_sales_return_plan
    ]
    if len(customer_plan_ids) > 0:
        await cur.execute(
            check_customer_advance_query,
            {"customer_plan_advance_ids": customer_plan_ids},
        )
        check_advance = await cur.fetchone()
        if not check_advance["all_present"]:
            raise BadRequestException("Customer Advance Doesnt Exist Or Not Closed")

    getting_basic_details_from_advance = """
        SELECT
            cat.term_amount,
            advance_type,
            cat.expires_at,
            location_id,
            cat.g22_rate,
            ca.sales_person_employee_id,
            cat.mature_at,
            ca.created_at,
            ca.joined_at,
            cat.weight,
            cat.weight_type
        FROM
            customer_advance ca
        LEFT JOIN (
            SELECT
                agg.customer_advance_id,
                agg.amount as term_amount,
                li.g22_rate,
                agg.weight,
                li.weight_type,
                li.expires_at,
                li.mature_at
            FROM (
                SELECT
                    customer_advance_id,
                    SUM(amount) AS amount,
                    MAX(id) AS latest_installment_id,
                    SUM(weight) AS weight
                FROM
                    customer_advance_installment
                GROUP BY
                    customer_advance_id
            ) agg
            JOIN customer_advance_installment li
                ON li.id = agg.latest_installment_id
        ) cat ON cat.customer_advance_id = ca.id
        WHERE ca.id=%(customer_advance_id)s
    """
    insert_into_customer_advance_installment = """
        INSERT INTO customer_advance_installment
        (   
            customer_advance_id,
            weight,
            amount,
            weight_type,
            g22_rate,
            mature_at,
            expires_at,
            created_by_employee_id
            
        )
        VALUES
        (   
            %(customer_advance_id)s,
            %(weight)s,
            %(amount)s,
            %(weight_type)s,
            %(g22_rate)s,
            %(mature_at)s,
            %(expires_at)s,
            %(created_by_employee_id)s
        )
        RETURNING ID;
    """
    newly_created_installment_ids = []
    for advance in customer_plan_advances:
        ##- Advances carried over from the original invoice of a clubbed sales
        ##- return are display-only (zero rate difference) and were already
        ##- redeemed on that invoice - never re-redeem them here.
        if (
            advance.is_advance
            and advance.type in ADVANCELIST
            and not advance.is_sales_return_plan
        ):
            ##- Direct clubbing
            if not advance.partial_clubbing:
                await cur.execute(
                    getting_basic_details_from_advance,
                    {"customer_advance_id": advance.advance_id},
                )
                advance_details = await cur.fetchone()

                await cur.execute(
                    insert_into_customer_advance_installment,
                    {
                        "customer_advance_id": advance.advance_id,
                        "weight": -advance_details["weight"],
                        "amount": -advance_details["term_amount"],
                        "weight_type": advance_details["weight_type"],
                        "g22_rate": advance_details["g22_rate"],
                        "mature_at": advance_details["mature_at"],
                        "expires_at": advance_details["expires_at"],
                        "created_by_employee_id": None,
                    },
                )
                negating_customer_advance_installment_id = await cur.fetchone()
                newly_created_installment_ids.append(
                    negating_customer_advance_installment_id["id"]
                )

                await update_customer_advance_status(cur, advance.advance_id, "BILLED")
            else:
                ##- Partial clubbing logic
                await cur.execute(
                    getting_basic_details_from_advance,
                    {"customer_advance_id": advance.advance_id},
                )
                advance_details = await cur.fetchone()

                if (
                    advance_details["term_amount"] < advance.amount
                    or advance_details["weight"] < advance.weight
                ):
                    raise BadRequestException(
                        f"Amount or weight not availabe in advance {advance.advance_code}"
                    )

                clubbing_advance_transaction_groups = []

                await cur.execute(
                    insert_into_customer_advance_installment,
                    {
                        "customer_advance_id": advance.advance_id,
                        "weight": -advance.weight if advance.weight else 0,
                        "amount": -advance.amount if advance.amount else 0,
                        "weight_type": advance_details["weight_type"],
                        "g22_rate": advance_details["g22_rate"],
                        "mature_at": advance_details["mature_at"],
                        "expires_at": advance_details["expires_at"],
                        "created_by_employee_id": None,
                    },
                )
                negating_customer_advance_installment_id = await cur.fetchone()
                newly_created_installment_ids.append(
                    negating_customer_advance_installment_id["id"]
                )
                attaching_transaction_groups = """
                INSERT INTO customer_advance_installment_transaction_group (
                    customer_advance_installment_id,
                    transaction_group_id
                )
                VALUES (
                    %(customer_advance_installment_id)s,
                    %(transaction_group_id)s
                )
                """
                for transaction_group in clubbing_advance_transaction_groups:
                    await cur.execute(
                        attaching_transaction_groups,
                        {
                            "customer_advance_installment_id": negating_customer_advance_installment_id[
                                "id"
                            ],
                            "transaction_group_id": transaction_group,
                        },
                    )

    return newly_created_installment_ids


async def insert_into_invoice_repurchase(
    cur: AsyncCursor[DictRow], payload: Invoice, invoice_id: int
):
    insert_into_invoice_repurchase = """
    INSERT INTO invoice_repurchase
        repurchase_id,
        invoice_id
    VALUES
    (
        %(repurchase_id)s,
        %(invoice_id)s
    )
    """
    sales_return__data_to_insert = [
        {"invoice_id": invoice_id, "repurchase_id": id} for id in payload.repurchase_id
    ]
    await cur.execute(insert_into_invoice_repurchase, sales_return__data_to_insert)


async def delete_draft_invoice(cur: AsyncCursor[DictRow], draft_invoice_id: int):
    delete_draft_invoice_query = """
    DELETE FROM
        draft_form
    WHERE
        id = %(draft_invoice_id)s
    """
    await cur.execute(
        delete_draft_invoice_query, {"draft_invoice_id": draft_invoice_id}
    )
    return {"message": "Draft Invoice Deleted Successfully"}


async def get_weight_id(
    cur: AsyncCursor[DictRow],
    material_code: str,
    product_id: int,
    quantity: int,
    weight: float,
):
    get_material_id_query = """
    SELECT
        id
    FROM
        material
    WHERE
        material_code = %(material_code)s
    """
    await cur.execute(get_material_id_query, {"material_code": material_code})
    material_id = await cur.fetchone()

    insert_into_product_weight_query = """
    INSERT INTO product_weight
    (
        product_id,
        total_weight,
        material_id,
        quantity
    )
    VALUES
    (
        %(product_id)s,
        %(total_weight)s,
        %(material_id)s,
        %(quantity)s
    )
    
    RETURNING ID;
    
    """
    await cur.execute(
        insert_into_product_weight_query,
        {
            "product_id": product_id,
            "total_weight": weight,
            "material_id": material_id["id"],
            "quantity": quantity,
        },
    )
    weight_id = await cur.fetchone()
    return weight_id["id"]


async def insert_repurchase(
    cur: AsyncCursor[DictRow], invoice_data: Invoice, repurchase_draft_id: int
):
    get_repurchase_data__query = """
    SELECT
        json_data as repurchase_data
    FROM
        draft_form
    WHERE
        id = %(repurchase_draft_id)s
    """
    await cur.execute(
        get_repurchase_data__query, {"repurchase_draft_id": repurchase_draft_id}
    )
    repurchase_data = await cur.fetchone()
    if not repurchase_data:
        raise BadRequestException("Repurchase draft not found")
    if (
        not invoice_data.sales_person_employee_id
        or not invoice_data.customer.customer_id
    ):
        raise BadRequestException("Sales Details Not Found")

    repurchase_code = await generate_document_code(
        cur, REPURCHASE_CODE_CONFIG, location_id=invoice_data.location.location_id
    )
    repurchase_code_latest = {"repurchase_code": repurchase_code}
    try:
        repurchase_data["repurchase_data"]["sales_details"] = {}
        repurchase_data["repurchase_data"]["sales_details"]["customer_id"] = (
            invoice_data.customer.customer_id
        )
        repurchase_data["repurchase_data"]["sales_details"][
            "salesperson_employee_id"
        ] = invoice_data.sales_person_employee_id
        repurchase = RepurchaseCreation.model_validate(
            {
                **repurchase_data["repurchase_data"]["sales_details"],
                **repurchase_data["repurchase_data"],
                **repurchase_code_latest,
            }
        )

    except ValidationError as e:
        raise_if_missing_fields(e)

    insert_into_repurchase_query = """
    INSERT INTO repurchase
    (
        customer_id,
        salesperson_employee_id,
        repurchase_code,
        created_by_employee_id,
        location_id,
        note
    )           
    VALUES
    (
        %(customer_id)s,
        %(salesperson_employee_id)s,
        %(repurchase_code)s,
        %(created_by_employee_id)s,
        %(location_id)s,
        %(note)s
    )
    RETURNING ID
    """
    await cur.execute(insert_into_repurchase_query, repurchase.to_dict())

    repurchase_id = await cur.fetchone()
    try:
        repurchase_line_items: List[RepurchaseLineItemCreation] = [
            RepurchaseLineItemCreation.model_validate(
                {**item, **{"repurchase_id": repurchase_id["id"]}}
            )
            for item in repurchase_data["repurchase_data"]["line_items"]
        ]
    except ValidationError as e:
        raise_if_missing_fields(e)

    chart_of_account_id_of_customer = await get_customer_chart_of_account_id(
        cur, repurchase_data["repurchase_data"]["sales_details"]["customer_id"]
    )
    transaction_group_ids = []
    repurchase_line_item_ids = []

    grouped_types = defaultdict(int)
    branch_code = await get_branch_code(
        cur, repurchase_data["repurchase_data"]["location_id"]
    )
    for item in repurchase_line_items:
        get_product_type_query = """
        SELECT 
            paev.value
        FROM product_template_attribute_value ptav
        JOIN product_attribute_enum_value paev on paev.id=ptav.product_attribute_enum_value_id
        JOIN product_attribute pa on pa.id=ptav.product_attribute_id
        WHERE pa.attribute_code='TYP' and ptav.product_template_id= %(product_template_id)s
        """
        await cur.execute(
            get_product_type_query, {"product_template_id": item.product_template_id}
        )
        product_attribute_enum_value = (await cur.fetchone())["value"]

        product_type = product_attribute_enum_value
        amount = item.total_value
        grouped_types[product_type] += amount

        try:
            line_item_materials: List[RepurchaseMaterialCreation] = [
                RepurchaseMaterialCreation.model_validate(material)
                for material in item.materials
            ]
        except ValidationError as e:
            raise_if_missing_fields(e)
        if item.gross_weight != (
            round(sum([material.weight for material in line_item_materials]), 3)
        ):
            raise BadRequestException(
                "Gross weight doesnot match with metal weight and stone weight"
            )

        if not item.touch_percentage:
            raise BadRequestException("Required Touch Percentage")

        material_list = [material.type for material in line_item_materials]
        if "STONE" in material_list:
            if "METAL" not in material_list:
                raise BadRequestException("Stone items needs metals")
        insert_into_product = """
            INSERT INTO product
            (
                product_code,
                product_name,
                piece_count,
                sales_va_percentage,
                touch_percentage,
                is_barcoded
            
            )
            VALUES
            (
                %(product_code)s,
                %(product_name)s,
                %(piece_count)s,
                %(sales_va_percentage)s,
                %(touch_percentage)s,
                %(is_barcoded)s
            
            )
            RETURNING ID;
        """
        product_code = await get_product_creation_code()

        await cur.execute(
            insert_into_product,
            {
                "product_code": product_code,
                "product_name": item.line_item_name,
                "piece_count": 1,
                "sales_va_percentage": 0.0,
                "touch_percentage": item.touch_percentage,
                "is_barcoded": False,
            },
        )
        product_id = (await cur.fetchone())["id"]
        # --inserting attributes set for templates--##
        fixed_template_attributes = await fetch_product_template_attributes(
            cur, item.product_template_id
        )
        if fixed_template_attributes:
            await insert_product_attribute_value(
                cur, product_id, fixed_template_attributes
            )
        else:
            raise BadRequestException(
                "Template does not have required attributes to create new product"
            )

        insert_into_repurchase_line_item_query = """
        INSERT INTO repurchase_line_item
        (
            product_id,
            repurchase_id,
            less_percentage,
            total_weight,
            metal_amount,
            stone_amount,
            total_value

        )
        VALUES
        (
            %(product_id)s,
            %(repurchase_id)s,
            %(less_percentage)s,
            %(total_weight)s,
            %(metal_amount)s,
            %(stone_amount)s,
            %(total_value)s
        )
        RETURNING ID;
        """
        await cur.execute(
            insert_into_repurchase_line_item_query,
            {
                "product_id": product_id,
                "repurchase_id": item.repurchase_id,
                "less_percentage": item.less_percentage,
                "total_weight": item.gross_weight,
                "metal_amount": item.metal_amount,
                "stone_amount": item.stone_amount,
                "total_value": item.total_value,
            },
        )
        repurchase_line_item_id = (await cur.fetchone())["id"]
        repurchase_line_item_ids.append(repurchase_line_item_id)

        insert_product_location = """
        INSERT INTO product_location (product_id,location_id,product_in_reason)
        VALUES (
            %(product_id)s,
            %(location_id)s,
            %(product_in_reason)s
        )
        """
        await cur.execute(
            insert_product_location,
            {
                "product_id": product_id,
                "location_id": repurchase.location_id,
                "product_in_reason": "REPURCHASE",
            },
        )

        for material in line_item_materials:
            get_material_id_query = """
            SELECT 
                id 
            FROM 
                material 
            WHERE 
                material_code = %(material_code)s;
            """
            await cur.execute(get_material_id_query, {"material_code": material.code})
            material_id = (await cur.fetchone())["id"]

            insert_into_product_material_query = """
            INSERT INTO product_material
            (
                product_id,
                material_id
    
            )
            VALUES
            (
                %(product_id)s,
                %(material_id)s
            )
            RETURNING ID;
            """
            await cur.execute(
                insert_into_product_material_query,
                {
                    "material_id": material_id,
                    "product_id": product_id,
                },
            )
            product_material_id = (await cur.fetchone())["id"]
            insert_into_product_weight_query = """
            INSERT INTO product_material_weight
            (   
                product_material_id,
                quantity,
                weight
                
    
            )
            VALUES
            (
                %(product_material_id)s,
                %(quantity)s,
                %(weight)s
            )
            RETURNING ID;
            """
            await cur.execute(
                insert_into_product_weight_query,
                {
                    **material.model_dump(),
                    **{"product_material_id": product_material_id},
                },
            )

            insert_into_line_item_rate_query = """
            INSERT INTO repurchase_line_item_material
            (

                repurchase_line_item_id,
                rate,
                product_material_id
            )
            VALUES
            (
                %(repurchase_line_item_id)s,
                %(rate)s,
                %(product_material_id)s

            )
            """
            await cur.execute(
                insert_into_line_item_rate_query,
                {
                    "repurchase_line_item_id": repurchase_line_item_id,
                    "rate": material.rate,
                    "product_material_id": product_material_id,
                },
            )

    ##-- Inserting transactions
    grouped_types = dict(grouped_types)
    for type_data in grouped_types:
        product_attribute_enum_value = type_data.replace(" ", "_").upper()
        repurchase_product_type = getattr(
            RepurchaseProductChartAccounts, product_attribute_enum_value
        )
        repurchase_product = f"{branch_code} - {repurchase_product_type}"

        _, _, transaction_group_id = await insert_into_transaction(
            cur,
            await get_chart_of_account_id(cur, repurchase_product),
            chart_of_account_id_of_customer,
            grouped_types[type_data],
            "REPURCHASE",
            repurchase_id["id"],
            repurchase_code_latest["repurchase_code"],
        )
        transaction_group_ids.append(transaction_group_id)

    insert_into_repurchase_transaction_query = """
    INSERT INTO repurchase_transaction_group
    (repurchase_id, transaction_group_id)
    VALUES
    (%(repurchase_id)s, %(transaction_group_id)s)
    """
    for i in transaction_group_ids:
        await cur.execute(
            insert_into_repurchase_transaction_query,
            {"repurchase_id": repurchase_id["id"], "transaction_group_id": i},
        )

    insert_into_repurchase_status = """
        INSERT INTO repurchase_status
        (
            repurchase_id,
            status
        
        )
        VALUES
        (
            %(repurchase_id)s,
            %(status)s
        )
    """
    await cur.execute(
        insert_into_repurchase_status,
        {"repurchase_id": repurchase_id["id"], "status": "CLOSED"},
    )

    # delete_repurchase_data__query = """
    #     DELETE FROM
    #         draft_form
    #     WHERE
    #         id = %(repurchase_draft_id)s
    #     """
    # await cur.execute(
    #     delete_repurchase_data__query,
    #     {"repurchase_draft_id": repurchase_draft_id},
    # )
    return repurchase_id, transaction_group_ids, repurchase_line_item_ids


async def insert_sales_return(
    cur: AsyncCursor[DictRow],
    sales_return_draft_id: int,
    user_id: int,
    user_branch_id: int,
):
    employee_id = await get_employee_id(cur, user_id)
    get_sales_return_draft_query = """
    SELECT 
        json_data
    FROM
        draft_form
    WHERE
        id = %(sales_return_draft_id)s AND form_type = 'SALES_RETURN'
    """
    await cur.execute(
        get_sales_return_draft_query, {"sales_return_draft_id": sales_return_draft_id}
    )
    draft_data = await cur.fetchone()
    validated_data = SalesReturn.model_validate(draft_data["json_data"])

    if not validated_data.sales_return_products:
        raise BadRequestException("At least one product is required in sales return")

    get_invoice_id_query = """
    SELECT 
        id,
        location_id,
        scheme_benefit_amount,
        advance_benefit_amount
    FROM 
        invoice 
    WHERE 
        invoice_code = %(invoice_code)s
    """
    await cur.execute(
        get_invoice_id_query, {"invoice_code": validated_data.invoice_code}
    )
    sales_return_invoice_id = await cur.fetchone()

    returned_product_ids = []
    for i in validated_data.sales_return_products:
        returned_product_ids.append(i.product_id)

    taxable_value = validated_data.total_sales_return_value

    create_sales_return_query = """
    INSERT INTO sales_return
    (
        sales_return_code,
        invoice_id,
        note,
        created_by_employee_id,
        salesperson_employee_id,
        location_id
        
    )
    VALUES (
        %(sales_return_code)s,
        %(invoice_id)s,
        %(note)s,
        %(created_by_employee_id)s,
        %(salesperson_employee_id)s,
        %(location_id)s
        
    ) 
    RETURNING id
    """
    employee_id = await get_employee_id(cur, user_id)
    sales_return_code = await generate_sales_return_code(cur, user_branch_id)
    await cur.execute(
        create_sales_return_query,
        {
            "sales_return_code": sales_return_code,
            "invoice_id": sales_return_invoice_id["id"],
            "note": validated_data.note if validated_data.note else "None",
            "created_by_employee_id": employee_id,
            "salesperson_employee_id": validated_data.salesperson_employee_id,
            "location_id": user_branch_id,
        },
    )
    sales_return_data = await cur.fetchone()

    create_sales_return_status_query = """
    INSERT INTO sales_return_status
    (
        sales_return_id,status
    )
    VALUES (
        %(sales_return_id)s,
        'PAID'
    )
    """
    await cur.execute(
        create_sales_return_status_query,
        {"sales_return_id": sales_return_data["id"]},
    )

    # get invoice_data
    for item in validated_data.sales_return_products:
        get_invoice_line_item_data_query = """
        SELECT
            ili.id
        From
            invoice_line_item ili
        LEFT JOIN
            product p on p.id = ili.product_id
        WHERE
            p.product_code = %(product_code)s and ili.invoice_id = %(invoice_id)s
        """
        await cur.execute(
            get_invoice_line_item_data_query,
            {
                "product_code": item.product_code,
                "invoice_id": sales_return_invoice_id["id"],
            },
        )
        invoice_line_item_data = await cur.fetchall()
        if not invoice_line_item_data:
            raise BadRequestException("Product not found in invoice for sales return")

        # make product unsold

        get_product_id_query = """
        SELECT
            id
        FROM
            product
        WHERE
            product_code = %(product_code)s
        """
        await cur.execute(get_product_id_query, {"product_code": item.product_code})
        product_id = await cur.fetchone()

        update_product_location = """
        UPDATE
            product_location
        SET
            end_time = now()
        WHERE
            product_id = %(product_id)s
            AND end_time='2100-01-01 00:00:00+00';
            
        """
        await cur.execute(update_product_location, {"product_id": product_id["id"]})

        insert_product_location = """
        INSERT INTO product_location
        (
            product_id,
            location_id,
            product_in_reason
        )
        VALUES
        (
            %(product_id)s,
            %(location_id)s,
            'SALES_RETURN'

        );
        """

        await cur.execute(
            insert_product_location,
            {
                "product_id": product_id["id"],
                "location_id": user_branch_id,
            },
        )

        for item in invoice_line_item_data:
            insert_into_sales_return_line_item_query = """
            INSERT INTO sales_return_line_item
            (
                sales_return_id,
                invoice_line_item_id
            )
            VALUES
            (
                %(sales_return_id)s,
                %(invoice_line_item_id)s
            )
            """
            await cur.execute(
                insert_into_sales_return_line_item_query,
                {
                    "sales_return_id": sales_return_data["id"],
                    "invoice_line_item_id": item["id"],
                },
            )
    return sales_return_data["id"], taxable_value


# async def insert_invoice_token_advance(
#     cur: AsyncCursor[DictRow], invoice: Invoice, invoice_id: int
# ):
#     for token in invoice.token_advances:
#         insert_into_invoice_advance_query = """
#         INSERT INTO invoice_token_advance
#         (
#             invoice_id,
#             token_advance_id
#         )
#         VALUES
#         (
#             %(invoice_id)s,
#             %(token_advance_id)s
#         )
#         """
#         await cur.execute(
#             insert_into_invoice_advance_query,
#             {"invoice_id": invoice_id, "token_advance_id": token.token_advance_id},
#         )

#         update_token_advance_old_time_query = """
#         UPDATE
#             token_advance_status
#         SET
#             end_time = now()
#         WHERE
#             token_advance_id = %(token_advance_id)s and end_time='2100-01-01 00:00:00+00'

#         """
#         await cur.execute(
#             update_token_advance_old_time_query,
#             {"token_advance_id": token.token_advance_id},
#         )

#         update_token_advance_status_query = """
#         INSERT INTO
#             token_advance_status
#         (
#             token_advance_id,
#             status
#         )
#         VALUES
#         (
#             %(token_advance_id)s,
#             'BILLED'
#         )
#         """
#         await cur.execute(
#             update_token_advance_status_query,
#             {"token_advance_id": token.token_advance_id},
#         )


async def Insert_status_update(cur: AsyncCursor[DictRow], invoice_id: int, status: str):
    insert_into_invoice_status_query = """
    INSERT INTO invoice_status
    (
        invoice_id,
        status
    )
    VALUES
    (
        %(invoice_id)s,
        %(status)s
    )
    """
    await cur.execute(
        insert_into_invoice_status_query, {"invoice_id": invoice_id, "status": status}
    )


async def insert_into_refund_remainder(
    cur: AsyncCursor[DictRow],
    refund_method: RefundMethod,
    invoice_id: int,
    amount: float,
    document_code: str,
    customer_id: int,
):
    select_bank_account_id_query = """
    SELECT
        id
    FROM
        bank_account
    WHERE
        account_number = %(account_number)s
    """
    await cur.execute(
        select_bank_account_id_query,
        {"account_number": refund_method.bank_account.account_number},
    )
    bank_account_id = await cur.fetchone()
    if bank_account_id is None:
        insert_into_bank_account_query = """
        INSERT INTO
            bank_account
        (
            bank_name,
            account_name,
            account_number,
            branch_name,
            ifsc_code
        )
        VALUES
        (
            %(bank_name)s,
            %(account_name)s,
            %(account_number)s,
            %(branch_name)s,
            %(ifsc_code)s
        )
        RETURNING ID;
        """
        await cur.execute(
            insert_into_bank_account_query,
            {
                "bank_name": refund_method.bank_account.bank_name,
                "account_name": refund_method.bank_account.account_name,
                "account_number": refund_method.bank_account.account_number,
                "branch_name": refund_method.bank_account.branch_name,
                "ifsc_code": refund_method.bank_account.ifsc_code,
            },
        )
        bank_account_id = await cur.fetchone()
    bank_account_id = bank_account_id["id"]

    update_bank_of_customer_query = """
    UPDATE customer
    SET bank_account_id = %(bank_account_id)s
    WHERE id = %(customer_id)s;
    """
    await cur.execute(
        update_bank_of_customer_query,
        {"customer_id": customer_id, "bank_account_id": bank_account_id},
    )

    insert_into_refund_remainder_query = """
    INSERT INTO
        customer_payment_reminder
    (
        customer_id,
        amount,
        due_date,
        is_done,
        document_type,
        document_code,
        document_id
    )
    VALUES
    (
        %(customer_id)s,     
        %(amount)s,
        %(due_date)s,
        false,
        'INVOICE',
        %(document_code)s,
        %(document_id)s
    )
    RETURNING ID;
    """
    await cur.execute(
        insert_into_refund_remainder_query,
        {
            "customer_id": customer_id,
            "amount": abs(amount),
            "due_date": refund_method.due_date,
            "document_id": invoice_id,
            "document_code": document_code,
        },
    )
    refund_reminder = await cur.fetchone()
    return refund_reminder["id"]
    # refund_id = await cur.fetchone()
    # update_invoice_query = """
    # UPDATE
    #     invoice
    # SET
    #     refund_reminder_id = %(refund_id)s
    # WHERE
    #     id = %(invoice_id)s
    # """
    # if refund_id:
    #     await cur.execute(
    #         update_invoice_query,
    #         {
    #             "refund_id": refund_id["id"],
    #             "invoice_id": invoice_id,
    #         },
    #     )


async def insert_tax_amount_transactions(
    cur: AsyncCursor[DictRow],
    amount: float,
    customer_id: int,
    invoice_id: int,
    invoice_code: str,
    branch_code: str,
    tax_type: str,
):
    customer_chart_id = await get_customer_chart_of_account_id(cur, customer_id)
    cgst_chart_id = await get_advance_chart_of_account_id(
        cur, f"{branch_code} - Output Tax {tax_type} 1.5%"
    )

    _, _, transaction_group_id = await insert_into_transaction(
        cur,
        customer_chart_id,
        cgst_chart_id,
        amount,
        "INVOICE",
        invoice_id,
        invoice_code,
    )
    return transaction_group_id


async def insert_igst_amount_transactions(
    cur: AsyncCursor[DictRow],
    igst_amount: float,
    customer_id: int,
    invoice_id: int,
    invoice_code: str,
    branch_code: str,
):
    customer_chart_id = await get_customer_chart_of_account_id(cur, customer_id)
    igst_chart_id = await get_advance_chart_of_account_id(
        cur, f"{branch_code} - Output Tax IGST 3%"
    )

    _, _, transaction_group_id = await insert_into_transaction(
        cur,
        customer_chart_id,
        igst_chart_id,
        igst_amount,
        "INVOICE",
        invoice_id,
        invoice_code,
    )
    return transaction_group_id


async def create_actual_invoice(
    async_pool: AsyncConnectionPool,
    draft_invoice_id: int,
    request: UserJWTPayload,
    background_tasks: BackgroundTasks,
    otp_token: str | None = None,
    otp: str | None = None,
):
    _timing_start = time.monotonic()
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            data = await invoice_draft_check(cur, draft_invoice_id)

            if data:
                raise BadRequestException(
                    "Can't generate Invoice draft id already exist"
                )
            get_data_from_draft = """
            SELECT
                json_data
            FROM
                draft_form
            WHERE
                id = %(draft_id)s AND form_type='INVOICE'
                AND json_data != '{}'::jsonb;
            """
            await cur.execute(get_data_from_draft, {"draft_id": draft_invoice_id})
            data = await cur.fetchone()

            ##- advance_refund_transaction_groups holds the list with remaining transaction_groups for advance
            transaction_groups_ids_without_payment = []
            repurchase_line_item_ids_to_move: list[int] = []
            if data:
                invoice_object = Invoice.model_validate(data["json_data"])
                if not invoice_object.customer:
                    raise BadRequestException("Customer Not Given")
                ##- Carried-over sales-return plans/advances redeem nothing, so
                ##- they must not by themselves force a customer OTP.
                if any(
                    not advance.is_sales_return_plan
                    for advance in invoice_object.customer_advances
                ):
                    if not otp_token or not otp:
                        raise BadRequestException(
                            "Please verify the OTP sent to the customer before "
                            "saving this invoice."
                        )
                    _otp_start = time.monotonic()
                    await has_otp(x_otp_token=otp_token, x_otp=otp, conn=conn, x=None)
                    logger.info(
                        "create_actual_invoice OTP verification took %.3fs",
                        time.monotonic() - _otp_start,
                    )
                _cash_balance_start = time.monotonic()
                sr_invoice_id, sr_value = _clubbed_sales_return_cash_args(
                    invoice_object
                )
                cash_balance = await CustomerCashBalance(
                    cur,
                    invoice_object.customer.customer_id,
                    location_id=invoice_object.location.location_id,
                    clubbed_document_codes=[
                        advance.advance_code
                        for advance in invoice_object.customer_advances
                    ],
                    sales_return_invoice_id=sr_invoice_id,
                    sales_return_value=sr_value,
                ).get_cash_balance()
                logger.info(
                    "create_actual_invoice cash balance check took %.3fs",
                    time.monotonic() - _cash_balance_start,
                )
                if (cash_balance - invoice_object.get_customer_cash_amount) < 0:
                    raise BadRequestException(
                        "Customer cash limit exceeded "
                        "(monthly ₹2,00,000 / financial-year ₹10,00,000)."
                    )

                gst_fields = {
                    "CGST": invoice_object.cgst_amount,
                    "SGST": invoice_object.sgst_amount,
                    "IGST": invoice_object.igst_amount,
                }

                for gst_name, gst_value in gst_fields.items():
                    if gst_value is not None and gst_value < 0:
                        raise BadRequestException(f"{gst_name} cannot be negative")

                # Weight_of_gold is mandatory for the insurer, so an insured invoice
                # with no gold would issue a policy against nothing. Block it here —
                # before anything is written — so the user can switch insurance off and
                # retry. This is a data problem, unlike a vendor API failure, which is
                # always swallowed after the commit.
                if (
                    _is_insurance_eligible(invoice_object)
                    and invoice_gold_weight(invoice_object) <= 0
                ):
                    raise BadRequestException(
                        "This invoice has no gold weight, so a jewellery insurance "
                        "policy cannot be issued. Turn off insurance for this invoice "
                        "and try again."
                    )

                _step_start = time.monotonic()
                insert_into_invoice_query = """
                INSERT INTO INVOICE
                (
                    invoice_code,
                    created_by_employee_id,
                    salesperson_employee_id,
                    location_id,
                    referral_user_id,
                    cgst,
                    sgst,
                    igst_amount,
                    round_off_amount,
                    customer_id,
                    manager_employee_id,
                    repurchase_amount,
                    repurchase_id,
                    sales_return_amount,
                    sales_return_benefit_amount,
                    sales_return_id,
                    advance_amount,
                    scheme_amount,
                    note,
                    type,
                    draft_form_id,
                    is_insured

                )
                VALUES
                (
                    %(invoice_code)s,
                    %(created_by_employee_id)s,
                    %(salesperson_employee_id)s,
                    %(location_id)s,
                    %(referral_user_id)s,
                    %(cgst)s,
                    %(sgst)s,
                    %(igst)s,
                    %(round_off_amount)s,
                    %(customer_id)s,
                    %(manager_employee_id)s,
                    %(repurchase_amount)s,
                    %(repurchase_id)s,
                    %(sales_return_amount)s,
                    %(sales_return_benefit_amount)s,
                    %(sales_return_id)s,
                    %(advance_amount)s,
                    %(scheme_amount)s,
                    %(note)s,
                    %(type)s,
                    %(draft_form_id)s,
                    %(is_insured)s
                )
                RETURNING ID;
                """
                manager_employee_id = getattr(
                    invoice_object, "manager_employee_id", None
                )
                if manager_employee_id:
                    manager_employee_id = await check_employee_id(
                        cur, manager_employee_id
                    )
                if invoice_object.repurchase:
                    (
                        repurchase_id,
                        transaction_groups_ids,
                        repurchase_line_item_ids_to_move,
                    ) = await insert_repurchase(
                        cur, invoice_object, invoice_object.repurchase.repurchase_id
                    )
                    transaction_groups_ids_without_payment.extend(
                        transaction_groups_ids
                    )

                if invoice_object.sales_return_discount:
                    await create_sales_return_products(
                        cur,
                        invoice_object.location.location_id,
                        invoice_object.sales_return_discount.products,
                    )

                if invoice_object.sales_return:
                    (sales_return_id, total_sale_return) = await insert_sales_return(
                        cur,
                        invoice_object.sales_return.draft_sales_return_id,
                        request.user_id,
                        invoice_object.location.location_id,
                    )

                logger.info(
                    "create_actual_invoice repurchase/sales_return stage took %.3fs",
                    time.monotonic() - _step_start,
                )
                _step_start = time.monotonic()
                customer_data_query = """
                SELECT a.state_code,c.gstin
                FROM customer c
                JOIN address a ON c.primary_address_id = a.id
                WHERE c.id = %(customer_id)s
                """
                await cur.execute(
                    customer_data_query,
                    {"customer_id": invoice_object.customer.customer_id},
                )
                customer_data_row = await cur.fetchone()
                ##-- Generating invoice code based on customer gst B2B/B2C
                if customer_data_row["gstin"]:
                    invoice_code = await generate_document_code(
                        cur,
                        SALES_INVOICE_B2B_CODE_CONFIG,
                        location_id=invoice_object.location.location_id,
                    )
                else:
                    invoice_code = await generate_document_code(
                        cur,
                        SALES_INVOICE_B2C_CODE_CONFIG,
                        location_id=invoice_object.location.location_id,
                    )
                logger.info(
                    "create_actual_invoice customer lookup + document code "
                    "generation took %.3fs",
                    time.monotonic() - _step_start,
                )
                _step_start = time.monotonic()

                # Get customer state via address

                customer_state = (
                    customer_data_row["state_code"] if customer_data_row else None
                )

                # Get branch/location state
                branch_state = getattr(invoice_object.location, "state", None)

                igst_bill = False
                if branch_state != customer_state:
                    igst_bill = True

                created_employee_id = await get_employee_id(cur, request.user_id)

                referral_user_id = getattr(invoice_object, "referral_user_id", None)
                if referral_user_id == 0:
                    referral_user_id = None

                await cur.execute(
                    insert_into_invoice_query,
                    {
                        "invoice_code": invoice_code,
                        "is_insured": _is_insurance_eligible(invoice_object),
                        "created_by_employee_id": created_employee_id,
                        "salesperson_employee_id": invoice_object.sales_person_employee_id,
                        "repurchase_amount": invoice_object.repurchase.total_amount
                        if invoice_object.repurchase
                        and invoice_object.repurchase.total_amount
                        else 0,
                        "repurchase_id": repurchase_id["id"]
                        if invoice_object.repurchase
                        else None,
                        "sales_return_amount": total_sale_return
                        if invoice_object.sales_return
                        else 0,
                        "sales_return_benefit_amount": invoice_object.sales_return_benefit
                        if invoice_object.sales_return
                        else 0,
                        "sales_return_id": sales_return_id
                        if invoice_object.sales_return
                        else None,
                        "referral_user_id": referral_user_id,
                        "location_id": invoice_object.location.location_id,
                        "cgst": invoice_object.cgst_amount
                        if branch_state == customer_state
                        else 0,
                        "sgst": invoice_object.sgst_amount
                        if branch_state == customer_state
                        else 0,
                        "igst": invoice_object.igst_amount
                        if branch_state != customer_state
                        else 0,
                        "round_off_amount": getattr(
                            invoice_object, "round_off_amount", None
                        ),
                        "customer_id": invoice_object.customer.customer_id,
                        "manager_employee_id": manager_employee_id,
                        "advance_benefit_amount": 0,
                        "scheme_benefit_amount": 0,
                        "advance_amount": invoice_object.total_advance_amount
                        if invoice_object.total_advance_amount
                        else 0,
                        "scheme_amount": invoice_object.total_plan_amount
                        if invoice_object.total_plan_amount
                        else 0,
                        "note": invoice_object.notes,
                        "type": "B2B" if customer_data_row["gstin"] else "B2C",
                        "draft_form_id": draft_invoice_id,
                    },
                )
                invoice = await cur.fetchone()
                invoice_id = invoice["id"]
                logger.info(
                    "create_actual_invoice invoice row insert took %.3fs",
                    time.monotonic() - _step_start,
                )
                _step_start = time.monotonic()

                ##- Record today's walk-in feedback as converted via a sale
                await mark_offline_feedback_status(
                    cur,
                    invoice_object.customer.customer_id,
                    OFFLINE_FEEDBACK_STATUS_SALES,
                )

                await insert_invoice_line_items(
                    cur,
                    invoice_object,
                    invoice_id,
                    invoice_object.location.location_id,
                    igst_bill,
                )
                logger.info(
                    "create_actual_invoice line items insert took %.3fs",
                    time.monotonic() - _step_start,
                )
                _step_start = time.monotonic()

                branch_code = await get_branch_code(
                    cur, invoice_object.location.location_id
                )

                customer_plan_advances = getattr(
                    invoice_object, "customer_advances", []
                )
                ##- Inserting partial and non partial advances
                newly_created_installment_ids = []
                newly_created_installment_ids = await insert_and_check_advance(
                    cur,
                    customer_plan_advances,
                )

                # customer_plan_ids = getattr(invoice_object, "customer_plans", [])
                await insert_and_check_plans(
                    cur,
                    invoice_id,
                    customer_plan_advances,
                    invoice_object.location.location_id,
                    invoice_object,
                )
                logger.info(
                    "create_actual_invoice branch_code + advance/plan insert "
                    "took %.3fs",
                    time.monotonic() - _step_start,
                )
                _step_start = time.monotonic()

                repurchase_id = (
                    repurchase_id["id"] if invoice_object.repurchase else None
                )

                sales_return_id = (
                    sales_return_id if invoice_object.sales_return else None
                )

                ##- Returning the newly created advance in refund if its in the refundmethods
                ##- Attached the transaction groups in payment insertion function for refund-Advance
                # transaction_group_ids=[]
                (
                    transaction_group_ids,
                    y,
                    z,
                    refunded_customer_advance_installment_id,
                ) = await create_payment_for_invoice(
                    cur,
                    invoice_object,
                    invoice_object.net_amount,
                    invoice_id,
                    invoice_code,
                    invoice_object.customer.customer_id,
                    invoice_object.location.location_id,
                    repurchase_id,
                    sales_return_id,
                    async_pool=async_pool,
                    # total_benefit_amount,
                )
                logger.info(
                    "create_actual_invoice create_payment_for_invoice took %.3fs",
                    time.monotonic() - _step_start,
                )
                _step_start = time.monotonic()
                paid_amount = 0
                for i in invoice_object.payment_methods:
                    paid_amount += i.amount
                if (
                    paid_amount < invoice_object.net_amount
                    and invoice_object.net_amount > 0
                ):
                    await Insert_status_update(cur, invoice_id, "PARTIAL_PAYMENT")
                else:
                    await Insert_status_update(cur, invoice_id, "SETTLED")
                # elif invoice_object.net_amount < 0:
                #     transaction_group_ids = (
                #         await create_payment_for_invoice_refund_case(
                #             cur,
                #             invoice_object,
                #             invoice_id,
                #             invoice_code,
                #             repurchase_id,
                #             sales_return_id,
                #         )
                #     )

                # Determine tax type
                if customer_state and branch_state and customer_state == branch_state:
                    # Same state → CGST + SGST
                    cgst_amount = invoice_object.cgst_amount
                    transaction_group_id = await insert_tax_amount_transactions(
                        cur,
                        cgst_amount,
                        invoice_object.customer.customer_id,
                        invoice_id,
                        invoice_code,
                        branch_code,
                        "CGST",
                    )
                    transaction_group_ids.append(transaction_group_id)
                    transaction_groups_ids_without_payment.append(transaction_group_id)

                    sgst_amount = invoice_object.sgst_amount
                    transaction_group_id = await insert_tax_amount_transactions(
                        cur,
                        sgst_amount,
                        invoice_object.customer.customer_id,
                        invoice_id,
                        invoice_code,
                        branch_code,
                        "SGST",
                    )
                    transaction_group_ids.append(transaction_group_id)
                    transaction_groups_ids_without_payment.append(transaction_group_id)
                else:
                    # Different state → IGST
                    igst_amount = invoice_object.igst_amount
                    transaction_group_id = await insert_igst_amount_transactions(
                        cur,
                        igst_amount,
                        invoice_object.customer.customer_id,
                        invoice_id,
                        invoice_code,
                        branch_code,
                    )
                    transaction_group_ids.append(transaction_group_id)
                    transaction_groups_ids_without_payment.append(transaction_group_id)
                logger.info(
                    "create_actual_invoice tax transaction insert took %.3fs",
                    time.monotonic() - _step_start,
                )
                _step_start = time.monotonic()

                insert_into_invoice_transaction_query = """
                INSERT INTO
                    invoice_transaction_group
                (
                    invoice_id,
                    transaction_group_id
                )
                VALUES
                (
                    %(invoice_id)s,
                    %(transaction_group_id)s
                )
                """
                values = [
                    {
                        "invoice_id": invoice_id,
                        "transaction_group_id": transaction_group_id,
                    }
                    for transaction_group_id in transaction_group_ids
                ]

                await cur.executemany(insert_into_invoice_transaction_query, values)

                ## -- Creating invoice customer_advance_redeemed

                insert_into_redeemed_advance_query = """
                INSERT INTO invoice_customer_advance_redeemed
                (
                    invoice_id,
                    customer_advance_id,
                    rate_difference,
                    redeemed_weight
                )
                VALUES(
                %(invoice_id)s,
                %(customer_advance_id)s,
                %(rate_difference)s,
                %(redeemed_weight)s
                )
                """
                for i in invoice_object.rate_difference:
                    if i.customer_advance.is_advance == True and i.amount != 0:
                        await cur.execute(
                            insert_into_redeemed_advance_query,
                            {
                                "invoice_id": invoice_id,
                                "customer_advance_id": i.customer_advance.advance_id,
                                "rate_difference": i.amount,
                                "redeemed_weight": i.weight,
                            },
                        )

                ##--Connecting invoice customer advance installment
                insert_into_invoice_customer_advance_installment = """
                INSERT INTO invoice_customer_advance_installment (invoice_id,customer_advance_installment_id)
                VALUES(
                    %(invoice_id)s,
                    %(customer_advance_installment_id)s
                )
                """
                if (
                    newly_created_installment_ids
                    or refunded_customer_advance_installment_id != None
                ):
                    installment_ids = newly_created_installment_ids
                    if refunded_customer_advance_installment_id != None:
                        installment_ids += [refunded_customer_advance_installment_id]
                    invoice_customer_advance = [
                        {"invoice_id": invoice_id, "customer_advance_installment_id": i}
                        for i in installment_ids
                    ]
                    await cur.executemany(
                        insert_into_invoice_customer_advance_installment,
                        invoice_customer_advance,
                    )

                ##--Connecting repurchase customer advance installment
                insert_into_repurchase_customer_advance_installment = """
                INSERT INTO repurchase_customer_advance_installment (repurchase_id,customer_advance_installment_id)
                VALUES(
                    %(repurchase_id)s,
                    %(customer_advance_installment_id)s
                )
                """
                if repurchase_id and refunded_customer_advance_installment_id:
                    await cur.execute(
                        insert_into_repurchase_customer_advance_installment,
                        {
                            "repurchase_id": repurchase_id,
                            "customer_advance_installment_id": refunded_customer_advance_installment_id,
                        },
                    )

                ##--Connecting sales return customer advance installment
                insert_into_sales_return_customer_advance_installment = """
                INSERT INTO sales_return_customer_advance_installment (sales_return_id,customer_advance_installment_id)
                VALUES(
                    %(sales_return_id)s,
                    %(customer_advance_installment_id)s
                )
                """
                if sales_return_id and refunded_customer_advance_installment_id:
                    await cur.execute(
                        insert_into_sales_return_customer_advance_installment,
                        {
                            "sales_return_id": sales_return_id,
                            "customer_advance_installment_id": refunded_customer_advance_installment_id,
                        },
                    )
                # Move repurchased items to their box within the SAME transaction
                # as the invoice, so a move failure rolls the whole invoice back
                # (no committed invoice/repurchase left with unmoved items in the
                # listing). Must run before commit.
                # The box is the one at the invoice's own branch — the same branch
                # the repurchased products were located at — not the saving user's
                # branch, which differs when one branch saves another's draft.
                if repurchase_line_item_ids_to_move:
                    await _move_repurchase_line_items(
                        cur,
                        repurchase_line_item_ids_to_move,
                        invoice_object.location.location_id,
                    )
                logger.info(
                    "create_actual_invoice advance/repurchase/sales_return "
                    "installment linking + box move took %.3fs",
                    time.monotonic() - _step_start,
                )
                _step_start = time.monotonic()
                await conn.commit()
                logger.info(
                    "create_actual_invoice conn.commit() took %.3fs",
                    time.monotonic() - _step_start,
                )
                logger.info(
                    "create_actual_invoice DB save (including OTP verification) "
                    "took %.3fs",
                    time.monotonic() - _timing_start,
                )
                coi_pdf = None
                if _is_insurance_eligible(invoice_object):
                    coi_pdf = await _issue_invoice_insurance(
                        cur, invoice_code, invoice_object
                    )
                await regenerate_invoice_pdf(async_pool, invoice_id, request)
                # The certificate is its own S3 object, so it is stored alongside the
                # invoice PDF rather than merged into it.
                if coi_pdf:
                    await store_invoice_coi(
                        async_pool, invoice_id, invoice_code, coi_pdf
                    )
                logger.info(
                    "create_actual_invoice total time %.3fs",
                    time.monotonic() - _timing_start,
                )
                return {"id": invoice_id}

            else:
                raise BadRequestException("Data Not Found")


# -----------------Actual Invoice creation ends ------------------------------


async def remove_advance(
    async_pool: AsyncConnectionPool, draft_invoice_id: int, customer_advance_index: int
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            fetch_invoice_data_query = """
            SELECT
                json_data
            FROM
                draft_form
            WHERE
                id= %(draft_id)s AND form_type='INVOICE'
            """
            await cur.execute(fetch_invoice_data_query, {"draft_id": draft_invoice_id})
            result = await cur.fetchone()
            invoice_data = Invoice.model_validate(result["json_data"])
            invoice_data.remove_customer_advance(customer_advance_index)

            data = await invoice_draft_check(cur, draft_invoice_id)

            if data:
                raise BadRequestException(
                    "Can't edit the data. Invoice already created."
                )

            update_invoice_data = """
            UPDATE draft_form
            SET json_data=%(json_data)s
            WHERE 
                id =%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                update_invoice_data,
                {
                    "json_data": invoice_data.model_dump_json(),
                    "draft_invoice_id": draft_invoice_id,
                },
            )
            return {"message": "Customer Advance Plan Removed Successfully"}


async def update_line_item_rate_function(
    cur: AsyncCursor[DictRow],
    draft_invoice_id: int,
    product_code: str,
    material_code: str,
    line_item_rate_request: UpdateLineItemRate,
):
    fetch_draft_invoice_query = """
            SELECT 
                json_data
            FROM
                draft_form
            WHERE
                id=%(draft_invoice_id)s
            """
    await cur.execute(fetch_draft_invoice_query, {"draft_invoice_id": draft_invoice_id})
    invoice_data = await cur.fetchone()
    invoice_data = invoice_data["json_data"]
    line_items = invoice_data["line_items"]
    for item in line_items:
        if item["product_code"] == product_code:
            material_rates = item["materials"]
            for rates in material_rates:
                if rates["code"] == material_code:
                    if rates["code"] != "G24" and rates["type"] == "METAL":
                        raise BadRequestException("Only G24 rate can be updated")
                    else:
                        rates["rate"] = line_item_rate_request.rate
    invoice_obj = Invoice.model_validate(invoice_data)
    invoice_json_str = invoice_obj.model_dump_json()

    data = await invoice_draft_check(cur, draft_invoice_id)
    if data:
        raise BadRequestException("Can't edit the data. Invoice already created.")

    update_json_data_query = """
        UPDATE draft_form
        SET json_data = %(serialized_json)s
        WHERE id = %(draft_invoice_id)s AND form_type='INVOICE'
    """

    await cur.execute(
        update_json_data_query,
        {
            "serialized_json": invoice_json_str,
            "draft_invoice_id": draft_invoice_id,
        },
    )
    return {"message": "Successfully Updated"}


async def update_line_item_rate(
    async_pool: AsyncConnectionPool,
    draft_invoice_id: int,
    product_code: str,
    material_code: str,
    line_item_rate_request: UpdateLineItemRate,
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            return await update_line_item_rate_function(
                cur,
                draft_invoice_id,
                product_code,
                material_code,
                line_item_rate_request,
            )


async def club_plan(
    async_pool: AsyncConnectionPool,
    request: UserJWTPayload,
    invoice_id: int,
    insert_plan_request: InvoiceInsertPlanRequest,
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            fetch_query = "SELECT json_data FROM draft_form WHERE id = %(invoice_id)s AND form_type='INVOICE';"
            await cur.execute(fetch_query, {"invoice_id": invoice_id})
            current_data_row = await cur.fetchone()
            invoice_data = current_data_row["json_data"]
            if not invoice_data:
                raise BadRequestException("Draft id not found")

            # A plan can only be clubbed when the invoice already has a customer,
            # and every plan must belong to that same customer.
            draft_customer_id = (invoice_data.get("customer") or {}).get("customer_id")
            if not draft_customer_id:
                raise BadRequestException(
                    "Please add a customer to the invoice before adding a plan"
                )

            other_customer_plans_query = """
                SELECT customer_plan_code
                FROM customer_plan
                WHERE id = ANY(%(plan_ids)s::integer[])
                  AND customer_id <> %(customer_id)s
                ORDER BY customer_plan_code
            """
            await cur.execute(
                other_customer_plans_query,
                {
                    "plan_ids": insert_plan_request.customer_plan_ids,
                    "customer_id": draft_customer_id,
                },
            )
            other_customer_plans = await cur.fetchall()
            if other_customer_plans:
                plan_codes = ", ".join(
                    plan["customer_plan_code"] for plan in other_customer_plans
                )
                raise BadRequestException(
                    f"Plan {plan_codes} does not belong to the customer on this invoice"
                )

            # Check if all the plan ids that come from the UI are close
            if not await check_plan_closed(
                async_pool, insert_plan_request.customer_plan_ids
            ):
                raise BadRequestException("Some plan ids are not closed")

            # Check if that not more than one plan id that comes from the UI are matured
            # if await if_cross_plans_matured(insert_plan_request.customer_plan_ids):
            #     raise BadRequestException("Only one type of matured plan is possible")

            # Check if atleast  invoice line is item exist before adding the customer plan
            if not await if_line_item_exists(async_pool, invoice_id):
                raise BadRequestException("Invoice line item does not exist")

            # Check if plan already added
            if await if_plan_exists(
                async_pool, invoice_id, insert_plan_request.customer_plan_ids
            ):
                raise BadRequestException("Plan already added")

            branch_id = request.branch_id

            # state_check_query = """
            #     SELECT COUNT(*) AS mismatch_count
            #     FROM customer_plan cp
            #     JOIN branch b ON b.id = cp.branch_id
            #     JOIN address a ON a.id = b.address_id
            #     WHERE cp.id = ANY(%(plan_ids)s::integer[])
            #       AND a.state_code != (
            #           SELECT a2.state_code
            #           FROM branch b2
            #           JOIN address a2 ON a2.id = b2.address_id
            #           WHERE b2.id = %(branch_id)s
            #       )
            # """
            # await cur.execute(
            #     state_check_query,
            #     {
            #         "plan_ids": insert_plan_request.customer_plan_ids,
            #         "branch_id": branch_id,
            #     },
            # )
            # state_check = await cur.fetchone()
            # if state_check["mismatch_count"] > 0:
            #     raise BadRequestException(
            #         "Plans from a different state cannot be clubbed"
            #     )

            # Generate list with all plan id respective of their type (REG, ILL, ADV)
            plan_id_codes_list = await generate_plan_code(
                async_pool, insert_plan_request.customer_plan_ids, branch_id
            )

            # Generate gold weights and rates on the time of payment
            plan_id_codes_list = await generate_gold_weights(
                async_pool, plan_id_codes_list
            )

            get_location_query = f"""
            SELECT json_agg(json_build_object('state', ad.state_code, 'location_id', branch.id)) AS result
            FROM branch
            LEFT JOIN address ad ON ad.id = branch.address_id
            WHERE branch.id = {branch_id}
            """
            await cur.execute(get_location_query)
            location = await cur.fetchone()
            location = location["result"][0]

            plan_id_codes_list = [
                i
                for i in plan_id_codes_list
                if not (i["status"] not in ["ACTIVE", "MATURED", "LAPSED"])
            ]

            invoice_obj = Invoice.model_validate(invoice_data)
            for i in plan_id_codes_list:
                i["location"] = location
                customer_plan = CustomerAdvance(**i, is_advance=False)
                invoice_obj.add_customer_advance(customer_plan, False)
            invoice_json_str = invoice_obj.model_dump_json()

            update_query = """
                UPDATE draft_form
                SET json_data = %(updated_invoice_data)s
                WHERE id = %(invoice_id)s AND form_type='INVOICE'
                RETURNING json_data;
            """
            await cur.execute(
                update_query,
                {
                    "updated_invoice_data": invoice_json_str,
                    "invoice_id": invoice_id,
                },
            )
            return json.loads(invoice_json_str)


async def remove_plan(
    async_pool: AsyncConnectionPool,
    request: Request,
    draft_invoice_id: int,
    customer_plan_index: int,
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            fetch_invoice_data_query = """
            SELECT
                json_data
            FROM
                draft_form
            WHERE
                id= %(draft_id)s AND form_type='INVOICE'
            """
            await cur.execute(fetch_invoice_data_query, {"draft_id": draft_invoice_id})
            result = await cur.fetchone()
            invoice_data = Invoice.model_validate(result["json_data"])
            invoice_data.remove_customer_plan(customer_plan_index)

            update_invoice_data = """
            UPDATE draft_form
            SET json_data=%(json_data)s
            WHERE 
                id =%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                update_invoice_data,
                {
                    "json_data": invoice_data.model_dump_json(),
                    "draft_invoice_id": draft_invoice_id,
                },
            )

            return json.loads(invoice_data.model_dump_json())


async def check_plan_closed(async_pool: AsyncConnectionPool, customer_plan_ids):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            placeholders = ", ".join(["%s"] * len(customer_plan_ids))
            fetch_status_query = f"""
                SELECT customer_plan_id
                FROM customer_plan_status
                WHERE customer_plan_id IN ({placeholders})
                AND end_time = '2100-01-01 00:00:00+00'
                AND status = 'CLOSED'
            """
            await cur.execute(fetch_status_query, customer_plan_ids)
            result = await cur.fetchall()
            if len(result) != len(customer_plan_ids):
                return False
            return True


# async def if_cross_plans_matured(customer_plan_ids):
#     async with async_pool.connection() as conn:
#         async with conn.cursor() as cur:
#             placeholders = ", ".join(["%s"] * len(customer_plan_ids))
#             fetch_status_query = f"""
#                 SELECT cp.type
#                 FROM customer_plan_status
#                 left join customer_plan cp on cp.id = customer_plan_status.customer_plan_id
#                 WHERE customer_plan_id IN ({placeholders})
#                 AND status = 'MATURED'

#             """
#             await cur.execute(fetch_status_query, customer_plan_ids)
#             result = await cur.fetchall()
#             types = [row["type"] for row in result]
#             if len(set(types)) > 1:
#                 return True
#             return False


async def if_line_item_exists(async_pool: AsyncConnectionPool, invoice_id):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            fetch_query = """
                SELECT EXISTS(
                    SELECT 1 FROM draft_form
                    WHERE id = %(invoice_id)s AND form_type='INVOICE'
                     AND COALESCE(jsonb_array_length(json_data->'line_items'), 0) > 0
                );
            """
            await cur.execute(fetch_query, {"invoice_id": invoice_id})
            result = await cur.fetchone()
            if result["exists"]:
                return True
            return False


async def if_advance_already_added(invoice_object: Invoice, advance_ids):
    for i in invoice_object.customer_advances:
        if i.advance_id in advance_ids:
            return True
    return False


async def if_plan_exists(
    async_pool: AsyncConnectionPool, invoice_id, customer_advance_ids
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            fetch_query = """
                SELECT json_data->'customer_advances' as customer_advances
                FROM draft_form
                WHERE id = %(invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(fetch_query, {"invoice_id": invoice_id})
            result = await cur.fetchone()
            for i in result["customer_advances"]:
                if i["advance_id"] in customer_advance_ids:
                    return True
            return False


async def generate_plan_code(async_pool: AsyncConnectionPool, plan_ids, location_id):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            get_location_query = """
            SELECT json_agg(json_build_object('state', ad.state_code, 'location_id', branch.id)) AS result
            FROM branch
            LEFT JOIN address ad ON ad.id = branch.address_id
            WHERE branch.id = %(location_id)s
            """
            await cur.execute(get_location_query, {"location_id": location_id})
            location = await cur.fetchone()
            location = location["result"][0]
            placeholders = ", ".join(["%s"] * len(plan_ids))
            fetch_plan_details_query = f"""
            SELECT 
                cp.id AS advance_id,                     
                cp.customer_plan_code AS advance_code,                     
                cp.referral_user_id,
                cp.joined_at,
                CASE 
                    WHEN cp.type = 'ADV' THEN (
                        SELECT prev_cp.type
                        FROM plan_advance pa
                        JOIN customer_plan prev_cp ON prev_cp.id = pa.previous_customer_plan_id
                        WHERE pa.customer_plan_id = cp.id
                        LIMIT 1
                    )
                    ELSE cp.type
                END AS type,
                CASE 
                    WHEN cp.type IN ('REG', 'ILL') THEN (
                        SELECT cps.status::TEXT
                        FROM customer_plan_status cps
                        WHERE cps.customer_plan_id = cp.id
                        ORDER BY cps.end_time DESC
                        LIMIT 1 OFFSET 1
                    )
                    WHEN cp.type = 'ADV' THEN (
                        SELECT sub.status::TEXT
                        FROM plan_advance pa
                        LEFT JOIN LATERAL (
                            SELECT cps.status
                            FROM customer_plan_status cps
                            WHERE cps.customer_plan_id = pa.previous_customer_plan_id
                            ORDER BY cps.end_time DESC
                            LIMIT 1 OFFSET 1
                        ) sub ON true
                        WHERE pa.customer_plan_id = cp.id
                        LIMIT 1
                    )
                END AS status,
                CASE 
                    WHEN cp.type = 'REG' THEN (
                        SELECT SUM(pir.amount)
                        FROM plan_installment_regalia pir
                        WHERE pir.customer_plan_id = cp.id
                        AND pir.status = 'PAID'
                    )
                    WHEN cp.type = 'ILL' THEN (
                        SELECt SUM(amount) as total_paid_amount
                        FROM plan_illuminati pi
                        LEFT JOIN plan_installment_illuminati pii on pii.customer_plan_id = pi.customer_plan_id
                        WHERE 
                        cp.id = pi.customer_plan_id
                        AND pii.status='PAID'
                    )
                    WHEN cp.type = 'ADV' THEN (
                        SELECT SUM(pa.total_amount)
                        FROM plan_advance pa
                        WHERE pa.customer_plan_id = cp.id
                    )
                END AS amount,
                CASE 
                    WHEN cp.type = 'REG' THEN (
                        SELECT COALESCE(json_agg(json_build_object('amount', pir.amount)), '[]'::json)
                        FROM plan_installment_regalia pir
                        WHERE pir.customer_plan_id = cp.id AND pir.status = 'PAID'
                    )
                    WHEN cp.type = 'ILL' THEN (
                        SELECT COALESCE(json_agg(json_build_object('rate', pii.gold_rate, 'weight', pii.weight, 'amount', pi.amount)), '[]'::json)
                        FROM plan_illuminati pi
                        JOIN plan_installment_illuminati pii ON pii.customer_plan_id = pi.customer_plan_id AND pii.status='PAID'
                        WHERE pi.customer_plan_id = cp.id
                    )
                    WHEN cp.type = 'ADV' THEN (
                        SELECT COALESCE(json_agg(json_build_object('amount', pa.total_amount)), '[]'::json)
                        FROM plan_advance pa
                        WHERE pa.customer_plan_id = cp.id
                    )
                    ELSE '[]'::json
                END AS installments
            FROM 
                public.customer_plan cp
            WHERE 
                cp.id IN ({placeholders})
            GROUP BY 
                cp.id, cp.customer_plan_code, cp.type;
            """
            await cur.execute(fetch_plan_details_query, plan_ids)
            results = await cur.fetchall()
            return results


async def update_line_item_va(
    async_pool: AsyncConnectionPool,
    draft_invoice_id: int,
    line_index: int,
    update_sales_va_request: UpdateSalesVa,
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            fetch_draft_invoice_query = """
            SELECT 
                json_data
            FROM
                draft_form
            WHERE
                id=%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                fetch_draft_invoice_query, {"draft_invoice_id": draft_invoice_id}
            )
            invoice_data = await cur.fetchone()
            if not invoice_data:
                raise BadRequestException("Draft Invoice Not Found")
            invoice_data = invoice_data["json_data"]
            line_items = invoice_data["line_items"]
            for line_item_index, item in enumerate(line_items):
                if line_item_index == line_index:
                    product_code = item["product_code"]
                    await cur.execute(
                        "SELECT minimum_va_percentage FROM product WHERE product_code = %(product_code)s",
                        {"product_code": product_code},
                    )
                    product_data = await cur.fetchone()
                    if not (
                        item["sales_va_percentage"]
                        >= update_sales_va_request.va_after_discount
                        >= product_data["minimum_va_percentage"]
                    ):
                        raise BadRequestException(
                            "Va percentage should be between minimum and maximum sales va"
                        )
                    item["va_after_discount"] = (
                        update_sales_va_request.va_after_discount
                    )
            invoice_obj = Invoice.model_validate(invoice_data)
            invoice_json_str = invoice_obj.model_dump_json()
            data = await invoice_draft_check(cur, draft_invoice_id)

            if data:
                raise BadRequestException(
                    "Can't edit the data. Invoice already created."
                )
            update_json_data_query = """
                UPDATE draft_form
                SET json_data = %(serialized_json)s
                WHERE id = %(draft_invoice_id)s AND form_type='INVOICE'
            """

            await cur.execute(
                update_json_data_query,
                {
                    "serialized_json": invoice_json_str,
                    "draft_invoice_id": draft_invoice_id,
                },
            )
            return {"message": "Successfully Updated"}


async def generate_gold_weights(async_pool: AsyncConnectionPool, plan_id_codes_list):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            for i in plan_id_codes_list:
                if i["type"] == "REG" or i["type"] == "ADV":
                    i["gold_weights"] = []
                if i["type"] == "ILL":
                    fetch_gold_weight_query = """
                    SELECT pii.created_at, pl.amount
                    FROM plan_installment_illuminati pii
                    LEFT JOIN plan_illuminati pl ON pl.customer_plan_id = pii.customer_plan_id
                    WHERE pl.customer_plan_id = %(customer_plan_id)s
                    AND pii.status = 'PAID';
                    """
                    await cur.execute(
                        fetch_gold_weight_query,
                        {"customer_plan_id": i["advance_id"]},
                    )
                    paid_dates = await cur.fetchall()
                    no_of_payments = len(paid_dates)

                    await cur.execute(
                        "SELECT branch_id FROM customer_plan WHERE id = %(customer_plan_id)s",
                        {"customer_plan_id": i["advance_id"]},
                    )
                    customer_plan = await cur.fetchone()
                    branch_id = customer_plan["branch_id"]

                    # Calculate the weight and rate data of G22
                    g22_weight = 0
                    total_g22_rates = 0
                    for date in paid_dates:
                        get_g22_rate = """
                        SELECT rate
                        FROM material_rate
                        LEFT JOIN material m ON m.id = material_rate.material_id
                        WHERE start_time < %(date)s
                        AND end_time > %(date)s
                        AND m.material_code = 'G22'
                        AND location_id = %(branch_id)s;
                        """
                        await cur.execute(
                            get_g22_rate,
                            {"date": date["created_at"], "branch_id": branch_id},
                        )
                        g22_rate = await cur.fetchone()
                        total_g22_rates += g22_rate["rate"]
                        average_g22_rate = total_g22_rates / no_of_payments
                        g22_weight += date["amount"] / g22_rate["rate"]

                        # Calculate the weight and rate data of G18
                        g18_weight = 0
                        total_g18_rates = 0
                        get_g18_rate = """
                        SELECT rate
                        FROM material_rate
                        LEFT JOIN material m ON m.id = material_rate.material_id
                        WHERE start_time < %(date)s
                        AND end_time > %(date)s
                        AND m.material_code = 'G18'
                        AND location_id = %(branch_id)s;
                        """
                        await cur.execute(
                            get_g18_rate,
                            {"date": date["created_at"], "branch_id": branch_id},
                        )
                        g18_rate = await cur.fetchone()
                        total_g18_rates += g18_rate["rate"]
                        average_g18_rate = total_g18_rates / no_of_payments
                        g18_weight += date["amount"] / g18_rate["rate"]
                        i["gold_weights"] = [
                            {
                                "code": "G22",
                                "average_rate": average_g22_rate,
                                "weight": g22_weight,
                            },
                            {
                                "code": "G18",
                                "average_rate": average_g18_rate,
                                "weight": g18_weight,
                            },
                        ]

            return plan_id_codes_list


async def remove_payment_method(
    async_pool: AsyncConnectionPool, draft_invoice_id: int, payment_method_index: int
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            fetch_invoice_data_query = """
            SELECT
                json_data
            FROM
                draft_form
            WHERE
                id= %(draft_id)s AND form_type='INVOICE'
            """
            await cur.execute(fetch_invoice_data_query, {"draft_id": draft_invoice_id})
            result = await cur.fetchone()
            invoice_data = Invoice.model_validate(result["json_data"])
            invoice_data.remove_payment_method(payment_method_index)

            data = await invoice_draft_check(cur, draft_invoice_id)

            if data:
                raise BadRequestException(
                    "Payment cannot be removed because the invoice has already been created."
                )

            update_invoice_data = """
            UPDATE draft_form
            SET json_data=%(json_data)s
            WHERE 
                id =%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                update_invoice_data,
                {
                    "json_data": invoice_data.model_dump_json(),
                    "draft_invoice_id": draft_invoice_id,
                },
            )
            return {"message": "Payment Method Removed Successfully"}


async def add_payment_method(
    async_pool: AsyncConnectionPool,
    draft_invoice_id: int,
    payment_methods: List[PaymentMethod],
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            fetch_draft_invoice_query = """
            SELECT 
                json_data
            FROM
                draft_form
            WHERE
                id=%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                fetch_draft_invoice_query, {"draft_invoice_id": draft_invoice_id}
            )
            invoice_data = await cur.fetchone()
            invoice_data = invoice_data["json_data"]
            customer_id = invoice_data["customer"]["customer_id"]
            if not customer_id:
                raise BadRequestException(
                    "Please club a customer to add payment method"
                )

            invoice_draft = Invoice.model_validate(invoice_data)

            data = await invoice_draft_check(cur, draft_invoice_id)

            if data:
                raise BadRequestException(
                    "Payment cannot be updated because the invoice has already been created."
                )

            for payment_data in payment_methods:
                # cash_limit = await if_cash_limit_exceeded(
                #     cur, customer_id, payment_data.amount
                # )
                # if cash_limit:
                #     raise BadRequestException(cash_limit)
                validate_payment_coa_query = """
                SELECT
                    account_name,
                    type
                FROM chart_of_account
                WHERE id = %(chart_of_account_id)s
                """

                await cur.execute(
                    validate_payment_coa_query,
                    {"chart_of_account_id": payment_data.chart_of_account_id},
                )

                coa = await cur.fetchone()

                if not coa:
                    raise BadRequestException("Invalid chart of account.")

                expected_coa_type = PaymentMethodToCoaType[
                    payment_data.payment_method
                ].value

                if coa["type"] != expected_coa_type:
                    raise BadRequestException(
                        f"Payment method '{payment_data.payment_method}' requires a "
                        f"'{expected_coa_type}' chart of account"
                    )
                invoice_draft.add_payment_method(payment_data)

            update_invoice_data = """
            UPDATE draft_form
            SET json_data=%(json_data)s 
            WHERE 
                id =%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                update_invoice_data,
                {
                    "json_data": invoice_draft.model_dump_json(),
                    "draft_invoice_id": draft_invoice_id,
                },
            )
            return {"message": "Successfully Updated"}


async def get_stone_rate(cur: AsyncCursor[DictRow], product_id: int):
    get_product_rate_query = """
    SELECT
        
         COALESCE(stone_rate.stone_rate, 0) as rate
    FROM 
        product p 
    LEFT JOIN 
       (
            SELECT 
                SUM(COALESCE(pw.purchase_rate, mr.rate) * pw.total_weight) as stone_rate , pw.product_id
            FROM
                product_weight pw 
            LEFT JOIN 
                product_location pl on pl.product_id = pw.product_id AND pl.end_time = '2100-01-01 00:00:00+00'
            LEFT JOIN 
                material_rate mr on mr.material_id = pw.material_id AND mr.location_id = pl.location_id
            LEFT JOIN 
                material m on m.id = mr.material_id
            WHERE 
                mr.end_time = '2100-01-01 00:00:00+00' AND pl.end_time = '2100-01-01 00:00:00+00' and m.type = 'STONE'
            GROUP BY pw.product_id
    
	   ) as stone_rate ON stone_rate.product_id = p.id
	WHERE
	   p.id = %(product_id)s and p.is_box = false
    
    """
    await cur.execute(get_product_rate_query, {"product_id": product_id})
    product_rate = await cur.fetchone()
    if not product_rate:
        raise ResourceNotFoundException("Product Id Not Found")
    return product_rate["rate"]


async def get_product_code(latest_product_code: str):
    product_code = latest_product_code.split("-")[1]
    product_code = int(product_code) + 1
    return f"SP-{str(product_code).zfill(8)}"


async def get_product_data(cur: AsyncCursor[DictRow], product_id: int):
    get_product_rate_query = """
    SELECT
        p.product_code,
        p.product_name,
        touch_percentage,
        COALESCE(p.sales_va_percentage, 0) AS sales_va_percentage,
        p.vendor_id,
        COALESCE(p.minimum_va_percentage, 0) AS minimum_va_percentage,
        p.piece_count
    FROM 
        product p 
   
    WHERE 
        p.id = %(product_id)s
    """
    await cur.execute(get_product_rate_query, {"product_id": product_id})
    return await cur.fetchone()


async def get_product_weight_data(
    cur: AsyncCursor[DictRow],
    product_id: int,
    payload_amount: ProductSplitRequest,
    line_item: LineItem,
):
    get_product_weight_data_query = """
    SELECT 
        SUM(pmw.weight) AS weight,
        SUM(pmw.quantity) AS quantity,
        m.material_code as material_type,
        p.product_code as from_product_code
       
    FROM 
        product_material pw
    LEFT JOIN
        product_material_weight pmw ON pmw.product_material_id = pw.id
    LEFT JOIN 
        product p on p.id = pw.product_id
    LEFT JOIN 
        material m on m.id = pw.material_id
    WHERE 
        product_id = %(product_id)s
    GROUP BY 
        m.material_code, p.product_code, m.type, pw.product_id
    HAVING 
        SUM(pmw.weight) > 0
    ORDER BY 
        SUM(pmw.weight) DESC
    """

    # Fetch raw weight data
    await cur.execute(get_product_weight_data_query, {"product_id": product_id})
    result = await cur.fetchall()

    # product_value = line_item.metal_value + line_item.stone_value
    # metal_percentage = line_item.metal_value / product_value
    # product_value -= line_item.sales_va_amount
    # va = line_item.sales_va_percentage
    data = []

    remaining_weight = {row["material_type"]: Decimal(row["weight"]) for row in result}
    for index, amount in enumerate(payload_amount.amount):
        # amount_percentage = Decimal(amount) / Decimal(product_value)
        # if va != 0.0:
        #     va_amount = Decimal(amount) * Decimal(1 - va / 100)
        #     amount = Decimal(amount) - va_amount
        ratio = Decimal(amount) / Decimal(sum(payload_amount.amount))

        split_result = []

        for row in result:
            material = row["material_type"]
            weight = Decimal(row["weight"])

            # Calculate split weight
            if index == len(payload_amount.amount) - 1:
                split_weight = remaining_weight[material]
            else:
                split_weight = weight * ratio
                remaining_weight[material] -= split_weight

            # Prepare split row
            split_row = {
                **row,
                "weight": float(split_weight),
                "quantity": row["quantity"] if index == 0 else 0,
            }

            split_result.append(split_row)

        data.append(split_result)

    return data


async def get_product_attributes(cur: AsyncCursor[DictRow], product_id: int):
    get_product_attributes_query = """
    SELECT
        attribute_code,value
    FROM
        product_attribute_value pav
    LEFT JOIN
        product_attribute pa on pa.id = pav.attribute_id
    WHERE
        product_id = %(product_id)s
    """

    await cur.execute(get_product_attributes_query, {"product_id": product_id})
    return await cur.fetchall()


async def get_product_template_id(cur: AsyncCursor[DictRow], product_name: str):
    get_template_id_query = """
    SELECT
        id
    FROM
        product_template
    WHERE
        product_template_code = %(product_name)s
"""
    await cur.execute(get_template_id_query, {"product_name": product_name})
    template_id = await cur.fetchone()
    return template_id["id"]


async def update_product_location(cur: AsyncCursor[DictRow], product_id: int):
    update_product_location_query = """
    UPDATE 
        product_location
    SET 
        end_time = now(),
        product_out_reason = 'HOLLOW'
    WHERE 
        product_id = %(product_id)s AND end_time = '2100-01-01 00:00:00+00';
    """
    await cur.execute(update_product_location_query, {"product_id": product_id})

    insert_product_location_query = """
    INSERT INTO product_location
        (product_id, location_id)
    VALUES
        (%(product_id)s, %(location_id)s)
    """
    await cur.execute(
        insert_product_location_query,
        {"product_id": product_id, "location_id": None},
    )


async def get_product_rate(
    payload: List[MaterialTransferData],
    material_rates: List[Material],
    va_percentage: float,
):
    product_rate_stone = 0
    product_rate_metal = 0
    rate = 0
    for data in payload:
        for material in material_rates:
            if material.code == data.material_type:
                rate = material.rate
        if data.material_type in ["DIA", "PRC", "UNC", "OTS", "PLK"]:
            product_rate_stone += data.weight * rate
        else:
            product_rate_metal += data.weight * rate
    return round(
        product_rate_stone + (product_rate_metal * (1 + (va_percentage / 100))), 2
    )


def _split_line_item_by_ratio(item_to_split: LineItem, split_ratio: Decimal):
    """
    Splits a single LineItem into two based on a given ratio (0.0 to 1.0),
    ensuring perfect conservation of weight.
    """
    if not (Decimal(0) < split_ratio < Decimal(1)):
        raise ValueError("Split ratio must be between 0 and 1.")

    item_for_current_bill = deepcopy(item_to_split)
    remainder_item = deepcopy(item_to_split)

    # Use direct subtraction on material weights for perfect conservation
    for i, original_material in enumerate(item_to_split.materials):
        if original_material.weight and original_material.weight > 0:
            original_weight = Decimal(str(original_material.weight))
            part1_weight = (original_weight * split_ratio).quantize(
                Decimal("1e-6"), rounding=ROUND_HALF_UP
            )
            item_for_current_bill.materials[i].weight = float(part1_weight)
            remainder_weight = original_weight - part1_weight
            remainder_item.materials[i].weight = float(remainder_weight)
            if remainder_weight <= Decimal("0.0001"):
                item_for_current_bill.materials[i].quantity = original_material.quantity
            else:
                item_for_current_bill.materials[i].quantity = 0

    return item_for_current_bill, remainder_item


def _calculate_split_plan(
    original_invoice: Invoice, amounts: List[float]
) -> List[Invoice]:
    """
    Calculates the logical distribution of line items across new invoices using an
    algorithm. Returns a list of complete, in-memory Invoice objects
    representing the final state of each bill.
    """
    products_splited = []
    item_pool = sorted(
        deepcopy(original_invoice.line_items),
        key=lambda item: item.product_value,
        reverse=True,
    )
    final_invoice_plans: List[Invoice] = []

    for index, target_amount in enumerate(amounts):
        shell_dict = original_invoice.model_dump()
        if index > 0:
            shell_dict.update(
                {
                    "repurchase": None,
                    "sales_return": None,
                    "customer_advances": [],
                    "customer_plans": [],
                    "customer_plan_benefit_amount": 0.0,
                    "advance_benefit_amount": 0.0,
                    "customer_id": None,
                    "total_advance_benefit_amount": None,
                    "total_advance_deduction_amount": None,
                    "total_customer_plan_benefit_amount": None,
                    "total_customer_plan_deduction_amount": None,
                    "sales_return_deduction": 0,
                    "repurchase_deduction": 0,
                    "sales_return_benefit": 0,
                    "sales_return_discount": None,
                    "customer_advance_benefit_amount": 0,
                }
            )
        shell_dict["round_off_amount"] = 0.0
        shell_dict["line_items"] = []

        target_decimal = Decimal(str(target_amount))
        packed_items_for_this_bill = []

        still_packing = True
        while still_packing:
            current_bill_value = Invoice.model_validate(
                {
                    **shell_dict,
                    "line_items": [i.model_dump() for i in packed_items_for_this_bill],
                }
            ).net_amount
            value_needed = target_decimal - Decimal(str(current_bill_value))

            best_fit = None
            for item in item_pool:
                item_value = (
                    Invoice.model_validate(
                        {**shell_dict, "line_items": [item.model_dump()]}
                    ).net_amount
                    - Invoice.model_validate(shell_dict).net_amount
                )
                if Decimal(str(item_value)) <= value_needed:
                    best_fit = item

            if best_fit:
                packed_items_for_this_bill.append(best_fit)
                item_pool.remove(best_fit)
            else:
                still_packing = False

        # Split best remaining item
        current_bill_value = Invoice.model_validate(
            {
                **shell_dict,
                "line_items": [i.model_dump() for i in packed_items_for_this_bill],
            }
        ).net_amount
        value_needed = target_decimal - Decimal(str(current_bill_value))

        if value_needed > Decimal("0.01") and item_pool:
            item_to_split = item_pool.pop(0)
            split_product = item_to_split.product_id
            if split_product not in products_splited and item_to_split.is_box == False:
                products_splited.append(split_product)
            value_with_item = Invoice.model_validate(
                {
                    **shell_dict,
                    "line_items": [i.model_dump() for i in packed_items_for_this_bill]
                    + [item_to_split.model_dump()],
                }
            ).net_amount
            item_net_contribution = Decimal(str(value_with_item)) - Decimal(
                str(current_bill_value)
            )

            if item_net_contribution > Decimal("0.01"):
                # fixed_benefits = (
                #     Decimal(str(shell_dict.get("advance_benefit_amount") or 0))
                #     + Decimal(str(shell_dict.get("customer_plan_benefit_amount") or 0))
                #     + Decimal(
                #         str(shell_dict.get("customer_advance_benefit_amount") or 0)
                #     )
                # )
                if not packed_items_for_this_bill:
                    # tax_rate = Decimal("0.03")
                    tax_multiplier = Decimal("1.03")
                    # tax_drag_on_benefit = fixed_benefits * tax_rate
                    required_product_value = value_needed / tax_multiplier
                    item_product_value = Decimal(str(item_to_split.product_value))

                    if item_product_value > 0:
                        split_ratio = required_product_value / item_product_value
                    else:
                        split_ratio = Decimal(0)
                else:
                    split_ratio = value_needed / item_net_contribution
                if Decimal(0) < split_ratio < Decimal(1):
                    part1, part2 = _split_line_item_by_ratio(item_to_split, split_ratio)
                    packed_items_for_this_bill.append(part1)
                    item_pool.insert(0, part2)

        # Finalize this bill plan
        shell_dict["line_items"] = [
            item.model_dump() for item in packed_items_for_this_bill
        ]
        final_shell = Invoice.model_validate(shell_dict)
        current_net_amount = Decimal(str(final_shell.net_amount))
        final_round_off = float(
            (target_decimal - current_net_amount).quantize(
                Decimal("0.01"), rounding=ROUND_HALF_UP
            )
        )
        shell_dict["round_off_amount"] = final_round_off

        final_invoice_plans.append(Invoice.model_validate(shell_dict))

    return final_invoice_plans, products_splited


async def _create_new_split_product_in_db(
    cur: AsyncCursor[DictRow],
    item: LineItem,
    user: UserJWTPayload,
    material_transfer_id: int,
):
    """
    Creates a new product record for a split item, updates inventory by reducing
    the parent's weight, and returns the new product's ID and code.
    """
    if not any(m.type == "METAL" for m in item.materials):
        raise BadRequestException(
            "A split item must contain at least one metal material."
        )

    ##--fetching existing attributes from parent box item--##
    fetch_parent_product_attribute_values = """
    SELECT
        attribute_id,
        product_attribute_enum_value_id,
        type,
        value
    FROM
        product_attribute_value
    WHERE
        product_id=%(parent_product_id)s
    """
    await cur.execute(
        fetch_parent_product_attribute_values, {"parent_product_id": item.product_id}
    )
    parent_product_attributes = await cur.fetchall()

    create_product_query = """
    INSERT INTO
        product
        (
            product_code,
            product_name, 
            sales_va_percentage,
            is_box,
            piece_count,
            touch_percentage, 
            is_barcoded, 
            parent_product_id,
            minimum_va_percentage
        ) 
    VALUES 
        (
            %(product_code)s, 
            %(product_name)s, 
            %(sales_va_percentage)s, 
            FALSE,
            %(piece_count)s, 
            %(touch_percentage)s,
            FALSE, 
            %(parent_product_id)s,
            %(minimum_va_percentage)s
        ) 
    RETURNING id;
    """
    new_product_code = f"SP_{''.join(random.choices(string.digits, k=6))}"

    await cur.execute(
        create_product_query,
        {
            "product_code": new_product_code,
            "product_name": item.product_name,
            "sales_va_percentage": item.sales_va_percentage,
            "piece_count": item.piece_count,
            "touch_percentage": item.touch_percentage,
            "parent_product_id": item.product_id,
            "minimum_va_percentage": item.minimum_va_percentage,
        },
    )
    new_product_id = (await cur.fetchone())["id"]
    for material in item.materials:
        if not material.weight or material.weight <= 0:
            continue
        select_material_query = """
        SELECT 
            id
        FROM 
            material 
        WHERE material_code = %(code)s
        """
        await cur.execute(select_material_query, {"code": material.code})
        material_id = (await cur.fetchone())["id"]
        select_product_material_query = """
        SELECT 
            id 
        FROM 
            product_material
        WHERE 
            product_id = %(p_id)s AND material_id = %(m_id)s
        """
        await cur.execute(
            select_product_material_query,
            {"p_id": item.product_id, "m_id": material_id},
        )
        old_pm_id = (await cur.fetchone())["id"]

        insert_into_material_weight_query = """
        INSERT
            INTO 
        product_material_weight 
            (
                product_material_id, weight, quantity
            ) 
        VALUES 
            (
                %(pm_id)s, %(w)s, %(q)s
            )
        RETURNING id
        """
        await cur.execute(
            insert_into_material_weight_query,
            {"pm_id": old_pm_id, "w": -material.weight, "q": -(material.quantity or 0)},
        )
        source_product_weight_id = await cur.fetchone()

        get_purchase_rate_and_sale_rate = """
        SELECT 
            purchase_rate,
            sale_rate
        FROM
            product_material
        WHERE
            id = %(pm_id)s
        """
        await cur.execute(get_purchase_rate_and_sale_rate, {"pm_id": old_pm_id})
        material_data = await cur.fetchone()

        insert_material_query = """
        INSERT 
            INTO 
        product_material 
            (
                product_id, 
                material_id,
                purchase_rate,
                sale_rate
            ) 
        VALUES
            (
                %(p_id)s, 
                %(m_id)s,
                %(purchase_rate)s,
                %(sale_rate)s
            )
        RETURNING id
        """
        await cur.execute(
            insert_material_query,
            {
                "p_id": new_product_id,
                "m_id": material_id,
                "purchase_rate": material_data["purchase_rate"],
                "sale_rate": material_data["sale_rate"],
            },
        )
        new_pm_id = (await cur.fetchone())["id"]
        material.product_material_id = new_pm_id
        insert_into_product_material_weight_query = """
        INSERT
            INTO 
        product_material_weight 
            (product_material_id, weight, quantity)
        VALUES 
            (%(pm_id)s, %(w)s, %(q)s)
        RETURNING id
        """
        await cur.execute(
            insert_into_product_material_weight_query,
            {"pm_id": new_pm_id, "w": material.weight, "q": material.quantity},
        )

        destination_product_weight_id = await cur.fetchone()
        create_material_transfer_product_query = """
        INSERT INTO material_transfer_product
        (
            material_transfer_id,
            source_product_material_weight_id,
            destination_product_material_weight_id
        )
        VALUES (
            %(material_transfer_id)s,
            %(source_product_material_weight_id)s,
            %(destination_product_material_weight_id)s 
        )
        """
        await cur.execute(
            create_material_transfer_product_query,
            {
                "material_transfer_id": material_transfer_id,
                "source_product_material_weight_id": source_product_weight_id["id"],
                "destination_product_material_weight_id": destination_product_weight_id[
                    "id"
                ],
            },
        )

    insert_into_product_location = """
    INSERT INTO product_location
    (
        product_id,
        location_id,
        end_time,
        product_in_reason
    )
    VALUES
    (
        %(product_id)s,
        %(location_id)s,
        '2100-01-01 00:00:00+00',
        'CONVERSION'

    )
    """
    await cur.execute(
        insert_into_product_location,
        {"product_id": new_product_id, "location_id": user.user.branch_id},
    )
    insert_product_attribute_value = """
    INSERT INTO product_attribute_value (product_id,attribute_id,product_attribute_enum_value_id,type,value)
    VALUES (
        %(product_id)s,
        %(attribute_id)s,
        %(product_attribute_enum_value_id)s,
        %(type)s,
        %(value)s
        )
    """
    ##--inserting parent product attributes for new product--##
    if parent_product_attributes:
        params = []
        for attribute in parent_product_attributes:
            params.append(
                {
                    "product_id": new_product_id,
                    "attribute_id": attribute["attribute_id"],
                    "product_attribute_enum_value_id": attribute[
                        "product_attribute_enum_value_id"
                    ],
                    "type": attribute["type"],
                    "value": attribute["value"],
                }
            )
        await cur.executemany(insert_product_attribute_value, params)
    else:
        raise BadRequestException(
            "Box item does not have required attributes to infer for inserting new product"
        )

    return new_product_id, new_product_code


async def get_material_transfer_id(cur: AsyncCursor[DictRow], employee_id: int):
    get_material_transfer_id_query = """
    
    INSERT INTO material_transfer
    (
        created_by_employee_id
    )
    VALUES (
        %(employee_id)s
    )
    RETURNING id
    """
    await cur.execute(get_material_transfer_id_query, {"employee_id": employee_id})
    material_transfer_data = await cur.fetchone()
    if not material_transfer_data:
        raise BadRequestException("Failed to create material transfer record.")
    return material_transfer_data["id"]


async def invoice_split(
    async_pool: AsyncConnectionPool,
    payload: ProductSplitRequest,
    request: UserJWTPayload,
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            get_draft_data_query = """
            SELECT 
                json_data
            FROM 
                draft_form 
            WHERE 
                id = %(draft_id)s AND form_type='INVOICE'
            """
            await cur.execute(get_draft_data_query, {"draft_id": payload.draft_id})
            invoice_record = await cur.fetchone()
            if not invoice_record:
                raise BadRequestException(
                    f"Draft with ID {payload.draft_id} not found."
                )

            original_invoice = Invoice.model_validate(invoice_record["json_data"])

            # if any(line_item.is_box for line_item in original_invoice.line_items):
            #     raise BadRequestException(
            #         "Cannot split invoice because one or more line items are box items"
            #     )

            original_products = {
                p.product_id: deepcopy(p) for p in original_invoice.line_items
            }
            products_splited = []
            material_transfer_mapping = {}
            # Get the line_item for the split
            planned_invoices, products_splited = _calculate_split_plan(
                original_invoice, payload.amount
            )

            draft_invoice_list = []

            # Execute the plan, persisting each bill to the database
            for index, planned_bill in enumerate(planned_invoices):
                final_line_items_for_this_bill = []

                #  Create any new products required for this bill
                for item in planned_bill.line_items:
                    original_item = original_products.get(item.product_id)
                    is_split = False
                    if original_item:
                        # A way to check for a split is to see if the weight has been reduced
                        if item.materials[0].weight < original_item.materials[0].weight:
                            is_split = True

                    if is_split:
                        parent_product_id = item.product_id
                        if parent_product_id not in material_transfer_mapping:
                            employee_id = await get_employee_id(
                                cur, request.state.user.user_id
                            )
                            material_transfer_id = await get_material_transfer_id(
                                cur, employee_id
                            )
                            material_transfer_mapping[parent_product_id] = (
                                material_transfer_id
                            )
                        #  create a new product in the DB
                        transfer_id = material_transfer_mapping[parent_product_id]
                        new_id, new_code = await _create_new_split_product_in_db(
                            cur, item, request.state, transfer_id
                        )
                        # Update the item in memory with its new, real ID and code
                        item.product_id = new_id
                        item.product_code = new_code
                    new_gross_weight = sum(m.weight or 0 for m in item.materials)
                    item.gross_weight = float(round(new_gross_weight, 3))
                    final_line_items_for_this_bill.append(item)

                # Update the planned bill with the final, correct line items
                planned_bill.line_items = final_line_items_for_this_bill

                # Create or Update the Draft Invoice in the database
                if index == 0:
                    # The first bill updates the original draft
                    current_draft_id = payload.draft_id
                else:
                    # Subsequent bills create new drafts
                    new_draft_record = await create_draft_invoice_function(
                        cur, request.state.user
                    )
                    current_draft_id = new_draft_record["id"]
                    draft_invoice_list.append(current_draft_id)

                # Persist the final state of this bill to its draft record

                final_json_data = planned_bill.model_dump_json()
                await cur.execute(
                    "UPDATE draft_form SET json_data = %(json_data)s WHERE id = %(draft_id)s",
                    {"json_data": final_json_data, "draft_id": current_draft_id},
                )
            # make splited product HOLLOW
            for product_id in products_splited:
                await update_product_location(cur, product_id)
            return draft_invoice_list


async def if_cash_limit_exceeded(
    cur: AsyncCursor[DictRow], customer_id: int, amount: float
):
    # get_customer_payments = """
    # SELECT t.created_at, t.amount, tg.transaction_mode
    # FROM customer
    # LEFT JOIN transaction t ON t.chart_of_account_id = customer.chart_of_account_id
    # LEFT JOIN transaction_group tg on tg.id = t.transaction_group_id
    # WHERE customer.id = %(customer_id)s
    # AND tg.transaction_mode = 'CASH'
    # AND amount < 0
    # """
    # await cur.execute(
    #     get_customer_payments,
    #     {"customer_id": customer_id},
    # )
    data = {}  # await cur.fetchall()
    paid_today = 0
    ist_zone = ZoneInfo("Asia/Kolkata")
    today_ist = datetime.now(ist_zone).date()
    for i in data:
        i["created_at"] = i["created_at"].astimezone(ist_zone)
        is_today = i["created_at"].date() == today_ist
        if is_today:
            paid_today -= abs(i["amount"])
    if (abs(paid_today) + abs(amount)) > 200000:
        message = f"Customer has already paid {round(abs(paid_today), 2)} today by cash, and the current amount exceeds the daily limit of 2 Lakhs"
    else:
        message = False
    return message


# API to insert token advance to draft invoice
# async def insert_token_advance(
#     draft_id: int, request: Request, token_advance_request: CreateTokenAdvanceRequest
# ):
#     async with async_pool.connection() as conn:
#         async with conn.cursor() as cur:
#             get_customer_id = """
#             SELECT
#              invoice_data
#             FROM
#                 draft_invoice
#             WHERE
#                 id= %(draft_id)s
#             """
#             await cur.execute(get_customer_id, {"draft_id": draft_id})
#             result = await cur.fetchone()
#             invoice_data = result["invoice_data"]
#             customer_id = invoice_data["customer_id"]
#             if not customer_id:
#                 raise BadRequestException("No customer_id found in the invoice data")
#             invoice_obj = Invoice.model_validate(invoice_data)
#             for i in token_advance_request.token_advance_id:
#                 get_token_advance_query = """
#                 SELECT
#                     customer_id, amount
#                 FROM
#                     token_advance
#                 WHERE
#                     id = %(token_advance_id)s
#                 """
#                 await cur.execute(get_token_advance_query, {"token_advance_id": i})
#                 token_advance_data = await cur.fetchone()
#                 if not token_advance_data["amount"]:
#                     raise BadRequestException("Invalid token advance id")
#                 if token_advance_data["customer_id"] != customer_id:
#                     raise BadRequestException(
#                         "Token advance id does not belong to the customer"
#                     )
#                 for inserted_token in invoice_data["token_advances"]:
#                     if inserted_token["token_advance_id"] == i:
#                         raise BadRequestException("Token advance is already added")
#                 token_advance_obj = TokenAdvance(
#                     token_advance_id=i, amount=token_advance_data["amount"]
#                 )
#                 invoice_obj.add_token_advance(token_advance_obj)
#             invoice_json_str = invoice_obj.model_dump_json()
#             update_invoice_data_query = """
#             UPDATE
#                 draft_invoice
#             SET
#                 invoice_data = %(invoice_data)s
#             WHERE
#                 id = %(draft_id)s
#             RETURNING invoice_data
#             """

#             await cur.execute(
#                 update_invoice_data_query,
#                 {"invoice_data": invoice_json_str, "draft_id": draft_id},
#             )
#             updated_data = await cur.fetchone()

#             return updated_data


# async def delete_token_advance(
#     request: Request, draft_invoice_id: int, token_advance_index: int
# ):
#     async with async_pool.connection() as conn:
#         async with conn.cursor() as cur:
#             fetch_invoice_data_query = """
#             SELECT
#                 invoice_data
#             FROM
#                 draft_invoice
#             WHERE
#                 id= %(draft_id)s
#             """
#             await cur.execute(fetch_invoice_data_query, {"draft_id": draft_invoice_id})
#             result = await cur.fetchone()
#             invoice_data = Invoice.model_validate(result["invoice_data"])
#             invoice_data.remove_token_advance(token_advance_index)

#             update_invoice_data = """
#             UPDATE draft_invoice
#             SET invoice_data=%(invoice_data)s
#             WHERE
#                 id =%(draft_invoice_id)s
#             """
#             await cur.execute(
#                 update_invoice_data,
#                 {
#                     "invoice_data": invoice_data.model_dump_json(),
#                     "draft_invoice_id": draft_invoice_id,
#                 },
#             )

#             return json.loads(invoice_data.model_dump_json())


# async def refund_info_add(draft_invoice_id: int, refund_info: RefundInfoRequest):
#     async with async_pool.connection() as conn:
#         async with conn.cursor() as cur:
#             fetch_invoice_data_query = """
#                 SELECT
#                     json_data
#                 FROM
#                     draft_form
#                 WHERE
#                     id= %(draft_invoice_id)s AND form_type='INVOICE'
#                 """
#             await cur.execute(
#                 fetch_invoice_data_query, {"draft_invoice_id": draft_invoice_id}
#             )
#             result = await cur.fetchone()
#             if not result:
#                 raise BadRequestException("Draft Not Found")

#             invoice_data = Invoice.model_validate(result["json_data"])
#             if refund_info:
#                 refund_info_invoice = RefundInfo(
#                     due_date=refund_info.due_date,
#                     bank_account=BankAccount.model_validate(
#                         refund_info.bank_account.model_dump()
#                     ),
#                 )
#                 invoice_data.refund_info = refund_info_invoice

#             else:
#                 refund_info_invoice = None
#                 invoice_data.refund_info = refund_info_invoice
#                 for x, method in enumerate(invoice_data.refund_methods):
#                     if method.refund_type == "NEFT":
#                         invoice_data.remove_refund_method(x)

#             update_invoice_data = """
#             UPDATE draft_form
#             SET json_data=%(json_data)s
#             WHERE
#                 id =%(draft_invoice_id)s AND form_type='INVOICE'
#             """
#             await cur.execute(
#                 update_invoice_data,
#                 {
#                     "json_data": invoice_data.model_dump_json(),
#                     "draft_invoice_id": draft_invoice_id,
#                 },
#             )

#             return json.loads(invoice_data.model_dump_json())


async def add_refund_method(
    async_pool: AsyncConnectionPool,
    draft_invoice_id: int,
    refund_method: List[RefundMethodRequest],
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            fetch_invoice_data_query = """
                SELECT
                    json_data
                FROM
                    draft_form
                WHERE
                    id= %(draft_invoice_id)s AND form_type='INVOICE'
                """
            await cur.execute(
                fetch_invoice_data_query, {"draft_invoice_id": draft_invoice_id}
            )
            result = await cur.fetchone()
            if not result:
                raise BadRequestException("Draft Not Found")
            invoice_data = Invoice.model_validate(result["json_data"])
            for i in refund_method:
                invoice_data.add_refund_method(
                    RefundMethod.model_validate(i.model_dump())
                )

            data = await invoice_draft_check(cur, draft_invoice_id)

            if data:
                raise BadRequestException(
                    "Can't edit the data. Invoice already created."
                )

            update_invoice_data = """
            UPDATE draft_form
            SET json_data=%(json_data)s
            WHERE 
                id =%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                update_invoice_data,
                {
                    "json_data": invoice_data.model_dump_json(),
                    "draft_invoice_id": draft_invoice_id,
                },
            )

            return json.loads(invoice_data.model_dump_json())


async def remove_refund_method(
    async_pool: AsyncConnectionPool, draft_invoice_id: int, index: int
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            data = await invoice_draft_check(cur, draft_invoice_id)

            if data:
                raise BadRequestException(
                    "Can't edit the data. Invoice already created."
                )

            fetch_invoice_data_query = """
                SELECT
                    json_data
                FROM
                    draft_form
                WHERE
                    id= %(draft_invoice_id)s AND form_type='INVOICE'
                """
            await cur.execute(
                fetch_invoice_data_query, {"draft_invoice_id": draft_invoice_id}
            )
            result = await cur.fetchone()
            if not result:
                raise BadRequestException("Draft Not Found")
            invoice_data = Invoice.model_validate(result["json_data"])
            invoice_data.remove_refund_method(index)
            update_invoice_data = """
            UPDATE draft_form
            SET json_data=%(json_data)s
            WHERE 
                id =%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                update_invoice_data,
                {
                    "json_data": invoice_data.model_dump_json(),
                    "draft_invoice_id": draft_invoice_id,
                },
            )

            return json.loads(invoice_data.model_dump_json())


async def product_materials(
    async_pool: AsyncConnectionPool, request: UserJWTPayload, product_code: str
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            get_product_detail = """
            SELECT 
                ARRAY_AGG(DISTINCT m.material_code) AS material_codes 
            FROM 
                product_weight pw
            LEFT JOIN 
                material m ON m.id = pw.material_id
            WHERE 
                pw.product_id = (
                    SELECT id FROM product WHERE product_code = %(product_code)s
                );
            """
            await cur.execute(get_product_detail, {"product_code": product_code})
            data = await cur.fetchall()
            if not data[0]["material_codes"]:
                raise BadRequestException("Product Not Found")
            return data[0]


async def get_product_details(
    cur: AsyncCursor[DictRow], product_code: str, branch_id: int
):
    get_product_data = """
    SELECT
        p.id,
        p.product_name,
        p.minimum_va_percentage,
        p.sales_va_percentage,
        p.piece_count,
        p.is_box,
        p.mrp_amount,
        p.touch_percentage,
        p.is_barcoded,
        MAX(typ.value) AS product_type_code,
        (SELECT SUM(pmw.weight)
        FROM product_material pm
        LEFT JOIN
        product_material_weight pmw on pmw.product_material_id = pm.id
        WHERE pm.product_id = p.id) AS total_product_material,
        json_agg(
            json_build_object(
                'code', sub.material_code,
                'type', sub.type,
                'weight', sub.total_weight,
                'quantity', sub.total_quantity,
                'rate', sub.rate,
                'sale_rate', sub.sale_rate,
                'material_rate', sub.material_rate,
                'product_material_id', sub.product_material_id,
                'sale_rate_offset', sub.sale_rate_offset
            )
        ) AS material_details
    FROM 
        product p
    LEFT JOIN (
        SELECT 
            pm.product_id,
            m.material_code,
            m.type,
            SUM(pmw.weight) AS total_weight,
            SUM(pmw.quantity) AS total_quantity,
            AVG(mr.rate) AS rate,
            AVG(pm.sale_rate) AS sale_rate,
            AVG(
                    CASE 
                        WHEN pm.sale_rate IS NOT NULL THEN pm.sale_rate
                        ELSE mr.rate
                    END + COALESCE(pm.sale_rate_offset, 0)
                ) AS material_rate,
            pm.id AS product_material_id,
            pm.sale_rate_offset
        FROM
            product_material pm
        JOIN
            material m ON m.id = pm.material_id
        LEFT JOIN
            product_material_weight pmw on pmw.product_material_id = pm.id
        LEFT JOIN
            material_rate mr ON mr.material_id = m.id AND mr.end_time = '2100-01-01 00:00:00+00' AND mr.location_id = %(branch_id)s
        GROUP BY
            pm.product_id, m.material_code, m.type, pm.id
    ) sub ON sub.product_id = p.id
    LEFT JOIN (
            SELECT
                pav.product_id,
                pev.value
            FROM
                product_attribute_value pav
            LEFT JOIN product_attribute_enum_value pev
                ON pev.id = pav.product_attribute_enum_value_id
            WHERE
                pav.attribute_id = (
                    SELECT id FROM product_attribute
                    WHERE attribute_code = 'TYP'
                )
        ) typ ON typ.product_id = p.id
    WHERE
        p.product_code = %(product_code)s
    AND EXISTS (
        SELECT 1 FROM product_location pl 
        WHERE pl.product_id = p.id AND pl.location_id = %(branch_id)s AND pl.end_time = '2100-01-01 00:00:00+00'
    )
    GROUP BY
        p.id, p.product_name, p.sales_va_percentage, p.piece_count;
    """

    await cur.execute(
        get_product_data,
        {"product_code": product_code, "branch_id": branch_id},
    )
    product_data = await cur.fetchone()
    return product_data


async def add_collection_reminder(
    async_pool: AsyncConnectionPool,
    request: UserJWTPayload,
    draft_invoice_id: int,
    collection_reminder: CollectionReminder,
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            get_draft_invoice_query = """
            SELECT json_data
            FROM draft_form
            WHERE id = %(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                get_draft_invoice_query, {"draft_invoice_id": draft_invoice_id}
            )
            result = await cur.fetchone()
            if not result:
                raise BadRequestException("Draft Not Found")
            invoice_data = Invoice.model_validate(result["json_data"])
            invoice_data.collection_reminder = collection_reminder

            data = await invoice_draft_check(cur, draft_invoice_id)

            if data:
                raise BadRequestException(
                    "Can't edit the data. Invoice already created."
                )

            update_invoice_data = """
            UPDATE draft_form
            SET json_data=%(json_data)s
            WHERE 
                id =%(draft_invoice_id)s AND form_type='INVOICE'
            """
            await cur.execute(
                update_invoice_data,
                {
                    "json_data": invoice_data.model_dump_json(),
                    "draft_invoice_id": draft_invoice_id,
                },
            )

            return json.loads(invoice_data.model_dump_json())


async def move_draft_invoice_to_target(
    async_pool: AsyncConnectionPool, to_draft_invoice_id: int, line_item: LineItem
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            fetch_invoice_data_query = """
                SELECT
                    json_data
                FROM
                    draft_form
                WHERE
                    id= %(draft_invoice_id)s AND form_type='INVOICE'
                """
            await cur.execute(
                fetch_invoice_data_query, {"draft_invoice_id": to_draft_invoice_id}
            )
            result = await cur.fetchone()
            if result is None:
                raise BadRequestException("Draft Not Found")
            invoice_data = Invoice.model_validate(result["json_data"])

            invoice_data.add_line_item()
            index = len(invoice_data.line_items) - 1
            invoice_data.line_items[index] = line_item
            invoice_data_json = invoice_data.model_dump_json()

            data = await invoice_draft_check(cur, to_draft_invoice_id)

            if data:
                raise BadRequestException(
                    "Can't move the draft. Invoice already created."
                )

            update_invoice_data_query = """
                UPDATE draft_form
                SET json_data=%(json_data)s
                WHERE
                    id= %(draft_invoice_id)s AND form_type='INVOICE'
                """
            await cur.execute(
                update_invoice_data_query,
                {
                    "json_data": invoice_data_json,
                    "draft_invoice_id": to_draft_invoice_id,
                },
            )
            return {"message": "Draft Invoice Moved Successfully"}


async def get_branch_code(cur: AsyncCursor[DictRow], location_id: int):
    await cur.execute(
        """
        SELECT branch_code
        FROM branch
        WHERE id = %(location_id)s
        """,
        {"location_id": location_id},
    )

    branch_data = await cur.fetchone()
    if not branch_data:
        raise BadRequestException("Invalid branch")
    return branch_data["branch_code"]


async def create_sales_return_products(
    cur: AsyncCursor[DictRow],
    branch_id: int,
    sales_discount_products: List[SalesReturnProduct],
):
    for product in sales_discount_products:
        product_code = await get_product_creation_code_sales_return(cur)
        create_product_query = """
            INSERT INTO product
            (
                product_code,
                product_name,
                sales_va_percentage,
                is_box,
                piece_count,
                touch_percentage,
                is_barcoded
                )
            VALUES
            (
                %(product_code)s,
                %(product_name)s,
                %(sales_va_percentage)s,
                FALSE,
                1,
                %(touch_percentage)s,
                TRUE
            )
            RETURNING ID, product_code;
            """

        await cur.execute(
            create_product_query,
            {
                "product_code": product_code,
                "product_name": product.product_name,
                "sales_va_percentage": product.sales_va_percentage,
                "touch_percentage": product.touch_percentage,
            },
        )
        product_id = await cur.fetchone()

        insert_into_product_material_weight = """
        INSERT INTO product_material_weight
        (
            product_material_id,
            weight,
            quantity
            
        )
        VALUES
        (
            %(product_material_id)s,
            %(weight)s,
            %(quantity)s
        )
        RETURNING id
        """

        insert_weight_into_product_material_query = """
        INSERT INTO product_material
        (
            product_id,
            material_id
            
        )
        VALUES
        (
            %(product_id)s,
            %(material_id)s
        )
        Returning id
        """

        for material in product.materials:
            if material.weight == 0:
                raise BadRequestException("Material weight cannot be zero")
            get_material_id_from_code = """
            SELECT
                id
            FROM
                material
            WHERE
                material_code = %(material_code)s
            """
            await cur.execute(
                get_material_id_from_code, {"material_code": material.code}
            )
            material_id = await cur.fetchone()

            await cur.execute(
                insert_weight_into_product_material_query,
                {
                    "product_id": product_id["id"],
                    "material_id": material_id["id"],
                    "sale_rate": material.rate,
                },
            )
            product_material_id = await cur.fetchone()

            await cur.execute(
                insert_into_product_material_weight,
                {
                    "product_material_id": product_material_id["id"],
                    "weight": material.weight,
                    "quantity": material.quantity,
                },
            )

        insert_into_product_location_previous_time = """
        INSERT INTO product_location
        (
            product_id,
            location_id,
            start_time,
            product_in_reason
        )
        VALUES
        (
            %(product_id)s,
            %(location_id)s,
            %(time_start)s,
            'SALES_RETURN'
        )
        """
        await cur.execute(
            insert_into_product_location_previous_time,
            {
                "product_id": product_id["id"],
                "location_id": branch_id,
                "time_start": datetime.now(),
            },
        )

        product_template_attributes = (
            await fetch_product_template_attributes_for_sales_return(
                cur, product.product_template_id
            )
        )

        insert_product_attribute_value_query = """
        INSERT INTO product_attribute_value (product_id,attribute_id,product_attribute_enum_value_id)
        VALUES (%(product_id)s,%(attribute_id)s,%(product_attribute_enum_value_id)s)
        """

        params = [
            {
                "product_id": product_id["id"],
                "attribute_id": product_attribute_value["product_attribute_id"],
                "product_attribute_enum_value_id": product_attribute_value[
                    "product_attribute_enum_value_id"
                ],
            }
            for product_attribute_value in product_template_attributes
        ]

        await cur.executemany(insert_product_attribute_value_query, params)


async def fetch_product_template_attributes_for_sales_return(
    cur: AsyncCursor[DictRow], product_template_id: int
):
    fetch_product_attribute_and_enum_values_of_template = """
        SELECT 
            product_attribute_id,
            product_attribute_enum_value_id
        FROM 
            product_template_attribute_value ptav
        JOIN
            product_template pt ON pt.id=ptav.product_template_id
        WHERE
            pt.id=%(product_template_id)s
        """

    await cur.execute(
        fetch_product_attribute_and_enum_values_of_template,
        {"product_template_id": product_template_id},
    )
    data = await cur.fetchall()
    return data


async def get_product_creation_code_sales_return(cur: AsyncCursor[DictRow]):
    fetch_last_product_code = """
    SELECT
        product_code
    FROM
        product
    WHERE
        is_barcoded=true and is_box=false
    ORDER BY
        product_code::int DESC LIMIT 1
    """
    await cur.execute(fetch_last_product_code)
    last_barcode = await cur.fetchone()
    if (
        last_barcode
        and last_barcode["product_code"]
        and last_barcode["product_code"].isnumeric()
    ):
        return int(last_barcode["product_code"]) + 1
    else:
        return 10000001


async def insert_into_sr_transaction_group(
    cur: AsyncCursor[DictRow], sales_return_id: int, transaction_group_ids: List[int]
):
    insert_into_sales_return_transaction_query = """
    INSERT INTO
        sales_return_transaction_group
    (
        sales_return_id,
        transaction_group_id
    )
    VALUES
    (
        %(sales_return_id)s,
        %(transaction_group_id)s
    )
    """
    for id in transaction_group_ids:
        await cur.execute(
            insert_into_sales_return_transaction_query,
            {
                "sales_return_id": sales_return_id,
                "transaction_group_id": id,
            },
        )


def _is_insurance_eligible(invoice_object: Invoice) -> bool:
    """Whether this invoice should carry a jewellery-insurance policy.

    Defers entirely to Invoice.is_insured, which already applies both the insurer's
    minimum taxable value and the user's explicit choice. Used for the stored
    invoice.is_insured column and for the issuance call, so the two cannot disagree.
    """
    return invoice_object.is_insured


async def _issue_invoice_insurance(
    cur: AsyncCursor[DictRow], invoice_code: str, invoice_object: Invoice
) -> bytes | None:
    """Issue a jewellery-insurance policy for a freshly created invoice and return the
    COI PDF bytes, which the caller stores as its own S3 object.

    Best-effort: returns None on any error, or if the certificate is not yet available
    (the vendor generates the COI asynchronously). Never raises — insurance must not
    break invoice creation.
    """
    try:
        if not invoice_object.customer:
            return None

        # The policy only applies from a taxable value of MIN_TAXABLE_VALUE upward, so
        # smaller invoices are skipped without troubling the vendor at all.
        taxable_value = invoice_object.taxable_value
        if taxable_value < MIN_TAXABLE_VALUE:
            logger.info(
                "Insurance skipped for invoice %s: taxable value %s below minimum %s",
                invoice_code,
                taxable_value,
                MIN_TAXABLE_VALUE,
            )
            return None

        config = get_config()
        if not is_affinity_configured(config):
            logger.warning(
                "Insurance skipped for invoice %s: AFFINITY_* config is not set",
                invoice_code,
            )
            return None

        built = await build_invoice_proposal(
            cur,
            invoice_code=invoice_code,
            invoice_object=invoice_object,
            # The sale is happening now, so the invoice's moment is the current one.
            invoice_moment=datetime.now(ZoneInfo("Asia/Kolkata")),
        )
        if built is None:
            return None
        proposal, email_diverted = built

        logger.info(
            "Insurance proposal for invoice %s: %s",
            invoice_code,
            json.dumps(proposal, default=str),
        )
        result = await issue_or_fetch_coi(config, proposal)
        # Every vendor payload for this invoice in one line, so a single occurrence in
        # production is enough to diagnose — we cannot keep retrying against live sales.
        logger.info(
            "Insurance raw vendor responses for invoice %s: %s",
            invoice_code,
            json.dumps(result.get("raw"), default=str),
        )
        logger.info(
            "Insurance for invoice %s: already_issued=%s status=%s policy_status=%s "
            "trace_id=%s premium=%s cert=%s cert_url=%s email_diverted=%s",
            invoice_code,
            result.get("already_issued"),
            result.get("status"),
            result.get("policy_status"),
            result.get("trace_id"),
            result.get("premium"),
            result.get("certificate_number"),
            result.get("certificate_url"),
            email_diverted,
        )
        return result.get("coi_pdf")
    except Exception:
        logger.exception("Insurance issuance failed for invoice %s", invoice_code)
        return None


async def regenerate_invoice_pdf(
    async_pool: AsyncConnectionPool,
    invoice_id: int,
    request: UserJWTPayload,
):
    async with async_pool.connection() as conn:
        async with conn.cursor() as cur:
            buffer, file_name = await generate_sales_bill_pdf(
                async_pool,
                invoice_id=invoice_id,
                user=request,
                show_va_percentage=True,
                show_va_amount=True,
                show_hsn=True,
                show_note=False,
            )
            pdf_bytes = buffer.getvalue()
            file_data = await upload_file(
                async_pool,
                file=pdf_bytes,
                file_name=file_name,
                mime="application/pdf",
                file_size=len(pdf_bytes),
                folder=INVOICE_PDF_FOLDER,
            )
            file_id = file_data["id"]
            existing_version_query = """
              SELECT version_no FROM invoice_file 
              WHERE invoice_id=%(invoice_id)s 
              ORDER BY id DESC LIMIT 1 
              """
            await cur.execute(existing_version_query, {"invoice_id": invoice_id})
            data = await cur.fetchone()
            if data:
                version_no = data["version_no"] + 1
            else:
                version_no = 1
            insert_query = """ INSERT INTO invoice_file 
                (version_no, invoice_id,file_id) 
                VALUES (%(version_no)s, %(invoice_id)s, %(file_id)s) 
                RETURNING id 
            """
            await cur.execute(
                insert_query,
                {
                    "version_no": version_no,
                    "invoice_id": invoice_id,
                    "file_id": file_id,
                },
            )
            file_invoice = await cur.fetchone()
            if not file_invoice:
                raise BadRequestException("Invoice file insert failed")
            return {"invoice id": invoice_id}


async def invoice_draft_check(cur: AsyncCursor[DictRow], draft_invoice_id: int):

    invoice_check = """
            SELECT *
            FROM invoice
            WHERE draft_form_id = %(draft_invoice_id)s
            """

    await cur.execute(invoice_check, {"draft_invoice_id": draft_invoice_id})

    data = await cur.fetchone()
    return data


async def insert_product_scan_log(
    cur: AsyncCursor[DictRow],
    product_id: int,
    branch_id: int,
    scanned_by_employee_id: int,
    customer_id: int,
):
    insert_product_scan_log_query = """
    INSERT INTO product_scan_log (
        product_id,
        branch_id,
        scanned_by_employee_id,
        customer_id
    )
    VALUES (
        %(product_id)s,
        %(branch_id)s,
        %(scanned_by_employee_id)s,
        %(customer_id)s
    )
    """
    await cur.execute(
        insert_product_scan_log_query,
        {
            "product_id": product_id,
            "branch_id": branch_id,
            "scanned_by_employee_id": scanned_by_employee_id,
            "customer_id": customer_id,
        },
    )
