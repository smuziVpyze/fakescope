import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/feed_item.dart';
import '../../graph/screens/graph_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _api = ApiClient();
  List<FeedItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() => _loading = true);
    try {
      final data = await _api.getFeed(refresh: refresh);
      setState(() {
        _items = data.map((j) => FeedItem.fromJson(j)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Color _verdictColor(String verdict) {
    switch (verdict) {
      case 'fake':  return const Color(0xFFE53935);
      case 'true':  return const Color(0xFF43A047);
      default:      return const Color(0xFFFB8C00);
    }
  }

  String _verdictEmoji(String verdict) {
    switch (verdict) {
      case 'fake':  return '⚠';
      case 'true':  return '✓';
      default:      return '?';
    }
  }

  String _sourceIcon(String trust) {
    switch (trust) {
      case 'reliable': return '🟢';
      case 'neutral':  return '🟡';
      default:         return '🔴';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        title: const Text('Лента новостей',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _load(refresh: true),
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final color = _verdictColor(item.verdict);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                    )],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: LinearProgressIndicator(
                          value: item.fakeScore,
                          minHeight: 5,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  Text(_sourceIcon(item.sourceTrust)),
                                  const SizedBox(width: 4),
                                  Text(item.sourceName,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                                ]),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_verdictEmoji(item.verdict)} ${(item.fakeScore * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(item.title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.4),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.summary.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(item.summary,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => GraphScreen(
                                      url: item.url,
                                      title: item.title,
                                    ))),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0e1420),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.hub, size: 12, color: Color(0xFF00e5ff)),
                                        SizedBox(width: 4),
                                        Text('Граф', style: TextStyle(fontSize: 11, color: Color(0xFF00e5ff), fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }
}
