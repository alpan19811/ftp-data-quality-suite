"""
test_03_referential_integrity.py — проверка ссылочной целостности.

Убеждаемся, что все клиенты, присутствующие в витрине,
реально существуют в справочнике dwh.dim_client_scd2.

Если в витрине появился "клиент-призрак" (которого нет в справочнике) —
это серьёзный дефект данных, который приведёт к ошибкам в отчётности.
"""
from src.db import fetch_one


def test_all_mart_clients_exist_in_dimension():
    """
    Проверяем, что каждый client_id из витрины есть в справочнике клиентов.

    Используем LEFT JOIN: если для строки витрины не нашлось пары
    в справочнике, поля справочника будут NULL — такие строки и считаем.
    """
    query = """
        SELECT COUNT(*)
        FROM mart.ftp_contract_mart m
        LEFT JOIN dwh.dim_client_scd2 d
            ON  m.client_id = d.client_id
            AND d.is_active = TRUE
        WHERE d.client_id IS NULL;
    """

    orphan_count = fetch_one(query)

    assert orphan_count == 0, (
        f"Найдено {orphan_count} договоров в витрине "
        f"с несуществующими клиентами (сиротские записи)"
    )