import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/router.dart';
import 'package:xiaojia_ledger/data/api/auth_api.dart';
import 'package:xiaojia_ledger/data/models/api_response.dart';
import 'package:xiaojia_ledger/data/models/user.dart';
import 'package:xiaojia_ledger/modules/auth/migration_page.dart';
import 'package:xiaojia_ledger/modules/onboarding/onboarding_page.dart';

class LoginPage extends StatefulWidget {
  final Future<ApiResponse<AuthData>> Function(String account, String password)
  login;

  const LoginPage({super.key, this.login = AuthApi.login});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLogin = true, _loading = false;
  final _account = TextEditingController(), _pw = TextEditingController(), _pw2 = TextEditingController();
  String _secQuestion = '';
  final _secCtrl = TextEditingController();

  static const _questions = AppConstants.securityQuestions;

  Future<void> _submit() async {
    final a = _account.text.trim(), p = _pw.text;
    if (a.isEmpty || p.isEmpty) { _t('请填写完整'); return; }
    if (p.length < 6) { _t('密码至少 6 位'); return; }
    if (!_isLogin) {
      if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(a)) {
        _t('请输入正确的手机号'); return;
      }
      if (_pw2.text != p) { _t('两次密码不一致'); return; }
      if (_secQuestion.isEmpty || _secCtrl.text.trim().isEmpty) { _t('请设置密保问题和答案'); return; }
    }
    setState(() => _loading = true);
    try {
      if (!_isLogin) {
        // 手机号注册
        final r = await AuthApi.registerWithPhone(a, p, _secQuestion, _secCtrl.text.trim());
        if (r.isSuccess && r.data != null) await _saveAndGo(r.data!.token, r.data!.username);
        else _t(r.message);
      } else {
        final r = await widget.login(a, p);
        if (r.isSuccess && r.data != null) {
          await _saveSession(r.data!.token, r.data!.username);
          // 检查是否需要迁移
          final needMigrate = r.data!.needMigrate;
          if (needMigrate && mounted) {
            final migrated = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => MigrationPage()));
            if (migrated == true && mounted) {
              await _goAfterLogin();
            } else if (mounted) {
              await _clearSession();
            }
          } else {
            await _goAfterLogin();
          }
        } else _t(r.message);
      }
    } catch (_) { _t('网络错误'); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveAndGo(String token, String username) async {
    await _saveSession(token, username);
    await _goAfterLogin();
  }

  Future<void> _saveSession(String token, String username) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: AppConstants.tokenKey, value: token);
    await storage.write(key: AppConstants.usernameKey, value: username);
  }

  Future<void> _clearSession() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: AppConstants.tokenKey);
    await storage.delete(key: AppConstants.usernameKey);
  }

  Future<void> _goAfterLogin() async {
    if (!mounted) return;
    // 检查是否首次登录，显示引导页
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final done = prefs.getBool('onboarding_done') ?? false;
    if (!done) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OnboardingPage(
            onComplete: (onboardingContext) => Navigator.pushReplacementNamed(
              onboardingContext,
              AppRouter.home,
            ),
          ),
        ),
      );
    } else {
      Navigator.pushReplacementNamed(context, AppRouter.home);
    }
  }

  void _t(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void dispose() { _account.dispose(); _pw.dispose(); _pw2.dispose(); _secCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(height: 40),
        // Logo — scheme-aware gradient
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.highlight, Color.lerp(AppColors.highlight, Colors.black, 0.2)!], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.highlight.withAlpha(50), blurRadius: 18)]),
          child: Icon(Icons.savings_rounded, color: Colors.white, size: 32),
        ),
        SizedBox(height: 24),
        Text(AppConstants.appName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink)),
        SizedBox(height: 8),
        Text(_isLogin ? '欢迎回来' : '创建账号', style: TextStyle(fontSize: 14, color: AppColors.gray)),
        SizedBox(height: 32),
        // 表单 — scheme-aware borders
        AppCard(child: Column(children: [
          TextField(controller: _account, keyboardType: TextInputType.phone, decoration: InputDecoration(hintText: '手机号', prefixIcon: Icon(Icons.phone_android_rounded, color: AppColors.gray, size: 20), border: inputBorder, enabledBorder: inputBorder, focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: AppColors.highlight, width: 1.5))), style: TextStyle(color: AppColors.ink)),
          SizedBox(height: 16),
          TextField(controller: _pw, obscureText: true, decoration: InputDecoration(hintText: '密码', prefixIcon: Icon(Icons.lock_rounded, color: AppColors.gray, size: 20), border: inputBorder, enabledBorder: inputBorder, focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: AppColors.highlight, width: 1.5))), style: TextStyle(color: AppColors.ink)),
          if (!_isLogin) ...[
            SizedBox(height: 16),
            TextField(controller: _pw2, obscureText: true, decoration: InputDecoration(hintText: '确认密码', prefixIcon: Icon(Icons.lock_rounded, color: AppColors.gray, size: 20), border: inputBorder, enabledBorder: inputBorder, focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: AppColors.highlight, width: 1.5))), style: TextStyle(color: AppColors.ink)),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text('选择密保问题', style: TextStyle(fontSize: 14, color: AppColors.gray)),
                  value: _secQuestion.isEmpty ? null : _secQuestion,
                  items: _questions.map((q) => DropdownMenuItem(value: q, child: Text(q, style: TextStyle(fontSize: 14, color: AppColors.ink)))).toList(),
                  onChanged: (v) => setState(() => _secQuestion = v ?? ''),
                ),
              ),
            ),
            SizedBox(height: 12),
            TextField(controller: _secCtrl, decoration: InputDecoration(hintText: '密保答案', prefixIcon: Icon(Icons.help_rounded, color: AppColors.gray, size: 20), border: inputBorder, enabledBorder: inputBorder, focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: AppColors.highlight, width: 1.5))), style: TextStyle(color: AppColors.ink)),
          ],
          SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _loading ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: AppColors.highlight, foregroundColor: Colors.white), child: Text(_isLogin ? '登 录' : '注 册', style: TextStyle(fontSize: 16)))),
        ])),
        SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(onTap: () { HapticFeedback.lightImpact(); setState(() => _isLogin = !_isLogin); }, child: Text(_isLogin ? '没有账号？去注册' : '已有账号？去登录', style: TextStyle(fontSize: 14, color: AppColors.highlight))),
        ]),
        if (_isLogin) ...[
          SizedBox(height: 12),
          GestureDetector(onTap: () { HapticFeedback.lightImpact(); Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())); }, child: Text('忘记密码？', style: TextStyle(fontSize: 14, color: AppColors.gray))),
        ],
      ])))),
    );
  }
}

