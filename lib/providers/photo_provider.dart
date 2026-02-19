// lib/providers/photo_provider.dart
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo_item.dart';
import '../models/similarity_result.dart';
import '../services/ml_service.dart';
import '../services/photo_service.dart';
import '../services/cache_service.dart';

class PhotoProvider extends ChangeNotifier {
  final MLService _mlService = MLService();
  final PhotoService _photoService = PhotoService();
  final CacheService _cacheService = CacheService();

  List<PhotoItem> _allPhotos = [];
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  PhotoItem? _targetPhoto;
  List<SimilarityResult> _similarPhotos = [];
  bool _isLoading = false;
  String _statusMessage = '';
  double _progress = 0.0;

  final Map<String, List<double>> _embeddingCache = {};

  List<PhotoItem> get allPhotos => _allPhotos;
  List<AssetPathEntity> get albums => _albums;
  AssetPathEntity? get selectedAlbum => _selectedAlbum;
  PhotoItem? get targetPhoto => _targetPhoto;
  List<SimilarityResult> get similarPhotos => _similarPhotos;
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  double get progress => _progress;
  int get cacheSize => _embeddingCache.length;

  Future<void> loadAlbums() async {
    _isLoading = true;
    _statusMessage = 'Loading albums...';
    notifyListeners();

    try {
      _albums = await _photoService.getAlbums();
      if (_albums.isNotEmpty && _selectedAlbum == null) {
        _selectedAlbum = _albums.first;
      }
      _statusMessage = 'Found ${_albums.length} albums';
    } catch (e) {
      _statusMessage = 'Error loading albums: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectAlbum(AssetPathEntity album) async {
    if (_selectedAlbum?.id == album.id) return; // Tidak reload kalau sama
    _selectedAlbum = album;
    _allPhotos = [];
    notifyListeners();
    await loadPhotos();
  }

  Future<void> loadPhotos({bool forceRefresh = false}) async {
    if (_selectedAlbum == null) {
      await loadAlbums();
      if (_selectedAlbum == null) return;
    }

    _isLoading = true;
    _progress = 0.0;

    // Cek apakah ada cache
    final hasCache = await _cacheService.isCacheValid(_selectedAlbum!.id);
    _statusMessage = hasCache
        ? 'Loading from cache...'
        : 'Loading photos from gallery...';
    notifyListeners();

    try {
      final totalCount = await _selectedAlbum!.assetCountAsync;

      _allPhotos = await _photoService.loadAllPhotosFromAlbum(
        _selectedAlbum!,
        forceRefresh: forceRefresh,
        onProgress: (loaded, total) {
          _progress = total > 0 ? loaded / total : 0;
          _statusMessage = hasCache
              ? 'Loading from cache: $loaded/$total'
              : 'Loading: $loaded/$total photos';
          notifyListeners();
        },
      );

      _statusMessage = 'Loaded ${_allPhotos.length} photos';
    } catch (e) {
      _statusMessage = 'Error: $e';
    }

    _isLoading = false;
    _progress = 1.0;
    notifyListeners();
  }

  Future<void> setTargetPhoto(PhotoItem photo) async {
    _targetPhoto = photo;
    notifyListeners();
  }

  Future<void> findSimilarPhotos({double threshold = 0.7}) async {
    if (_targetPhoto == null) return;

    _isLoading = true;
    _statusMessage = 'Initializing ML model...';
    _progress = 0.0;
    _similarPhotos = [];
    notifyListeners();

    try {
      await _mlService.initialize();

      _statusMessage = 'Analyzing target photo...';
      notifyListeners();

      List<double> targetFeatures;
      if (_embeddingCache.containsKey(_targetPhoto!.id)) {
        targetFeatures = _embeddingCache[_targetPhoto!.id]!;
      } else {
        targetFeatures = await _mlService.extractFeatures(_targetPhoto!.path);
        if (targetFeatures.isNotEmpty) {
          _embeddingCache[_targetPhoto!.id] = targetFeatures;
        }
      }

      if (targetFeatures.isEmpty) {
        _statusMessage = 'Failed to analyze target photo';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _targetPhoto!.embedding = targetFeatures;

      final photosToProcess =
          _allPhotos.where((p) => p.id != _targetPhoto!.id).toList();
      final total = photosToProcess.length;
      List<SimilarityResult> results = [];
      const int batchSize = 5;

      for (int i = 0; i < total; i += batchSize) {
        final end = (i + batchSize).clamp(0, total);
        final batch = photosToProcess.sublist(i, end);

        final futures = batch.map((photo) async {
          List<double> features;
          if (_embeddingCache.containsKey(photo.id)) {
            features = _embeddingCache[photo.id]!;
          } else {
            features = await _mlService.extractFeatures(photo.path);
            if (features.isNotEmpty) _embeddingCache[photo.id] = features;
          }

          if (features.isEmpty) return null;
          photo.embedding = features;

          final similarity = _mlService.calculateCosineSimilarity(
            targetFeatures,
            features,
          );

          return similarity >= threshold
              ? SimilarityResult(photo: photo, similarity: similarity)
              : null;
        });

        final batchResults = await Future.wait(futures);
        for (final r in batchResults) {
          if (r != null) results.add(r);
        }

        _progress = (i + batch.length) / total;
        _statusMessage =
            'Analyzed ${i + batch.length}/$total (cached: ${_embeddingCache.length})';
        notifyListeners();
      }

      results.sort((a, b) => b.similarity.compareTo(a.similarity));
      _similarPhotos = results;
      _statusMessage = 'Found ${_similarPhotos.length} similar photos';
    } catch (e) {
      _statusMessage = 'Error: $e';
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
    for (var r in _similarPhotos) r.isSelected = true;
    notifyListeners();
  }

  void deselectAll() {
    for (var r in _similarPhotos) r.isSelected = false;
    notifyListeners();
  }

  List<SimilarityResult> getSelectedPhotos() =>
      _similarPhotos.where((r) => r.isSelected).toList();

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
        for (final p in photos) _embeddingCache.remove(p.id);
        _similarPhotos.removeWhere((r) => r.isSelected);
        _statusMessage = 'Deleted ${selected.length} photos';
      } else {
        _statusMessage = 'Failed to delete some photos';
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _statusMessage = 'Error: $e';
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
        for (final p in photos) _embeddingCache.remove(p.id);
        _similarPhotos.removeWhere((r) => r.isSelected);
        _statusMessage = 'Moved ${selected.length} photos to $folderName';
      } else {
        _statusMessage = 'Failed to move some photos';
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _statusMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshAlbum() async {
    await loadPhotos(forceRefresh: true);
  }

  void clearEmbeddingCache() {
    _embeddingCache.clear();
    notifyListeners();
  }

  Future<void> clearAllCache() async {
    await _cacheService.clearAllCache();
    _embeddingCache.clear();
    notifyListeners();
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