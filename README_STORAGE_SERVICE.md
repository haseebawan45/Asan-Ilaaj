# StorageService Documentation

The `StorageService` class is a centralized service for handling image uploads to Firebase Storage in the healthcare app. It provides consistent, optimized methods for uploading different types of images with appropriate compression and organization.

## Features

- **Standardized Image Upload**: Consistent file paths and naming in Firebase Storage
- **Image Compression**: Automatic compression to reduce bandwidth and storage usage
- **Quality Settings**: Different quality levels for different image types (profile vs documents)
- **Error Handling**: Robust error handling and cleanup of temporary files
- **Helper Methods**: Convenience methods for common upload operations

## Usage Examples

### Basic Usage

```dart
import 'package:healthcare/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';

// Create an instance of the service
final storageService = StorageService();

// Get an image from image_picker
final ImagePicker picker = ImagePicker();
final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery);

if (pickedImage != null) {
  // Upload the image with custom options
  final String downloadUrl = await storageService.uploadImage(
    file: pickedImage,
    path: 'my_custom_path',
    fileName: 'custom_name.jpg',
    quality: StorageService.highQuality,
    maxWidth: 800,
  );
  
  // Use the download URL as needed
  print('Image uploaded. URL: $downloadUrl');
}
```

### Uploading Profile Images

```dart
// For a patient profile image
final String downloadUrl = await storageService.uploadProfileImage(
  file: pickedImage,
  userId: currentUserId,
  isDoctor: false, // This is for a patient
);

// For a doctor profile image
final String downloadUrl = await storageService.uploadProfileImage(
  file: pickedImage,
  userId: currentUserId,
  isDoctor: true, // This is for a doctor
);
```

### Uploading Document Images

```dart
// For document images (medical license, CNIC, degree, etc.)
final String downloadUrl = await storageService.uploadDocumentImage(
  file: pickedImage,
  userId: currentUserId,
  isDoctor: true,
  documentType: 'medical_license_front',
);
```

### Working with Existing Images

```dart
// Converting a URL to a File for editing
final File? imageFile = await storageService.getImageFileFromUrl(imageUrl);

if (imageFile != null) {
  // Edit the image...
  
  // When done, convert back to XFile for upload
  final XFile xFile = storageService.fileToXFile(imageFile);
  
  // Upload the edited image
  final String newUrl = await storageService.uploadProfileImage(
    file: xFile,
    userId: currentUserId,
    isDoctor: true,
  );
}
```

### Deleting Images

```dart
// Delete an image by its download URL
await storageService.deleteImage(imageUrl);
```

## Quality Settings

The service provides three quality presets:

- `StorageService.highQuality` (85) - For important images like profile pictures
- `StorageService.mediumQuality` (70) - For general-purpose images
- `StorageService.lowQuality` (50) - For less important images or when bandwidth is a concern

## Image Size Settings

The service provides two size presets:

- `StorageService.maxProfileWidth` (500px) - For profile images
- `StorageService.maxDocumentWidth` (1200px) - For document images that need more clarity

## Best Practices

1. **Use Helper Methods**: Prefer using the specific helper methods like `uploadProfileImage` and `uploadDocumentImage` over the generic `uploadImage` method to ensure consistent file organization.

2. **Handle Errors**: Always wrap calls to the storage service in try-catch blocks to handle potential errors gracefully.

3. **Cleanup**: The service automatically cleans up temporary files after upload, but make sure to handle any other temporary files in your code.

4. **Compression Settings**: Use the appropriate quality settings for different types of images to balance quality vs. bandwidth usage.

5. **Image Dimensions**: Consider the intended use of the image when setting the maxWidth parameter. Don't upload images at sizes larger than needed.

## File Organization in Firebase Storage

The service organizes files in Firebase Storage with the following structure:

- Profile images: `profile_images/[doctors|patients]/[userId]/profile.jpg`
- Document images: `documents/[doctors|patients]/[userId]/[documentType].jpg`

This structured approach makes it easier to manage and locate files, implement security rules, and perform cleanup operations. 