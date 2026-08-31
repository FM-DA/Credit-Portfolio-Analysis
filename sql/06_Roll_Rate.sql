WITH first_credit AS (
    -- Определяем первый кредит каждого клиента
    SELECT
        credit_hub_id,
        ROW_NUMBER() OVER(PARTITION BY customer_hub_id ORDER BY disb_date, credit_hub_id) AS rn
    FROM l2.credits
    WHERE product_id NOT IN (1258,1244,1238,1248,1241,1291,1237,1240,1210,1242,1239,1289,1206,1223,1288,1207,1224,1205,1269)
),
credit_base AS (
    SELECT
        credit_hub_id,
        credit_id,
        product_id,
        branch_id,
        office_id
    FROM l2.credits
    WHERE product_id NOT IN (1258,1244,1238,1248,1241,1291,1237,1240,1210,1242,1239,1289,1206,1223,1288,1207,1224,1205,1269)
),
months AS (
    -- Формируем даты срезов на конец каждого месяца
    SELECT
        (DATE_TRUNC('month', gs) + INTERVAL '1 month - 1 day')::date AS month_end
    FROM generate_series(
        DATE '2025-06-01',
        DATE '2026-06-01',
        INTERVAL '1 month'
    ) AS gs
),
portfolio_snapshot AS (
    -- Определяем бакет просрочки каждого кредита на дату среза
    SELECT
        ci.credit_id,
        cb.product_id,
        cb.branch_id,
        cb.office_id,
        m.month_end,
        ci.som_balance,
        CASE
            WHEN ci.overdue_mainsumm_days = 0 THEN '0'
            WHEN ci.overdue_mainsumm_days BETWEEN 1 AND 30 THEN '1-30'
            WHEN ci.overdue_mainsumm_days BETWEEN 31 AND 60 THEN '31-60'
            WHEN ci.overdue_mainsumm_days BETWEEN 61 AND 90 THEN '61-90'
            ELSE '90+'
        END AS bucket,
        CASE
            WHEN fc.rn = 1 THEN 'Новый'
            ELSE 'Повторный'
        END AS client_status
    FROM months m
    JOIN l2.credits_indicators AS ci
        ON ci.date_range @> m.month_end
    JOIN credit_base AS cb
        ON ci.credit_hub_id = cb.credit_hub_id
    JOIN first_credit AS fc
        ON ci.credit_hub_id = fc.credit_hub_id
),
roll_rate AS (
    -- Сопоставляем бакет кредита с предыдущим месяцем
    SELECT
        credit_id,
        product_id,
        branch_id,
        office_id,
        LAG(month_end) OVER (
            PARTITION BY credit_id
            ORDER BY month_end
        ) AS previous_month,
        month_end,
        LAG(bucket) OVER (
            PARTITION BY credit_id
            ORDER BY month_end
        ) AS previous_bucket,
        bucket AS current_bucket,
        som_balance,
        client_status
    FROM portfolio_snapshot
)
SELECT
    credit_id AS "ID кредита",
    product_id AS "ID продукта",
    previous_bucket AS "Предыдущий бакет",
    current_bucket AS "Текущий бакет",
    som_balance AS "Остаток ОД",
    month_end AS "Дата среза",
    branch_id AS "ID филиала",
    office_id AS "ID отделения",
    client_status AS "Статус клиента"
FROM roll_rate
WHERE DATE_TRUNC('month', previous_month + INTERVAL '1 month') =
      DATE_TRUNC('month', month_end);
