List<String> reportRecommendationMessages(Map<String, dynamic>? data) {
  final insights = data?['insights'];
  if (insights is! Map) {
    return const ['继续记录几笔，数据充足后再给你有依据的建议。'];
  }
  final raw = insights['recommendations'];
  if (raw is List) {
    final messages = raw
        .whereType<Map>()
        .map((item) => '${item['message'] ?? ''}'.trim())
        .where((message) => message.isNotEmpty)
        .take(3)
        .toList();
    if (messages.isNotEmpty) return messages;
  }
  return const ['继续记录几笔，数据充足后再给你有依据的建议。'];
}
