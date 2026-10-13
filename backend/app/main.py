from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.core.database import init_db
from app.api.router import api_router
from app.models.category import seed_categories
from app.models.user_setting import UserSetting
from app.models.wallet_budget import WalletBudget
from app.models.wallet_category_binding import WalletCategoryBinding
from app.models.idempotency_request import IdempotencyRequest
from app.models.merchant_category_rule import MerchantCategoryRule
from app.models.ocr_cache import OcrCache
from app.models.deal import Deal
from app.core.database import Session, engine


def _setup():
    init_db()
    db = Session(engine)
    try:
        seed_categories(db)
    finally:
        db.close()


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.VERSION,
)
app.add_event_handler("startup", _setup)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.get("/")
def root():
    return {"name": settings.APP_NAME, "version": settings.VERSION}
