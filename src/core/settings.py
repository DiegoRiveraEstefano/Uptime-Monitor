from enum import Enum
from pathlib import Path
from typing import Optional

from msgspec import Struct
from msgspec_settings import BaseSettings


class Environment(str, Enum):
    DEVELOPMENT = "development"
    PRODUCTION = "production"
    TESTING = "testing"


class AppSettings(Struct):
    name: str = "Uptime Monitor"
    env: Environment = Environment.DEVELOPMENT
    debug: bool = True
    version: str = "0.1.0"
    secret_key: str = "change-me-in-production"


class LoggingSettings(Struct):
    level: str = "INFO"
    json_format: bool = False


class DatabaseSettings(Struct):
    dsn: str = "sqlite+aiosqlite:///./database.sqlite"


class Settings(BaseSettings):
    app: AppSettings = AppSettings()
    logging: LoggingSettings = LoggingSettings()
    database: DatabaseSettings = DatabaseSettings()


# Instantiate settings
# By default, it will look for environment variables or a .env file
settings = Settings()

# Base project directory
BASE_DIR = Path(__file__).resolve().parent.parent.parent
