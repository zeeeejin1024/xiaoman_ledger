# 生活费闭环与智能报告 APK 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Android APK 中交付混合生活费、首次引导、首页进度与温和阈值提醒、月底结余转存，并增强周报/月报的确定性洞察。

**Architecture:** 生活费使用纯 Dart 周期与汇总模型，SharedPreferences 只负责本机配置和幂等标记，现有账单 API 提供真实收支，Savings API 接收月底结余。报告后端继续坚持“事实计算与表达分离”，本轮增加多周期可复用的分类贡献、预算节奏和稳健异常基础能力，不把原始流水交给模型。

**Tech Stack:** Flutter、SharedPreferences、flutter_local_notifications、Python、FastAPI、pytest、flutter_test。

---

## File Structure

- Create: `frontend/lib/core/living_allowance.dart` — 周期、汇总、阈值和月底转存决策。
- Create: `frontend/lib/core/living_allowance_repository.dart` — 配置、补充收入、无支出确认和幂等标记。
- Create: `frontend/lib/widgets/living_allowance_setup_dialog.dart` — 首次说明与配置 UI。
- Create: `frontend/lib/core/notification_device_settings.dart` — Android 厂商通知/后台设置桥接与教程映射。
- Create: `frontend/lib/modules/notifications/notification_help_page.dart` — 用户可见的权限和后台教程。
- Create: `frontend/test/modules/onboarding/onboarding_notification_permission_test.dart` — 先解释后授权。
- Create: `frontend/test/core/notification_device_settings_test.dart` — 厂商教程映射。
- Create: `frontend/test/core/living_allowance_test.dart` — 纯规则测试。
- Create: `frontend/test/core/living_allowance_repository_test.dart` — 本地持久化测试。
- Modify: `frontend/lib/modules/home/home_page.dart` — 首页卡片、数据完整度、开屏提醒和结余转存。
- Modify: `frontend/lib/modules/record/add_record_sheet.dart` — 收入是否补充生活费。
- Modify: `frontend/lib/core/notifications.dart` — 75%、90%、100% 生活费提醒。
- Modify: `frontend/lib/modules/onboarding/onboarding_page.dart` — 最后一页应用内解释后再申请系统通知权限。
- Modify: `frontend/lib/modules/auth/splash_page.dart` — 删除启动时直接申请权限。
- Modify: `frontend/lib/modules/notifications/notification_center_page.dart` — 正式帮助与诊断入口。
- Modify: `frontend/android/app/src/main/kotlin/com/xiaojia/xiaojia_ledger/MainActivity.kt` — 厂商与系统设置跳转。
- Modify: `backend/app/services/report_insight_engine.py` — 分类贡献、稳健异常、稳定周期。
- Modify: `backend/tests/test_report_insight_engine.py` — 新洞察回归测试。
- Modify: `frontend/pubspec.yaml`、`frontend/lib/core/constants.dart`、`frontend/test/core/version_test.dart` — `7.0.4+31`。

### Task 1: 通知首次授权与后台教程

- [ ] 写失败测试，验证最后一页先出现“让提醒按时出现”，只有点击“开启通知”才调用系统权限；“暂不开启”和顶部“跳过”不请求权限。
- [ ] 运行 onboarding 定向测试确认 RED。
- [ ] 删除 Splash 登录用户启动时的直接权限请求，只保留通知协调恢复。
- [ ] 实现可注入的 onboarding 权限回调并保存解释页、系统请求两个兼容标记。
- [ ] 写失败测试覆盖 Xiaomi、Huawei、Honor、OPPO、realme、vivo、iQOO、Samsung 和通用教程。
- [ ] 实现 `xiaojia/notification_settings` MethodChannel，所有厂商跳转失败时回退应用详情页。
- [ ] 通知中心增加“通知与后台设置”“通知诊断”正式入口，不再依赖连续点击版本号。
- [ ] 运行通知相关定向测试。

### Task 2: 生活费周期与汇总模型

- [ ] 写失败测试，覆盖发薪日前后周期、补充收入、剩余金额、使用速度、数据完整度、75/90/100 阈值和月底结余。
- [ ] 运行 `flutter test test/core/living_allowance_test.dart`，确认因文件或类型不存在而失败。
- [ ] 实现不可变的 `LivingAllowanceSettings`、`LivingAllowancePeriod`、`LivingAllowanceSummary` 和 `LivingAllowanceAlert`。
- [ ] 再次运行定向测试并确认通过。

### Task 3: 本地配置和首次引导

- [ ] 写失败测试，验证旧 `living_expense/pay_day` 可迁移、补充收入 ID 去重、无支出日期去重、周期转存和阈值提醒幂等。
- [ ] 运行 `flutter test test/core/living_allowance_repository_test.dart`，确认 RED。
- [ ] 实现 `LivingAllowanceRepository`。
- [ ] 新增首次说明和设置对话框：基础额度、到账日、月底自动转存；未确认不写设置。
- [ ] 运行仓库和 Widget 定向测试。

### Task 4: 接入记账和首页

- [ ] 写 Widget/源码守卫测试，验证收入页出现“计入本月生活费”，首页包含水平进度、剩余金额、完整度和“确认今日无支出”。
- [ ] 运行测试确认 RED。
- [ ] 收入保存成功后将返回账单 ID 写入补充收入集合。
- [ ] 首页按发薪日周期查询账单并计算生活费，不再用自然月总支出冒充生活费支出。
- [ ] 阈值首次跨越时显示应用内提示并调用生活费通知；同一周期同一阈值不重复。
- [ ] 当前日无账单时允许确认“今天无支出”，并立即提升完整度。
- [ ] 上一周期存在正结余且未处理时，自动创建或复用“生活费结余”存钱目标并存入；失败不写幂等标记。
- [ ] 运行首页、记账和生活费测试。

### Task 5: 增强报告事实引擎

- [ ] 写失败测试：分类变化贡献、MAD 大额异常、稳定周期不硬凑建议、建议引用事实 ID。
- [ ] 运行 `python -m pytest backend/tests/test_report_insight_engine.py -q` 确认 RED。
- [ ] 将类别聚合和基线聚合拆成小函数，增加候选事实与排序；不调用语言模型。
- [ ] 运行报告测试确认 GREEN。

### Task 6: 版本、验证与 APK

- [ ] 将版本更新为 `7.0.4+31`，版本测试先 RED 后 GREEN。
- [ ] 运行 `python -m pytest backend/tests -q`。
- [ ] 运行 `flutter test`。
- [ ] 运行 `flutter analyze`，区分新增问题和历史警告。
- [ ] 运行 `flutter build apk --release`。
- [ ] 将 APK 复制为 `releases/android/小满记账-v7.0.4+31.apk` 并生成 SHA-256。
- [ ] 若 ADB 有设备，安装并启动；否则报告需要连接手机进行实机验证。

## Acceptance Checklist

- 首次点击生活费卡会先解释功能，再进入设置。
- 首次 onboarding 不直接弹系统权限；先展示用途说明，拒绝也可继续使用。
- 设置页可查看品牌后台教程，并能打开通知设置、后台设置和诊断页。
- 生活费按到账日形成周期，补充收入只有用户勾选后才计入。
- 首页水平进度条同时显示剩余金额、日均可用、节奏和数据完整度。
- 75%、90%、100% 每周期最多提醒一次。
- 月底正结余进入“生活费结余”目标，不被计为普通消费或收入。
- 周报/月报不再只根据最大分类固定建议减少 10%。
- APK 版本为 `7.0.4+31`。
