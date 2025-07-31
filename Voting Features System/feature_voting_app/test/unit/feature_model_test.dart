// test/unit/feature_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_voting_app/models/feature.dart';
import 'package:feature_voting_app/models/user.dart';

void main() {
  group('Feature Model', () {
    final mockUserJson = {
      'id': 'user-123',
      'username': 'creator',
      'email': 'creator@example.com',
      'first_name': 'John',
      'last_name': 'Doe',
    };

    final mockFeatureJson = {
      'id': 'feat-456',
      'title': 'New Feature Idea',
      'description': 'A detailed description of the feature.',
      'status': 'Open',
      'created_by': mockUserJson,
      'created_at': '2025-07-29T10:00:00Z',
      'updated_at': '2025-07-29T10:00:00Z',
      'vote_count': 5,
      'has_voted': true,
    };

    test('Feature.fromJson should correctly parse JSON', () {
      final feature = Feature.fromJson(mockFeatureJson);

      expect(feature.id, 'feat-456');
      expect(feature.title, 'New Feature Idea');
      expect(feature.description, 'A detailed description of the feature.');
      expect(feature.status, 'Open');
      expect(feature.createdBy.username, 'creator');
      expect(feature.createdAt, DateTime.utc(2025, 7, 29, 10, 0, 0));
      expect(feature.updatedAt, DateTime.utc(2025, 7, 29, 10, 0, 0));
      expect(feature.voteCount, 5);
      expect(feature.hasVoted, true);
    });

    test('Feature.fromJson should handle missing vote_count/has_voted', () {
      final Map<String, dynamic> jsonWithoutVotes = {
        'id': 'feat-789',
        'title': 'Another Feature',
        'description': 'Another description.',
        'status': 'Planned',
        'created_by': mockUserJson,
        'created_at': '2025-07-28T12:00:00Z',
        'updated_at': '2025-07-28T12:00:00Z',
        // vote_count and has_voted are omitted
      };

      final feature = Feature.fromJson(jsonWithoutVotes);

      expect(feature.id, 'feat-789');
      expect(feature.title, 'Another Feature');
      expect(feature.voteCount, 0); // Default value
      expect(feature.hasVoted, false); // Default value
    });

    test('Feature.toJson should correctly convert to JSON', () {
      final user = User.fromJson(mockUserJson);
      final feature = Feature(
        id: 'feat-456',
        title: 'New Feature Idea',
        description: 'A detailed description of the feature.',
        status: 'Open',
        createdBy: user,
        createdAt: DateTime.utc(2025, 7, 29, 10, 0, 0),
        updatedAt: DateTime.utc(2025, 7, 29, 10, 0, 0),
        voteCount: 5,
        hasVoted: true,
      );

      final json = feature.toJson();

      expect(json['id'], 'feat-456');
      expect(json['title'], 'New Feature Idea');
      expect(json['status'], 'Open');
      expect(json['created_by']['username'], 'creator'); // Check nested user
      expect(json['vote_count'], 5);
      expect(json['has_voted'], true);
    });
  });
}