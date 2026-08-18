import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MindWellApiClient {
  MindWellApiClient({required String baseUrl, http.Client? httpClient})
    : _baseUri = _normalizeBase(baseUrl),
      _client = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  static Uri _normalizeBase(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse(trimmed.isEmpty ? 'http://127.0.0.1:8000' : trimmed);
  }

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return _baseUri.replace(
      path: '${_baseUri.path}$normalizedPath',
      queryParameters: query?.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
    );
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final response = await _client.get(
      _buildUri(path, query),
      headers: _buildHeaders(headers),
    );
    return _decode(response);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final response = await _client.get(
      _buildUri(path, query),
      headers: _buildHeaders(headers),
    );
    final decoded = _decodeBody(response);
    if (decoded is List) {
      return decoded;
    }
    throw MindWellApiException(
      'Unexpected response payload for $path',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response = await _client.post(
      _buildUri(path),
      headers: _buildHeaders(headers, json: true),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response = await _client.patch(
      _buildUri(path),
      headers: _buildHeaders(headers, json: true),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decode(response);
  }

  Future<void> delete(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final response = await _client.delete(
      _buildUri(path, query),
      headers: _buildHeaders(headers),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MindWellApiException(
        'Request failed with status ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = _decodeBody(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw MindWellApiException(
      'Unexpected response payload.',
      statusCode: response.statusCode,
    );
  }

  dynamic _decodeBody(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return const <String, dynamic>{};
      return jsonDecode(response.body);
    }
    throw MindWellApiException(
      'Request failed with status ${response.statusCode}',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  Map<String, String> _buildHeaders(
    Map<String, String>? headers, {
    bool json = false,
  }) {
    final merged = <String, String>{};
    if (json) {
      merged['Content-Type'] = 'application/json';
    }
    
    // Add Supabase JWT token if available
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session?.accessToken != null) {
        merged['Authorization'] = 'Bearer ${session!.accessToken}';
      }
    } catch (_) {
      // Supabase not initialized, skip auth header
    }
    
    if (headers != null && headers.isNotEmpty) {
      merged.addAll(headers);
    }
    return merged;
  }

  void dispose() => _client.close();
}

class MindWellApiException implements Exception {
  MindWellApiException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' (status: $statusCode)';
    if (body == null || body!.isEmpty) {
      return '$message$code';
    }
    return '$message$code\n$body';
  }
}
