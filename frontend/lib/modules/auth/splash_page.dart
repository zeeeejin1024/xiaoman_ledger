import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/core/router.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/notifications.dart';
import 'package:xiaojia_ledger/core/notification_coordinator.dart';
import 'package:xiaojia_ledger/widgets/unfinished_ring_mark.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2200), () async {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.tokenKey);
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        await _requestNotificationPermission();
        final lastAuth = p.getString('last_auth_check');
        final now = DateTime.now();
        bool needConfirm = true;
        if (lastAuth != null) {
          final last = DateTime.tryParse(lastAuth);
          if (last != null && now.difference(last).inDays < 7)
            needConfirm = false;
        }
        if (needConfirm) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('确认登录'),
              content: Text('为了你的账号安全，请确认继续使用当前账号。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('退出登录'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    '确认',
                    style: TextStyle(color: AppColors.highlight),
                  ),
                ),
              ],
            ),
          );
          if (ok == true && mounted) {
            await p.setString('last_auth_check', now.toIso8601String());
            if (mounted)
              Navigator.pushReplacementNamed(context, AppRouter.home);
          } else if (mounted) {
            await storage.delete(key: AppConstants.tokenKey);
            await storage.delete(key: AppConstants.usernameKey);
            if (mounted)
              Navigator.pushReplacementNamed(context, AppRouter.login);
          }
        } else {
          if (mounted) Navigator.pushReplacementNamed(context, AppRouter.home);
        }
      } else {
        if (mounted) Navigator.pushReplacementNamed(context, AppRouter.login);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final p = await SharedPreferences.getInstance();
      final hasRequested =
          p.getBool('notification_permission_requested') ?? false;
      if (!hasRequested) {
        await NotificationService.requestPermission();
        await p.setBool('notification_permission_requested', true);
      }
      final coordinator = await NotificationCoordinator.shared();
      await coordinator.reconcileAll();
    } catch (_) {}
  }

  static const _title = '小满记账';
  static const _subtitle = '记录每一笔，攒出小确幸';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final progress = Curves.easeOutCubic.transform(_ctrl.value);
          final markProgress = (progress / 0.48).clamp(0.0, 1.0);
          final titleProgress = ((progress - 0.22) / 0.4).clamp(0.0, 1.0);
          final subtitleProgress = ((progress - 0.5) / 0.3).clamp(0.0, 1.0);
          return Container(
            color: AppColors.bg,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: markProgress,
                        child: Transform.scale(
                          scale: 0.86 + markProgress * 0.14,
                          child: Container(
                            width: 132,
                            height: 132,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withAlpha(35),
                                  blurRadius: 30,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: const UnfinishedRingMark(
                              size: 76,
                              animate: true,
                              ringColor: Color(0xFFF5F4EE),
                              markerColor: Color(0xFFD56F54),
                              trackColor: Color(0x335F8C7D),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Opacity(
                        opacity: Curves.easeOut.transform(titleProgress),
                        child: Transform.translate(
                          offset: Offset(0, 12 * (1 - titleProgress)),
                          child: Text(
                            _title,
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Opacity(
                        opacity: Curves.easeOut.transform(subtitleProgress),
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - subtitleProgress)),
                          child: Text(
                            _subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.gray,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
