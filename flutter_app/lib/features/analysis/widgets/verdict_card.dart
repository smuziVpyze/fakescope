import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
      case 'nlp':              return '🤖 NLP Анализ';
      case 'google_factcheck': return '🔍 Google Factcheck';
      case 'factcheck':        return '📋 Фактчек база';
      case 'domain':           return '🌐 Источник';
      default:                 return module;
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

          // Прогресс-бар
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
            factcheckUrl: score.module == 'google_factcheck'
                ? result.factcheckUrl
                : null,
          )),

          // XAI — подсветка слов
          if (result.wordHighlights.length >= 3) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _WordHighlightSection(highlights: result.wordHighlights),
          ],

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

// ───────────────────────────────────────────
// Секция XAI: облако слов с подсветкой
// ───────────────────────────────────────────
class _WordHighlightSection extends StatelessWidget {
  final List<WordHighlight> highlights;
  const _WordHighlightSection({required this.highlights});

  @override
  Widget build(BuildContext context) {
    // Макс. абсолютный вес для нормализации интенсивности
    final maxWeight = highlights
        .map((h) => h.weight.abs())
        .fold(0.0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🔬 ', style: TextStyle(fontSize: 13)),
            Text('Ключевые слова',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 0.3)),
            const SizedBox(width: 8),
            _Legend(color: const Color(0xFFE53935), label: 'фейк'),
            const SizedBox(width: 8),
            _Legend(color: const Color(0xFF43A047), label: 'правда'),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: highlights.map((h) {
            final intensity = maxWeight > 0 ? h.weight.abs() / maxWeight : 0.0;
            final isFake = h.weight > 0;
            final baseColor = isFake ? const Color(0xFFE53935) : const Color(0xFF43A047);
            final bgColor = baseColor.withOpacity(0.08 + intensity * 0.22);
            final borderColor = baseColor.withOpacity(0.2 + intensity * 0.4);
            final textColor = baseColor.withOpacity(0.7 + intensity * 0.3);
            final fontSize = 11.0 + intensity * 4.0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Text(
                h.word,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: intensity > 0.5 ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text('Размер слова отражает силу влияния на вердикт',
          style: TextStyle(fontSize: 10, color: Colors.grey[400], fontStyle: FontStyle.italic)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }
}

// ───────────────────────────────────────────
// Строка модуля
// ───────────────────────────────────────────
class _ModuleScoreRow extends StatelessWidget {
  final String label;
  final double score;
  final String explanation;
  final Color color;
  final String? factcheckUrl;

  const _ModuleScoreRow({
    required this.label,
    required this.score,
    required this.explanation,
    required this.color,
    this.factcheckUrl,
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
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${(score * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score,
              minHeight: 5,
              backgroundColor: Colors.grey[100],
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 3),
          Text(explanation,
            style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.4)),
          if (factcheckUrl != null && factcheckUrl!.isNotEmpty) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(factcheckUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new, size: 11, color: Color(0xFF1565C0)),
                  const SizedBox(width: 4),
                  const Text('Открыть источник фактчека',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
