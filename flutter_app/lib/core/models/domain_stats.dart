class DomainStats {
  final String domain;
  final int totalAnalyses;
  final Map<String, int> verdicts;
  final double? avgConfidence;
  final double trustScore;
  final double? trustScoreDynamic;
  final List<TrendPoint> trend;
  final bool known;
  final double? userTrustScore;

  DomainStats({
    required this.domain,
    required this.totalAnalyses,
    required this.verdicts,
    this.avgConfidence,
    required this.trustScore,
    this.trustScoreDynamic,
    required this.trend,
    required this.known,
    this.userTrustScore,
  });

  factory DomainStats.fromJson(Map<String, dynamic> json) {
    return DomainStats(
      domain: json['domain'] ?? '',
      totalAnalyses: json['total_analyses'] ?? 0,
      verdicts: Map<String, int>.from(json['verdicts'] ?? {}),
      avgConfidence: (json['avg_confidence'] as num?)?.toDouble(),
      trustScore: (json['trust_score'] as num?)?.toDouble() ?? 0.5,
      trustScoreDynamic: (json['trust_score_dynamic'] as num?)?.toDouble(),
      trend: (json['trend'] as List? ?? [])
          .map((e) => TrendPoint.fromJson(e))
          .toList(),
      known: json['known'] ?? false,
      userTrustScore: (json['user_trust_score'] as num?)?.toDouble(),
    );
  }
}

class TrendPoint {
  final String date;
  final int count;
  final double fakeRatio;
  final double trueRatio;
  final int trueCount;
  final int fakeCount;
  final int unverifiedCount;

  TrendPoint({required this.date, required this.count, required this.fakeRatio, this.trueRatio = 0.0, this.trueCount = 0, this.fakeCount = 0, this.unverifiedCount = 0});

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      date: json['date'] ?? '',
      count: json['count'] ?? 0,
      fakeRatio: (json['fake_ratio'] as num?)?.toDouble() ?? 0.0,
      trueRatio: (json['true_ratio'] as num?)?.toDouble() ?? 0.0,
      trueCount: json['true_count'] == null ? 0 : (json['true_count'] as num).toInt(),
      fakeCount: json['fake_count'] == null ? 0 : (json['fake_count'] as num).toInt(),
      unverifiedCount: json['unverified_count'] == null ? 0 : (json['unverified_count'] as num).toInt(),
    );
  }
}
