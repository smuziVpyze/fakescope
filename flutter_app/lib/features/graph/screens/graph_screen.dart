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

  final Graph _graph = Graph()..isTree = false;
  final BuchheimWalkerConfiguration _config = BuchheimWalkerConfiguration()
    ..siblingSeparation = 50
    ..levelSeparation = 80
    ..subtreeSeparation = 50
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
    final Map<String, Node> nodeMap = {};

    for (final n in nodes) {
      final node = Node.Id(n['id']);
      nodeMap[n['id'] as String] = node;
      _graph.addNode(node);
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Граф распространения',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : Column(
              children: [

                // Заголовок новости
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
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.hub, size: 14, color: Color(0xFF1A1208)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(_graphData?['summary'] ?? '',
                            style: const TextStyle(
                              color: Color(0xFF1A1208),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ))),
                        ],
                      ),
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
                            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('Новость не найдена\nв отслеживаемых источниках',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                          ],
                        ))
                    : InteractiveViewer(
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(80),
                        minScale: 0.4,
                        maxScale: 2.0,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: GraphView(
                            graph: _graph,
                            algorithm: BuchheimWalkerAlgorithm(
                              _config, TreeEdgeRenderer(_config)),
                            paint: Paint()
                              ..color = const Color(0xFFBBB0A0)
                              ..strokeWidth = 1.5
                              ..style = PaintingStyle.stroke,
                            builder: (node) {
                              final id = node.key!.value as String;
                              final data = _nodeData(id);
                              final trust = (data?['trust'] as num?)?.toDouble() ?? 0.5;
                              final isOriginal = data?['is_original'] == true;
                              final label = data?['label'] ?? id;
                              final publishedAt = data?['published_at'] as String?;
                              final color = _trustColor(trust);

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isOriginal
                                    ? const Color(0xFF1A1208)
                                    : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isOriginal
                                      ? const Color(0xFF1A1208)
                                      : color.withOpacity(0.5),
                                    width: isOriginal ? 0 : 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text('ПЕРВОИСТОЧНИК',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.white70,
                                            letterSpacing: 0.8,
                                            fontWeight: FontWeight.w600,
                                          )),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(label.toString(),
                                      style: TextStyle(
                                        color: isOriginal ? Colors.white : const Color(0xFF1A1208),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      )),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6, height: 6,
                                          decoration: BoxDecoration(
                                            color: isOriginal ? Colors.white54 : color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text('${(trust * 100).toInt()}%',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isOriginal ? Colors.white70 : color,
                                            fontWeight: FontWeight.w600,
                                          )),
                                      ],
                                    ),
                                    if (publishedAt != null) ...[
                                      const SizedBox(height: 2),
                                      Text(_formatTime(publishedAt),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isOriginal ? Colors.white38 : Colors.grey[400],
                                        )),
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
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE0D8CC))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legend(const Color(0xFF43A047), 'Надёжный'),
                      const SizedBox(width: 20),
                      _legend(const Color(0xFFFB8C00), 'Нейтральный'),
                      const SizedBox(width: 20),
                      _legend(const Color(0xFFE53935), 'Ненадёжный'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
      ],
    );
  }
}
