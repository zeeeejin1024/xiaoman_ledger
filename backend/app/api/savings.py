from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.savings_goal import SavingsGoal
from app.schemas.savings import GoalCreate, GoalUpdate, DepositRequest, RuleCreate
from app.schemas.common import success, error
from app.services import savings_service as svc

router = APIRouter(prefix="/savings", tags=["存钱"])


def _goal_out(g: SavingsGoal) -> dict:
    return {
        "id": g.id,
        "name": g.name,
        "target_amount": g.target_amount,
        "current_amount": g.current_amount,
        "deadline": g.deadline,
        "emoji": g.emoji,
        "is_completed": g.is_completed,
        "progress": round(g.current_amount / g.target_amount, 4) if g.target_amount > 0 else 0,
        "rules": [
            {
                "id": r.id,
                "rule_type": r.rule_type.value if hasattr(r.rule_type, 'value') else r.rule_type,
                "amount": r.amount,
                "is_active": r.is_active,
            }
            for r in (g.rules or [])
        ],
    }


@router.get("/goals")
def list_goals(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    goals = db.query(SavingsGoal).filter(SavingsGoal.user_id == user.id).all()
    return success(data=[_goal_out(g) for g in goals])


@router.post("/goals")
def create_goal(data: GoalCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    goal = svc.create_goal(db, user.id, data)
    return success(data=_goal_out(goal))


@router.put("/goals/{goal_id}")
def update_goal(goal_id: int, data: GoalUpdate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    goal = svc.update_goal(db, goal_id, user.id, data)
    if not goal:
        return error(404, "目标不存在")
    return success(data=_goal_out(goal))


@router.delete("/goals/{goal_id}")
def delete_goal(goal_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    ok = svc.delete_goal(db, goal_id, user.id)
    if not ok:
        return error(404, "目标不存在")
    return success()


@router.post("/deposit")
def deposit(data: DepositRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    goal = svc.deposit(db, user.id, data)
    if not goal:
        return error(404, "目标不存在")
    return success(data=_goal_out(goal))


@router.get("/goals/{goal_id}/history")
def deposit_history(
    goal_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    goal = db.query(SavingsGoal).filter(
        SavingsGoal.id == goal_id, SavingsGoal.user_id == user.id
    ).first()
    if not goal:
        return error(404, "目标不存在")

    records = svc.get_deposit_history(db, goal_id, user.id)
    recorded_amount = sum(record.amount for record in records)
    items = [
        {
            "id": record.id,
            "amount": record.amount,
            "note": record.note,
            "deposited_at": record.deposited_at.isoformat() + (
                "Z" if record.deposited_at.tzinfo is None else ""
            ),
            "is_legacy": False,
        }
        for record in records
    ]
    legacy_amount = max(0.0, round(goal.current_amount - recorded_amount, 2))
    if legacy_amount > 0:
        items.append(
            {
                "id": None,
                "amount": legacy_amount,
                "note": "升级前累计",
                "deposited_at": None,
                "is_legacy": True,
            }
        )
    return success(data=items)


@router.post("/rules")
def create_rule(data: RuleCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    rule = svc.create_rule(db, user.id, data)
    return success(data={"id": rule.id})


@router.delete("/rules/{rule_id}")
def delete_rule(rule_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    svc.delete_rule(db, rule_id, user.id)
    return success()
