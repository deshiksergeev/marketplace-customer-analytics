/*
Project: Marketplace Customer Analytics
Description: Customer-level feature mart for marketplace data
Author: Eldar Dzhamaldinov
Date: 2026-07-17

This query builds a customer-level analytical feature mart,
with features aggregated at the user-region level.

The final grain of the mart is:
    one row per user-region pair.

Only the top 3 regions by number of orders are included.
*/


/* ============================================================
   1. Filter orders and users
   ============================================================ */

WITH orders_filtered AS (
    SELECT *
    FROM ds_ecom.orders
    WHERE order_status IN ('Доставлено', 'Отменено')
),

users_orders_filtered AS (
    SELECT *
    FROM ds_ecom.users
    INNER JOIN orders_filtered USING (buyer_id)
),

/*
Keep the top 3 regions dynamically based on the number of orders.
This avoids hardcoding specific region names.
*/
users_orders_region_filtered AS (
    SELECT *
    FROM users_orders_filtered
    WHERE region IN (
        SELECT region
        FROM users_orders_filtered
        GROUP BY region
        ORDER BY COUNT(order_id) DESC
        LIMIT 3
    )
),


/* ============================================================
   2. Customer-level behavioral features
   ============================================================ */

/*
Aggregate order activity at the user-region level.

customer_activity_duration represents the observed time interval
between the first and last recorded order of a customer within
a given region.
*/
client_base_info AS (
    SELECT
        user_id,
        region,
        MIN(order_purchase_ts) AS first_order_ts,
        MAX(order_purchase_ts) AS last_order_ts,
        MAX(order_purchase_ts) - MIN(order_purchase_ts) AS customer_activity_duration
    FROM users_orders_region_filtered
    GROUP BY
        user_id,
        region
),


/* ============================================================
   3. Review features
   ============================================================ */

/*
Aggregate reviews at the order level to prevent row multiplication
when joining review data with order-level information.

Some review scores exceed the expected 1-5 scale and are corrected
by dividing them by 10.
*/
order_reviews_aggregated AS (
    SELECT
        order_id,
        AVG(
            CASE
                WHEN review_score > 5
                    THEN review_score / 10::NUMERIC
                ELSE review_score
            END
        ) AS avg_review_score_corrected
    FROM ds_ecom.order_reviews
    GROUP BY order_id
),

orders_info AS (
    SELECT
        user_id,
        region,
        COUNT(DISTINCT order_id) AS total_orders,
        ROUND(
            AVG(ora.avg_review_score_corrected),
            2
        ) AS avg_order_rating,
        COUNT(
            ora.avg_review_score_corrected
        ) AS num_orders_with_rating,
        COUNT(DISTINCT order_id)
            FILTER (
                WHERE order_status = 'Отменено'
            ) AS num_canceled_orders,
        (
            COUNT(DISTINCT order_id)
                FILTER (
                    WHERE order_status = 'Отменено'
                )
        ) / COUNT(DISTINCT order_id)::NUMERIC AS canceled_orders_ratio
    FROM users_orders_region_filtered
    LEFT JOIN order_reviews_aggregated ora USING (order_id)
    GROUP BY
        user_id,
        region
),


/* ============================================================
   4. Order value features
   ============================================================ */

/*
Calculate the total value of each order as the sum of item prices
and delivery costs.
*/
orders_total_price AS (
    SELECT
        order_id,
        SUM(price + delivery_cost) AS total_price
    FROM ds_ecom.order_items
    GROUP BY order_id
),


/* ============================================================
   5. Payment features
   ============================================================ */

/*
Recalculate payment sequence within each order to ensure
consistent ordering of payment records.
*/
order_payments_with_true_order AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY payment_sequential
        ) AS true_order
    FROM ds_ecom.order_payments
),

/*
Create order-level binary payment features:
- installment payment used;
- promo code used;
- money transfer used as the first payment method.
*/
order_payments_aggregated AS (
    SELECT
        order_id,
        MAX(
            CASE
                WHEN payment_installments > 1
                    THEN 1
                ELSE 0
            END
        ) AS has_installments,
        MAX(
            CASE
                WHEN payment_type = 'промокод'
                    THEN 1
                ELSE 0
            END
        ) AS has_promo,
        MAX(
            CASE
                WHEN true_order = 1
                     AND payment_type = 'денежный перевод'
                    THEN 1
                ELSE 0
            END
        ) AS has_money_transfer_first
    FROM order_payments_with_true_order
    GROUP BY order_id
),

/*
Aggregate monetary and payment-related features at the
user-region level.

Only delivered orders are included in monetary metrics,
while canceled orders are excluded from completed-order
monetary calculations.

COALESCE replaces NULL values produced by LEFT JOINs with zeros
for binary payment indicators.
*/
payments_info AS (
    SELECT
        uorf.user_id,
        uorf.region,
        SUM(otp.total_price)
            FILTER (
                WHERE uorf.order_status = 'Доставлено'
            ) AS total_order_costs,
        ROUND(
            AVG(otp.total_price)
                FILTER (
                    WHERE uorf.order_status = 'Доставлено'
                ),
            2
        ) AS avg_order_cost,
        SUM(
            COALESCE(opa.has_installments, 0)
        ) AS num_installment_orders,
        SUM(
            COALESCE(opa.has_promo, 0)
        ) AS num_orders_with_promo
    FROM users_orders_region_filtered uorf
    LEFT JOIN orders_total_price otp USING (order_id)
    LEFT JOIN order_payments_aggregated opa USING (order_id)
    GROUP BY
        uorf.user_id,
        uorf.region
),


/* ============================================================
   6. Binary customer-level features
   ============================================================ */

/*
Convert order-level payment and cancellation indicators
into customer-level binary features.
*/
binary_features AS (
    SELECT
        uorf.user_id,
        uorf.region,
        MAX(
            COALESCE(
                opa.has_money_transfer_first,
                0
            )
        ) AS used_money_transfer,
        MAX(
            COALESCE(
                opa.has_installments,
                0
            )
        ) AS used_installments,
        MAX(
            CASE
                WHEN uorf.order_status = 'Отменено'
                    THEN 1
                ELSE 0
            END
        ) AS used_cancel
    FROM users_orders_region_filtered uorf
    LEFT JOIN order_payments_aggregated opa USING (order_id)
    GROUP BY
        uorf.user_id,
        uorf.region
)


/* ============================================================
   7. Final customer feature mart
   ============================================================ */

/*
Combine customer activity, order, payment, and behavioral
features into a single customer-level analytical dataset.

Final grain:
    one row per user-region pair.
*/
SELECT
    cb.user_id,
    cb.region,
    cb.first_order_ts,
    cb.last_order_ts,
    cb.customer_activity_duration,

    oi.total_orders,
    oi.avg_order_rating,
    oi.num_orders_with_rating,
    oi.num_canceled_orders,
    oi.canceled_orders_ratio,

    pi.total_order_costs,
    pi.avg_order_cost,
    pi.num_installment_orders,
    pi.num_orders_with_promo,

    bf.used_money_transfer,
    bf.used_installments,
    bf.used_cancel

FROM client_base_info cb
LEFT JOIN orders_info oi USING (user_id, region)
LEFT JOIN payments_info pi USING (user_id, region)
LEFT JOIN binary_features bf USING (user_id, region);
