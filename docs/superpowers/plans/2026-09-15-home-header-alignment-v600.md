# Home Header Alignment 6.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 发布 `6.0.0+19`，让首页 Logo 与“小满记账”严格同线，并把自定义话语编辑行稳定放在标题下方。

**Architecture:** 保留现有 `HomeHeader`、`HomeSubtitleDialog` 和仓库边界，仅重排头部内部约束；使用稳定 key 做真实渲染几何测试。版本继续由 `pubspec.yaml` 与 `AppConstants.appVersion` 双源同步。

**Tech Stack:** Flutter 3、Dart、flutter_test、Android API 36、ADB。

---

### Task 1: 版本与布局红灯

**Files:**
- Modify: `frontend/test/core/version_test.dart`
- Modify: `frontend/test/modules/home/home_header_test.dart`

- [ ] 更新期望为 `6.0.0` 与 `6.0.0+19`，运行版本测试并确认因旧值失败。
- [ ] 添加 `home-brand-mark`、`home-brand-title`、`home-subtitle-row` 几何断言，运行测试并确认因 key 或对齐缺失失败。

### Task 2: 最小实现

**Files:**
- Modify: `frontend/lib/modules/home/home_header.dart`
- Modify: `frontend/lib/core/constants.dart`
- Modify: `frontend/pubspec.yaml`

- [ ] 第一行建立固定 38dp 品牌轴，Logo 和标题中心偏差不超过 1dp。
- [ ] 第二行从标题左边缘开始显示话语与 48dp “更改”入口。
- [ ] 更新两个版本源，运行头部与版本测试直至通过。

### Task 3: 发布与实机

**Files:**
- Create: `releases/android/小满记账-v6.0.0+19.apk`
- Create: `releases/android/小满记账-v6.0.0+19.apk.sha256`

- [ ] 运行格式检查、定向分析、完整测试与 `git diff --check`。
- [ ] 构建 release APK，验证 `versionName=6.0.0`、`versionCode=19`、`targetSdk=36` 与 APK 签名。
- [ ] 生成 SHA-256，保留所有历史 APK，覆盖安装到设备 `4d6cc461`。
- [ ] 冷启动并验证首页几何、编辑交互与应用版本，不清除数据。
