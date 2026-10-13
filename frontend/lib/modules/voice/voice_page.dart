import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/data/api/api_client.dart';
import 'package:xiaojia_ledger/data/api/record_api.dart';
import 'package:xiaojia_ledger/data/api/category_api.dart';
import 'package:xiaojia_ledger/modules/voice/voice_recorder_controller.dart';
import 'package:uuid/uuid.dart';

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});
  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _saving = false;
  Map<String, dynamic>? _parsed;
  late final VoiceRecorderController _recorder;
  String? _saveRequestId;

  @override
  void initState() {
    super.initState();
    _recorder = VoiceRecorderController()..addListener(_recordingChanged);
  }

  void _recordingChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleRecording() async {
    if (_recorder.state == VoiceState.recording) {
      final path = await _recorder.stop();
      if (path != null) await _uploadVoice(path);
    } else {
      await _recorder.start();
    }
  }

  Future<void> _uploadVoice(String path) async {
    setState(() => _loading = true);
    try {
      final response = await ApiClient().post(
        '/ai/voice',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(path, filename: 'voice.wav'),
        }),
      );
      if (response.data['code'] == 0) {
        _parsed = Map<String, dynamic>.from(response.data['data']['parsed'] as Map);
        _ctrl.text = '${response.data['data']['text'] ?? ''}';
        _recorder.confirm();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.data['message'] ?? '语音识别失败')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音识别失败，可改用文字输入')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _parse() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await ApiClient().post('/ai/parse', data: {'text': text});
      if (res.data['code'] == 0) {
        setState(() => _parsed = res.data['data']);
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? '解析失败')),
          );
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('网络错误，请重试')));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_parsed == null) return;
    final p = _parsed!;
    final type = p['type'] ?? 'expense';
    final amount = double.tryParse((p['amount'] ?? '0').toString()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('金额无效')));
      return;
    }
    setState(() => _saving = true);
    try {
      int catId = int.tryParse('${p['category_id'] ?? 0}') ?? 0;
      // 如果没有 category_id，尝试按名称匹配
      if (catId <= 1) {
        try {
          final cats = await CategoryApi.getCategories();
          if (cats.isSuccess && cats.data != null) {
            final allLeaf = cats.data!
                .where((c) => c.type == type)
                .expand((c) => c.leafCategories)
                .toList();
            final catName = p['category']?.toString() ?? '';
            final found = allLeaf.where(
              (c) =>
                  c.name == catName ||
                  c.name.contains(catName) ||
                  catName.contains(c.name),
            );
            if (found.isNotEmpty) {
              catId = found.first.id;
            }
          }
        } catch (_) {}
      }
      if (catId <= 0) {
        final picked = await _pickCategory(type);
        if (picked == null) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        catId = picked;
        _parsed = {...p, 'category_id': catId};
      }
      final r = await RecordApi.addRecord(
        type: type,
        amount: amount,
        categoryId: catId,
        date: DateTime.now().toIso8601String().split('T')[0],
        note: _ctrl.text.trim(),
        requestId: _saveRequestId ??= const Uuid().v4(),
      );
      if (mounted) {
        if (r.isSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已保存')));
          _parsed = null;
          _saveRequestId = null;
          _ctrl.clear();
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(r.message)));
        }
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败')));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<int?> _pickCategory(String type) async {
    final result = await CategoryApi.getCategories();
    if (!result.isSuccess || result.data == null || !mounted) return null;
    final categories = result.data!
        .where((category) => category.type == type)
        .expand((category) => [category, ...category.leafCategories])
        .toList();
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择记账分类'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: categories.length,
            itemBuilder: (_, index) {
              final category = categories[index];
              return ListTile(
                leading: Text(category.emoji ?? '•'),
                title: Text(category.name),
                onTap: () => Navigator.pop(dialogContext, category.id),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recorder.removeListener(_recordingChanged);
    _recorder.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AppThemedPage(builder: (context, _) => _buildPage(context));

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('语音记账'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.goldLight, AppColors.goldDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withAlpha(50),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(Icons.mic_rounded, color: Colors.white, size: 36),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _toggleRecording,
                  icon: Icon(
                    _recorder.state == VoiceState.recording
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                  ),
                  label: Text(
                    _recorder.state == VoiceState.recording ? '停止录音' : '录音记账',
                  ),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: '输入消费文字，如：午餐花了22元',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _ctrl.text.isNotEmpty && !_loading ? _parse : null,
                  child: Text(_loading ? '解析中...' : 'AI 解析'),
                ),
              ),
              if (_parsed != null) ...[
                SizedBox(height: 16),
                AppCard(
                  child: Column(
                    children: [
                      Text(
                        '类型: ${_parsed!['type'] == 'income' ? '收入' : '支出'}',
                        style: TextStyle(color: AppColors.ink),
                      ),
                      Text(
                        '金额: ¥${_parsed!['amount']}',
                        style: TextStyle(color: AppColors.ink),
                      ),
                      Text(
                        '分类: ${_parsed!['category'] ?? '未知'}',
                        style: TextStyle(color: AppColors.ink),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sage,
                          ),
                          child: Text(_saving ? '保存中...' : '保存记录'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
