import 'dart:io';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter_image_compress/flutter_image_compress.dart'; // COMMENTED OUT DUE TO BUILD ISSUES
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart'; // Import for XFile

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
      print("Starting image upload process:");
      print("File path: ${file.path}");
      print("Storage path: $path");
      
      // Check if file exists
      final fileObj = File(file.path);
      if (!await fileObj.exists()) {
        print("ERROR: File does not exist at path: ${file.path}");
        throw Exception("File not found at ${file.path}");
      }
      print("File exists and has size: ${await fileObj.length()} bytes");
      
      // Generate filename if not provided
      final String fileExt = file.path.split('.').last;
      final String name = fileName ?? '${Uuid().v4()}.$fileExt';
      final String storagePath = '$path/$name';
      
      print("Full storage path: $storagePath");
      
      // Get reference to storage location
      final Reference ref = _storage.ref().child(storagePath);
      
      print("Got storage reference");
      
      // Create explicit metadata to avoid null pointer issues
      final metadata = SettableMetadata(
        contentType: 'image/${fileExt == 'jpg' ? 'jpeg' : fileExt}',
        customMetadata: {
          'uploaded_by': 'app_user',
          'timestamp': DateTime.now().toIso8601String(),
          'quality': quality.toString(),
          'maxWidth': maxWidth.toString(),
        },
      );
      
      print("Created metadata: $metadata");
      
      // Upload to Firebase Storage with retries and better error handling
      print("Starting upload to Firebase Storage...");
      
      TaskSnapshot? snapshot;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (snapshot == null && retryCount < maxRetries) {
        try {
          // Use explicit metadata in putFile call
          final uploadTask = ref.putFile(
            fileObj,
            metadata,
          );
          
          // Add error handling for the upload task
          uploadTask.snapshotEvents.listen(
            (TaskSnapshot snap) {
              print("Upload progress: ${snap.bytesTransferred}/${snap.totalBytes}");
            },
            onError: (error) {
              print("Upload error: $error");
              if (error.toString().contains('channel-error')) {
                throw Exception("Firebase Storage connection error: $error");
              }
            },
          );
          
          snapshot = await uploadTask.timeout(
            const Duration(minutes: 3),
            onTimeout: () {
              print("Upload timed out, will retry");
              throw TimeoutException("Upload timed out");
            },
          );
          
          print("Upload complete! Status: ${snapshot.state}");
        } catch (e) {
          retryCount++;
          print("Upload error (attempt $retryCount/$maxRetries): $e");
          
          if (e.toString().contains('channel-error')) {
            print("Platform channel error detected. Retrying in 2 seconds...");
            await Future.delayed(const Duration(seconds: 2));
          } else if (e is FirebaseException) {
            print("Firebase error code: ${e.code}");
            if (e.code == 'unauthorized' || e.code == 'unauthenticated') {
              rethrow;
            }
          } else if (retryCount >= maxRetries) {
            print("Max retries reached, giving up");
            rethrow;
          }
          
          await Future.delayed(Duration(seconds: retryCount));
        }
      }
      
      if (snapshot == null) {
        throw Exception("Failed to upload file after $maxRetries attempts");
      }
      
      // Get the download URL with retries
      print("Getting download URL...");
      String? downloadUrl;
      retryCount = 0;
      
      while (downloadUrl == null && retryCount < maxRetries) {
        try {
          downloadUrl = await snapshot.ref.getDownloadURL();
          print("Got download URL: $downloadUrl");
        } catch (e) {
          retryCount++;
          print("Error getting download URL (attempt $retryCount/$maxRetries): $e");
          
          if (retryCount >= maxRetries) {
            print("Max retries reached, giving up");
            rethrow;
          }
          
          await Future.delayed(Duration(seconds: retryCount));
        }
      }
      
      if (downloadUrl == null) {
        throw Exception("Failed to get download URL after $maxRetries attempts");
      }
      
      return downloadUrl;
    } catch (e) {
      print('Error during image upload process: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      
      if (e.toString().contains('channel-error')) {
        throw Exception("Firebase Storage connection error. Please check your internet connection and try again.");
      }
      
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
    // TEMPORARY IMPLEMENTATION - Uses original file without compression
    // When flutter_image_compress is available, this should be replaced with proper compression
    print('Image compression is disabled. Using original file: ${file.path}');
    return file;
    
    /* COMMENTED OUT DUE TO BUILD ISSUES
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
    */
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