// ============================================================
// 忘记密码页
// ============================================================
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _phone = TextEditingController(), _answer = TextEditingController(), _newPw = TextEditingController();
  bool _loading = false;
  String? _tempToken;

  void _t(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _verify() async {
    final p = _phone.text.trim(), a = _answer.text.trim();
    if (p.isEmpty || a.isEmpty) { _t('请填写完整'); return; }
    setState(() => _loading = true);
    try {
      final r = await AuthApi.forgotPassword(p, a);
      if (r.isSuccess && r.data != null) {
        _tempToken = r.data!['temp_token'];
        _t('验证成功，请设置新密码');
      } else _t(r.message);
    } catch (_) { _t('网络错误'); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reset() async {
    final pw = _newPw.text;
    if (pw.length < 6) { _t('新密码至少6位'); return; }
    setState(() => _loading = true);
    try {
      final r = await AuthApi.resetPassword(_tempToken!, pw);
      if (r.isSuccess) { _t('密码重置成功'); if (mounted) Navigator.pop(context); }
      else _t(r.message);
    } catch (_) { _t('网络错误'); }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() { _phone.dispose(); _answer.dispose(); _newPw.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('忘记密码', style: TextStyle(color: AppColors.ink)), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(child: Padding(padding: EdgeInsets.all(24), child: Column(children: [
        if (_tempToken == null) ...[
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(hintText: '注册时使用的手机号', border: inputBorder, enabledBorder: inputBorder)),
          SizedBox(height: 16),
          TextField(controller: _answer, decoration: InputDecoration(hintText: '密保答案', border: inputBorder, enabledBorder: inputBorder)),
          SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _loading ? null : _verify, child: Text('验证'))),
        ] else ...[
          Text('已验证身份，请输入新密码', style: TextStyle(fontSize: 16, color: AppColors.ink)),
          SizedBox(height: 16),
          TextField(controller: _newPw, obscureText: true, decoration: InputDecoration(hintText: '新密码（至少6位）', border: OutlineInputBorder())),
          SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _loading ? null : _reset, child: Text('重置密码'))),
        ],
      ]))),
    );
  }
}
