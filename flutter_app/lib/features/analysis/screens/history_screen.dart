import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/history_item.dart';

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

  Color _verdictColor(String verdict) {
    switch (verdict) {
      case 'fake':       return const Color(0xFFE53935);
      case 'true':       return const Color(0xFF43A047);
      default:           return const Color(0xFFFB8C00);
    }
  }

  String _verdictLabel(String verdict) {
    switch (verdict) {
      case 'fake':       return '⚠ ФЕЙК';
      case 'true':       return '✓ ПРАВДА';
      default:           return '? НЕ ВЕРИФИЦИРОВАНО';
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
                  return Container(
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
                        Text('${(item.confidence * 100).toStringAsFixed(1)}% уверенность',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
