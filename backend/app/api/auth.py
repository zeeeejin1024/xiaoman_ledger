import re
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import hash_password, verify_password, create_access_token, create_temp_token, decode_token
from app.core.deps import get_current_user
from app.models.user import User
from app.schemas.user import RegisterRequest, LoginRequest, AuthResponse, UserInfo
from app.schemas.common import success, error

router = APIRouter(prefix="/auth", tags=["认证"])


# ============================================================
# 注册（兼容用户名 + 新增手机号注册）
# ============================================================
@router.post("/register")
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    # 手机号注册
    if hasattr(data, 'phone') and data.phone:
        if not re.match(r"^1[3-9]\d{9}$", data.phone):
            return error(400, "手机号格式不正确")
        if db.query(User).filter(User.phone == data.phone).first():
            return error(409, "该手机号已注册")
        if len(data.password) < 6:
            return error(400, "密码至少6位")
        security_q = getattr(data, 'security_question', '')
        security_a = getattr(data, 'security_answer', '')
        if not security_q or not security_a:
            return error(400, "请设置密保问题和答案")
        user = User(
            username=data.phone,  # 用手机号填充 username（该字段不可为空）
            phone=data.phone,
            password_hash=hash_password(data.password),
            security_question=security_q,
            security_answer_hash=hash_password(security_a),
            migrated=True,
        )
    else:
        # 用户名注册（兼容旧版）
        existing = db.query(User).filter(User.username == data.username).first()
        if existing:
            return error(409, "用户名已存在")
        user = User(
            username=data.username,
            password_hash=hash_password(data.password),
        )
    db.add(user)
    db.commit()
    db.refresh(user)
    token = create_access_token(user.id)
    return success(data=AuthResponse(username=user.username or user.phone or '', token=token).model_dump())


# ============================================================
# 登录（兼容用户名 + 手机号）
# ============================================================
@router.post("/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):
    # 判断是手机号还是用户名
    if re.match(r"^1[3-9]\d{9}$", data.username):
        user = db.query(User).filter(User.phone == data.username).first()
    else:
        user = db.query(User).filter(User.username == data.username).first()

    if not user or not verify_password(data.password, user.password_hash):
        return error(401, "手机号或密码错误")

    token = create_access_token(user.id)
    return success(data={
        "token": token,
        "username": user.username or user.phone or '',
        "phone": user.phone,
        "need_migrate": not user.migrated,
    })


# ============================================================
# 获取当前用户信息
# ============================================================
@router.get("/me")
def get_me(user: User = Depends(get_current_user)):
    return success(data={
        "username": user.username or user.phone or '',
        "phone": user.phone,
        "migrated": user.migrated,
    })


# ============================================================
# 老用户迁移：绑定手机号 + 密保
# ============================================================
@router.post("/migrate")
def migrate(data: dict, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if user.migrated:
        return error(400, "账号已完成迁移")

    phone = data.get('phone', '')
    password = data.get('password', '')
    security_q = data.get('security_question', '')
    security_a = data.get('security_answer', '')

    if not re.match(r"^1[3-9]\d{9}$", phone):
        return error(400, "手机号格式不正确")
    if db.query(User).filter(User.phone == phone, User.id != user.id).first():
        return error(400, "该手机号已被其他账号绑定")
    if len(password) < 6:
        return error(400, "密码至少6位")
    if not security_q or not security_a:
        return error(400, "请设置密保问题和答案")

    user.phone = phone
    user.password_hash = hash_password(password)
    user.security_question = security_q
    user.security_answer_hash = hash_password(security_a)
    user.migrated = True
    db.commit()
    return success(data={"ok": True})


# ============================================================
# 忘记密码：验证手机号 + 密保答案
# ============================================================
@router.post("/forgot-password")
def forgot_password(data: dict, db: Session = Depends(get_db)):
    phone = data.get('phone', '')
    answer = data.get('security_answer', '')

    user = db.query(User).filter(User.phone == phone).first()
    if not user:
        return error(404, "该手机号未注册")
    if not user.security_answer_hash or not verify_password(answer, user.security_answer_hash):
        return error(400, "密保答案错误")

    temp_token = create_temp_token(str(user.id))
    return success(data={"temp_token": temp_token})


# ============================================================
# 重置密码：用临时 token 更新密码
# ============================================================
@router.post("/reset-password")
def reset_password(data: dict, db: Session = Depends(get_db)):
    temp_token = data.get('temp_token', '')
    new_password = data.get('new_password', '')

    try:
        payload = decode_token(temp_token)
        if payload.get("type") != "temp":
            return error(401, "令牌类型错误")
        user_id = int(payload.get("sub", 0))
    except Exception:
        return error(401, "临时令牌无效或已过期")

    if len(new_password) < 6:
        return error(400, "新密码至少6位")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return error(404, "用户不存在")

    user.password_hash = hash_password(new_password)
    db.commit()
    return success(data={"ok": True})


# ============================================================
# 修改密码（需旧密码验证）
# ============================================================
@router.put("/user/update-password")
def update_password(data: dict, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    old_pw = data.get('old_password', '')
    new_pw = data.get('new_password', '')

    if not verify_password(old_pw, user.password_hash):
        return error(400, "原密码错误")
    if len(new_pw) < 6:
        return error(400, "新密码至少6位")

    user.password_hash = hash_password(new_pw)
    db.commit()
    return success(data={"ok": True})


# ============================================================
# 修改手机号（需密码验证）
# ============================================================
@router.put("/user/update-phone")
def update_phone(data: dict, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    password = data.get('password', '')
    new_phone = data.get('phone', '')

    if not verify_password(password, user.password_hash):
        return error(400, "密码错误")
    if not re.match(r"^1[3-9]\d{9}$", new_phone):
        return error(400, "手机号格式不正确")
    if db.query(User).filter(User.phone == new_phone, User.id != user.id).first():
        return error(400, "该手机号已被占用")

    user.phone = new_phone
    db.commit()
    return success(data={"ok": True})


# ============================================================
# 修改密保（需密码验证）
# ============================================================
@router.put("/user/update-security")
def update_security(data: dict, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    password = data.get('password', '')
    question = data.get('security_question', '')
    answer = data.get('security_answer', '')

    if not verify_password(password, user.password_hash):
        return error(400, "密码错误")
    if not question or not answer:
        return error(400, "请填写密保问题和答案")

    user.security_question = question
    user.security_answer_hash = hash_password(answer)
    db.commit()
    return success(data={"ok": True})
