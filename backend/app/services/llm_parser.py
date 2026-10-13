from __future__ import annotations
import json, os, requests, logging, base64, io, re
from app.models.category import Category
from sqlalchemy.orm import Session

logger = logging.getLogger("llm_parser")
QWEN_API_KEY = os.environ.get("QWEN_API_KEY", "")

def _get_categories(db):
    cats = db.query(Category).filter(Category.parent_id.isnot(None)).all()
    return [c.name for c in cats if c.name]

def _compress(b64):
    try:
        raw = base64.b64decode(b64)
        if len(raw) <= 200 * 1024:
            return b64
        from PIL import Image
        im = Image.open(io.BytesIO(raw))
        if im.width > 1024:
            im = im.resize((1024, int(im.height * 1024 / im.width)), Image.LANCZOS)
        buf = io.BytesIO()
        im.convert("RGB").save(buf, "JPEG", quality=60)
        return base64.b64encode(buf.getvalue()).decode()
    except:
        return b64

def _match_category(vl_category, db_categories):
    """将 VL 返回的类别名匹配到数据库类别"""
    if not vl_category:
        return db_categories[0] if db_categories else ""
    vl_lower = vl_category.strip().lower()
    # 精确匹配
    for c in db_categories:
        if vl_lower == c.lower():
            return c
    # 包含匹配
    for c in db_categories:
        if vl_lower in c.lower() or c.lower() in vl_lower:
            return c
    # 关键词映射
    keyword_map = {
        "打车": ["打车"], "滴滴": ["打车"], "快车": ["打车"],
        "地铁": ["地铁公交"], "公交": ["地铁公交"],
        "单车": ["共享单车"], "骑行": ["共享单车"],
        "早餐": ["早餐"], "午餐": ["午餐"], "晚餐": ["晚餐"],
        "外卖": ["外卖"], "宵夜": ["宵夜"],
        "零食": ["零食"], "奶茶": ["奶茶咖啡"], "咖啡": ["奶茶咖啡"],
        "水果": ["水果"], "超市": ["超市便利"], "便利店": ["超市便利"],
        "网购": ["网购"], "衣服": ["服饰鞋包"], "鞋": ["服饰鞋包"],
        "电影": ["电影演出"], "游戏": ["游戏氪金"], "健身": ["运动健身"],
        "话费": ["手机话费"], "宽带": ["宽带网络"], "会员": ["APP会员"],
        "房租": ["房租月供"], "水电": ["水电燃气"], "物业": ["物业费"],
        "快递": ["快递物流"], "理发": ["理发造型"],
    }
    for keyword, targets in keyword_map.items():
        if keyword in vl_lower:
            for t in targets:
                for c in db_categories:
                    if t in c:
                        return c
    return ""

def parse_receipt(image_base64, db):
    if not QWEN_API_KEY:
        return []
    db_categories = _get_categories(db)
    cat_text = "\n".join([f"- {c}" for c in db_categories[:50]])
    img = _compress(image_base64)

    prompt = (
        "识别这张支付/账单截图中的所有消费记录。\n\n"
        "重要规则（严格遵守）：\n"
        "1. 金额：必须是截图中显示的真实数字，不要猜测或推测\n"
        "2. 日期：如果截图中有明确的日期（如5月25日、2026-05-25、周二），则识别出来；如果没有明确日期，必须返回空字符串\"\"\n"
        "3. 商家名称：如果截图中有明确的商家名/店铺名/收款方，则识别出来；如果没有，必须返回空字符串\"\"\n"
        "4. 备注：如果截图中有明确的备注信息，则识别出来；如果没有，必须返回空字符串\"\"\n"
        "5. 不要使用同一张截图上其他消费的信息来猜测当前消费的日期/商家/备注\n"
        "6. 每笔消费单独一条记录\n\n"
        "返回格式（纯 JSON，不要 markdown 代码块）：\n"
        '{"items":[{"type":"expense","amount":22.5,"category":"午餐","merchant":"瑞幸咖啡","date":"2026-05-31","note":""}]}\n\n'
        "type 只能是 expense 或 income。\n"
        "category 必须从以下列表中选择最匹配的：\n" + cat_text
    )

    try:
        resp = requests.post(
            "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
            headers={"Authorization": f"Bearer {QWEN_API_KEY}", "Content-Type": "application/json"},
            json={
                "model": "qwen-vl-plus",
                "messages": [{"role": "user", "content": [
                    {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + img}},
                    {"type": "text", "text": prompt},
                ]}],
                "temperature": 0.1,
                "max_tokens": 1500,
            },
            timeout=120,
        )
        data = resp.json()
        raw_content = data["choices"][0]["message"]["content"]
        logger.error("VL RESP: %s", raw_content[:600])
    except Exception as e:
        logger.error("VL HTTP: %s", e)
        return []

    # 提取 JSON
    content = raw_content.strip()
    m = re.search(r"```json\s*\n(.*?)\n\s*```", content, re.DOTALL)
    if m:
        content = m.group(1)

    try:
        parsed = json.loads(content)
    except json.JSONDecodeError:
        brace_count = 0
        start = content.find("{")
        if start == -1:
            return []
        end = start
        in_string = False
        for i in range(start, len(content)):
            if content[i] == '"' and (i == 0 or content[i - 1] != "\\"):
                in_string = not in_string
            elif not in_string:
                if content[i] == "{":
                    brace_count += 1
                elif content[i] == "}":
                    brace_count -= 1
            if brace_count == 0 and content[i] == "}":
                end = i + 1
                break
        try:
            parsed = json.loads(content[start:end])
        except:
            return []

    items = parsed.get("items", []) if isinstance(parsed, dict) else parsed if isinstance(parsed, list) else []
    if not isinstance(items, list):
        items = []

    # 修复 + 匹配类别
    for it in items:
        t = str(it.get("type", "")).strip().lower()
        if t not in ("expense", "income"):
            it["type"] = "expense"
        try:
            it["amount"] = float(it["amount"])
        except:
            it["amount"] = 0
        # 匹配数据库类别
        vl_cat = str(it.get("category", "")).strip()
        it["category"] = _match_category(vl_cat, db_categories)

    logger.error("VL OK: %d items", len(items))
    return items
