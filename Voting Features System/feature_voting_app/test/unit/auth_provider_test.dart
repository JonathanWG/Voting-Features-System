// test/unit/auth_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:feature_voting_app/providers/auth_provider.dart';
import 'package:feature_voting_app/services/api_service.dart';
import 'package:feature_voting_app/models/user.dart';

import 'auth_provider_test.mocks.dart'; // Generated mock file

@GenerateMocks([ApiService])
void main() {
  group('AuthProvider', () {
    late MockApiService mockApiService;
    late AuthProvider authProvider;

    setUp(() {
      mockApiService = MockApiService();
      authProvider = AuthProvider(); // Creates a new instance for each test
      // Manually inject mockApiService, as AuthProvider creates it internally by default.
      // This is a common pattern: either inject via constructor or use a factory pattern.
      // For simplicity here, we'll override the internal _apiService.
      authProvider.dispose(); // Dispose previous instance before replacing
      authProvider = AuthProvider().._apiService = mockApiService;
      // Mock initial checkLoginStatus to avoid side effects in most tests
      when(mockApiService.getCurrentUser()).thenAnswer((_) async => null);
    });

    tearDown(() {
      authProvider.dispose();
    });

    test('initial state is unauthenticated and not loading', () {
      // Re-initialize to test initial state truly
      authProvider = AuthProvider();
      expect(authProvider.currentUser, isNull);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.isLoading, isFalse); // Should be false after _checkLoginStatus finishes
      expect(authProvider.errorMessage, isNull);
    });

    test('login success sets current user and authenticates', () async {
      final user = User(id: '1', username: 'test', email: 'test@example.com');
      when(mockApiService.login('testuser', 'password123'))
          .thenAnswer((_) async => user);
      when(mockApiService.getCurrentUser()) // Called after login
          .thenAnswer((_) async => user);

      final result = await authProvider.login('testuser', 'password123');

      expect(result, isTrue);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentUser, user);
      expect(authProvider.errorMessage, isNull);
      verify(mockApiService.login('testuser', 'password123')).called(1);
      verify(mockApiService.getCurrentUser()).called(1); // Ensure it tries to fetch current user
    });

    test('login failure does not set user and sets error message', () async {
      when(mockApiService.login('wronguser', 'wrongpass'))
          .thenAnswer((_) async => null);

      final result = await authProvider.login('wronguser', 'wrongpass');

      expect(result, isFalse);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
      expect(authProvider.errorMessage, 'Invalid username or password.');
      verify(mockApiService.login('wronguser', 'wrongpass')).called(1);
    });

    test('register success does not set user but returns true', () async {
      when(mockApiService.register('newuser', 'new@example.com', 'password123'))
          .thenAnswer((_) async => true);

      final result = await authProvider.register('newuser', 'new@example.com', 'password123');

      expect(result, isTrue);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.isAuthenticated, isFalse); // Register doesn't log in
      expect(authProvider.currentUser, isNull);
      expect(authProvider.errorMessage, isNull);
      verify(mockApiService.register('newuser', 'new@example.com', 'password123')).called(1);
    });

    test('register failure returns false and sets error message', () async {
      when(mockApiService.register('dupuser', 'dup@example.com', 'password123'))
          .thenAnswer((_) async => false);

      final result = await authProvider.register('dupuser', 'dup@example.com', 'password123');

      expect(result, isFalse);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
      expect(authProvider.errorMessage, 'Registration failed. Username or email might be taken.');
      verify(mockApiService.register('dupuser', 'dup@example.com', 'password123')).called(1);
    });

    test('logout clears user and authentication status', () async {
      final user = User(id: '1', username: 'test', email: 'test@example.com');
      // Simulate already logged in
      authProvider.login('testuser', 'password123'); // This would set _currentUser if login worked
      authProvider._currentUser = user; // Manually set for this test
      when(mockApiService.logout()).thenAnswer((_) async => Future.value());

      await authProvider.logout();

      expect(authProvider.isLoading, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
      verify(mockApiService.logout()).called(1);
    });

    test('_checkLoginStatus restores session if tokens exist and are valid', () async {
      final user = User(id: '1', username: 'test', email: 'test@example.com');
      when(mockApiService.getCurrentUser()).thenAnswer((_) async => user);

      authProvider = AuthProvider().._apiService = mockApiService; // Re-initialize to trigger _checkLoginStatus

      // Wait for async initialization
      await Future.microtask(() {}); // Await any post-frame callbacks or async init

      expect(authProvider.isLoading, isFalse);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentUser, user);
      verify(mockApiService.getCurrentUser()).called(1);
    });

    test('_checkLoginStatus does nothing if no valid tokens', () async {
      when(mockApiService.getCurrentUser()).thenAnswer((_) async => null);

      authProvider = AuthProvider().._apiService = mockApiService; // Re-initialize

      await Future.microtask(() {});

      expect(authProvider.isLoading, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
      verify(mockApiService.getCurrentUser()).called(1);
    });
  });
}