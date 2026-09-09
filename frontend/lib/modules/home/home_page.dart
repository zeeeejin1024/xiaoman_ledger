import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/core/notification_coordinator.dart';
import 'package:xiaojia_ledger/modules/record/add_record_sheet.dart';
import 'package:xiaojia_ledger/modules/record/records_list_page.dart';
import 'package:xiaojia_ledger/modules/stats/stats_page.dart';
import 'package:xiaojia_ledger/modules/savings/savings_page.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _DashTab(),
      const StatsPage(),
      const SavingsPage(),
      const WalletPage(),
      const RecordsListPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
          child: pages[_tab],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.navBg,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: NavigationBar(
            height: 70,
            selectedIndex: _tab,
            onDestinationSelected: (i) {
              HapticFeedback.lightImpact();
              setState(() => _tab = i);
            },
            backgroundColor: AppColors.navBg,
            indicatorColor: AppColors.accent.withAlpha(18),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
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
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: '钱包',
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
            ],
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
  String _appTitle = AppConstants.appName;
  List<Category> _walletCategories = [];
  int _payDay = 0;
  double _livingExpense = 0;

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
        _loadTitle(),
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
      // 检查通知点击的自动打开标记
      _checkAutoOpenAdd();
      NotificationCoordinator.shared().then(
        (coordinator) => coordinator.reconcileAll(),
      );
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

  Future<void> _loadTitle() async {
    final p = await SharedPreferences.getInstance();
    final newTitle = p.getString('app_title') ?? AppConstants.appName;
    if (mounted && _appTitle != newTitle) setState(() => _appTitle = newTitle);
  }

  Future<void> _loadLiving() async {
    final p = await SharedPreferences.getInstance();
    final newPayDay = p.getInt('pay_day') ?? 0;
    final newExpense = p.getDouble('living_expense') ?? 0;
    if (mounted && (_payDay != newPayDay || _livingExpense != newExpense)) {
      setState(() {
        _payDay = newPayDay;
        _livingExpense = newExpense;
      });
    }
  }

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

  void _editTitle() {
    final c = TextEditingController(text: _appTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改名称'),
        content: TextField(
          controller: c,
          decoration: InputDecoration(hintText: '给你的账本取个名字'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (c.text.trim().isNotEmpty) {
                final p = await SharedPreferences.getInstance();
                await p.setString('app_title', c.text.trim());
                setState(() => _appTitle = c.text.trim());
              }
            },
            child: Text('保存'),
          ),
        ],
      ),
    );
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

  void _openVoice() {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => VoicePage()));
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
          _showOcrBatchResult(d.cast<Map<String, dynamic>>());
        } else if (d is Map) {
          _showOcrBatchResult([d.cast<String, dynamic>()]);
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

  void _showFabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.all(24),
        child: PremiumCard(
          padding: EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _opt(Icons.edit_rounded, '手动记账', _openAdd),
              Divider(height: 1),
              _opt(Icons.mic_rounded, '语音记账', _openVoice),
              Divider(height: 1),
              _opt(Icons.camera_alt_rounded, '截图记账', _openOCR),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opt(IconData icon, String t, VoidCallback f) => ListTile(
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: AppColors.accentDark),
    ),
    title: Text(
      t,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    trailing: Icon(Icons.chevron_right, color: AppColors.gray),
    onTap: () {
      Navigator.pop(context);
      f();
    },
    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  void _showOcrBatchResult(List<Map<String, dynamic>> items) {
    final results = items
        .where((item) => (item['amount'] ?? 0).toString() != '0')
        .toList();
    if (results.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('未识别到有效消费信息')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // 拖拽条
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: EdgeInsets.only(top: 12),
                ),
                // 标题
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '识别到 ${results.length} 笔记录',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setInner(() {
                          results.add({
                            'type': 'expense',
                            'amount': 0,
                            'category': '',
                            'merchant': '',
                            'date': DateTime.now().toIso8601String().split(
                              'T',
                            )[0],
                            'note': '',
                          });
                        }),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add,
                              size: 18,
                              color: AppColors.highlight,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '添加',
                              style: TextStyle(
                                color: AppColors.highlight,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 分隔线
                Divider(height: 1, color: AppColors.divider),
                // 可编辑列表
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return _ocrEditableItem(
                        item: item,
                        index: index,
                        onDelete: () => setInner(() => results.removeAt(index)),
                        onChanged: () => setInner(() {}),
                      );
                    },
                  ),
                ),
                // 底部保存按钮
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        // 预加载一次分类列表
                        final catRes = await CategoryApi.getCategories();
                        final allLeaves = <String, int>{};
                        if (catRes.isSuccess && catRes.data != null) {
                          for (final cat in catRes.data!) {
                            for (final leaf in cat.leafCategories) {
                              allLeaves[leaf.name] = leaf.id;
                            }
                          }
                        }
                        int saved = 0;
                        for (final item in results) {
                          try {
                            final t = item['type'] ?? 'expense';
                            final a =
                                double.tryParse(
                                  (item['amount'] ?? '0').toString(),
                                ) ??
                                0;
                            if (a <= 0) continue;
                            int cid = (item['category_id'] is int)
                                ? item['category_id']
                                : 0;
                            if (cid <= 0 && item['category'] != null) {
                              cid = allLeaves[item['category'].toString()] ?? 1;
                            }
                            await RecordApi.addRecord(
                              type: t,
                              amount: a,
                              categoryId: cid,
                              date:
                                  item['date']?.toString() ??
                                  DateTime.now().toIso8601String().split(
                                    'T',
                                  )[0],
                              note:
                                  (item['note']?.toString().isNotEmpty == true)
                                  ? item['note'].toString()
                                  : null,
                            );
                            saved++;
                          } catch (_) {}
                        }
                        _reload();
                        Navigator.pop(context);
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已保存 $saved 笔记录')),
                          );
                      },
                      icon: Icon(Icons.save, size: 20),
                      label: Text(
                        '全部保存',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.highlight,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ocrEditableItem({
    required Map<String, dynamic> item,
    required int index,
    required VoidCallback onDelete,
    required VoidCallback onChanged,
  }) {
    final amountCtrl = TextEditingController(
      text: item['amount']?.toString() ?? '',
    );
    final merchantCtrl = TextEditingController(
      text: item['merchant']?.toString() ?? '',
    );
    final noteCtrl = TextEditingController(
      text: item['note']?.toString() ?? '',
    );
    // 日期：空值时显示"未识别"，用户手动填写
    final dateValue = item['date']?.toString();
    final dateCtrl = TextEditingController(
      text: dateValue?.isNotEmpty == true ? dateValue : '',
    );
    final hasDate = dateValue?.isNotEmpty == true;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: AppColors.ink.withAlpha(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行：序号 + 金额 + 删除按钮
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.highlight.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.highlight,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '¥${item['amount']?.toString() ?? '0'}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                    size: 22,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
            SizedBox(height: 12),
            // 金额
            _buildFieldRow('金额', amountCtrl, TextInputType.number, (v) {
              item['amount'] = double.tryParse(v) ?? 0;
              onChanged();
            }),
            SizedBox(height: 8),
            // 商家
            _buildFieldRow('商家', merchantCtrl, TextInputType.text, (v) {
              item['merchant'] = v;
              onChanged();
            }),
            SizedBox(height: 8),
            // 备注
            _buildFieldRow('备注', noteCtrl, TextInputType.text, (v) {
              item['note'] = v;
              onChanged();
            }),
            SizedBox(height: 8),
            // 日期
            _buildFieldRow('日期', dateCtrl, TextInputType.datetime, (v) {
              item['date'] = v;
              onChanged();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(
    String label,
    TextEditingController ctrl,
    TextInputType type,
    Function(String) onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.gray),
          ),
        ),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: type,
            style: TextStyle(fontSize: 14, color: AppColors.ink),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              filled: true,
              fillColor: AppColors.cardAlt,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _editLiving() async {
    final p = await SharedPreferences.getInstance();
    final dc = TextEditingController(
      text: _payDay > 0 ? _payDay.toString() : '',
    );
    final ac = TextEditingController(
      text: _livingExpense > 0 ? _livingExpense.toStringAsFixed(2) : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('我的生活费'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ac,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '每月生活费金额'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: dc,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '每月几号到账'),
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
            child: Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final a = double.tryParse(ac.text) ?? 0;
      final d = int.tryParse(dc.text) ?? 0;
      await p.setDouble('living_expense', a);
      await p.setInt('pay_day', d);
      setState(() {
        _livingExpense = a;
        _payDay = d;
      });
    }
  }

  // ============================================================
  // BUILD — Phase 6 新布局
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_loading)
      return Center(child: CircularProgressIndicator(color: AppColors.gold));

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
            SizedBox(height: AppSpacing.xl),
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
  }

  Widget _header() {
    return Row(
      children: [
        const UnfinishedRingMark(
          size: 38,
          animate: true,
          ringColor: Color(0xFF173E37),
          markerColor: Color(0xFFD56F54),
          trackColor: Color(0x24173E37),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: GestureDetector(
            onTap: _editTitle,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _appTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '今天也留一点余地',
                  style: TextStyle(fontSize: 12, color: AppColors.gray),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.settings_outlined, size: 24, color: AppColors.ink),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
        ),
      ],
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
    int dl;
    if (_payDay > now.day) {
      dl = _payDay - now.day;
    } else {
      final dim = DateTime(now.year, now.month + 1, 0).day;
      dl = dim - now.day + _payDay;
    }
    // 计算还能花多少：总额 - 本月已支出
    final remaining = _livingExpense - _exp;
    final pct = _livingExpense > 0
        ? (_exp / _livingExpense).clamp(0.0, 1.0)
        : 0.0;
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
                      '每月$_payDay号 · 距到账 $dl 天',
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
                    '¥${_exp.toStringAsFixed(2)}',
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
                    '¥${_livingExpense.toStringAsFixed(2)}',
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
