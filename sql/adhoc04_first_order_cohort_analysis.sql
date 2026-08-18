/*
Customer activity by first order month, 2023 cohorts.

Cohorts are restricted to first orders in 2023 while orders continue into 2024, so earlier
cohorts are observed longer. A fixed 30-day window removes the confound; lifetime itself is
zero for single-order customers and cannot be compared across cohorts.
*/
SELECT
	DATE_TRUNC('month', first_order_ts)::DATE AS month_of_2023,
	COUNT(DISTINCT user_id) AS users_in_month,
	SUM(total_orders) AS orders_in_month,
	ROUND(
        SUM(total_order_costs)
        / NULLIF(SUM(total_orders - num_canceled_orders), 0)::NUMERIC,
        2
    ) AS AOV_month,
	ROUND(
        SUM(avg_order_rating * num_orders_with_rating)
        / SUM(num_orders_with_rating)::NUMERIC,
        2
    ) AS avg_order_rating_month,
	ROUND(
        AVG(used_money_transfer),
        2
    ) AS money_transfer_ratio_month,
	ROUND(
        (EXTRACT(EPOCH FROM AVG(lifetime)) / 86400)::NUMERIC,
        1
    ) AS avg_first_to_last_order_days,
    ROUND(
        AVG(
            CASE
                WHEN total_orders > 1
                     AND lifetime <= '30 days'::INTERVAL
                    THEN 1
                ELSE 0
            END
        )::NUMERIC,
        4
    ) AS repeat_within_30d_lower_bound
FROM
	ds_ecom.product_user_features
WHERE
	first_order_ts >= '2023-01-01'
	AND first_order_ts < '2024-01-01'
GROUP BY
	month_of_2023
ORDER BY
	month_of_2023;