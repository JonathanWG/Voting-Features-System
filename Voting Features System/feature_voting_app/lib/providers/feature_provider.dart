// lib/providers/feature_provider.dart
import 'package:flutter/material.dart';
import '../models/feature.dart';
import '../services/api_service.dart';
import 'auth_provider.dart'; // To access current user info if needed for client-side checks

class FeatureProvider with ChangeNotifier {
  List<Feature> _features = [];
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _errorMessage;

  List<Feature> get features => _features;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fetches all features from the backend
  Future<void> fetchFeatures() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _features = await _apiService.getFeatures();
    } catch (e) {
      _errorMessage = 'Failed to load features: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Creates a new feature
  Future<bool> createFeature(String title, String description) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final newFeature = await _apiService.createFeature(title, description);
    _isLoading = false;
    if (newFeature != null) {
      _features.insert(0, newFeature); // Add to the beginning for immediate display
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Failed to create feature. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // Handles upvoting a feature
  Future<bool> upvoteFeature(String featureId) async {
    final index = _features.indexWhere((f) => f.id == featureId);
    if (index == -1) return false;

    // Optimistic UI update: update immediately for responsiveness
    _features[index].voteCount++;
    _features[index].hasVoted = true;
    notifyListeners();

    final success = await _apiService.upvoteFeature(featureId);
    if (!success) {
      // Revert UI if API call fails
      _features[index].voteCount--;
      _features[index].hasVoted = false;
      notifyListeners();
      _errorMessage = 'Failed to upvote feature. You might have already voted.';
      return false;
    }
    // If successful, the UI is already updated optimistically
    return true;
  }

  // Handles unvoting a feature
  Future<bool> unvoteFeature(String featureId) async {
    final index = _features.indexWhere((f) => f.id == featureId);
    if (index == -1) return false;

    // Optimistic UI update
    _features[index].voteCount--;
    _features[index].hasVoted = false;
    notifyListeners();

    final success = await _apiService.unvoteFeature(featureId);
    if (!success) {
      // Revert UI if API call fails
      _features[index].voteCount++;
      _features[index].hasVoted = true;
      notifyListeners();
      _errorMessage = 'Failed to unvote feature.';
      return false;
    }
    // If successful, the UI is already updated optimistically
    return true;
  }

  // --- Basic CRUD for Features (for owner/admin, though simplified here) ---

  Future<bool> updateFeature(String featureId, String title, String description, String status) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final success = await _apiService.updateFeature(featureId, title, description, status);
    _isLoading = false;
    if (success) {
      // Re-fetch features to ensure updated data is consistent with backend
      await fetchFeatures();
      return true;
    } else {
      _errorMessage = 'Failed to update feature.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteFeature(String featureId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final success = await _apiService.deleteFeature(featureId);
    _isLoading = false;
    if (success) {
      _features.removeWhere((feature) => feature.id == featureId);
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Failed to delete feature.';
      notifyListeners();
      return false;
    }
  }
}