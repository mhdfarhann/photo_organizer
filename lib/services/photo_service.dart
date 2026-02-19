// lib/services/photo_service.dart
import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../models/photo_item.dart';
import 'cache_service.dart';

class PhotoService {
  final CacheService _cacheService = CacheService();

  Future<List<AssetPathEntity>> getAlbums() async {
    try {
      return await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
        ),
      );
    } catch (e) {
      print('Error getting albums: $e');
      return [];
    }
  }

  /// Load foto dari album — gunakan cache assetId+path jika tersedia
  Future<List<PhotoItem>> loadAllPhotosFromAlbum(
    AssetPathEntity album, {
    bool forceRefresh = false,
    Function(int loaded, int total)? onProgress,
  }) async {
    final albumId = album.id;

    // ── Coba dari cache ──────────────────────────────────────────────────
    if (!forceRefresh && await _cacheService.isCacheValid(albumId)) {
      final cachedData = await _cacheService.getAlbumData(albumId);
      if (cachedData != null && cachedData.isNotEmpty) {
        print('Cache hit: ${cachedData.length} items for ${album.name}');
        return await _buildFromCache(cachedData, album, onProgress: onProgress);
      }
    }

    // ── Load fresh dari galeri ───────────────────────────────────────────
    print('Cache miss, loading fresh: ${album.name}');
    final photos = await _loadFromGallery(album, onProgress: onProgress);

    // Simpan ke cache: {id, path}
    if (photos.isNotEmpty) {
      final items = photos
          .map((p) => {'id': p.id, 'path': p.path})
          .toList();
      await _cacheService.saveAlbumData(albumId, items);
    }

    return photos;
  }

  /// Rebuild PhotoItems dari cache.
  /// Pakai getAssetListRange lalu filter by id — compatible semua versi photo_manager.
  Future<List<PhotoItem>> _buildFromCache(
    List<Map<String, String>> cachedData,
    AssetPathEntity album, {
    Function(int loaded, int total)? onProgress,
  }) async {
    // Build map id→path dari cache untuk lookup cepat
    final pathMap = {
      for (final item in cachedData) item['id']!: item['path']!
    };
    final cachedIds = pathMap.keys.toSet();
    final total = cachedData.length;

    List<PhotoItem> photos = [];
    int loaded = 0;
    const batchSize = 200;

    final totalAssets = await album.assetCountAsync;

    for (int i = 0; i < totalAssets; i += batchSize) {
      final end = (i + batchSize).clamp(0, totalAssets);
      final assets = await album.getAssetListRange(start: i, end: end);

      for (final asset in assets) {
        if (cachedIds.contains(asset.id)) {
          final cachedPath = pathMap[asset.id]!;
          // Cek file masih ada, pakai cached path (tidak perlu asset.file)
          if (await File(cachedPath).exists()) {
            photos.add(PhotoItem(
              id: asset.id,
              asset: asset,
              path: cachedPath,
            ));
          }
          loaded++;
          if (loaded % 100 == 0) {
            onProgress?.call(loaded, total);
          }
        }
      }

      // Early exit jika semua cached ID sudah ditemukan
      if (loaded >= cachedIds.length) break;
    }

    onProgress?.call(photos.length, total);
    print('Rebuilt ${photos.length} PhotoItems from cache');
    return photos;
  }

  /// Load langsung dari galeri (tidak ada cache)
  Future<List<PhotoItem>> _loadFromGallery(
    AssetPathEntity album, {
    Function(int loaded, int total)? onProgress,
  }) async {
    List<PhotoItem> photos = [];
    final int totalCount = await album.assetCountAsync;
    const int batchSize = 100;

    for (int i = 0; i < totalCount; i += batchSize) {
      final end = (i + batchSize).clamp(0, totalCount);
      final assets = await album.getAssetListRange(start: i, end: end);

      for (final asset in assets) {
        try {
          final file = await asset.file;
          if (file != null && await file.exists()) {
            photos.add(PhotoItem(
              id: asset.id,
              asset: asset,
              path: file.path,
            ));
          }
        } catch (e) {
          continue;
        }
      }

      onProgress?.call(photos.length, totalCount);
    }

    return photos;
  }

  Future<List<PhotoItem>> loadPhotosFromGallery() async {
    try {
      final albums = await getAlbums();
      if (albums.isEmpty) return [];
      return await loadAllPhotosFromAlbum(albums.first);
    } catch (e) {
      print('Error: $e');
      return [];
    }
  }

  Future<bool> deletePhoto(PhotoItem photo) async {
    try {
      final result = await PhotoManager.editor.deleteWithIds([photo.id]);
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> movePhotoToFolder(PhotoItem photo, String folderName) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return false;

      final targetDir = Directory('${dir.path}/$folderName');
      if (!await targetDir.exists()) await targetDir.create(recursive: true);

      final fileName = photo.path.split('/').last;
      await File(photo.path).copy('${targetDir.path}/$fileName');
      return await deletePhoto(photo);
    } catch (e) {
      print('Error moving photo: $e');
      return false;
    }
  }

  Future<bool> deletePhotos(List<PhotoItem> photos) async {
    if (photos.isEmpty) return false;
    try {
      final ids = photos.map((p) => p.id).toList();
      final result = await PhotoManager.editor.deleteWithIds(ids);
      return result.length == ids.length;
    } catch (e) {
      return false;
    }
  }

  Future<bool> movePhotos(List<PhotoItem> photos, String folderName) async {
    if (photos.isEmpty) return false;
    try {
      int success = 0;
      for (final p in photos) {
        if (await movePhotoToFolder(p, folderName)) success++;
      }
      return success == photos.length;
    } catch (e) {
      return false;
    }
  }
}