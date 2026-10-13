from datetime import datetime, timezone

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.core.database import Base
from app.models.savings_goal import SavingsDeposit, SavingsGoal
from app.models.user import User
from app.schemas.savings import DepositRequest
from app.services.savings_service import deposit, get_deposit_history


def _session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    db = Session(engine)
    db.add(User(id=1, username="saver", password_hash="x"))
    db.add(
        SavingsGoal(
            id=1,
            user_id=1,
            name="旅行",
            target_amount=5000,
            current_amount=300,
        )
    )
    db.commit()
    return db


def test_deposit_creates_timestamped_history_record():
    db = _session()

    goal = deposit(
        db,
        1,
        DepositRequest(goal_id=1, amount=88.5, note="周末结余"),
    )

    record = db.query(SavingsDeposit).one()
    assert goal.current_amount == 388.5
    assert record.goal_id == 1
    assert record.user_id == 1
    assert record.amount == 88.5
    assert record.note == "周末结余"
    assert record.deposited_at is not None


def test_history_is_scoped_to_user_and_sorted_newest_first():
    db = _session()
    db.add_all(
        [
            SavingsDeposit(
                user_id=1,
                goal_id=1,
                amount=10,
                deposited_at=datetime(2026, 9, 19, 8, 0, tzinfo=timezone.utc),
            ),
            SavingsDeposit(
                user_id=1,
                goal_id=1,
                amount=20,
                deposited_at=datetime(2026, 9, 20, 9, 30, tzinfo=timezone.utc),
            ),
        ]
    )
    db.commit()

    history = get_deposit_history(db, goal_id=1, user_id=1)

    assert [item.amount for item in history] == [20, 10]
    assert get_deposit_history(db, goal_id=1, user_id=2) == []
