import 'package:flutter/material.dart';
import '../../../core/models/analysis_result.dart';

class VerdictCard extends StatelessWidget {
  final AnalysisResult result;
  const VerdictCard({super.key, required this.result});

  Color get _verdictColor {
    switch (result.verdict) {
      case 'fake': return const Color(0xFFE53935);
      case 'true': return const Color(0xFF43A047);
      default:     return const Color(0xFFFB8C00);
    }
  }

  String get _verdictLabel {
    switch (result.verdict) {
      case 'fake': return '⚠ ВЕРОЯТНЫЙ ФЕЙК';
      case 'true': return '✓ ДОСТОВЕРНО';
      default:     return '? НЕ ВЕРИФИЦИРОВАНО';
    }
  }

  String _moduleLabel(String module) {
    switch (module) {
      case 'nlp':             return '🤖 NLP Анализ';
      case 'google_factcheck': return '🔍 Google Factcheck';
      case 'factcheck':       return '📋 Фактчек база';
      case 'domain':          return '🌐 Источник';
      default:                return module;
    }
  }

  Color _scoreColor(double score) {
    if (score >= 0.65) return const Color(0xFFE53935);
    if (score >= 0.35) return const Color(0xFFFB8C00);
    return const Color(0xFF43A047);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 4),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Вердикт
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _verdictColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _verdictColor.withOpacity(0.3)),
            ),
            child: Text(_verdictLabel,
              style: TextStyle(
                color: _verdictColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.5,
              )),
          ),

          const SizedBox(height: 20),

          // Итоговый прогресс-бар
          Text('Вероятность фейка',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: result.confidence),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 12,
                backgroundColor: Colors.grey[100],
                valueColor: AlwaysStoppedAnimation(_verdictColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('${(result.confidence * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _verdictColor,
            )),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Скоры по модулям
          Text('Анализ по модулям',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          const SizedBox(height: 10),

          ...result.scores.map((score) => _ModuleScoreRow(
            label: _moduleLabel(score.module),
            score: score.score,
            explanation: score.explanation,
            color: _scoreColor(score.score),
          )),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Аргументы
          Text('Аргументы',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          ...result.arguments.map((arg) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('→ ', style: TextStyle(color: _verdictColor, fontWeight: FontWeight.bold, fontSize: 14)),
                Expanded(child: Text(arg, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF333333)))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _ModuleScoreRow extends StatelessWidget {
  final String label;
  final double score;
  final String explanation;
  final Color color;

  const _ModuleScoreRow({
    required this.label,
    required this.score,
    required this.explanation,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(score * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: Colors.grey[100],
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(explanation,
            style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
