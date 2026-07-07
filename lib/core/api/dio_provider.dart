import 'package:avogs/core/auth/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authTokenProvider);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Multipart uploads need Dio to set the boundary — not application/json.
        if (options.data is FormData) {
          options.headers.remove(Headers.contentTypeHeader);
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await ref.read(authRepositoryProvider).handleUnauthorized();
          ref.read(authControllerProvider.notifier).bootstrap();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
