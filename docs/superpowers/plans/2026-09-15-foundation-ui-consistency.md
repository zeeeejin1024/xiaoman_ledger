# 小满记账 5.9.0 基础界面一致性实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 发布 `5.9.0+14`，让所有主要页面同步主题，底栏缩减为五项，首页改为可控的副标题编辑，并扩大个人资料入口的触摸范围。

**Architecture:** 保留现有 `ValueNotifier<AppColorScheme>` 作为唯一主题信号，使用 `AppThemeBuilder` 包裹每个读取静态 `AppColors` 的页面视觉根节点，刷新视觉但保留 StatefulWidget 状态。首页文案拆为独立组件和偏好仓库，导航目的地提取为可测试常量；钱包页面仍通过首页卡片和旧通知路由访问。

**Tech Stack:** Flutter 3、Dart、Material 3、SharedPreferences、flutter_test、Android API 36。

---

## 文件结构

- Create: `frontend/lib/modules/home/home_header.dart` — 固定品牌标题、副标题显示及编辑入口。
- Create: `frontend/lib/modules/home/home_subtitle_repository.dart` — `home_subtitle` 的读取、规范化和保存。
- Create: `frontend/test/modules/home/home_header_test.dart` — 首页头部交互和字数限制测试。
- Create: `frontend/test/modules/home/home_navigation_test.dart` — 五入口底栏和钱包入口保留测试。
- Create: `frontend/test/modules/profile/profile_hit_target_test.dart` — 个人资料入口命中范围测试。
- Create: `frontend/test/modules/theme/page_theme_refresh_test.dart` — 页面主题边界刷新且不重建状态测试。
- Modify: `frontend/lib/modules/home/home_page.dart` — 使用新头部，删除底栏钱包，修正索引。
- Modify: `frontend/lib/core/theme.dart` — 增加复用的 `AppThemedPage` 视觉边界。
- Modify: `frontend/lib/modules/stats/stats_page.dart` — 添加主题边界。
- Modify: `frontend/lib/modules/savings/savings_page.dart` — 添加主题边界。
- Modify: `frontend/lib/modules/record/records_list_page.dart` — 添加主题边界。
- Modify: `frontend/lib/modules/profile/profile_page.dart` — 添加主题边界并扩大命中区域。
- Modify: `frontend/lib/modules/wallet/wallet_page.dart` — 添加主题边界。
- Modify: `frontend/lib/modules/report/weekly_report_page.dart` — 添加主题边界。
- Modify: `frontend/lib/modules/report/monthly_report_page.dart` — 添加主题边界。
- Modify: `frontend/lib/modules/settings/settings_page.dart` — 添加主题边界。
- Modify: `frontend/lib/modules/voice/voice_page.dart` — 添加主题边界。
- Modify: `frontend/pubspec.yaml` — 版本更新为 `5.9.0+14`。
- Modify: `frontend/lib/core/constants.dart` — 展示版本更新为 `5.9.0`。
- Modify: `frontend/test/core/version_test.dart` — 更新版本断言。

### Task 1: 版本基线

**Files:**

- Modify: `frontend/pubspec.yaml:4`
- Modify: `frontend/lib/core/constants.dart:3`
- Modify: `frontend/test/core/version_test.dart`

- [ ] **Step 1: 先更新测试期望并验证失败**

```dart
expect(AppConstants.appVersion, '5.9.0');
expect(pubspec, contains('version: 5.9.0+14'));
```

Run: `flutter test test/core/version_test.dart`

Expected: FAIL，实际版本仍为 `5.8.7` 和 `5.8.7+13`。

- [ ] **Step 2: 更新两个版本来源**

```yaml
version: 5.9.0+14
```

```dart
static const String appVersion = '5.9.0';
```

- [ ] **Step 3: 验证版本测试通过**

Run: `flutter test test/core/version_test.dart`

Expected: PASS。

- [ ] **Step 4: 提交版本基线**

```powershell
git add frontend/pubspec.yaml frontend/lib/core/constants.dart frontend/test/core/version_test.dart
git commit -m "chore: bump Android app to 5.9.0"
```

### Task 2: 五入口底部导航

**Files:**

- Create: `frontend/test/modules/home/home_navigation_test.dart`
- Modify: `frontend/lib/modules/home/home_page.dart:37`

