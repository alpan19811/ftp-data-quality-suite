-- ============================================================
-- 04_build_dwh.sql
-- ETL: source -> dwh (очистка и трансформация данных)
-- ============================================================
-- Что делаем:
--   1. Дедуплицируем клиентов и договоры через оконную функцию
--      ROW_NUMBER() (в сырых данных были дубли).
--   2. Отсеиваем аномалии: отрицательные суммы, некорректные даты,
--      договоры с несуществующими клиентами (ссылочная целостность).
--   3. Рассчитываем производные поля: срок в днях (term_days)
--      и категорию срока (term_bucket).
-- ============================================================
-- Файл идемпотентен: его можно запускать многократно.
-- ============================================================


-- ------------------------------------------------------------
-- Очистка целевых таблиц для идемпотентности
-- RESTART IDENTITY сбрасывает счётчик суррогатных ключей
-- ------------------------------------------------------------
TRUNCATE TABLE dwh.dim_client_scd2 RESTART IDENTITY;
TRUNCATE TABLE dwh.fact_contract;


-- ============================================================
-- ШАГ 1. Справочник клиентов (SCD Type 2, первичная загрузка)
-- ============================================================
-- Дедупликация: из всех версий одного клиента (по client_id)
-- берём самую свежую по load_dttm. Окно — по client_id,
-- сортировка — по времени загрузки в обратном порядке.
-- ============================================================
WITH dedup_clients AS (
    SELECT
        client_id,
        client_name,
        client_segment,
        region,
        inn,
        load_dttm,
        ROW_NUMBER() OVER (
            PARTITION BY client_id
            ORDER BY load_dttm DESC
        ) AS rn
    FROM source.clients
)
INSERT INTO dwh.dim_client_scd2 (
    client_id, client_name, client_segment, region, inn,
    valid_from, valid_to, is_active
)
SELECT
    client_id,
    client_name,
    client_segment,
    region,
    inn,
    CURRENT_DATE          AS valid_from,
    DATE '9999-12-31'     AS valid_to,
    TRUE                  AS is_active
FROM dedup_clients
WHERE rn = 1;


-- ============================================================
-- ШАГ 2. Факты по кредитным договорам
-- ============================================================
-- 2.1. Дедупликация по contract_id (ROW_NUMBER).
-- 2.2. Фильтрация аномалий:
--        - amount > 0          (отсекаем отрицательные суммы)
--        - maturity >= start   (отсекаем некорректные даты)
-- 2.3. Ссылочная целостность:
--        оставляем только договоры, у которых клиент существует
--        в dwh.dim_client_scd2 (JOIN отсекает несуществующих).
-- 2.4. Расчёт срока и категории срока (терм-бакет).
-- ============================================================
WITH dedup_contracts AS (
    SELECT
        contract_id,
        client_id,
        product_type,
        currency_code,
        start_date,
        maturity_date,
        amount,
        client_rate,
        branch_id,
        status,
        load_dttm,
        ROW_NUMBER() OVER (
            PARTITION BY contract_id
            ORDER BY load_dttm DESC
        ) AS rn
    FROM source.contracts
),
valid_contracts AS (
    SELECT *
    FROM dedup_contracts
    WHERE rn = 1
      AND amount > 0
      AND maturity_date >= start_date
)
INSERT INTO dwh.fact_contract (
    contract_id, client_sk, client_id, product_type, currency_code,
    start_date, maturity_date, amount, client_rate, branch_id, status,
    term_days, term_bucket
)
SELECT
    c.contract_id,
    d.client_sk,
    c.client_id,
    c.product_type,
    c.currency_code,
    c.start_date,
    c.maturity_date,
    c.amount,
    c.client_rate,
    c.branch_id,
    c.status,
    (c.maturity_date - c.start_date) AS term_days,
    CASE
        WHEN (c.maturity_date - c.start_date) <= 365  THEN 'до 1 года'
        WHEN (c.maturity_date - c.start_date) <= 1095 THEN '1-3 года'
        WHEN (c.maturity_date - c.start_date) <= 1825 THEN '3-5 лет'
        ELSE 'свыше 5 лет'
    END AS term_bucket
FROM valid_contracts c
JOIN dwh.dim_client_scd2 d
    ON c.client_id = d.client_id
   AND d.is_active = TRUE;