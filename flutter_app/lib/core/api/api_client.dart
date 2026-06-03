import 'package:dio/dio.dart';

class ApiClient {
  static const String baseUrl = 'http://127.0.0.1:8000';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 120),
  ));

  Future<Map<String, dynamic>> analyze({String? text, String? url, String? title}) async {
    final response = await _dio.post('/api/analyze', data: {
      if (text != null) 'text': text, if (title != null) 'title': title,
      if (url != null) 'url': url,
    });
    return response.data;
  }

  Future<List<dynamic>> getHistory() async {
    final response = await _dio.get('/api/history');
    return response.data;
  }

  Future<List<dynamic>> getFeed({bool refresh = false}) async {
    final response = await _dio.get('/api/feed',
        queryParameters: refresh ? {'refresh': true} : null);
    return response.data['articles'];
  }

  Future<Map<String, dynamic>> getDomainStats(String domain) async {
    final response = await _dio.get('/api/domains/$domain/stats');
    return response.data;
  }

  Future<Map<String, dynamic>> getGraph({String? url, required String title, String? publishedAt}) async {
    final params = <String, dynamic>{'title': title};
    if (url != null) params['url'] = url;
    if (publishedAt != null) params['published_at'] = publishedAt;
    final response = await _dio.get('/api/graph', queryParameters: params);
    return response.data;
  }

  // ── Встроенные источники ──────────────────────────────────────────────────

  Future<List<dynamic>> getBuiltinSources() async {
    final response = await _dio.get('/api/sources');
    return response.data['sources'];
  }

  Future<Map<String, dynamic>> toggleBuiltinSource(String domain) async {
    final response = await _dio.patch('/api/sources/builtin/$domain/toggle');
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> setBuiltinTrust(String domain, double trustScore) async {
    final response = await _dio.patch(
      '/api/sources/builtin/$domain/trust',
      data: {'trust_score': trustScore},
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> resetBuiltinTrust(String domain) async {
    await _dio.delete('/api/sources/builtin/$domain/trust');
  }

  // ── Пользовательские источники ────────────────────────────────────────────

  Future<List<dynamic>> getUserSources() async {
    final response = await _dio.get('/api/sources/user');
    return response.data['sources'];
  }

  Future<Map<String, dynamic>> addUserSource({
    required String name,
    required String domain,
    String? rssUrl,
  }) async {
    final response = await _dio.post('/api/sources/user', data: {
      'name': name,
      'domain': domain,
      if (rssUrl != null) 'rss_url': rssUrl,
    });
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> toggleUserSource(String id) async {
    await _dio.patch('/api/sources/user/$id/toggle');
  }

  Future<Map<String, dynamic>> setUserTrust(String id, double trustScore) async {
    final response = await _dio.patch(
      '/api/sources/user/$id/trust',
      data: {'trust_score': trustScore},
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> resetUserTrust(String id) async {
    await _dio.delete('/api/sources/user/$id/trust');
  }

  Future<void> deleteUserSource(String id) async {
    await _dio.delete('/api/sources/user/$id');
  }
}
