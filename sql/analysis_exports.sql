/*
Project: Marketplace Customer Analytics
Analysis: Customer-level extracts for the notebook

The four ad hoc queries return aggregates: three rows by region, twelve by
cohort. Aggregates carry no within-group variance, so no difference between
regions or cohorts can be tested from them. These two extracts pull the same
population at the customer-region grain, which is what the significance tests in
the notebook consume.

lifetime is an interval in the source table; it is converted to days here so the
notebook reads a numeric column. Note that it is zero for customers with a
single order and is not a retention metric - see adhoc04.
*/


-- ============================================================
-- 1. Full customer extract
-- ============================================================
/*
Feeds the segmentation, ranking and regional sections. Customers whose orders
were all canceled are kept: they have no order value by construction, and
dropping them here would silently change the customer counts reported by
adhoc01 and adhoc03.
*/

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


-- ============================================================
-- 2. 2023 first-order cohort extract
-- ============================================================
/*
Feeds the cohort section. The window matches adhoc04 so that the aggregates in
first_order_cohort_analysis.csv can be reproduced from this file.
*/

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