- [ ] **Step 1: 写导航失败测试**

```dart
testWidgets('home navigation exposes five destinations without wallet', (
  tester,
) async {
  await tester.pumpWidget(const MaterialApp(home: HomePage()));
  await tester.pump();

  final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
  expect(navigation.destinations, hasLength(5));
  expect(find.text('首页'), findsOneWidget);
  expect(find.text('统计'), findsOneWidget);
  expect(find.text('存钱'), findsOneWidget);
  expect(find.text('流水'), findsOneWidget);
  expect(find.text('我的'), findsOneWidget);
  expect(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text('钱包'),
  ), findsNothing);
});

testWidgets('home content keeps the wallet entry', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: HomePage()));
  await tester.pump();
  expect(find.text('我的钱包'), findsOneWidget);
});
```

测试安装 SharedPreferences mock，并允许首页异步加载保持 pending，不调用 `pumpAndSettle`。

- [ ] **Step 2: 运行测试并确认失败原因**

Run: `flutter test test/modules/home/home_navigation_test.dart`

Expected: 第一个测试 FAIL，当前有 6 个目的地且包含“钱包”。

- [ ] **Step 3: 删除底栏钱包构建器和目的地**

将 `LazyTabHost.builders` 改为：

```dart
builders: [
  (_) => const _DashTab(),
  (_) => const StatsPage(),
  (_) => const SavingsPage(),
  (_) => const RecordsListPage(),
  (_) => const ProfilePage(),
],
```

将 `NavigationBar.destinations` 改为首页、统计、存钱、流水、我的五项。保留 `_walletEntry()` 中 `Navigator.push(...WalletPage())`。

- [ ] **Step 4: 验证导航测试通过**

Run: `flutter test test/modules/home/home_navigation_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交导航改动**

```powershell
git add frontend/lib/modules/home/home_page.dart frontend/test/modules/home/home_navigation_test.dart
git commit -m "feat: keep wallet off the bottom navigation"
```

### Task 3: 首页固定标题与可编辑副标题

**Files:**

- Create: `frontend/lib/modules/home/home_subtitle_repository.dart`
- Create: `frontend/lib/modules/home/home_header.dart`
- Create: `frontend/test/modules/home/home_header_test.dart`
- Modify: `frontend/lib/modules/home/home_page.dart:122`

- [ ] **Step 1: 写副标题仓库和头部失败测试**

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('subtitle normalizes blank and limits text to 16 characters', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = HomeSubtitleRepository(prefs);

    await repository.save('   ');
    expect(repository.load(), HomeSubtitleRepository.defaultValue);

    await repository.save('一二三四五六七八九十一二三四五六七八九');
    expect(repository.load(), '一二三四五六七八九十一二三四五六');
  });

  testWidgets('only the change action edits the subtitle', (tester) async {
    String? edited;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeHeader(
          subtitle: HomeSubtitleRepository.defaultValue,
          onEditSubtitle: () => edited = 'opened',
          onOpenSettings: () {},
        ),
      ),
    ));

    expect(find.text('小满记账'), findsOneWidget);
    await tester.tap(find.text(HomeSubtitleRepository.defaultValue));
    expect(edited, isNull);
    await tester.tap(find.text('更改'));
    expect(edited, 'opened');
  });
}
```

- [ ] **Step 2: 运行测试并确认缺少实现**

Run: `flutter test test/modules/home/home_header_test.dart`

Expected: FAIL，`HomeSubtitleRepository` 和 `HomeHeader` 尚不存在。

- [ ] **Step 3: 实现偏好仓库**

```dart
class HomeSubtitleRepository {
  static const key = 'home_subtitle';
  static const defaultValue = '今天也留一点余地';
  static const maxLength = 16;

  final SharedPreferences preferences;
  HomeSubtitleRepository(this.preferences);

  String load() => normalize(preferences.getString(key));

  Future<void> save(String value) =>
      preferences.setString(key, normalize(value));

  static String normalize(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return defaultValue;
    final characters = trimmed.characters;
    return characters.length <= maxLength
        ? trimmed
        : characters.take(maxLength).toString();
  }
}
```

导入 `package:characters/characters.dart`，使用 Unicode 字符数量而不是 UTF-16 长度。

