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

class AnalysisResult {
  final String verdict;
  final double confidence;
  final List<ModuleScore> scores;
  final List<String> arguments;
  final List<WordHighlight> wordHighlights;

  AnalysisResult({
    required this.verdict,
    required this.confidence,
    required this.scores,
    required this.arguments,
    required this.wordHighlights,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
    verdict: json['verdict'],
    confidence: (json['confidence'] as num).toDouble(),
    scores: (json['scores'] as List).map((s) => ModuleScore.fromJson(s)).toList(),
    arguments: List<String>.from(json['arguments']),
    wordHighlights: ((json['word_highlights'] ?? []) as List)
        .map((w) => WordHighlight.fromJson(w))
        .toList(),
  );
}
