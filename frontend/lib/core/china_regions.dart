import 'dart:convert';

import 'package:flutter/services.dart';

/// Local administrative division data used by profile region selection.
/// The asset is generated from the public Administrative-divisions-of-China
/// dataset and keeps the UI independent from a network request.
class ChinaRegions {
  final Map<String, Map<String, List<String>>> data;

  const ChinaRegions(this.data);

  static Future<ChinaRegions> load() async {
    final source = await rootBundle.loadString('assets/china_regions.json');
    final parsed = ChinaRegions.fromJson(source);
    final merged = <String, Map<String, List<String>>>{...parsed.data};
    for (final entry in _supplementalRegions.entries) {
      merged.putIfAbsent(entry.key, () => entry.value);
    }
    final normalized = <String, Map<String, List<String>>>{};
    for (final entry in merged.entries) {
      normalized[entry.key] = Map.unmodifiable(entry.value);
    }
    return ChinaRegions(Map.unmodifiable(normalized));
  }

  static const _supplementalRegions = {
    '台湾省': {
      '台北市': [
        '中正区',
        '大同区',
        '中山区',
        '松山区',
        '大安区',
        '万华区',
        '信义区',
        '士林区',
        '北投区',
        '内湖区',
        '南港区',
        '文山区',
      ],
      '新北市': [
        '板桥区',
        '三重区',
        '中和区',
        '永和区',
        '新庄区',
        '新店区',
        '树林区',
        '莺歌区',
        '三峡区',
        '淡水区',
        '汐止区',
        '瑞芳区',
      ],
      '桃园市': ['桃园区', '中坜区', '平镇区', '八德区', '杨梅区', '芦竹区'],
      '台中市': ['中区', '东区', '南区', '西区', '北区', '西屯区', '南屯区', '北屯区', '丰原区', '大里区'],
      '台南市': ['中西区', '东区', '南区', '北区', '安平区', '安南区', '永康区', '归仁区'],
      '高雄市': [
        '新兴区',
        '前金区',
        '苓雅区',
        '盐埕区',
        '鼓山区',
        '前镇区',
        '三民区',
        '左营区',
        '楠梓区',
        '小港区',
      ],
      '基隆市': ['仁爱区', '信义区', '中正区', '中山区', '安乐区', '暖暖区', '七堵区'],
      '新竹市': ['东区', '北区', '香山区'],
      '嘉义市': ['东区', '西区'],
      '新竹县': [
        '竹北市',
        '竹东镇',
        '新埔镇',
        '关西镇',
        '湖口乡',
        '新丰乡',
        '芎林乡',
        '横山乡',
        '北埔乡',
        '宝山乡',
        '峨眉乡',
        '尖石乡',
        '五峰乡',
      ],
      '苗栗县': [
        '苗栗市',
        '苑里镇',
        '通霄镇',
        '竹南镇',
        '头份市',
        '后龙镇',
        '卓兰镇',
        '大湖乡',
        '公馆乡',
        '铜锣乡',
        '三义乡',
        '西湖乡',
        '造桥乡',
        '三湾乡',
        '南庄乡',
        '头屋乡',
      ],
      '彰化县': ['彰化市', '员林市', '鹿港镇', '和美镇', '溪湖镇', '二林镇', '田中镇', '北斗镇'],
      '南投县': [
        '南投市',
        '埔里镇',
        '草屯镇',
        '竹山镇',
        '集集镇',
        '名间乡',
        '鹿谷乡',
        '鱼池乡',
        '国姓乡',
        '水里乡',
        '信义乡',
        '仁爱乡',
      ],
      '云林县': [
        '斗六市',
        '斗南镇',
        '虎尾镇',
        '西螺镇',
        '土库镇',
        '北港镇',
        '古坑乡',
        '大埤乡',
        '莿桐乡',
        '林内乡',
        '二仑乡',
        '仑背乡',
      ],
      '嘉义县': [
        '太保市',
        '朴子市',
        '布袋镇',
        '大林镇',
        '民雄乡',
        '溪口乡',
        '新港乡',
        '六脚乡',
        '东石乡',
        '义竹乡',
        '鹿草乡',
        '水上乡',
        '中埔乡',
        '竹崎乡',
        '梅山乡',
        '番路乡',
        '大埔乡',
        '阿里山乡',
      ],
      '屏东县': [
        '屏东市',
        '潮州镇',
        '东港镇',
        '恒春镇',
        '万丹乡',
        '长治乡',
        '麟洛乡',
        '竹田乡',
        '内埔乡',
        '枋寮乡',
        '新园乡',
        '佳冬乡',
      ],
      '宜兰县': [
        '宜兰市',
        '罗东镇',
        '苏澳镇',
        '头城镇',
        '礁溪乡',
        '壮围乡',
        '员山乡',
        '冬山乡',
        '五结乡',
        '三星乡',
        '大同乡',
        '南澳乡',
      ],
      '花莲县': [
        '花莲市',
        '凤林镇',
        '玉里镇',
        '新城乡',
        '吉安乡',
        '寿丰乡',
        '光复乡',
        '瑞穗乡',
        '富里乡',
        '秀林乡',
      ],
      '台东县': [
        '台东市',
        '成功镇',
        '关山镇',
        '卑南乡',
        '鹿野乡',
        '池上乡',
        '东河乡',
        '长滨乡',
        '太麻里乡',
        '大武乡',
      ],
      '澎湖县': ['马公市', '湖西乡', '白沙乡', '西屿乡', '望安乡', '七美乡'],
      '金门县': ['金城镇', '金沙镇', '金湖镇', '金宁乡', '烈屿乡', '乌坵乡'],
      '连江县': ['南竿乡', '北竿乡', '莒光乡', '东引乡'],
    },
    '香港特别行政区': {
      '香港': [
        '中西区',
        '湾仔区',
        '东区',
        '南区',
        '油尖旺区',
        '深水埗区',
        '九龙城区',
        '黄大仙区',
        '观塘区',
        '葵青区',
        '荃湾区',
        '屯门区',
        '元朗区',
        '北区',
        '大埔区',
        '沙田区',
        '西贡区',
        '离岛区',
      ],
    },
    '澳门特别行政区': {
      '澳门': [
        '花地玛堂区',
        '圣安多尼堂区',
        '大堂区',
        '望德堂区',
        '风顺堂区',
        '嘉模堂区',
        '路凼填海区',
        '圣方济各堂区',
      ],
    },
  };

