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
WHERE DATE_TRUNC('year', first_order_ts) = '2023-01-01'
GROUP BY month_of_2023
ORDER BY month_of_2023;

/*
Key findings:

The January first-order cohort is the smallest by both customer count
and total number of orders.

The December first-order cohort has a relatively high total number of orders
and one of the highest average order values among the analyzed cohorts.

The share of customers using money transfers remains relatively stable
across the first-order cohorts.

The average customer activity duration is relatively low for the December cohort,
which may indicate a higher share of customers with shorter observed activity
periods in the available data.

The observed differences between first-order cohorts may be related to
seasonal purchasing patterns around the New Year period and require
further investigation.
*/
