import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int maxRetries;
  final Duration retryDuration;
  final bool circular;

  const FirebaseCachedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.maxRetries = 3,
    this.retryDuration = const Duration(seconds: 3),
    this.circular = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      maxHeightDiskCache: 1500,
      memCacheWidth: 800,
      fadeInDuration: const Duration(milliseconds: 500),
      fadeOutDuration: const Duration(milliseconds: 500),
      placeholderFadeInDuration: const Duration(milliseconds: 500),
      placeholder: (context, url) => placeholder ?? 
          Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      errorWidget: (context, url, error) {
        print('Error loading image: $error');
        return errorWidget ?? 
          Container(
            color: Colors.grey[200],
            child: const Icon(Icons.error_outline, color: Colors.red),
          );
      },
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: imageProvider,
            fit: fit,
          ),
        ),
      ),
    );

    if (circular) {
      return ClipOval(child: imageWidget);
    }

    return imageWidget;
  }

  static Future<String?> getValidImageUrl(String path) async {
    try {
      return await FirebaseStorage.instance.ref(path).getDownloadURL();
    } on FirebaseException catch (e) {
      print('Firebase Storage Error: ${e.code} - ${e.message}');
      if (e.code == 'storage/object-not-found') {
        return null;
      } else if (e.code == 'storage/retry-limit-exceeded') {
        // Wait and retry
        await Future.delayed(const Duration(seconds: 2));
        return getValidImageUrl(path);
      }
      return null;
    } catch (e) {
      print('Error getting download URL: $e');
      return null;
    }
  }
} 