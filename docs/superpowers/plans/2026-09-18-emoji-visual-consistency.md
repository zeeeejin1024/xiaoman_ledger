# 小满记账 Emoji 视觉统一实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用统一圆角图标替换报告、引导页和预设状态中的装饰性 Emoji，同时保留承担分类识别与用户自定义功能的 Emoji。

**Architecture:** 不增加依赖，直接使用 Flutter Material Rounded 图标。通过源码约束测试限定禁止 Emoji 的页面范围，避免误伤分类和存钱目标数据。

**Tech Stack:** Flutter、Dart、flutter_test、Material Icons、Android Release APK

---

### Task 1: 建立装饰性 Emoji 边界测试

**Files:**
- Create: `frontend/test/modules/theme/decorative_emoji_policy_test.dart`

- [ ] 写测试，读取引导页、周报、月报和个人页源码，断言不包含 `💰 📊 🎯 🐣 🌟 😊 😅 😰 🎉` 等装饰符号。
- [ ] 运行 `flutter test test/modules/theme/decorative_emoji_policy_test.dart`，确认因当前源码仍含 Emoji 而失败。

### Task 2: 替换引导页大型 Emoji

**Files:**
- Modify: `frontend/lib/modules/onboarding/onboarding_page.dart`

- [ ] 将 `_OnboardData.emoji` 改为 `icon` 与 `iconColor`。
- [ ] 使用 `Icons.receipt_long_rounded`、`Icons.insights_rounded`、`Icons.savings_rounded`。
- [ ] 在 104×104 圆角容器中显示 48px 图标，并使用主题色浅背景。

### Task 3: 替换报告和预设状态 Emoji

**Files:**
- Modify: `frontend/lib/modules/report/weekly_report_page.dart`
- Modify: `frontend/lib/modules/report/monthly_report_page.dart`
- Modify: `frontend/lib/modules/profile/profile_page.dart`

- [ ] 周报鼓励语改为无 Emoji 的完整中文句子。
- [ ] 月报 `_gradeEmoji` 改为 `_gradeIcon`，根据结余返回不同 Material Rounded 图标。
- [ ] 个人页预设状态仅保留中文文本；不迁移、不覆盖用户已保存的自定义状态。

### Task 4: 版本、验证与实机安装

**Files:**
- Modify: `frontend/pubspec.yaml`
- Modify: `frontend/lib/core/constants.dart`
- Modify: `frontend/test/core/version_test.dart`

- [ ] 版本更新为 `7.0.7+34`。
- [ ] 运行装饰 Emoji 测试、分类选择测试、报告测试和版本测试，确认全部通过。
- [ ] 运行相关文件静态分析，确认无错误。
- [ ] 构建 Release APK 到 `releases/android/小满记账-v7.0.7+34.apk`。
- [ ] 覆盖安装到 Android 16 实机并核对 `versionName=7.0.7`、`versionCode=34`。
