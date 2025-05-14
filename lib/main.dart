import 'package:flutter/material.dart';
import 'package:healthcare/views/screens/onboarding/splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:healthcare/firebase_options.dart';
import 'package:healthcare/views/screens/bottom_navigation_bar.dart';
import 'package:healthcare/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthcare/views/screens/patient/bottom_navigation_patient.dart';
import 'package:healthcare/views/screens/patient/complete_profile/profile_page1.dart';
import 'package:healthcare/views/screens/doctor/complete_profile/doctor_profile_page1.dart';
import 'package:healthcare/views/screens/menu/appointment_history.dart';
import 'package:healthcare/views/screens/menu/faqs.dart';
import 'package:healthcare/views/screens/menu/payment_method.dart';
import 'package:healthcare/views/screens/menu/profile_update.dart';
import 'package:healthcare/views/screens/dashboard/menu.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthcare/views/screens/patient/dashboard/home.dart';
import 'package:healthcare/utils/app_theme.dart';
import 'package:healthcare/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:healthcare/models/chat_room_model.dart';
import 'package:healthcare/views/screens/common/chat/chat_detail_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with explicit error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Test Firebase Storage initialization
    final storage = FirebaseStorage.instance;
    print("Firebase Storage initialized successfully: $storage");
    
    // Set preferred orientations and initialize other aspects
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    runApp(const MyApp());
  } catch (e) {
    print("Error initializing Firebase: $e");
    // You might want to show an error screen here
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Error initializing app. Please try again.',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Helper method to determine user type from Firestore
  Future<UserType> _getUserType() async {
    try {
      final auth = FirebaseAuth.instance;
      final uid = auth.currentUser?.uid;
      
      if (uid != null) {
        // Check if user exists in doctors collection
        final doctorDoc = await FirebaseFirestore.instance.collection('doctors').doc(uid).get();
        if (doctorDoc.exists) {
          return UserType.doctor;
        }
        
        // Check if user exists in patients collection
        final patientDoc = await FirebaseFirestore.instance.collection('patients').doc(uid).get();
        if (patientDoc.exists) {
          return UserType.patient;
        }
      }
    } catch (e) {
      debugPrint('Error determining user type: $e');
    }
    
    // Default fallback
    return UserType.patient;
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // Scaffold key needed for global context access
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    
    // Initialize notification service with context after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        // NotificationService().initialize(navigatorKey.currentContext!); // COMMENTED OUT DUE TO BUILD ISSUES
      }
    });
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Add navigator key
      theme: AppTheme.getThemeData(), // Apply our centralized theme
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/profile/edit': (context) => const ProfileEditorScreen(),
        '/appointments/history': (context) => const AppointmentHistoryScreen(),
        '/payment/methods': (context) => PaymentMethodsScreen(userType: UserType.doctor),
        '/faqs': (context) {
          // Try to determine the user type from auth service
          final authService = AuthService();
          if (authService.isLoggedIn) {
            // Check if the user is a doctor or patient and pass the appropriate userType
            return FutureBuilder<UserType>(
              future: _getUserType(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                  return FAQScreen(userType: snapshot.data);
                }
                // Default or loading state - show all FAQs
                return const FAQScreen();
              },
            );
          }
          // User not logged in, show all FAQs
          return const FAQScreen();
        },
        '/bottom_navigation': (context) => const BottomNavigationBarScreen(profileStatus: "complete"),
        '/patient/home': (context) => const PatientHomeScreen(profileStatus: "complete"),
        '/patient/bottom_navigation': (context) => const BottomNavigationBarPatientScreen(
          profileStatus: "complete",
          profileCompletionPercentage: 100.0,
        ),
        '/help': (context) => Scaffold(
          appBar: AppBar(title: const Text("Help Center")),
          body: const Center(child: Text("Help Center Coming Soon")),
        ),
        '/medical/records': (context) => Scaffold(
          appBar: AppBar(title: const Text("Medical Records")),
          body: const Center(child: Text("Medical Records Coming Soon")),
        ),
      },
    );
  }
}

// Authentication Wrapper Component
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _initialized = false;
  bool _error = false;
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  // Check if user is already authenticated
  Future<void> _checkAuthState() async {
    try {
      // Check for existing authentication
      if (_authService.isLoggedIn) {
        // Update last login timestamp
        await _authService.updateLastLogin(_authService.currentUser!.uid);
        
        // Check profile completion status
        final isProfileComplete = await _authService.isProfileComplete();
        
        setState(() {
          _checkingAuth = false;
          _initialized = true;
        });
        
        // First check if there's a pending notification
        /* COMMENTED OUT DUE TO BUILD ISSUES
        final notificationService = NotificationService();
        final notificationData = notificationService.getAndClearClickedNotification();
        
        if (notificationData != null && notificationData.chatRoomId != null) {
          // If there's a notification, navigate to the chat room
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToChatFromNotification(notificationData);
          });
        } else {
        */
          // Use the simplified navigation helper
          final navigationScreen = await _authService.getNavigationScreenForUser(
            isProfileComplete: isProfileComplete
          );
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => navigationScreen),
            );
          });
        // } // COMMENTED OUT DUE TO BUILD ISSUES
      } else {
        // No existing user - need to go through onboarding flow
        setState(() {
          _checkingAuth = false;
          _initialized = true;
        });
      }
    } catch (e) {
      print('Error checking authentication state: $e');
      setState(() {
        _error = true;
        _checkingAuth = false;
        _initialized = true;
      });
    }
  }
  
  // Navigate to chat room from notification
  Future<void> _navigateToChatFromNotification(NotificationData notificationData) async {
    try {
      // Get the chat room document
      final roomDoc = await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(notificationData.chatRoomId)
          .get();
          
      if (!roomDoc.exists) {
        // Fallback to normal navigation if chat room doesn't exist
        final navigationScreen = await _authService.getNavigationScreenForUser(
          isProfileComplete: true
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => navigationScreen),
        );
        return;
      }
      
      // Import needed here to avoid circular dependencies in notification_service.dart
      // This is only used in a user-facing component, not a service
      final chatRoom = ChatRoom.fromFirestore(roomDoc);
      
      // Navigate to the chat screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            chatRoom: chatRoom,
            isDoctor: notificationData.isDoctor ?? false,
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to chat room: $e');
      // Fallback to normal navigation if anything goes wrong
      final navigationScreen = await _authService.getNavigationScreenForUser(
        isProfileComplete: true
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => navigationScreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking authentication
    if (_checkingAuth) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // If there was an error or user is not logged in, go to splash screen
    if (_error || !_authService.isLoggedIn) {
      return Scaffold(
        body: SplashScreen(),
      );
    }
    
    // This is a placeholder - navigation happens in checkAuthState
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}