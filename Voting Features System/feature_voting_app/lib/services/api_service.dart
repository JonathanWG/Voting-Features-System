// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feature.dart';
import '../models/user.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // For platform detection

class ApiService {
  // Base URL for your Django backend API.
  // Adjust based on where your Django server is running.
  // For Android Emulator to access host machine: 'http://10.0.2.2:8000/api'
  // For web or physical device (if accessible): 'http://127.0.0.1:8000/api' or your server IP.
  static const String _baseUrl = kIsWeb ? 'http://127.0.0.1:8000/api' : 'http://10.0.2.2:8000/api';

  String? _accessToken;
  String? _refreshToken;

  // --- Authentication Methods ---

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  Future<void> _deleteTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    _accessToken = null;
    _refreshToken = null;
  }

  Future<String?> _getAccessToken() async {
    if (_accessToken == null) {
      await _loadTokens();
    }
    return _accessToken;
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) {
      await _loadTokens();
    }
    if (_refreshToken == null) {
      print('No refresh token available.');
      return false;
    }

    final url = Uri.parse('$_baseUrl/token/refresh/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveTokens(data['access'], _refreshToken!); // Use the existing refresh token
        print('Access token refreshed successfully.');
        return true;
      } else {
        print('Failed to refresh token: ${response.statusCode} ${response.body}');
        await _deleteTokens(); // Clear all tokens if refresh fails (e.g., refresh token expired)
        return false;
      }
    } catch (e) {
      print('Error refreshing token: $e');
      await _deleteTokens();
      return false;
    }
  }

  Future<Map<String, String>> _getAuthHeaders({bool requireAuth = true}) async {
    String? token = await _getAccessToken();
    if (token == null && requireAuth) {
      // If no token, or it's potentially expired, try refreshing
      bool refreshed = await _refreshAccessToken();
      if (refreshed) {
        token = await _getAccessToken();
      } else {
        return {}; // Still no valid token, cannot proceed with authenticated request
      }
    }
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> register(String username, String email, String password) async {
    final url = Uri.parse('$_baseUrl/users/register/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      if (response.statusCode == 201) {
        return true;
      } else {
        print('Registration failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error during registration: $e');
      return false;
    }
  }

  Future<User?> login(String username, String password) async {
    final url = Uri.parse('$_baseUrl/token/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveTokens(data['access'], data['refresh']);

        // Fetch user details immediately after successful login
        return await getCurrentUser();
      } else {
        print('Login failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _deleteTokens();
  }

  Future<User?> getCurrentUser() async {
    final url = Uri.parse('$_baseUrl/users/me/');
    try {
      final headers = await _getAuthHeaders();
      if (headers.isEmpty) return null; // No token available after attempts

      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 401) {
        // Token likely expired, try refreshing and retrying
        print('Access token expired or invalid, attempting refresh...');
        bool refreshed = await _refreshAccessToken();
        if (refreshed) {
          return await getCurrentUser(); // Retry the request with the new token
        }
      }
      print('Failed to get current user: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // --- Feature Management Methods ---

  Future<List<Feature>> getFeatures() async {
    final url = Uri.parse('$_baseUrl/features/');
    try {
      // Pass requireAuth=false because feature list is publicly accessible
      // But pass headers if available for 'has_voted' field to work.
      final headers = await _getAuthHeaders(requireAuth: false);
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Feature.fromJson(json)).toList();
      } else {
        print('Failed to load features: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error loading features: $e');
      return [];
    }
  }

  Future<Feature?> createFeature(String title, String description) async {
    final url = Uri.parse('$_baseUrl/features/');
    try {
      final headers = await _getAuthHeaders();
      if (headers.isEmpty) {
        print('Cannot create feature: Not authenticated.');
        return null;
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'title': title,
          'description': description,
        }),
      );

      if (response.statusCode == 201) {
        return Feature.fromJson(jsonDecode(response.body));
      } else {
        print('Failed to create feature: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error creating feature: $e');
      return null;
    }
  }

  // --- Voting Methods ---

  Future<bool> upvoteFeature(String featureId) async {
    final url = Uri.parse('$_baseUrl/features/$featureId/upvote/');
    try {
      final headers = await _getAuthHeaders();
      if (headers.isEmpty) {
        print('Cannot upvote: Not authenticated.');
        return false;
      }

      final response = await http.post(url, headers: headers);
      if (response.statusCode == 201) {
        return true;
      } else {
        print('Failed to upvote feature: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error upvoting feature: $e');
      return false;
    }
  }

  Future<bool> unvoteFeature(String featureId) async {
    final url = Uri.parse('$_baseUrl/features/$featureId/unvote/');
    try {
      final headers = await _getAuthHeaders();
      if (headers.isEmpty) {
        print('Cannot unvote: Not authenticated.');
        return false;
      }

      final response = await http.post(url, headers: headers);
      if (response.statusCode == 204) { // 204 No Content for successful deletion
        return true;
      } else {
        print('Failed to unvote feature: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error unvoting feature: $e');
      return false;
    }
  }

  // --- Feature CRUD (for owner/admin) ---
  // Note: This example assumes any authenticated user can CRUD features they own.
  // Django backend permission might need to be fine-tuned.

  Future<bool> updateFeature(String featureId, String title, String description, String status) async {
    final url = Uri.parse('$_baseUrl/features/$featureId/');
    try {
      final headers = await _getAuthHeaders();
      if (headers.isEmpty) return false;

      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode({
          'title': title,
          'description': description,
          'status': status,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating feature: $e');
      return false;
    }
  }

  Future<bool> deleteFeature(String featureId) async {
    final url = Uri.parse('$_baseUrl/features/$featureId/');
    try {
      final headers = await _getAuthHeaders();
      if (headers.isEmpty) return false;

      final response = await http.delete(url, headers: headers);
      return response.statusCode == 204;
    } catch (e) {
      print('Error deleting feature: $e');
      return false;
    }
  }
}