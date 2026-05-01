import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final _api = ApiClient();
  List<dynamic> _sources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getSources();
      setState(() {
        _sources = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Color _trustColor(double score) {
    if (score >= 0.8) return const Color(0xFF43A047);
    if (score >= 0.6) return const Color(0xFFFB8C00);
    return const Color(0xFFE53935);
  }

  String _trustEmoji(double score) {
    if (score >= 0.8) return '🟢';
    if (score >= 0.6) return '🟡';
    return '🔴';
  }

  String _trustLabel(double score) {
    if (score >= 0.8) return 'Надёжный';
    if (score >= 0.6) return 'Нейтральный';
    return 'Ненадёжный';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        title: const Text('Источники',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF1A1208),
                child: const Text(
                  'Рейтинг доверия основан на редакционных стандартах, '
                  'прозрачности и истории публикаций.',
                  style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFEDE8DF),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _legendItem('🟢', 'Надёжный', '80–100%'),
                    _legendItem('🟡', 'Нейтральный', '60–79%'),
                    _legendItem('🔴', 'Осторожно', '< 60%'),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sources.length,
                  itemBuilder: (context, index) {
                    final s = _sources[index];
                    final score = (s['trust_score'] as num).toDouble();
                    final color = _trustColor(score);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                        )],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  Text(_trustEmoji(score),
                                    style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Text(s['name'],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1208),
                                    )),
                                ]),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${(score * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(s['domain'],
                              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: score),
                                duration: Duration(milliseconds: 600 + index * 50),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) =>
                                  LinearProgressIndicator(
                                    value: value,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey[100],
                                    valueColor: AlwaysStoppedAnimation(color),
                                  ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_trustLabel(score),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600,
                              )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }

  Widget _legendItem(String emoji, String label, String range) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A1208))),
        Text(range, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ]),
    ]);
  }
}
