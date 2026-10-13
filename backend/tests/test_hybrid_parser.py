from app.services.hybrid_parser import parse_hybrid, should_call_model


def test_spoken_money_and_correction():
    assert parse_hybrid("午饭二十二块五").items[0].amount == 22.5
    assert parse_hybrid("不是二十，是十二块").items[0].amount == 12


def test_multi_record_and_cost_route():
    result = parse_hybrid("早餐八块，地铁三块")
    assert [i.amount for i in result.items] == [8, 3]
    assert should_call_model(result.items)


def test_clear_single_record_bypasses_model():
    result = parse_hybrid("午餐 22 元")
    assert not should_call_model(result.items)
