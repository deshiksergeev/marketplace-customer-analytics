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
January has the lowest number of customers and orders among the analyzed
first-order cohorts, while December shows relatively high customer activity
and one of the highest average order values.
The share of customers using money transfers remains relatively stable
across the cohorts.
The average customer activity duration is relatively low for the December cohort,
which may indicate a higher share of short-term customers.
This pattern may be related to seasonal demand around the New Year period
and requires further investigation.
*/
