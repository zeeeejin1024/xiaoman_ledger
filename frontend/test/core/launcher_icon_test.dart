import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/widgets/brand_mark_geometry.dart';

void main() {
  test('launcher and in-app mark share one normalized geometry source', () {
    final painter = File(
      'lib/widgets/unfinished_ring_mark.dart',
    ).readAsStringSync();
    final generator = File(
      'tool/regenerate_android_icon.ps1',
    ).readAsStringSync();

    expect(painter, contains("import 'brand_mark_geometry.dart';"));
    expect(generator, contains('widgets/brand_mark_geometry.dart'));
    expect(generator, contains('BrandMarkGeometry'));
    expect(BrandMarkGeometry.outerRadius, lessThan(0.5));
    expect(BrandMarkGeometry.launcherScale, lessThanOrEqualTo(0.78));
  });

  test(
    'Android adaptive launcher no longer uses the hand-written override',
    () {
      final obsolete = File(
        'android/app/src/main/res/drawable/ic_launcher_brand_foreground.xml',
      );
      final adaptive = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      ).readAsStringSync();
      final adaptiveRound = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml',
      ).readAsStringSync();

      expect(obsolete.existsSync(), isFalse);
      expect(adaptive, isNot(contains('ic_launcher_brand_foreground')));
      expect(adaptiveRound, isNot(contains('ic_launcher_brand_foreground')));
      expect(adaptive, contains('ic_launcher_foreground'));
    },
  );

  test('launcher regeneration is Android-only', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('android: true'));
    expect(pubspec, contains('ios: false'));
    expect(pubspec, contains('adaptive_icon_foreground_inset: 0'));
    expect(
      pubspec,
      contains('adaptive_icon_foreground: "assets/icon_foreground.png"'),
    );
  });
}
