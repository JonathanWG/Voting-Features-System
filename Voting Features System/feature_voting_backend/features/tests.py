# features/tests.py
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from django.core.cache import cache
from .models import Feature, Vote
import json

User = get_user_model()

class FeatureModelTest(TestCase):
    """
    Testes unitários para o modelo Feature.
    """
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser', email='user@example.com', password='password'
        )
        self.feature = Feature.objects.create(
            title='Test Feature', description='Description for test feature.', created_by=self.user
        )
        # Clear cache before each test that might rely on vote counts
        cache.clear()

    def test_feature_creation(self):
        self.assertIsInstance(self.feature, Feature)
        self.assertEqual(self.feature.title, 'Test Feature')
        self.assertEqual(self.feature.description, 'Description for test feature.')
        self.assertEqual(self.feature.created_by, self.user)
        self.assertEqual(self.feature.status, 'Open') # Default status

    def test_feature_str_representation(self):
        self.assertEqual(str(self.feature), 'Test Feature')

    def test_feature_get_vote_count_no_votes(self):
        self.assertEqual(self.feature.get_vote_count(), 0)
        # Verify cache was populated
        self.assertEqual(cache.get(f'feature:{self.feature.id}:votes'), 0)

    def test_feature_get_vote_count_with_votes(self):
        # Create votes
        user2 = User.objects.create_user(username='user2', email='user2@example.com', password='password')
        Vote.objects.create(user=self.user, feature=self.feature)
        Vote.objects.create(user=user2, feature=self.feature)
        self.assertEqual(self.feature.get_vote_count(), 2)
        self.assertEqual(cache.get(f'feature:{self.feature.id}:votes'), 2)

    def test_feature_get_vote_count_cache_miss_then_populate(self):
        # Explicitly remove from cache to simulate a cache miss
        cache.delete(f'feature:{self.feature.id}:votes')
        Vote.objects.create(user=self.user, feature=self.feature)
        self.assertEqual(self.feature.get_vote_count(), 1) # Should hit DB and then populate cache
        self.assertEqual(cache.get(f'feature:{self.feature.id}:votes'), 1)


class VoteModelTest(TestCase):
    """
    Testes unitários para o modelo Vote e sua interação com o cache.
    """
    def setUp(self):
        self.user1 = User.objects.create_user(username='user1', email='u1@example.com', password='password')
        self.user2 = User.objects.create_user(username='user2', email='u2@example.com', password='password')
        self.feature = Feature.objects.create(
            title='Vote Test Feature', description='Desc.', created_by=self.user1
        )
        # Ensure cache is clean before starting vote tests
        cache.clear()

    def test_vote_creation(self):
        vote = Vote.objects.create(user=self.user1, feature=self.feature)
        self.assertIsInstance(vote, Vote)
        self.assertEqual(vote.user, self.user1)
        self.assertEqual(vote.feature, self.feature)
        # Check if vote count in cache incremented
        self.assertEqual(cache.get(f'feature:{self.feature.id}:votes'), 1)

    def test_vote_str_representation(self):
        vote = Vote.objects.create(user=self.user1, feature=self.feature)
        self.assertEqual(str(vote), f"{self.user1.username} voted for {self.feature.title}")

    def test_unique_together_constraint(self):
        Vote.objects.create(user=self.user1, feature=self.feature)
        with self.assertRaises(Exception) as cm: # Expecting IntegrityError, but could be other DB errors
            Vote.objects.create(user=self.user1, feature=self.feature)
        # Check for specific database integrity error message (might vary slightly)
        self.assertIn("duplicate key value violates unique constraint", str(cm.exception))
        # Ensure cache count remains 1, as second vote failed
        self.assertEqual(cache.get(f'feature:{self.feature.id}:votes'), 1)


    def test_vote_delete_decrements_cache(self):
        vote1 = Vote.objects.create(user=self.user1, feature=self.feature)
        Vote.objects.create(user=self.user2, feature=self.feature)
        self.assertEqual(cache.get(f'feature:{self.feature.id}:votes'), 2)

        vote1.delete()
        self.assertEqual(cache.get(f'feature:{self.feature.id}:votes'), 1)


