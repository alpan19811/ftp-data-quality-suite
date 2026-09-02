-- ============================================================
-- 05_build_mart.sql
-- Построение итоговой витрины расчёта трансфертных ставок (FTP)
-- ============================================================
-- Что делаем:
--   1. Для каждого договора подбираем АКТУАЛЬНУЮ ставку казначейства
--      по трём ключам: продукт, валюта, категория срока (term_bucket).
--      Ставка должна действовать на дату начала договора.
--      Если подходящих ставок несколько — берём самую свежую
--      через оконную функцию ROW_NUMBER().
--   2. Рассчитываем итоговую трансфертную ставку и её компоненты.
--   3. Рассчитываем маржу клиента и годовые суммы.
-- ============================================================
-- Формулы:
--   total_transfer_rate = base_ftp_rate
--                       + liquidity_premium
--                       + reserve_compensation
--                       + prepayment_option_compensation
--
--   client_margin       = client_rate - total_transfer_rate
--   annual_ftp_charge   = amount * total_transfer_rate
--   annual_client_interest = amount * client_rate
--   annual_margin_amount   = amount * client_margin
-- ============================================================
-- Файл идемпотентен: его можно запускать многократно.
-- ============================================================


-- ------------------------------------------------------------
-- Очистка витрины для идемпотентности
-- ------------------------------------------------------------
TRUNCATE TABLE mart.ftp_contract_mart;


-- ============================================================
-- Подбор актуальной ставки казначейства для каждого договора
-- ============================================================
-- Соединяем договор со ставкой по (продукт, валюта, категория срока),
-- при этом дата начала договора должна попадать в период действия ставки.
-- Если таких ставок несколько, оконная функция ROW_NUMBER()
-- ранжирует их по valid_from (самая свежая = 1), и мы берём только её.
-- ============================================================
WITH rates_for_contract AS (
    SELECT
        fc.contract_id,
        r.base_ftp_rate,
        r.liquidity_premium,
        r.reserve_compensation,
        r.prepayment_option_compensation,
        ROW_NUMBER() OVER (
            PARTITION BY fc.contract_id
            ORDER BY r.valid_from DESC
        ) AS rn
    FROM dwh.fact_contract fc
    JOIN source.treasury_ftp_rates r
        ON  fc.product_type  = r.product_type
        AND fc.currency_code = r.currency_code
        AND fc.term_bucket   = r.term_bucket
        AND fc.start_date   >= r.valid_from
        AND fc.start_date   <= r.valid_to
)


-- ============================================================
-- Финальная сборка витрины
-- ============================================================
INSERT INTO mart.ftp_contract_mart (
    contract_id, client_id, client_name, client_segment,
    product_type, currency_code, start_date, maturity_date, term_bucket,
    amount, client_rate,
    base_ftp_rate, liquidity_premium, reserve_compensation, prepayment_option_compensation,
    total_transfer_rate, client_margin,
    annual_ftp_charge, annual_client_interest, annual_margin_amount,
    report_date
)
SELECT
    fc.contract_id,
    fc.client_id,
    dc.client_name,
    dc.client_segment,
    fc.product_type,
    fc.currency_code,
    fc.start_date,
    fc.maturity_date,
    fc.term_bucket,
    fc.amount,
    fc.client_rate,
    rfc.base_ftp_rate,
    rfc.liquidity_premium,
    rfc.reserve_compensation,
    rfc.prepayment_option_compensation,

    -- Итоговая трансфертная ставка (сумма всех компонентов)
    (
        rfc.base_ftp_rate
        + rfc.liquidity_premium
        + rfc.reserve_compensation
        + rfc.prepayment_option_compensation
    ) AS total_transfer_rate,

    -- Маржа клиента: клиентская ставка минус трансфертная ставка
    (
        fc.client_rate
        - (
            rfc.base_ftp_rate
            + rfc.liquidity_premium
            + rfc.reserve_compensation
            + rfc.prepayment_option_compensation
        )
    ) AS client_margin,

    -- Годовая FTP-плата (сколько договор "стоит" с точки зрения фондирования)
    ROUND(fc.amount * (
        rfc.base_ftp_rate
        + rfc.liquidity_premium
        + rfc.reserve_compensation
        + rfc.prepayment_option_compensation
    ), 2) AS annual_ftp_charge,

    -- Годовой процент, который платит клиент
    ROUND(fc.amount * fc.client_rate, 2) AS annual_client_interest,

    -- Годовая маржа в деньгах
    ROUND(fc.amount * (
        fc.client_rate
        - (
            rfc.base_ftp_rate
            + rfc.liquidity_premium
            + rfc.reserve_compensation
            + rfc.prepayment_option_compensation
        )
    ), 2) AS annual_margin_amount,

    CURRENT_DATE AS report_date

FROM dwh.fact_contract fc
JOIN dwh.dim_client_scd2 dc
    ON  fc.client_id = dc.client_id
    AND dc.is_active = TRUE
JOIN rates_for_contract rfc
    ON  fc.contract_id = rfc.contract_id
    AND rfc.rn = 1;