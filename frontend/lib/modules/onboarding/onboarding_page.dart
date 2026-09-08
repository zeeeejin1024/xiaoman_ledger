import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/theme.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingPage({super.key, required this.onComplete});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardData(
      emoji: '💰',
      title: '轻松记账',
      subtitle: '手动、语音、拍照\n三种方式随心选择',
      bg: Color(0xFFFFF8E1),
    ),
    _OnboardData(
      emoji: '📊',
      title: '智能统计',
      subtitle: '收支一目了然\n月报周报自动生成',
      bg: Color(0xFFE8F5E9),
    ),
    _OnboardData(
      emoji: '🎯',
      title: '预算管理',
      subtitle: '设定存钱目标\n养成理财好习惯',
      bg: Color(0xFFE3F2FD),
    ),
  ];

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pages[_page].bg,
      body: SafeArea(child: Column(children: [
        Align(alignment: Alignment.topRight, child: TextButton(
          onPressed: _finish,
          child: Text('跳过', style: TextStyle(color: AppColors.gray, fontSize: 14)),
        )),
        Expanded(child: PageView.builder(
          controller: _controller,
          itemCount: _pages.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) {
            final p = _pages[i];
            return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(p.emoji, style: TextStyle(fontSize: 80)),
              SizedBox(height: 32),
              Text(p.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink)),
              SizedBox(height: 12),
              Text(p.subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.gray, height: 1.6)),
            ]);
          },
        )),
        // 指示点
        Padding(padding: EdgeInsets.only(bottom: 12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_pages.length, (i) => AnimatedContainer(
          duration: Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: _page == i ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(color: _page == i ? AppColors.accent : AppColors.gray.withAlpha(80), borderRadius: BorderRadius.circular(4)),
        )))),
        // 按钮
        Padding(padding: EdgeInsets.fromLTRB(32, 0, 32, 40), child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _page == _pages.length - 1 ? _finish : () => _controller.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeInOut),
            child: Text(_page == _pages.length - 1 ? '开始使用' : '下一步', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        )),
      ])),
    );
  }

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarding_done', true);
    widget.onComplete();
  }
}

class _OnboardData {
  final String emoji;
  final String title;
  final String subtitle;
  final Color bg;
  const _OnboardData({required this.emoji, required this.title, required this.subtitle, required this.bg});
}
