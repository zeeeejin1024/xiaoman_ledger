import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/data/api/record_api.dart';
import 'package:xiaojia_ledger/data/api/category_api.dart';
import 'package:xiaojia_ledger/data/models/record.dart';
import 'package:xiaojia_ledger/data/models/category.dart';
import 'package:xiaojia_ledger/widgets/particle_effect.dart';

class RecordsListPage extends StatefulWidget {
  const RecordsListPage({super.key});
  @override
  State<RecordsListPage> createState() => _RecordsListPageState();
}

class _RecordsListPageState extends State<RecordsListPage> {
  List<Record> _all = [];
  bool _loading = true;
  String _filter = 'all';
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await RecordApi.getRecords();
      if (r.isSuccess && r.data != null) setState(() => _all = r.data!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败，请稍后重试')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Record> get _filtered {
    List<Record> result = _all;
    if (_filter == 'expense') result = result.where((r) => !r.isIncome).toList();
    else if (_filter == 'income') result = result.where((r) => r.isIncome).toList();
    if (_search.isNotEmpty) {
      result = result.where((r) =>
        r.categoryName.toLowerCase().contains(_search.toLowerCase()) ||
        (r.note?.toLowerCase().contains(_search.toLowerCase()) ?? false)
      ).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Record>>{};
    for (final r in _filtered) { (grouped[r.date] ??= []).add(r); }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: Column(children: [
        // 搜索框
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: '搜索备注或分类...',
              prefixIcon: Icon(Icons.search, color: AppColors.gray, size: 20),
              suffixIcon: _search.isNotEmpty ? IconButton(
                icon: Icon(Icons.clear, size: 18),
                onPressed: () { _searchController.clear(); setState(() => _search = ''); },
              ) : null,
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
            style: TextStyle(fontSize: 14, color: AppColors.ink),
          ),
        ),
        // 筛选按钮
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
            _filterChip('全部', 'all'),
            SizedBox(width: 8),
            _filterChip('支出', 'expense'),
            SizedBox(width: 8),
            _filterChip('收入', 'income'),
          ]),
        ),
        SizedBox(height: 8),
        // 列表
        Expanded(
          child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.amber))
            : RefreshIndicator(
            onRefresh: _load,
            color: AppColors.amber,
            child: dates.isEmpty
              ? ListView(children: [SizedBox(height: 120), Center(child: Column(children: [Icon(Icons.receipt_long_rounded, size: 56, color: AppColors.accent.withAlpha(80)), SizedBox(height: 16), Text('暂无记录', style: TextStyle(fontSize: 14, color: AppColors.gray))]))])
              : ListView.builder(
                  itemCount: dates.length,
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemBuilder: (_, i) {
                    final date = dates[i]; final recs = grouped[date]!;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: EdgeInsets.only(left: 4, bottom: 10, top: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(date, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gray)),
                          Text('支出 ¥${recs.where((r) => !r.isIncome).fold<double>(0, (sum, r) => sum + r.amount).toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: AppColors.gray)),
                        ])),
                      GlassCard(padding: EdgeInsets.zero, child: Column(
                        children: recs.asMap().entries.map((e) {
                          final idx = e.key; final r = e.value;
                          return Column(children: [
                            Dismissible(
                              key: Key('${r.id}_${r.date}'),
                              direction: DismissDirection.endToStart,
                              background: Container(alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20), decoration: BoxDecoration(color: AppColors.coralRed.withAlpha(15), borderRadius: BorderRadius.circular(20)), child: Icon(Icons.delete_outline, color: AppColors.coralRed)),
                              confirmDismiss: (_) async {
                                HapticFeedback.mediumImpact();
                                return await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('删除记录'), content: Text('确定删除「${r.categoryName} ¥${r.amount.toStringAsFixed(2)}」？'), actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('删除', style: TextStyle(color: AppColors.coralRed))),
                                ])) ?? false;
                              },
                              onDismissed: (_) async { await RecordApi.deleteRecord(r.id); _load(); },
                              child: GestureDetector(
                                onTap: () => _editRecord(r),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [
                                  Text(r.categoryEmoji ?? '●', style: TextStyle(fontSize: 18)), SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(r.categoryName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                                    if (r.note != null && r.note!.isNotEmpty) Text(r.note!, style: TextStyle(fontSize: 12, color: AppColors.gray), overflow: TextOverflow.ellipsis, maxLines: 1),
                                  ])),
                                  Text('${r.isIncome ? '+' : '-'}¥${r.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: r.isIncome ? AppColors.sage : AppColors.coralRed)),
                                ])),
                              ),
                            ),
                            if (idx < recs.length - 1) Divider(indent: 48),
                          ]);
                        }).toList(),
                      )),
                      SizedBox(height: 10),
                    ]);
                  },
                ),
          )),
        ],
      )),
    );
  }

  Widget _buildFilter() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(children: [
        _filterPill('全部', 'all'),
        SizedBox(width: 8),
        _filterPill('支出', 'expense'),
        SizedBox(width: 8),
        _filterPill('收入', 'income'),
      ]),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); setState(() => _filter = value); },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: active ? AppColors.highlight.withAlpha(30) : AppColors.card, borderRadius: BorderRadius.circular(20), border: active ? Border.all(color: AppColors.highlight.withAlpha(100)) : null),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? AppColors.highlight : AppColors.gray)),
      ),
    );
  }

  Widget _filterPill(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); setState(() => _filter = value); },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(color: active ? AppColors.amber.withAlpha(30) : AppColors.card, borderRadius: BorderRadius.circular(20), border: active ? Border.all(color: AppColors.amber.withAlpha(100)) : null),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? AppColors.ink : AppColors.gray)),
      ),
    );
  }

  Future<void> _editRecord(Record r) async {
    HapticFeedback.lightImpact();
    final amtCtrl = TextEditingController(text: r.amount.toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: r.note ?? '');
    DateTime editDate = DateTime.tryParse(r.date) ?? DateTime.now();
    Category? selectedCat;
    List<Category> allCats = [];

    // 加载分类列表
    try {
      final cr = await CategoryApi.getCategories();
      if (cr.isSuccess && cr.data != null) allCats = cr.data!;
      // 找到当前分类
      for (final root in allCats) {
        if (root.id == r.categoryId) { selectedCat = root; break; }
        for (final leaf in root.leafCategories) {
          if (leaf.id == r.categoryId) { selectedCat = leaf; break; }
        }
        if (selectedCat != null) break;
      }
    } catch (_) {}

    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx2, setSt) {
        // 按类型筛选分类
        final catType = r.isIncome ? 'income' : 'expense';
        final roots = allCats.where((c) => c.type == catType).toList();
        int? expandedCatId;
        return AlertDialog(
          title: Text('编辑记录'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 金额
            TextField(controller: amtCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '金额', prefixText: '¥ '),),
            SizedBox(height: 12),
            // 分类
            Text('分类', style: TextStyle(fontSize: 12, color: AppColors.gray)),
            SizedBox(height: 6),
            ...roots.map((parent) {
              final children = parent.children.where((c) => c.type == catType).toList();
              final isExpanded = expandedCatId == parent.id;
              return Column(children: [
                GestureDetector(
                  onTap: () => setSt(() => expandedCatId = isExpanded ? null : parent.id),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 4),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: isExpanded ? AppColors.accent.withAlpha(15) : AppColors.card, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Text(parent.emoji ?? '', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Expanded(child: Text(parent.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink))),
                      Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.gray, size: 22),
                    ]),
                  ),
                ),
                if (isExpanded && children.isNotEmpty) Padding(
                  padding: EdgeInsets.only(left: 12, bottom: 8),
                  child: Wrap(spacing: 6, runSpacing: 6, children: children.map((c) {
                    final sel = selectedCat?.id == c.id;
                    return GestureDetector(
                      onTap: () => setSt(() => selectedCat = c),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: sel ? AppColors.accent.withAlpha(40) : AppColors.card, borderRadius: BorderRadius.circular(10), border: sel ? Border.all(color: AppColors.accent, width: 1.2) : null),
                        child: Text('${c.emoji ?? ''} ${c.name}', style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? AppColors.accentDark : AppColors.ink)),
                      ),
                    );
                  }).toList()),
                ),
              ]);
            }),
            SizedBox(height: 12),
            // 日期
            GestureDetector(
              onTap: () async {
                final p = await showDatePicker(context: ctx2, initialDate: editDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (p != null) setSt(() => editDate = p);
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.calendar_today, size: 16, color: AppColors.gray),
                  SizedBox(width: 8),
                  Text('${editDate.month}月${editDate.day}日', style: TextStyle(color: AppColors.ink, fontSize: 14)),
                ]),
              ),
            ),
            SizedBox(height: 12),
            // 备注
            TextField(controller: noteCtrl, decoration: InputDecoration(labelText: '备注'),),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2, false), child: Text('取消')),
            ParticleEffect(
              onTap: () => Navigator.pop(ctx2, true),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx2, true),
                child: Text('保存'),
              ),
            ),
          ],
        );
      });
    });

    if (ok == true && mounted) {
      final newAmt = double.tryParse(amtCtrl.text);
      if (newAmt == null || newAmt <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请输入有效金额')));
        return;
      }
      bool success = true;
      // 逐字段更新
      if (newAmt != r.amount) {
        final ok = await RecordApi.updateRecord(r.id, 'amount', newAmt);
        if (!ok) success = false;
      }
      if (selectedCat != null && selectedCat!.id != r.categoryId) {
        final ok = await RecordApi.updateRecord(r.id, 'category_id', selectedCat!.id);
        if (!ok) success = false;
      }
      final newDate = editDate.toIso8601String().split('T')[0];
      if (newDate != r.date) {
        final ok = await RecordApi.updateRecord(r.id, 'date', newDate);
        if (!ok) success = false;
      }
      final newNote = noteCtrl.text.trim();
      if (newNote != (r.note ?? '')) {
        final ok = await RecordApi.updateRecord(r.id, 'note', newNote);
        if (!ok) success = false;
      }
      if (mounted) {
        if (success) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已更新')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('部分更新失败')));
        }
        _load();
      }
    }
  }
}
