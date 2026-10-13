# 主题按钮扩散 Implementation Plan

> **For agentic workers:** 使用 executing-plans 在现有工作区逐项执行；用户已于 2026-10-13 批准设计并要求开始实现，无需再次选择执行模式。

**Goal:** 六套主题从对应色板圆心扩散，保持真实页面状态及系统栏最终一致。

**Architecture:** 根部 RepaintBoundary 捕获一次旧画面，CustomPainter 使用偶奇路径裁剪揭示圆内的真实新主题。AppColors 为唯一主题来源；过渡系统栏样式独立通知，只在状态栏或底部区域完全揭开时切换图标明暗。请求代次排除过期捕获，偏好写入串行化。

**Tech Stack:** Flutter、dart:ui、SharedPreferences、现有 Android MethodChannel，无新增依赖。

## Task 1: 几何与保护测试

文件：`frontend/lib/core/theme_reveal_geometry.dart`，`frontend/test/core/theme_reveal_geometry_test.dart`。

- [ ] 编写四角覆盖、半径零时完全遮挡、半径终点透明、系统栏分区覆盖测试。
- [ ] Run: `flutter test --no-pub test/core/theme_reveal_geometry_test.dart`，先确认缺失功能导致失败。
- [ ] 使用 `max((corner-origin).distance)+2` 计算终点；偶奇路径 `Path()..fillType=PathFillType.evenOdd..addRect(bounds)..addOval(circle)` 裁出旧画面。
- [ ] 原点与尺寸校验拒绝 NaN、越界及零尺寸；Run 相同命令确认通过。

## Task 2: 根扩散组件及并发

文件：`frontend/lib/core/theme_reveal.dart`，`frontend/test/core/theme_reveal_test.dart`。

- [ ] 编写控件测试：中途截图层存在、结束消失；不复制 StatefulWidget；重复主题与减少动画不截图。
- [ ] 编写失败、过期捕获、最后主题选择、偏好保存失败测试并确认失败。
- [ ] 实现 `ThemeReveal.change(context, scheme, globalOrigin)`、可注入的捕获/持久化依赖以及根 StatefulWidget。
- [ ] 截图安装后等待 endOfFrame，更新 AppColors，再等待 endOfFrame，执行 360ms `Cubic(.25,1,.5,1)`；只 CustomPainter 重绘。
- [ ] 请求代次不匹配释放图片并退出；连点、滚动、生命周期、窗口变更、导航切换调用 finish，不保留旧遮罩；保存链上一笔失败不阻止下一笔。
- [ ] Run: `flutter test --no-pub test/core/theme_reveal_test.dart`，确认通过。

## Task 3: 系统栏与主题入口

文件：`frontend/lib/main.dart`、`frontend/lib/core/theme.dart`、`frontend/lib/modules/profile/profile_page.dart`、`frontend/lib/modules/home/home_page.dart`、`frontend/android/app/src/main/kotlin/com/xiaojia/xiaojia_ledger/MainActivity.kt`。

- [ ] 编写集成测试：主程序有 ThemeReveal 包装且 themeAnimationDuration 为 Duration.zero；色板与标签共享圆心；保存最终值；导航离开时清理。
- [ ] Root: `builder: (_, child) => ThemeReveal(child: AppSystemUi(scheme: scheme, child: child!))`；添加过渡导航观察器；禁用 MaterialApp 默认色彩插值。
- [ ] 每个色板使用 GlobalKey 取得 40dp 圆心，通过 ThemeReveal.change 提交；选中标记直接读取 AppColors.schemeIndex，不维护第二个主题索引。
- [ ] AppColors 增加临时系统样式通知器；AppSystemUi 监听其变更。桥接默认参数保持兼容，过渡时额外传 `navigationIsDark`，Kotlin 分别应用状态栏和导航图标明暗。
- [ ] Run: `flutter test --no-pub test/core/theme_reveal_test.dart test/core/system_ui_theme_test.dart test/modules/profile/profile_theme_reveal_test.dart`。

## Task 4: 验证与交付

- [ ] `dart format` 本轮文件；`flutter analyze --no-pub` 检查本轮无新错误。
- [ ] `flutter test --no-pub` 全量通过；新增 tests 比较像素证明圆内新主题、圆外旧主题。
- [ ] `git diff --check` 本轮修改；检查版本未变；不清理无关用户文件、不提交历史未完成实现。
- [ ] 检查 ADB 设备。未进入发布阶段不构建 APK、不覆盖手机安装；真机 profile 和录屏列入后续验证，不假称已达 60/120fps。
- [ ] 报告已验证范围、遗留风险，先问有无新需求。

## 工作记录

基线：2026-10-13 全量 133 项 Flutter 测试通过。Flutter 自身更新检查因本机代理失败，测试仍正常完成，不改代理或升级 SDK。

### 2026-10-13 开发结果

- [x] Task 1 完成：四角、初末遮罩、系统栏分区及无效原点测试通过。
- [x] Task 2 完成：截图安装时序、超时、失败、过期捕获、资源释放、状态保留和非逐帧重建验证通过。
- [x] Task 3 完成：主程序、色板圆心、全局选中、导航清理与系统栏桥接接入；保存失败提示测试通过。
- [x] 独立只读审查：保存取消竞态与返回手势开始清理，分别新增失败回归后修复。
- [x] 最终只读复核：上述两项 Important 问题均已关闭，未发现其他确定的遗留代码问题。
- [x] 最终全量验证：`flutter test --no-pub`，161 项全部通过，比基线增加 28 项。
- [x] 本轮 9 个相关 Dart 文件静态分析：`No issues found`；已检查本轮代码格式及 diff 空白。
- [x] 离线 pub get 刷新指向旧缓存的生成插件配置；pubspec.lock 哈希不变，无依赖升级。
- [x] ADB 检查无连接设备；保留现有工作区，不更新版本、不构建 APK。
- [x] 保留版本 `7.0.10+37`；APK 输出目录仅原有 2026-09-22 的安装包，本轮未生成安装包。
- [ ] 原生 Kotlin 编译检查成功：离线缓存缺 Flutter debug 引擎及部分 AndroidX 构件，目前只完成 Dart 编译，不能宣称原生构建通过。
- [ ] 真机 profile 帧时间、录屏与系统栏明暗切换验收。
- [ ] 用户确认进入发布阶段后同步 versionName/versionCode、打包和手机安装验证。

早期任务列表作为实施步骤保留；各 Task 执行状态以此工作记录及验证记录为准。
