from typing import List
import os


class Settings:
    APP_NAME: str = "小满记账 API"
    VERSION: str = "5.7.1"

    # 数据库 — 开发环境默认用 SQLite，生产环境用 MySQL
    DATABASE_URL: str = os.environ.get(
        "DATABASE_URL",
        "sqlite:///./xiaojia.db",
    )

    # JWT
    SECRET_KEY: str = os.environ.get("SECRET_KEY", os.urandom(32).hex())
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 天

    # CORS
    CORS_ORIGINS: List[str] = ["*"]

    # 调试
    DEBUG: bool = os.environ.get("DEBUG", "true").lower() == "true"


settings = Settings()
