import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/modules/notifications/notification_center_page.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/core/router.dart';
import 'package:xiaojia_ledger/modules/home/home_page.dart';
import 'package:xiaojia_ledger/data/api/api_client.dart';
import 'package:xiaojia_ledger/modules/settings/about_page.dart';
import 'package:xiaojia_ledger/data/api/auth_api.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _syncFrequency = '手动';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _syncFrequency = prefs.getString('sync_frequency') ?? '手动';
    });
  }

  Future<void> _pickSyncFrequency() async {
    final frequencies = ['手动', '每5分钟', '每小时', '每次打开'];
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('同步频率'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: frequencies
              .map(
                (f) => RadioListTile<String>(
                  title: Text(f),
                  value: f,
                  groupValue: _syncFrequency,
                  onChanged: (v) => Navigator.pop(ctx, v),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消')),
        ],
      ),
    );
    if (result != null) {
      setState(() => _syncFrequency = result);
      final p = await SharedPreferences.getInstance();
      await p.setString('sync_frequency', result);
    }
  }

  @override
  Widget build(BuildContext context) =>
      AppThemedPage(builder: (context, _) => _buildPage(context));

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('设置', style: TextStyle(color: AppColors.ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          SizedBox(height: 20),
          // 账号安全
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(Icons.phone_android_rounded, '修改手机号', onTap: _changePhone),
                Divider(indent: 52),
                _row(Icons.lock_rounded, '修改密码', onTap: _changePassword),
                Divider(indent: 52),
                _row(Icons.help_rounded, '修改密保', onTap: _changeSecurity),
              ],
            ),
          ),
          SizedBox(height: 20),
          // 账号
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(
                  Icons.person_outline_rounded,
                  '当前账号',
                  trailing: FutureBuilder<String?>(
                    future: SharedPreferences.getInstance().then(
                      (p) => p.getString(AppConstants.usernameKey),
                    ),
                    builder: (_, s) => Text(
                      s.data ?? '—',
                      style: TextStyle(fontSize: 14, color: AppColors.gray),
                    ),
                  ),
                ),
                Divider(indent: 52),
                _row(
                  Icons.swap_horiz_rounded,
                  '切换账号',
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('切换账号'),
                        content: Text('确定要切换账号吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              '确定',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && mounted) {
                      const storage = FlutterSecureStorage();
                      await storage.delete(key: AppConstants.tokenKey);
                      await storage.delete(key: AppConstants.usernameKey);
                      if (mounted)
                        Navigator.pushReplacementNamed(
                          context,
                          AppRouter.login,
                        );
                    }
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: _row(
              Icons.notifications_active_outlined,
              '通知中心',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationCenterPage(),
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: _row(
              Icons.sync_rounded,
              '自动同步',
              trailing: Text(
                _syncFrequency,
                style: TextStyle(color: AppColors.gray),
              ),
              onTap: _pickSyncFrequency,
            ),
          ),
          SizedBox(height: 20),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(
                  Icons.download_rounded,
                  '导出 CSV',
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    try {
                      final r = await ApiClient().get(
                        '/export/csv',
                        options: Options(responseType: ResponseType.plain),
                      );
                      final csvText = r.data as String;
                      if (!csvText.contains('日期,类型,分类,金额,备注')) {
                        throw const FormatException('CSV 表头无效');
                      }
                      final dir = await getTemporaryDirectory();
                      final f = File(
                        '${dir.path}/records_${DateTime.now().toIso8601String().split('T')[0]}.csv',
                      );
                      await f.writeAsString(csvText);
                      await Share.shareXFiles([
                        XFile(f.path),
                      ], text: '小满记账 - 账单导出');
                    } catch (_) {
                      if (mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('导出失败')));
                    }
                  },
                ),
                Divider(indent: 52),
                _row(
                  Icons.code_rounded,
                  '导出 JSON',
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    try {
                      final r = await ApiClient().get(
                        '/export/json',
                        options: Options(responseType: ResponseType.plain),
                      );
                      final jsonText = r.data as String;
                      if (jsonDecode(jsonText) is! List) {
                        throw const FormatException('JSON 数据无效');
                      }
                      final dir = await getTemporaryDirectory();
                      final f = File(
                        '${dir.path}/backup_${DateTime.now().toIso8601String().split('T')[0]}.json',
                      );
                      await f.writeAsString(jsonText);
                      await Share.shareXFiles([
                        XFile(f.path),
                      ], text: '小满记账 - 备份导出');
                    } catch (_) {
                      if (mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('导出失败')));
                    }
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: _row(
              Icons.delete_outline_rounded,
              '清空所有数据',
              onTap: () async {
                HapticFeedback.lightImpact();
                final confirmCtrl = TextEditingController();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => StatefulBuilder(
                    builder: (ctx, setSt) {
                      final confirmed = confirmCtrl.text.trim() == '清空';
                      return AlertDialog(
                        title: Text('确认清空'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('此操作不可恢复！'),
                            SizedBox(height: 12),
                            Text(
                              '请输入"清空"以确认：',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.gray,
                              ),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: confirmCtrl,
                              onChanged: (_) => setSt(() {}),
                              decoration: InputDecoration(
                                hintText: '请输入"清空"',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('取消'),
                          ),
                          TextButton(
                            onPressed: confirmed
                                ? () => Navigator.pop(context, true)
                                : null,
                            child: Text(
                              '确定',
                              style: TextStyle(
                                color: confirmed
                                    ? AppColors.danger
                                    : AppColors.gray,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
                if (ok == true) {
                  try {
                    await ApiClient().delete('/records');
                  } catch (_) {
                    if (mounted)
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('清空失败，请重试')));
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('已清空')));
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => HomePage()),
                      (_) => false,
                    );
                  }
                }
              },
              isDanger: true,
            ),
          ),
          SizedBox(height: 20),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(
                  Icons.help_rounded,
                  '关于与帮助',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                ),
                Divider(indent: 52),
                _row(
                  Icons.star_rounded,
                  '给个好评',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('感谢您的支持！')));
                  },
                ),
                Divider(indent: 52),
                _row(
                  Icons.info_rounded,
                  '开源许可',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showLicensePage(
                      context: context,
                      applicationName: AppConstants.appName,
                      applicationVersion: 'v${AppConstants.appVersion}',
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 40),
          Center(
            child: Text(
              '${AppConstants.appName} v${AppConstants.appVersion}',
              style: TextStyle(fontSize: 12, color: AppColors.gray),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePhone() async {
    HapticFeedback.lightImpact();
    final pwCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改手机号'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: '输入密码确认身份'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: '新手机号'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确定'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        final r = await AuthApi.updatePhone(pwCtrl.text, phoneCtrl.text.trim());
        if (r.isSuccess)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('手机号已更新')));
        else
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(r.message)));
      } catch (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('网络错误')));
      }
    }
  }

  Future<void> _changePassword() async {
    HapticFeedback.lightImpact();
    final oldPw = TextEditingController(), newPw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPw,
              obscureText: true,
              decoration: InputDecoration(labelText: '原密码'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: newPw,
              obscureText: true,
              decoration: InputDecoration(labelText: '新密码（至少6位）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确定'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        final r = await AuthApi.updatePassword(oldPw.text, newPw.text);
        if (r.isSuccess)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('密码已更新')));
        else
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(r.message)));
      } catch (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('网络错误')));
      }
    }
  }

  Future<void> _changeSecurity() async {
    HapticFeedback.lightImpact();
    final pwCtrl = TextEditingController(), ansCtrl = TextEditingController();
    String q = '你的母亲的名字是？';
    const questions = AppConstants.securityQuestions;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) {
          return AlertDialog(
            title: Text('修改密保'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pwCtrl,
                  obscureText: true,
                  decoration: InputDecoration(labelText: '输入密码确认身份'),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField(
                  value: q,
                  items: questions
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setSt(() => q = v ?? q),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: ansCtrl,
                  decoration: InputDecoration(labelText: '答案'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('确定'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true && mounted) {
      try {
        final r = await AuthApi.updateSecurity(
          pwCtrl.text,
          q,
          ansCtrl.text.trim(),
        );
        if (r.isSuccess)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('密保已更新')));
        else
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(r.message)));
      } catch (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('网络错误')));
      }
    }
  }

  Widget _row(
    IconData icon,
    String title, {
    VoidCallback? onTap,
    Widget? trailing,
    bool isDanger = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDanger ? AppColors.danger : AppColors.ink,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isDanger ? AppColors.danger : AppColors.ink,
        ),
      ),
      trailing:
          trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right, color: AppColors.gray, size: 20)
              : null),
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap();
            }
          : null,
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
