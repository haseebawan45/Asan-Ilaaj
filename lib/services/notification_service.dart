import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

// Class to store notification click data
class NotificationData {
  final String? chatRoomId;
  final bool? isDoctor;
  
  NotificationData({this.chatRoomId, this.isDoctor});
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Keep track of the latest notification that was clicked
  NotificationData? lastNotificationClicked;
  
  bool _initialized = false;
  
  // Collection to store user tokens
  final CollectionReference _tokensCollection = FirebaseFirestore.instance.collection('userTokens');
  
  // Create a singleton
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  Future<void> initialize(BuildContext context) async {
    if (_initialized) return;
    
    // Request permission for notifications (Android 13+ requires this)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else {
      print('User declined permission');
      return; // Don't continue if permission denied
    }
    
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        _handleNotificationTap(response);
      },
    );
    
    // Create notification channel for Android
    await _createNotificationChannel();
    
    // Get the token
    String? token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }
    
    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestore(newToken);
    });
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });
    
    // Handle notification click when app is in background but opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });
    
    _initialized = true;
  }
  
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chat_messages', // id
      'Chat Messages', // title
      description: 'Notifications for new chat messages', // description
      importance: Importance.high,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _tokensCollection.doc(user.uid).set({
        'token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      });
    }
  }
  
  void _handleForegroundMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    
    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_messages',
            'Chat Messages',
            channelDescription: 'Notifications for new chat messages',
            icon: android.smallIcon ?? '@mipmap/ic_launcher',
            color: Colors.blue,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: json.encode(message.data),
      );
    }
  }
  
  void _handleNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!) as Map<String, dynamic>;
        if (data.containsKey('chatRoomId')) {
          _checkAndStoreChatRoomData(data['chatRoomId']);
        }
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }
  
  void _handleNotificationClick(RemoteMessage message) {
    if (message.data.containsKey('chatRoomId')) {
      final chatRoomId = message.data['chatRoomId'];
      _checkAndStoreChatRoomData(chatRoomId);
    }
  }
  
  // Helper method to check and store chat room data
  Future<void> _checkAndStoreChatRoomData(String chatRoomId) async {
    try {
      // We need to get the chat room data first
      final roomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      
      if (!roomDoc.exists) {
        print('Chat room not found');
        return;
      }
      
      final roomData = roomDoc.data();
      if (roomData == null) return;
      
      // Get current user ID
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;
      
      // Determine if current user is doctor or patient in this chat
      final isDoctor = currentUserId == roomData['doctorId'];
      
      // Store this data to be used later
      lastNotificationClicked = NotificationData(
        chatRoomId: chatRoomId,
        isDoctor: isDoctor,
      );
    } catch (e) {
      print('Error checking chat room data: $e');
    }
  }
  
  // Method to check if there is a pending notification and clear it
  NotificationData? getAndClearClickedNotification() {
    final data = lastNotificationClicked;
    lastNotificationClicked = null;
    return data;
  }
  
  // Get user's FCM token by user ID
  Future<String?> getUserToken(String userId) async {
    try {
      final doc = await _tokensCollection.doc(userId).get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)['token'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting user token: $e');
      return null;
    }
  }
  
  // Send a chat notification to a specific user
  Future<void> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String messageBody,
    required String chatRoomId,
  }) async {
    // This method would typically call a Cloud Function to send the notification
    // We'll implement a basic structure for now
    try {
      final recipientToken = await getUserToken(recipientId);
      
      if (recipientToken != null) {
        // In a complete implementation, you'd call your Cloud Function here
        // For example:
        /*
        await FirebaseFunctions.instance.httpsCallable('sendChatNotification').call({
          'token': recipientToken,
          'title': senderName,
          'body': messageBody,
          'chatRoomId': chatRoomId
        });
        */
        
        print('Notification would be sent to token: $recipientToken');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}

// Handler for background messages - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Need to initialize Firebase here
  await Firebase.initializeApp();
  
  print("Handling a background message: ${message.messageId}");
  // Don't need to show a notification as FCM will do this automatically on Android
} 