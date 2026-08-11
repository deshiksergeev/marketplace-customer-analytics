/*
Project: Marketplace Customer Analytics
Analysis: Customer segmentation by order frequency

Segments are computed per customer across regions (GROUP BY user_id), not per
user-region row: a customer who ordered from two top-3 regions is one customer
with the combined order count, not two. This differs from adhoc03, which is
regional by design.

Average order cost divides delivered cost by delivered orders. Canceled orders
are excluded from the denominator because they contribute nothing to the
numerator.
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
			WHEN SUM(total_orders) BETWEEN 2 AND 5 THEN '2 - 5 заказов'
			WHEN SUM(total_orders) BETWEEN 6 AND 10 THEN '6 - 10 заказов'
			WHEN SUM(total_orders) >= 11 THEN '11 и более заказов'
		END AS segment
	FROM
		ds_ecom.product_user_features
	GROUP BY
		user_id
)
SELECT
	segment,
	COUNT(user_id) AS users_in_segment,
	ROUND(AVG(orders_total_for_user), 0) AS avg_orders_count,
	ROUND(SUM(cost_total) / SUM(orders_total_for_user - canceled_orders_total_for_user)::NUMERIC, 2) AS avg_order_cost
FROM
	segmentation
GROUP BY
	segment
ORDER BY
	users_in_segment DESC;