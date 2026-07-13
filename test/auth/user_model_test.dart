import 'package:edufocus_mobile/features/auth/domain/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User.fromJson', () {
    test('parses the /api/auth/login response user shape', () {
      final user = User.fromJson(const {
        'id': '66f0a1',
        'name': 'Rayen Mestiri',
        'email': 'rayen@example.com',
        'avatar': 'https://res.cloudinary.com/demo/avatar.png',
        'role': 'user',
      });

      expect(user.id, '66f0a1');
      expect(user.name, 'Rayen Mestiri');
      expect(user.email, 'rayen@example.com');
      expect(user.role, 'user');
      expect(user.stats, isNull);
      expect(user.initial, 'R');
    });

    test('parses the /api/auth/me response including stats', () {
      final user = User.fromJson(const {
        'id': '66f0a1',
        'name': 'Rayen',
        'email': 'rayen@example.com',
        'stats': {
          'totalStudyMinutes': 320,
          'totalSessions': 12,
          'points': 181,
          'streak': 2,
          'longestStreak': 5,
          'lastStudyDate': '2026-07-10T08:00:00.000Z',
        },
      });

      expect(user.stats, isNotNull);
      expect(user.stats!.totalStudyMinutes, 320);
      expect(user.stats!.points, 181);
      expect(user.stats!.streak, 2);
      expect(user.stats!.longestStreak, 5);
      expect(user.stats!.lastStudyDate, isNotNull);
    });

    test('falls back to _id when id is absent (raw Mongo document)', () {
      final user = User.fromJson(const {
        '_id': 'abc123',
        'name': 'Test',
        'email': 't@t.co',
      });
      expect(user.id, 'abc123');
    });
  });
}
