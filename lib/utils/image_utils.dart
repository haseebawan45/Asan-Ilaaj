import 'package:firebase_storage/firebase_storage.dart';

class ImageUtils {
  static Future<String?> getFirebaseImageUrl(String? path) async {
    if (path == null || path.isEmpty) return null;

    // If it's already a full URL, return it
    if (path.startsWith('http')) return path;

    try {
      // Get download URL from Firebase Storage
      final ref = FirebaseStorage.instance.ref(path);
      final url = await ref.getDownloadURL();
      return url;
    } on FirebaseException catch (e) {
      print('Firebase Storage Error: ${e.code} - ${e.message}');
      if (e.code == 'storage/object-not-found') {
        return null;
      } else if (e.code == 'storage/retry-limit-exceeded') {
        // Wait and retry once
        await Future.delayed(const Duration(seconds: 2));
        try {
          final ref = FirebaseStorage.instance.ref(path);
          return await ref.getDownloadURL();
        } catch (e) {
          print('Retry failed: $e');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('Error getting Firebase image URL: $e');
      return null;
    }
  }

  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http') || url.startsWith('https');
  }
} 