-----------------------------------basic queries----------------------------------------------------------------------

select * from user_login where username like '%TRS%'

select * from user_designation where user_id = 1080

select * from designation where id = 58

select distinct(type) from chart_of_account

-----------------------------------invoice queries----------------------------------------------------------------------
select * from invoice 
where id = 193713
draft_form_id = 579043

select * from transfer where invoice_id = 193713

SELECT * FROM invoice_line_item WHERE invoice_id = 165464;

select * from invoice_line_item_component_value where invoice_line_item_id = 388438

select * from invoice_line_item_material where invoice_line_item_id = 388438

select * from invoice_status where invoice_id = 165464

select * from invoice_transaction_group where invoice_id = 165464

select * from invoice_collection where invoice_id = 165464

select * from invoice_customer_plan where invoice_id = 165464

select * from invoice_file where invoice_id = 165464

select * from invoice_customer_advance_installment where invoice_id = 165464

select * from invoice_customer_advance_redeemed where invoice_id = 165464

select * from product where id = 613047

select * from product_location where product_id = 613047

select * from customer_plan_status where customer_plan_id = 109332

select * from customer_advance_status where customer_advance_id = 102150 order by id desc