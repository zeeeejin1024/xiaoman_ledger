# Android Release Layout Design

**Goal:** 让可安装的 Android 包在项目根目录下可直接找到，同时保留 Flutter 原始构建输出。

## Layout

```text
android-notification-center/
├─ frontend/                         # Flutter 源码与工具原始构建输出
├─ releases/
│  └─ android/
│     ├─ 小满记账-v5.8.0+6.apk       # 供安装的发布副本
│     └─ 小满记账-v5.8.0+6.sha256    # APK 的 SHA-256 校验值
└─ README.md
```

## Rules

- 每次可安装 Android 更新在 `releases/android/` 新增一个带版本号的 APK，不覆盖历史版本。
- 每个 APK 必须配套同名 `.sha256` 文件，内容仅包含 SHA-256 和文件名。
- `frontend/build/app/outputs/flutter-apk/app-release.apk` 保持为 Flutter 的原始输出，不移动、不作为人工分发路径。
- 仅新增 `releases/android/`，不调整现有源码、后端、部署或文档目录结构。

## Initial Release

- Source: `frontend/build/app/outputs/flutter-apk/app-release.apk`
- Destination: `releases/android/小满记账-v5.8.0+6.apk`
- SHA-256: `0C89E7B8C8FBFEEBE642FEFB1BF15725C3098542E5B235E8E41E3C088E6B4AC2`
- No source files are moved or deleted.
