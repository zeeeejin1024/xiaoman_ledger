import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/widgets/unfinished_ring_mark.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _version = 'v${AppConstants.appVersion}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('关于与帮助', style: TextStyle(color: AppColors.ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          // App 图标
          Center(
            child: Container(
              width: 88,
              height: 88,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withAlpha(35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const UnfinishedRingMark(
                size: 52,
                animate: true,
                ringColor: Color(0xFFF5F4EE),
                markerColor: Color(0xFFD56F54),
                trackColor: Color(0x335F8C7D),
              ),
            ),
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          SizedBox(height: 4),
          Center(
            child: Text(
              _version,
              style: TextStyle(fontSize: 14, color: AppColors.gray),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              '小江 开发',
              style: TextStyle(fontSize: 14, color: AppColors.gray),
            ),
          ),
          SizedBox(height: 24),

          // 功能介绍
          PremiumCard(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '功能特性',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 12),
                _featureRow(Icons.camera_alt_rounded, '截图识别', '智能识别账单，自动记账'),
                _featureRow(Icons.mic_rounded, '语音记账', '说出金额，快速记录'),
                _featureRow(
                  Icons.account_balance_wallet_rounded,
                  '多钱包管理',
                  '支持预算追踪、超支提醒',
                ),
                _featureRow(Icons.bar_chart_rounded, '统计分析', '周报/月报/年度趋势'),
                _featureRow(Icons.dark_mode_rounded, '深色模式', '6 套配色方案随心切换'),
                _featureRow(Icons.notifications_rounded, '记账提醒', '每日定时提醒记账'),
                _featureRow(Icons.sync_rounded, '云同步', '数据自动同步，永不丢失'),
              ],
            ),
          ),
          SizedBox(height: 16),

          // 相关链接
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _linkRow(
                  Icons.privacy_tip_rounded,
                  '隐私政策',
                  () => _launchUrl(
                    'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1963916938002324672',
                  ),
                ),
                Divider(indent: 52),
                _linkRow(Icons.description_rounded, '用户协议', () {}),
                Divider(indent: 52),
                _linkRow(Icons.language_rounded, '了解官网', () {}),
                Divider(indent: 52),
                _linkRow(
                  Icons.code_rounded,
                  '开源许可',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LicensePage()),
                  ),
                ),
                Divider(indent: 52),
                _linkRow(
                  Icons.share_rounded,
                  '分享给朋友',
                  () => Share.share(
                    '小满记账 - 智能记账App，记录每一笔，攒出小确幸 🌸\nhttps://github.com/zeeeejin1024/xiaojia_ledger',
                  ),
                ),
                Divider(indent: 52),
                _linkRow(
                  Icons.help_outline_rounded,
                  '帮助中心',
                  () => _launchUrl(
                    'https://github.com/zeeeejin1024/xiaojia_ledger/wiki',
                  ),
                ),
                Divider(indent: 52),
                _linkRow(Icons.info_outline_rounded, '检查更新', () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('当前已是最新版本')));
                }),
              ],
            ),
          ),
          SizedBox(height: 16),

          // 联系我们
          PremiumCard(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '联系我们',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 12),
                _infoRow('开发者', '小江'),
                _infoRow('邮箱', '2026335267@qq.com'),
                GestureDetector(
                  onTap: () => _launchUrl(
                    'https://github.com/zeeeejin1024/xiaojia_ledger',
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GitHub',
                          style: TextStyle(fontSize: 14, color: AppColors.gray),
                        ),
                        Row(
                          children: [
                            Text(
                              'github.com/zeeeejin1024/xiaojia_ledger',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.highlight,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.open_in_new,
                              size: 14,
                              color: AppColors.highlight,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // 版权信息
          Center(
            child: Text(
              '© 2026 小满记账团队',
              style: TextStyle(fontSize: 12, color: AppColors.gray),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              '保留所有权利',
              style: TextStyle(fontSize: 12, color: AppColors.gray),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String title, String desc) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12, color: AppColors.gray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkRow(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.ink, size: 22),
      title: Text(title, style: TextStyle(fontSize: 16, color: AppColors.ink)),
      trailing: Icon(Icons.chevron_right, color: AppColors.gray, size: 20),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: AppColors.gray)),
          Text(value, style: TextStyle(fontSize: 14, color: AppColors.ink)),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('无法打开链接')));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法打开链接')));
      }
    }
  }
}
