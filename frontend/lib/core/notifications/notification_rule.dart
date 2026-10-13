import 'package:flutter/material.dart';

enum NotificationRuleKind { daily, weekly, monthly, budget, deal }

class NotificationRule {
  final String id;
  final bool enabled;
  final TimeOfDay time;
  final NotificationRuleKind kind;
  const NotificationRule({
    required this.id,
    required this.enabled,
    required this.time,
    required this.kind,
  });
}
