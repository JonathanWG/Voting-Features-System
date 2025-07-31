// lib/screens/feature_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../providers/auth_provider.dart';
import '../providers/feature_provider.dart';
import '../models/feature.dart';

class FeatureListScreen extends StatefulWidget {
  const FeatureListScreen({super.key});

  @override
  State<FeatureListScreen> createState() => _FeatureListScreenState();
}

class _FeatureListScreenState extends State<FeatureListScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch features when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FeatureProvider>(context, listen: false).fetchFeatures();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final featureProvider = Provider.of<FeatureProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Voting'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (authProvider.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add New Feature',
              onPressed: () {
                Navigator.of(context).pushNamed('/add-feature');
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Features',
            onPressed: () {
              featureProvider.fetchFeatures();
            },
          ),
          if (authProvider.isAuthenticated)
            TextButton.icon(
              onPressed: () async {
                await authProvider.logout();
                if (mounted) {
                  // Navigate back to auth screen after logout
                  Navigator.of(context).pushReplacementNamed('/auth');
                }
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Logout', style: TextStyle(color: Colors.white)),
            )
          else
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/auth');
              },
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('Login', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: featureProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : featureProvider.errorMessage != null
              ? Center(
                  child: Text(
                    featureProvider.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                )
              : featureProvider.features.isEmpty
                  ? const Center(
                      child: Text(
                        'No features posted yet. Be the first!',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(10.0),
                      itemCount: featureProvider.features.length,
                      itemBuilder: (context, index) {
                        final feature = featureProvider.features[index];
                        return FeatureCard(feature: feature);
                      },
                    ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final Feature feature;

  const FeatureCard({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    // We use listen: false for featureProvider here because we only call methods,
    // we don't need to rebuild the widget when the list changes directly from here.
    final featureProvider = Provider.of<FeatureProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    feature.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                // Show menu button only if user is authenticated and is the creator of the feature
                if (authProvider.isAuthenticated && authProvider.currentUser?.id == feature.createdBy.id)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        // Implement edit functionality here (e.g., navigate to an edit screen)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit functionality not implemented in this example.')),
                        );
                      } else if (value == 'delete') {
                        _confirmDelete(context, feature, featureProvider);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              feature.description,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Divider(color: Colors.grey[300]),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Posted by: ${feature.createdBy.username}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    Text(
                      'on ${DateFormat.yMMMd().format(feature.createdAt)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${feature.voteCount}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      icon: Icon(
                        feature.hasVoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                        color: feature.hasVoted ? Colors.blue : Colors.grey,
                        size: 28,
                      ),
                      onPressed: authProvider.isAuthenticated
                          ? () async {
                              bool success;
                              if (feature.hasVoted) {
                                success = await featureProvider.unvoteFeature(feature.id);
                              } else {
                                success = await featureProvider.upvoteFeature(feature.id);
                              }
                              if (!success && featureProvider.errorMessage != null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(featureProvider.errorMessage!),
                                      backgroundColor: Theme.of(context).colorScheme.error,
                                    ),
                                  );
                                }
                              }
                            }
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please login to vote.')),
                              );
                            },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.bottomRight,
              child: Chip(
                label: Text(
                  feature.status,
                  style: TextStyle(color: _getStatusColor(feature.status)),
                ),
                backgroundColor: _getStatusBackgroundColor(feature.status),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper functions for status chip colors
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open': return Colors.blue.shade800;
      case 'Under Review': return Colors.orange.shade800;
      case 'Planned': return Colors.purple.shade800;
      case 'Completed': return Colors.green.shade800;
      case 'Archived': return Colors.grey.shade800;
      default: return Colors.black;
    }
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status) {
      case 'Open': return Colors.blue.shade50;
      case 'Under Review': return Colors.orange.shade50;
      case 'Planned': return Colors.purple.shade50;
      case 'Completed': return Colors.green.shade50;
      case 'Archived': return Colors.grey.shade50;
      default: return Colors.white;
    }
  }

  void _confirmDelete(BuildContext context, Feature feature, FeatureProvider featureProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "${feature.title}"?'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false); // Dismiss dialog, do not delete
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop(true); // Dismiss dialog, proceed with delete
              final success = await featureProvider.deleteFeature(feature.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Feature deleted successfully!'
                        : featureProvider.errorMessage ?? 'Failed to delete feature.'),
                    backgroundColor: success ? Colors.green : Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}