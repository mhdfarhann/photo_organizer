// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/photo_provider.dart';
import '../services/permission_service.dart';
import 'select_target_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasPermission = false;
  bool _isLoadingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoadingPermission = true;
    });

    final hasPermission = await PermissionService.checkPermissions();
    
    setState(() {
      _hasPermission = hasPermission;
      _isLoadingPermission = false;
    });

    if (hasPermission) {
      _loadPhotos();
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoadingPermission = true;
    });

    final granted = await PermissionService.requestPermissions();
    
    setState(() {
      _hasPermission = granted;
      _isLoadingPermission = false;
    });

    if (granted) {
      _loadPhotos();
    } else {
      _showPermissionDeniedDialog();
    }
  }

  Future<void> _loadPhotos() async {
    final provider = context.read<PhotoProvider>();
    await provider.loadPhotos();
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Photo access is required to use this app. Please grant permission in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestPermissions();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Organizer'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoadingPermission
          ? const Center(child: CircularProgressIndicator())
          : _hasPermission
              ? _buildBody()
              : _buildPermissionRequest(),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library,
              size: 100,
              color: Colors.blue.shade300,
            ),
            const SizedBox(height: 32),
            const Text(
              'Permission Required',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This app needs access to your photos to organize them using AI.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _requestPermissions,
              icon: const Icon(Icons.security),
              label: const Text('Grant Permission'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<PhotoProvider>(
      builder: (context, provider, child) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 120,
                  color: Colors.blue.shade400,
                ),
                const SizedBox(height: 32),
                const Text(
                  'AI Photo Organizer',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Find and manage similar photos using AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 48),
                
                if (provider.isLoading)
                  Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        provider.statusMessage,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  )
                else if (provider.allPhotos.isEmpty)
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _loadPhotos,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Load Photos from Gallery'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (provider.statusMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            provider.statusMessage,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${provider.allPhotos.length}',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Photos Loaded',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SelectTargetScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Start Finding Similar Photos'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 18,
                          ),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _loadPhotos,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload Photos'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}