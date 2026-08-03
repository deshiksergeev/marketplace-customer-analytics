/*
Project: Marketplace Customer Analytics
Analysis: Regional customer and order statistics
Description:
Compare customer and order metrics across regions,
including average order value, installment usage,
promo code usage, and customer cancellation rate.
*/
SELECT
    region,
    COUNT(user_id) AS total_users_region,
    SUM(total_orders) AS orders_total_region,
    ROUND(
        SUM(total_order_costs) / SUM(total_orders)::NUMERIC,
        2
    ) AS AOV_region,
    ROUND(
        SUM(num_installment_orders) / SUM(total_orders)::NUMERIC,
        2
    ) AS installments_ratio,
    ROUND(
        SUM(num_orders_with_promo) / SUM(total_orders)::NUMERIC,
        3
    ) AS promo_ratio,
    ROUND(
        AVG(used_cancel),
        4
    ) AS cancel_ratio
FROM ds_ecom.product_user_features
GROUP BY region
ORDER BY total_users_region DESC;
/*
Key findings:
Moscow has the largest customer base and the highest total number of orders.
Saint Petersburg has the highest average order value and the largest share
of orders paid in installments.
Moscow also has the highest share of customers who canceled at least one order,
which may indicate regional differences in customer behavior and deserves
further investigation.
*/
