-- =============================================
-- Итоговый скрипт (MySQL 8.0+)
-- Период: ровно 12 месяцев, июнь 2015 - май 2016
-- (даты в данных - всегда 1-е число месяца, поэтому 2016-06-01 исключена)
-- Операция = чек (Id_check); сумма чека = SUM(Sum_payment) по его строкам
-- =============================================

USE customers_transactions;

-- Представление: один ряд = один чек
CREATE OR REPLACE VIEW checks AS
SELECT Id_check, ID_client, date_new, SUM(Sum_payment) AS check_sum
FROM transactions
WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
GROUP BY Id_check, ID_client, date_new;


-- =============================================
-- 1. Клиенты с непрерывной историей (покупки в каждом из 12 месяцев)
-- =============================================
SELECT c.ID_client,
       COALESCE(ci.Gender, 'NA')             AS gender,
       COALESCE(CAST(ci.Age AS CHAR), 'NA')  AS age,
       ROUND(SUM(c.check_sum) / COUNT(*), 2) AS avg_check,
       ROUND(SUM(c.check_sum) / 12, 2)       AS avg_monthly_amount,
       COUNT(*)                              AS total_operations
FROM checks c
LEFT JOIN customers ci ON c.ID_client = ci.Id_client
WHERE c.ID_client IN (
    SELECT ID_client
    FROM checks
    GROUP BY ID_client
    HAVING COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m')) = 12
)
GROUP BY c.ID_client, ci.Gender, ci.Age
ORDER BY SUM(c.check_sum) DESC;


-- =============================================
-- 2. Статистика в разрезе месяцев
-- =============================================
SELECT DATE_FORMAT(date_new, '%Y-%m')                     AS month,
       ROUND(SUM(check_sum) / COUNT(*), 2)                AS avg_check_month,
       COUNT(*)                                           AS operations_in_month,
       COUNT(DISTINCT ID_client)                          AS clients_in_month,
       ROUND(COUNT(*) / COUNT(DISTINCT ID_client), 2)     AS ops_per_client,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)               AS pct_operations_of_year,
       ROUND(100 * SUM(check_sum) / SUM(SUM(check_sum)) OVER (), 2)   AS pct_amount_of_year
FROM checks
GROUP BY 1
ORDER BY 1;


-- =============================================
-- 3. Соотношение M/F/NA по месяцам и доля затрат
-- =============================================
SELECT DATE_FORMAT(c.date_new, '%Y-%m') AS month,
       COALESCE(ci.Gender, 'NA')        AS gender,
       COUNT(*)                         AS operations,
       SUM(c.check_sum)                 AS total_amount,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY DATE_FORMAT(c.date_new, '%Y-%m')), 2)                AS pct_operations,
       ROUND(100 * SUM(c.check_sum) / SUM(SUM(c.check_sum)) OVER (PARTITION BY DATE_FORMAT(c.date_new, '%Y-%m')), 2) AS pct_amount
FROM checks c
LEFT JOIN customers ci ON c.ID_client = ci.Id_client
GROUP BY 1, 2
ORDER BY 1, 2;


-- =============================================
-- 4.1 Возрастные группы (шаг 10 лет) за весь период
-- =============================================
WITH g AS (
    SELECT c.check_sum, c.date_new,
           CASE WHEN ci.Age IS NULL THEN 'NA'
                WHEN ci.Age < 20 THEN '0-19'
                WHEN ci.Age < 30 THEN '20-29'
                WHEN ci.Age < 40 THEN '30-39'
                WHEN ci.Age < 50 THEN '40-49'
                WHEN ci.Age < 60 THEN '50-59'
                WHEN ci.Age < 70 THEN '60-69'
                ELSE '70+' END AS age_group
    FROM checks c
    LEFT JOIN customers ci ON c.ID_client = ci.Id_client
)
SELECT age_group,
       SUM(check_sum) AS total_amount,
       COUNT(*)       AS total_operations,
       ROUND(100 * SUM(check_sum) / SUM(SUM(check_sum)) OVER (), 2) AS pct_amount,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)             AS pct_operations
FROM g
GROUP BY age_group
ORDER BY age_group = 'NA', age_group;


-- =============================================
-- 4.2 Возрастные группы поквартально
-- (2015-Q2 = только июнь, 2016-Q2 = апрель и май)
-- =============================================
WITH g AS (
    SELECT c.check_sum, c.date_new,
           CASE WHEN ci.Age IS NULL THEN 'NA'
                WHEN ci.Age < 20 THEN '0-19'
                WHEN ci.Age < 30 THEN '20-29'
                WHEN ci.Age < 40 THEN '30-39'
                WHEN ci.Age < 50 THEN '40-49'
                WHEN ci.Age < 60 THEN '50-59'
                WHEN ci.Age < 70 THEN '60-69'
                ELSE '70+' END AS age_group
    FROM checks c
    LEFT JOIN customers ci ON c.ID_client = ci.Id_client
)
SELECT CONCAT(YEAR(date_new), '-Q', QUARTER(date_new)) AS quarter,
       age_group,
       ROUND(SUM(check_sum) / COUNT(*), 2)                  AS avg_check,
       ROUND(COUNT(*) / COUNT(DISTINCT date_new), 2)        AS avg_ops_per_month,
       ROUND(100 * SUM(check_sum) / SUM(SUM(check_sum)) OVER (PARTITION BY CONCAT(YEAR(date_new), '-Q', QUARTER(date_new))), 2) AS pct_amount_in_quarter,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY CONCAT(YEAR(date_new), '-Q', QUARTER(date_new))), 2)             AS pct_operations_in_quarter
FROM g
GROUP BY quarter, age_group
ORDER BY quarter, age_group = 'NA', age_group;
