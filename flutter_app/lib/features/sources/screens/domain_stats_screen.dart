import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/api/api_client.dart';
import '../../../core/models/domain_stats.dart';

class DomainStatsScreen extends StatefulWidget {
  final String domain;
  final String name;

  const DomainStatsScreen({super.key, required this.domain, required this.name});

  @override
  State<DomainStatsScreen> createState() => _DomainStatsScreenState();
}

class _DomainStatsScreenState extends State<DomainStatsScreen> {
  final _api = ApiClient();
  DomainStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await _api.getDomainStats(widget.domain);
      setState(() {
        _stats = DomainStats.fromJson(json);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final s = _stats!;
    final effectiveTrust = s.userTrustScore ?? s.trustScoreDynamic ?? s.trustScore;
    final color = _trustColor(effectiveTrust);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trust score карточка
          _buildTrustCard(s, effectiveTrust, color),
          const SizedBox(height: 16),

          // Pie chart вердиктов
          if (s.totalAnalyses > 0) ...[
            _buildVerdictsCard(s),
            const SizedBox(height: 16),
          ],

          // Тренд
          if (s.trend.isNotEmpty) ...[
            _buildTrendCard(s),
            const SizedBox(height: 16),
          ],

          // Нет данных
          if (s.totalAnalyses == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: [
                Icon(Icons.info_outline, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text('Нет данных об анализах для этого домена',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildTrustCard(DomainStats s, double trust, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.domain, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Center(child: Text('${(trust * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color))),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Рейтинг надёжности',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: trust,
                minHeight: 8,
                backgroundColor: Colors.grey[100],
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 6),
            if (s.known)
              Text(
                s.userTrustScore != null
                    ? 'Вы установили: ${(s.userTrustScore! * 100).toStringAsFixed(0)}%${s.trustScoreDynamic != null ? " · Рекомендуемый: ${(s.trustScoreDynamic! * 100).toStringAsFixed(0)}% (на основе ${s.totalAnalyses} анализов)" : ""}'
                    : 'Базовый: ${(s.trustScore * 100).toStringAsFixed(0)}%${s.trustScoreDynamic != null ? " · Рекомендуемый: ${(s.trustScoreDynamic! * 100).toStringAsFixed(0)}% (на основе ${s.totalAnalyses} анализов)" : ""}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _statChip('${s.totalAnalyses}', 'анализов', const Color(0xFF1A1208)),
          const SizedBox(width: 8),
          if (s.avgConfidence != null)
            _statChip('${(s.avgConfidence! * 100).toStringAsFixed(0)}%', 'ср. уверенность', Colors.grey),
        ]),
      ]),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
      ]),
    );
  }

  Widget _buildVerdictsCard(DomainStats s) {
    final total = s.totalAnalyses;
    final trueCount = s.verdicts['true'] ?? 0;
    final fakeCount = s.verdicts['fake'] ?? 0;
    final unverifiedCount = s.verdicts['unverified'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Распределение вердиктов',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1208))),
        const SizedBox(height: 20),
        Row(children: [
          SizedBox(
            width: 120, height: 120,
            child: CustomPaint(
              painter: _PieChartPainter(
                trueRatio: trueCount / total,
                fakeRatio: fakeCount / total,
                unverifiedRatio: unverifiedCount / total,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _legendRow('Достоверно', trueCount, total, const Color(0xFF43A047)),
            const SizedBox(height: 10),
            _legendRow('Не верифицировано', unverifiedCount, total, const Color(0xFFFB8C00)),
            const SizedBox(height: 10),
            _legendRow('Фейк', fakeCount, total, const Color(0xFFE53935)),
          ])),
        ]),
      ]),
    );
  }

  Widget _legendRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
      Text('$count ($pct%)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ]);
  }

  String _formatShortDate(String date) {
    try {
      final dt = DateTime.parse(date);
      final months = ['янв','фев','мар','апр','мая','июн','июл','авг','сен','окт','ноя','дек'];
      return '${dt.day} ${months[dt.month-1]}';
    } catch (_) { return date.substring(5); }
  }

  Widget _buildTrendCard(DomainStats s) {
    // Строим карту дата -> точка
    final Map<String, TrendPoint> trendMap = {for (var t in s.trend) t.date: t};
    
    // Генерируем все 30 дней
    final now = DateTime.now();
    final allDays = List.generate(30, (i) {
      final day = now.subtract(Duration(days: 29 - i));
      return '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
    });

    final maxCount = s.trend.isEmpty ? 1 : s.trend.map((t) => t.count).reduce(math.max).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Активность за 30 дней',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1208))),
          Text('${s.totalAnalyses} анализов',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: allDays.map((date) {
              final point = trendMap[date];
              if (point == null) {
                return Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(height: 3, color: Colors.grey[200]),
                ));
              }
              final total = point.count.toDouble();
              final trueH = (point.trueCount / total) * 70;
              final unverH = (point.unverifiedCount / total) * 70;
              final fakeH = (point.fakeCount / total) * 70;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (fakeH > 0) Container(height: fakeH,
                        decoration: BoxDecoration(color: const Color(0xFFE53935).withOpacity(0.8),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)))),
                      if (unverH > 0) Container(height: unverH,
                        color: const Color(0xFFFB8C00).withOpacity(0.8)),
                      if (trueH > 0) Container(height: trueH,
                        decoration: BoxDecoration(color: const Color(0xFF43A047).withOpacity(0.8),
                          borderRadius: BorderRadius.vertical(
                            top: fakeH == 0 && unverH == 0 ? const Radius.circular(2) : Radius.zero,
                            bottom: const Radius.circular(2)))),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_formatShortDate(allDays.first), style: TextStyle(fontSize: 10, color: Colors.grey[400])),
          Text('сегодня', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF43A047).withOpacity(0.8), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text('достоверно', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(width: 12),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFFB8C00).withOpacity(0.8), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text('смешанно', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(width: 12),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFE53935).withOpacity(0.8), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text('фейки', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ]),
      ]),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final double trueRatio;
  final double fakeRatio;
  final double unverifiedRatio;

  _PieChartPainter({required this.trueRatio, required this.fakeRatio, required this.unverifiedRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final segments = [
      (trueRatio, const Color(0xFF43A047)),
      (unverifiedRatio, const Color(0xFFFB8C00)),
      (fakeRatio, const Color(0xFFE53935)),
    ];

    double startAngle = -math.pi / 2;
    for (final (ratio, color) in segments) {
      if (ratio <= 0) continue;
      final sweepAngle = ratio * 2 * math.pi;
      final paint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }

    // Дырка в центре
    canvas.drawCircle(center, radius * 0.55,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_PieChartPainter old) => false;
}
