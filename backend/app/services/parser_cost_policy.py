def route_for(items):
    return "model" if any(i.amount is None or i.confidence < .78 or i.ambiguities for i in items) or len(items) > 1 else "rule"
