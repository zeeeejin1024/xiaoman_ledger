import 'package:characters/characters.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeSubtitleRepository {
  static const key = 'home_subtitle';
  static const defaultValue = '今天也留一点余地';
  static const maxLength = 16;

  final SharedPreferences preferences;

  HomeSubtitleRepository(this.preferences);

  String load() => normalize(preferences.getString(key));

  Future<bool> save(String value) =>
      preferences.setString(key, normalize(value));

  static String normalize(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return defaultValue;

    final characters = trimmed.characters;
    return characters.length <= maxLength
        ? trimmed
        : characters.take(maxLength).toString();
  }
}
