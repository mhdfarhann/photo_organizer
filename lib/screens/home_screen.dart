// lib/screens/home_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/photo_provider.dart';
import '../services/permission_service.dart';
import 'select_target_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _permissionGranted = false;
  bool _showAlbumPicker = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final granted = await PermissionService.requestPermissions();
    setState(() => _permissionGranted = granted);

    if (granted && mounted) {
      final provider = context.read<PhotoProvider>();
      await provider.loadAlbums();
      await provider.loadPhotos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PhotoProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: !_permissionGranted
          ? _buildPermissionDenied()
          : _showAlbumPicker
              ? _buildAlbumPicker(provider)
              : _buildHome(provider),
    );
  }

  // ─── HOME ────────────────────────────────────────────────────────────────

  Widget _buildHome(PhotoProvider provider) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(provider),
        SliverToBoxAdapter(
          child: provider.isLoading
              ? _buildLoadingCard(provider)
              : _buildBody(provider),
        ),
      ],
    );
  }

  Widget _buildAppBar(PhotoProvider provider) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.blue.shade700,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Photo Organizer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade800, Colors.blue.shade500],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Album',
          onPressed: provider.isLoading ? null : () => provider.refreshAlbum(),
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'clear_cache') {
              await provider.clearAllCache();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache cleared')),
                );
              }
            } else if (value == 'clear_embedding') {
              provider.clearEmbeddingCache();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Embedding cache cleared')),
                );
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'clear_embedding',
              child: Row(children: [
                Icon(Icons.memory, size: 18),
                SizedBox(width: 8),
                Text('Clear Embedding Cache'),
              ]),
            ),
            const PopupMenuItem(
              value: 'clear_cache',
              child: Row(children: [
                Icon(Icons.delete_sweep, size: 18),
                SizedBox(width: 8),
                Text('Clear All Cache'),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingCard(PhotoProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                provider.statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: provider.progress > 0 ? provider.progress : null,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              if (provider.progress > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${(provider.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(PhotoProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected album card
          _buildSelectedAlbumCard(provider),
          const SizedBox(height: 16),

          // Stats row
          _buildStatsRow(provider),
          const SizedBox(height: 24),

          // Find similar button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: provider.allPhotos.isEmpty
                  ? null
                  : () {
                      provider.reset();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SelectTargetScreen(),
                        ),
                      );
                    },
              icon: const Icon(Icons.image_search, size: 24),
              label: const Text('Find Similar Photos'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Analyzing ${provider.allPhotos.length} photos from "${provider.selectedAlbum?.name ?? ''}"',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAlbumCard(PhotoProvider provider) {
    final album = provider.selectedAlbum;
    if (album == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _showAlbumPicker = true),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Album thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FutureBuilder<Uint8List?>(
                future: _getAlbumThumbnail(album),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    );
                  }
                  return Container(
                    width: 64,
                    height: 64,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.photo_album, color: Colors.grey),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Album',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    album.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${provider.allPhotos.length} photos loaded',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(PhotoProvider provider) {
    return Row(
      children: [
        _buildStatCard(
          icon: Icons.photo,
          value: '${provider.allPhotos.length}',
          label: 'Photos',
          color: Colors.blue,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.photo_album,
          value: '${provider.albums.length}',
          label: 'Albums',
          color: Colors.purple,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.memory,
          value: '${provider.cacheSize}',
          label: 'Cached',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ALBUM PICKER ────────────────────────────────────────────────────────

  Widget _buildAlbumPicker(PhotoProvider provider) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        title: const Text(
          'Choose Album',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _showAlbumPicker = false),
        ),
      ),
      body: provider.albums.isEmpty
          ? const Center(child: Text('No albums found'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: provider.albums.length,
              itemBuilder: (context, index) {
                final album = provider.albums[index];
                final isSelected = provider.selectedAlbum?.id == album.id;
                return _buildAlbumCard(album, isSelected, provider);
              },
            ),
    );
  }

  Widget _buildAlbumCard(
    AssetPathEntity album,
    bool isSelected,
    PhotoProvider provider,
  ) {
    return GestureDetector(
      onTap: () async {
        setState(() => _showAlbumPicker = false);
        if (provider.selectedAlbum?.id != album.id) {
          await provider.selectAlbum(album);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: Colors.blue, width: 3)
              : Border.all(color: Colors.transparent, width: 3),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail background
              FutureBuilder<Uint8List?>(
                future: _getAlbumThumbnail(album),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                    );
                  }
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Icon(
                      Icons.photo_album,
                      size: 48,
                      color: Colors.grey,
                    ),
                  );
                },
              ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),

              // Album info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        album.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      FutureBuilder<int>(
                        future: album.assetCountAsync,
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.hasData
                                ? '${snapshot.data} photos'
                                : '...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Selected checkmark
              if (isSelected)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _getAlbumThumbnail(AssetPathEntity album) async {
    try {
      final assets = await album.getAssetListRange(start: 0, end: 1);
      if (assets.isEmpty) return null;
      return await assets.first.thumbnailDataWithSize(
        const ThumbnailSize(300, 300),
      );
    } catch (e) {
      return null;
    }
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Permission Required',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please grant access to your photo gallery to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _init,
              icon: const Icon(Icons.settings),
              label: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }
}