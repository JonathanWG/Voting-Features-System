// test/unit/feature_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:feature_voting_app/providers/feature_provider.dart';
import 'package:feature_voting_app/services/api_service.dart';
import 'package:feature_voting_app/models/feature.dart';
import 'package:feature_voting_app/models/user.dart';

import 'feature_provider_test.mocks.dart'; // Generated mock file

@GenerateMocks([ApiService])
void main() {
  group('FeatureProvider', () {
    late MockApiService mockApiService;
    late FeatureProvider featureProvider;

    final testUser = User(id: 'user1', username: 'testuser', email: 'test@example.com');
    final feature1 = Feature(
      id: 'f1',
      title: 'Feature One',
      description: 'Desc One',
      status: 'Open',
      createdBy: testUser,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      voteCount: 5,
      hasVoted: false,
    );
    final feature2 = Feature(
      id: 'f2',
      title: 'Feature Two',
      description: 'Desc Two',
      status: 'Under Review',
      createdBy: testUser,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      voteCount: 10,
      hasVoted: true,
    );

    setUp(() {
      mockApiService = MockApiService();
      featureProvider = FeatureProvider().._apiService = mockApiService; // Inject mock
    });

    test('initial state is not loading and empty features', () {
      expect(featureProvider.features, isEmpty);
      expect(featureProvider.isLoading, isFalse);
      expect(featureProvider.errorMessage, isNull);
    });

    test('fetchFeatures success populates features list', () async {
      when(mockApiService.getFeatures()).thenAnswer((_) async => [feature1, feature2]);

      await featureProvider.fetchFeatures();

      expect(featureProvider.isLoading, isFalse);
      expect(featureProvider.features, containsAll([feature1, feature2]));
      expect(featureProvider.errorMessage, isNull);
      verify(mockApiService.getFeatures()).called(1);
    });

    test('fetchFeatures failure sets error message', () async {
      when(mockApiService.getFeatures()).thenThrow(Exception('Network Error'));

      await featureProvider.fetchFeatures();

      expect(featureProvider.isLoading, isFalse);
      expect(featureProvider.features, isEmpty);
      expect(featureProvider.errorMessage, 'Failed to load features: Exception: Network Error');
      verify(mockApiService.getFeatures()).called(1);
    });

    test('createFeature success adds new feature to list', () async {
      final newFeature = Feature(
        id: 'f3',
        title: 'New Feature',
        description: 'New Desc',
        status: 'Open',
        createdBy: testUser,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        voteCount: 0,
        hasVoted: false,
      );
      when(mockApiService.createFeature('New Feature', 'New Desc'))
          .thenAnswer((_) async => newFeature);

      // Simulate initial features for testing insertion at the beginning
      featureProvider.features.addAll([feature1, feature2]);

      final success = await featureProvider.createFeature('New Feature', 'New Desc');

      expect(success, isTrue);
      expect(featureProvider.isLoading, isFalse);
      expect(featureProvider.features.length, 3);
      expect(featureProvider.features.first, newFeature); // Should be added to the beginning
      expect(featureProvider.errorMessage, isNull);
      verify(mockApiService.createFeature('New Feature', 'New Desc')).called(1);
    });

    test('createFeature failure sets error message', () async {
      when(mockApiService.createFeature('Bad Feature', 'Bad Desc'))
          .thenAnswer((_) async => null);

      final success = await featureProvider.createFeature('Bad Feature', 'Bad Desc');

      expect(success, isFalse);
      expect(featureProvider.isLoading, isFalse);
      expect(featureProvider.features, isEmpty); // Assuming no initial features
      expect(featureProvider.errorMessage, 'Failed to create feature. Please try again.');
      verify(mockApiService.createFeature('Bad Feature', 'Bad Desc')).called(1);
    });

    test('upvoteFeature success updates vote count and hasVoted optimistically', () async {
      featureProvider.features.add(feature1); // Add feature to list

      when(mockApiService.upvoteFeature(feature1.id)).thenAnswer((_) async => true);

      final initialVoteCount = feature1.voteCount;
      final initialHasVoted = feature1.hasVoted;

      final success = await featureProvider.upvoteFeature(feature1.id);

      expect(success, isTrue);
      expect(feature1.voteCount, initialVoteCount + 1);
      expect(feature1.hasVoted, isTrue);
      expect(featureProvider.errorMessage, isNull);
      verify(mockApiService.upvoteFeature(feature1.id)).called(1);
    });

    test('upvoteFeature failure reverts optimistic update and sets error', () async {
      featureProvider.features.add(feature1); // Add feature to list

      when(mockApiService.upvoteFeature(feature1.id)).thenAnswer((_) async => false);

      final initialVoteCount = feature1.voteCount;
      final initialHasVoted = feature1.hasVoted;

      final success = await featureProvider.upvoteFeature(feature1.id);

      expect(success, isFalse);
      expect(feature1.voteCount, initialVoteCount); // Reverted
      expect(feature1.hasVoted, initialHasVoted); // Reverted
      expect(featureProvider.errorMessage, 'Failed to upvote feature. You might have already voted.');
      verify(mockApiService.upvoteFeature(feature1.id)).called(1);
    });

    test('unvoteFeature success updates vote count and hasVoted optimistically', () async {
      featureProvider.features.add(feature2); // Add feature2 (hasVoted = true)

      when(mockApiService.unvoteFeature(feature2.id)).thenAnswer((_) async => true);

      final initialVoteCount = feature2.voteCount;
      final initialHasVoted = feature2.hasVoted;

      final success = await featureProvider.unvoteFeature(feature2.id);

      expect(success, isTrue);
      expect(feature2.voteCount, initialVoteCount - 1);
      expect(feature2.hasVoted, isFalse);
      expect(featureProvider.errorMessage, isNull);
      verify(mockApiService.unvoteFeature(feature2.id)).called(1);
    });

    test('unvoteFeature failure reverts optimistic update and sets error', () async {
      featureProvider.features.add(feature2);

      when(mockApiService.unvoteFeature(feature2.id)).thenAnswer((_) async => false);

      final initialVoteCount = feature2.voteCount;
      final initialHasVoted = feature2.hasVoted;

      final success = await featureProvider.unvoteFeature(feature2.id);

      expect(success, isFalse);
      expect(feature2.voteCount, initialVoteCount); // Reverted
      expect(feature2.hasVoted, initialHasVoted); // Reverted
      expect(featureProvider.errorMessage, 'Failed to unvote feature.');
      verify(mockApiService.unvoteFeature(feature2.id)).called(1);
    });

    test('deleteFeature success removes feature from list', () async {
      featureProvider.features.addAll([feature1, feature2]);

      when(mockApiService.deleteFeature(feature1.id)).thenAnswer((_) async => true);

      final success = await featureProvider.deleteFeature(feature1.id);

      expect(success, isTrue);
      expect(featureProvider.isLoading, isFalse);
      expect(featureProvider.features.length, 1);
      expect(featureProvider.features, contains(feature2));
      expect(featureProvider.features, isNot(contains(feature1)));
      expect(featureProvider.errorMessage, isNull);
      verify(mockApiService.deleteFeature(feature1.id)).called(1);
    });

    test('deleteFeature failure sets error message', () async {
      featureProvider.features.addAll([feature1, feature2]);

      when(mockApiService.deleteFeature(feature1.id)).thenAnswer((_) async => false);

      final success = await featureProvider.deleteFeature(feature1.id);

      expect(success, isFalse);
      expect(featureProvider.isLoading, isFalse);
      expect(featureProvider.features.length, 2); // Not removed
      expect(featureProvider.errorMessage, 'Failed to delete feature.');
      verify(mockApiService.deleteFeature(feature1.id)).called(1);
    });
  });
}