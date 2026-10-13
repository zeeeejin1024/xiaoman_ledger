from typing import Optional
from datetime import datetime, timezone
from sqlalchemy import String, Integer, Float, Date, Boolean, ForeignKey, Enum as SAEnum, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
import enum


class AutoRuleType(str, enum.Enum):
    daily_fixed = "daily_fixed"
    round_up = "round_up"
    weekly_fixed = "weekly_fixed"
    monthly_fixed = "monthly_fixed"


class SavingsGoal(Base):
    __tablename__ = "savings_goals"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    target_amount: Mapped[float] = mapped_column(Float, nullable=False)
    current_amount: Mapped[float] = mapped_column(Float, default=0.0)
    deadline: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    emoji: Mapped[Optional[str]] = mapped_column(String(10), nullable=True, default="💰")
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )

    rules = relationship("AutoSaveRule", back_populates="goal", lazy="select")
    deposits = relationship("SavingsDeposit", back_populates="goal", lazy="select")


class AutoSaveRule(Base):
    __tablename__ = "auto_save_rules"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    goal_id: Mapped[int] = mapped_column(Integer, ForeignKey("savings_goals.id"), nullable=False)
    rule_type: Mapped[AutoRuleType] = mapped_column(
        SAEnum(AutoRuleType, name="auto_rule_type"), nullable=False
    )
    amount: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    goal = relationship("SavingsGoal", back_populates="rules")


class SavingsDeposit(Base):
    __tablename__ = "savings_deposits"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=False, index=True
    )
    goal_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("savings_goals.id"), nullable=False, index=True
    )
    amount: Mapped[float] = mapped_column(Float, nullable=False)
    note: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    deposited_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )

    goal = relationship("SavingsGoal", back_populates="deposits")