  factory ChinaRegions.fromJson(String source) {
    final raw = jsonDecode(source);
    if (raw is! List) throw const FormatException('Invalid region data');
    final result = <String, Map<String, List<String>>>{};
    for (final province in raw.whereType<Map>()) {
      final provinceName = '${province['name'] ?? ''}'.trim();
      if (provinceName.isEmpty) continue;
      final cities = <String, List<String>>{};
      final children = province['children'];
      if (children is List) {
        for (final city in children.whereType<Map>()) {
          final cityName = '${city['name'] ?? ''}'.trim();
          if (cityName.isEmpty) continue;
          final districts = <String>[];
          final cityChildren = city['children'];
          if (cityChildren is List) {
            for (final district in cityChildren.whereType<Map>()) {
              final districtName = '${district['name'] ?? ''}'.trim();
              if (districtName.isNotEmpty) districts.add(districtName);
            }
          }
          cities[cityName] = List.unmodifiable(districts);
        }
      }
      result[provinceName] = Map.unmodifiable(cities);
    }
    return ChinaRegions(Map.unmodifiable(result));
  }

  int get provinceCount => data.length;
  int get cityCount => data.values.fold(0, (sum, value) => sum + value.length);
  int get districtCount => data.values
      .expand((cities) => cities.values)
      .fold(0, (sum, value) => sum + value.length);

  List<String> cityNames(String province) =>
      List.unmodifiable(data[province]?.keys ?? const <String>[]);

  List<String> districtNames(String province, String city) =>
      List.unmodifiable(data[province]?[city] ?? const <String>[]);
}
