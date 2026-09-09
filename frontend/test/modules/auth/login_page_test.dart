import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/data/models/api_response.dart';
import 'package:xiaojia_ledger/data/models/user.dart';
import 'package:xiaojia_ledger/modules/auth/login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
  });

  testWidgets('旧用户名登录会先保存令牌再进入账号升级', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          login: (account, password) async => ApiResponse<AuthData>(
            code: 0,
            message: 'ok',
            data: AuthData(
              username: account,
              token: 'session-token',
              needMigrate: true,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '江泽锦');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.text('登 录'));
    await tester.pumpAndSettle();

    expect(find.text('账号升级'), findsOneWidget);
    expect(
      await const FlutterSecureStorage().read(key: AppConstants.tokenKey),
      'session-token',
    );
  });
}