- [ ] **Step 4: 实现独立头部**

`HomeHeader` 固定渲染“小满记账”，副标题为普通 `Text`，其后使用 `TextButton` 渲染“更改”。“更改”按钮最小尺寸为 48×48；设置图标保持 24，命中范围为 48×48。品牌环继续使用 `UnfinishedRingMark`，颜色改用当前主题 token，避免固定墨绿/橙色。

```dart
TextButton(
  key: const ValueKey('home-subtitle-edit'),
  onPressed: onEditSubtitle,
  style: TextButton.styleFrom(
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: 6),
  ),
  child: const Text('更改'),
)
```

- [ ] **Step 5: 接入首页并实现编辑弹层**

`_DashTabState` 将 `_appTitle` 替换为 `_subtitle`；初始化时通过 `HomeSubtitleRepository.load()` 读取。编辑弹层使用 `TextField(maxLength: 16)`，保存后更新仓库和 `_subtitle`。删除 `_editTitle` 和 `app_title` 的读取/写入路径，不删除旧偏好数据。

```dart
Future<void> _saveSubtitle(String value) async {
  final prefs = await SharedPreferences.getInstance();
  final repository = HomeSubtitleRepository(prefs);
  await repository.save(value);
  if (mounted) setState(() => _subtitle = repository.load());
}
```

- [ ] **Step 6: 验证头部和首页测试通过**

Run: `flutter test test/modules/home/home_header_test.dart test/modules/home/home_navigation_test.dart`

Expected: PASS。

- [ ] **Step 7: 提交首页文案改动**

```powershell
git add frontend/lib/modules/home/home_header.dart frontend/lib/modules/home/home_subtitle_repository.dart frontend/lib/modules/home/home_page.dart frontend/test/modules/home/home_header_test.dart
git commit -m "feat: make the home subtitle explicitly editable"
```

### Task 4: 可复用页面主题边界

**Files:**

- Modify: `frontend/lib/core/theme.dart:375`
- Create: `frontend/test/modules/theme/page_theme_refresh_test.dart`

- [ ] **Step 1: 写状态保持与视觉刷新失败测试**

```dart
class StatefulThemeProbe extends StatefulWidget {
  const StatefulThemeProbe({super.key});
  @override
  State<StatefulThemeProbe> createState() => _StatefulThemeProbeState();
}

class _StatefulThemeProbeState extends State<StatefulThemeProbe> {
  int count = 0;
  @override
  Widget build(BuildContext context) => AppThemedPage(
    builder: (context, scheme) => ColoredBox(
      key: const ValueKey('page-color'),
      color: AppColors.bg,
      child: TextButton(
        onPressed: () => setState(() => count++),
        child: Text('${scheme.name}:$count'),
      ),
    ),
  );
}

testWidgets('page theme refresh preserves state', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: StatefulThemeProbe()));
  await tester.tap(find.byType(TextButton));
  await tester.pump();
  expect(find.text('未满之圆:1'), findsOneWidget);

  AppColors.apply(AppColorScheme.deepNight);
  await tester.pump();

  expect(find.text('极夜:1'), findsOneWidget);
  expect(
    tester.widget<ColoredBox>(find.byKey(const ValueKey('page-color'))).color,
    AppColorScheme.deepNight.bg,
  );
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/modules/theme/page_theme_refresh_test.dart`

Expected: FAIL，`AppThemedPage` 尚不存在。

- [ ] **Step 3: 实现页面主题边界**

```dart
class AppThemedPage extends StatelessWidget {
  final Widget Function(BuildContext context, AppColorScheme scheme) builder;
  const AppThemedPage({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => AppThemeBuilder(builder: builder);
}
```

该组件不增加 key，不替换子页面 State，只在当前位置因通知重新执行视觉 builder。

- [ ] **Step 4: 验证边界测试通过**

Run: `flutter test test/modules/theme/page_theme_refresh_test.dart`

Expected: PASS，计数保持为 1，颜色变为极夜背景。

- [ ] **Step 5: 提交主题边界**

```powershell
git add frontend/lib/core/theme.dart frontend/test/modules/theme/page_theme_refresh_test.dart
git commit -m "feat: add a state-preserving page theme boundary"
```

### Task 5: 覆盖所有主要页面

