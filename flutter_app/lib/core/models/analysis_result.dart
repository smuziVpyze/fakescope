class ModuleScore {
  final String module;
  final double score;
  final String explanation;

  ModuleScore({required this.module, required this.score, required this.explanation});

  factory ModuleScore.fromJson(Map<String, dynamic> json) => ModuleScore(
    module: json['module'],
    score: (json['score'] as num).toDouble(),
    explanation: json['explanation'],
  );
}

class WordHighlight {
  final String word;
  final double weight;

  WordHighlight({required this.word, required this.weight});

  factory WordHighlight.fromJson(Map<String, dynamic> json) => WordHighlight(
    word: json['word'],
    weight: (json['weight'] as num).toDouble(),
  );
}

class DomainInfo {
  final String domain;
  final double trustScore;
  final String explanation;

  DomainInfo({required this.domain, required this.trustScore, required this.explanation});

  factory DomainInfo.fromJson(Map<String, dynamic> json) => DomainInfo(
    domain: json['domain'],
    trustScore: (json['trust_score'] as num).toDouble(),
    explanation: json['explanation'],
  );
}

class AnalysisResult {
  final String verdict;
  final double confidence;
  final List<ModuleScore> scores;
  final List<String> arguments;
  final List<WordHighlight> wordHighlights;
  final DomainInfo? domainInfo;
  final String? category;
  final String? categoryRu;
  final String? categoryEmoji;
  final String? title; // заголовок статьи — используется для графа
  final String? factcheckUrl; // ссылка на источник фактчека

  AnalysisResult({
    required this.verdict,
    required this.confidence,
    required this.scores,
    required this.arguments,
    required this.wordHighlights,
    this.domainInfo,
    this.category,
    this.categoryRu,
    this.categoryEmoji,
    this.title,
    this.factcheckUrl,
  });

  // Используется при открытии графа из экрана анализа URL
  String? get graphTitle => title?.isNotEmpty == true ? title : null;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
    verdict: json['verdict'],
    confidence: (json['confidence'] as num).toDouble(),
    scores: (json['scores'] as List).map((s) => ModuleScore.fromJson(s)).toList(),
    arguments: List<String>.from(json['arguments']),
    wordHighlights: (json['word_highlights'] as List? ?? [])
        .map((w) => WordHighlight.fromJson(w))
        .toList(),
    domainInfo: json['domain_info'] != null
        ? DomainInfo.fromJson(json['domain_info'])
        : null,
    category: json['category'],
    categoryRu: json['category_ru'],
    categoryEmoji: json['category_emoji'],
    title: json['title'],
    factcheckUrl: json['factcheck_url'],
  );
}
