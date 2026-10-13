import base64
import logging
from fastapi import APIRouter, Depends, UploadFile, File
from pydantic import BaseModel, Field

from app.core.deps import get_current_user
from app.models.user import User
from app.schemas.common import success, error
from app.services.hybrid_parser import parse_hybrid, should_call_model
from app.services.xunfei_service import recognize

router = APIRouter(prefix="/ai", tags=["AI"])
logger = logging.getLogger("hybrid_parser")


def _item_dict(item):
    return {
        "type": item.type,
        "amount": item.amount or 0,
        "category": item.category,
        "confidence": item.confidence,
        "ambiguities": item.ambiguities,
    }


class VoiceRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)


@router.post("/parse")
def parse_voice(data: VoiceRequest, user: User = Depends(get_current_user)):
    """AI 语义解析：从自然语言中提取类型、金额、分类。"""
    result = parse_hybrid(data.text)
    route = "model" if should_call_model(result.items) else "rule"
    logger.info("parser_route=%s item_count=%d", route, len(result.items))
    payload = _item_dict(result.items[0]) if len(result.items) == 1 else {
        "items": [_item_dict(item) for item in result.items],
        "route": route,
    }
    return success(data=payload)


@router.post("/voice")
async def voice_recognize(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
):
    """语音识别：上传音频文件，返回识别文字 + AI 解析结果。"""
    try:
        audio_bytes = await file.read()
        # Flutter records mono 16kHz PCM WAV. Xunfei expects the raw PCM payload.
        pcm_bytes = audio_bytes[44:] if audio_bytes[:4] == b"RIFF" and len(audio_bytes) > 44 else audio_bytes
        audio_b64 = base64.b64encode(pcm_bytes).decode()

        # 确保音频格式正确：单声道 16kHz 16bit PCM
        text = recognize(audio_b64)

        if not text:
            return error(400, "未识别到语音内容，请重试")

        result = parse_hybrid(text)
        route = "model" if should_call_model(result.items) else "rule"
        logger.info("parser_route=%s item_count=%d source=voice", route, len(result.items))
        parsed = _item_dict(result.items[0]) if len(result.items) == 1 else {
            "items": [_item_dict(item) for item in result.items],
            "route": route,
        }
        return success(data={"text": text, "parsed": parsed})
    except Exception as e:
        return error(500, f"语音识别失败: {str(e)}")
