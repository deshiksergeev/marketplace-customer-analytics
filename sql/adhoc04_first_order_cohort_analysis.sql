/*
Project: Marketplace Customer Analytics
Analysis: Customer activity by first order month

Groups customers by the month of their first order in 2023 and compares cohort
size, order value, ratings, payment preference and repeat purchase behaviour.

Cohort comparisons of lifetime are confounded by unequal observation windows:
the data effectively ends 2023-12-31, so the December cohort is observed for 17
days on average against 341 for the January cohort. A fixed 30-day window
removes the confound.

The mart stores only the first and last order timestamp, so a repeat purchase
within 30 days is exactly identifiable for customers with exactly two orders
(90.7% of all repeat customers) and is a lower bound otherwise. The gap between
the lower and upper bound is at most 0.6 pp per cohort and does not change the
conclusion.

Note that lifetime itself is degenerate: it is zero for the 96% of cohort
customers with a single order, so its average equals the repeat rate times the
mean span among repeat customers and cannot separate the two.
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