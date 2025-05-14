import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthcare/views/screens/patient/bottom_navigation_patient.dart';
import 'package:healthcare/views/screens/bottom_navigation_bar.dart';
import 'package:healthcare/views/screens/patient/complete_profile/profile_page1.dart';
import 'package:healthcare/views/screens/doctor/complete_profile/doctor_profile_page1.dart';
import 'package:healthcare/views/screens/onboarding/splash.dart';
import 'package:healthcare/views/screens/admin/admin_dashboard.dart';

enum UserRole {
  patient,
  doctor,
  ladyHealthWorker,
  admin,
  unknown,
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for admin credentials
  static Map<String, dynamic>? _cachedAdminCredentials;
  static DateTime? _lastAdminCredentialsFetch;
  static final Duration _cacheDuration = Duration(minutes: 5);

  // Get current user
  User? get currentUser {
    // Check if we're in admin mode
    if (_isAdminSession()) {
      return null; // Admin doesn't have a Firebase Auth user
    }
    return _auth.currentUser;
  }

  // Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is logged in
  bool get isLoggedIn {
    // Check if we have a Firebase Auth user
    if (_auth.currentUser != null) {
      return true;
    }
    
    // Check if we have an admin session
    try {
      final prefs = _getPrefs();
      return prefs != null && prefs.containsKey('admin_session');
    } catch (_) {
      return false;
    }
  }

