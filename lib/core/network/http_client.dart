import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../constants/server_config.dart';

/// HTTP client untuk kebutuhan speed test.
class HttpClient {
  final http.Client _client;
  final Duration timeout;

  HttpClient({
    http.Client? client,
    this.timeout = const Duration(seconds: AppConstants.connectionTimeoutSeconds),
  }) : _client = client ?? http.Client();

  Future<http.StreamedResponse> getStreamed(
    String url, {
    Map<String, String>? headers,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(ServerConfig.defaultHeaders);
    if (headers != null) request.headers.addAll(headers);
    return _client.send(request).timeout(timeout);
  }

  Future<http.Response> postBytes(
    String url,
    Uint8List body, {
    Map<String, String>? headers,
  }) async {
    return _client
        .post(
          Uri.parse(url),
          headers: {
            ...ServerConfig.defaultHeaders,
            'Content-Type': 'application/octet-stream',
            ...?headers,
          },
          body: body,
        )
        .timeout(timeout);
  }

  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    return _client
        .get(
          Uri.parse(url),
          headers: {
            ...ServerConfig.defaultHeaders,
            ...?headers,
          },
        )
        .timeout(timeout);
  }

  void close() => _client.close();
}
