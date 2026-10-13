import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/modules/home/home_page.dart';

void main() {
  test('home navigation exposes five destinations without wallet', () {
    final labels = homeNavigationDestinations
        .map((destination) => destination.label)
        .toList();

    expect(labels, equals(const ['首页', '统计', '存钱', '流水', '我的']));
    expect(labels, isNot(contains('钱包')));
  });

  test('home content keeps the standalone wallet entry', () {
    final source = File('lib/modules/home/home_page.dart').readAsStringSync();

    expect(source, contains('_walletEntry(),'));
    expect(source, contains('MaterialPageRoute(builder: (_) => WalletPage())'));
  });
}
