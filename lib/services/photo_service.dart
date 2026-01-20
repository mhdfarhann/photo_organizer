// lib/services/photo_service.dart
import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../models/photo_item.dart';

class PhotoService {
  /// Load photos from device gallery
  Future<List<PhotoItem>> loadPhotosFromGallery({int maxPhotos = 1000}) async {
    List<PhotoItem> photos = [];

    try {
      // Get all photo albums
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      if (albums.isEmpty) {
        print('No albums found');
        return photos;
      }

      // Get photos from first album (usually "Recent" or "All Photos")
      final AssetPathEntity album = albums.first;
      final int totalCount = await album.assetCountAsync;
      final int loadCount = totalCount > maxPhotos ? maxPhotos : totalCount;

      print('Found $totalCount photos, loading $loadCount');

      // Load photos
      final List<AssetEntity> assets = await album.getAssetListRange(
        start: 0,
        end: loadCount,
      );

      // Convert to PhotoItem
      for (var asset in assets) {
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
          print('Error loading photo ${asset.id}: $e');
          continue;
        }
      }

      print('Successfully loaded ${photos.length} photos');
      return photos;
    } catch (e) {
      print('Error loading photos: $e');
      return photos;
    }
  }

  /// Delete a single photo
  Future<bool> deletePhoto(PhotoItem photo) async {
    try {
      final List<String> result = await PhotoManager.editor.deleteWithIds([photo.id]);
      return result.isNotEmpty;
    } catch (e) {
      print('Error deleting photo: $e');
      return false;
    }
  }

  /// Move photo to a specific folder
  Future<bool> movePhotoToFolder(PhotoItem photo, String folderName) async {
    try {
      // Get external storage directory
      final Directory? directory = await getExternalStorageDirectory();
      if (directory == null) {
        print('External storage not available');
        return false;
      }

      // Create target folder
      final String targetPath = '${directory.path}/$folderName';
      final Directory targetDir = Directory(targetPath);
      
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
        print('Created folder: $targetPath');
      }

      // Copy file to new location
      final File sourceFile = File(photo.path);
      final String fileName = photo.path.split('/').last;
      final String newPath = '$targetPath/$fileName';
      
      await sourceFile.copy(newPath);
      print('Copied photo to: $newPath');

      // Delete original from gallery
      final deleted = await deletePhoto(photo);
      
      if (deleted) {
        print('Moved photo to $folderName');
        return true;
      } else {
        print('Photo copied but not deleted from gallery');
        return false;
      }
    } catch (e) {
      print('Error moving photo: $e');
      return false;
    }
  }

  /// Delete multiple photos
  Future<bool> deletePhotos(List<PhotoItem> photos) async {
    if (photos.isEmpty) {
      return false;
    }

    try {
      final List<String> ids = photos.map((p) => p.id).toList();
      print('Deleting ${ids.length} photos...');
      
      final List<String> result = await PhotoManager.editor.deleteWithIds(ids);
      final success = result.length == ids.length;
      
      if (success) {
        print('Successfully deleted ${result.length} photos');
      } else {
        print('Deleted ${result.length}/${ids.length} photos');
      }
      
      return success;
    } catch (e) {
      print('Error deleting photos: $e');
      return false;
    }
  }

  /// Move multiple photos to folder
  Future<bool> movePhotos(List<PhotoItem> photos, String folderName) async {
    if (photos.isEmpty) {
      return false;
    }

    try {
      print('Moving ${photos.length} photos to $folderName...');
      
      int successCount = 0;

      for (var photo in photos) {
        final success = await movePhotoToFolder(photo, folderName);
        if (success) {
          successCount++;
        }
      }

      print('Moved $successCount photos');
      return successCount == photos.length;
    } catch (e) {
      print('Error moving photos: $e');
      return false;
    }
  }
}