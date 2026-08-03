/*
Project: Marketplace Customer Analytics
Analysis: Customer segmentation by order frequency
Description:
Segment customers based on the total number of orders
and calculate the number of customers, average order count,
and average order value for each segment.
*/
WITH 
segmentation AS (
SELECT
	user_id,
	SUM(total_orders) AS orders_total_for_user,
	SUM(num_canceled_orders) AS canceled_orders_total_for_user,
	SUM(total_order_costs) AS cost_total,
	CASE
		WHEN SUM(total_orders) = 1 THEN '1 заказ'
		WHEN SUM(total_orders) BETWEEN 2 AND 5 THEN '2—5 заказов'
		WHEN SUM(total_orders) BETWEEN 6 AND 10 THEN '6–10 заказов'
		WHEN SUM(total_orders) >= 11 THEN '11 и более заказов'
		END AS segment
FROM ds_ecom.product_user_features
GROUP BY user_id
)
SELECT
	segment,
	COUNT(user_id) AS users_in_segment,
	ROUND(AVG(orders_total_for_user), 0) AS avg_orders_count,
	ROUND(SUM(cost_total) / SUM(orders_total_for_user - canceled_orders_total_for_user)::NUMERIC, 2) AS avg_order_cost
FROM segmentation
GROUP BY segment
ORDER BY users_in_segment DESC;
