WITH first_credit AS (
    -- Определяем первый кредит каждого клиента
    SELECT 
        credit_hub_id,
        ROW_NUMBER() OVER(PARTITION BY customer_hub_id ORDER BY disb_date, credit_hub_id) AS rn
    FROM l2.credits
    WHERE product_id NOT IN (1258,1244,1238,1248,1241,1291,1237,1240,1210,1242,1239,1289,1206,1223,1288,1207,1224,1205,1269)
)
SELECT 
    c.customer_id AS "ID клиента",
    ca.credit_id AS "ID кредита",
    c.product_id AS "ID продукта",
    c.disb_date AS "Дата выдачи",
    ca.reserve_type_name AS "Классификация РППУ",

    -- Объединяем категории РППУ в две группы.
    CASE
        WHEN ca.reserve_type_id IN (4,5,6) THEN 'Классифицированные активы'
        ELSE 'Неклассифицированные активы'
    END AS "Категория классификации",
    ca.reserve_summ_n AS "РППУ по ОД",
    ca.percents_reserve_summn AS "РППУ по процентам",
    ca.reserve_reason AS "Основание для РППУ",
    ca.end_month AS "Дата РППУ",

    -- Определяем статус клиента по порядку выдачи его кредитов.
    CASE 
        WHEN fc.rn = 1 THEN 'Новый'
        ELSE 'Повторный'
    END AS "Статус клиента",
    c.branch_id AS "ID филиала",
    c.office_id AS "ID отделения"
FROM l2.credits AS c
JOIN onlinebankdb_func.credits_aggregate_reports_get_rppu_info AS ca 
    ON c.credit_hub_id = ca.credit_hub_id 
JOIN first_credit AS fc 
    ON fc.credit_hub_id = c.credit_hub_id 
WHERE c.product_id NOT IN (1258,1244,1238,1248,1241,1291,1237,1240,1210,1242,1239,1289,1206,1223,1288,1207,1224,1205,1269)
    AND ca.end_month >= DATE '2025-07-01'
    AND ca.end_month < DATE '2026-07-01';