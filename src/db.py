"""
db.py — модуль для работы с PostgreSQL.

Предоставляет:
  - get_connection()       — подключение через psycopg2
  - fetch_one(query)       — выполнить запрос и вернуть одно значение
  - fetch_all(query)       — выполнить запрос и вернуть все строки
  - fetch_dataframe(query) — выполнить запрос и вернуть pandas.DataFrame
"""
from typing import Any

import pandas as pd
import psycopg2

from src.config import get_db_config


def get_connection():
    """Возвращает соединение с PostgreSQL (контекстный менеджер)."""
    config = get_db_config()
    return psycopg2.connect(**config)


def fetch_one(query: str, params: tuple | None = None) -> Any:
    """
    Выполняет SQL-запрос и возвращает ОДНО значение
    (первую ячейку первой строки результата).

    Типичное использование:
        COUNT(*), MAX(...), EXISTS-проверки.
    """
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(query, params)
            row = cursor.fetchone()
            return row[0] if row else None


def fetch_all(query: str, params: tuple | None = None) -> list[tuple]:
    """
    Выполняет SQL-запрос и возвращает все строки результата
    как список кортежей.
    """
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(query, params)
            return cursor.fetchall()


def fetch_dataframe(query: str, params: tuple | None = None) -> pd.DataFrame:
    """
    Выполняет SQL-запрос и возвращает результат как pandas.DataFrame.

    Очень удобно для сверок и агрегаций в тестах качества данных:
    сразу получаем табличный вид с именами колонок.
    """
    with get_connection() as conn:
        return pd.read_sql_query(query, conn, params=params)


if __name__ == "__main__":
    # Быстрая проверка подключения: считаем строки в витрине
    count = fetch_one("SELECT COUNT(*) FROM mart.ftp_contract_mart;")
    print(f"Витрина mart.ftp_contract_mart содержит {count} строк")

    # Проверка fetch_dataframe
    df = fetch_dataframe(
        "SELECT contract_id, client_name, total_transfer_rate "
        "FROM mart.ftp_contract_mart ORDER BY contract_id"
    )
    print("\nDataFrame:")
    print(df)