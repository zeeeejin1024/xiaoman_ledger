import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/core/router.dart';
import 'package:xiaojia_ledger/core/notifications.dart';
import 'package:xiaojia_ledger/core/notification_coordinator.dart';
import 'package:xiaojia_ledger/core/calendar_service.dart';
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
  int _idx = 0;
  bool _reminderEnabled = false;
  bool _budgetEnabled = false;
  bool _weeklyEnabled = true;
  bool _monthlyEnabled = true;
  bool _dealsEnabled = false;
  bool _notificationPermission = false;
  int _pendingNotifications = 0;
  bool _calendarSyncEnabled = false;
  String _reminderTime = '21:00';
  String _syncFrequency = '手动';

  @override
  void initState() {
    super.initState();
    _idx = AppColors.schemeIndex;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final syncEnabled = await CalendarService.isSyncEnabled();
    final coordinator = await NotificationCoordinator.shared();
    final n = coordinator.settings;
    final permission = await NotificationService.isPermissionGranted();
    final pending = await NotificationService.pendingCount();
    setState(() {
      _reminderEnabled = n.dailyEnabled;
      _reminderTime =
          '${n.dailyHour.toString().padLeft(2, '0')}:${n.dailyMinute.toString().padLeft(2, '0')}';
      _budgetEnabled = n.budgetEnabled;
      _weeklyEnabled = n.weeklyEnabled;
      _monthlyEnabled = n.monthlyEnabled;
      _dealsEnabled = n.dealsEnabled;
      _notificationPermission = permission;
      _pendingNotifications = pending;
      _calendarSyncEnabled = syncEnabled;
      _syncFrequency = prefs.getString('sync_frequency') ?? '手动';
    });
  }

  Future<void> _toggleNotificationType(String type, bool enabled) async {
    final coordinator = await NotificationCoordinator.shared();
    final current = coordinator.settings;
    final next = switch (type) {
      'daily' => current.copyWith(dailyEnabled: enabled),
      'budget' => current.copyWith(budgetEnabled: enabled),
      'weekly' => current.copyWith(weeklyEnabled: enabled),
      'monthly' => current.copyWith(monthlyEnabled: enabled),
      'deals' => current.copyWith(dealsEnabled: enabled),
      _ => current,
    };
    final ok = await coordinator.requestPermissionAndUpdate(next);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('需要通知权限才能开启提醒')));
      return;
    }
    await _loadSettings();
  }

  Future<void> _scheduleReminder() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('reminder_time', _reminderTime);
    final parts = _reminderTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final coordinator = await NotificationCoordinator.shared();
    await coordinator.requestPermissionAndUpdate(
      coordinator.settings.copyWith(
        dailyEnabled: true,
        dailyHour: hour,
        dailyMinute: minute,
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('记账提醒已开启，每天 $_reminderTime 提醒')));
  }

  Future<void> _pickReminderTime() async {
    final parts = _reminderTime.split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (time != null) {
      final newTime =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      setState(() => _reminderTime = newTime);
      final p = await SharedPreferences.getInstance();
      await p.setString('reminder_time', newTime);
      final coordinator = await NotificationCoordinator.shared();
      await coordinator.requestPermissionAndUpdate(
        coordinator.settings.copyWith(
          dailyEnabled: true,
          dailyHour: time.hour,
          dailyMinute: time.minute,
        ),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('提醒时间已设为 $newTime')));
    }
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

  void _pickScheme(int i) async {
    final s = AppColorScheme.all[i];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('color_scheme', i);
    AppColors.apply(s);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: s.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: s.navBg,
        systemNavigationBarIconBrightness: s.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
    if (mounted)
      setState(() {
        _idx = i;
      });
  }

  @override
  Widget build(BuildContext context) {
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
          // 记账提醒
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(
                  Icons.notifications_rounded,
                  '记账提醒',
                  trailing: Switch(
                    value: _reminderEnabled,
                    onChanged: (v) async {
                      HapticFeedback.lightImpact();
                      await _toggleNotificationType('daily', v);
                    },
                  ),
                ),
                if (_reminderEnabled) ...[
                  Divider(indent: 52),
                  _row(
                    Icons.access_time_rounded,
                    '提醒时间',
                    trailing: Text(
                      _reminderTime,
                      style: TextStyle(fontSize: 14, color: AppColors.gray),
                    ),
                    onTap: _pickReminderTime,
                  ),
                  Divider(indent: 52),
                  _row(
                    Icons.send_rounded,
                    '测试即时通知',
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await NotificationService.testNotification();
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('即时通知已发送，查看通知栏')),
                        );
                    },
                  ),
                  Divider(indent: 52),
                  _row(
                    Icons.timer_rounded,
                    '测试定时通知（15秒）',
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final ok =
                          await NotificationService.testScheduledNotification();
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? '定时通知已调度，15秒后查看通知栏' : '调度失败，请检查权限',
                            ),
                          ),
                        );
                    },
                  ),
                ],
                Divider(indent: 52),
                _row(
                  Icons.account_balance_wallet_rounded,
                  '预算超支提醒',
                  trailing: Switch(
                    value: _budgetEnabled,
                    onChanged: (v) => _toggleNotificationType('budget', v),
                  ),
                ),
                Divider(indent: 52),
                _row(
                  Icons.auto_awesome_rounded,
                  '省钱周报提醒',
                  trailing: Switch(
                    value: _weeklyEnabled,
                    onChanged: (v) => _toggleNotificationType('weekly', v),
                  ),
                ),
                Divider(indent: 52),
                _row(
                  Icons.calendar_month_rounded,
                  '月度报告提醒',
                  trailing: Switch(
                    value: _monthlyEnabled,
                    onChanged: (v) => _toggleNotificationType('monthly', v),
                  ),
                ),
                Divider(indent: 52),
                _row(
                  Icons.local_offer_rounded,
                  '优惠到期提醒',
                  trailing: Switch(
                    value: _dealsEnabled,
                    onChanged: (v) => _toggleNotificationType('deals', v),
                  ),
                ),
                Divider(indent: 52),
                _row(
                  Icons.pending_actions_rounded,
                  '待触发通知',
                  trailing: Text(
                    '$_pendingNotifications 条',
                    style: TextStyle(fontSize: 13, color: AppColors.gray),
                  ),
                ),
                Divider(indent: 52),
                _row(
                  _notificationPermission
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  _notificationPermission ? '通知权限已开启' : '通知权限未开启',
                  trailing: _notificationPermission
                      ? null
                      : TextButton(
                          onPressed: () async {
                            await NotificationService.openSystemNotificationSettings();
                          },
                          child: const Text('去设置'),
                        ),
                ),
                Divider(indent: 52),
                _row(
                  Icons.calendar_today_rounded,
                  '日历同步',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '同步周报/月报',
                        style: TextStyle(fontSize: 11, color: AppColors.gray),
                      ),
                      SizedBox(width: 8),
                      Switch(
                        value: _calendarSyncEnabled,
                        onChanged: (v) async {
                          HapticFeedback.lightImpact();
                          if (v) {
                            final granted =
                                await CalendarService.requestPermission();
                            if (!granted) {
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('需要日历权限才能同步')),
                                );
                              return;
                            }
                          }
                          setState(() => _calendarSyncEnabled = v);
                          await CalendarService.setSyncEnabled(v);
                        },
                      ),
                    ],
                  ),
                ),
                Divider(indent: 52),
                _row(
                  Icons.sync_rounded,
                  '自动同步',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _syncFrequency,
                        style: TextStyle(fontSize: 11, color: AppColors.gray),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.gray,
                        size: 18,
                      ),
                    ],
                  ),
                  onTap: _pickSyncFrequency,
                ),
              ],
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
                      final r = await ApiClient().get('/export/csv');
                      final dir = await getTemporaryDirectory();
                      final f = File(
                        '${dir.path}/records_${DateTime.now().toIso8601String().split('T')[0]}.csv',
                      );
                      await f.writeAsString(r.data.toString());
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
                      final r = await ApiClient().get('/export/json');
                      final dir = await getTemporaryDirectory();
                      final f = File(
                        '${dir.path}/backup_${DateTime.now().toIso8601String().split('T')[0]}.json',
                      );
                      await f.writeAsString(r.data.toString());
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
