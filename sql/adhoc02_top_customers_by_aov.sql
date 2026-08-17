/*
Project: Marketplace Customer Analytics
Analysis: Top customers by average order value (AOV)

Ranks customers with at least 3 orders by average order value and returns the
top 15.

Ranking by a maximum is a selection procedure, not a test: the composition of the top
reflects the base rates of the population it is drawn from, before any relationship between
frequency and value is involved. The composition of this top-15 matches the base
rates of the >= 3 population and is not used as evidence about the
frequency-AOV relationship; that question is tested directly in the notebook.
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