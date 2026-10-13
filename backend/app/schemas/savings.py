from typing import Optional
from pydantic import BaseModel, Field
from app.models.savings_goal import AutoRuleType


class GoalCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    target_amount: float = Field(gt=0)
    deadline: Optional[str] = None
    emoji: Optional[str] = "💰"


class GoalUpdate(BaseModel):
    name: Optional[str] = None
    target_amount: Optional[float] = None
    deadline: Optional[str] = None
    emoji: Optional[str] = None
    is_completed: Optional[bool] = None


class DepositRequest(BaseModel):
    goal_id: int
    amount: float = Field(gt=0)
    note: Optional[str] = Field(default=None, max_length=200)


class RuleCreate(BaseModel):
    goal_id: int
    rule_type: AutoRuleType
    amount: Optional[float] = None