  // Fetch admin credentials from Firestore
  Future<Map<String, dynamic>?> _fetchAdminCredentials(String phoneNumber) async {
    try {
      // If we already have cached credentials and they're not expired, return them
      if (_cachedAdminCredentials != null && 
          _lastAdminCredentialsFetch != null &&
          DateTime.now().difference(_lastAdminCredentialsFetch!) < _cacheDuration) {
        return _cachedAdminCredentials;
      }
      
      print('***** FETCHING ADMIN CREDENTIALS FOR $phoneNumber *****');
      
      // Query Firestore for admin credentials
      final querySnapshot = await _firestore
          .collection('admin_credentials')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        print('***** NO ADMIN CREDENTIALS FOUND *****');
        return null;
      }
      
      // Get the admin document
      final doc = querySnapshot.docs.first;
      final data = doc.data();
      
      print('***** FOUND ADMIN CREDENTIALS: ${data['phoneNumber']} *****');
      
      // Cache the credentials
      _cachedAdminCredentials = {
        'id': doc.id,
        'phoneNumber': data['phoneNumber'],
        'pin': data['pin'],
        'active': data['active'],
      };
      _lastAdminCredentialsFetch = DateTime.now();
      
      return _cachedAdminCredentials;
    } catch (e) {
      debugPrint('Error fetching admin credentials: $e');
      return null;
    }
  }

  // Check if credentials match admin
  Future<bool> isAdminCredentials(String phoneNumber, String otp) async {
    final adminCredentials = await _fetchAdminCredentials(phoneNumber);
    if (adminCredentials == null) return false;
    
    return adminCredentials['pin'] == otp;
  }

  // Check if phone number is for an admin
  Future<bool> isAdminPhoneNumber(String phoneNumber) async {
    final adminCredentials = await _fetchAdminCredentials(phoneNumber);
    return adminCredentials != null;
  }

  // Get user role from shared preferences (for quicker access)
  Future<UserRole> getUserRole() async {  
    // Always check Firebase Auth first to see if we have a currently authenticated user
    final currentFirebaseUser = _auth.currentUser;
    
    // Get SharedPreferences for session data
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? adminUserId = prefs.getString('admin_session');
    
    print('***** GETTING USER ROLE - Firebase User: ${currentFirebaseUser?.uid}, Admin Session: $adminUserId *****');
    
    // If we have a Firebase user but also an admin session and they don't match,
    // it likely means we've switched from admin to normal user or vice versa
    if (currentFirebaseUser != null && adminUserId != null && currentFirebaseUser.uid != adminUserId) {
      print('***** MISMATCH BETWEEN FIREBASE USER AND ADMIN SESSION - CLEARING ADMIN SESSION *****');
      await prefs.remove('admin_session');
      await prefs.remove('admin_user_id');
      await prefs.remove('admin_phone');
    }
    
    // Only use admin session if there's no Firebase user (admin mode) or the IDs match
    if (adminUserId != null && (currentFirebaseUser == null || currentFirebaseUser.uid == adminUserId)) {
      print('***** FOUND VALID ADMIN SESSION: $adminUserId *****');
      final String? adminRoleStr = prefs.getString('user_role_$adminUserId');
      if (adminRoleStr == 'admin') {
        print('***** RETURNING ADMIN ROLE FOR ADMIN SESSION *****');
        return UserRole.admin;
      }
    }
    
    // If not admin and not logged in, return unknown
    if (currentUser == null) {
      print('***** NO CURRENT USER, RETURNING UNKNOWN ROLE *****');
      return UserRole.unknown;
    }
    
    // First try to get role from Firestore to ensure accuracy
    try {
      print('***** FETCHING USER ROLE FROM FIRESTORE FOR ${currentUser!.uid} *****');
      final userRole = await _fetchUserRoleFromFirestore();
      if (userRole != UserRole.unknown) {
        // If we got a valid role, save it to prefs and return it
        print('***** FOUND VALID ROLE FROM FIRESTORE: $userRole *****');
        await _saveUserRole(userRole);
        return userRole;
      }
    } catch (e) {
      print('***** ERROR FETCHING FROM FIRESTORE: $e *****');
      // Fall back to prefs if Firestore fails
    }
    
    // Try to get role from prefs as fallback
    final String? roleStr = prefs.getString('user_role_${currentUser!.uid}');
    print('***** ROLE FROM PREFS: $roleStr for user ${currentUser!.uid} *****');
    
    if (roleStr == null) {
      print('***** NO CACHED ROLE, RETURNING UNKNOWN *****');
      return UserRole.unknown;
    }
    
    UserRole role;
    switch (roleStr) {
      case 'patient': role = UserRole.patient; break;
      case 'doctor': role = UserRole.doctor; break;
      case 'ladyHealthWorker': role = UserRole.ladyHealthWorker; break;
      case 'admin': role = UserRole.admin; break;
      default: role = UserRole.unknown; break;
    }
    
    print('***** RETURNING ROLE FROM PREFS: $role *****');
    return role;
  }

  // Save user role to shared preferences
  Future<void> _saveUserRole(UserRole role) async {
    if (currentUser == null) return;
    
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String roleStr;
    
    switch (role) {
      case UserRole.patient: roleStr = 'patient'; break;
      case UserRole.doctor: roleStr = 'doctor'; break;
      case UserRole.ladyHealthWorker: roleStr = 'ladyHealthWorker'; break;
      case UserRole.admin: roleStr = 'admin'; break;
      default: roleStr = 'unknown'; break;
    }
    
    print('***** SAVING USER ROLE TO PREFS: $roleStr for user ${currentUser!.uid} *****');
    await prefs.setString('user_role_${currentUser!.uid}', roleStr);
    print('***** ROLE SAVED TO PREFS *****');
  }

  // Fetch user role from Firestore
  Future<UserRole> _fetchUserRoleFromFirestore() async {
    if (currentUser == null) return UserRole.unknown;
    
    try {
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      print('***** FETCHING USER ROLE - DOC EXISTS: ${doc.exists} *****');
      print('***** USER ID: ${currentUser!.uid} *****');
      
      if (!doc.exists) return UserRole.unknown;
      
      final data = doc.data();
      print('***** FIRESTORE USER DATA: $data *****');
      
      if (data == null || !data.containsKey('role')) {
        print('***** NO ROLE FIELD FOUND IN USER DATA *****');
        // Check if there might be a casing issue with the role field
        if (data != null) {
          final keys = data.keys.toList();
          print('***** AVAILABLE FIELDS: $keys *****');
          // Check for alternative casing of 'role'
          for (final key in keys) {
            if (key.toLowerCase() == 'role') {
              print('***** FOUND ROLE WITH DIFFERENT CASING: $key *****');
              final String role = data[key].toString().toLowerCase();
              print('***** ROLE VALUE WITH DIFFERENT CASING: $role *****');
              
              UserRole userRole;
              switch (role) {
                case 'patient': userRole = UserRole.patient; break;
                case 'doctor': userRole = UserRole.doctor; break;
                case 'ladyhealthworker': userRole = UserRole.ladyHealthWorker; break;
                case 'admin': userRole = UserRole.admin; break;
                default: userRole = UserRole.unknown; break;
              }
              
              print('***** DETERMINED USER ROLE FROM ALTERNATIVE CASING: $userRole *****');
              await _saveUserRole(userRole);
              return userRole;
            }
          }
        }
        return UserRole.unknown;
      }
      
      final String role = data['role'].toString().toLowerCase();  // Convert to lowercase for case-insensitive comparison
      print('***** ROLE STRING FROM FIRESTORE (normalized): $role *****');
      
      UserRole userRole;
      switch (role) {
        case 'patient': userRole = UserRole.patient; break;
        case 'doctor': userRole = UserRole.doctor; break;
        case 'ladyhealthworker': userRole = UserRole.ladyHealthWorker; break;
        case 'admin': userRole = UserRole.admin; break;
        default: 
          print('***** UNKNOWN ROLE STRING: $role *****');
          userRole = UserRole.unknown; 
          break;
      }
      
      print('***** DETERMINED USER ROLE: $userRole *****');
      // Cache the result
      await _saveUserRole(userRole);
      return userRole;
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      return UserRole.unknown;
    }
  }

  // Send OTP for signin or signup
  Future<Map<String, dynamic>> sendOTP({
    required String phoneNumber,
  }) async {
    try {
      print('***** SENDING OTP TO $phoneNumber *****');
      
      // Special handling for admin
      final isAdmin = await isAdminPhoneNumber(phoneNumber);
      if (isAdmin) {
        print('***** ADMIN VERIFICATION REQUESTED *****');
        return {
          'success': true,
          'verificationId': 'admin-verification-id-${DateTime.now().millisecondsSinceEpoch}',
          'message': 'Admin verification code sent',
          'isAdmin': true
        };
      }

      final completer = Completer<Map<String, dynamic>>();

      print('***** CALLING FIREBASE VERIFY PHONE NUMBER *****');
      try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
          timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android
          try {
              print('***** AUTO VERIFICATION COMPLETED *****');
            await _auth.signInWithCredential(credential);
            completer.complete({
              'success': true,
              'message': 'Auto-verification successful',
              'autoVerified': true
            });
          } catch (e) {
              print('***** AUTO VERIFICATION FAILED: $e *****');
            completer.complete({
              'success': false,
              'message': 'Auto-verification failed: ${e.toString()}',
              'autoVerified': false
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
            print('***** VERIFICATION FAILED: ${e.code} - ${e.message} *****');
            completer.complete({
              'success': false,
              'message': _getReadableAuthError(e),
              'error': e
            });
        },
        codeSent: (String verificationId, int? resendToken) {
            print('***** OTP CODE SENT SUCCESSFULLY, VERIFICATION ID: $verificationId *****');
          completer.complete({
            'success': true,
            'verificationId': verificationId,
            'resendToken': resendToken,
            'message': 'OTP sent successfully'
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
            print('***** CODE AUTO RETRIEVAL TIMEOUT *****');
          // Only complete if not already completed
          if (!completer.isCompleted) {
            completer.complete({
              'success': true,
              'verificationId': verificationId,
              'message': 'Auto-retrieval timeout'
            });
          }
          }
        );
      } catch (firebaseError) {
        print('***** FIREBASE VERIFICATION ERROR: $firebaseError *****');
        return {
          'success': false,
          'message': 'Failed to send verification code: ${firebaseError.toString()}',
          'error': firebaseError.toString()
        };
      }

      return completer.future;
    } catch (e) {
      print('***** ERROR SENDING OTP: $e *****');
      return {
        'success': false,
        'message': 'Error sending verification code: ${e.toString()}',
        'error': e.toString()
      };
    }
  }

  // Verify OTP and sign in
  Future<Map<String, dynamic>> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    print('***** VERIFYING OTP CODE: $smsCode with VERIFICATION ID: $verificationId *****');
    try {
      // Check if this is an admin verification
      final bool isAdminVerification = verificationId.startsWith('admin-verification-id-');

      // Clear any existing admin session data when a new verification is attempted
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // If this is not an admin verification, clear any existing admin session
      if (!isAdminVerification) {
        print('***** NON-ADMIN VERIFICATION - CLEARING ANY EXISTING ADMIN SESSION *****');
        await prefs.remove('admin_session');
        await prefs.remove('admin_user_id');
        await prefs.remove('admin_phone');
      }
      
      // Handle admin verification
      if (isAdminVerification) {
        print('***** HANDLING ADMIN VERIFICATION *****');
        // Extract timestamp from stored admin verification data
        final String timestampPart = verificationId.split('-').last;
        final int timestamp = int.tryParse(timestampPart) ?? 0;
        
        // Basic validation: ensure the verification ID is not more than 10 minutes old
        if (DateTime.now().millisecondsSinceEpoch - timestamp > 600000) {
          return {
            'success': false,
            'message': 'Admin verification code expired',
            'isAdmin': true
          };
        }
        
        // Find the admin with matching PIN
        print('***** CHECKING ADMIN CREDENTIALS *****');
        final querySnapshot = await _firestore
            .collection('admin_credentials')
            .where('active', isEqualTo: true)
            .get();
        
        String adminPhoneNumber = '';
        String adminId = '';
        bool isValidAdmin = false;
        
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          if (data['pin'] == smsCode) {
            adminPhoneNumber = data['phoneNumber'];
            adminId = doc.id;
            isValidAdmin = true;
            print('***** VALID ADMIN FOUND: $adminId *****');
            break;
          }
        }
        
        if (isValidAdmin) {
          // Create or get admin user from Firestore directly (no Firebase Auth)
          try {
            // Look for existing admin user
            final adminUsersQuery = await _firestore.collection('users')
                .where('phoneNumber', isEqualTo: adminPhoneNumber)
                .where('role', isEqualTo: 'admin')
                .limit(1)
                .get();
                
            String adminUserId;
            
            if (adminUsersQuery.docs.isNotEmpty) {
              // Use existing admin user
              adminUserId = adminUsersQuery.docs.first.id;
              print('***** USING EXISTING ADMIN USER: $adminUserId *****');
              
              // Update last login
              await _firestore.collection('users').doc(adminUserId).update({
                'lastLogin': FieldValue.serverTimestamp(),
              });
            } else {
              // Create new admin user document
              final adminUserRef = _firestore.collection('users').doc();
              adminUserId = adminUserRef.id;
              print('***** CREATING NEW ADMIN USER: $adminUserId *****');
              
              await adminUserRef.set({
                'phoneNumber': adminPhoneNumber,
                'role': 'admin',
                'fullName': 'Admin User',
                'profileComplete': true,
                'createdAt': FieldValue.serverTimestamp(),
                'lastLogin': FieldValue.serverTimestamp(),
                'adminCredentialId': adminId,
                'active': true,
                'profileType': 'admin',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
            
            // Store admin session info in SharedPreferences
            await prefs.setString('admin_user_id', adminUserId);
            await prefs.setString('admin_phone', adminPhoneNumber);
            await prefs.setString('user_role_$adminUserId', 'admin');
            
            // Update the last login timestamp in admin_credentials
            await _firestore.collection('admin_credentials').doc(adminId).update({
              'lastLogin': FieldValue.serverTimestamp()
            });
            
            // Save admin session
            await _saveAdminSession(adminUserId);
            
            print('***** ADMIN VERIFICATION SUCCESS - USER ID: $adminUserId *****');
            print('***** ADMIN SESSION SAVED *****');
            
            return {
              'success': true,
              'userId': adminUserId,
              'isNewUser': false,
              'message': 'Admin verification successful',
              'isAdmin': true
            };
          } catch (e) {
            debugPrint('Error creating admin user: $e');
            return {
              'success': false,
              'message': 'Failed to create admin session: ${e.toString()}'
            };
          }
        } else {
          print('***** INVALID ADMIN VERIFICATION CODE *****');
          return {
            'success': false,
            'message': 'Invalid admin verification code',
            'isAdmin': true
          };
        }
      }
      
      print('***** ATTEMPTING NORMAL FIREBASE AUTH VERIFICATION *****');
      
      try {
      // Normal verification flow
      final AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
        // Try to sign in
        UserCredential? userCredential;
        try {
          userCredential = await _auth.signInWithCredential(credential);
        } catch (e) {
          print('***** ERROR SIGNING IN WITH CREDENTIAL: $e *****');
          
          // Check if this is the specific type error
          if (e.toString().contains("type 'List<Object?>'" ) || 
              e.toString().contains("PigeonUserDetails")) {
            // This is a known issue with Firebase Auth - the sign-in actually succeeded
            // We need to get the current user manually
            await Future.delayed(Duration(milliseconds: 500)); // Wait for auth state to update
            final currentFirebaseUser = _auth.currentUser;
            
            if (currentFirebaseUser != null) {
              print('***** WORKAROUND: GOT USER AFTER ERROR: ${currentFirebaseUser.uid} *****');
              
              // Check if user exists in Firestore
              final bool userExists = await this.userExists(currentFirebaseUser.uid);
              
              return {
                'success': true,
                'user': currentFirebaseUser,
                'isNewUser': !userExists,
                'message': 'OTP verified successfully (with error handling)'
              };
            } else {
              throw Exception("Failed to get user after credential verification");
            }
          } else {
            // Re-throw if it's a different error
            rethrow;
          }
        }
        
        if (userCredential != null && userCredential.user != null) {
          print('***** VERIFICATION SUCCESSFUL: ${userCredential.user?.uid} *****');
      
      // Check if user exists in Firestore
      final bool userExists = await this.userExists(userCredential.user!.uid);
      
      return {
        'success': true,
        'user': userCredential.user,
        'isNewUser': !userExists,
        'message': 'OTP verified successfully'
      };
        } else {
          throw Exception("User credential or user is null after sign-in");
        }
      } catch (credentialError) {
        print('***** NORMAL VERIFICATION FAILED: $credentialError *****');
        
        // Check if the auth state has changed despite the error
        final currentFirebaseUser = _auth.currentUser;
        if (currentFirebaseUser != null) {
          print('***** USER IS ACTUALLY LOGGED IN: ${currentFirebaseUser.uid} *****');
          
          // Check if user exists in Firestore
          final bool userExists = await this.userExists(currentFirebaseUser.uid);
          
          return {
            'success': true,
            'user': currentFirebaseUser,
            'isNewUser': !userExists,
            'message': 'OTP verified successfully (caught error)'
          };
        }
        
        // Rethrow to be caught by outer catch
        throw credentialError;
      }
    } on FirebaseAuthException catch (e) {
      print('***** FIREBASE AUTH EXCEPTION: ${e.code} - ${e.message} *****');
      return {
        'success': false,
        'message': _getReadableAuthError(e),
        'error': e
      };
    } catch (e) {
      print('***** UNEXPECTED ERROR IN VERIFY OTP: $e *****');
      
      // Final check - maybe auth succeeded despite the error
      final currentFirebaseUser = _auth.currentUser;
      if (currentFirebaseUser != null) {
        print('***** FINAL CHECK: USER IS LOGGED IN: ${currentFirebaseUser.uid} *****');
        
        // Check if user exists in Firestore
        final bool userExists = await this.userExists(currentFirebaseUser.uid);
        
        return {
          'success': true,
          'user': currentFirebaseUser,
          'isNewUser': !userExists,
          'message': 'OTP verified with error recovery'
        };
      }
      
      return {
        'success': false,
        'message': 'Failed to verify OTP: ${e.toString()}'
      };
    }
  }

  // Register a new user
  Future<Map<String, dynamic>> registerUser({
    required String uid,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
  }) async {
    try {
      print('***** REGISTERING USER: $fullName with role: $role *****');
      
      // Prepare role string for Firestore - use lowercase for consistency
      String roleStr;
      switch (role) {
        case UserRole.patient: roleStr = 'patient'; break;
        case UserRole.doctor: roleStr = 'doctor'; break;
        case UserRole.ladyHealthWorker: roleStr = 'ladyhealthworker'; break;
        case UserRole.admin: roleStr = 'admin'; break;
        default: roleStr = 'unknown'; break;
      }
      
      print('***** ROLE STR FOR FIRESTORE: $roleStr *****');
      
      // Check if user already exists
      try {
        final existingDoc = await _firestore.collection('users').doc(uid).get();
        if (existingDoc.exists) {
          print('***** USER ALREADY EXISTS WITH UID: $uid *****');
          
          // Check if the existing user has the same phone number
          final existingData = existingDoc.data();
          if (existingData != null && existingData['phoneNumber'] == phoneNumber) {
            print('***** EXISTING USER HAS SAME PHONE NUMBER - UPDATING *****');
            
            // Update existing user data
            await _firestore.collection('users').doc(uid).update({
              'fullName': fullName,
              'role': roleStr,
              'lastLogin': FieldValue.serverTimestamp(),
            });
            
            print('***** EXISTING USER UPDATED SUCCESSFULLY *****');
            
            // Cache user role
            await _saveUserRole(role);
            
            return {
              'success': true,
              'message': 'User updated successfully',
              'isNew': false
            };
          } else {
            print('***** PHONE NUMBER MISMATCH FOR EXISTING USER *****');
            return {
              'success': false,
              'message': 'User ID already exists with different phone number'
            };
          }
        }
      } catch (e) {
        print('***** ERROR CHECKING EXISTING USER: $e *****');
        // Continue with registration if we couldn't check for existing user
      }
      
      // Prepare user data for new user
      final Map<String, dynamic> userData = {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'role': roleStr,  // Always use lowercase for consistency
        'createdAt': FieldValue.serverTimestamp(),
        'profileComplete': false,
        'lastLogin': FieldValue.serverTimestamp(),
      };
      
      print('***** WRITING USER DATA TO FIRESTORE: $userData *****');
      
      // Save user data to Firestore
      await _firestore.collection('users').doc(uid).set(userData);
      
      print('***** USER DATA WRITTEN SUCCESSFULLY *****');
      
      // Cache user role
      await _saveUserRole(role);
      
      return {
        'success': true,
        'message': 'User registered successfully',
        'isNew': true
      };
    } catch (e) {
      print('***** ERROR REGISTERING USER: $e *****');
      return {
        'success': false,
        'message': 'Failed to register user: ${e.toString()}'
      };
    }
  }
  
  // Update user's last login timestamp
  Future<void> updateLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating last login: $e');
    }
  }

  // Check if a user exists in Firestore
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('Error checking if user exists: $e');
      return false;
    }
  }

  // Check if profile is complete
  Future<bool> isProfileComplete() async {
    // Check for admin session first
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? adminUserId = prefs.getString('admin_session');
    
    // Admin users always have a complete profile
    if (adminUserId != null) {
      print('***** ADMIN USER - PROFILE ALWAYS COMPLETE *****');
      return true;
    }
    
    if (currentUser == null) return false;
    
    try {
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (!doc.exists) return false;
      
      final data = doc.data();
      return data != null && data['profileComplete'] == true;
    } catch (e) {
      debugPrint('Error checking profile completion: $e');
      return false;
    }
  }

  // Set profile complete status
  Future<void> setProfileComplete(bool isComplete) async {
    if (currentUser == null) return;
    
    try {
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'profileComplete': isComplete,
      });
    } catch (e) {
      debugPrint('Error setting profile completion: $e');
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserData() async {
    if (currentUser == null) return null;
    
    try {
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (!doc.exists) return null;
      
      return doc.data();
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Clear user-specific role cache
      if (currentUser != null) {
        await prefs.remove('user_role_${currentUser!.uid}');
      }
      
      // Clear admin session completely
      await prefs.remove('admin_session');
      await prefs.remove('admin_user_id');
      await prefs.remove('admin_phone');
      
      // Clear any cached admin credentials
      _cachedAdminCredentials = null;
      _lastAdminCredentialsFetch = null;
      
      print('***** ALL SESSION DATA CLEARED DURING LOGOUT *****');
      
      // Sign out from Firebase Auth
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
  
  // Clear role cache for current user
  Future<void> clearRoleCache() async {
    try {
      if (currentUser != null) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_role_${currentUser!.uid}');
        print('***** CLEARED ROLE CACHE FOR ${currentUser!.uid} *****');
      }
    } catch (e) {
      debugPrint('Error clearing role cache: $e');
    }
  }
  
  // Helper method to get readable auth error messages
  String _getReadableAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The provided phone number is invalid.';
      case 'invalid-verification-code':
        return 'The verification code is invalid. Please check and try again.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'quota-exceeded':
        return 'Service temporarily unavailable. Please try again later.';
      case 'session-expired':
        return 'The verification session has expired. Please request a new code.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }

  // Check if a phone number exists in Firestore and get user data
  Future<Map<String, dynamic>> getUserByPhoneNumber(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
          
      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        final userId = querySnapshot.docs.first.id;
        
        // Parse the role
        UserRole userRole = UserRole.unknown;
        if (userData.containsKey('role')) {
          final String roleStr = userData['role'];
          switch (roleStr) {
            case 'patient': userRole = UserRole.patient; break;
            case 'doctor': userRole = UserRole.doctor; break;
            case 'ladyHealthWorker': userRole = UserRole.ladyHealthWorker; break;
            case 'admin': userRole = UserRole.admin; break;
            default: userRole = UserRole.unknown; break;
          }
        }
        
        return {
          'exists': true,
          'userId': userId,
          'userData': userData,
          'userRole': userRole,
          'isProfileComplete': userData['profileComplete'] ?? false,
        };
      }
      
      // Return not exists if phone number not found in Firestore
      return {'exists': false};
    } catch (e) {
      debugPrint('Error checking user by phone number: $e');
      return {'error': e.toString()};
    }
  }

  // Navigate user to correct screen based on role - simple and direct approach
  Future<Widget> getNavigationScreenForUser({required bool isProfileComplete}) async {
    // Get current user role directly from Firestore for accuracy
    final userRole = await _fetchUserRoleFromFirestore();
    print('***** NAVIGATION: Got user role from Firestore: $userRole *****');
    
    // If we couldn't get a valid role from Firestore, try SharedPreferences as fallback
    if (userRole == UserRole.unknown) {
      final fallbackRole = await getUserRole();
      print('***** NAVIGATION: Using fallback role: $fallbackRole *****');
      
      // Simple direct routing based on role
      if (fallbackRole == UserRole.doctor) {
        print('***** NAVIGATION: Routing to DOCTOR home screen (fallback) *****');
        if (!isProfileComplete) {
          return DoctorProfilePage1Screen();
        } else {
          return BottomNavigationBarScreen(
            key: BottomNavigationBarScreen.navigatorKey,
            profileStatus: "complete",
            userType: "Doctor"
          );
        }
      } 
      else if (fallbackRole == UserRole.patient) {
        print('***** NAVIGATION: Routing to PATIENT home screen (fallback) *****');
        if (!isProfileComplete) {
          return CompleteProfilePatient1Screen();
        } else {
          return BottomNavigationBarPatientScreen(
            key: BottomNavigationBarPatientScreen.navigatorKey,
            profileStatus: "complete"
          );
        }
      }
      else if (fallbackRole == UserRole.ladyHealthWorker) {
        print('***** NAVIGATION: Routing to LHW home screen (fallback) *****');
        if (!isProfileComplete) {
          return CompleteProfilePatient1Screen();
        } else {
          return BottomNavigationBarScreen(
            key: BottomNavigationBarScreen.navigatorKey,
            profileStatus: "complete",
            userType: "LadyHealthWorker"
          );
        }
      }
      else if (fallbackRole == UserRole.admin) {
        print('***** NAVIGATION: Routing to ADMIN DASHBOARD (fallback) *****');
        return AdminDashboard();
      }
      else {
        // Default/fallback
        print('***** NAVIGATION: Unknown role, routing to onboarding (fallback) *****');
        return SplashScreen();
      }
    }
    
    // Simple direct routing based on role from Firestore
    if (userRole == UserRole.doctor) {
      print('***** NAVIGATION: Routing to DOCTOR home screen *****');
      if (!isProfileComplete) {
        return DoctorProfilePage1Screen();
      } else {
        return BottomNavigationBarScreen(
          key: BottomNavigationBarScreen.navigatorKey,
          profileStatus: "complete",
          userType: "Doctor"
        );
      }
    } 
    else if (userRole == UserRole.patient) {
      print('***** NAVIGATION: Routing to PATIENT home screen *****');
      if (!isProfileComplete) {
        return CompleteProfilePatient1Screen();
      } else {
        return BottomNavigationBarPatientScreen(
          key: BottomNavigationBarPatientScreen.navigatorKey,
          profileStatus: "complete"
        );
      }
    }
    else if (userRole == UserRole.ladyHealthWorker) {
      print('***** NAVIGATION: Routing to LHW home screen *****');
      if (!isProfileComplete) {
        return CompleteProfilePatient1Screen();
      } else {
        return BottomNavigationBarScreen(
          key: BottomNavigationBarScreen.navigatorKey,
          profileStatus: "complete",
          userType: "LadyHealthWorker"
        );
      }
    }
    else if (userRole == UserRole.admin) {
      print('***** NAVIGATION: Routing to ADMIN DASHBOARD *****');
      return AdminDashboard();
    }
    else {
      // Default/fallback
      print('***** NAVIGATION: Unknown role, routing to onboarding *****');
      return SplashScreen();
    }
  }

  // Save admin session
  Future<void> _saveAdminSession(String adminUserId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Store the admin user ID
    await prefs.setString('admin_session', adminUserId);
    await prefs.setString('user_role_$adminUserId', 'admin');
    
    // Cache the role
    await _saveUserRole(UserRole.admin);
  }

  // Check if this is an admin session
  bool _isAdminSession() {
    try {
      // SharedPreferences.getInstance() returns a Future, cannot be used synchronously
      final prefs = _getPrefs();
      return prefs?.containsKey('admin_session') ?? false;
    } catch (_) {
      return false;
    }
  }
  
  // Helper method to get cached prefs
  SharedPreferences? _prefsInstance;
  
  // Constructor to initialize SharedPreferences
  AuthService() {
    _initPrefs();
  }
  
  SharedPreferences? _getPrefs() {
    return _prefsInstance;
  }
  
  // Initialize prefs at service startup
  Future<void> _initPrefs() async {
    try {
      _prefsInstance = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Error initializing SharedPreferences: $e');
    }
  }
  
  // Get current user ID (works for both regular users and admin)
  String? get currentUserId {
    // Check if we're in admin mode
    final prefs = _getPrefs();
    final String? adminUserId = prefs?.getString('admin_session');
    
    if (adminUserId != null) {
      print('***** USING ADMIN USER ID: $adminUserId *****');
      return adminUserId;
    }
    
    return _auth.currentUser?.uid;
  }
} 