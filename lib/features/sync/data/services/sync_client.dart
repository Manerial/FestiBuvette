import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:festi_buvette_app/features/sync/data/models/sync_exception.dart';

/// Thin HTTP wrapper used by the second device to talk to the control.
///
/// - Injects `Authorization: Bearer <token>` automatically when [token] is set.
/// - Retries once on transient network errors (SocketException / ClientException).
/// - Surfaces typed [SyncAuthException], [SyncNetworkException], [SyncServerException].
class SyncClient {
  final String baseUrl;
  final String? token;
  final http.Client _httpClient;

  static const Duration _timeout = Duration(seconds: 10);

  SyncClient({
    required this.baseUrl,
    this.token,
    http.Client? client,
  }) : _httpClient = client ?? http.Client();

  Map<String, String> get _authHeaders => {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      };

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// POST /auth — returns the bearer token on success.
  /// Throws [SyncAuthException] on wrong PIN.
  /// Throws [SyncNetworkException] on connection failure (no retry).
  Future<String> authenticate(String pin) async {
    final body = await _rawPost('/auth', {'pin': pin},
        headers: {'content-type': 'application/json'});
    return body['token'] as String;
  }

  /// Performs an authenticated GET request. Retries once on network error.
  Future<Map<String, dynamic>> get(String path) => _doGet(path);

  /// Performs an authenticated POST request. Retries once on network error.
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _doPost(path, body, headers: _authHeaders);

  /// Releases the underlying [http.Client].
  void close() => _httpClient.close();

  // ─── Private ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _doGet(String path,
      {int retriesLeft = 1}) async {
    try {
      final resp = await _httpClient
          .get(Uri.parse('$baseUrl$path'), headers: _authHeaders)
          .timeout(_timeout);
      return _parse(resp);
    } on SocketException catch (e) {
      if (retriesLeft > 0) return _doGet(path, retriesLeft: 0);
      throw SyncNetworkException(e.message);
    } on http.ClientException catch (e) {
      if (retriesLeft > 0) return _doGet(path, retriesLeft: 0);
      throw SyncNetworkException(e.message);
    } on TimeoutException {
      if (retriesLeft > 0) return _doGet(path, retriesLeft: 0);
      throw const SyncNetworkException('Request timed out');
    }
  }

  Future<Map<String, dynamic>> _doPost(
    String path,
    Map<String, dynamic> body, {
    required Map<String, String> headers,
    int retriesLeft = 1,
  }) async {
    try {
      final resp = await _httpClient
          .post(Uri.parse('$baseUrl$path'),
              headers: headers, body: jsonEncode(body))
          .timeout(_timeout);
      return _parse(resp);
    } on SocketException catch (e) {
      if (retriesLeft > 0) {
        return _doPost(path, body, headers: headers, retriesLeft: 0);
      }
      throw SyncNetworkException(e.message);
    } on http.ClientException catch (e) {
      if (retriesLeft > 0) {
        return _doPost(path, body, headers: headers, retriesLeft: 0);
      }
      throw SyncNetworkException(e.message);
    } on TimeoutException {
      if (retriesLeft > 0) {
        return _doPost(path, body, headers: headers, retriesLeft: 0);
      }
      throw const SyncNetworkException('Request timed out');
    }
  }

  /// No-retry version for auth (wrong PIN should not be retried).
  Future<Map<String, dynamic>> _rawPost(
    String path,
    Map<String, dynamic> body, {
    required Map<String, String> headers,
  }) async {
    try {
      final resp = await _httpClient
          .post(Uri.parse('$baseUrl$path'),
              headers: headers, body: jsonEncode(body))
          .timeout(_timeout);
      return _parse(resp);
    } on SocketException catch (e) {
      throw SyncNetworkException(e.message);
    } on http.ClientException catch (e) {
      throw SyncNetworkException(e.message);
    } on TimeoutException {
      throw const SyncNetworkException('Request timed out');
    }
  }

  Map<String, dynamic> _parse(http.Response resp) {
    if (resp.statusCode == 401) throw const SyncAuthException();
    if (resp.statusCode >= 400) throw SyncServerException(resp.statusCode);
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
