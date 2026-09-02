"""
test_04_validity.py — проверка валидности (допустимости) значений.

Проверяем бизнес-правила для числовых полей:
  - суммы кредитов должны быть положительными;
  - клиентская ставка — в разумных пределах (0 < rate < 1, т.е. 0–100%);
  - итоговая трансфертная ставка — положительная и меньше клиентской
    (иначе банк работает в убыток по договору).
"""
from src.db import fetch_one


def test_amounts_are_positive():
    """Суммы кредитов в витрине должны быть строго положительными."""
    query = """
        SELECT COUNT(*)
        FROM mart.ftp_contract_mart
        WHERE amount <= 0;
    """
    count = fetch_one(query)
    assert count == 0, f"Найдено {count} договоров с неположительной суммой"


def test_client_rate_in_valid_range():
    """Клиентская ставка должна быть в диапазоне (0; 1), т.е. 0–100%."""
    query = """
        SELECT COUNT(*)
        FROM mart.ftp_contract_mart
        WHERE client_rate <= 0 OR client_rate >= 1;
    """
    count = fetch_one(query)
    assert count == 0, f"Найдено {count} договоров со ставкой вне диапазона (0; 1)"


def test_total_transfer_rate_is_positive():
    """Итоговая трансфертная ставка должна быть положительной."""
    query = """
        SELECT COUNT(*)
        FROM mart.ftp_contract_mart
        WHERE total_transfer_rate <= 0;
    """
    count = fetch_one(query)
    assert count == 0, f"Найдено {count} договоров с неположительной трансфертной ставкой"


def test_margin_is_not_negative():
    """
    Маржа клиента не должна быть отрицательной.

    Отрицательная маржа означает, что клиентская ставка НИЖЕ стоимости
    фондирования — банк теряет деньги на таком договоре. Такие случаи
    требуют немедленного разбирательства.
    """
    query = """
        SELECT COUNT(*)
        FROM mart.ftp_contract_mart
        WHERE client_margin < 0;
    """
    count = fetch_one(query)
    assert count == 0, (
        f"Найдено {count} договоров с отрицательной маржой — "
        f"клиентская ставка ниже стоимости фондирования!"
    )