from __future__ import annotations

from collections import defaultdict

from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.record import Record, RecordType
from app.models.wallet_budget import WalletBudget
from app.models.wallet_category_binding import WalletCategoryBinding


def bind_wallet_category(
    db: Session, wallet_id: int, category_id: int, include_descendants: bool,
) -> WalletCategoryBinding:
    binding = (
        db.query(WalletCategoryBinding)
        .filter_by(wallet_id=wallet_id, category_id=category_id)
        .first()
    )
    if binding is None:
        binding = WalletCategoryBinding(
            wallet_id=wallet_id,
            category_id=category_id,
            include_descendants=include_descendants,
        )
        db.add(binding)
    else:
        binding.include_descendants = include_descendants
    db.commit()
    db.refresh(binding)
    return binding


def _ancestor_ids(categories: list[Category]) -> dict[int, list[int]]:
    parents = {c.id: c.parent_id for c in categories}
    result: dict[int, list[int]] = {}
    for category in categories:
        chain = [category.id]
        parent = parents.get(category.id)
        seen = set(chain)
        while parent is not None and parent not in seen:
            chain.append(parent)
            seen.add(parent)
            parent = parents.get(parent)
        result[category.id] = chain
    return result


def calculate_wallet_spend(db: Session, user_id: int, month: str) -> dict[int, float]:
    wallets = (
        db.query(WalletBudget)
        .filter(WalletBudget.user_id == user_id)
        .order_by(WalletBudget.sort_order, WalletBudget.id)
        .all()
    )
    if not wallets:
        return {}
    bindings = (
        db.query(WalletCategoryBinding)
        .filter(WalletCategoryBinding.wallet_id.in_([w.id for w in wallets]))
        .all()
    )
    categories = db.query(Category).all()
    ancestors = _ancestor_ids(categories)
    bindings_by_wallet = defaultdict(list)
    for binding in bindings:
        bindings_by_wallet[binding.wallet_id].append(binding)

    spent = {w.id: 0.0 for w in wallets}
    records = (
        db.query(Record)
        .filter(
            Record.user_id == user_id,
            Record.date.startswith(month),
            Record.type == RecordType.expense,
        )
        .all()
    )
    wallet_order = {w.id: index for index, w in enumerate(wallets)}
    for record in records:
        candidates = []
        record_ancestors = ancestors.get(record.category_id, [record.category_id])
        for wallet in wallets:
            for binding in bindings_by_wallet[wallet.id]:
                if binding.category_id == record.category_id:
                    candidates.append((0, wallet_order[wallet.id], wallet.id))
                elif binding.include_descendants and binding.category_id in record_ancestors:
                    candidates.append((1, wallet_order[wallet.id], wallet.id))
        if candidates:
            _, _, wallet_id = min(candidates)
            spent[wallet_id] += float(record.amount)
    return spent
