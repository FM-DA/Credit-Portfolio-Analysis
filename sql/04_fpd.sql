WITH first_payment AS (
    -- Находим первый платеж по графику для каждого кредита
    SELECT
        hub_id,
        pay_date,
        ROW_NUMBER() OVER(PARTITION BY hub_id ORDER BY pay_date) AS rn
    FROM l1_credits.hs_graphic_onlinebankdb_active
),
first_credit AS (
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
        customer_id,
        credit_id,
        product_id,
        disb_date,
        branch_id,
        office_id
    FROM l2.credits
    WHERE product_id NOT IN (1258,1244,1238,1248,1241,1291,1237,1240,1210,1242,1239,1289,1206,1223,1288,1207,1224,1205,1269)
        AND disb_date >= DATE '2025-07-01'
        AND disb_date < DATE '2026-07-01'
),
fpd_base AS (
    SELECT
        c.*,
        f.pay_date
    FROM credit_base AS c
    JOIN first_payment AS f
        ON c.credit_hub_id = f.hub_id
        AND f.rn = 1
)
SELECT
    fb.customer_id AS "ID клиента",
    fb.credit_id AS "ID кредита",
    fb.product_id AS "ID продукта",
    fb.disb_date AS "Дата выдачи",
    fb.branch_id AS "ID филиала",
    fb.office_id AS "ID отделения",
    fb.pay_date AS "Дата первого платежа по графику",

    -- Для исключения потенциального грейс-периода определяем FPD как наличие просрочки в течение 15 дней после первого платежа
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM l2.credits_indicators AS ci
            WHERE ci.credit_hub_id = fb.credit_hub_id
                AND LOWER(ci.date_range) BETWEEN fb.pay_date + INTERVAL '1 day'
                                              AND fb.pay_date + INTERVAL '15 day'
                AND ci.overdue_days > 0
        )
        THEN 'Да'
        ELSE 'Нет'
    END AS "FPD",
    CASE
        WHEN fc.rn = 1 THEN 'Новый'
        ELSE 'Повторный'
    END AS "Статус клиента"
FROM fpd_base AS fb
JOIN first_credit AS fc
    ON fb.credit_hub_id = fc.credit_hub_id;