"""
test_06_reconciliation.py — сверка данных между слоями (консистентность).

Убеждаемся, что при построении витрины (dwh -> mart) мы не потеряли
и не задублировали ни одной строки и ни одного рубля.
Это классическая проверка ETL-процесса: "что вошло, то и вышло".
"""
from decimal import Decimal

from src.db import fetch_one


def test_dwh_to_mart_row_count():
    """
    Количество договоров в dwh.fact_contract должно точно совпадать
    с количеством строк в итоговой витрине mart.ftp_contract_mart.
    """
    dwh_count = fetch_one("SELECT COUNT(*) FROM dwh.fact_contract;")
    mart_count = fetch_one("SELECT COUNT(*) FROM mart.ftp_contract_mart;")

    assert dwh_count == mart_count, (
        f"Расхождение в количестве строк: DWH={dwh_count}, Mart={mart_count}. "
        f"Возможно, часть договоров не попала в витрину из-за отсутствия ставки казначейства."
    )


def test_dwh_to_mart_total_amount():
    """
    Сумма всех кредитов в dwh должна совпадать с суммой в витрине.
    Ни один рубль не должен потеряться или появиться из ниоткуда.

    Важный нюанс: PostgreSQL возвращает NUMERIC как Python Decimal,
    поэтому сравниваем через Decimal с точностью до копейки.
    Использование float для финансовых сумм некорректно из-за
    ошибок представления чисел с плавающей точкой.
    """
    dwh_sum = fetch_one("SELECT SUM(amount) FROM dwh.fact_contract;")
    mart_sum = fetch_one("SELECT SUM(amount) FROM mart.ftp_contract_mart;")

    # Приводим к Decimal на случай, если БД вернула None или другой тип
    dwh_amount = Decimal(dwh_sum) if dwh_sum is not None else Decimal("0")
    mart_amount = Decimal(mart_sum) if mart_sum is not None else Decimal("0")

    # Допуск — 1 копейка (абсолютная точность для денежных расчётов)
    tolerance = Decimal("0.01")

    assert abs(dwh_amount - mart_amount) <= tolerance, (
        f"Расхождение в суммах: DWH={dwh_amount}, Mart={mart_amount}. "
        f"Разница превышает допустимую погрешность {tolerance}."
    )