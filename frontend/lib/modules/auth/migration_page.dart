import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/data/api/auth_api.dart';

class MigrationPage extends StatefulWidget {
  const MigrationPage({super.key});
  @override
  State<MigrationPage> createState() => _MigrationPageState();
}

class _MigrationPageState extends State<MigrationPage> {
  final _phone = TextEditingController(),
      _pw = TextEditingController(),
      _answer = TextEditingController();
  String _secQuestion = '';
  bool _loading = false;

  static const _questions = AppConstants.securityQuestions;

  Future<void> _migrate() async {
    final phone = _phone.text.trim(), pw = _pw.text;
    if (phone.isEmpty || pw.isEmpty) {
      _t('请填写完整');
      return;
    }
    if (pw.length < 6) {
      _t('密码至少6位');
      return;
    }
    if (_secQuestion.isEmpty || _answer.text.trim().isEmpty) {
      _t('请设置密保');
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await AuthApi.migrate(
        phone,
        pw,
        _secQuestion,
        _answer.text.trim(),
      );
      if (r.isSuccess) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'last_auth_check',
          DateTime.now().toIso8601String(),
        );
        _t('迁移成功！');
        if (mounted) Navigator.pop(context, true);
      } else {
        _t(r.message);
      }
    } catch (_) {
      _t('网络错误');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _t(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void dispose() {
    _phone.dispose();
    _pw.dispose();
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('账号升级', style: TextStyle(color: AppColors.ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.highlight,
                        Color.lerp(AppColors.highlight, Colors.black, 0.2)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.upgrade_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '为了更好的安全体验，请绑定手机号和密保',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '后续可以通过手机号和密保找回密码',
                  style: TextStyle(fontSize: 14, color: AppColors.gray),
                ),
                SizedBox(height: 32),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '手机号',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _pw,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '设置新密码',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.gray.withAlpha(60)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: Text(
                        '选择密保问题',
                        style: TextStyle(fontSize: 14, color: AppColors.gray),
                      ),
                      value: _secQuestion.isEmpty ? null : _secQuestion,
                      items: _questions
                          .map(
                            (q) => DropdownMenuItem(
                              value: q,
                              child: Text(
                                q,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _secQuestion = v ?? ''),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _answer,
                  decoration: InputDecoration(
                    hintText: '密保答案',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _migrate,
                    child: Text('完成升级'),
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
