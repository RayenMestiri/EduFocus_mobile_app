import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_context.dart';
import '../domain/dashboard_stats.dart';

/// Offline-first read of GET /api/stats/dashboard: network when reachable
/// (cache refreshed), last known snapshot when not.
class DashboardRepository {
  DashboardRepository(this._dio, this._offline);

  final Dio _dio;
  final OfflineContext _offline;

  static const _cacheKey = 'latest';

  Future<DashboardStats> fetch() async {
    if (_offline.isOnline) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/stats/dashboard',
        );
        final data = response.data?['data'];
        if (data is! Map<String, dynamic>) {
          throw const ApiException('Réponse du serveur invalide.');
        }
        await _offline.cache.put(_cacheKey, data);
        return DashboardStats.fromJson(data);
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    final cached = await _offline.cache.get(_cacheKey);
    if (cached != null) return DashboardStats.fromJson(cached);
    throw const ApiException(
      'Hors ligne — aucune donnée en cache pour le moment.',
    );
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    ref.watch(apiClientProvider),
    offlineContext(ref, 'dashboard'),
  );
});

/// Auto-disposing so stats are re-fetched fresh when the screen is reopened;
/// pull-to-refresh invalidates this provider.
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((
  ref,
) {
  return ref.watch(dashboardRepositoryProvider).fetch();
});
