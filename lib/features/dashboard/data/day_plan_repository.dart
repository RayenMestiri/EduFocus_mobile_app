import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/day_plan.dart';

class DayPlanRepository {
  DayPlanRepository(this._dio);
  final Dio _dio;

  /// Fetch plan for a specific date (YYYY-MM-DD)
  Future<DayPlan> getPlanForDate(String date) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/day-plans/$date');
      return DayPlan.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Erreur lors de la récupération du planning : ${e.message}');
    }
  }

  /// Save or update a day plan
  Future<DayPlan> savePlan(Map<String, dynamic> planData) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/day-plans', data: planData);
      return DayPlan.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Erreur lors de l\'enregistrement du planning : ${e.message}');
    }
  }
}

final dayPlanRepositoryProvider = Provider<DayPlanRepository>((ref) {
  return DayPlanRepository(ref.watch(apiClientProvider));
});

final dayPlanProvider = FutureProvider.autoDispose.family<DayPlan, String>((ref, date) {
  return ref.watch(dayPlanRepositoryProvider).getPlanForDate(date);
});
