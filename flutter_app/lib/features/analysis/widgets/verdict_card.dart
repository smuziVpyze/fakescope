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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Вердикт
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _verdictColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _verdictColor.withOpacity(0.3)),
            ),
            child: Text(_verdictLabel,
              style: TextStyle(color: _verdictColor, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 20),

          // Прогресс-бар
          Text('Вероятность фейка', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: result.confidence),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(_verdictColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('${(result.confidence * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _verdictColor)),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Аргументы
          Text('Аргументы', style: TextStyle(fontSize: 12, color: Colors.grey[600], letterSpacing: 0.3)),
          const SizedBox(height: 8),
          ...result.arguments.map((arg) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('→ ', style: TextStyle(color: _verdictColor, fontWeight: FontWeight.bold)),
                Expanded(child: Text(arg, style: const TextStyle(fontSize: 14, height: 1.4))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
