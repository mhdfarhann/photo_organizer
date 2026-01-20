// lib/screens/select_target_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/photo_provider.dart';
import '../models/photo_item.dart';
import 'results_screen.dart';

class SelectTargetScreen extends StatefulWidget {
  const SelectTargetScreen({Key? key}) : super(key: key);

  @override
  State<SelectTargetScreen> createState() => _SelectTargetScreenState();
}

class _SelectTargetScreenState extends State<SelectTargetScreen> {
  PhotoItem? _selectedPhoto;
  double _threshold = 0.7;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PhotoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Target Photo'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildPhotoGrid(provider),
          ),
          if (_selectedPhoto != null) _buildActionPanel(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Select a photo to find similar images',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Similarity Threshold:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _threshold,
                  min: 0.5,
                  max: 0.95,
                  divisions: 9,
                  label: '${(_threshold * 100).round()}%',
                  onChanged: (value) {
                    setState(() {
                      _threshold = value;
                    });
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(_threshold * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(
            _threshold >= 0.85
                ? '🎯 Very strict - only highly similar photos'
                : _threshold >= 0.70
                    ? '👍 Balanced - good for finding duplicates'
                    : '🔍 Loose - more results, less accuracy',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(PhotoProvider provider) {
    if (provider.allPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No photos available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: provider.allPhotos.length,
      itemBuilder: (context, index) {
        final photo = provider.allPhotos[index];
        final isSelected = _selectedPhoto?.id == photo.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPhoto = photo;
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>(
                future: photo.getThumbnail(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                    );
                  }

                  return Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
              if (isSelected)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 4),
                    color: Colors.blue.withOpacity(0.3),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 48,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Target photo selected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedPhoto = null;
                    });
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _findSimilarPhotos,
                icon: const Icon(Icons.search),
                label: const Text('Find Similar Photos'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _findSimilarPhotos() async {
    if (_selectedPhoto == null) return;

    final provider = context.read<PhotoProvider>();
    await provider.setTargetPhoto(_selectedPhoto!);

    // Show loading dialog with progress
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog(),
    );

    // Start finding similar photos
    try {
      await provider.findSimilarPhotos(threshold: _threshold);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Navigate to results screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ResultsScreen(),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to analyze photos: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildLoadingDialog() {
    return PopScope(
      canPop: false,
      child: Consumer<PhotoProvider>(
        builder: (context, provider, child) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  provider.statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: provider.progress,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(provider.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}