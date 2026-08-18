/*
Customer-level feature mart at the user-region grain.

One row per user-region pair: a customer who ordered from two top-3 regions appears twice.

Careful with the denominator. total_order_costs covers delivered orders only, while
total_orders counts canceled ones too, so AOV must divide by
(total_orders - num_canceled_orders). For customers whose orders were all canceled
total_order_costs is NULL by construction, not missing.

Review scores above 5 are treated as a data entry error and divided by 10.
*/


------------ 1. Filter orders and users ----------

-- Top 3 regions are picked dynamically rather than hardcoded by name.

WITH orders_filtered AS (
	SELECT
		*
	FROM
		ds_ecom.orders
	WHERE
		order_status IN (
			'Доставлено', 'Отменено'
		)
),
users_orders_filtered AS (
	SELECT
		*
	FROM
		ds_ecom.users
	INNER JOIN orders_filtered
			USING (buyer_id)
),
/*
Keep the top 3 regions dynamically based on the number of orders.
This avoids hardcoding specific region names.
*/
users_orders_region_filtered AS (
	SELECT
		*
	FROM
		users_orders_filtered
	WHERE
		region IN (
			SELECT
				region
			FROM
				users_orders_filtered
			GROUP BY
				region
			ORDER BY
				COUNT(order_id) DESC
			LIMIT 3
		)
),
------------ 2. Customer-level behavioural features ----------

/*
first_to_last_order_days is the span between a customer's first and last order, not a
lifetime. It is zero for single-order customers, so its group average is the repeat rate
times the mean span among repeat customers and cannot separate the two. Retention is
measured by repeat purchase in a fixed window instead, see adhoc04.
*/
client_base_info AS (
	SELECT
		user_id,
		region,
		MIN(order_purchase_ts) AS first_order_ts,
		MAX(order_purchase_ts) AS last_order_ts,
		(
			MAX(order_purchase_ts)::DATE - MIN(order_purchase_ts)::DATE
		) AS first_to_last_order_days
	FROM
		users_orders_region_filtered
	GROUP BY
		user_id,
		region
),
------------ 3. Review features ----------

-- Reviews are collapsed to the order level first, otherwise the join multiplies rows.
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
	FROM
		ds_ecom.order_reviews
	GROUP BY
		order_id
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
		COUNT(ora.avg_review_score_corrected) AS num_orders_with_rating,
		COUNT(DISTINCT order_id)
            FILTER (
		WHERE
			order_status = 'Отменено'
		) AS num_canceled_orders,
		(
			COUNT(DISTINCT order_id)
                FILTER (
			WHERE
				order_status = 'Отменено'
			)
		) / COUNT(DISTINCT order_id)::NUMERIC AS canceled_orders_ratio
	FROM
		users_orders_region_filtered
	LEFT JOIN order_reviews_aggregated ora
			USING (order_id)
	GROUP BY
		user_id,
		region
),
------------ 4. Order value features ----------
orders_total_price AS (
	SELECT
		order_id,
		SUM(price + delivery_cost) AS total_price
	FROM
		ds_ecom.order_items
	GROUP BY
		order_id
),
------------ 5. Payment features ----------

-- payment_sequential is not guaranteed to be gapless, so the order is recomputed.
order_payments_with_true_order AS (
	SELECT
		*,
		ROW_NUMBER() OVER (
			PARTITION BY order_id
		ORDER BY
			payment_sequential
		) AS true_order
	FROM
		ds_ecom.order_payments
),
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
/*
Money transfer counts only as the first payment method: the task defines the feature
that way, and a later transfer in a split payment is a different behaviour.
*/
		MAX(
            CASE
                WHEN true_order = 1
                     AND payment_type = 'денежный перевод'
                    THEN 1
                ELSE 0
            END
        ) AS has_money_transfer_first
	FROM
		order_payments_with_true_order
	GROUP BY
		order_id
),
/*
Monetary metrics cover delivered orders only, while installment and promo counts cover
all of them. Any ratio built on these must use a matching denominator.
*/
payments_info AS (
	SELECT
		uorf.user_id,
		uorf.region,
		SUM(otp.total_price)
            FILTER (
		WHERE
			uorf.order_status = 'Доставлено'
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
	FROM
		users_orders_region_filtered uorf
	LEFT JOIN orders_total_price otp
			USING (order_id)
	LEFT JOIN order_payments_aggregated opa
			USING (order_id)
	GROUP BY
		uorf.user_id,
		uorf.region
),
------------ 6. Binary customer-level features ----------
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
	FROM
		users_orders_region_filtered uorf
	LEFT JOIN order_payments_aggregated opa
			USING (order_id)
	GROUP BY
		uorf.user_id,
		uorf.region
)
------------ 7. Final mart: one row per user-region pair ----------
SELECT
	cb.user_id,
	cb.region,
	cb.first_order_ts,
	cb.last_order_ts,
	cb.first_to_last_order_days,
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
FROM
	client_base_info cb
LEFT JOIN orders_info oi
		USING (
		user_id,
		region
	)
LEFT JOIN payments_info pi
		USING (
		user_id,
		region
	)
LEFT JOIN binary_features bf
		USING (
		user_id,
		region
	);