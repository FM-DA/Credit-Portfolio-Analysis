WITH first_credit AS (
    -- Определяем первый кредит каждого клиента
    SELECT
        credit_hub_id,
        ROW_NUMBER() OVER(PARTITION BY customer_hub_id ORDER BY disb_date, credit_hub_id) AS rn
    FROM l2.credits
    WHERE product_id NOT IN (1258,1244,1238,1248,1241,1291,1237,1240,1210,1242,1239,1289,1206,1223,1288,1207,1224,1205,1269)
),
credit_base AS (
    -- Формируем когорту выданных кредитов за анализируемый период
    SELECT
        c.credit_hub_id,
        c.customer_id,
        c.credit_id,
        c.product_id,
        c.disb_date,
        c.disbursed_summ_lcy,
        c.branch_id,
        c.office_id,
        CASE
            WHEN fc.rn = 1 THEN 'Новый'
            ELSE 'Повторный'
        END AS new_client
    FROM l2.credits c
    JOIN first_credit fc
        ON c.credit_hub_id = fc.credit_hub_id
    WHERE c.product_id NOT IN (1258,1244,1238,1248,1241,1291,1237,1240,1210,1242,1239,1289,1206,1223,1288,1207,1224,1205,1269)
        AND c.disb_date >= DATE '2025-07-01'
        AND c.disb_date < DATE '2026-07-01'
),
months AS (
    -- Формируем календарь срезов на конец каждого месяца
    SELECT
        DATE_TRUNC('month', gs)::date AS month_start,
        (DATE_TRUNC('month', gs) + INTERVAL '1 month - 1 day')::date AS month_end
    FROM generate_series(
        DATE '2025-07-01',
        DATE '2026-06-01',
        INTERVAL '1 month'
    ) gs
),
credit_months AS (
    -- Формируем наблюдения по каждому кредиту от месяца выдачи до конца периода
    SELECT
        c.credit_hub_id,
        c.customer_id,
        c.credit_id,
        c.product_id,
        c.disb_date,
        c.disbursed_summ_lcy,
        c.branch_id,
        c.office_id,
        c.new_client,
        m.month_end,
        (
            EXTRACT(YEAR FROM m.month_end) * 12 +
            EXTRACT(MONTH FROM m.month_end) -
            EXTRACT(YEAR FROM c.disb_date) * 12 -
            EXTRACT(MONTH FROM c.disb_date)
        )::int AS mob
    FROM credit_base c
    JOIN months m
        ON m.month_start >= DATE_TRUNC('month', c.disb_date)::date
),
eom AS (
    -- Получаем состояние кредита на конец каждого месяца
    SELECT
        cm.credit_hub_id,
        cm.credit_id,
        cm.month_end,
        cm.mob,
        ci.som_balance AS som_balance_end_month,
        ci.overdue_days AS overdue_days_end_month,
        CASE
            WHEN COALESCE(ci.overdue_days,0) > 0
            THEN ci.som_balance
            ELSE 0
        END AS overdue_balance_end_month,
        ROW_NUMBER() OVER(
            PARTITION BY cm.credit_hub_id, cm.credit_id, cm.month_end, cm.mob
            ORDER BY LOWER(ci.date_range) DESC
        ) AS rn
    FROM credit_months cm
    LEFT JOIN l2.credits_indicators ci
        ON ci.credit_hub_id = cm.credit_hub_id
        AND ci.date_range @> cm.month_end
        AND LOWER(ci.date_range)::date >= cm.disb_date
)
SELECT
    c.customer_id AS "ID клиента",
    c.credit_id AS "ID кредита",
    c.product_id AS "ID продукта",
    c.disb_date AS "Дата выдачи",
    DATE_TRUNC('month', c.disb_date)::date AS "Месяц выдачи",
    c.disbursed_summ_lcy AS "Сумма кредита",
    e.month_end AS "Дата среза",
    e.mob AS "Возраст кредита MOB",
    e.som_balance_end_month AS "Остаток ОД на конец месяца",
    e.overdue_days_end_month AS "Дни просрочки на конец месяца",
    e.overdue_balance_end_month AS "Просроченный ОД на конец месяца",
    c.new_client AS "Статус клиента",
    c.branch_id AS "ID филиала",
    c.office_id AS "ID отделения"
FROM eom e
JOIN credit_base c
    ON e.credit_hub_id = c.credit_hub_id
WHERE e.rn = 1;
