# healthcare

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# Building an Optimized APK with Agora Voice/Video Calls

This project includes Agora voice and video calling functionality. To build the smallest possible APK:

## Building for Specific Architectures

To build a smaller APK targeted at a specific architecture:

```bash
# For arm64-v8a (most modern Android devices)
flutter build apk --target-platform android-arm64 --release

# For armeabi-v7a (older devices)
flutter build apk --target-platform android-arm --release
```

## Building Android App Bundle

For Play Store distribution, use an Android App Bundle for optimal size:

```bash
flutter build appbundle --release
```

## Size Optimization Notes

1. We've implemented the following optimizations:
   - Using `android:extractNativeLibs="true"` to compress native libraries
   - Configuring ABI splits to include only needed architectures
   - ProGuard/R8 optimization with Agora-specific rules
   - Minimized Agora extensions by only including core functionality

2. Voice calls will consume less space than video calls. If you don't need video calling, you can further reduce the app size by:
   - Modifying the call implementation to only use audio features
   - Removing video-specific permissions and imports

## Using Voice/Video Calls

Voice and video calls have been implemented in:
- `lib/services/call_service.dart` - Core call functionality
- `lib/views/screens/common/calls/voice_call_screen.dart` - Voice call UI
- `lib/views/screens/common/calls/video_call_screen.dart` - Video call UI

Calls can be initiated from the chat detail screen using the phone and video icons in the app bar.
