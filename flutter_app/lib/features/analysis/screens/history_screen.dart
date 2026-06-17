import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/history_item.dart';
import '../../../core/models/analysis_result.dart';
import '../widgets/verdict_card.dart';
import '../../graph/screens/graph_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _api = ApiClient();
  List<HistoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getHistory();
      setState(() {
        _items = data.map((j) => HistoryItem.fromJson(j)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openItem(HistoryItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final data = await _api.getHistoryItem(item.id);
      if (!mounted) return;
      Navigator.pop(context);
      final result = AnalysisResult.fromJson(data);
      final sourceName = data['source_name'] as String? ?? 'Источник';
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _HistoryResultScreen(result: result, item: item, sourceName: sourceName),
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить результат')),
      );
    }
  }

  Color _verdictColor(String verdict) {
    switch (verdict) {
      case 'fake':    return const Color(0xFFE53935);
      case 'true':    return const Color(0xFF43A047);
      default:        return const Color(0xFFFB8C00);
    }
  }

  String _verdictLabel(String verdict) {
    switch (verdict) {
      case 'fake':    return '⚠ ФЕЙК';
      case 'true':    return '✓ ПРАВДА';
      default:        return '? НЕ ВЕРИФИЦИРОВАНО';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24)   return '${diff.inHours} ч назад';
    return '${diff.inDays} д назад';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        title: const Text('История проверок',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
          ? const Center(child: Text('Нет проверок'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final color = _verdictColor(item.verdict);
                  return GestureDetector(
                    onTap: () => _openItem(item),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(left: BorderSide(color: color, width: 4)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_verdictLabel(item.verdict),
                                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
                              Text(_timeAgo(item.createdAt),
                                style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(item.displayText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, height: 1.4)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: item.confidence,
                              minHeight: 4,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(color),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${(item.confidence * 100).toStringAsFixed(1)}% уверенность',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _HistoryResultScreen extends StatelessWidget {
  final AnalysisResult result;
  final HistoryItem item;
  final String sourceName;

  const _HistoryResultScreen({required this.result, required this.item, required this.sourceName});

  String get _sourceName => sourceName;

  String get _dateStr {
    final d = item.createdAt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = result.title != null && result.title!.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_sourceName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Источник и дата
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1208),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_sourceName,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Text(_dateStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),

            if (hasTitle) ...[
              const SizedBox(height: 12),
              Text(result.title!,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.3, letterSpacing: -0.3)),
            ],

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            VerdictCard(result: result, showTitle: false),

            const SizedBox(height: 16),

            // Кнопка графа
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => GraphScreen(
                    url: item.url,
                    title: result.title ?? item.displayText,
                  ))),
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

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