**Files:**

- Modify: `frontend/lib/modules/stats/stats_page.dart:46`
- Modify: `frontend/lib/modules/savings/savings_page.dart:239`
- Modify: `frontend/lib/modules/record/records_list_page.dart:64`
- Modify: `frontend/lib/modules/profile/profile_page.dart:258`
- Modify: `frontend/lib/modules/wallet/wallet_page.dart:309`
- Modify: `frontend/lib/modules/report/weekly_report_page.dart:39`
- Modify: `frontend/lib/modules/report/monthly_report_page.dart:37`
- Modify: `frontend/lib/modules/settings/settings_page.dart:172`
- Modify: `frontend/lib/modules/voice/voice_page.dart:116`
- Modify: `frontend/test/modules/theme/page_theme_refresh_test.dart`

- [ ] **Step 1: 增加主要页面主题清单失败测试**

测试读取主要页面源文件，并断言每个 Stateful 页面 build 根节点包含 `AppThemedPage`。这项结构测试用于防止后续新改动又把静态 `AppColors` 放回无订阅页面。

```dart
for (final path in pagePaths) {
  final source = File(path).readAsStringSync();
  expect(source, contains('AppThemedPage('), reason: path);
}
```

Run: `flutter test test/modules/theme/page_theme_refresh_test.dart`

Expected: FAIL，至少统计、存钱、流水、我的页面缺少主题边界。

- [ ] **Step 2: 包裹底栏缓存页面**

每个页面的 `build` 改为：

```dart
@override
Widget build(BuildContext context) => AppThemedPage(
  builder: (context, scheme) => Scaffold(
    backgroundColor: AppColors.bg,
    // 保留原有 Scaffold 内容
  ),
);
```

不得在 builder 内调用 `_load()`，不得修改 `initState` 或页面 key。

- [ ] **Step 3: 包裹路由页面**

钱包、周报、月报、设置和语音页面使用同一模式。弹层继续从页面 builder 中创建，因此下一次打开时读取当前主题；已打开的长驻弹层在后续子项目统一抽成主题弹层边界。

- [ ] **Step 4: 格式化并运行主题测试**

Run: `dart format lib/core/theme.dart lib/modules/stats/stats_page.dart lib/modules/savings/savings_page.dart lib/modules/record/records_list_page.dart lib/modules/profile/profile_page.dart lib/modules/wallet/wallet_page.dart lib/modules/report/weekly_report_page.dart lib/modules/report/monthly_report_page.dart lib/modules/settings/settings_page.dart lib/modules/voice/voice_page.dart test/modules/theme/page_theme_refresh_test.dart`

Run: `flutter test test/core/theme_test.dart test/core/system_ui_theme_test.dart test/modules/theme/page_theme_refresh_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交主要页面主题同步**

```powershell
git add frontend/lib/modules/stats/stats_page.dart frontend/lib/modules/savings/savings_page.dart frontend/lib/modules/record/records_list_page.dart frontend/lib/modules/profile/profile_page.dart frontend/lib/modules/wallet/wallet_page.dart frontend/lib/modules/report/weekly_report_page.dart frontend/lib/modules/report/monthly_report_page.dart frontend/lib/modules/settings/settings_page.dart frontend/lib/modules/voice/voice_page.dart frontend/test/modules/theme/page_theme_refresh_test.dart
git commit -m "fix: refresh every primary page on theme changes"
```

### Task 6: 个人资料触摸范围

**Files:**

- Modify: `frontend/lib/modules/profile/profile_page.dart:267`
- Create: `frontend/test/modules/profile/profile_hit_target_test.dart`

- [ ] **Step 1: 写命中范围失败测试**

为头部入口和完成按钮添加稳定 key 后，测试实际渲染尺寸：

```dart
expect(
  tester.getSize(find.byKey(const ValueKey('profile-edit-hit-target'))).height,
  greaterThanOrEqualTo(48),
);
expect(
  tester.getSize(find.byKey(const ValueKey('profile-save-hit-target'))).height,
  greaterThanOrEqualTo(48),
);
expect(
  tester.widget<Icon>(find.byIcon(Icons.chevron_right)).size,
  22,
);
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/modules/profile/profile_hit_target_test.dart`

Expected: FAIL，稳定 key 和明确的最小命中约束不存在。

- [ ] **Step 3: 扩大透明命中区域**

头部入口：

```dart
GestureDetector(
  key: const ValueKey('profile-edit-hit-target'),
  behavior: HitTestBehavior.opaque,
  onTap: _openPersonalInfo,
  child: ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 96),
    child: Row(/* 原有内容 */),
  ),
)
```

完成按钮：

```dart
TextButton(
  key: const ValueKey('profile-save-hit-target'),
  onPressed: _save,
  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
  child: Text('完成', style: TextStyle(color: AppColors.sage, fontSize: 16)),
)
```

头像图标和右侧箭头尺寸保持不变。

- [ ] **Step 4: 验证命中测试通过**

Run: `flutter test test/modules/profile/profile_hit_target_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交触摸范围改动**

