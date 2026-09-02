"""
test_07_timeliness.py — проверка своевременности и актуальности данных.

Убеждаемся, что витрина содержит свежие данные, а не устаревшие выгрузки.
В реальном банке витрины должны обновляться ежедневно (или чаще).
"""
from datetime import date, timedelta

from src.db import fetch_one


def test_report_date_is_recent():
    """
    Отчётная дата (report_date) в витрине должна быть не старше 7 дней
    от текущей даты. Если витрина не обновлялась неделю — это инцидент.
    """
    latest_report_date = fetch_one(
        "SELECT MAX(report_date) FROM mart.ftp_contract_mart;"
    )

    # latest_report_date вернётся как объект datetime.date
    threshold_date = date.today() - timedelta(days=7)

    assert latest_report_date is not None, "В витрине нет ни одной записи (MAX(report_date) = NULL)"
    assert latest_report_date >= threshold_date, (
        f"Данные в витрине устарели! Последняя report_date: {latest_report_date}, "
        f"ожидалось не ранее {threshold_date}."
    )


def test_load_dttm_is_present():
    """
    У каждой строки в витрине должна быть проставлена дата/время загрузки (load_dttm).
    Это техническое поле нужно для аудита и понимания, когда именно ETL отработал.
    """
    null_load_count = fetch_one(
        "SELECT COUNT(*) FROM mart.ftp_contract_mart WHERE load_dttm IS NULL;"
    )
    assert null_load_count == 0, f"Найдено {null_load_count} строк без проставленного load_dttm"