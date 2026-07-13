import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/dashboard_stats.dart';

class DashboardRepository {
  DashboardRepository(this._dio);

  final Dio _dio;

  /// GET /api/stats/dashboard → `{ success, data: {...} }`.
  Future<DashboardStats> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/stats/dashboard');
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Réponse du serveur invalide.');
      }
      return DashboardStats.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

/// Auto-disposing so stats are re-fetched fresh when the screen is reopened;
/// pull-to-refresh invalidates this provider.
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((
  ref,
) {
  return ref.watch(dashboardRepositoryProvider).fetch();
});
