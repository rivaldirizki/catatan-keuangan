import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiClient {
  final String baseUrl;
  String? _authToken;

  ApiClient({String? customBaseUrl}) : baseUrl = customBaseUrl ?? ApiConstants.baseUrl;

  void setToken(String? token) {
    _authToken = token;
  }

  Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final response = await http.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final dynamic data = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      final message = data is Map && data['error'] != null ? data['error'] : 'HTTP ${response.statusCode} error';
      throw Exception(message);
    }
  }
}
