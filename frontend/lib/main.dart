import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/router.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/theme_reveal.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/core/notification_models.dart';
import 'package:xiaojia_ledger/core/notifications.dart';
import 'package:xiaojia_ledger/data/api/api_client.dart';
import 'package:xiaojia_ledger/modules/report/weekly_report_page.dart';
import 'package:xiaojia_ledger/modules/report/monthly_report_page.dart';
import 'package:xiaojia_ledger/modules/wallet/wallet_page.dart';
import 'package:xiaojia_ledger/modules/profile/profile_page.dart';

NotificationPayload? _pendingNotificationPayload;

void _handleNotificationPayload(NotificationPayload payload) {
  final context = ApiClient.navigatorKey.currentContext;
  if (context == null) {
    _pendingNotificationPayload = payload;
    return;
  }
  if (payload.type == 'daily') {
    final prefs = SharedPreferences.getInstance();
    prefs.then((value) async {
      await value.setBool('auto_open_add', true);
      if (ApiClient.navigatorKey.currentContext != null) {
        Navigator.of(
          ApiClient.navigatorKey.currentContext!,
        ).pushNamedAndRemoveUntil('/home', (_) => false);
      }
    });
    return;
  }
  final page = switch (payload.route) {
    'weekly_report' => const WeeklyReportPage(),
    'monthly_report' => const MonthlyReportPage(),
    'wallet' => const WalletPage(),
    'profile' => const ProfilePage(),
    _ => null,
  };
  if (page != null) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final schemeIdx = prefs.getInt('color_scheme') ?? 0;
  AppColors.apply(
    AppColorScheme.all[schemeIdx.clamp(0, AppColorScheme.all.length - 1)],
  );
  // 先注册语义回调，再初始化插件，确保冷启动通知不会丢失。
  NotificationService.onNotificationPayload = _handleNotificationPayload;
  await NotificationService.init();

  runApp(const XiaojiaApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final payload = _pendingNotificationPayload;
    _pendingNotificationPayload = null;
    if (payload != null) _handleNotificationPayload(payload);
  });
}

class XiaojiaApp extends StatelessWidget {
  const XiaojiaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppColors.notifier,
        AppColors.systemUiOverride,
      ]),
      builder: (context, child) {
        final scheme = AppColors.scheme;
        return MaterialApp(
          title: AppConstants.appName,
          navigatorKey: ApiClient.navigatorKey,
          theme: appTheme(),
          themeAnimationDuration: Duration.zero,
          navigatorObservers: [themeRevealNavigationObserver],
          debugShowCheckedModeBanner: false,
          initialRoute: AppRouter.splash,
          onGenerateRoute: AppRouter.generateRoute,
          builder: (context, child) => ThemeReveal(
            child: AppSystemUi(
              scheme: scheme,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

class AppSystemUi extends StatefulWidget {
  final Widget child;
  final AppColorScheme scheme;

  const AppSystemUi({
    super.key,
    required this.child,
    this.scheme = AppColorScheme.warmAmber,
  });

  @override
  State<AppSystemUi> createState() => _AppSystemUiState();
}

class _AppSystemUiState extends State<AppSystemUi> {
  @override
  void initState() {
    super.initState();
    AppColors.systemUiOverride.addListener(_onOverride);
    _syncAfterFrame();
  }

  void _onOverride() {
    if (!mounted) return;
    setState(() {});
    _syncAfterFrame();
  }

  @override
  void dispose() {
    AppColors.systemUiOverride.removeListener(_onOverride);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppSystemUi oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheme != widget.scheme) _syncAfterFrame();
  }

  void _syncAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemChrome.setSystemUIOverlayStyle(AppColors.systemUiOverlayStyle);
      _applyNativeStyle();
    });
  }

  Future<void> _applyNativeStyle() async {
    try {
      await AppSystemUiBridge.apply(
        widget.scheme,
        overlay: AppColors.systemUiOverride.value,
      );
    } on MissingPluginException {
      // Flutter-only hosts and unsupported native targets retain the standard
      // SystemChrome path. Android has the bridge.
    } on PlatformException {
      // A native bridge error must not interrupt theme switching.
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('app-system-ui-region'),
      value: AppColors.systemUiOverlayStyle,
      child: ColoredBox(
        key: const ValueKey('app-system-ui-background'),
        color: AppColors.bg,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.topLeft,
          children: [
            widget.child,
            if (viewPadding.bottom > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: viewPadding.bottom,
                child: IgnorePointer(
                  child: ColoredBox(
                    key: const ValueKey('app-system-navigation-background'),
                    color: AppColors.navBg,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
