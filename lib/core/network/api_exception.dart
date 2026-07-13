import 'package:dio/dio.dart';

/// Normalized API failure surfaced to the UI layer.
///
/// The EduFocus backend answers errors as either
/// `{ success: false, message: "..." }` or
/// `{ success: false, errors: [{ msg: "..." }, ...] }` (express-validator).
/// Both shapes are folded into a single human-readable [message].
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) {
      return const ApiException(
        'Impossible de joindre le serveur. Vérifiez votre connexion.',
      );
    }

    final data = response.data;
    String? message;
    if (data is Map<String, dynamic>) {
      final rawMessage = data['message'];
      if (rawMessage is String && rawMessage.isNotEmpty) {
        message = rawMessage;
      } else {
        final errors = data['errors'];
        if (errors is List && errors.isNotEmpty) {
          message = errors
              .whereType<Map<String, dynamic>>()
              .map((e) => e['msg'])
              .whereType<String>()
              .join('\n');
        }
      }
    }

    return ApiException(
      (message == null || message.isEmpty)
          ? 'Une erreur est survenue (${response.statusCode}).'
          : message,
      statusCode: response.statusCode,
    );
  }

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
