import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/data/api/stats_api.dart';
import 'package:xiaojia_ledger/modules/stats/chart_scale.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTime _curMonth = DateTime.now();
  int _curYear = DateTime.now().year;
  Map<String, dynamic>? _md, _yd;
  bool _loading = true;
  bool _showExpense = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await Future.wait([
      StatsApi.getMonthly(
        '${_curMonth.year}-${_curMonth.month.toString().padLeft(2, '0')}',
      ),
      StatsApi.getYearly(_curYear.toString()),
    ]);
    if (mounted) {
      _md = r[0];
      _yd = r[1];
      _loading = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) =>
      AppThemedPage(builder: (context, _) => _buildPage(context));

  Widget _buildPage(BuildContext context) {
    if (_loading)
      return Center(child: CircularProgressIndicator(color: AppColors.amber));
    return SafeArea(
      child: Column(
        children: [
          _tabs(),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 200),
              child: _tab == 0 ? _monthly() : _yearly(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(child: _tb('本月', 0)),
          SizedBox(width: 8),
          Expanded(child: _tb('年度', 1)),
        ],
      ),
    );
  }

  Widget _tb(String t, int i) {
    final on = _tab == i;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _tab = i);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.accent.withAlpha(20) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: on ? Border.all(color: AppColors.accent.withAlpha(60)) : null,
        ),
        child: Text(
          t,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: on ? AppColors.accentDark : AppColors.gray,
          ),
        ),
      ),
    );
  }

  // ==================== 月度 ====================
  Widget _monthly() {
    final d = _md;
    if (d == null) return _empty();
    final inc = (d['income'] as num?)?.toDouble() ?? 0;
    final exp = (d['expense'] as num?)?.toDouble() ?? 0;
    final bal = (d['balance'] as num?)?.toDouble() ?? 0;
    final ec = (d['expense_cats'] as Map<String, dynamic>?) ?? {};
    final ic = (d['income_cats'] as Map<String, dynamic>?) ?? {};
    final emojis = (d['cat_emojis'] as Map<String, dynamic>?) ?? {};
    final cats = _showExpense ? ec : ic;
    final total = _showExpense ? exp : inc;
    final sorted = cats.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value));

    final now = DateTime.now();
    final canFwd =
        _curMonth.year < now.year ||
        (_curMonth.year == now.year && _curMonth.month < now.month);

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        // 月份切换
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _arrow(Icons.chevron_left, () {
              _curMonth = DateTime(_curMonth.year, _curMonth.month - 1);
              _load();
            }),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                DateFormat('yyyy年M月').format(_curMonth),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            _arrow(
              Icons.chevron_right,
              canFwd
                  ? () {
                      _curMonth = DateTime(_curMonth.year, _curMonth.month + 1);
                      _load();
                    }
                  : null,
              dimmed: !canFwd,
            ),
          ],
        ),
        SizedBox(height: 24),

        // Hero 总金额
        Center(
          child: Column(
            children: [
              Text(
                '¥${_fmtNum(total)}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                _showExpense ? '总支出' : '总收入',
                style: TextStyle(fontSize: 14, color: AppColors.gray),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),

        // 收支小计
        Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniStat('收入', inc, AppColors.success),
              _miniStat('支出', exp, AppColors.danger),
              _miniStat('结余', bal, AppColors.amber),
            ],
          ),
        ),
        SizedBox(height: 20),

        // 收支切换
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _chip(
              '支出',
              _showExpense,
              () => setState(() => _showExpense = true),
            ),
            SizedBox(width: 8),
            _chip(
              '收入',
              !_showExpense,
              () => setState(() => _showExpense = false),
            ),
          ],
        ),
        SizedBox(height: 20),

        // 环形图（磨砂玻璃）
        if (sorted.isNotEmpty && total > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(AppColors.isDark ? 30 : 90),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.premiumLight.withAlpha(15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.premium.withAlpha(10),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 55,
                          sections: sorted.take(6).toList().asMap().entries.map(
                            (e) {
                              final v = (e.value.value as num).toDouble();
                              return PieChartSectionData(
                                value: v,
                                color: AppColors.chartColor(e.key),
                                radius: 18,
                                title: '',
                                showTitle: false,
                              );
                            },
                          ).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '¥${_fmtNum(total)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            _showExpense ? '总支出' : '总收入',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.gray,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
        ],

        // 分类列表
        if (sorted.isNotEmpty && total > 0) ...[
          Text(
            _showExpense ? '支出构成' : '收入构成',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 12),
          ...sorted.take(8).toList().asMap().entries.map((e) {
            final v = (e.value.value as num).toDouble();
            final pct = total > 0 ? v / total : 0.0;
            final color = AppColors.chartColor(e.key);
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(AppColors.isDark ? 20 : 45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withAlpha(50)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [color.withAlpha(25), color.withAlpha(10)],
                          ),
                          border: Border.all(color: color.withAlpha(15)),
                        ),
                        child: Center(
                          child: Text(
                            emojis[e.value.key] ??
                                (e.value.key.isNotEmpty ? e.value.key[0] : '?'),
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.value.key,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Text(
                        '¥${_fmtNum(v)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 12, color: AppColors.gray),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct),
                      duration: AppAnimations.normal,
                      curve: Curves.easeOutCubic,
                      builder: (_, p, __) => Stack(
                        children: [
                          // background track
                          Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: color.withAlpha(15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          // gradient fill
                          FractionallySizedBox(
                            widthFactor: p,
                            child: Container(
                              height: 5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                gradient: LinearGradient(
                                  colors: [color, color.withAlpha(180)],
                                ),
                              ),
                            ),
                          ),
                          // gloss overlay on first half
                          if (p > 0)
                            FractionallySizedBox(
                              widthFactor: p * 0.5,
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withAlpha(60),
                                      Colors.white.withAlpha(0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withAlpha(25) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: active
              ? Border.all(color: AppColors.accent.withAlpha(50))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? AppColors.accentDark : AppColors.gray,
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, double v, Color c) {
    return Column(
      children: [
        Text(
          '¥${_fmtNum(v)}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c),
        ),
        SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.gray)),
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback? onTap, {bool dimmed = false}) {
    return GestureDetector(
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap();
            }
          : null,
      child: Container(
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(minWidth: 44, minHeight: 44),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.card,
        ),
        child: Icon(
          icon,
          color: dimmed ? AppColors.gray.withAlpha(80) : AppColors.ink,
          size: 20,
        ),
      ),
    );
  }

  // ==================== 年度（微信风格）====================
  Widget _yearly() {
    final d = _yd;
    if (d == null) return _empty();
    final ti = (d['total_income'] as num?)?.toDouble() ?? 0;
    final te = (d['total_expense'] as num?)?.toDouble() ?? 0;
    final months = (d['months'] as List<dynamic>?) ?? [];
    final chartScale = ChartScale.from(months.expand<num>((month) => [
      (month['income'] as num?) ?? 0,
      (month['expense'] as num?) ?? 0,
    ]));

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        // 年份切换
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _arrow(Icons.chevron_left, () {
              _curYear--;
              _load();
            }),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$_curYear年',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            _arrow(
              Icons.chevron_right,
              _curYear <= DateTime.now().year
                  ? () {
                      _curYear++;
                      _load();
                    }
                  : null,
              dimmed: _curYear > DateTime.now().year,
            ),
          ],
        ),
        SizedBox(height: 24),

        // Hero 总金额
        Center(
          child: Column(
            children: [
              Text(
                '¥${_fmtNum(ti - te)}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: (ti - te) >= 0 ? AppColors.success : AppColors.danger,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '年度结余',
                style: TextStyle(fontSize: 14, color: AppColors.gray),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),

        // 收支概览卡片
        Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniStat('收入', ti, AppColors.success),
              _miniStat('支出', te, AppColors.danger),
              _miniStat('结余', ti - te, AppColors.amber),
            ],
          ),
        ),

        if (months.isNotEmpty) ...[
          SizedBox(height: 24),
          Text(
            '月度趋势',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 12),
          // 磨砂玻璃卡片
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(AppColors.isDark ? 30 : 90),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.premiumLight.withAlpha(15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.premium.withAlpha(10),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 收入/支出图例
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '收入',
                          style: TextStyle(fontSize: 12, color: AppColors.gray),
                        ),
                        SizedBox(width: 16),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '支出',
                          style: TextStyle(fontSize: 12, color: AppColors.gray),
                        ),
                      ],
                    ),
                    if (chartScale.mode == ChartScaleMode.squareRoot)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('已优化显示比例，金额仍按真实值展示', style: TextStyle(fontSize: 11, color: AppColors.gray)),
                      ),
                    SizedBox(height: 12),
                    // 柱状图
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 1.25,
                          barGroups: _buildBarGroups(months, chartScale),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                    final label = rodIndex == 0 ? '收入' : '支出';
                                    final month = months[group.x];
                                    final value = ((month[rodIndex == 0 ? 'income' : 'expense'] ?? 0) as num).toDouble().toStringAsFixed(2);
                                    return BarTooltipItem(
                                      '$label ¥$value',
                                      TextStyle(
                                        color: AppColors.card,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                            ),
                            touchCallback:
                                (
                                  FlTouchEvent event,
                                  BarTouchResponse? response,
                                ) {
                                  if (event is FlTapUpEvent ||
                                      event is FlLongPressEnd) {
                                    HapticFeedback.lightImpact();
                                  }
                                },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (v, _) {
                                  final idx = v.toInt();
                                  if (idx >= 0 && idx < months.length) {
                                    final mStr =
                                        months[idx]['month']?.toString() ?? '';
                                    final monthNum = mStr.length >= 7
                                        ? int.tryParse(mStr.substring(5, 7))
                                        : (idx + 1);
                                    return Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        '${monthNum ?? idx + 1}月',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.gray,
                                        ),
                                      ),
                                    );
                                  }
                                  return Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: .25,
                            getDrawingHorizontalLine: (v) => FlLine(
                              color: AppColors.divider,
                              strokeWidth: 0.5,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  double _calculateMaxY(List<dynamic> months) {
    double maxY = 0;
    for (final m in months) {
      final income = ((m['income'] ?? 0) as num).toDouble();
      final expense = ((m['expense'] ?? 0) as num).toDouble();
      final max = income > expense ? income : expense;
      if (max > maxY) maxY = max;
    }
    return maxY * 1.25;
  }

  List<BarChartGroupData> _buildBarGroups(List<dynamic> months, ChartScale scale) {
    return months.asMap().entries.map((e) {
      final i = e.key;
      final m = e.value;
      final income = ((m['income'] ?? 0) as num).toDouble();
      final expense = ((m['expense'] ?? 0) as num).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: scale.visualValue(income),
            width: 10,
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            color: AppColors.success,
          ),
          BarChartRodData(
            toY: scale.visualValue(expense),
            width: 10,
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            color: AppColors.danger,
          ),
        ],
      );
    }).toList();
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.bar_chart_rounded,
          size: 48,
          color: AppColors.gray.withAlpha(80),
        ),
        SizedBox(height: 16),
        Text(
          '暂无数据',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '记一笔后这里会出现统计图表',
          style: TextStyle(fontSize: 12, color: AppColors.gray),
        ),
      ],
    ),
  );

  String _fmtNum(double v) => v.toStringAsFixed(2);
}
