import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Quality levels for image uploads
  static const int highQuality = 85;
  static const int mediumQuality = 70;
  static const int lowQuality = 50;
  
  /// Maximum dimensions for images
  static const int maxProfileWidth = 500;  // Profile pics don't need to be large
  static const int maxDocumentWidth = 1200;  // Documents need more clarity
  
  /// Uploads an image from an XFile to Firebase Storage
  /// 
  /// Parameters:
  /// - file: XFile containing the image
  /// - path: Storage path where the image should be uploaded
  /// - fileName: Optional filename to use (generates UUID if not provided)
  /// - quality: Image compression quality (default: 85)
  /// - maxWidth: Maximum width for resizing (keeps aspect ratio)
  /// 
  /// Returns the download URL of the uploaded image
  Future<String> uploadImage({
    required XFile file,
    required String path,
    String? fileName,
    int quality = highQuality,
    int maxWidth = maxProfileWidth,
  }) async {
    try {
      // Generate filename if not provided
      final String fileExt = file.path.split('.').last;
      final String name = fileName ?? '${Uuid().v4()}.$fileExt';
      final String storagePath = '$path/$name';
      
      // Get reference to storage location
      final Reference ref = _storage.ref().child(storagePath);
      
      // Compress image before uploading to save bandwidth and storage
      final File compressedFile = await _compressImage(
        file: File(file.path),
        quality: quality,
        maxWidth: maxWidth,
      );
      
      // Upload to Firebase Storage
      final TaskSnapshot snapshot = await ref.putFile(compressedFile);
      
      // Get the download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Clean up the temporary compressed file
      if (compressedFile.path != file.path) {
        await compressedFile.delete();
      }
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }
  
  /// Uploads a profile image for a user
  /// 
  /// Parameters:
  /// - file: XFile containing the image
  /// - userId: User ID of the doctor/patient
  /// - isDoctor: Whether the user is a doctor (determines storage path)
  /// 
  /// Returns the download URL of the uploaded image
  Future<String> uploadProfileImage({
    required XFile file,
    required String userId,
    required bool isDoctor,
  }) async {
    final String userType = isDoctor ? 'doctors' : 'patients';
    return uploadImage(
      file: file,
      path: 'profile_images/$userType/$userId',
      fileName: 'profile.jpg',
      quality: highQuality,
      maxWidth: maxProfileWidth,
    );
  }
  
  /// Uploads a document image (license, CNIC, degree, etc.)
  /// 
  /// Parameters:
  /// - file: XFile containing the image
  /// - userId: User ID of the doctor/patient
  /// - isDoctor: Whether the user is a doctor (determines storage path)
  /// - documentType: Type of document being uploaded
  /// 
  /// Returns the download URL of the uploaded image
  Future<String> uploadDocumentImage({
    required XFile file,
    required String userId,
    required bool isDoctor,
    required String documentType,
  }) async {
    final String userType = isDoctor ? 'doctors' : 'patients';
    return uploadImage(
      file: file,
      path: 'documents/$userType/$userId',
      fileName: '$documentType.jpg',
      quality: highQuality,
      maxWidth: maxDocumentWidth,
    );
  }
  
  /// Deletes an image from Firebase Storage by URL
  Future<void> deleteImage(String imageUrl) async {
    try {
      // Extract file path from the URL
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Error deleting image: $e');
      rethrow;
    }
  }
  
  /// Compresses an image file
  Future<File> _compressImage({
    required File file,
    required int quality,
    required int maxWidth,
  }) async {
    // If the image is already small, don't bother compressing
    final fileSize = await file.length();
    if (fileSize < 500 * 1024) { // Less than 500KB
      return file;
    }
    
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(dir.path, '${Uuid().v4()}.jpg');
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        format: CompressFormat.jpeg,
      );
      
      return result != null ? File(result.path) : file;
    } catch (e) {
      print('Error compressing image: $e');
      return file; // Return original if compression fails
    }
  }
  
  /// Fetches an image as a File from URL for editing
  Future<File?> getImageFileFromUrl(String imageUrl) async {
    try {
      final dir = await getTemporaryDirectory();
      final filename = '${Uuid().v4()}.jpg';
      final file = File('${dir.path}/$filename');
      
      // Download the file from Firebase Storage
      final data = await _storage.refFromURL(imageUrl).getData();
      if (data == null) return null;
      
      // Write to a temporary file
      await file.writeAsBytes(data);
      return file;
    } catch (e) {
      print('Error downloading image: $e');
      return null;
    }
  }
  
  /// Converts a File to XFile for compatibility with image pickers
  XFile fileToXFile(File file) {
    return XFile(file.path);
  }
} 