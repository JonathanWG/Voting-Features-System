// lib/models/feature.dart
import 'user.dart';

class Feature {
  final String id;
  final String title;
  final String description;
  final String status;
  final User createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  int voteCount; // This can be updated in the UI
  bool hasVoted; // This can be updated in the UI

  Feature({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.voteCount = 0,
    this.hasVoted = false,
  });

  factory Feature.fromJson(Map<String, dynamic> json) {
    return Feature(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      createdBy: User.fromJson(json['created_by'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      voteCount: json['vote_count'] as int? ?? 0,
      hasVoted: json['has_voted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'created_by': createdBy.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'vote_count': voteCount,
      'has_voted': hasVoted,
    };
  }
}