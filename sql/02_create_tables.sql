-- ============================================================
-- 02_create_tables.sql
-- Создание всех таблиц проекта (слои: source -> dwh -> mart -> dq)
-- ============================================================
-- Конвенции:
--   * Ставки хранятся как доли: 0.123456 = 12.3456%
--   * Денежные суммы: NUMERIC(18,2)
--   * В слое source НЕТ первичных ключей и ограничений уникальности:
--     сырые данные могут содержать дубли и аномалии,
--     которые мы будем выявлять проверками качества и дедуплицировать в dwh.
-- ============================================================


-- ============================================================
-- СЛОЙ SOURCE: сырые данные (имитация выгрузок из АБС и казначейства)
-- ============================================================

-- Клиенты (как приходят из операционной системы банка)
CREATE TABLE IF NOT EXISTS source.clients (
    client_id       BIGINT,
    client_name     TEXT,
    client_segment  TEXT,
    region          TEXT,
    inn             TEXT,
    load_dttm       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE source.clients IS 'Сырые данные по клиентам. Могут содержать дубли (демонстрация проблем качества данных).';

-- Кредитные договоры
CREATE TABLE IF NOT EXISTS source.contracts (
    contract_id     BIGINT,
    client_id       BIGINT,
    product_type    TEXT,
    currency_code   TEXT,
    start_date      DATE,
    maturity_date   DATE,
    amount          NUMERIC(18,2),
    client_rate     NUMERIC(10,6),
    branch_id       BIGINT,
    status          TEXT,
    load_dttm       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE source.contracts IS 'Сырые данные по кредитным договорам: сумма, клиентская ставка, сроки, продукт.';

-- Ставки казначейства (источник для расчёта FTP)
CREATE TABLE IF NOT EXISTS source.treasury_ftp_rates (
    rate_id                         BIGINT,
    product_type                    TEXT,
    currency_code                   TEXT,
    term_bucket                     TEXT,
    base_ftp_rate                   NUMERIC(10,6),
    liquidity_premium               NUMERIC(10,6),
    reserve_compensation            NUMERIC(10,6),
    prepayment_option_compensation  NUMERIC(10,6),
    valid_from                      DATE,
    valid_to                        DATE,
    load_dttm                       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE source.treasury_ftp_rates IS 'Трансфертные ставки казначейства с разбивкой на компоненты: базовая ставка, премия за ликвидность, компенсация резервов, компенсация опциона досрочного погашения.';


-- ============================================================
-- СЛОЙ DWH: корпоративное хранилище (очищенные данные)
-- ============================================================

-- Измерение "Клиент" по методологии SCD Type 2 (с историей изменений)
CREATE TABLE IF NOT EXISTS dwh.dim_client_scd2 (
    client_sk       BIGINT GENERATED ALWAYS AS IDENTITY,
    client_id       BIGINT NOT NULL,
    client_name     TEXT,
    client_segment  TEXT,
    region          TEXT,
    inn             TEXT,
    valid_from      DATE NOT NULL,
    valid_to        DATE NOT NULL DEFAULT '9999-12-31',
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    load_dttm       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_dim_client_scd2 PRIMARY KEY (client_sk)
);

COMMENT ON TABLE dwh.dim_client_scd2 IS 'Справочник клиентов по SCD Type 2: хранит историю изменений атрибутов клиента (сегмент, регион и т.д.).';

-- Факт "Кредитный договор"
CREATE TABLE IF NOT EXISTS dwh.fact_contract (
    contract_id     BIGINT NOT NULL,
    client_sk       BIGINT,
    client_id       BIGINT,
    product_type    TEXT,
    currency_code   TEXT,
    start_date      DATE,
    maturity_date   DATE,
    amount          NUMERIC(18,2),
    client_rate     NUMERIC(10,6),
    branch_id       BIGINT,
    status          TEXT,
    term_days       INT,
    term_bucket     TEXT,
    load_dttm       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_fact_contract PRIMARY KEY (contract_id)
);

COMMENT ON TABLE dwh.fact_contract IS 'Фактическая таблица по кредитным договорам. Содержит рассчитанные поля: срок в днях (term_days) и категорию срока (term_bucket).';


-- ============================================================
-- СЛОЙ MART: витрина данных (предметная область вакансии)
-- ============================================================

-- Витрина расчёта трансфертных ставок (FTP) по кредитным договорам
CREATE TABLE IF NOT EXISTS mart.ftp_contract_mart (
    contract_id                     BIGINT NOT NULL,
    client_id                       BIGINT,
    client_name                     TEXT,
    client_segment                  TEXT,
    product_type                    TEXT,
    currency_code                   TEXT,
    start_date                      DATE,
    maturity_date                   DATE,
    term_bucket                     TEXT,
    amount                          NUMERIC(18,2),
    client_rate                     NUMERIC(10,6),
    base_ftp_rate                   NUMERIC(10,6),
    liquidity_premium               NUMERIC(10,6),
    reserve_compensation            NUMERIC(10,6),
    prepayment_option_compensation  NUMERIC(10,6),
    total_transfer_rate             NUMERIC(10,6),
    client_margin                   NUMERIC(10,6),
    annual_ftp_charge               NUMERIC(18,2),
    annual_client_interest          NUMERIC(18,2),
    annual_margin_amount            NUMERIC(18,2),
    report_date                     DATE,
    load_dttm                       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_ftp_contract_mart PRIMARY KEY (contract_id, report_date)
);

COMMENT ON TABLE mart.ftp_contract_mart IS 'Итоговая витрина: расчёт трансфертных ставок FTP, компенсаций, маржи клиента и годовых сумм по каждому договору.';


-- ============================================================
-- СЛОЙ DQ: результаты проверок качества данных
-- ============================================================

-- Журнал результатов проверок качества данных
CREATE TABLE IF NOT EXISTS dq.dq_check_results (
    check_id        BIGINT GENERATED ALWAYS AS IDENTITY,
    check_name      TEXT NOT NULL,
    check_category  TEXT NOT NULL,
    status          TEXT NOT NULL,
    failed_rows     INT,
    details         TEXT,
    run_dttm        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_dq_check_results PRIMARY KEY (check_id)
);

COMMENT ON TABLE dq.dq_check_results IS 'Журнал результатов Data Quality проверок: какая проверка, статус, количество проблемных строк, детали.';