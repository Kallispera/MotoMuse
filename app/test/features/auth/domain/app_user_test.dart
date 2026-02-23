import 'package:flutter_test/flutter_test.dart';
import 'package:motomuse/features/auth/domain/app_user.dart';

void main() {
  group('AppUser', () {
    const uid = 'test-uid-123';
    const email = 'rider@motomuse.app';

    const full = AppUser(
      uid: uid,
      email: email,
      isEmailVerified: true,
      displayName: 'Road Rider',
      photoUrl: 'https://example.com/photo.jpg',
    );

    const minimal = AppUser(
      uid: uid,
      email: email,
      isEmailVerified: false,
    );

    group('equality', () {
      test('identical instances are equal', () {
        expect(full, equals(full));
      });

      test('instances with same fields are equal', () {
        const copy = AppUser(
          uid: uid,
          email: email,
          isEmailVerified: true,
          displayName: 'Road Rider',
          photoUrl: 'https://example.com/photo.jpg',
        );
        expect(full, equals(copy));
      });

      test('instances with different uid are not equal', () {
        const other = AppUser(
          uid: 'different-uid',
          email: email,
          isEmailVerified: true,
        );
        expect(full, isNot(equals(other)));
      });

      test('instances with different email are not equal', () {
        const other = AppUser(
          uid: uid,
          email: 'other@motomuse.app',
          isEmailVerified: true,
        );
        expect(full, isNot(equals(other)));
      });

      test('instances with different isEmailVerified are not equal', () {
        expect(full, isNot(equals(minimal)));
      });

      test('instances with different displayName are not equal', () {
        const other = AppUser(
          uid: uid,
          email: email,
          isEmailVerified: true,
          displayName: 'Different Name',
        );
        expect(full, isNot(equals(other)));
      });
    });

    group('hashCode', () {
      test('equal instances have the same hashCode', () {
        const copy = AppUser(
          uid: uid,
          email: email,
          isEmailVerified: true,
          displayName: 'Road Rider',
          photoUrl: 'https://example.com/photo.jpg',
        );
        expect(full.hashCode, equals(copy.hashCode));
      });
    });

    group('fields', () {
      test('optional fields default to null', () {
        expect(minimal.displayName, isNull);
        expect(minimal.photoUrl, isNull);
      });

      test('all fields are stored correctly', () {
        expect(full.uid, equals(uid));
        expect(full.email, equals(email));
        expect(full.isEmailVerified, isTrue);
        expect(full.displayName, equals('Road Rider'));
        expect(full.photoUrl, equals('https://example.com/photo.jpg'));
      });
    });

    group('toString', () {
      test('includes uid, email, and isEmailVerified', () {
        final result = full.toString();
        expect(result, contains(uid));
        expect(result, contains(email));
        expect(result, contains('true'));
      });
    });
  });
}
