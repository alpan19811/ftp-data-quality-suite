"""
test_05_calculation_accuracy.py — проверка корректности расчётов.
(Самая важная категория проверок для вакансии.)

Подход:
  1. Загружаем витрину в pandas DataFrame.
  2. Независимо пересчитываем каждый производный показатель.
  3. Сравниваем с фактическими значениями через np.isclose
     (числовое сравнение с допуском).

Используем:
  - pandas  — загрузка и векторизованные операции с данными;
  - NumPy   — точные числовые сравнения (np.isclose).
"""
import numpy as np

from src.db import fetch_dataframe


def load_mart() -> "pd.DataFrame":
    """Загружает витрину в pandas DataFrame для анализа."""
    query = """
        SELECT
            contract_id,
            amount,
            client_rate,
            base_ftp_rate,
            liquidity_premium,
            reserve_compensation,
            prepayment_option_compensation,
            total_transfer_rate,
            client_margin,
            annual_ftp_charge,
            annual_client_interest,
            annual_margin_amount
        FROM mart.ftp_contract_mart
        ORDER BY contract_id
    """
    return fetch_dataframe(query)


def test_total_transfer_rate_is_sum_of_components():
    """
    Итоговая трансфертная ставка должна равняться сумме четырёх компонентов:
    базовая ставка + премия за ликвидность + компенсация резервов
    + компенсация опциона досрочного погашения.
    """
    df = load_mart()

    expected = (
        df["base_ftp_rate"]
        + df["liquidity_premium"]
        + df["reserve_compensation"]
        + df["prepayment_option_compensation"]
    )

    assert np.isclose(df["total_transfer_rate"], expected, atol=1e-6).all(), (
        "Итоговая трансфертная ставка не равна сумме компонентов"
    )


def test_client_margin_formula():
    """Маржа клиента = клиентская ставка - итоговая трансфертная ставка."""
    df = load_mart()

    expected_margin = df["client_rate"] - df["total_transfer_rate"]

    assert np.isclose(df["client_margin"], expected_margin, atol=1e-6).all(), (
        "Маржа клиента рассчитана некорректно"
    )


def test_annual_ftp_charge_formula():
    """Годовая FTP-плата = сумма кредита × итоговая трансфертная ставка."""
    df = load_mart()

    expected_charge = df["amount"] * df["total_transfer_rate"]

    assert np.isclose(df["annual_ftp_charge"], expected_charge, atol=0.01).all(), (
        "Годовая FTP-плата рассчитана некорректно"
    )


def test_annual_client_interest_formula():
    """Годовой процент клиента = сумма кредита × клиентская ставка."""
    df = load_mart()

    expected_interest = df["amount"] * df["client_rate"]

    assert np.isclose(df["annual_client_interest"], expected_interest, atol=0.01).all(), (
        "Годовой процент клиента рассчитан некорректно"
    )


def test_annual_margin_amount_formula():
    """Годовая маржа в деньгах = сумма кредита × маржа клиента."""
    df = load_mart()

    expected_margin_amount = df["amount"] * df["client_margin"]

    assert np.isclose(df["annual_margin_amount"], expected_margin_amount, atol=0.01).all(), (
        "Годовая маржа в деньгах рассчитана некорректно"
    )