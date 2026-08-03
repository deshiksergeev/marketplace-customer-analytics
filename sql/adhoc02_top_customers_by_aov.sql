/*
Project: Marketplace Customer Analytics
Analysis: Top customers by average order value (AOV)
Description:
Rank customers with at least 3 orders by average order value
and return the top 15 customers.
*/

SELECT
    user_id,
    ROUND(
        SUM(total_order_costs)
        / SUM(total_orders)::NUMERIC,
        2
    ) AS aov,
    RANK() OVER (
        ORDER BY
            SUM(total_order_costs)
            / SUM(total_orders)::NUMERIC DESC
    ) AS customer_rank
FROM ds_ecom.product_user_features
GROUP BY user_id
HAVING SUM(total_orders) >= 3
ORDER BY aov DESC
LIMIT 15;
