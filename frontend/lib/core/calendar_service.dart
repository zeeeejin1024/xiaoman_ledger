import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarService {
  static Future<bool> requestPermission() async {
    final status = await Permission.calendar.request();
    return status.isGranted;
  }

  static Future<bool> isPermissionGranted() async {
    final status = await Permission.calendar.status;
    return status.isGranted;
  }

  /// 同步周报到系统日历
  /// 注意：当前为占位实现，实际日历写入功能待后续集成
  static Future<bool> syncWeeklyReport(String startDate, String endDate, Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    final enabled = p.getBool('calendar_sync_enabled') ?? false;
    if (!enabled) return false;

    final granted = await isPermissionGranted();
    if (!granted) return false;

    // TODO: 实现实际的日历同步逻辑
    // 需要使用 platform channel 或第三方包来写入系统日历
    // 当前仅返回成功，实际未写入日历
    return true;
  }

  /// 同步月报到系统日历
  /// 注意：当前为占位实现，实际日历写入功能待后续集成
  static Future<bool> syncMonthlyReport(String month, Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    final enabled = p.getBool('calendar_sync_enabled') ?? false;
    if (!enabled) return false;

    final granted = await isPermissionGranted();
    if (!granted) return false;

    // TODO: 实现实际的日历同步逻辑
    // 当前仅返回成功，实际未写入日历
    return true;
  }

  static Future<void> setSyncEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('calendar_sync_enabled', enabled);
  }

  static Future<bool> isSyncEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('calendar_sync_enabled') ?? false;
  }
}
