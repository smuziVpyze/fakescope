import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';

class GraphScreen extends StatefulWidget {
  final String? url;
  final String title;
  final String? publishedAt;

  const GraphScreen({super.key, this.url, required this.title, this.publishedAt});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _graphData;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _selectedNode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getGraph(url: widget.url, title: widget.title, publishedAt: widget.publishedAt);
      setState(() {
        _graphData = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _trustColor(double trust) {
    if (trust >= 0.8) return const Color(0xFF43A047);
    if (trust >= 0.6) return const Color(0xFFFB8C00);
    return const Color(0xFFE53935);
  }

  String _formatDateTime(String? publishedAt) {
    if (publishedAt == null) return '';
    try {
      final dt = DateTime.parse(publishedAt).toLocal();
      final months = ['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'];
      return '${dt.day} ${months[dt.month-1]}, ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
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
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final nodes = (_graphData!['nodes'] as List).cast<Map<String, dynamic>>();
    final original = nodes.firstWhere((n) => n['is_original'] == true, orElse: () => nodes.first);
    final reposts = nodes.where((n) => n['is_original'] != true).toList()
      ..sort((a, b) {
        final da = a['published_at'] as String?;
        final db = b['published_at'] as String?;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    return Column(
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.hub, size: 14, color: Color(0xFF1A1208)),
                const SizedBox(width: 4),
                Expanded(child: Text(_graphData?['summary'] ?? '',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE0D8CC)),

        Expanded(
          child: reposts.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('Перепечаток не найдено', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                  ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Первоисточник
                      _buildOriginalCard(original),

                      // Перепечатки вертикально со стрелками
                      ...reposts.map((n) => Column(children: [
                        _buildArrow(),
                        _buildRepostCard(n),
                      ])).toList(),

                      const SizedBox(height: 24),

                      // Легенда
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _legendDot(const Color(0xFF43A047), 'Надёжный'),
                        const SizedBox(width: 16),
                        _legendDot(const Color(0xFFFB8C00), 'Нейтральный'),
                        const SizedBox(width: 16),
                        _legendDot(const Color(0xFFE53935), 'Ненадёжный'),
                      ]),
                    ],
                  ),
                ),
        ),

        // Панель выбранного узла
        if (_selectedNode != null) _buildNodePanel(_selectedNode!),
      ],
    );
  }

  Widget _buildOriginalCard(Map<String, dynamic> node) {
    final trust = (node['trust'] as num?)?.toDouble() ?? 0.5;
    final trustKnown = node['trust_known'] as bool? ?? false;
    final color = _trustColor(trust);
    return GestureDetector(
      onTap: () => setState(() => _selectedNode = _selectedNode == node ? null : node),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1208),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
          border: _selectedNode == node ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('ПЕРВОИСТОЧНИК', style: TextStyle(fontSize: 9, color: Colors.white70, letterSpacing: 1, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          Text(node['label'] ?? '', textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          if (trustKnown) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('${(trust * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          if (node['published_at'] != null) ...[
            const SizedBox(height: 4),
            Text(_formatDateTime(node['published_at'] as String?),
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ]),
      ),
    );
  }

  Widget _buildArrow() {
    return Column(children: [
      Container(width: 2, height: 16, color: const Color(0xFFBBB0A0)),
      CustomPaint(
        size: const Size(14, 10),
        painter: _ArrowPainter(),
      ),
      const SizedBox(height: 4),
    ]);
  }

  Widget _buildRepostCard(Map<String, dynamic> node) {
    final trust = (node['trust'] as num?)?.toDouble() ?? 0.5;
    final trustKnown = node['trust_known'] as bool? ?? false;
    final color = _trustColor(trust);
    final delay = _getDelay(node['id'] as String);
    final isSelected = _selectedNode == node;

    return GestureDetector(
      onTap: () => setState(() => _selectedNode = isSelected ? null : node),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1A1208)
                : trustKnown
                    ? color.withOpacity(0.4)
                    : Colors.grey.shade300,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          Text(node['label'] ?? '', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A1208)),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          if (trustKnown) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('${(trust * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
          if (node['published_at'] != null) ...[
            const SizedBox(height: 4),
            Text(_formatDateTime(node['published_at'] as String?),
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
          if (delay != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(delay, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }

  String? _getDelay(String nodeId) {
    if (_graphData == null) return null;
    final edges = _graphData!['edges'] as List;
    try {
      final edge = edges.firstWhere((e) => e['to'] == nodeId);
      return edge['delay'] as String?;
    } catch (_) { return null; }
  }

  Widget _buildNodePanel(Map<String, dynamic> node) {
    final trust = (node['trust'] as num?)?.toDouble() ?? 0.5;
    final color = _trustColor(trust);
    final url = node['url'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(node['label'] ?? '',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1A1208)))),
          GestureDetector(
            onTap: () => setState(() => _selectedNode = null),
            child: const Icon(Icons.close, size: 20, color: Color(0xFF1A1208)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(node['id'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 8),
        if (node['trust_known'] as bool? ?? false) Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Надёжность: ${(trust * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)),
        ]),
        if (node['published_at'] != null) ...[
          const SizedBox(height: 4),
          Text('Опубликовано: ${_formatDateTime(node['published_at'] as String?)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
        if (url != null && url.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(url, style: const TextStyle(fontSize: 11, color: Color(0xFF1565C0),
                decoration: TextDecoration.underline), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ]),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBBB0A0)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    // Стрелка вниз ↓
    canvas.drawLine(Offset(cx - 6, 0), Offset(cx, size.height), paint);
    canvas.drawLine(Offset(cx + 6, 0), Offset(cx, size.height), paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}
