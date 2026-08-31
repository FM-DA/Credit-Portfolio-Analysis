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
    c.credit_id AS "ID кредита",
    c.product_id AS "ID продукта",
    c.disbursed_summ_lcy AS "Сумма кредита",
    c.approved_period AS "Срок кредита (мес.)",
    c.disb_date AS "Дата выдачи",

    -- Проверяем, был ли кредит закрыт в день выдачи
    CASE
        WHEN c.disb_date = c.close_date THEN 'Да'
        ELSE 'Нет'
    END AS "Закрытие кредита в день выдачи",

    -- Определяем статус клиента по порядку выдачи его кредитов 
    CASE
        WHEN fc.rn = 1 THEN 'Новый'
        ELSE 'Повторный'
    END AS "Статус клиента",
    c.officer_fullname AS "Кредитный специалист",
    c.branch_id AS "ID филиала",
    c.office_id AS "ID отделения"
FROM l2.credits AS c
LEFT JOIN first_credit AS fc ON c.credit_hub_id = fc.credit_hub_id    
WHERE c.disb_date >= DATE '2025-07-01'
    AND c.disb_date < DATE '2026-07-01'
    AND c.product_id NOT IN ((1258,1244,1238,1248,1241,1291,1237,1240,1210,1242,1239,1289,1206,1223,1288,1207,1224,1205,1269)
