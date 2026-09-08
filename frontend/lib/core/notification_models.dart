import 'dart:convert';

enum BudgetThreshold { eightyPercent, hundredPercent }

class NotificationPreferences {
  final bool dailyEnabled;
  final int dailyHour;
  final int dailyMinute;
  final bool budgetEnabled;
  final bool weeklyEnabled;
  final int weeklyWeekday;
  final int weeklyHour;
  final int weeklyMinute;
  final bool monthlyEnabled;
  final int monthlyDay;
  final int monthlyHour;
  final int monthlyMinute;
  final bool dealsEnabled;
  final int dealsHour;
  final int dealsMinute;

  const NotificationPreferences({
    this.dailyEnabled = false,
    this.dailyHour = 21,
    this.dailyMinute = 0,
    this.budgetEnabled = false,
    this.weeklyEnabled = true,
    this.weeklyWeekday = DateTime.monday,
    this.weeklyHour = 9,
    this.weeklyMinute = 0,
    this.monthlyEnabled = true,
    this.monthlyDay = 1,
    this.monthlyHour = 9,
    this.monthlyMinute = 0,
    this.dealsEnabled = false,
    this.dealsHour = 9,
    this.dealsMinute = 0,
  });

  NotificationPreferences copyWith({
    bool? dailyEnabled,
    int? dailyHour,
    int? dailyMinute,
    bool? budgetEnabled,
    bool? weeklyEnabled,
    int? weeklyWeekday,
    int? weeklyHour,
    int? weeklyMinute,
    bool? monthlyEnabled,
    int? monthlyDay,
    int? monthlyHour,
    int? monthlyMinute,
    bool? dealsEnabled,
    int? dealsHour,
    int? dealsMinute,
  }) => NotificationPreferences(
    dailyEnabled: dailyEnabled ?? this.dailyEnabled,
    dailyHour: dailyHour ?? this.dailyHour,
    dailyMinute: dailyMinute ?? this.dailyMinute,
    budgetEnabled: budgetEnabled ?? this.budgetEnabled,
    weeklyEnabled: weeklyEnabled ?? this.weeklyEnabled,
    weeklyWeekday: weeklyWeekday ?? this.weeklyWeekday,
    weeklyHour: weeklyHour ?? this.weeklyHour,
    weeklyMinute: weeklyMinute ?? this.weeklyMinute,
    monthlyEnabled: monthlyEnabled ?? this.monthlyEnabled,
    monthlyDay: monthlyDay ?? this.monthlyDay,
    monthlyHour: monthlyHour ?? this.monthlyHour,
    monthlyMinute: monthlyMinute ?? this.monthlyMinute,
    dealsEnabled: dealsEnabled ?? this.dealsEnabled,
    dealsHour: dealsHour ?? this.dealsHour,
    dealsMinute: dealsMinute ?? this.dealsMinute,
  );
}

class DealReminder {
  final int id;
  final String title;
  final String description;
  final DateTime remindDate;

  const DealReminder({
    required this.id,
    required this.title,
    required this.description,
    required this.remindDate,
  });
}

class BudgetSnapshot {
  final String id;
  final String label;
  final double spent;
  final double limit;

  const BudgetSnapshot({
    required this.id,
    required this.label,
    required this.spent,
    required this.limit,
  });
}

class NotificationPayload {
  final int version;
  final String type;
  final String route;
  final String action;
  final int? entityId;

  const NotificationPayload({
    required this.type,
    required this.route,
    this.action = '',
    this.entityId,
    this.version = 1,
  });

  static const fallback = NotificationPayload(type: 'unknown', route: 'home');

  String encode() => jsonEncode({
    'v': version,
    'type': type,
    'route': route,
    'action': action,
    if (entityId != null) 'entity_id': entityId,
  });

  static NotificationPayload decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) return fallback;
      final type = value['type'];
      final route = value['route'];
      if (type is! String ||
          route is! String ||
          type.isEmpty ||
          route.isEmpty) {
        return fallback;
      }
      final entity = value['entity_id'];
      return NotificationPayload(
        version: value['v'] is int ? value['v'] as int : 1,
        type: type,
        route: route,
        action: value['action'] is String ? value['action'] as String : '',
        entityId: entity is int ? entity : int.tryParse('$entity'),
      );
    } catch (_) {
      return fallback;
    }
  }
}
