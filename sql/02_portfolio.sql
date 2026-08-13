WITH first_credit AS (
    -- Определяем первый кредит каждого клиента
    SELECT
        credit_hub_id,
        ROW_NUMBER() OVER(PARTITION BY customer_hub_id ORDER BY disb_date, credit_hub_id) AS rn
    FROM l2.credits
    WHERE product_id NOT IN (1258,1244,1238,1248,1241,1291,1237,1240,1210,1242,1239,1289,1206,1223,1288,1207,1224,1205,1269)
),
employee_history AS (
    -- Получаем историю сотрудников и их типы
    SELECT
        user_hub_id,
        hub_id,
        start_date,
        end_date,
        CASE
            WHEN officer_type_id = 5 THEN 'Юрист'
            WHEN officer_type_id = 6 THEN 'Коллектор'
            ELSE 'КС'
        END AS type_employee
    FROM l1_credits.hs_credits_officer_onlinebankdb_active
),
base AS (
    SELECT
        c.customer_id,
        c.credit_id,
        c.product_id,
        LOWER(ci.date_range)::date AS snapshot_date,
        ci.som_balance,
        ci.percents_som,
        ci.overdue_days,

        -- Определяем статус клиента по порядку выдачи его кредитов.
        CASE
            WHEN fc.rn = 1 THEN 'Новый'
            ELSE 'Повторный'
        END AS client_status,

        -- Определяем наличие погашения при наличии просрочки.
        CASE
            WHEN ci.overdue_days > 0
                AND c.disbursed_summ_lcy = ci.som_balance THEN 'Нет'
            WHEN ci.overdue_days > 0
                AND c.disbursed_summ_lcy <> ci.som_balance THEN 'Да'
            ELSE 'Просрочки нет'
        END AS repayment_flag,
        u.fullname,
        eh.type_employee,
        c.branch_id,
        c.office_id,

        -- Выбираем одну запись сотрудника для каждого кредита и среза.
        ROW_NUMBER() OVER(
            PARTITION BY c.credit_id, LOWER(ci.date_range)::date
            ORDER BY eh.start_date DESC NULLS LAST
        ) AS emp_rn
    FROM l2.credits_indicators ci
    JOIN l2.credits c
        ON ci.credit_hub_id = c.credit_hub_id
    LEFT JOIN employee_history eh
        ON ci.credit_hub_id = eh.hub_id
        AND LOWER(ci.date_range) >= eh.start_date
        AND (LOWER(ci.date_range) <= eh.end_date OR eh.end_date IS NULL)
    LEFT JOIN l1_dbo.hs_user_onlinebankdb_active u
        ON eh.user_hub_id = u.hub_id
    JOIN first_credit fc
        ON fc.credit_hub_id = c.credit_hub_id
    WHERE c.product_id NOT IN (1258,1244,1238,1248,1241,1291,1237,1240,1210,1242,1239,1289,1206,1223,1288,1207,1224,1205,1269)
        AND LOWER(ci.date_range) >= DATE '2025-07-01'
        AND LOWER(ci.date_range) < DATE '2026-07-01'
)
SELECT
    customer_id AS "ID клиента",
    credit_id AS "ID кредита",
    product_id AS "ID продукта",
    snapshot_date AS "Дата среза",
    som_balance AS "Остаток по ОД",
    percents_som AS "Остаток по процентам",
    overdue_days AS "Кол-во дней просрочки",
    client_status AS "Статус клиента",
    repayment_flag AS "Погашения по просроченному кредиту",
    fullname AS "Сотрудник",
    type_employee AS "Тип сотрудника",
    branch_id AS "ID филиала",
    office_id AS "ID отделения"
FROM base
WHERE emp_rn = 1;