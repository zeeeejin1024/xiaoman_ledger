from sqlalchemy import ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base


class MerchantCategoryRule(Base):
    __tablename__ = "merchant_category_rules"
    __table_args__ = (UniqueConstraint("user_id", "merchant_key", name="uq_user_merchant"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, index=True)
    merchant_key: Mapped[str] = mapped_column(String(100), index=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"))
    confirmations: Mapped[int] = mapped_column(Integer, default=1)
