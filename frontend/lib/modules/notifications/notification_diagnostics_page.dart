import 'package:flutter/material.dart';
import 'package:xiaojia_ledger/core/notifications.dart';
import 'package:xiaojia_ledger/core/notification_models.dart';
import 'package:xiaojia_ledger/core/theme.dart';

class NotificationDiagnosticsPage extends StatefulWidget {
  const NotificationDiagnosticsPage({super.key});
  @override
  State<NotificationDiagnosticsPage> createState() =>
      _NotificationDiagnosticsPageState();
}

class _NotificationDiagnosticsPageState
    extends State<NotificationDiagnosticsPage> {
  NotificationQueueState _pending = NotificationQueueState.unavailable;
  bool _running = false;
  bool _refreshing = false;
  bool? _permission;
  String _result = '尚未执行测试';
  DateTime? _refreshedAt;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing || !mounted) return;
    setState(() => _refreshing = true);
    try {
      final pending = await NotificationService.pendingState();
      final permission = await NotificationService.isPermissionGranted();
      if (mounted) {
        setState(() {
          _pending = pending;
          _permission = permission;
          _refreshedAt = DateTime.now();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pending = NotificationQueueState.unavailable;
          _permission = null;
          _result = '状态读取失败，请重试';
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _test(bool scheduled) async {
    if (_running || _refreshing) return;
    setState(() => _running = true);
    var success = false;
    try {
      if (scheduled) {
        success = await NotificationService.testScheduledNotification();
      } else {
        if (!await NotificationService.isPermissionGranted()) {
          success = await NotificationService.requestPermission();
        } else {
          success = true;
        }
        if (success) await NotificationService.testNotification();
      }
    } catch (_) {
      success = false;
    }
    await _refresh();
    if (mounted) {
      setState(() {
        _running = false;
        _result = success
            ? (scheduled
                  ? '系统队列已确认；目标时间为 15 秒后，省电模式可能延后。是否收到请查看通知栏。'
                  : '已提交系统，请查看通知栏确认是否收到')
            : '测试失败，请检查通知权限和后台设置';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AppThemedPage(
    builder: (_, _) => Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('通知诊断')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('开发诊断', style: TextStyle(color: AppColors.gray)),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('通知权限'),
            subtitle: Text(
              _refreshing
                  ? '读取中'
                  : _permission == null
                  ? '暂不可用'
                  : _permission!
                  ? '已允许'
                  : '未允许',
            ),
          ),
          ListTile(
            title: const Text('待触发通知'),
            subtitle: Text(
              _refreshing
                  ? '读取中'
                  : _pending.isAvailable
                  ? '${_pending.count} 条'
                  : '无法读取系统队列',
            ),
          ),
          ListTile(
            title: const Text('最近一次检查'),
            subtitle: Text(
              _refreshedAt == null
                  ? '尚未读取'
                  : '${_refreshedAt!.hour.toString().padLeft(2, '0')}:${_refreshedAt!.minute.toString().padLeft(2, '0')}:${_refreshedAt!.second.toString().padLeft(2, '0')}',
            ),
          ),
          Card(
            color: AppColors.info.withAlpha(18),
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('测试结果'),
              subtitle: Text(_result),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _running || _refreshing ? null : () => _test(false),
            child: const Text('发送即时测试'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _running || _refreshing ? null : () => _test(true),
            child: const Text('安排定时测试'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _running || _refreshing ? null : _refresh,
            child: const Text('重新读取系统队列'),
          ),
        ],
      ),
    ),
  );
}
