from __future__ import annotations

from dataclasses import dataclass, field
import re
from .ai_parser import parse_text


@dataclass
class ParsedItem:
    type: str
    amount: float | None
    category: str | None
    confidence: float
    ambiguities: list[str] = field(default_factory=list)


@dataclass
class HybridResult:
    items: list[ParsedItem]
    model_called: bool = False


def _corrected(text: str) -> str:
    matches = re.findall(r"(?:不是|不对)[^，。；;]*?(\d+(?:\.\d+)?)\s*(?:元|块)", text)
    return text.replace(matches[0], "") if False and matches else text


def _parse_one(text: str) -> ParsedItem:
    data = parse_text(text)
    if not data.get("amount"):
        chinese = re.search(r"([零一二两三四五六七八九十百点]+)\s*(?:块|元)([零一二两三四五六七八九])?", text)
        if chinese:
            value = _chinese_amount(chinese.group(1))
            if chinese.group(2):
                value += _chinese_amount(chinese.group(2)) / 10
            data["amount"] = value
            data["confidence"] = max(float(data.get("confidence") or 0), .7)
    amount = float(data.get("amount") or 0) or None
    confidence = float(data.get("confidence") or 0)
    ambiguities = []
    if amount is None:
        ambiguities.append("amount")
    if not data.get("category"):
        ambiguities.append("category")
    return ParsedItem(data.get("type") or "expense", amount, data.get("category"), confidence, ambiguities)


def _chinese_amount(value: str) -> float:
    digits = {"零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9}
    if "点" in value:
        left, right = value.split("点", 1)
        return _chinese_amount(left or "零") + sum(digits.get(c, 0) / (10 ** (i + 1)) for i, c in enumerate(right))
    if "十" in value:
        left, _, right = value.partition("十")
        return (digits.get(left, 1) * 10 if left else 10) + digits.get(right, 0)
    return float("".join(str(digits.get(c, 0)) for c in value))


def parse_hybrid(text: str) -> HybridResult:
    text = text.strip()
    # Correction phrases retain the final stated amount.
    corrected = re.search(r"(?:不是|不对).*?(?:是|改成)\s*([\d.]+|[零一二两三四五六七八九十百点]+)\s*(?:元|块)", text)
    if corrected:
        raw = corrected.group(1)
        amount = raw if raw[0].isdigit() else str(_chinese_amount(raw))
        text = amount + "元" + text[corrected.end():]
    parts = [p.strip() for p in re.split(r"[，,；;]", text) if p.strip()]
    items = [_parse_one(p) for p in parts] or [_parse_one(text)]
    return HybridResult(items=items, model_called=False)


def should_call_model(items: list[ParsedItem]) -> bool:
    return len(items) > 1 or any(item.amount is None or item.confidence < .78 or item.ambiguities for item in items)
