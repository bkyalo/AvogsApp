import 'dart:convert';

import 'package:avogs/core/api/api_exception.dart';
import 'package:dio/dio.dart';

ApiException mapDioError(DioException error) {
  final response = error.response;
  final data = _decodeErrorBody(response?.data);
  if (data is Map<String, dynamic>) {
    final err = data['error'];
    if (err is Map<String, dynamic>) {
      final fieldsRaw = err['fields'];
      final fields = <String, String>{};
      if (fieldsRaw is Map) {
        fieldsRaw.forEach((key, value) {
          fields['$key'] = '$value';
        });
      }
      return ApiException(
        message: '${err['message'] ?? 'Request failed'}',
        statusCode: response?.statusCode,
        code: err['code'] as String?,
        fields: fields,
      );
    }
  }

  if (_isConnectionIssue(error)) {
    return ApiException(
      message: _connectionMessage(error),
      statusCode: response?.statusCode,
    );
  }

  return ApiException(
    message: error.message ?? 'Network request failed',
    statusCode: response?.statusCode,
  );
}

bool _isConnectionIssue(DioException error) {
  return error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.unknown;
}

String _connectionMessage(DioException error) {
  final host = error.requestOptions.uri.host;
  if (host == 'localhost' || host == '127.0.0.1') {
    return "Cannot reach localhost from a phone. Open Settings and switch Environment to Development or Production.";
  }

  final raw = error.message?.trim();
  if (raw != null && raw.isNotEmpty && raw.toLowerCase() != 'null') {
    return raw;
  }

  return 'Could not connect to the server. Check your network and API environment in Settings.';
}

dynamic _decodeErrorBody(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
  return null;
}
