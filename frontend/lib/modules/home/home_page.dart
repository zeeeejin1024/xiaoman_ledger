import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/theme_reveal.dart';
import 'package:xiaojia_ledger/core/notification_coordinator.dart';
import 'package:xiaojia_ledger/core/notification_preferences.dart';
import 'package:xiaojia_ledger/core/living_allowance.dart';
import 'package:xiaojia_ledger/core/living_allowance_repository.dart';
import 'package:xiaojia_ledger/core/notifications.dart';
import 'package:xiaojia_ledger/core/notifications/threshold_delivery.dart';
import 'package:xiaojia_ledger/modules/home/home_header.dart';
import 'package:xiaojia_ledger/modules/home/home_subtitle_repository.dart';
import 'package:xiaojia_ledger/modules/record/add_record_sheet.dart';
import 'package:xiaojia_ledger/modules/record/records_list_page.dart';
import 'package:xiaojia_ledger/modules/stats/stats_page.dart';
import 'package:xiaojia_ledger/modules/savings/savings_page.dart';
import 'package:xiaojia_ledger/data/api/savings_api.dart';
import 'package:xiaojia_ledger/widgets/living_allowance_setup_dialog.dart';
import 'package:xiaojia_ledger/modules/profile/profile_page.dart';
import 'package:xiaojia_ledger/modules/settings/settings_page.dart';
import 'package:xiaojia_ledger/modules/voice/voice_page.dart';
import 'package:xiaojia_ledger/modules/report/weekly_report_page.dart';
import 'package:xiaojia_ledger/modules/wallet/wallet_page.dart';
import 'package:xiaojia_ledger/data/api/api_client.dart';
import 'package:xiaojia_ledger/data/api/record_api.dart';
import 'package:xiaojia_ledger/data/api/category_api.dart';
import 'package:xiaojia_ledger/data/models/record.dart';
import 'package:xiaojia_ledger/data/models/category.dart';
import 'package:xiaojia_ledger/widgets/unfinished_ring_mark.dart';
import 'package:xiaojia_ledger/widgets/lazy_tab_host.dart';
import 'package:xiaojia_ledger/modules/ocr/ocr_result_controller.dart';
import 'package:xiaojia_ledger/modules/ocr/ocr_result_page.dart';
import 'package:xiaojia_ledger/core/navigation_motion_controller.dart';
import 'package:xiaojia_ledger/widgets/liquid_glass_navigation_bar.dart';

const homeNavigationDestinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home_rounded),
    label: '首页',
  ),
  NavigationDestination(
    icon: Icon(Icons.insights_outlined),
    selectedIcon: Icon(Icons.insights_rounded),
    label: '统计',
  ),
  NavigationDestination(
    icon: Icon(Icons.flag_outlined),
    selectedIcon: Icon(Icons.flag_rounded),
    label: '存钱',
  ),
  NavigationDestination(
    icon: Icon(Icons.receipt_long_outlined),
    selectedIcon: Icon(Icons.receipt_long_rounded),
    label: '流水',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline_rounded),
    selectedIcon: Icon(Icons.person_rounded),
    label: '我的',
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final NavigationMotionController _navMotion;

  @override
  void initState() {
    super.initState();
    _navMotion = NavigationMotionController(vsync: this);
  }

  @override
  void dispose() {
    _navMotion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeBuilder(
      builder: (_, _) => Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: LazyTabHost(
            index: _tab,
            builders: [
              (_) => const _DashTab(),
              (_) => const StatsPage(),
              (_) => const SavingsPage(),
              (_) => const RecordsListPage(),
              (_) => const ProfilePage(),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: LiquidGlassNavigationBar(
            selectedIndex: _tab,
            controller: _navMotion,
            destinations: homeNavigationDestinations,
            onSelected: (i) {
              ThemeReveal.finish(context);
              _navMotion.animateTo(i);
              setState(() => _tab = i);
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 首页内容
// ============================================================
class _DashTab extends StatefulWidget {
  const _DashTab();
  @override
  State<_DashTab> createState() => _DashTabState();
}

class _DashTabState extends State<_DashTab> {
  List<Record> _records = [];
  double _exp = 0;
  double _todayExp = 0;
  double _prevExp = 0;
  bool _loading = true;
  String _subtitle = HomeSubtitleRepository.defaultValue;
  List<Category> _walletCategories = [];
  int _payDay = 0;
  double _livingExpense = 0;
  LivingAllowanceSettings _livingSettings = const LivingAllowanceSettings(
    baseAmount: 0,
    payday: 1,
  );
  LivingAllowanceSummary? _livingSummary;
  LivingAlertDelivery? _livingAlerts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final m = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    // 上月
    final prevMonth = now.month == 1
        ? '${now.year - 1}-12'
        : '${now.year}-${(now.month - 1).toString().padLeft(2, '0')}';
    try {
      final results = await Future.wait([
        RecordApi.getRecords(month: m),
        RecordApi.getRecords(month: prevMonth),
        _loadSubtitle(),
        _loadWalletData(),
        _loadLiving(),
      ]);
      final r = results[0] as dynamic;
      final rPrev = results[1] as dynamic;
      double exp = 0;
      double todayExp = 0;
      double prevExp = 0;
      final today = DateTime.now().toIso8601String().split('T')[0];
      if (r.isSuccess && r.data != null) {
        for (final e in r.data!) {
          if (!e.isIncome) {
            exp += e.amount;
            if (e.date == today) todayExp += e.amount;
          }
        }
      }
      if (rPrev.isSuccess && rPrev.data != null) {
        for (final e in rPrev.data!) {
          if (!e.isIncome) prevExp += e.amount;
        }
      }
      if (mounted)
        setState(() {
          _records = r.data ?? [];
          _exp = exp;
          _todayExp = todayExp;
          _prevExp = prevExp;
          _loading = false;
        });
      await _refreshLivingSummary([...(r.data ?? []), ...(rPrev.data ?? [])]);
      // 检查通知点击的自动打开标记
      _checkAutoOpenAdd();
      // Voice/OCR/imported records share this refresh path with manual entries.
      // Do not let notification recovery turn a successful data load into an error.
      try {
        final coordinator = await NotificationCoordinator.shared();
        if (r.isSuccess &&
            r.data != null &&
            (r.data as List<Record>).any((record) => record.date == today)) {
          await coordinator.preferences.markRecordedOn(now);
        }
        await coordinator.reconcileAll();
      } catch (error) {
        debugPrint('Notification refresh failed: ${error.runtimeType}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载失败，请下拉刷新')));
      }
    }
  }

  Future<void> _checkAutoOpenAdd() async {
    final p = await SharedPreferences.getInstance();
    final autoOpen = p.getBool('auto_open_add') ?? false;
    if (autoOpen && mounted) {
      await p.remove('auto_open_add');
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) _openAdd();
      });
    }
  }

  Future<void> _loadSubtitle() async {
    final preferences = await SharedPreferences.getInstance();
    final subtitle = HomeSubtitleRepository(preferences).load();
    if (mounted && _subtitle != subtitle) {
      setState(() => _subtitle = subtitle);
    }
  }

  Future<void> _loadLiving() async {
    final p = await SharedPreferences.getInstance();
    final settings = LivingAllowanceRepository(p).loadSettings();
    final newPayDay = settings.payday;
    final newExpense = settings.baseAmount;
    if (mounted && (_payDay != newPayDay || _livingExpense != newExpense)) {
      setState(() {
        _livingSettings = settings;
        _payDay = newPayDay;
        _livingExpense = newExpense;
      });
    } else {
      _livingSettings = settings;
    }
  }

  Future<void> _refreshLivingSummary(List<Record> records) async {
    if (_livingSettings.baseAmount <= 0) return;
    final preferences = await SharedPreferences.getInstance();
    final repository = LivingAllowanceRepository(preferences);
    final summary = LivingAllowanceSummary.calculate(
      settings: _livingSettings,
      records: records,
      includedIncomeIds: repository.includedIncomeIds(),
      confirmedNoSpendDates: repository.confirmedNoSpendDates(),
      now: DateTime.now(),
    );
    if (mounted) setState(() => _livingSummary = summary);
    _livingAlerts ??= LivingAlertDelivery(
      repository: repository,
      isAllowed: NotificationService.isPermissionGranted,
      send: (threshold, remaining) =>
          NotificationService.showLivingAllowanceAlert(
            threshold: threshold,
            remaining: remaining,
          ),
    );
    try {
      final settings = NotificationPreferencesRepository(preferences).load();
      final threshold = await _livingAlerts!.evaluate(
        period: summary.period.key,
        spentRatio: summary.spentRatio,
        remaining: summary.remaining,
        completeness: summary.completeness,
        enabled: settings.livingEnabled,
      );
      if (threshold != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              threshold >= 100
                  ? '本期生活费已经用完'
                  : '本期生活费已使用 $threshold%，还剩 ¥${summary.remaining.toStringAsFixed(2)}',
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint('Living allowance alert failed: ${error.runtimeType}');
    }
    await _rollOverPreviousPeriod(repository);
  }

  Future<void> _rollOverPreviousPeriod(
    LivingAllowanceRepository repository,
  ) async {
    if (!_livingSettings.autoSaveRemainder) return;
    final previous = LivingAllowancePeriod.forDate(
      DateTime.now(),
      _livingSettings.payday,
    ).previous();
    final current = LivingAllowancePeriod.forDate(
      DateTime.now(),
      _livingSettings.payday,
    );
    if (repository.startedPeriodKey == null ||
        repository.startedPeriodKey == current.key) {
      return;
    }
    if (repository.wasRolledOver(previous.key)) return;
    final months = <String>{_monthKey(previous.start), _monthKey(previous.end)};
    final results = await Future.wait(
      months.map((month) => RecordApi.getRecords(month: month)),
    );
    final records = results
        .where((result) => result.isSuccess)
        .expand((result) => result.data ?? <Record>[])
        .toList();
    final summary = LivingAllowanceSummary.calculate(
      settings: _livingSettings,
      records: records,
      includedIncomeIds: repository.includedIncomeIds(),
      confirmedNoSpendDates: repository.confirmedNoSpendDates(),
      now: previous.end,
      period: previous,
    );
    if (records.isEmpty || summary.completeness < .7 || summary.remaining <= 0)
      return;
    var goalId = repository.savingsGoalId;
    if (goalId == null) {
      final goals = await SavingsApi.getGoals();
      Map? existing;
      for (final goal in goals.whereType<Map>()) {
        if (goal['name'] == '生活费结余') {
          existing = goal;
          break;
        }
      }
      final goal =
          existing ??
          await SavingsApi.createGoal(
            '生活费结余',
            (summary.remaining * 12).clamp(10000, 1000000),
          );
      goalId = (goal?['id'] as num?)?.toInt();
      if (goalId != null) await repository.setSavingsGoalId(goalId);
    }
    if (goalId == null) return;
    final deposited = await SavingsApi.deposit(
      goalId,
      summary.remaining,
      note: '${previous.key} 生活费结余',
    );
    if (deposited == null) return;
    await repository.markRolledOver(previous.key);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '上期留下 ¥${summary.remaining.toStringAsFixed(2)}，已计入生活费结余',
          ),
        ),
      );
  }

  static String _monthKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}';

  Future<void> _loadWalletData() async {
    try {
      final r = await CategoryApi.getCategories();
      if (!r.isSuccess || r.data == null) return;
      final ec = r.data!
          .where((c) => c.type == 'expense')
          .expand((c) => c.leafCategories)
          .toList();
      final p = await SharedPreferences.getInstance();
      final budgets = <int, double>{},
          active = p.getStringList('active_wallets') ?? [];
      for (final c in ec) {
        final b = p.getDouble('wallet_budget_${c.id}') ?? 0;
        if (b > 0) budgets[c.id] = b;
      }
      List<Category> shown;
      if (active.isEmpty && budgets.isEmpty) {
        shown = [];
      } else if (active.isNotEmpty) {
        shown = ec.where((c) => active.contains(c.id.toString())).toList();
      } else {
        shown = ec.where((c) => budgets.containsKey(c.id)).toList();
      }
      for (final c in ec) {
        if (budgets.containsKey(c.id) && !active.contains(c.id.toString()))
          active.add(c.id.toString());
      }
      await p.setStringList('active_wallets', active);
      if (mounted) {
        setState(() {
          _walletCategories = shown;
        });
      }
    } catch (_) {
      /* ignore */
    }
  }

  Future<void> _reload() async {
    await _load();
  }

  Future<void> _editSubtitle() async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          HomeSubtitleDialog(initialValue: _subtitle, onSave: _saveSubtitle),
    );
  }

  Future<bool> _saveSubtitle(String value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final repository = HomeSubtitleRepository(preferences);
      final saved = await repository.save(value);
      if (saved && mounted) setState(() => _subtitle = repository.load());
      return saved;
    } catch (_) {
      return false;
    }
  }

  void _openAdd() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddRecordSheet(onSaved: _reload),
    );
  }

  Future<void> _openVoice() async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VoicePage()),
    );
    if (mounted) await _reload();
  }

  Future<void> _openOCR() async {
    HapticFeedback.mediumImpact();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.all(24),
        child: PremiumCard(
          padding: EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.ink),
                title: Text('拍照识别'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.ink),
                title: Text('从相册选择'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (xFile == null) return;

    _showOcrLoading();
    try {
      final bytes = await xFile.readAsBytes();
      if (bytes.length > 4 * 1024 * 1024) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('图片过大，请选择小于4MB的图片')));
        }
        return;
      }
      final base64 = base64Encode(bytes);
      final res = await ApiClient().post(
        '/ai/ocr',
        data: {'image_base64': base64},
        options: Options(contentType: 'application/json'),
      );
      if (mounted) Navigator.pop(context);
      if (res.data['code'] == 0 && res.data['data'] != null) {
        final d = res.data['data'];
        if (d is List && d.isNotEmpty) {
          _openOcrConfirmation(d.cast<Map<String, dynamic>>());
        } else if (d is Map) {
          _openOcrConfirmation([d.cast<String, dynamic>()]);
        } else {
          _showOcrResult(d);
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? '未识别到消费信息，请尝试手动输入')),
          );
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('网络错误，请重试')));
      }
    }
  }

  Future<void> _openOcrConfirmation(List<Map<String, dynamic>> rawItems) async {
    final categoryResponse = await CategoryApi.getCategories();
    if (!mounted ||
        !categoryResponse.isSuccess ||
        categoryResponse.data == null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('分类加载失败，请稍后重试')));
      return;
    }
    final items = <OcrEditableItem>[];
    for (var index = 0; index < rawItems.length; index++) {
      final raw = rawItems[index];
      final amount = double.tryParse('${raw['amount'] ?? 0}') ?? 0;
      if (amount <= 0) continue;
      final fallbackDate = DateTime.now().toIso8601String().split('T')[0];
      final parsedDate = DateTime.tryParse('${raw['date'] ?? ''}');
      items.add(
        OcrEditableItem(
          clientId: 'ocr-$index-${DateTime.now().microsecondsSinceEpoch}',
          amount: amount,
          merchant: '${raw['merchant'] ?? ''}',
          date: parsedDate?.toIso8601String().split('T')[0] ?? fallbackDate,
          note: '${raw['note'] ?? ''}',
          categoryId: raw['category_id'] is int
              ? raw['category_id'] as int
              : null,
        ),
      );
    }
    if (items.isEmpty) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OcrResultPage(
          controller: OcrResultController(items),
          categories: categoryResponse.data!
              .where((category) => category.type == 'expense')
              .toList(),
          onSave: (rows) async {
            final results = <OcrItemSaveResult>[];
            for (final row in rows) {
              try {
                final result = await RecordApi.addRecord(
                  type: 'expense',
                  amount: row.amount,
                  categoryId: row.categoryId!,
                  date: row.date,
                  note: row.note.isNotEmpty
                      ? row.note
                      : (row.merchant.isEmpty ? null : row.merchant),
                  requestId: row.clientId,
                );
                results.add(
                  OcrItemSaveResult(
                    clientId: row.clientId,
                    saved: result.isSuccess,
                    message: result.isSuccess ? null : result.message,
                  ),
                );
                if (result.isSuccess && row.merchant.isNotEmpty) {
                  try {
                    await ApiClient().post(
                      '/ai/ocr/confirm',
                      data: {
                        'merchant': row.merchant,
                        'category_id': row.categoryId,
                      },
                    );
                  } catch (_) {
                    // Learning is optional and must not undo a saved record.
                  }
                }
              } catch (_) {
                results.add(
                  OcrItemSaveResult(
                    clientId: row.clientId,
                    saved: false,
                    message: '网络中断，请重试',
                  ),
                );
              }
            }
            return OcrBatchSaveResult(results);
          },
        ),
      ),
    );
    if (saved == true) _reload();
  }

  void _showOcrLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: PremiumCard(
          padding: EdgeInsets.all(32),
          radius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'AI 正在分析截图',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '请稍候，约30秒',
                style: TextStyle(fontSize: 12, color: AppColors.gray),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOcrResult(dynamic data) {
    final type = data['type'] ?? 'expense';
    final amount = double.tryParse((data['amount'] ?? '0').toString()) ?? 0;
    final category = data['category'] ?? '未知';
    final note = data['note'] ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.all(24),
        child: PremiumCard(
          padding: EdgeInsets.all(24),
          radius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.document_scanner_rounded,
                size: 48,
                color: AppColors.gold,
              ),
              SizedBox(height: 16),
              Text(
                '识别结果',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 20),
              _ocrRow('类型', type == 'income' ? '收入' : '支出'),
              _ocrRow('金额', '¥${amount.toStringAsFixed(2)}'),
              _ocrRow('分类', category.toString()),
              if (note.toString().isNotEmpty) _ocrRow('备注', note.toString()),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        await Future.delayed(Duration(milliseconds: 150));
                        _openAdd();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: BorderSide(color: AppColors.gray.withAlpha(80)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: Size(double.infinity, 48),
                      ),
                      child: Text('手动修改'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        try {
                          final catId = data['category_id'] ?? 1;
                          final r = await RecordApi.addRecord(
                            type: type,
                            amount: amount,
                            categoryId: catId is int ? catId : 1,
                            date: DateTime.now().toIso8601String().split(
                              'T',
                            )[0],
                            note: note.toString().isNotEmpty
                                ? note.toString()
                                : null,
                          );
                          if (r.isSuccess) {
                            _reload();
                            if (mounted)
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('已保存')));
                          }
                        } catch (_) {
                          if (mounted)
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('保存失败')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: Size(double.infinity, 48),
                      ),
                      child: Text('确认保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ocrRow(String label, String value) {
    final display = value?.isNotEmpty == true ? value : '未识别';
    final color = value?.isNotEmpty == true ? AppColors.ink : AppColors.gray;
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: AppColors.gray),
            ),
          ),
          Expanded(
            child: Text(
              display,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openWeeklyReport() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WeeklyReportPage()),
    );
  }

  void _editLiving() async {
    final p = await SharedPreferences.getInstance();
    final repository = LivingAllowanceRepository(p);
    if (!_livingSettings.setupComplete &&
        !await showLivingAllowancePrimer(context))
      return;
    if (!mounted) return;
    final value = await showLivingAllowanceSetup(
      context,
      initial: _livingSettings,
    );
    if (value == null) return;
    await repository.saveSettings(value);
    if (!mounted) return;
    setState(() {
      _livingSettings = value;
      _livingExpense = value.baseAmount;
      _payDay = value.payday;
    });
    await _reload();
  }

  Future<void> _confirmNoSpendToday() async {
    final preferences = await SharedPreferences.getInstance();
    await LivingAllowanceRepository(
      preferences,
    ).confirmNoSpendDate(DateTime.now());
    await _reload();
  }

  // ============================================================
  // BUILD — Phase 6 新布局
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return AppThemeBuilder(
      builder: (_, _) {
        if (_loading) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          );
        }

        return PremiumBackground(
          child: RefreshIndicator(
            onRefresh: _reload,
            color: AppColors.highlight,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                100,
              ),
              children: [
                _header(),
                SizedBox(height: AppSpacing.md),
                _heroCard(),
                SizedBox(height: AppSpacing.lg),
                _quickActions(),
                SizedBox(height: AppSpacing.lg),
                _weeklyBar(),
                SizedBox(height: AppSpacing.md),
                _livingCard(),
                SizedBox(height: AppSpacing.md),
                _walletEntry(),
                SizedBox(height: AppSpacing.lg),
                _recordSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header() {
    return HomeHeader(
      subtitle: _subtitle,
      onEditSubtitle: _editSubtitle,
      onOpenSettings: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
      },
    );
  }

  Widget _heroCard() {
    final changePct = _prevExp > 0
        ? ((_exp - _prevExp) / _prevExp * 100).round()
        : null;
    final isUp = changePct != null && changePct > 0;
    final changeLabel = changePct != null ? '${changePct.abs()}%' : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(AppColors.isDark ? 50 : 32),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本月支出',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      '留有余量，才有从容。',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withAlpha(220),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const UnfinishedRingMark(
                size: 62,
                animate: true,
                ringColor: Color(0xFFF5F4EE),
                markerColor: Color(0xFFD56F54),
                trackColor: Color(0x335F8C7D),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            '¥${_exp.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.2,
              height: 1.05,
            ),
          ),
          SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withAlpha(35)),
          SizedBox(height: 12),
          Row(
            children: [
              Text(
                '今日 ¥${_todayExp.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(180),
                ),
              ),
              const Spacer(),
              if (changeLabel != null) ...[
                Icon(
                  isUp
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 15,
                  color: isUp
                      ? const Color(0xFFF2A184)
                      : const Color(0xFFA9D2A4),
                ),
                SizedBox(width: 4),
                Text(
                  '比上月 $changeLabel',
                  style: TextStyle(
                    fontSize: 12,
                    color: isUp
                        ? const Color(0xFFF2A184)
                        : const Color(0xFFA9D2A4),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _actionBtn(Icons.edit_rounded, '记一笔', _openAdd),
        _actionBtn(Icons.camera_alt_rounded, '截图', _openOCR),
        _actionBtn(Icons.auto_awesome_rounded, 'AI 记账', _openVoice),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: PressScale(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.accent, size: 22),
                SizedBox(height: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.ink2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _weeklyBar() {
    return PremiumCard(
      onTap: _openWeeklyReport,
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.premiumLight, AppColors.premiumDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              '省钱周报',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          HeroAmount(
            amount: _exp,
            prefix: '¥',
            size: 18,
            color: AppColors.ink2,
          ),
          SizedBox(width: 8),
          Icon(Icons.chevron_right, color: AppColors.gray, size: 20),
        ],
      ),
    );
  }

  Widget _walletEntry() {
    void goToWalletPage() {
      HapticFeedback.lightImpact();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WalletPage()),
      ).then((_) => _loadWalletData());
    }

    return PremiumCard(
      onTap: goToWalletPage,
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.premium.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.premiumDark,
              size: 20,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              '我的钱包',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          if (_walletCategories.isNotEmpty)
            Text(
              '${_walletCategories.length} 个钱包',
              style: TextStyle(fontSize: 14, color: AppColors.gray),
            ),
          SizedBox(width: 8),
          Icon(Icons.chevron_right, color: AppColors.gray, size: 20),
        ],
      ),
    );
  }

  Widget _livingCard() {
    if (_livingExpense <= 0) {
      return PremiumCard(
        gradient: AppColors.cardSageTint,
        shadows: [
          BoxShadow(
            color: AppColors.sage.withAlpha(30),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        onTap: _editLiving,
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.sage.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.credit_card_rounded,
                  color: AppColors.sage,
                  size: 20,
                ),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                '设置我的生活费',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            Icon(Icons.add_circle_outline, color: AppColors.sage),
          ],
        ),
      );
    }
    final now = DateTime.now();
    final summary = _livingSummary;
    final remaining = summary?.remaining ?? _livingExpense;
    final pct = (summary?.spentRatio ?? 0).clamp(0.0, 1.0);
    final remainingColor = remaining > 0 ? AppColors.sage : AppColors.danger;
    return PremiumCard(
      gradient: AppColors.cardSageTint,
      shadows: [
        BoxShadow(
          color: AppColors.sage.withAlpha(30),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
      onTap: _editLiving,
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.sage, AppColors.sageLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.credit_card_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '我的生活费',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '每月$_payDay号到账 · ${summary?.paceLabel ?? '等待账单数据'}',
                      style: TextStyle(fontSize: 12, color: AppColors.gray),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.gray),
            ],
          ),
          SizedBox(height: 16),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.sage.withAlpha(30),
              valueColor: AlwaysStoppedAnimation(
                remaining > 0 ? AppColors.sage : AppColors.danger,
              ),
              minHeight: 6,
            ),
          ),
          SizedBox(height: 12),
          // 还能花多少
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已花费',
                    style: TextStyle(fontSize: 12, color: AppColors.gray),
                  ),
                  Text(
                    '¥${(summary?.spent ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '总额',
                    style: TextStyle(fontSize: 12, color: AppColors.gray),
                  ),
                  Text(
                    '¥${(summary?.available ?? _livingExpense).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '剩余',
                    style: TextStyle(fontSize: 12, color: AppColors.gray),
                  ),
                  Text(
                    '¥${remaining.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: remainingColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (summary != null) ...[
            const SizedBox(height: 12),
            Text(
              '日均还能使用 ¥${summary.dailyAvailable.toStringAsFixed(2)} · 数据完整度 ${(summary.completeness * 100).round()}%',
              style: TextStyle(fontSize: 12, color: AppColors.gray),
            ),
            if (!_records.any(
              (record) =>
                  record.date ==
                  _monthKey(now) + '-${now.day.toString().padLeft(2, '0')}',
            ))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _confirmNoSpendToday,
                  child: const Text('确认今日无支出'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _recordSection() {
    if (_records.isEmpty) {
      return PremiumCard(
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 44,
                color: AppColors.accent.withAlpha(100),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                '还没有记录哦',
                style: TextStyle(fontSize: 14, color: AppColors.gray),
              ),
              SizedBox(height: AppSpacing.md),
              GestureDetector(
                onTap: _openAdd,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withAlpha(35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '记一笔',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.goldDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final items = _records.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '最近流水',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecordsListPage()),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              child: const Text('查看全部'),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: StaggeredList(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final r = items[i];
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color:
                                (r.isIncome
                                        ? AppColors.success
                                        : AppColors.accent)
                                    .withAlpha(18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            r.isIncome
                                ? Icons.south_west_rounded
                                : Icons.north_east_rounded,
                            size: 19,
                            color: r.isIncome
                                ? AppColors.success
                                : AppColors.accent,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.categoryName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              if (r.note != null && r.note!.isNotEmpty)
                                Text(
                                  r.note!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gray,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        HeroAmount(
                          amount: r.amount,
                          prefix: r.isIncome ? '+' : '-',
                          size: 18,
                          color: r.isIncome ? AppColors.sage : AppColors.danger,
                        ),
                      ],
                    ),
                  ),
                  if (i < items.length - 1) Divider(indent: 56),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
