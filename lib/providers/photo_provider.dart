// lib/providers/photo_provider.dart
import 'package:flutter/foundation.dart';
import '../models/photo_item.dart';
import '../models/similarity_result.dart';
import '../services/ml_service.dart';
import '../services/photo_service.dart';

class PhotoProvider extends ChangeNotifier {
  final MLService _mlService = MLService();
  final PhotoService _photoService = PhotoService();

  List<PhotoItem> _allPhotos = [];
  PhotoItem? _targetPhoto;
  List<SimilarityResult> _similarPhotos = [];  // <-- Explicit type
  bool _isLoading = false;
  String _statusMessage = '';
  double _progress = 0.0;

  List<PhotoItem> get allPhotos => _allPhotos;
  PhotoItem? get targetPhoto => _targetPhoto;
  List<SimilarityResult> get similarPhotos => _similarPhotos;  // <-- Explicit type
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  double get progress => _progress;

  Future<void> loadPhotos() async {
    _isLoading = true;
    _statusMessage = 'Loading photos from gallery...';
    notifyListeners();

    try {
      _allPhotos = await _photoService.loadPhotosFromGallery();
      _statusMessage = 'Loaded ${_allPhotos.length} photos';
    } catch (e) {
      _statusMessage = 'Error loading photos: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setTargetPhoto(PhotoItem photo) async {
    _targetPhoto = photo;
    _statusMessage = 'Target photo selected';
    notifyListeners();
  }

  Future<void> findSimilarPhotos({double threshold = 0.7}) async {
    if (_targetPhoto == null) {
      _statusMessage = 'Please select a target photo first';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _statusMessage = 'Initializing ML model...';
    _progress = 0.0;
    _similarPhotos = [];
    notifyListeners();

    try {
      await _mlService.initialize();

      _statusMessage = 'Analyzing target photo...';
      notifyListeners();
      
      final targetFeatures = await _mlService.extractFeatures(_targetPhoto!.path);
      
      if (targetFeatures.isEmpty) {
        _statusMessage = 'Failed to analyze target photo';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _targetPhoto!.embedding = targetFeatures;

      _statusMessage = 'Analyzing ${_allPhotos.length} photos...';
      notifyListeners();

      List<SimilarityResult> results = [];  // <-- Explicit type
      
      for (int i = 0; i < _allPhotos.length; i++) {
        final photo = _allPhotos[i];
        
        if (photo.id == _targetPhoto!.id) continue;

        final features = await _mlService.extractFeatures(photo.path);
        
        if (features.isNotEmpty) {
          photo.embedding = features;
          
          final similarity = _mlService.calculateCosineSimilarity(
            targetFeatures,
            features,
          );

          if (similarity >= threshold) {
            results.add(SimilarityResult(
              photo: photo,
              similarity: similarity,
            ));
          }
        }

        _progress = (i + 1) / _allPhotos.length;
        _statusMessage = 'Analyzed ${i + 1}/${_allPhotos.length} photos';
        notifyListeners();
      }

      // Fix sorting with explicit types
      results.sort((a, b) => b.similarity.compareTo(a.similarity));
      _similarPhotos = results;

      _statusMessage = 'Found ${_similarPhotos.length} similar photos';
    } catch (e) {
      _statusMessage = 'Error: $e';
      print('Error in findSimilarPhotos: $e');
    }

    _isLoading = false;
    _progress = 1.0;
    notifyListeners();
  }

  void togglePhotoSelection(int index) {
    if (index >= 0 && index < _similarPhotos.length) {
      _similarPhotos[index].isSelected = !_similarPhotos[index].isSelected;
      notifyListeners();
    }
  }

  void selectAll() {
    for (var result in _similarPhotos) {
      result.isSelected = true;
    }
    notifyListeners();
  }

  void deselectAll() {
    for (var result in _similarPhotos) {
      result.isSelected = false;
    }
    notifyListeners();
  }

  List<SimilarityResult> getSelectedPhotos() {
    return _similarPhotos.where((r) => r.isSelected).toList();
  }

  Future<bool> deleteSelectedPhotos() async {
    final selected = getSelectedPhotos();
    if (selected.isEmpty) return false;

    _isLoading = true;
    _statusMessage = 'Deleting ${selected.length} photos...';
    notifyListeners();

    try {
      final photos = selected.map((r) => r.photo).toList();
      final success = await _photoService.deletePhotos(photos);

      if (success) {
        _similarPhotos.removeWhere((r) => r.isSelected);
        _statusMessage = 'Deleted ${selected.length} photos';
      } else {
        _statusMessage = 'Failed to delete some photos';
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _statusMessage = 'Error deleting photos: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> moveSelectedPhotos(String folderName) async {
    final selected = getSelectedPhotos();
    if (selected.isEmpty) return false;

    _isLoading = true;
    _statusMessage = 'Moving ${selected.length} photos...';
    notifyListeners();

    try {
      final photos = selected.map((r) => r.photo).toList();
      final success = await _photoService.movePhotos(photos, folderName);

      if (success) {
        _similarPhotos.removeWhere((r) => r.isSelected);
        _statusMessage = 'Moved ${selected.length} photos to $folderName';
      } else {
        _statusMessage = 'Failed to move some photos';
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _statusMessage = 'Error moving photos: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _targetPhoto = null;
    _similarPhotos = [];
    _statusMessage = '';
    _progress = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _mlService.dispose();
    super.dispose();
  }
}