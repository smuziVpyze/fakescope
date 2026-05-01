import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/feed_item.dart';
import 'news_detail_screen.dart';

const _allCategories = [
  {'slug': 'all', 'ru': 'Все', 'emoji': '📰'},
  {'slug': 'politics', 'ru': 'Политика', 'emoji': '🏛'},
  {'slug': 'economy', 'ru': 'Экономика', 'emoji': '📈'},
  {'slug': 'society', 'ru': 'Общество', 'emoji': '👥'},
  {'slug': 'health', 'ru': 'Здоровье', 'emoji': '🏥'},
  {'slug': 'tech', 'ru': 'Технологии', 'emoji': '💻'},
  {'slug': 'sport', 'ru': 'Спорт', 'emoji': '⚽'},
  {'slug': 'crime', 'ru': 'Происшествия', 'emoji': '🚨'},
  {'slug': 'world', 'ru': 'Мир', 'emoji': '🌍'},
  {'slug': 'culture', 'ru': 'Культура', 'emoji': '🎭'},
];

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _api = ApiClient();
  List<FeedItem> _items = [];
  bool _loading = true;
  String _selectedCategory = 'all';

  List<FeedItem> get _filtered {
    if (_selectedCategory == 'all') return _items;
    return _items.where((i) => i.category == _selectedCategory).toList();
  }

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
      body: Column(
        children: [

          // Фильтр по категориям
          Container(
            color: const Color(0xFF1A1208),
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _allCategories.length,
              itemBuilder: (context, index) {
                final cat = _allCategories[index];
                final isSelected = _selectedCategory == cat['slug'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['slug']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${cat['emoji']} ${cat['ru']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                          ? const Color(0xFF1A1208)
                          : Colors.white70,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Счётчик новостей
          if (!_loading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFFEDE8DF),
              child: Text(
                '${_filtered.length} новостей',
                style: TextStyle(fontSize: 11, color: Colors.grey[600],
                  fontWeight: FontWeight.w600),
              ),
            ),

          // Список новостей
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('😔', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text('Нет новостей в этой категории',
                          style: TextStyle(color: Colors.grey[500])),
                      ],
                    ))
                : RefreshIndicator(
                    onRefresh: () => _load(refresh: true),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final item = _filtered[index];
                        final color = _verdictColor(item.verdict);

                        return GestureDetector(
                          onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                              builder: (_) => NewsDetailScreen(item: item))),
                          child: Container(
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
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12)),
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
                                        mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(children: [
                                            Text(_sourceIcon(item.sourceTrust)),
                                            const SizedBox(width: 4),
                                            Text(item.sourceName,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w600)),
                                          ]),
                                          Row(children: [
                                            // Категория
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1A1208)
                                                  .withOpacity(0.07),
                                                borderRadius:
                                                  BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${item.categoryEmoji}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1A1208),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // Вердикт
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.1),
                                                borderRadius:
                                                  BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${_verdictEmoji(item.verdict)} '
                                                '${(item.fakeScore * 100).toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: color,
                                                  fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                          ]),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(item.title,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          height: 1.4),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.summary.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(item.summary,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            height: 1.4),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Нажмите для подробного анализа',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[400])),
                                          Icon(Icons.arrow_forward_ios,
                                            size: 12, color: Colors.grey[400]),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
