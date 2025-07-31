// test/unit/user_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_voting_app/models/user.dart';

void main() {
  group('User Model', () {
    test('User.fromJson should correctly parse JSON', () {
      final Map<String, dynamic> json = {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'username': 'testuser',
        'email': 'test@example.com',
        'first_name': 'Test',
        'last_name': 'User',
      };

      final user = User.fromJson(json);

      expect(user.id, '123e4567-e89b-12d3-a456-426614174000');
      expect(user.username, 'testuser');
      expect(user.email, 'test@example.com');
      expect(user.firstName, 'Test');
      expect(user.lastName, 'User');
    });

    test('User.fromJson should handle null/missing optional fields', () {
      final Map<String, dynamic> json = {
        'id': 'a1b2c3d4-e5f6-7890-1234-567890abcdef',
        'username': 'anotheruser',
        'email': 'another@example.com',
        // first_name and last_name are omitted
      };

      final user = User.fromJson(json);

      expect(user.id, 'a1b2c3d4-e5f6-7890-1234-567890abcdef');
      expect(user.username, 'anotheruser');
      expect(user.email, 'another@example.com');
      expect(user.firstName, isNull);
      expect(user.lastName, isNull);
    });

    test('User.toJson should correctly convert to JSON', () {
      final user = User(
        id: '123e4567-e89b-12d3-a456-426614174000',
        username: 'testuser',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
      );

      final json = user.toJson();

      expect(json['id'], '123e4567-e89b-12d3-a456-426614174000');
      expect(json['username'], 'testuser');
      expect(json['email'], 'test@example.com');
      expect(json['first_name'], 'Test');
      expect(json['last_name'], 'User');
    });
  });
}