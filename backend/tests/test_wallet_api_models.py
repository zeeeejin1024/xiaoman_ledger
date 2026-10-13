from app.api.wallets import WalletCreate


def test_wallet_create_accepts_multiple_category_bindings():
    request = WalletCreate.model_validate({
        "name": "一日三餐",
        "amount": 1200,
        "bindings": [
            {"category_id": 1, "include_descendants": True},
            {"category_id": 9, "include_descendants": False},
        ],
    })

    assert [binding.category_id for binding in request.bindings] == [1, 9]
    assert request.bindings[0].include_descendants is True
