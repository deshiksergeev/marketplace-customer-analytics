/*
Top 15 customers by AOV among those with at least 3 orders.

Ranking by a maximum is a selection, not a test. Whether frequency relates to order value
is tested in the notebook.
*/
SELECT
	user_id,
	ROUND(
        SUM(total_order_costs)
        / NULLIF(SUM(total_orders - num_canceled_orders), 0)::NUMERIC,
        2
    ) AS aov,
	RANK() OVER (
	ORDER BY
		SUM(total_order_costs)
            / NULLIF(SUM(total_orders - num_canceled_orders), 0)::NUMERIC DESC
	) AS customer_rank
FROM
	ds_ecom.product_user_features
GROUP BY
	user_id
HAVING
	SUM(total_orders) >= 3
ORDER BY
	aov DESC
LIMIT 15;