class FeatureAPITest(TestCase):
    """
    Testes de API para features e votação.
    """
    def setUp(self):
        self.client = APIClient()
        self.user1 = User.objects.create_user(username='user1', email='u1@example.com', password='password')
        self.user2 = User.objects.create_user(username='user2', email='u2@example.com', password='password')
        self.feature1 = Feature.objects.create(title='Feat A', description='Desc A', created_by=self.user1)
        self.feature2 = Feature.objects.create(title='Feat B', description='Desc B', created_by=self.user2)

        # Clear cache before running API tests, especially those involving vote counts
        cache.clear()

        # Log in user1 to get token for authenticated requests
        login_response = self.client.post('/api/token/', {'username': 'user1', 'password': 'password'}, format='json')
        self.user1_access_token = login_response.data['access']

        # Log in user2 to get token for authenticated requests
        login_response = self.client.post('/api/token/', {'username': 'user2', 'password': 'password'}, format='json')
        self.user2_access_token = login_response.data['access']

        self.feature_list_url = '/api/features/'
        self.feature_detail_url = lambda pk: f'/api/features/{pk}/'
        self.upvote_url = lambda pk: f'/api/features/{pk}/upvote/'
        self.unvote_url = lambda pk: f'/api/features/{pk}/unvote/'

    def test_list_features_unauthenticated(self):
        response = self.client.get(self.feature_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 2) # Assuming pagination is on
        self.assertIn('vote_count', response.data['results'][0])
        self.assertIn('has_voted', response.data['results'][0])
        self.assertFalse(response.data['results'][0]['has_voted']) # Should be false if unauthenticated

    def test_list_features_authenticated_and_has_voted(self):
        # User1 upvotes feature2
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user1_access_token}')
        self.client.post(self.upvote_url(self.feature2.id))

        # List features as user1
        response = self.client.get(self.feature_list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Find feature2 in the results
        feature2_data = next((f for f in response.data['results'] if f['id'] == str(self.feature2.id)), None)
        self.assertIsNotNone(feature2_data)
        self.assertTrue(feature2_data['has_voted'])
        self.assertEqual(feature2_data['vote_count'], 1)

        # Find feature1 in the results (not voted by user1)
        feature1_data = next((f for f in response.data['results'] if f['id'] == str(self.feature1.id)), None)
        self.assertIsNotNone(feature1_data)
        self.assertFalse(feature1_data['has_voted'])
        self.assertEqual(feature1_data['vote_count'], 0)


    def test_retrieve_feature_unauthenticated(self):
        response = self.client.get(self.feature_detail_url(self.feature1.id))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['title'], 'Feat A')
        self.assertIn('vote_count', response.data)
        self.assertIn('has_voted', response.data)
        self.assertFalse(response.data['has_voted']) # Unauthenticated user hasn't voted

    def test_create_feature_authenticated(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user1_access_token}')
        data = {
            'title': 'New Feature Idea',
            'description': 'This is a great idea for a new feature.',
        }
        response = self.client.post(self.feature_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['title'], 'New Feature Idea')
        self.assertEqual(response.data['created_by']['username'], 'user1')
        self.assertEqual(Feature.objects.count(), 3) # Two existing + one new

    def test_create_feature_unauthenticated(self):
        data = {
            'title': 'New Feature Idea',
            'description': 'This is a great idea for a new feature.',
        }
        response = self.client.post(self.feature_list_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(Feature.objects.count(), 2)

    def test_update_feature_authenticated_owner(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user1_access_token}')
        update_data = {
            'title': 'Updated Feat A',
            'description': 'Updated description.',
            'status': 'Under Review'
        }
        response = self.client.put(self.feature_detail_url(self.feature1.id), update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.feature1.refresh_from_db()
        self.assertEqual(self.feature1.title, 'Updated Feat A')
        self.assertEqual(self.feature1.status, 'Under Review')

    def test_update_feature_authenticated_not_owner(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user1_access_token}') # User1 is not owner of feature2
        update_data = {
            'title': 'Updated Feat B by User1 (should fail)',
            'description': 'Updated description by unauthorized user.',
            'status': 'Completed'
        }
        response = self.client.put(self.feature_detail_url(self.feature2.id), update_data, format='json')
        # DRF's default IsAuthenticated allows any authenticated user to update.
        # To restrict to owner, you'd need a custom permission like IsOwnerOrReadOnly.
        # Given the current permission settings in views.py, this will pass.
        # If you implement IsOwnerOrReadOnly, this should be 403.
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.feature2.refresh_from_db()
        self.assertEqual(self.feature2.title, 'Updated Feat B by User1 (should fail)') # Check that it actually updated

    def test_delete_feature_authenticated_owner(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user1_access_token}')
        response = self.client.delete(self.feature_detail_url(self.feature1.id))
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Feature.objects.filter(id=self.feature1.id).exists())
        self.assertEqual(Feature.objects.count(), 1)

    def test_delete_feature_authenticated_not_owner(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user1_access_token}') # User1 is not owner of feature2
        response = self.client.delete(self.feature_detail_url(self.feature2.id))
        # Similar to update, with default permissions, this will pass.
        # With IsOwnerOrReadOnly, this should be 403.
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Feature.objects.filter(id=self.feature2.id).exists())
        self.assertEqual(Feature.objects.count(), 1)


    def test_upvote_feature_success(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user1_access_token}')
        response = self.client.post(self.upvote_url(self.feature1.id))
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(Vote.objects.filter(user=self.user1, feature=self.feature1).exists())
        self.assertEqual(self.feature1.get_vote_count(), 1) # Check count via model method
        self.assertEqual(cache.get(f'feature:{self.feature1.id}:votes'), 1) # Check direct cache

    def test_upvote_feature_already_voted(self):
        Vote.objects.create(user=self.user1, feature=self.feature1) # Pre-vote
        self.assertEqual(cache.get(f'feature:{self.feature1.id}:votes'), 1) # Initial cache check

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user1_access_token}')
        response = self.client.post(self.upvote_url(self.feature1.id))
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('detail', response.data)
        self.assertEqual(response.data['detail'], 'You have already upvoted this feature.')
        self.assertEqual(self.feature1.get_vote_count(), 1) # Vote count should remain 1
        self.assertEqual(cache.get(f'feature:{self.feature1.id}:votes'), 1) # Cache should not have incremented

    def test_upvote_feature_unauthenticated(self):
        response = self.client.post(self.upvote_url(self.feature1.id))
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertFalse(Vote.objects.filter(user=self.user1, feature=self.feature1).exists())
        self.assertEqual(self.feature1.get_vote_count(), 0) # Should still be 0

    def test_unvote_feature_success(self):
        Vote.objects.create(user=self.user1, feature=self.feature1) # Create a vote to delete
        self.assertEqual(cache.get(f'feature:{self.feature1.id}:votes'), 1)

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user1_access_token}')
        response = self.client.post(self.unvote_url(self.feature1.id))
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Vote.objects.filter(user=self.user1, feature=self.feature1).exists())
        self.assertEqual(self.feature1.get_vote_count(), 0)
        self.assertEqual(cache.get(f'feature:{self.feature1.id}:votes'), 0)

    def test_unvote_feature_not_voted(self):
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user1_access_token}')
        response = self.client.post(self.unvote_url(self.feature1.id))
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('detail', response.data)
        self.assertEqual(response.data['detail'], 'You have not upvoted this feature.')
        self.assertEqual(self.feature1.get_vote_count(), 0)

    def test_unvote_feature_unauthenticated(self):
        Vote.objects.create(user=self.user1, feature=self.feature1)
        response = self.client.post(self.unvote_url(self.feature1.id))
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertTrue(Vote.objects.filter(user=self.user1, feature=self.feature1).exists()) # Vote should still exist
        self.assertEqual(self.feature1.get_vote_count(), 1)

    def test_vote_count_accuracy_with_multiple_operations(self):
        # User1 upvotes feature1
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user1_access_token}')
        self.client.post(self.upvote_url(self.feature1.id))
        self.assertEqual(self.feature1.get_vote_count(), 1)
        self.assertEqual(cache.get(f'feature:{self.feature1.id}:votes'), 1)

        # User2 upvotes feature1
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user2_access_token}')
        self.client.post(self.upvote_url(self.feature1.id))
        self.assertEqual(self.feature1.get_vote_count(), 2)
        self.assertEqual(cache.get(f'feature:{self.feature1.id}:votes'), 2)

        # User1 unvotes feature1
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user1_access_token}')
        self.client.post(self.unvote_url(self.feature1.id))
        self.assertEqual(self.feature1.get_vote_count(), 1)
        self.assertEqual(cache.get(f'feature:{self.feature1.id}:votes'), 1)

        # User2 unvotes feature1
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.user2_access_token}')
        self.client.post(self.unvote_url(self.feature1.id))
        self.assertEqual(self.feature1.get_vote_count(), 0)
        self.assertEqual(cache.get(f'feature:{self.feature1.id}:votes'), 0)