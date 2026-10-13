# 小满记账 xiaojia_ledger

一款功能完整的智能记账 App，支持截图识别、语音记账、多钱包管理、周报/月报等特色功能。

## 功能特性

- 📸 截图识别记账（DeepSeek AI 语义解析）
- 🎤 语音记账
- 💳 多钱包管理（预算追踪、超支提醒）
- 📊 统计分析（周报/月报/年度趋势）
- 🌙 深色模式（6 套配色方案）
- 🔔 记账提醒通知
- 💾 数据云同步

## 技术栈

- **前端**: Flutter 3.x + Dart
- **后端**: Python FastAPI
- **数据库**: SQLite + SQLAlchemy
- **AI**: DeepSeek API（语义解析）

## 快速开始

### 1. 克隆项目
```bash
git clone https://github.com/your-username/xiaojia_ledger.git
cd xiaojia_ledger
```

### 2. 配置环境变量
```bash
cp .env.example .env
# 编辑 .env 填入你的 API Key
```

### 3. 启动后端
```bash
cd backend
pip install -r requirements.txt
python -m uvicorn app.main:app --reload
```

### 4. 启动前端
```bash
cd frontend
flutter pub get
flutter run
```

## 环境变量配置

在项目根目录创建 `.env` 文件：

```env
# JWT 密钥（生产环境必须更改）
SECRET_KEY=your_secret_key_here

# 通义千问 API（截图识别）
QWEN_API_KEY=your_key_here

# 讯飞 OCR（文字识别）
XUNFEI_APPID=bf1acb41
XUNFEI_API_KEY=your_key_here
XUNFEI_API_SECRET=your_secret_here

# 服务器地址
BASE_URL=http://your-server-ip/api/v1
```

## 项目结构

```
xiaojia_ledger/
├── frontend/          # Flutter 前端
│   ├── lib/
│   │   ├── core/      # 核心服务（主题、通知、API）
│   │   ├── modules/   # 页面模块
│   │   └── data/      # 数据层（API、模型）
│   └── android/       # Android 配置
├── backend/           # Python 后端
│   ├── app/
│   │   ├── api/       # API 路由
│   │   ├── models/    # 数据库模型
│   │   └── services/  # 业务逻辑
│   └── requirements.txt
├── .env.example       # 环境变量模板
└── README.md
```

## API 端点

| 端点 | 方法 | 描述 |
|------|------|------|
| `/api/v1/auth/register` | POST | 手机号注册 |
| `/api/v1/auth/login` | POST | 手机号登录 |
| `/api/v1/categories` | GET | 获取分类 |
| `/api/v1/records` | GET/POST | 记录管理 |
| `/api/v1/ai/ocr` | POST | 截图识别 |
| `/api/v1/stats/monthly` | GET | 月度统计 |
| `/api/v1/stats/weekly` | GET | 周度统计 |

## 许可证

MIT License

## 联系方式

- 邮箱：support@xiaoman.app
- GitHub Issues
