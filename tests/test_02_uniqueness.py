"""
test_02_uniqueness.py — проверка уникальности бизнес-ключей.

Убеждаемся, что в витрине нет дублей по бизнес-ключу
(contract_id, report_date) — каждая комбинация должна быть уникальной.
"""
from src.db import fetch_one


def test_no_duplicates_by_business_key():
    """
    Проверяем, что бизнес-ключ (contract_id + report_date) уникален.

    Если есть дубли — тест падает, мы видим проблему дедупликации.
    """
    query = """
        SELECT COUNT(*)
        FROM (
            SELECT contract_id, report_date, COUNT(*) AS cnt
            FROM mart.ftp_contract_mart
            GROUP BY contract_id, report_date
            HAVING COUNT(*) > 1
        ) duplicates;
    """

    count = fetch_one(query)

    assert count == 0, f"Найдено {count} дублей по бизнес-ключу (contract_id, report_date)"