class HistoryItem {
  final String id;
  final String verdict;
  final double confidence;
  final String? text;
  final String? url;
  final List<String> arguments;
  final DateTime createdAt;

  HistoryItem({
    required this.id,
    required this.verdict,
    required this.confidence,
    this.text,
    this.url,
    required this.arguments,
    required this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'],
    verdict: json['verdict'],
    confidence: (json['confidence'] as num).toDouble(),
    text: json['text'],
    url: json['url'],
    arguments: List<String>.from(json['arguments']),
    createdAt: DateTime.parse(json['created_at']),
  );

  String get displayText => text ?? url ?? 'Без текста';
}