```powershell
git add frontend/lib/modules/profile/profile_page.dart frontend/test/modules/profile/profile_hit_target_test.dart
git commit -m "fix: enlarge profile editing hit targets"
```

### Task 7: 全量验证与 Android 发布包

**Files:**

- Create: `releases/android/小满记账-v5.9.0+14.apk`
- Create: `releases/android/小满记账-v5.9.0+14.apk.sha256`

- [ ] **Step 1: 检查格式、静态分析和差异**

Run: `dart format --output=none --set-exit-if-changed lib test`

Run: `flutter analyze`

Run: `git diff --check`

Expected: 三条命令退出码均为 0。

- [ ] **Step 2: 运行完整 Flutter 测试**

Run: `flutter test`

Expected: 全部测试通过，0 failures。

- [ ] **Step 3: 构建发布 APK**

使用 ASCII 路径缓存和 Android Studio JBR：

```powershell
$env:JAVA_HOME='D:\Android studio\jbr'
$env:PUB_CACHE='D:\flutter_pub_cache'
$env:Path="D:\Android studio\jbr\bin;D:\Android\Sdk\platform-tools;$env:Path"
flutter build apk --release
```

Expected: `Built build\app\outputs\flutter-apk\app-release.apk`。

- [ ] **Step 4: 复制并校验发布物**

复制为 `releases/android/小满记账-v5.9.0+14.apk`，生成同名 `.sha256`。使用 `aapt dump badging` 验证 `versionName=5.9.0`、`versionCode=14`、`targetSdkVersion=36`。

- [ ] **Step 5: 覆盖安装并实机验收**

```powershell
adb -s 4d6cc461 install -r D:\ascii-release\xiaojia-v5.9.0-14.apk
```

不得卸载旧应用。依次验证未满之圆到极夜、极夜到未满之圆；查看首页、统计、存钱、流水、我的、钱包六个页面，确认状态栏、页面、底栏和手势区同步。验证底栏无钱包、首页钱包入口仍可用、副标题编辑限制和个人资料整行点击。

- [ ] **Step 6: 记录验证证据并提交发布变更**

截图存放在 `docs/device-v590-*.png`。仅在完整测试、构建和实机验证通过后提交本阶段源码及发布物。

```powershell
git add frontend/pubspec.yaml frontend/lib/core/constants.dart frontend/lib/core/theme.dart frontend/lib/modules/home/home_header.dart frontend/lib/modules/home/home_subtitle_repository.dart frontend/lib/modules/home/home_page.dart frontend/lib/modules/stats/stats_page.dart frontend/lib/modules/savings/savings_page.dart frontend/lib/modules/record/records_list_page.dart frontend/lib/modules/profile/profile_page.dart frontend/lib/modules/wallet/wallet_page.dart frontend/lib/modules/report/weekly_report_page.dart frontend/lib/modules/report/monthly_report_page.dart frontend/lib/modules/settings/settings_page.dart frontend/lib/modules/voice/voice_page.dart frontend/test/core/version_test.dart frontend/test/modules/home/home_header_test.dart frontend/test/modules/home/home_navigation_test.dart frontend/test/modules/profile/profile_hit_target_test.dart frontend/test/modules/theme/page_theme_refresh_test.dart releases/android/小满记账-v5.9.0+14.apk releases/android/小满记账-v5.9.0+14.apk.sha256 docs/device-v590-*.png
git commit -m "release: ship Android 5.9.0"
```
