-----------------------------------closed customer plan----------------------------------------------------------------------
select 
	*
from 
	customer_plan cp
INNER JOIN
	(
		select 
			customer_plan_id,
			status
		from 
			customer_plan_status
	) as plans
	on plans.customer_plan_id = cp.id
where customer_id = 1 and plans.status = 'CLOSED'