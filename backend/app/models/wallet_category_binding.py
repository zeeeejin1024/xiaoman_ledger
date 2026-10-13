from sqlalchemy import Boolean, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class WalletCategoryBinding(Base):
    __tablename__ = "wallet_category_bindings"
    __table_args__ = (UniqueConstraint("wallet_id", "category_id", name="uq_wallet_category"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    wallet_id: Mapped[int] = mapped_column(ForeignKey("wallet_budgets.id"), index=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"), index=True)
    include_descendants: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
