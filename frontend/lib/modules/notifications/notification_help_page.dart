import 'package:flutter/material.dart';
import 'package:xiaojia_ledger/core/notification_device_settings.dart';
import 'package:xiaojia_ledger/core/theme.dart';

class NotificationHelpPage extends StatelessWidget {
  const NotificationHelpPage({super.key});

  @override
  Widget build(BuildContext context) => AppThemedPage(
    builder: (_, _) => Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('通知与后台设置')),
      body: FutureBuilder<String>(
        future: NotificationDeviceSettings.manufacturer(),
        builder: (_, snapshot) {
          final guide = NotificationDeviceGuide.fromManufacturer(
            snapshot.data ?? 'Android',
          );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${guide.brandName} 设置建议',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...guide.steps.indexed.map(
                (item) => ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${item.$1 + 1}'),
                  ),
                  title: Text(item.$2),
                ),
              ),
              const SizedBox(height: 12),
              Text(guide.fallback, style: TextStyle(color: AppColors.gray)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: NotificationDeviceSettings.openNotificationSettings,
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('打开通知设置'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: NotificationDeviceSettings.openBackgroundSettings,
                icon: const Icon(Icons.battery_saver_outlined),
                label: const Text('打开后台设置'),
              ),
            ],
          );
        },
      ),
    ),
  );
}
