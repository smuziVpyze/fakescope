import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/feed_item.dart';
import '../../../core/models/analysis_result.dart';
import '../../../features/analysis/widgets/verdict_card.dart';
import '../../graph/screens/graph_screen.dart';

class NewsDetailScreen extends StatefulWidget {
  final FeedItem item;
  const NewsDetailScreen({super.key, required this.item});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  final _api = ApiClient();
  AnalysisResult? _analysis;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final json = await _api.analyze(url: widget.item.url, title: widget.item.title);
      setState(() {
        _analysis = AnalysisResult.fromJson(json);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть ссылку')),
        );
      }
    }
  }

  Color _verdictColor(String verdict) {
    switch (verdict) {
      case 'fake':  return const Color(0xFFE53935);
      case 'true':  return const Color(0xFF43A047);
      default:      return const Color(0xFFFB8C00);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = _verdictColor(item.verdict);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(item.sourceName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Источник и время
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1208),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(item.sourceName,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Text(item.publishedAt.substring(0, 10),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),

            const SizedBox(height: 12),

            // Заголовок
            Text(item.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.3, letterSpacing: -0.3)),

            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(item.summary,
                style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.6)),
            ],

            if (item.url.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _openUrl(item.url),
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new, size: 13, color: Color(0xFF1565C0)),
                    const SizedBox(width: 4),
                    const Text('Перейти к оригиналу',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF1565C0),
                      )),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            // Быстрый скор из ленты
            Row(
              children: [
                const Text('Предварительная оценка:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text('${(item.fakeScore * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.fakeScore,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),

            const SizedBox(height: 24),

            // Детальный анализ
            const Text('Детальный анализ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
            const SizedBox(height: 12),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 12)),
              )
            else if (_analysis != null)
              VerdictCard(result: _analysis!, showTitle: false),

            const SizedBox(height: 16),

            // Кнопка графа
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => GraphScreen(
                    url: item.url,
                    title: item.title,
                    publishedAt: item.publishedAt,
                  ))),
                icon: const Icon(Icons.hub, size: 16, color: Color(0xFF1A1208)),
                label: const Text('Граф распространения',
                  style: TextStyle(
                    color: Color(0xFF1A1208),
                    fontWeight: FontWeight.w700,
                  )),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF1A1208)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
