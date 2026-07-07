import 'dart:typed_data';

import 'package:avogs/core/api/api_error_mapper.dart';
import 'package:avogs/core/api/api_exception.dart';
import 'package:avogs/core/api/dio_provider.dart';
import 'package:avogs/core/config/app_config.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    dio: ref.watch(dioProvider),
    config: ref.watch(appConfigProvider),
  );
});

class ApiClient {
  ApiClient({required Dio dio, required AppConfig config})
      : _dio = dio,
        _config = config;

  final Dio _dio;
  final AppConfig _config;

  String get _baseUrl => _config.baseUrl;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _request(() => _dio.get<Map<String, dynamic>>(
          '$_baseUrl$path',
          queryParameters: queryParameters,
        ));
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await _request(() => _dio.get<dynamic>(
          '$_baseUrl$path',
          queryParameters: queryParameters,
        ));
    if (data is List) return data;
    throw ApiException(message: 'Expected JSON array from $path');
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _request(() => _dio.post<Map<String, dynamic>>(
          '$_baseUrl$path',
          data: body,
        ));
  }

  Future<void> postEmpty(String path) async {
    await _request(() => _dio.post<void>('$_baseUrl$path'));
  }

  /// Multipart upload, e.g. `POST /media` with a `file` field. Takes raw
  /// bytes rather than a file path so it works on Flutter Web too — dart:io
  /// (and therefore MultipartFile.fromFile) isn't available there, but
  /// MultipartFile.fromBytes works on every platform this app targets.
  /// Dio sets the multipart boundary content-type header itself from the
  /// FormData — don't pass a Content-Type override here.
  Future<Map<String, dynamic>> uploadBytes(
    String path, {
    required Uint8List bytes,
    required String filename,
    String field = 'file',
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      field: MultipartFile.fromBytes(bytes, filename: filename),
    });
    return _request(() => _dio.post<Map<String, dynamic>>(
          '$_baseUrl$path',
          data: formData,
          onSendProgress: onSendProgress,
          options: Options(
            sendTimeout: const Duration(minutes: 2),
            receiveTimeout: const Duration(minutes: 2),
          ),
        ));
  }

  Future<T> _request<T>(Future<Response<T>> Function() call) async {
    try {
      final response = await call();
      final data = response.data;
      if (data == null) {
        throw ApiException(
          message: 'Empty response',
          statusCode: response.statusCode,
        );
      }
      if (data is Map<String, dynamic>) return data as T;
      if (data is List) return data as T;
      return data;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
