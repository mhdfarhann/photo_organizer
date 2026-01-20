// lib/models/photo_item.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';

class PhotoItem {
  final String id;
  final AssetEntity asset;
  final String path;
  List<double>? embedding;

  PhotoItem({
    required this.id,
    required this.asset,
    required this.path,
    this.embedding,
  });

  Future<Uint8List?> getThumbnail() async {
    return await asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
    );
  }

  Future<File?> getFile() async {
    return await asset.file;
  }
}