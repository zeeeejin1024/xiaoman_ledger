import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/data/api/stats_api.dart';
import 'package:xiaojia_ledger/modules/report/report_view_data.dart';

class MonthlyReportPage extends StatefulWidget {
  final DateTime? month; // null = 上月
  const MonthlyReportPage({super.key, this.month});
  @override
  State<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends State<MonthlyReportPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m =
        widget.month ?? DateTime(DateTime.now().year, DateTime.now().month - 1);
    final mStr = '${m.year}-${m.month.toString().padLeft(2, '0')}';
    try {
      _data = await StatsApi.getMonthly(mStr);
    } catch (_) {
      _data = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) =>
      AppThemedPage(builder: (context, _) => _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final m =
        widget.month ?? DateTime(DateTime.now().year, DateTime.now().month - 1);
    final monthLabel = DateFormat('yyyy年M月').format(m);
    final inc = (_data?['income'] as num?)?.toDouble() ?? 0;
    final exp = (_data?['expense'] as num?)?.toDouble() ?? 0;
    final bal = (_data?['balance'] as num?)?.toDouble() ?? 0;
    final cats = (_data?['expense_cats'] as Map<String, dynamic>?) ?? {};
    final sortedCats = cats.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('$monthLabel 月度报告'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.amber))
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
                // 总体评分
                GlassCard(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.amber, AppColors.coral],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.amber.withAlpha(40),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _gradeIcon,
                            size: 34,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '$monthLabel理财报告',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '结余 ¥${bal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // 收支总览
                GlassCard(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '收支总览',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _stat('总收入', inc, AppColors.sage),
                          _stat('总支出', exp, AppColors.coralRed),
                          _stat('结余', bal, AppColors.amber),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // 分类排行
                if (sortedCats.isNotEmpty)
                  GlassCard(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '支出排行',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 16),
                        ...sortedCats.take(6).toList().asMap().entries.map((e) {
                          final i = e.key;
                          final v = (e.value.value as num).toDouble();
                          final pct = exp > 0
                              ? (v / exp * 100).toStringAsFixed(0)
                              : '0';
                          return Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors
                                        .chartPalette[i %
                                            AppColors.chartPalette.length]
                                        .withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          AppColors.chartPalette[i %
                                              AppColors.chartPalette.length],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    e.value.key,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  '¥${v.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.ink,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '$pct%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gray,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                SizedBox(height: 20),

                // 建议
                PremiumCard(
                  padding: EdgeInsets.all(20),
                  gradient: AppColors.cardAccentGradient,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.mistBlue.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                color: AppColors.mistBlue,
                                size: 16,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            '理财建议',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      ...reportRecommendationMessages(_data).map(
                        (message) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            message,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.inkSecondary,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),
              ],
            ),
    );
  }

  IconData get _gradeIcon {
    final bal = (_data?['balance'] as num?)?.toDouble() ?? 0;
    final exp = (_data?['expense'] as num?)?.toDouble() ?? 0;
    final inc = (_data?['income'] as num?)?.toDouble() ?? 0;
    if (inc == 0 && exp == 0) return Icons.hourglass_empty_rounded;
    if (bal > inc * 0.3) return Icons.verified_rounded;
    if (bal > 0) return Icons.trending_up_rounded;
    if (bal > -inc * 0.2) return Icons.tune_rounded;
    return Icons.warning_amber_rounded;
  }

  Widget _stat(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          '¥${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.gray)),
      ],
    );
  }
}
