import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

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
  SettingsRepository(this._dio);

  final Dio _dio;

  Future<TimerSettings> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/auth/timer-settings',
      );
      final settings = response.data?['settings'];
      return settings is Map<String, dynamic>
          ? TimerSettings.fromJson(settings)
          : const TimerSettings();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<TimerSettings> save(TimerSettings settings) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/auth/timer-settings',
        data: settings.toJson(),
      );
      final saved = response.data?['settings'];
      return saved is Map<String, dynamic>
          ? TimerSettings.fromJson(saved)
          : settings;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(apiClientProvider));
});

final timerSettingsProvider = FutureProvider.autoDispose<TimerSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).fetch();
});
