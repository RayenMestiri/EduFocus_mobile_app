import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_context.dart';
import '../../../core/offline/sync_queue.dart';

/// Timer settings synced with GET/PUT /api/auth/timer-settings
/// (backend User.preferences.studySettings).
@immutable
class TimerSettings {
  const TimerSettings({
    this.pomodoroLength = 25,
    this.shortBreak = 5,
    this.longBreak = 15,
    this.sessionsBeforeLongBreak = 4,
    this.dailySessionsGoal = 4,
    this.autoStartBreaks = true,
    this.autoStartFocus = false,
  });

  final int pomodoroLength;
  final int shortBreak;
  final int longBreak;
  final int sessionsBeforeLongBreak;
  final int dailySessionsGoal;
  final bool autoStartBreaks;
  final bool autoStartFocus;

  factory TimerSettings.fromJson(Map<String, dynamic> json) {
    return TimerSettings(
      pomodoroLength: (json['pomodoroLength'] as num?)?.toInt() ?? 25,
      shortBreak: (json['shortBreak'] as num?)?.toInt() ?? 5,
      longBreak: (json['longBreak'] as num?)?.toInt() ?? 15,
      sessionsBeforeLongBreak:
          (json['sessionsBeforeLongBreak'] as num?)?.toInt() ?? 4,
      dailySessionsGoal: (json['dailySessionsGoal'] as num?)?.toInt() ?? 4,
      autoStartBreaks: json['autoStartBreaks'] as bool? ?? true,
      autoStartFocus: json['autoStartFocus'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'pomodoroLength': pomodoroLength,
    'shortBreak': shortBreak,
    'longBreak': longBreak,
    'sessionsBeforeLongBreak': sessionsBeforeLongBreak,
    'dailySessionsGoal': dailySessionsGoal,
    'autoStartBreaks': autoStartBreaks,
    'autoStartFocus': autoStartFocus,
  };

  TimerSettings copyWith({
    int? pomodoroLength,
    int? shortBreak,
    int? longBreak,
    int? sessionsBeforeLongBreak,
    int? dailySessionsGoal,
    bool? autoStartBreaks,
    bool? autoStartFocus,
  }) {
    return TimerSettings(
      pomodoroLength: pomodoroLength ?? this.pomodoroLength,
      shortBreak: shortBreak ?? this.shortBreak,
      longBreak: longBreak ?? this.longBreak,
      sessionsBeforeLongBreak:
          sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
      dailySessionsGoal: dailySessionsGoal ?? this.dailySessionsGoal,
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      autoStartFocus: autoStartFocus ?? this.autoStartFocus,
    );
  }
}

class SettingsRepository {
  SettingsRepository(this._dio, this._offline);

  final Dio _dio;
  final OfflineContext _offline;

  static const _cacheKey = 'timer';

  Future<TimerSettings> fetch() async {
    if (_offline.isOnline) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/auth/timer-settings',
        );
        final settings = response.data?['settings'];
        if (settings is Map<String, dynamic>) {
          await _offline.cache.put(_cacheKey, settings);
          return TimerSettings.fromJson(settings);
        }
        return const TimerSettings();
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    final cached = await _offline.cache.get(_cacheKey);
    return cached != null
        ? TimerSettings.fromJson(cached)
        : const TimerSettings();
  }

  Future<TimerSettings> save(TimerSettings settings) async {
    if (_offline.isOnline) {
      try {
        final response = await _dio.put<Map<String, dynamic>>(
          '/auth/timer-settings',
          data: settings.toJson(),
        );
        final saved = response.data?['settings'];
        final result = saved is Map<String, dynamic>
            ? TimerSettings.fromJson(saved)
            : settings;
        await _offline.cache.put(_cacheKey, result.toJson());
        return result;
      } on DioException catch (e) {
        if (!isTransportError(e)) throw ApiException.fromDio(e);
      }
    }
    // Offline: keep the user's choice locally and queue the sync.
    await _offline.cache.put(_cacheKey, settings.toJson());
    await _offline.enqueue(
      PendingOp(
        id: newOpId(),
        entity: 'settings',
        method: 'PUT',
        path: '/auth/timer-settings',
        body: settings.toJson(),
      ),
    );
    return settings;
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    ref.watch(apiClientProvider),
    offlineContext(ref, 'settings'),
  );
});

final timerSettingsProvider = FutureProvider.autoDispose<TimerSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).fetch();
});
