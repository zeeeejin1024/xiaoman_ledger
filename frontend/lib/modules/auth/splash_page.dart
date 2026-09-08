import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/core/router.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/notifications.dart';
import 'package:xiaojia_ledger/core/notification_coordinator.dart';

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
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;

          // Logo: scale 0→1.05→1 + rotation (first 50%)
          final logoProgress = (t / 0.5).clamp(0.0, 1.0);
          final logoBounce = logoProgress < 0.8
              ? Curves.easeOutCubic.transform(logoProgress / 0.8) * 1.08
              : 1.08 -
                    (Curves.easeInOut.transform((logoProgress - 0.8) / 0.2) *
                        0.08);
          final logoScale = logoProgress <= 0 ? 0.0 : logoBounce;
          final logoRotate =
              (1 - Curves.easeOut.transform(logoProgress)) * 0.18;
          // Logo 光晕脉冲
          final glowPulse = logoProgress > 0.3
              ? (0.3 + 0.15 * (1 + (t * 6).abs() * 0))
              : 0.0;

          // Title stagger: 25%-65%
          final titleStart = 0.25;
          final titleEnd = 0.65;

          // Subtitle: 55%-85%
          final subProgress = ((t - 0.55) / 0.3).clamp(0.0, 1.0);

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.bg, AppColors.bgDeep],
              ),
            ),
            child: Stack(
              children: [
                // 径向光晕
                if (!AppColors.isDark)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center:
                              AppColors.scheme.bgGlowPos ?? Alignment.topCenter,
                          radius: 1.2,
                          colors: [
                            AppColors.bgGlowColor.withAlpha(
                              (18 * logoProgress).round(),
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.8,
                          colors: [
                            AppColors.bgGlowColor.withAlpha(
                              (12 * logoProgress).round(),
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                // 浮动光点装饰
                ...List.generate(5, (i) {
                  final delay = i * 0.15;
                  final dotProgress = ((t - delay) / 0.5).clamp(0.0, 1.0);
                  if (dotProgress <= 0) return const SizedBox.shrink();
                  final positions = [
                    Offset(0.2, 0.3),
                    Offset(0.8, 0.25),
                    Offset(0.15, 0.7),
                    Offset(0.85, 0.65),
                    Offset(0.5, 0.15),
                  ];
                  final sizes = [6.0, 4.0, 5.0, 3.0, 4.0];
                  final pos = positions[i];
                  final opacity = Curves.easeOut.transform(dotProgress) * 0.3;
                  return Positioned(
                    left: pos.dx * MediaQuery.of(context).size.width,
                    top: pos.dy * MediaQuery.of(context).size.height,
                    child: Container(
                      width: sizes[i],
                      height: sizes[i],
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.premiumLight.withAlpha(
                          (opacity * 255).round(),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.premiumLight.withAlpha(
                              (opacity * 120).round(),
                            ),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // 主体内容
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo 带光晕
                      Transform.rotate(
                        angle: logoRotate,
                        child: Transform.scale(
                          scale: logoScale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 光晕层
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.premiumLight.withAlpha(
                                        (60 *
                                                Curves.easeOut.transform(
                                                  logoProgress,
                                                ))
                                            .round(),
                                      ),
                                      AppColors.premium.withAlpha(
                                        (20 *
                                                Curves.easeOut.transform(
                                                  logoProgress,
                                                ))
                                            .round(),
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              // Logo 主体 — 毛玻璃
                              ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 12,
                                    sigmaY: 12,
                                  ),
                                  child: Container(
                                    width: 92,
                                    height: 92,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.premiumLight,
                                          AppColors.premium,
                                          AppColors.premiumDark,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: Colors.white.withAlpha(60),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.premium.withAlpha(
                                            80,
                                          ),
                                          blurRadius: 32,
                                          offset: const Offset(0, 12),
                                        ),
                                        BoxShadow(
                                          color: AppColors.premiumLight
                                              .withAlpha(40),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // 内高光
                                        Positioned(
                                          top: 0,
                                          left: 12,
                                          right: 12,
                                          child: Container(
                                            height: 1,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.white.withAlpha(100),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.savings_rounded,
                                          color: Colors.white,
                                          size: 42,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 32),
                      // Title — 渐变 shimmer
                      _StaggeredTitle(
                        title: _title,
                        controller: _ctrl,
                        start: titleStart,
                        end: titleEnd,
                      ),
                      SizedBox(height: 12),
                      // Subtitle — fade + float
                      Opacity(
                        opacity: Curves.easeOut.transform(subProgress),
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - subProgress)),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.premiumLight.withAlpha(10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.gray,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StaggeredTitle extends StatelessWidget {
  final String title;
  final AnimationController controller;
  final double start, end;

  const _StaggeredTitle({
    required this.title,
    required this.controller,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final chars = title.characters.toList();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(chars.length, (i) {
            final charStart = start + (i * 0.07);
            final charProgress =
                ((controller.value - charStart) / (end - start)).clamp(
                  0.0,
                  1.0,
                );
            final y = (1 - Curves.easeOutBack.transform(charProgress)) * 24;
            final opacity = Curves.easeOut.transform(charProgress);
            // 每个 char 微微缩放
            final scale = charProgress < 0.5
                ? 0.8 + Curves.easeOut.transform(charProgress * 2) * 0.2
                : 1.0;
            return Transform.translate(
              offset: Offset(0, y),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        AppColors.ink,
                        AppColors.premiumDark,
                        AppColors.ink,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: [0.0, controller.value.clamp(0.3, 0.7), 1.0],
                    ).createShader(bounds),
                    child: Text(
                      chars[i],
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
