import 'package:flutter/material.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/core/notification_policy.dart';
import 'package:xiaojia_ledger/core/notification_models.dart';
import 'package:xiaojia_ledger/core/notifications.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'notification_center_labels.dart';
import 'notification_center_backend.dart';
import 'notification_diagnostics_page.dart';
import 'notification_help_page.dart';
import 'package:xiaojia_ledger/core/notifications/schedule_plan.dart';

class NotificationCenterPage extends StatefulWidget {
  final NotificationCenterBackend? backend;
  const NotificationCenterPage({super.key, this.backend});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage>
    with WidgetsBindingObserver {
  late final NotificationCenterBackend _backend;
  NotificationPreferences? _settings;
  bool _permission = false;
  bool _loading = true;
  bool _saving = false;
  int _versionTaps = 0;
  AuditState _dailyState = AuditState.disabled;
  DateTime? _dailyNextAt;
  Set<int>? _pendingIds;
  String? _error;
  bool _refreshing = false;
  bool _resumePending = false;

  @override
  void initState() {
    super.initState();
    _backend = widget.backend ?? LocalNotificationCenterBackend();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_saving || _refreshing) {
      _resumePending = true;
    } else {
      _load();
    }
  }

  void _apply(NotificationCenterSnapshot snapshot) {
    _settings = snapshot.settings;
    _permission = snapshot.permission;
    _dailyState = snapshot.dailyState;
    _dailyNextAt = snapshot.dailyNextAt;
    _pendingIds = snapshot.pendingIds;
    _error = null;
  }

