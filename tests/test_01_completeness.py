"""
test_01_completeness.py — проверка полноты данных (completeness).

Убеждаемся, что в витрине mart.ftp_contract_mart нет NULL
в критичных полях (contract_id, client_id, amount, rates и т.д.).
"""
from src.db import fetch_one


def test_no_nulls_in_critical_mart_fields():
    """
    Проверяем, что в витрине нет строк с NULL в обязательных полях.

    Если хотя бы одно критичное поле NULL — тест падает,
    мы видим проблему качества данных.
    """
    query = """
        SELECT COUNT(*)
        FROM mart.ftp_contract_mart
        WHERE contract_id IS NULL
           OR client_id IS NULL
           OR client_name IS NULL
           OR product_type IS NULL
           OR currency_code IS NULL
           OR start_date IS NULL
           OR maturity_date IS NULL
           OR amount IS NULL
           OR client_rate IS NULL
           OR total_transfer_rate IS NULL
           OR client_margin IS NULL
           OR annual_ftp_charge IS NULL
           OR report_date IS NULL;
    """

    count = fetch_one(query)

    assert count == 0, f"Найдено {count} строк с NULL в критичных полях витрины"