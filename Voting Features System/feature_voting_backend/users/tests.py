# users/tests.py
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
import json

User = get_user_model()

class UserModelsTest(TestCase):
    """
    Testes unitários para o modelo CustomUser.
    """
    def test_create_user(self):
        user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='password123'
        )
        self.assertEqual(user.username, 'testuser')
        self.assertEqual(user.email, 'test@example.com')
        self.assertTrue(user.check_password('password123'))
        self.assertFalse(user.is_staff)
        self.assertFalse(user.is_superuser)

    def test_create_superuser(self):
        superuser = User.objects.create_superuser(
            username='adminuser',
            email='admin@example.com',
            password='adminpassword'
        )
        self.assertEqual(superuser.username, 'adminuser')
        self.assertEqual(superuser.email, 'admin@example.com')
        self.assertTrue(superuser.check_password('adminpassword'))
        self.assertTrue(superuser.is_staff)
        self.assertTrue(superuser.is_superuser)

    def test_user_str_representation(self):
        user = User.objects.create_user(username='testuser', email='test@example.com', password='password123')
        self.assertEqual(str(user), 'testuser')

class UserAPITest(TestCase):
    """
    Testes de API para registro e autenticação de usuários.
    """
    def setUp(self):
        self.client = APIClient()
        self.register_url = '/api/users/register/'
        self.login_url = '/api/token/'
        self.refresh_token_url = '/api/token/refresh/'
        self.current_user_url = '/api/users/me/'

    def test_user_registration_success(self):
        data = {
            'username': 'newuser',
            'email': 'new@example.com',
            'password': 'strongpassword',
        }
        response = self.client.post(self.register_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('id', response.data)
        self.assertIn('username', response.data)
        self.assertIn('email', response.data)
        self.assertEqual(response.data['username'], 'newuser')
        self.assertEqual(response.data['email'], 'new@example.com')
        self.assertTrue(User.objects.filter(username='newuser').exists())

    def test_user_registration_missing_fields(self):
        data = {
            'username': 'incompleteuser',
            # 'email': 'incomplete@example.com', # Missing email
            'password': 'password',
        }
        response = self.client.post(self.register_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('email', response.data)

    def test_user_registration_duplicate_username_or_email(self):
        # Register first user
        self.client.post(self.register_url, {
            'username': 'duplicate',
            'email': 'duplicate@example.com',
            'password': 'password',
        }, format='json')

        # Try to register with duplicate username
        data_username = {
            'username': 'duplicate',
            'email': 'another@example.com',
            'password': 'password',
        }
        response = self.client.post(self.register_url, data_username, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('detail', response.data)
        self.assertEqual(response.data['detail'], 'A user with that username or email already exists.')

        # Try to register with duplicate email
        data_email = {
            'username': 'another_user',
            'email': 'duplicate@example.com',
            'password': 'password',
        }
        response = self.client.post(self.register_url, data_email, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('email', response.data) # Specific serializer error for email

    def test_user_login_success(self):
        User.objects.create_user(username='testlogin', email='login@example.com', password='testpassword')
        data = {
            'username': 'testlogin',
            'password': 'testpassword',
        }
        response = self.client.post(self.login_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)

    def test_user_login_invalid_credentials(self):
        User.objects.create_user(username='wronguser', email='wrong@example.com', password='wrongpassword')
        data = {
            'username': 'wronguser',
            'password': 'incorrect_password',
        }
        response = self.client.post(self.login_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertIn('detail', response.data)

    def test_get_current_user_authenticated(self):
        user = User.objects.create_user(username='authuser', email='auth@example.com', password='authpassword')
        login_data = {'username': 'authuser', 'password': 'authpassword'}
        login_response = self.client.post(self.login_url, login_data, format='json')
        access_token = login_response.data['access']

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
        response = self.client.get(self.current_user_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['username'], 'authuser')
        self.assertEqual(response.data['email'], 'auth@example.com')

    def test_get_current_user_unauthenticated(self):
        response = self.client.get(self.current_user_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_token_refresh(self):
        user = User.objects.create_user(username='refreshuser', email='refresh@example.com', password='refreshpassword')
        login_data = {'username': 'refreshuser', 'password': 'refreshpassword'}
        login_response = self.client.post(self.login_url, login_data, format='json')
        refresh_token = login_response.data['refresh']

        data = {'refresh': refresh_token}
        response = self.client.post(self.refresh_token_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertNotEqual(login_response.data['access'], response.data['access']) # New access token