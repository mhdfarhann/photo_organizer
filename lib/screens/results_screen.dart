// lib/screens/results_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/photo_provider.dart';
import '../models/similarity_result.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({Key? key}) : super(key: key);

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final TextEditingController _folderController = TextEditingController();

  @override
  void dispose() {
    _folderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PhotoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Similar Photos'),
        actions: [
          if (provider.similarPhotos.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'select_all') {
                  provider.selectAll();
                } else if (value == 'deselect_all') {
                  provider.deselectAll();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'select_all',
                  child: Text('Select All'),
                ),
                const PopupMenuItem(
                  value: 'deselect_all',
                  child: Text('Deselect All'),
                ),
              ],
            ),
        ],
      ),
      body: provider.similarPhotos.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildHeader(provider),
                Expanded(child: _buildPhotoGrid(provider)),
              ],
            ),
      bottomNavigationBar: provider.getSelectedPhotos().isNotEmpty
          ? _buildActionBar(provider)
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            const Text(
              'No Similar Photos Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Try selecting a different photo or lowering the similarity threshold.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PhotoProvider provider) {
    final selectedCount = provider.getSelectedPhotos().length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found ${provider.similarPhotos.length} similar photos',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (selectedCount > 0)
                  Text(
                    '$selectedCount selected',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                    ),
                  ),
              ],
            ),
          ),
          if (provider.targetPhoto != null)
            FutureBuilder<Widget>(
              future: _buildThumbnail(provider.targetPhoto!.asset),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: snapshot.data!,
                    ),
                  );
                }
                return const SizedBox(width: 60, height: 60);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(PhotoProvider provider) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 0.8,
      ),
      itemCount: provider.similarPhotos.length,
      itemBuilder: (context, index) {
        final result = provider.similarPhotos[index];
        return _buildPhotoItem(result, index, provider);
      },
    );
  }

  Widget _buildPhotoItem(
    SimilarityResult result,
    int index,
    PhotoProvider provider,
  ) {
    return GestureDetector(
      onTap: () {
        provider.togglePhotoSelection(index);
      },
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                FutureBuilder<Widget>(
                  future: _buildThumbnail(result.photo.asset),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return snapshot.data!;
                    }
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                ),
                if (result.isSelected)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 3),
                      color: Colors.blue.withOpacity(0.3),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(result.similarity * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<Widget> _buildThumbnail(AssetEntity asset) async {
    final thumb = await asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
    );
    
    if (thumb != null) {
      return Image.memory(
        thumb,
        fit: BoxFit.cover,
      );
    }
    
    return Container(
      color: Colors.grey.shade300,
      child: const Icon(Icons.image),
    );
  }

  Widget _buildActionBar(PhotoProvider provider) {
    final selectedCount = provider.getSelectedPhotos().length;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showMoveDialog(provider),
                icon: const Icon(Icons.drive_file_move),
                label: Text('Move ($selectedCount)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showDeleteDialog(provider),
                icon: const Icon(Icons.delete),
                label: Text('Delete ($selectedCount)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoveDialog(PhotoProvider provider) async {
    _folderController.text = 'SimilarPhotos';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Photos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Move ${provider.getSelectedPhotos().length} photos to folder:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _folderController,
              decoration: const InputDecoration(
                labelText: 'Folder name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final folderName = _folderController.text.trim();
              if (folderName.isNotEmpty) {
                _showLoadingDialog();
                await provider.moveSelectedPhotos(folderName);
                if (mounted) Navigator.pop(context);
                _showSnackBar('Photos moved successfully');
              }
            },
            child: const Text('Move'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(PhotoProvider provider) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photos'),
        content: Text(
          'Are you sure you want to delete ${provider.getSelectedPhotos().length} photos? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showLoadingDialog();
              await provider.deleteSelectedPhotos();
              if (mounted) Navigator.pop(context);
              _showSnackBar('Photos deleted successfully');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing...'),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}