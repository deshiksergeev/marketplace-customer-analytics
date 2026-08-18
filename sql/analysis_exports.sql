/*
Customer-level extracts for the notebook.

The ad hoc queries return aggregates, and aggregates have no within-group variance, so
nothing can be tested on them. These two extracts pull the same population one row per
customer-region, which is what the tests in the notebook use.

lifetime comes as an interval and is converted to days here. It is zero for single-order
customers, so it is not a retention metric, see adhoc04.
*/


-- Feeds the segmentation, ranking and regional sections.

SELECT
	user_id,
	region,
	total_orders,
	num_canceled_orders,
	total_order_costs,
	avg_order_cost,
	avg_order_rating,
	num_orders_with_rating,
	num_installment_orders,
	num_orders_with_promo,
	used_installments,
	used_money_transfer,
	used_cancel,
	(EXTRACT(EPOCH FROM lifetime) / 86400)::NUMERIC AS lifetime_days
FROM
	ds_ecom.product_user_features;


-- Feeds the cohort section. Same window as adhoc04, so its aggregates reproduce from here.

SELECT
	user_id,
	region,
	first_order_ts,
	total_orders,
	num_canceled_orders,
	total_order_costs,
	avg_order_rating,
	num_orders_with_rating,
	used_money_transfer,
	(
		EXTRACT(EPOCH FROM lifetime) / 86400
	)::NUMERIC AS lifetime_days
FROM
	ds_ecom.product_user_features
WHERE
	first_order_ts >= '2023-01-01'
	AND first_order_ts < '2024-01-01';