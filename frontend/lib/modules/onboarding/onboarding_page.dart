import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/notifications.dart';

class OnboardingPage extends StatefulWidget {
  final ValueChanged<BuildContext> onComplete;
  final Future<bool> Function()? requestNotificationPermission;
  const OnboardingPage({
    super.key,
    required this.onComplete,
    this.requestNotificationPermission,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardData(
      icon: Icons.receipt_long_rounded,
      iconColor: Color(0xFFB7791F),
      title: '轻松记账',
      subtitle: '手动、语音、拍照\n三种方式随心选择',
      bg: Color(0xFFFFF8E1),
    ),
    _OnboardData(
      icon: Icons.insights_rounded,
      iconColor: Color(0xFF4F7A65),
      title: '智能统计',
      subtitle: '收支一目了然\n月报周报自动生成',
      bg: Color(0xFFE8F5E9),
    ),
    _OnboardData(
      icon: Icons.savings_rounded,
      iconColor: Color(0xFF4E6F8E),
      title: '预算管理',
      subtitle: '设定存钱目标\n养成理财好习惯',
      bg: Color(0xFFE3F2FD),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pages[_page].bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => _finish(),
                child: Text(
                  '跳过',
                  style: TextStyle(color: AppColors.gray, fontSize: 14),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: p.iconColor.withAlpha(24),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: p.iconColor.withAlpha(34)),
                        ),
                        alignment: Alignment.center,
                        child: Icon(p.icon, size: 48, color: p.iconColor),
                      ),
                      SizedBox(height: 32),
                      Text(
                        p.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        p.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.gray,
                          height: 1.6,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // 指示点
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _page == i
                          ? AppColors.accent
                          : AppColors.gray.withAlpha(80),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            // 按钮
            Padding(
              padding: EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _page == _pages.length - 1
                      ? _offerNotificationPermission
                      : () => _controller.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                  child: Text(
                    _page == _pages.length - 1 ? '开始使用' : '下一步',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _offerNotificationPermission() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notification_permission_primer_seen', true);
    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('让提醒按时出现'),
        content: const Text('小满只会在你设定的时间提醒记账、查看周报或关注生活费，不发送广告。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不开启'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('开启通知'),
          ),
        ],
      ),
    );
    if (enable == true) {
      await (widget.requestNotificationPermission ??
          NotificationService.requestPermission)();
      await p.setBool('notification_permission_requested', true);
    }
    await _finish();
  }

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarding_done', true);
    if (mounted) widget.onComplete(context);
  }
}

class _OnboardData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color bg;
  const _OnboardData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.bg,
  });
}
