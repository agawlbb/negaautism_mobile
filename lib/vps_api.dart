import 'api_endpoints.dart';

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class VpsApiException implements Exception {
  final String message;
  final int? status;
  const VpsApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class VpsApi {
  final http.Client _client;
  final Future<String?> Function() _token;
  final bool _usesFirebase;
  final String? _owner;
  VpsApi({http.Client? client, Future<String?> Function()? token})
    : _client = client ?? http.Client(),
      _token = token ?? _freshToken,
      _usesFirebase = token == null,
      _owner = token == null ? FirebaseAuth.instance.currentUser?.uid : null;

  static Future<String?> _freshToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken(true);

  void _checkOwner() {
    if (_usesFirebase &&
        (_owner == null || FirebaseAuth.instance.currentUser?.uid != _owner)) {
      throw const VpsApiException(
        'Your sign-in changed. Reopen this screen.',
        401,
      );
    }
  }

  // Each operation gets a fresh token. Writes are never retried automatically.
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    _checkOwner();
    final token = await _token();
    _checkOwner();
    if (token == null || token.isEmpty) {
      throw const VpsApiException('Sign in again to continue.', 401);
    }
    final uri = ApiEndpoints.uri(path, query: query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);
    final response = await (() async => http.Response.fromStream(
      await _client.send(request),
    ))().timeout(timeout);
    _checkOwner();
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const VpsApiException(
        'The service returned an unexpected response.',
      );
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw VpsApiException(
        data['message'] is String
            ? data['message'] as String
            : 'The request failed.',
        response.statusCode,
      );
    }
    return data;
  }

  void close() => _client.close();
}
