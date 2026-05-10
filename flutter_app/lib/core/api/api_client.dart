import 'package:dio/dio.dart';

class ApiClient {
  static const String baseUrl = 'http://127.0.0.1:8000';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Future<Map<String, dynamic>> analyze({String? text, String? url}) async {
    final response = await _dio.post('/api/analyze', data: {
      if (text != null) 'text': text,
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

  Future<List<dynamic>> getSources() async {
    final response = await _dio.get('/api/sources');
    return response.data['sources'];
  }

  Future<Map<String, dynamic>> getGraph({String? url, required String title}) async {
    final params = <String, dynamic>{'title': title};
    if (url != null) params['url'] = url;
    final response = await _dio.get('/api/graph', queryParameters: params);
    return response.data;
  }

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

  Future<void> deleteUserSource(String id) async {
    await _dio.delete('/api/sources/user/$id');
  }
}
