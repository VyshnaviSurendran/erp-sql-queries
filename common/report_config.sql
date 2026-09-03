-----------------------------------report config----------------------------------------------------------------------------------
SELECT * FROM public.report_config where id = 62
ORDER BY id ASC 
-----------------------------------insert into report config----------------------------------------------------------------------
INSERT INTO public.report_config
    (report_code, report_name, icon_name, config, access_control_list, is_visible, group_name, config_type)
VALUES (
    'product-wise-incentive-report',
    'Product-wise Incentive Report',
    'HandCoins',
    '{
        "sort": [],
        "title": "Product-wise Incentive Report",
        "columns": [
            {"field": "invoice_date", "headerName": "Invoice Date", "valueFormatter": "formatDate"},
            {"field": "invoice_code", "headerName": "Invoice Code"},
            {"field": "customer_name", "headerName": "Customer Name"},
            {"field": "customer_phone", "headerName": "Customer Phone"},
            {"field": "sales_person", "headerName": "Sales Man"},
            {"field": "referral_person", "headerName": "Referral Person"},
            {"field": "type_value", "headerName": "Type"},
            {"field": "category_value", "headerName": "Category"},
            {"field": "style_value", "headerName": "Style"},
            {"field": "collection_value", "headerName": "Collection"},
            {"field": "gross_weight", "headerName": "Gross Weight", "valueFormatter": "toFixedThree"},
            {"field": "mc_percentage", "headerName": "MC%", "valueFormatter": "appendPercentage"},
            {"field": "product_value", "headerName": "Product Value", "valueFormatter": "prependRupees"},
            {"field": "branch_name", "headerName": "Branch Name"}
        ],
        "filters": [
            {"key1": "start_date", "key2": "end_date", "type": "date_range", "label": "Invoice Date Range"},
            {
		      "key": "location_ids",
		      "type": "async_multi_select",
		      "label": "Branch",
		      "async_options": {
		        "key": "id",
		        "value": "branch_name",
		        "endpoint": "branch/"
		      }
		    },
            {
		      "key": "sales_person_employee_id",
		      "type": "async_combobox",
		      "label": "Sales Person",
		      "async_options": {
		        "key": "employee_id",
		        "value": "first_name, last_name, employee_code",
		        "endpoint": "employee/?designation_code=SAE"
		      }
		    },
            {
		      "key": "user_id",
		      "type": "async_combobox",
		      "label": "Referral Employee",
		      "async_options": {
		        "key": "userId",
		        "value": "first_name, last_name, username",
		        "endpoint": "user/"
		      }
		    },
            {"key": "query", "type": "input", "label": "Search"},
            {
		      "key": "type_attribute_id",
		      "type": "async_combobox",
		      "label": "Type",
		      "async_options": {
		        "key": "id",
		        "value": "name",
		        "endpoint": "product-attribute/TYP/enum"
		      }
		    },
		    {
		      "key": "category_attribute_id",
		      "type": "async_combobox",
		      "label": "Category",
		      "async_options": {
		        "key": "id",
		        "value": "name",
		        "endpoint": "product-attribute/CTY/enum"
		      }
		    },
			{
		      "key": "style_attribute_id",
		      "type": "async_combobox",
		      "label": "Style",
		      "async_options": {
		        "key": "id",
		        "value": "name",
		        "endpoint": "product-attribute/STL/enum"
		      }
		    },
			{
		      "key": "collection_attribute_id",
		      "type": "async_combobox",
		      "label": "Collection",
		      "async_options": {
		        "key": "id",
		        "value": "name",
		        "endpoint": "product-attribute/COL/enum"
		      }
		    }
        ],
        "show_summary": true,
        "default_filters": {"start_date": "today_start", "end_date": "today_end"},
        "hide_pagination": false,
        "report_endpoint": "report/sales/product_wise_incentive",
        "summary_endpoint": "report/sales/product_wise_incentive/summary",
        "xl_report_download_endpoint": "report/sales/product_wise_incentive/xl"
    }'::jsonb,
    '["LSE"]'::jsonb,
    true,
    'Sales',
    'REPORT'
);
