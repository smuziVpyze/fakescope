import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  late final TabController _tabController;

  List<Map<String, dynamic>> _builtinSources = [];
  bool _builtinLoading = true;

  List<Map<String, dynamic>> _userSources = [];
  bool _userLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBuiltin();
    _loadUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBuiltin() async {
    try {
      final data = await _api.getBuiltinSources();
      setState(() {
        _builtinSources = List<Map<String, dynamic>>.from(data);
        _builtinLoading = false;
      });
    } catch (e) {
      setState(() => _builtinLoading = false);
    }
  }

  Future<void> _loadUser() async {
    try {
      final data = await _api.getUserSources();
      setState(() {
        _userSources = List<Map<String, dynamic>>.from(data);
        _userLoading = false;
      });
    } catch (e) {
      setState(() => _userLoading = false);
    }
  }

  Future<void> _toggleBuiltin(String domain, bool currentEnabled) async {
    final idx = _builtinSources.indexWhere((s) => s['domain'] == domain);
    if (idx != -1) setState(() => _builtinSources[idx]['enabled'] = !currentEnabled);
    try {
      await _api.toggleBuiltinSource(domain);
    } catch (_) {
      if (idx != -1) setState(() => _builtinSources[idx]['enabled'] = currentEnabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось изменить источник')),
        );
      }
    }
  }

  void _showTrustDialog({
    required String name,
    required double baseTrust,
    required double currentTrust,
    required bool hasCustom,
    required Future<void> Function(double) onSave,
    required Future<void> Function() onReset,
    required void Function(double) onLocalUpdate,
  }) {
    double sliderValue = currentTrust;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Рейтинг: $name',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1208))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Базовый рейтинг: ${(baseTrust * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ваш рейтинг',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[700])),
                  Text(
                    '${(sliderValue * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _trustColor(sliderValue)),
                  ),
                ],
              ),
              Slider(
                value: sliderValue,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                activeColor: _trustColor(sliderValue),
                onChanged: (v) => setModalState(() => sliderValue = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ненадёжный', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  Text('Надёжный', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(height: 24),
              Row(children: [
                if (hasCustom) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await onReset();
                        onLocalUpdate(baseTrust);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1A1208)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Сбросить',
                          style: TextStyle(
                              color: Color(0xFF1A1208),
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await onSave(sliderValue);
                      onLocalUpdate(sliderValue);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1208),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Сохранить',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleUserSource(String id, bool currentEnabled) async {
    final idx = _userSources.indexWhere((s) => s['id'] == id);
    if (idx != -1) setState(() => _userSources[idx]['enabled'] = !currentEnabled);
    try {
      await _api.toggleUserSource(id);
    } catch (_) {
      if (idx != -1) setState(() => _userSources[idx]['enabled'] = currentEnabled);
    }
  }

  Future<void> _deleteUserSource(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить источник?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить',
                  style: TextStyle(color: Color(0xFFE53935)))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _userSources.removeWhere((s) => s['id'] == id));
    try {
      await _api.deleteUserSource(id);
    } catch (_) {
      _loadUser();
    }
  }

  void _showAddSourceDialog() {
    final nameCtrl = TextEditingController();
    final domainCtrl = TextEditingController();
    final rssCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Добавить источник',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1208))),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: _inputDecoration('Название', 'Например: Медиазона'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Введите название' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: domainCtrl,
                    decoration: _inputDecoration('Домен', 'Например: zona.media'),
                    keyboardType: TextInputType.url,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Введите домен';
                      if (!v.contains('.')) return 'Некорректный домен';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: rssCtrl,
                    decoration: _inputDecoration(
                        'RSS-лента (необязательно)', 'https://...rss.xml'),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => saving = true);
                              try {
                                final newSource = await _api.addUserSource(
                                  name: nameCtrl.text.trim(),
                                  domain: domainCtrl.text.trim(),
                                  rssUrl: rssCtrl.text.trim().isEmpty
                                      ? null
                                      : rssCtrl.text.trim(),
                                );
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                setState(() => _userSources.insert(0, newSource));
                                _tabController.animateTo(1);
                              } catch (e) {
                                setModalState(() => saving = false);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Ошибка: $e'),
                                      backgroundColor: const Color(0xFFE53935)),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1208),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Добавить',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFFF5F0E8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1A1208), width: 1.5),
      ),
    );
  }

  Color _trustColor(double score) {
    if (score >= 0.75) return const Color(0xFF43A047);
    if (score >= 0.5)  return const Color(0xFFFB8C00);
    return const Color(0xFFE53935);
  }

  String _trustEmoji(double score) {
    if (score >= 0.75) return '🟢';
    if (score >= 0.5)  return '🟡';
    return '🔴';
  }

  String _trustLabel(double score) {
    if (score >= 0.75) return 'Надёжный';
    if (score >= 0.5)  return 'Нейтральный';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddSourceDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Встроенные (${_builtinSources.length})'),
            Tab(text: 'Мои (${_userSources.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _builtinLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _builtinSources.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _builtinHeader();
                    final s = _builtinSources[index - 1];
                    final score = (s['effective_trust_score'] as num).toDouble();
                    final enabled = s['enabled'] as bool? ?? true;
                    return _builtinCard(s, score, enabled);
                  },
                ),
          _userLoading
              ? const Center(child: CircularProgressIndicator())
              : _userSources.isEmpty
                  ? _emptyUserState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _userSources.length,
                      itemBuilder: (context, index) {
                        final s = _userSources[index];
                        return _userSourceCard(s);
                      },
                    ),
        ],
      ),

    );
  }

  Widget _builtinHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1208).withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1A1208).withOpacity(0.15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Color(0xFF1A1208)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Нажмите на % чтобы изменить рейтинг. Переключатель скрывает источник из ленты.',
              style: TextStyle(fontSize: 12, color: Color(0xFF1A1208), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _builtinCard(Map<String, dynamic> s, double score, bool enabled) {
    final color = _trustColor(score);
    final hasCustom = s['user_trust_score'] != null;
    final baseTrust = (s['base_trust_score'] as num).toDouble();

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: enabled ? null : Border.all(color: Colors.grey.shade300),
          boxShadow: enabled
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]
              : null,
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
                            color: Color(0xFF1A1208))),
                  ]),
                  GestureDetector(
                    onTap: () => _showTrustDialog(
                      name: s['name'],
                      baseTrust: baseTrust,
                      currentTrust: score,
                      hasCustom: hasCustom,
                      onSave: (v) => _api.setBuiltinTrust(s['domain'], v),
                      onReset: () => _api.resetBuiltinTrust(s['domain']),
                      onLocalUpdate: (v) {
                        final idx = _builtinSources
                            .indexWhere((x) => x['domain'] == s['domain']);
                        if (idx != -1) {
                          setState(() {
                            _builtinSources[idx]['effective_trust_score'] = v;
                            _builtinSources[idx]['user_trust_score'] =
                                v == baseTrust ? null : v;
                          });
                        }
                      },
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: hasCustom
                            ? Border.all(
                                color: color.withOpacity(0.4), width: 1.5)
                            : null,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          '${(score * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: color),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit, size: 12, color: color),
                      ]),
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
                child: LinearProgressIndicator(
                  value: score,
                  minHeight: 8,
                  backgroundColor: Colors.grey[100],
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Text(_trustLabel(score),
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600)),
                    if (hasCustom) ...[
                      const SizedBox(width: 6),
                      Text('· изменён вами',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[400])),
                    ],
                  ]),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: enabled,
                      activeColor: const Color(0xFF43A047),
                      onChanged: (_) =>
                          _toggleBuiltin(s['domain'], enabled),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userSourceCard(Map<String, dynamic> s) {
    final enabled = s['enabled'] as bool? ?? true;
    final score = (s['effective_trust_score'] as num).toDouble();
    final baseTrust = (s['base_trust_score'] as num).toDouble();
    final hasCustom = s['user_trust_score'] != null;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: enabled ? null : Border.all(color: Colors.grey.shade300),
          boxShadow: enabled
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1208).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    (s['name'] as String).substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1208)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['name'],
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1208))),
                    const SizedBox(height: 2),
                    Text(s['domain'],
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500])),
                    if (s['rss_url'] != null &&
                        (s['rss_url'] as String).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.rss_feed,
                            size: 11, color: Colors.orange[400]),
                        const SizedBox(width: 3),
                        Text('RSS подключён',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[600],
                                fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showTrustDialog(
                  name: s['name'],
                  baseTrust: baseTrust,
                  currentTrust: score,
                  hasCustom: hasCustom,
                  onSave: (v) => _api.setUserTrust(s['id'], v),
                  onReset: () => _api.resetUserTrust(s['id']),
                  onLocalUpdate: (v) {
                    final idx =
                        _userSources.indexWhere((x) => x['id'] == s['id']);
                    if (idx != -1) {
                      setState(() {
                        _userSources[idx]['effective_trust_score'] = v;
                        _userSources[idx]['user_trust_score'] =
                            v == baseTrust ? null : v;
                      });
                    }
                  },
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _trustColor(score).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: hasCustom
                        ? Border.all(
                            color: _trustColor(score).withOpacity(0.4),
                            width: 1.5)
                        : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '${(score * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _trustColor(score)),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.edit, size: 11, color: _trustColor(score)),
                  ]),
                ),
              ),
              Switch(
                value: enabled,
                activeColor: const Color(0xFF43A047),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (_) => _toggleUserSource(s['id'], enabled),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: Color(0xFFE53935)),
                onPressed: () => _deleteUserSource(s['id']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyUserState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1208).withOpacity(0.06),
                borderRadius: BorderRadius.circular(40),
              ),
              child:
                  const Icon(Icons.add_link, size: 36, color: Color(0xFF1A1208)),
            ),
            const SizedBox(height: 20),
            const Text('Нет добавленных источников',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1208))),
            const SizedBox(height: 8),
            Text(
              'Добавьте свои источники новостей.\nМожно отключить любой источник — он не будет показан в ленте.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddSourceDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Добавить источник',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1208),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
