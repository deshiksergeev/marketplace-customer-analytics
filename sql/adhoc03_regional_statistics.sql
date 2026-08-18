/*
Regional customer and order statistics.

installments_ratio and promo_ratio are order-weighted, cancel_ratio is customer-weighted -
the three are not comparable to one another.

COUNT(user_id) without DISTINCT is correct here: the mart is one row per user-region pair.
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