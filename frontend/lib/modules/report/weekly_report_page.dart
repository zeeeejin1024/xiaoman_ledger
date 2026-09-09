import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/data/api/stats_api.dart';
import 'package:xiaojia_ledger/widgets/unfinished_ring_mark.dart';

class WeeklyReportPage extends StatefulWidget {
  const WeeklyReportPage({super.key});
  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startStr =
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    final endStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      _data = await StatsApi.getWeekly(startStr, endStr);
    } catch (_) {
      _data = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dateRange = '${monday.month}/${monday.day} — ${now.month}/${now.day}';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('省钱周报'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.amber))
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
                // 日期范围
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AppColors.gray,
                    ),
                    SizedBox(width: 8),
                    Text(
                      dateRange,
                      style: TextStyle(fontSize: 14, color: AppColors.gray),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // 概览
                GlassCard(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        padding: EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: UnfinishedRingMark(
                          size: 42,
                          animate: true,
                          ringColor: Colors.white,
                          markerColor: AppColors.highlight,
                          trackColor: Colors.white.withAlpha(40),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '本周省钱报告',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _summary,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.inkSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // 支出概览
                GlassCard(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '支出概览',
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
                          _statItem(
                            '本周支出',
                            _data != null
                                ? '¥${(_data!['total_expense'] as num?)?.toStringAsFixed(2) ?? '0'}'
                                : '—',
                            AppColors.coralRed,
                          ),
                          _statItem(
                            '本周收入',
                            _data != null
                                ? '¥${(_data!['total_income'] as num?)?.toStringAsFixed(2) ?? '0'}'
                                : '—',
                            AppColors.sage,
                          ),
                          _statItem(
                            '日均支出',
                            _data != null
                                ? '¥${(((_data!['total_expense'] as num?)?.toDouble() ?? 0) / 7).toStringAsFixed(2)}'
                                : '—',
                            AppColors.amber,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // 每日支出
                if (_data != null &&
                    _data!['daily'] != null &&
                    (_data!['daily'] as List).isNotEmpty)
                  PremiumCard(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '每日支出',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 16),
                        ...(_data!['daily'] as List).map((d) {
                          final dayData = d as Map<String, dynamic>;
                          final expense =
                              (dayData['expense'] as num?)?.toDouble() ?? 0;
                          final maxExpense = _data!['total_expense'] > 0
                              ? (_data!['total_expense'] as num).toDouble()
                              : 1.0;
                          final pct = maxExpense > 0
                              ? expense / maxExpense
                              : 0.0;
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    dayData['date'].toString().substring(5),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gray,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      backgroundColor: AppColors.coralRed
                                          .withAlpha(20),
                                      valueColor: AlwaysStoppedAnimation(
                                        AppColors.coralRed,
                                      ),
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  '¥${expense.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
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

                // 省钱建议
                PremiumCard(
                  padding: EdgeInsets.all(20),
                  gradient: AppColors.cardSageTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.sage.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.lightbulb_outline_rounded,
                                color: AppColors.sage,
                                size: 16,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            '省钱小建议',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      if (_data != null && _data!['suggestions'] != null)
                        ...(_data!['suggestions'] as List).map(
                          (s) => Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: EdgeInsets.only(top: 6, right: 10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.sage,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    s.toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.inkSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          '记账越规律，省钱建议越精准哦～',
                          style: TextStyle(fontSize: 14, color: AppColors.gray),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String get _summary {
    if (_data == null) return '本周暂无数据，快去记一笔吧～';
    final exp = (_data!['total_expense'] as num?)?.toDouble() ?? 0;
    final lastExp = (_data!['last_week_expense'] as num?)?.toDouble() ?? 0;
    if (lastExp > 0) {
      final diff = exp - lastExp;
      if (diff < 0) return '本周比上周少花了 ¥${diff.abs().toStringAsFixed(2)}，继续保持！🎉';
      if (diff > 0) return '本周比上周多花了 ¥${diff.toStringAsFixed(2)}，注意控制哦～';
    }
    return '本周总支出 ¥${exp.toStringAsFixed(2)}';
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
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
