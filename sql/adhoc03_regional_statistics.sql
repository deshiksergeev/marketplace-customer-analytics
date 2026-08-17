/*
Project: Marketplace Customer Analytics
Analysis: Regional customer and order statistics

Compares customer and order metrics across the three top regions: average order
value, installment usage, promo code usage and customer cancellation rate.

The three shares are not normalized the same way: installments_ratio and
promo_ratio are order-weighted, cancel_ratio is customer-weighted (AVG of a
customer-level binary flag). They are not comparable to one another.

COUNT(user_id) is correct at this grain: the mart is one row per user-region
pair, so user_id is unique within a region. Across regions the row count
(62,408) exceeds the number of distinct customers (62,400) because 8 customers
ordered from more than one top-3 region.
*/
SELECT
	region,
	COUNT(user_id) AS total_users_region,
	SUM(total_orders) AS orders_total_region,
	ROUND(
        SUM(total_order_costs)
        / NULLIF(SUM(total_orders - num_canceled_orders), 0)::NUMERIC,
        2
    ) AS AOV_region,
	ROUND(
        SUM(num_installment_orders)
        / NULLIF(SUM(total_orders - num_canceled_orders), 0)::NUMERIC,
        4
    ) AS installments_ratio,
	ROUND(
        SUM(num_orders_with_promo)
        / NULLIF(SUM(total_orders - num_canceled_orders), 0)::NUMERIC,
        4
    ) AS promo_ratio,
	ROUND(
        AVG(used_cancel),
        4
    ) AS cancel_ratio
FROM
	ds_ecom.product_user_features
GROUP BY
	region
ORDER BY
	total_users_region DESC;