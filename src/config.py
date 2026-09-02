"""
config.py — загрузка настроек подключения к БД из .env
"""
import os
from dotenv import load_dotenv

# Загружаем переменные из .env (если файл существует)
load_dotenv()

# Настройки подключения к PostgreSQL
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5433")),
    "dbname": os.getenv("DB_NAME", "ftp_dq"),
    "user": os.getenv("DB_USER", "qa_user"),
    "password": os.getenv("DB_PASSWORD", "qa_password"),
}


def get_db_config() -> dict:
    """Возвращает словарь с настройками подключения к БД."""
    return DB_CONFIG.copy()


if __name__ == "__main__":
    # Простая проверка: запускаем модуль как скрипт и смотрим настройки
    print("DB Config loaded:")
    for key, value in get_db_config().items():
        if key == "password":
            print(f"  {key}: ********")
        else:
            print(f"  {key}: {value}")