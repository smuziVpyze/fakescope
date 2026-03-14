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
}
