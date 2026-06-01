import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../../../core/api/api_client.dart';

class GraphScreen extends StatefulWidget {
  final String? url;
  final String title;

  const GraphScreen({super.key, this.url, required this.title});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _graphData;
  bool _loading = true;
  String? _error;

  final Graph _graph = Graph()..isTree = true;
  final BuchheimWalkerConfiguration _config = BuchheimWalkerConfiguration()
    ..siblingSeparation = 40
    ..levelSeparation = 120
    ..subtreeSeparation = 40
    ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getGraph(url: widget.url, title: widget.title);
      setState(() {
        _graphData = data;
        _buildGraph(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _buildGraph(Map<String, dynamic> data) {
    final nodes = data['nodes'] as List;
    final edges = data['edges'] as List;

    // Сортируем не-первоисточники по дате
    final original = nodes.firstWhere((n) => n['is_original'] == true,
        orElse: () => nodes.first);
    final rest = nodes.where((n) => n['is_original'] != true).toList()
      ..sort((a, b) {
        final da = a['published_at'] as String?;
        final db = b['published_at'] as String?;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    final Map<String, Node> nodeMap = {};

    // Сначала добавляем первоисточник
    final originNode = Node.Id(original['id']);
    nodeMap[original['id'] as String] = originNode;
    _graph.addNode(originNode);

    // Затем остальные в порядке времени
    for (final n in rest) {
      final node = Node.Id(n['id']);
      nodeMap[n['id'] as String] = node;
      _graph.addNode(node);
    }

    // Рёбра от первоисточника ко всем
    final Set<String> addedEdges = {};
    for (final e in edges) {
      final key = '${e['from']}-${e['to']}';
      if (!addedEdges.contains(key)) {
        final from = nodeMap[e['from']];
        final to = nodeMap[e['to']];
        if (from != null && to != null) {
          _graph.addEdge(from, to);
          addedEdges.add(key);
        }
      }
    }
  }

  Color _trustColor(double trust) {
    if (trust >= 0.8) return const Color(0xFF43A047);
    if (trust >= 0.6) return const Color(0xFFFB8C00);
    return const Color(0xFFE53935);
  }

  Map<String, dynamic>? _nodeData(String id) {
    if (_graphData == null) return null;
    final nodes = _graphData!['nodes'] as List;
    try {
      return nodes.firstWhere((n) => n['id'] == id) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String? _edgeDelay(String fromId, String toId) {
    if (_graphData == null) return null;
    final edges = _graphData!['edges'] as List;
    try {
      final edge = edges.firstWhere(
          (e) => e['from'] == fromId && e['to'] == toId);
      return edge['delay'] as String?;
    } catch (_) {
      return null;
    }
  }

  String? _edgeRelation(String fromId, String toId) {
    if (_graphData == null) return null;
    final edges = _graphData!['edges'] as List;
    try {
      final edge = edges.firstWhere(
          (e) => e['from'] == fromId && e['to'] == toId);
      return edge['type'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _formatTime(String? publishedAt) {
    if (publishedAt == null) return '';
    try {
      final dt = DateTime.parse(publishedAt).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Граф распространения',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // Заголовок
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title,
                              style: const TextStyle(
                                color: Color(0xFF1A1208),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(Icons.hub,
                                size: 14, color: Color(0xFF1A1208)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _graphData?['summary'] ?? '',
                                style: const TextStyle(
                                  color: Color(0xFF1A1208),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFE0D8CC)),

                    // Граф
                    Expanded(
                      child: _graph.nodeCount() <= 1
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Новость не найдена\nв отслеживаемых источниках',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : InteractiveViewer(
                              constrained: false,
                              boundaryMargin: const EdgeInsets.all(80),
                              minScale: 0.3,
                              maxScale: 2.0,
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: GraphView(
                                  graph: _graph,
                                  algorithm: BuchheimWalkerAlgorithm(
                                      _config,
                                      TreeEdgeRenderer(_config)),
                                  paint: Paint()
                                    ..color = const Color(0xFFBBB0A0)
                                    ..strokeWidth = 1.5
                                    ..style = PaintingStyle.stroke,
                                  builder: (node) {
                                    final id =
                                        node.key!.value as String;
                                    final data = _nodeData(id);
                                    final trust =
                                        (data?['trust'] as num?)
                                                ?.toDouble() ??
                                            0.5;
                                    final isOriginal =
                                        data?['is_original'] == true;
                                    final label = data?['label'] ?? id;
                                    final publishedAt =
                                        data?['published_at'] as String?;
                                    final color = _trustColor(trust);
                                    final timeStr =
                                        _formatTime(publishedAt);

                                    // Ищем delay и relation для этого узла
                                    String? delay;
                                    String? relation;
                                    if (!isOriginal && _graphData != null) {
                                      final orig = (_graphData!['nodes'] as List)
                                          .firstWhere(
                                              (n) => n['is_original'] == true,
                                              orElse: () => null);
                                      if (orig != null) {
                                        delay = _edgeDelay(orig['id'] as String, id);
                                        relation = _edgeRelation(orig['id'] as String, id);
                                      }
                                    }
                                    final isCited = relation == 'cited' || relation == 'both';

                                    return Container(
                                      constraints: const BoxConstraints(
                                          maxWidth: 130),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isOriginal
                                            ? const Color(0xFF1A1208)
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isOriginal
                                              ? const Color(0xFF1A1208)
                                              : color.withOpacity(0.5),
                                          width: isOriginal ? 0 : 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.08),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isOriginal) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        3),
                                              ),
                                              child: const Text(
                                                  'ПЕРВОИСТОЧНИК',
                                                  style: TextStyle(
                                                    fontSize: 7,
                                                    color: Colors.white70,
                                                    letterSpacing: 0.8,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  )),
                                            ),
                                            const SizedBox(height: 4),
                                          ],
                                          Text(
                                            label.toString(),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: isOriginal
                                                  ? Colors.white
                                                  : const Color(
                                                      0xFF1A1208),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: isOriginal
                                                      ? Colors.white54
                                                      : color,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${(trust * 100).toInt()}%',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isOriginal
                                                      ? Colors.white70
                                                      : color,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Время публикации
                                          if (timeStr.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(timeStr,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: isOriginal
                                                      ? Colors.white38
                                                      : Colors.grey[400],
                                                )),
                                          ],
                                          // Задержка от первоисточника
                                          if (delay != null) ...[
                                            const SizedBox(height: 2),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(delay,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: color,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  )),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                    ),

                    // Легенда
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _legendItem(const Color(0xFF43A047), 'Надёжный'),
                          const SizedBox(width: 20),
                          _legendItem(
                              const Color(0xFFFB8C00), 'Нейтральный'),
                          const SizedBox(width: 20),
                          _legendItem(
                              const Color(0xFFE53935), 'Ненадёжный'),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
