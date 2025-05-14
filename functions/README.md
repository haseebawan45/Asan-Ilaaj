# Firebase Cloud Functions for Chat Notifications

This directory contains Firebase Cloud Functions for handling chat notifications in the Specialist Doctors app.

## Features

- `sendChatNotification`: Automatically sends push notifications when a new message is added to a chat room.
- `updateOnlineStatus`: Updates user online status in all relevant chat rooms.

## Prerequisites

1. Firebase CLI installed: `npm install -g firebase-tools`
2. Firebase Blaze plan (required for Cloud Functions)
3. Firebase project initialized

## Setup and Deployment

1. **Login to Firebase CLI**:
   ```bash
   firebase login
   ```

2. **Initialize your Firebase project** (if not already initialized):
   ```bash
   firebase init
   ```
   - Select the Firebase project you want to use
   - Choose Functions
   - Select JavaScript
   - Say yes to ESLint
   - Say yes to installing dependencies

3. **Deploy the functions**:
   ```bash
   firebase deploy --only functions
   ```

## Configuration

Make sure your Flutter app has the correct permissions for notifications:

- For Android, the `AndroidManifest.xml` should include:
  ```xml
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
  <uses-permission android:name="android.permission.WAKE_LOCK" />
  <uses-permission android:name="android.permission.VIBRATE" />
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
  ```

## Testing

To test the notifications:

1. Make sure Firebase Cloud Messaging is properly set up in your Flutter app.
2. Send a message from one user to another.
3. The receiving user should get a notification if the app is in the background or closed.

## Troubleshooting

- Check Firebase Function logs in the Firebase Console to debug issues.
- Ensure your app has the latest FCM token stored in Firestore.
- For Android devices, make sure notification permissions are granted.
- Verify that your device can receive FCM messages using the Firebase console "Send test message" feature.

## Important Notes

- These functions require a Blaze (pay-as-you-go) plan on Firebase.
- The first invocation of a function might be slow due to cold starts.
- There are quotas and limits for Firebase Functions. Check the Firebase documentation for details. 