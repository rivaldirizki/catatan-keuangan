import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiClient {
  final String baseUrl;
  String? _authToken;
  final Duration timeoutDuration;

  ApiClient({String? customBaseUrl, Duration? timeout})
      : baseUrl = customBaseUrl ?? ApiConstants.baseUrl,
        timeoutDuration = timeout ?? const Duration(seconds: 15);

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

    final response = await http.get(uri, headers: _headers()).timeout(
      timeoutDuration,
      onTimeout: () => throw Exception('Koneksi internet lambat atau batas waktu habis (15 detik).'),
    );
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(
      timeoutDuration,
      onTimeout: () => throw Exception('Koneksi internet lambat atau batas waktu habis (15 detik).'),
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.put(
      uri,
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(
      timeoutDuration,
      onTimeout: () => throw Exception('Koneksi internet lambat atau batas waktu habis (15 detik).'),
    );
    return _handleResponse(response);
  }

  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(
      timeoutDuration,
      onTimeout: () => throw Exception('Koneksi internet lambat atau batas waktu habis (15 detik).'),
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.delete(
      uri,
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(
      timeoutDuration,
      onTimeout: () => throw Exception('Koneksi internet lambat atau batas waktu habis (15 detik).'),
    );
    return _handleResponse(response);
  }

  Future<dynamic> postMultipart(
    String endpoint,
    File? file, {
    Uint8List? bytes,
    String? filename,
    String fileField = 'file',
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri);
    if (_authToken != null) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }

    if (bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        bytes,
        filename: filename ?? 'upload.bin',
      ));
    } else if (file != null) {
      if (kIsWeb) {
        final fileBytes = await file.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: filename ?? file.path.split(RegExp(r'[/\\]')).last,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(fileField, file.path, filename: filename));
      }
    }

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw Exception('Upload file batas waktu habis (45 detik).'),
    );
    final response = await http.Response.fromStream(streamedResponse);
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