  Future<void> _load() async {
    if (_refreshing || _saving || !mounted) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final snapshot = await _backend.load();
      if (mounted) setState(() => _apply(snapshot));
    } catch (_) {
      if (mounted) setState(() => _error = '通知设置读取失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
        if (_resumePending) {
          _resumePending = false;
          await _load();
        }
      }
    }
  }

  String get _dailyStatus {
    switch (_dailyState) {
      case AuditState.scheduled:
      case AuditState.degraded:
        final next = _dailyNextAt;
        if (next == null) return '已安排';
        return '下一次：${next.month}月${next.day}日 ${NotificationCenterLabels.time(next.hour, next.minute)}';
      case AuditState.blocked:
        return '等待系统通知权限';
      case AuditState.failed:
        return '系统队列未确认，请重试';
      case AuditState.disabled:
        return '已关闭';
    }
  }

  Future<void> _update(NotificationPreferences next) async {
    if (_saving || _refreshing || !mounted) return;
    setState(() => _saving = true);
    var saved = false;
    try {
      final ok = await _backend.save(next);
      saved = true;
      final snapshot = await _backend.load(reconcile: false);
      if (!mounted) return;
      setState(() => _apply(snapshot));
      if (!ok) {
        _message(
          snapshot.permission ? '设置已保存，但部分提醒未安排成功，请下拉重试' : '系统通知权限未开启，请前往设置后重试',
        );
      }
    } catch (_) {
      if (mounted) {
        _message(saved ? '设置已提交，但状态读取失败，请下拉刷新' : '设置保存失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        if (_resumePending) {
          _resumePending = false;
          await _load();
        }
      }
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String _reportStatus(bool enabled, int id) {
    if (!enabled) return '已关闭';
    if (!_permission) return '等待系统通知权限';
    if (_pendingIds == null) return '暂时无法读取系统队列';
    return _pendingIds!.contains(id) ? '已安排查看提醒，打开后加载报告' : '系统队列未确认，请下拉重试';
  }

  Future<void> _pickTime(
    String title,
    int hour,
    int minute,
    NotificationPreferences Function(TimeOfDay) change,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      helpText: title,
    );
    if (picked != null && mounted) await _update(change(picked));
  }

  Future<void> _pickWeekday() async {
    final settings = _settings;
    if (settings == null) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: List.generate(7, (index) {
            final value = index + 1;
            return ListTile(
              title: Text(NotificationCenterLabels.weekday(value)),
              trailing: value == settings.weeklyWeekday
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(context, value),
            );
          }),
        ),
      ),
    );
    if (selected != null && mounted) {
      await _update(settings.copyWith(weeklyWeekday: selected));
    }
  }

  Future<void> _pickMonthDay() async {
    final settings = _settings;
    if (settings == null) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 320,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 28,
            itemBuilder: (_, index) {
              final value = index + 1;
              return OutlinedButton(
                onPressed: () => Navigator.pop(context, value),
                child: Text('$value'),
              );
            },
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      await _update(settings.copyWith(monthlyDay: selected));
    }
  }

  Widget _ruleCard({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    Widget? detail,
  }) => Card(
    key: key,
    margin: const EdgeInsets.only(bottom: 12),
    child: Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          secondary: Icon(icon, color: AppColors.info),
          title: Text(title),
          subtitle: Text(subtitle),
          value: enabled,
          onChanged: _saving || _refreshing ? null : onChanged,
        ),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: detail,
          ),
      ],
    ),
  );

  Widget _timeButton({required String label, required VoidCallback onTap}) =>
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: _saving || _refreshing ? null : onTap,
        icon: const Icon(Icons.schedule_outlined, size: 18),
        label: Text(label),
      );

  @override
  Widget build(BuildContext context) => AppThemedPage(
    builder: (_, _) => Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('通知中心')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _settings == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? '通知设置读取失败，请重试'),
                  TextButton(
                    onPressed: _refreshing ? null : _load,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (_error != null)
                    ListTile(
                      title: Text(_error!),
                      trailing: TextButton(
                        onPressed: _load,
                        child: const Text('重试'),
                      ),
                    ),
                  Card(
                    color: _permission
                        ? AppColors.success.withAlpha(22)
                        : AppColors.danger.withAlpha(22),
                    child: ListTile(
                      leading: Icon(
                        _permission
                            ? Icons.verified_rounded
                            : Icons.error_outline_rounded,
                        color: _permission
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                      title: Text(_permission ? '系统通知权限已开启' : '系统通知权限未开启'),
                      subtitle: Text(
                        _permission ? '本机提醒可能受省电与后台限制影响' : '开启权限后才能收到定时提醒',
                      ),
                      trailing: _permission
                          ? null
                          : TextButton(
                              onPressed: NotificationService
                                  .openSystemNotificationSettings,
                              child: const Text('去设置'),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('提醒规则', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _ruleCard(
                    key: const ValueKey('notification-rule-daily'),
                    icon: Icons.edit_calendar_outlined,
                    title: '每日记账提醒',
                    subtitle: _dailyStatus,
                    enabled: _settings!.dailyEnabled,
                    onChanged: (value) =>
                        _update(_settings!.copyWith(dailyEnabled: value)),
                    detail: _timeButton(
                      label: NotificationCenterLabels.time(
                        _settings!.dailyHour,
                        _settings!.dailyMinute,
                      ),
                      onTap: () => _pickTime(
                        '选择每日提醒时间',
                        _settings!.dailyHour,
                        _settings!.dailyMinute,
                        (time) => _settings!.copyWith(
                          dailyHour: time.hour,
                          dailyMinute: time.minute,
                        ),
                      ),
                    ),
                  ),
                  _ruleCard(
                    key: const ValueKey('notification-rule-weekly'),
                    icon: Icons.insights_outlined,
                    title: '省钱周报',
                    subtitle: _reportStatus(
                      _settings!.weeklyEnabled,
                      NotificationPolicy.weeklyReportId,
                    ),
                    enabled: _settings!.weeklyEnabled,
                    onChanged: (value) =>
                        _update(_settings!.copyWith(weeklyEnabled: value)),
                    detail: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _timeButton(
                          label: NotificationCenterLabels.weekday(
                            _settings!.weeklyWeekday,
                          ),
                          onTap: _pickWeekday,
                        ),
                        _timeButton(
                          label: NotificationCenterLabels.time(
                            _settings!.weeklyHour,
                            _settings!.weeklyMinute,
                          ),
                          onTap: () => _pickTime(
                            '选择周报提醒时间',
                            _settings!.weeklyHour,
                            _settings!.weeklyMinute,
                            (time) => _settings!.copyWith(
                              weeklyHour: time.hour,
                              weeklyMinute: time.minute,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ruleCard(
                    key: const ValueKey('notification-rule-monthly'),
                    icon: Icons.calendar_month_outlined,
                    title: '月度报告',
                    subtitle: _reportStatus(
                      _settings!.monthlyEnabled,
                      NotificationPolicy.monthlyReportId,
                    ),
                    enabled: _settings!.monthlyEnabled,
                    onChanged: (value) =>
                        _update(_settings!.copyWith(monthlyEnabled: value)),
                    detail: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _timeButton(
                          label: NotificationCenterLabels.monthDay(
                            _settings!.monthlyDay,
                          ),
                          onTap: _pickMonthDay,
                        ),
                        _timeButton(
                          label: NotificationCenterLabels.time(
                            _settings!.monthlyHour,
                            _settings!.monthlyMinute,
                          ),
                          onTap: () => _pickTime(
                            '选择月报提醒时间',
                            _settings!.monthlyHour,
                            _settings!.monthlyMinute,
                            (time) => _settings!.copyWith(
                              monthlyHour: time.hour,
                              monthlyMinute: time.minute,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ruleCard(
                    key: const ValueKey('notification-rule-budget'),
                    icon: Icons.account_balance_wallet_outlined,
                    title: '预算提醒',
                    subtitle: _settings!.budgetEnabled
                        ? '达到 80% 和 100% 时提醒'
                        : '已关闭',
                    enabled: _settings!.budgetEnabled,
                    onChanged: (value) =>
                        _update(_settings!.copyWith(budgetEnabled: value)),
                  ),
                  _ruleCard(
                    key: const ValueKey('notification-rule-living'),
                    icon: Icons.savings_outlined,
                    title: '生活费提醒',
                    subtitle: _settings!.livingEnabled
                        ? '达到 75%、90% 和 100% 时提醒'
                        : '已关闭',
                    enabled: _settings!.livingEnabled,
                    onChanged: (value) =>
                        _update(_settings!.copyWith(livingEnabled: value)),
                  ),
                  _ruleCard(
                    key: const ValueKey('notification-rule-deals'),
                    icon: Icons.local_offer_outlined,
                    title: '优惠提醒',
                    subtitle: _settings!.dealsEnabled ? '有待办优惠时提醒' : '已关闭',
                    enabled: _settings!.dealsEnabled,
                    onChanged: (value) =>
                        _update(_settings!.copyWith(dealsEnabled: value)),
                    detail: _timeButton(
                      label: NotificationCenterLabels.time(
                        _settings!.dealsHour,
                        _settings!.dealsMinute,
                      ),
                      onTap: () => _pickTime(
                        '选择优惠提醒时间',
                        _settings!.dealsHour,
                        _settings!.dealsMinute,
                        (time) => _settings!.copyWith(
                          dealsHour: time.hour,
                          dealsMinute: time.minute,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '每日提醒预排未来 30 天，打开应用自动续排；当天记过账后跳过。定时提醒使用省电模式，可能延后。',
                    style: TextStyle(color: AppColors.gray, fontSize: 12),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.settings_suggest_outlined),
                      title: const Text('通知与后台设置'),
                      subtitle: const Text('查看手机品牌教程并打开系统设置'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationHelpPage(),
                        ),
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.build_circle_outlined),
                      title: const Text('通知诊断'),
                      subtitle: const Text('测试即时和定时通知，检查系统队列'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationDiagnosticsPage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      _versionTaps++;
                      if (_versionTaps >= 7) {
                        _versionTaps = 0;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationDiagnosticsPage(),
                          ),
                        );
                      }
                    },
                    child: Center(
                      child: Text(
                        '通知模块 ${AppConstants.appVersion}',
                        style: TextStyle(color: AppColors.gray, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}
