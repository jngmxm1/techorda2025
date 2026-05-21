-- =============================================
-- ЕДИНЫЙ SQL-БЛОК ДЛЯ MySQL
-- Таблицы: customers и transactions
-- Период: 01.06.2015 - 01.06.2016
-- =============================================

USE customers_transactions;

-- =============================================
-- 1. Клиенты с непрерывной историей (минимум 1 покупка каждый месяц — 12 месяцев)
-- =============================================
WITH client_monthly_status AS (
    -- Считаем, в скольких уникальных месяцах у клиента были покупки
    SELECT 
        ID_client,
        COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m-01')) AS active_months
    FROM transactions
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client
    HAVING active_months = 12
)
SELECT 
    t.ID_client,
    ci.gender,
    ci.age,
    ROUND(AVG(t.Sum_payment), 2) AS avg_check,
    ROUND(SUM(t.Sum_payment) / 12, 2) AS avg_monthly_amount,
    COUNT(t.Id_check) AS total_operations
FROM transactions t
JOIN client_monthly_status cms ON t.ID_client = cms.ID_client
LEFT JOIN customers ci ON t.ID_client = ci.ID_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY t.ID_client, ci.gender, ci.age
ORDER BY SUM(t.Sum_payment) DESC;


-- =============================================
-- 2. Статистика в разрезе месяцев
-- =============================================
WITH monthly_metrics AS (
    SELECT 
        DATE_FORMAT(date_new, '%Y-%m-01') AS month_start,
        AVG(Sum_payment) AS avg_check_month,
        -- Считаем среднее в день для этого месяца (операции и клиенты)
        COUNT(Id_check) / COUNT(DISTINCT date_new) AS avg_operations_per_day,
        COUNT(DISTINCT ID_client) / COUNT(DISTINCT date_new) AS avg_clients_per_day,
        -- Абсолютные значения для расчета долей ниже
        COUNT(Id_check) AS total_operations_month,
        SUM(Sum_payment) AS total_amount_month
    FROM transactions
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY DATE_FORMAT(date_new, '%Y-%m-01')
),
year_totals AS (
    SELECT 
        SUM(total_operations_month) AS total_ops_year,
        SUM(total_amount_month) AS total_amount_year
    FROM monthly_metrics
)
SELECT 
    m.month_start,
    ROUND(m.avg_check_month, 2) AS avg_check_month,
    ROUND(m.avg_operations_per_day, 2) AS avg_operations_daily_in_month,
    ROUND(m.avg_clients_per_day, 2) AS avg_clients_daily_in_month,
    ROUND(100.0 * m.total_operations_month / yt.total_ops_year, 2) AS pct_operations_of_year,
    ROUND(100.0 * m.total_amount_month / yt.total_amount_year, 2) AS pct_amount_of_year
FROM monthly_metrics m
CROSS JOIN year_totals yt
ORDER BY m.month_start;


-- =============================================
-- 3. Процентное соотношение M/F/NA по месяцам + доли
-- =============================================
SELECT 
    DATE_FORMAT(t.date_new, '%Y-%m-01') AS month_start,
    COALESCE(ci.gender, 'NA') AS gender,
    COUNT(*) AS operations,
    SUM(t.Sum_payment) AS total_amount,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m-01')), 2) AS pct_operations,
    ROUND(100.0 * SUM(t.Sum_payment) / SUM(SUM(t.Sum_payment)) OVER (PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m-01')), 2) AS pct_amount
FROM transactions t
LEFT JOIN customers ci ON t.ID_client = ci.ID_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY DATE_FORMAT(t.date_new, '%Y-%m-01'), COALESCE(ci.gender, 'NA')
ORDER BY month_start, gender;


-- =============================================
-- 4. Возрастные группы (Шаг 10 лет)
-- =============================================

-- Подзапрос 4.1: За весь период (с дублированием структуры CTE для чистоты выполнения)
WITH age_grouped AS (
    SELECT 
        t.Sum_payment, t.Id_check, t.date_new,
        CASE 
            WHEN ci.age IS NULL THEN 'NA'
            WHEN ci.age < 20 THEN '0-19'
            WHEN ci.age < 30 THEN '20-29'
            WHEN ci.age < 40 THEN '30-39'
            WHEN ci.age < 50 THEN '40-49'
            WHEN ci.age < 60 THEN '50-59'
            WHEN ci.age < 70 THEN '60-69'
            ELSE '70+' 
        END AS age_group
    FROM transactions t
    LEFT JOIN customers ci ON t.ID_client = ci.ID_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
)
SELECT 
    age_group,
    SUM(Sum_payment) AS total_amount,
    COUNT(Id_check) AS total_operations,
    ROUND(100.0 * SUM(Sum_payment) / SUM(SUM(Sum_payment)) OVER (), 2) AS pct_amount,
    ROUND(100.0 * COUNT(Id_check) / SUM(COUNT(Id_check)) OVER (), 2) AS pct_operations
FROM age_grouped
GROUP BY age_group
ORDER BY 
    CASE age_group 
        WHEN 'NA' THEN 999 
        ELSE CAST(SUBSTRING_INDEX(age_group, '-', 1) AS UNSIGNED) 
    END;

-- Подзапрос 4.2: Поквартально
WITH age_grouped AS (
    SELECT 
        t.Sum_payment, t.Id_check, t.date_new,
        CASE 
            WHEN ci.age IS NULL THEN 'NA'
            WHEN ci.age < 20 THEN '0-19'
            WHEN ci.age < 30 THEN '20-29'
            WHEN ci.age < 40 THEN '30-39'
            WHEN ci.age < 50 THEN '40-49'
            WHEN ci.age < 60 THEN '50-59'
            WHEN ci.age < 70 THEN '60-69'
            ELSE '70+' 
        END AS age_group
    FROM transactions t
    LEFT JOIN customers ci ON t.ID_client = ci.ID_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
)
SELECT 
    CONCAT(YEAR(date_new), '-Q', QUARTER(date_new)) AS quarter,
    age_group,
    ROUND(AVG(Sum_payment), 2) AS avg_check_quarter,
    ROUND(COUNT(Id_check) / COUNT(DISTINCT date_new), 2) AS avg_operations_daily_quarter, -- средний показатель по ТЗ
    ROUND(100.0 * SUM(Sum_payment) / SUM(SUM(Sum_payment)) OVER (PARTITION BY CONCAT(YEAR(date_new), '-Q', QUARTER(date_new))), 2) AS pct_amount_in_quarter
FROM age_grouped
GROUP BY CONCAT(YEAR(date_new), '-Q', QUARTER(date_new)), age_group
ORDER BY quarter, 
         CASE age_group 
             WHEN 'NA' THEN 999 
             ELSE CAST(SUBSTRING_INDEX(age_group, '-', 1) AS UNSIGNED) 
         END;