class FeedItem {
  final String title;
  final String url;
  final String summary;
  final String sourceName;
  final String sourceTrust;
  final String publishedAt;
  final double fakeScore;
  final String verdict;

  FeedItem({
    required this.title,
    required this.url,
    required this.summary,
    required this.sourceName,
    required this.sourceTrust,
    required this.publishedAt,
    required this.fakeScore,
    required this.verdict,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
    title: json['title'] ?? '',
    url: json['url'] ?? '',
    summary: json['summary'] ?? '',
    sourceName: json['source_name'] ?? '',
    sourceTrust: json['source_trust'] ?? 'neutral',
    publishedAt: json['published_at'] ?? '',
    fakeScore: (json['fake_score'] as num).toDouble(),
    verdict: json['verdict'] ?? 'unverified',
  );
}
