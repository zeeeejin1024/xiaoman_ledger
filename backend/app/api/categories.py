from typing import Dict, List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.category import Category
from app.schemas.common import success, error

router = APIRouter(prefix="/categories", tags=["分类"])


def _build_tree(categories: List[Category]) -> List[dict]:
    """将扁平分类列表转为树形结构。"""
    by_id: Dict[int, dict] = {}
    roots: List[dict] = []

    for c in categories:
        node = {
            "id": c.id,
            "name": c.name,
            "type": c.type.value if hasattr(c.type, 'value') else c.type,
            "emoji": c.emoji,
            "is_system": c.is_system if hasattr(c, 'is_system') else True,
            "children": [],
        }
        by_id[c.id] = node

    for c in categories:
        node = by_id[c.id]
        if c.parent_id and c.parent_id in by_id:
            by_id[c.parent_id]["children"].append(node)
        else:
            roots.append(node)

    return roots


@router.get("")
def get_categories(db: Session = Depends(get_db)):
    categories = db.query(Category).order_by(Category.sort_order).all()
    tree = _build_tree(categories)
    return success(data=tree)


@router.post("")
def create_category(data: dict, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """创建自定义分类"""
    name = data.get('name', '').strip()
    cat_type = data.get('type', 'expense')
    emoji = data.get('emoji', '📌')
    parent_id = data.get('parent_id', None)

    if not name:
        return {"code": 1, "message": "分类名称不能为空"}

    cat = Category(
        name=name, type=cat_type, emoji=emoji,
        parent_id=parent_id, is_system=False, sort_order=999
    )
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return success(data={"id": cat.id, "name": cat.name, "emoji": cat.emoji})


@router.delete("/{category_id}")
def delete_category(category_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """删除自定义分类（系统预设分类不可删除）"""
    cat = db.query(Category).filter(Category.id == category_id).first()
    if not cat:
        return error(404, "分类不存在")
    if cat.is_system:
        return error(403, "系统预设分类不可删除")
    # 同时删除子分类
    db.query(Category).filter(Category.parent_id == category_id).delete()
    db.delete(cat)
    db.commit()
    return success(message="已删除")
