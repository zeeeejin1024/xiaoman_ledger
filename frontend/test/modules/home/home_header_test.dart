import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/modules/home/home_header.dart';
import 'package:xiaojia_ledger/modules/home/home_subtitle_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('subtitle normalizes blank and limits text to 16 characters', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = HomeSubtitleRepository(preferences);

    await repository.save('   ');
    expect(repository.load(), HomeSubtitleRepository.defaultValue);

    await repository.save('一二三四五六七八九十一二三四五六七八九');
    expect(repository.load(), '一二三四五六七八九十一二三四五六');
  });

  testWidgets('only the change action edits the subtitle', (tester) async {
    var editCount = 0;
    var settingsCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeHeader(
            subtitle: HomeSubtitleRepository.defaultValue,
            onEditSubtitle: () => editCount++,
            onOpenSettings: () => settingsCount++,
          ),
        ),
      ),
    );

    expect(find.text('小满记账'), findsOneWidget);
    await tester.tap(find.text(HomeSubtitleRepository.defaultValue));
    expect(editCount, 0);

    await tester.tap(find.byKey(const ValueKey('home-subtitle-edit')));
    expect(editCount, 1);
    expect(settingsCount, 0);
  });

  testWidgets('header actions keep 48dp hit targets and 24dp settings icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              HomeHeader(
                subtitle: HomeSubtitleRepository.defaultValue,
                onEditSubtitle: () {},
                onOpenSettings: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('home-subtitle-edit'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('home-settings'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.settings_outlined)).size, 24);
  });

  testWidgets('brand mark and title share one axis above the subtitle row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeHeader(
            subtitle: HomeSubtitleRepository.defaultValue,
            onEditSubtitle: () {},
            onOpenSettings: () {},
          ),
        ),
      ),
    );

    final markRect = tester.getRect(
      find.byKey(const ValueKey('home-brand-mark')),
    );
    final titleRect = tester.getRect(
      find.byKey(const ValueKey('home-brand-title')),
    );
    final subtitleRect = tester.getRect(
      find.byKey(const ValueKey('home-subtitle-row')),
    );

    expect(
      (markRect.center.dy - titleRect.center.dy).abs(),
      lessThanOrEqualTo(1),
    );
    expect(subtitleRect.top, greaterThan(titleRect.bottom));
    expect(subtitleRect.left, closeTo(titleRect.left, 1));
  });

  testWidgets(
    'signature and edit action share a baseline with visual spacing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeHeader(
              subtitle: HomeSubtitleRepository.defaultValue,
              onEditSubtitle: () {},
              onOpenSettings: () {},
            ),
          ),
        ),
      );

      final signature = tester.getRect(
        find.byKey(const ValueKey('home-signature-text')),
      );
      final editIcon = tester.getRect(
        find.byKey(const ValueKey('home-signature-edit-icon')),
      );

      expect(
        (signature.center.dy - editIcon.center.dy).abs(),
        lessThanOrEqualTo(2),
      );
      expect(signature.left - editIcon.right, greaterThanOrEqualTo(0));
      expect(find.text('编辑签名'), findsNothing);
    },
  );

  testWidgets('header keeps the two-line brand block compact', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              HomeHeader(
                subtitle: HomeSubtitleRepository.defaultValue,
                onEditSubtitle: () {},
                onOpenSettings: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final header = tester.getRect(find.byType(HomeHeader));
    final title = tester.widget<Text>(
      find.byKey(const ValueKey('home-brand-title')),
    );
    final subtitle = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('home-subtitle-row')),
        matching: find.text(HomeSubtitleRepository.defaultValue),
      ),
    );

    expect(header.height, lessThanOrEqualTo(56));
    expect(subtitle.style!.fontSize, lessThan(title.style!.fontSize!));
  });

  testWidgets('subtitle dialog stays open until persistence succeeds', (
    tester,
  ) async {
    var attempts = 0;
    String? savedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => HomeSubtitleDialog(
                initialValue: HomeSubtitleRepository.defaultValue,
                onSave: (value) async {
                  attempts++;
                  savedValue = value;
                  return attempts > 1;
                },
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('编辑签名'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '我的留白');
    await tester.tap(find.byKey(const ValueKey('home-subtitle-save')));
    await tester.pump();

    expect(find.byType(HomeSubtitleDialog), findsOneWidget);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(savedValue, '我的留白');

    await tester.tap(find.byKey(const ValueKey('home-subtitle-save')));
    await tester.pumpAndSettle();

    expect(find.byType(HomeSubtitleDialog), findsNothing);
    expect(attempts, 2);
  });

  test('home uses the fixed title header and subtitle repository', () {
    final source = File('lib/modules/home/home_page.dart').readAsStringSync();

    expect(source, contains('HomeHeader('));
    expect(source, contains('HomeSubtitleRepository'));
    expect(source, isNot(contains("'app_title'")));
  });
}
