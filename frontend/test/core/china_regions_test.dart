import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/china_regions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses complete province city district hierarchy', () {
    const source = '''[
      {"code":"11","name":"北京市","children":[{"code":"1101","name":"市辖区","children":[{"code":"110101","name":"东城区"}]}]},
      {"code":"36","name":"江西省","children":[{"code":"3601","name":"南昌市","children":[{"code":"360102","name":"东湖区"},{"code":"360103","name":"西湖区"}]}]}
    ]''';
    final regions = ChinaRegions.fromJson(source);
    expect(regions.provinceCount, 2);
    expect(regions.cityCount, 2);
    expect(regions.districtCount, 3);
    expect(regions.cityNames('江西省'), ['南昌市']);
    expect(regions.districtNames('江西省', '南昌市'), ['东湖区', '西湖区']);
  });

  test(
    'bundled data covers all mainland province-level entries and districts',
    () async {
      final regions = await ChinaRegions.load();
      expect(regions.provinceCount, greaterThanOrEqualTo(34));
      expect(regions.cityCount, greaterThanOrEqualTo(330));
      expect(regions.districtCount, greaterThanOrEqualTo(2800));
      expect(regions.cityNames('江西省'), contains('南昌市'));
      expect(regions.districtNames('江西省', '南昌市'), contains('东湖区'));
      expect(regions.cityNames('台湾省'), contains('台北市'));
      expect(regions.districtNames('香港特别行政区', '香港'), contains('中西区'));
      expect(regions.districtNames('澳门特别行政区', '澳门'), contains('大堂区'));
    },
  );
}
