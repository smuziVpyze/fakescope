import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../../../core/api/api_client.dart';

class GraphScreen extends StatefulWidget {
  final String url;
  final String title;

  const GraphScreen({super.key, required this.url, required this.title});

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
    ..siblingSeparation = 60
    ..levelSeparation = 80
    ..subtreeSeparation = 60
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
      backgroundColor: const Color(0xFF0e1420),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        title: const Text('Граф распространения',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : Column(
              children: [
                // Заголовок новости
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF141b2d),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(_graphData?['summary'] ?? '',
                        style: const TextStyle(color: Color(0xFF00e5ff), fontSize: 12)),
                    ],
                  ),
                ),

                // Граф
                Expanded(
                  child: _graph.nodeCount() <= 1
                    ? const Center(
                        child: Text('Перепечаток не найдено',
                          style: TextStyle(color: Colors.white54, fontSize: 14)))
                    : InteractiveViewer(
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(100),
                        minScale: 0.3,
                        maxScale: 2.0,
                        child: GraphView(
                          graph: _graph,
                          algorithm: BuchheimWalkerAlgorithm(
                            _config,
                            TreeEdgeRenderer(_config),
                          ),
                          paint: Paint()
                            ..color = const Color(0xFF00e5ff)
                            ..strokeWidth = 1.5
                            ..style = PaintingStyle.stroke,
                          builder: (node) {
                            final id = node.key!.value as String;
                            final data = _nodeData(id);
                            final trust = (data?['trust'] as num?)?.toDouble() ?? 0.5;
                            final isOriginal = data?['is_original'] == true;
                            final label = data?['label'] ?? id;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isOriginal
                                  ? const Color(0xFF00e5ff).withOpacity(0.15)
                                  : _trustColor(trust).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isOriginal
                                    ? const Color(0xFF00e5ff)
                                    : _trustColor(trust),
                                  width: isOriginal ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isOriginal)
                                    const Text('ИСТОЧНИК',
                                      style: TextStyle(fontSize: 8, color: Color(0xFF00e5ff), letterSpacing: 0.5)),
                                  Text(label.toString(),
                                    style: TextStyle(
                                      color: isOriginal ? const Color(0xFF00e5ff) : Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    )),
                                  Text('${(trust * 100).toInt()}% доверие',
                                    style: TextStyle(fontSize: 9, color: _trustColor(trust))),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                ),

                // Легенда
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFF141b2d),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legend(const Color(0xFF43A047), 'Надёжный'),
                      const SizedBox(width: 16),
                      _legend(const Color(0xFFFB8C00), 'Нейтральный'),
                      const SizedBox(width: 16),
                      _legend(const Color(0xFFE53935), 'Ненадёжный'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
