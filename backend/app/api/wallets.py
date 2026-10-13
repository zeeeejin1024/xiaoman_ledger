from typing import List
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.wallet_budget import WalletBudget
from app.models.record import Record
from app.models.category import Category
from app.models.wallet_category_binding import WalletCategoryBinding
from app.services.wallet_service import calculate_wallet_spend, bind_wallet_category
from datetime import datetime

router = APIRouter(prefix="/wallets", tags=["钱包"])


class WalletUpdate(BaseModel):
    wallets: List[dict]


class WalletCategoryBindingRequest(BaseModel):
    category_id: int
    include_descendants: bool = False


class WalletCreate(BaseModel):
    name: str
    amount: float
    wallet_type: str = "custom"
    color: str = "#7BAF8A"
    bindings: List[WalletCategoryBindingRequest]


class WalletSingleUpdate(BaseModel):
    name: str = None
    amount: float = None
    color: str = None
    wallet_type: str = None


@router.get("", response_model=dict)
def get_wallets(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """获取所有钱包分区及当月余额"""
    wallets = db.query(WalletBudget).filter(WalletBudget.user_id == user.id).order_by(WalletBudget.sort_order).all()
    if not wallets:
        # 首次自动创建默认四个钱包
        defaults = [
            {"wallet_type": "food", "name": "吃饭钱包", "amount": 1500, "color": "#7BAF8A", "sort_order": 0},
            {"wallet_type": "fun", "name": "快乐钱包", "amount": 800, "color": "#7BAED4", "sort_order": 1},
            {"wallet_type": "gaming", "name": "游戏钱包", "amount": 300, "color": "#E8806A", "sort_order": 2},
            {"wallet_type": "saving", "name": "攒钱钱包", "amount": 400, "color": "#F5C542", "sort_order": 3},
        ]
        for d in defaults:
            w = WalletBudget(user_id=user.id, **d)
            db.add(w)
        db.commit()
        wallets = db.query(WalletBudget).filter(WalletBudget.user_id == user.id).order_by(WalletBudget.sort_order).all()

    # 兼容旧版按 wallet_type 保存的钱包：仅对没有绑定规则的钱包建立一次根分类规则。
    legacy_roots = {"food": 1, "fun": 26, "gaming": 26}
    for wallet in wallets:
        has_binding = db.query(WalletCategoryBinding.id).filter(
            WalletCategoryBinding.wallet_id == wallet.id,
        ).first()
        root_id = legacy_roots.get(wallet.wallet_type)
        if has_binding is None and root_id is not None:
            db.add(WalletCategoryBinding(
                wallet_id=wallet.id,
                category_id=root_id,
                include_descendants=True,
            ))
    db.commit()

    # 计算本月已花。新钱包按分类绑定聚合；未迁移的旧钱包暂时保持零值。
    now = datetime.now()
    month_prefix = f"{now.year}-{now.month:02d}"
    spent_by_wallet = calculate_wallet_spend(db, user.id, month_prefix)

    result = []
    for w in wallets:
        used = spent_by_wallet.get(w.id, 0.0)
        bindings = db.query(WalletCategoryBinding).filter(WalletCategoryBinding.wallet_id == w.id).all()
        result.append({
            "id": w.id, "wallet_type": w.wallet_type, "name": w.name,
            "amount": w.amount, "color": w.color,
            "spent": used, "remaining": w.amount - used,
            "pct": min(used / w.amount, 1.0) if w.amount > 0 else 0,
            "exhausted": used >= w.amount,
            "bindings": [
                {"category_id": b.category_id, "include_descendants": b.include_descendants}
                for b in bindings
            ],
        })

    return {"code": 0, "data": result}


@router.put("/{wallet_id}/categories", response_model=dict)
def update_wallet_categories(
    wallet_id: int,
    req: List[WalletCategoryBindingRequest],
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    wallet = db.query(WalletBudget).filter(WalletBudget.id == wallet_id, WalletBudget.user_id == user.id).first()
    if not wallet:
        return {"code": 1, "message": "钱包不存在"}
    db.query(WalletCategoryBinding).filter(WalletCategoryBinding.wallet_id == wallet_id).delete()
    for item in req:
        db.add(WalletCategoryBinding(
            wallet_id=wallet_id,
            category_id=item.category_id,
            include_descendants=item.include_descendants,
        ))
    db.commit()
    return {"code": 0, "message": "分类规则已更新"}


@router.put("", response_model=dict)
def update_wallets(req: WalletUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """批量更新钱包分区"""
    for item in req.wallets:
        wid = item.get("id")
        if wid:
            w = db.query(WalletBudget).filter(WalletBudget.id == wid, WalletBudget.user_id == user.id).first()
            if w:
                w.amount = item.get("amount", w.amount)
                w.name = item.get("name", w.name)
                w.color = item.get("color", w.color)
    db.commit()
    return {"code": 0, "message": "已更新"}


@router.post("", response_model=dict)
def create_wallet(req: WalletCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """创建自定义钱包"""
    if not req.name.strip():
        return {"code": 1, "message": "钱包名称不能为空"}
    if not req.bindings:
        return {"code": 1, "message": "请至少选择一个分类"}
    category_ids = {binding.category_id for binding in req.bindings}
    existing_category_ids = {
        row[0] for row in db.query(Category.id).filter(Category.id.in_(category_ids)).all()
    }
    if existing_category_ids != category_ids:
        return {"code": 1, "message": "包含不存在的分类"}
    max_order = db.query(WalletBudget).filter(WalletBudget.user_id == user.id).count()
    w = WalletBudget(user_id=user.id, name=req.name.strip(), amount=req.amount, wallet_type=req.wallet_type, color=req.color, sort_order=max_order)
    db.add(w)
    db.flush()
    for binding in req.bindings:
        db.add(WalletCategoryBinding(
            wallet_id=w.id,
            category_id=binding.category_id,
            include_descendants=binding.include_descendants,
        ))
    db.commit()
    db.refresh(w)
    return {"code": 0, "data": {
        "id": w.id, "name": w.name, "amount": w.amount,
        "wallet_type": w.wallet_type, "color": w.color,
        "bindings": [binding.model_dump() for binding in req.bindings],
    }}


@router.put("/{wallet_id}", response_model=dict)
def update_single_wallet(wallet_id: int, req: WalletSingleUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """编辑单个钱包"""
    w = db.query(WalletBudget).filter(WalletBudget.id == wallet_id, WalletBudget.user_id == user.id).first()
    if not w: return {"code": 1, "message": "钱包不存在"}
    if req.name is not None: w.name = req.name
    if req.amount is not None: w.amount = req.amount
    if req.color is not None: w.color = req.color
    if req.wallet_type is not None: w.wallet_type = req.wallet_type
    db.commit()
    return {"code": 0, "message": "已更新"}


@router.delete("/{wallet_id}", response_model=dict)
def delete_wallet(wallet_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """删除钱包"""
    w = db.query(WalletBudget).filter(WalletBudget.id == wallet_id, WalletBudget.user_id == user.id).first()
    if not w: return {"code": 1, "message": "钱包不存在"}
    db.query(WalletCategoryBinding).filter(WalletCategoryBinding.wallet_id == wallet_id).delete()
    db.delete(w); db.commit()
    return {"code": 0, "message": "已删除"}
