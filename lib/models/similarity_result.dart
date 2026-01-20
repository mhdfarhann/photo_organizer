// lib/models/similarity_result.dart
import 'photo_item.dart';

class SimilarityResult {
  final PhotoItem photo;
  final double similarity;
  bool isSelected;

  SimilarityResult({
    required this.photo,
    required this.similarity,
    this.isSelected = false,
  });

  /// Get similarity as percentage string (e.g., "85%")
  String get similarityPercentage {
    return '${(similarity * 100).toStringAsFixed(0)}%';
  }

  /// Get similarity as percentage value (e.g., 85.5)
  double get similarityPercentageValue {
    return similarity * 100;
  }

  /// Check if photo is highly similar (>= 85%)
  bool get isHighlySimilar => similarity >= 0.85;

  /// Check if photo is moderately similar (>= 70%)
  bool get isSimilar => similarity >= 0.70;

  /// Check if photo is loosely similar (>= 50%)
  bool get isLooselySimilar => similarity >= 0.50;

  /// Get similarity level as string
  String get similarityLevel {
    if (similarity >= 0.90) return 'Very High';
    if (similarity >= 0.80) return 'High';
    if (similarity >= 0.70) return 'Medium';
    if (similarity >= 0.60) return 'Low';
    return 'Very Low';
  }

  /// Get similarity color indicator
  SimilarityColor get similarityColor {
    if (similarity >= 0.90) return SimilarityColor.veryHigh;
    if (similarity >= 0.80) return SimilarityColor.high;
    if (similarity >= 0.70) return SimilarityColor.medium;
    if (similarity >= 0.60) return SimilarityColor.low;
    return SimilarityColor.veryLow;
  }

  /// Toggle selection
  void toggleSelection() {
    isSelected = !isSelected;
  }

  /// Select this result
  void select() {
    isSelected = true;
  }

  /// Deselect this result
  void deselect() {
    isSelected = false;
  }

  /// Create a copy with modified values
  SimilarityResult copyWith({
    PhotoItem? photo,
    double? similarity,
    bool? isSelected,
  }) {
    return SimilarityResult(
      photo: photo ?? this.photo,
      similarity: similarity ?? this.similarity,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  /// Convert to string for debugging
  @override
  String toString() {
    return 'SimilarityResult(photoId: ${photo.id}, similarity: ${similarityPercentage}, selected: $isSelected)';
  }

  /// Check equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SimilarityResult &&
        other.photo.id == photo.id &&
        other.similarity == similarity;
  }

  @override
  int get hashCode => photo.id.hashCode ^ similarity.hashCode;

  /// Convert to JSON (for potential serialization)
  Map<String, dynamic> toJson() {
    return {
      'photoId': photo.id,
      'photoPath': photo.path,
      'similarity': similarity,
      'isSelected': isSelected,
    };
  }

  /// Create from JSON
  static SimilarityResult? fromJson(Map<String, dynamic> json, PhotoItem photo) {
    try {
      return SimilarityResult(
        photo: photo,
        similarity: json['similarity'] as double,
        isSelected: json['isSelected'] as bool? ?? false,
      );
    } catch (e) {
      print('Error parsing SimilarityResult from JSON: $e');
      return null;
    }
  }
}

/// Enum for similarity color coding
enum SimilarityColor {
  veryHigh,  // 90%+  - Green
  high,      // 80%+  - Blue
  medium,    // 70%+  - Orange
  low,       // 60%+  - Yellow
  veryLow,   // <60%  - Red
}

/// Extension for SimilarityColor
extension SimilarityColorExtension on SimilarityColor {
  /// Get color name as string
  String get name {
    switch (this) {
      case SimilarityColor.veryHigh:
        return 'Very High';
      case SimilarityColor.high:
        return 'High';
      case SimilarityColor.medium:
        return 'Medium';
      case SimilarityColor.low:
        return 'Low';
      case SimilarityColor.veryLow:
        return 'Very Low';
    }
  }

  /// Get suggested color value (for UI)
  int get colorValue {
    switch (this) {
      case SimilarityColor.veryHigh:
        return 0xFF4CAF50; // Green
      case SimilarityColor.high:
        return 0xFF2196F3; // Blue
      case SimilarityColor.medium:
        return 0xFFFF9800; // Orange
      case SimilarityColor.low:
        return 0xFFFFC107; // Yellow
      case SimilarityColor.veryLow:
        return 0xFFF44336; // Red
    }
  }
}