// lib/services/permission_service.dart
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class PermissionService {
  /// Request photo library permissions
  static Future<bool> requestPermissions() async {
    try {
      // Request permission using PhotoManager
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      
      if (ps.isAuth) {
        print('Photo permission granted (isAuth)');
        return true;
      } else if (ps.hasAccess) {
        print('Photo permission granted (hasAccess)');
        return true;
      } else {
        print('Photo permission denied');
        
        // If denied, open settings
        await PhotoManager.openSetting();
        return false;
      }
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if permissions are already granted
  static Future<bool> checkPermissions() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      return ps.isAuth || ps.hasAccess;
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }
}