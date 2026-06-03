import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analysis_provider.dart';
import '../widgets/verdict_card.dart';
import '../../graph/screens/graph_screen.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  final _controller = TextEditingController();
  bool get _isUrl => _controller.text.trim().startsWith('http');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _analyze() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    if (_isUrl) {
      ref.read(analysisProvider.notifier).analyze(text, isUrl: true);
    } else {
      ref.read(analysisProvider.notifier).analyze(text, isUrl: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        title: const Text('FakeScope',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Проверить новость',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text('Вставьте текст или URL новости',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
              ),
              child: TextField(
                controller: _controller,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Вставьте текст или URL новости...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (_controller.text.isNotEmpty)
              Row(
                children: [
                  Icon(_isUrl ? Icons.link : Icons.text_fields,
                    size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(_isUrl ? 'URL — анализ домена + граф' : 'Текст — NLP + поиск источника',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state is AnalysisLoading ? null : _analyze,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1208),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: state is AnalysisLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Проверить',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),

            const SizedBox(height: 24),

            if (state is AnalysisSuccess) ...[
              VerdictCard(result: state.result, showTitle: _isUrl),
              const SizedBox(height: 12),

              // Кнопка графа
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final input = _controller.text.trim();
                    // Если URL — передаём url + заголовок из результата анализа
                    // Если текст — передаём первые 100 символов как заголовок
                    final rawTitle = state.result.title ?? "";
                    final graphTitle = _isUrl
                      ? (rawTitle.isNotEmpty ? rawTitle : state.result.arguments.isNotEmpty ? state.result.arguments.first : input)
                      : input;
                    Navigator.push(context,
                      MaterialPageRoute(builder: (_) => GraphScreen(
                        url: _isUrl ? input : null,
                        title: graphTitle,
                      )));
                  },
                  icon: const Icon(Icons.hub, size: 16, color: Color(0xFF1A1208)),
                  label: const Text('Граф распространения',
                    style: TextStyle(color: Color(0xFF1A1208), fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF1A1208)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],

            if (state is AnalysisError)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF9A9A)),
                ),
                child: Text(state.message,
                  style: const TextStyle(color: Color(0xFFC62828))),
              ),
          ],
        ),
      ),
    );
  }
}
