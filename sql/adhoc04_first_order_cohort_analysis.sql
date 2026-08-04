/*
Project: Marketplace Customer Analytics
Analysis: Customer activity by first order month
Description:
Group customers by the month of their first order in 2023
and analyze customer activity, order behavior, payment preferences,
and average customer activity duration across cohorts.
*/

SELECT
    DATE_TRUNC('month', first_order_ts)::DATE AS month_of_2023,
    COUNT(DISTINCT user_id) AS users_in_month,
    SUM(total_orders) AS orders_in_month,
    ROUND(
        SUM(total_order_costs) / SUM(total_orders)::NUMERIC,
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
    AVG(lifetime) AS avg_customer_activity_duration
FROM ds_ecom.product_user_features
WHERE first_order_ts >= '2023-01-01' AND first_order_ts < '2024-01-01'
GROUP BY month_of_2023
ORDER BY month_of_2023;

/*
Key findings:

The January first-order cohort is the smallest by both customer count
and total number of orders, while the November cohort is the largest.

The September first-order cohort has the highest average order value
among the analyzed cohorts, followed by the October and November cohorts.

The share of customers using money transfers remains relatively stable
across the first-order cohorts, ranging from approximately 19% to 22%.

The average observed customer activity duration decreases substantially
for later first-order cohorts. This pattern should be interpreted with caution,
as customers acquired later in 2023 have a shorter available observation window
in the dataset.

The observed differences in cohort size and average order value may reflect
seasonal variation in customer acquisition and purchasing behavior and require
further investigation.
*/
