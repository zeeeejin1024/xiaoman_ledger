import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/router.dart';
import 'package:xiaojia_ledger/core/theme.dart';
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
  if (page != null)
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final schemeIdx = prefs.getInt('color_scheme') ?? 0;
  AppColors.apply(
    AppColorScheme.all[schemeIdx.clamp(0, AppColorScheme.all.length - 1)],
  );
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: AppColors.isDark
          ? Brightness.light
          : Brightness.dark,
    ),
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
    return MaterialApp(
      title: AppConstants.appName,
      navigatorKey: ApiClient.navigatorKey,
      theme: appTheme(),
      debugShowCheckedModeBanner: false,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
