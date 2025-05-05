import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/views/screens/menu/appointment_history.dart';
import 'package:healthcare/views/screens/menu/faqs.dart';
import 'package:healthcare/views/screens/menu/payment_method.dart';
import 'package:healthcare/views/screens/menu/profile_update.dart';
import 'package:healthcare/views/screens/onboarding/onboarding_3.dart';
import 'package:healthcare/views/screens/onboarding/signupoptions.dart';
import 'package:healthcare/views/screens/patient/complete_profile/profile_page1.dart';
import 'package:healthcare/views/screens/patient/dashboard/patient_profile_details.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:healthcare/views/screens/dashboard/menu.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../services/cache_service.dart';
import 'package:healthcare/utils/app_theme.dart';

class PatientMenuScreen extends StatefulWidget {
  final String name;
  final String role;
  final double profileCompletionPercentage;
  final UserType userType;
  
  const PatientMenuScreen({
    super.key,
    this.name = "Amna",
    this.role = "Patient",
    this.profileCompletionPercentage = 0.0,
    this.userType = UserType.patient,
  });

  @override
  State<PatientMenuScreen> createState() => _PatientMenuScreenState();
}

class _PatientMenuScreenState extends State<PatientMenuScreen> {
  late List<MenuItem> menuItems;
  late double profileCompletionPercentage;
  bool isLoading = true;
  bool isRefreshing = false;
  String userName = "User";
  String? profileImageUrl;
  String userRole = "Patient";
  Map<String, dynamic>? _userData;
  static const String _userCacheKey = 'patient_profile_data';
  
  @override
  void initState() {
    super.initState();
    _initializeMenuItems();
    profileCompletionPercentage = widget.profileCompletionPercentage;
    // Clean up expired cache entries when app starts
    _cleanupCache();
    _loadData();
    
    // Set status bar to be transparent with light icons
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    // Reset system UI when leaving
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    super.dispose();
  }

  // Clean up expired cache
  Future<void> _cleanupCache() async {
    try {
      await CacheService.cleanupExpiredCache();
    } catch (e) {
      debugPrint('Error cleaning up cache: $e');
    }
  }

  Future<void> _loadData() async {
    try {
    setState(() {
      isLoading = true;
    });

      // First try to load data from cache
      await _loadCachedData();
    
      // Then fetch fresh data from Firestore in the background
      if (!mounted) return;
    _fetchUserData();
    } catch (e) {
      debugPrint('Error in _loadData: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadCachedData() async {
    try {
      Map<String, dynamic>? cachedData = await CacheService.getData(_userCacheKey);
      
      if (cachedData != null && mounted) {
        // Get completion percentage from cache or calculate it
        double cachedPercentage = 0.0;
        if (cachedData.containsKey('completionPercentage')) {
          cachedPercentage = (cachedData['completionPercentage'] as num).toDouble();
        } else {
          cachedPercentage = _calculateCompletionPercentage(cachedData);
        }
        
        setState(() {
          _userData = cachedData;
          userName = cachedData['fullName'] ?? cachedData['name'] ?? "User";
          profileImageUrl = cachedData['profileImageUrl'];
          userRole = cachedData['role'] ?? "Patient";
          profileCompletionPercentage = cachedPercentage;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  Future<void> _fetchUserData() async {
    if (!mounted) return;
    
    setState(() => isRefreshing = true);
    
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      
      // Fetch user data from the users collection
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists || !mounted) {
        setState(() => isRefreshing = false);
        return;
      }
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      // Fetch patient data from the patients collection
      DocumentSnapshot patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(userId)
          .get();
      
      // If patient document exists, merge with userData (patient data takes precedence)
      if (patientDoc.exists) {
        Map<String, dynamic> patientData = patientDoc.data() as Map<String, dynamic>;
        userData.addAll(patientData);
      }
      
      // Calculate completion percentage
      double storedPercentage = userData.containsKey('completionPercentage') 
          ? (userData['completionPercentage'] as num).toDouble()
          : _calculateCompletionPercentage(userData);
      
      // Update Firestore with calculated percentage if needed
      if (!userData.containsKey('completionPercentage')) {
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(userId)
            .set({'completionPercentage': storedPercentage}, SetOptions(merge: true));
      }
      
      if (!mounted) return;
      
      // Check if data has changed before updating state
      bool hasDataChanged = _userData == null || 
          !_areMapContentsEqual(_userData!, userData) ||
          profileCompletionPercentage != storedPercentage;
      
      if (hasDataChanged) {
        setState(() {
          _userData = userData;
          userName = userData['fullName'] ?? userData['name'] ?? "User";
          profileImageUrl = userData['profileImageUrl'];
          userRole = userData['role'] ?? "Patient";
          profileCompletionPercentage = storedPercentage;
        });
        
        // Save updated data to cache with expiration
        await CacheService.saveData(_userCacheKey, userData);
      }
    } catch (e) {
      debugPrint('Error fetching profile data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
          isLoading = false;
        });
      }
    }
  }

  // Calculate profile completion percentage based on filled fields
  double _calculateCompletionPercentage(Map<String, dynamic> userData) {
    int totalFields = 10; // Total number of important profile fields
    int filledFields = 0;
    
    // Check basic profile fields
    if ((userData['fullName']?.toString() ?? '').isNotEmpty) filledFields++;
    if ((userData['email']?.toString() ?? '').isNotEmpty) filledFields++;
    if ((userData['phoneNumber']?.toString() ?? '').isNotEmpty) filledFields++;
    
    // Check medical info
    if ((userData['age']?.toString() ?? '').isNotEmpty) filledFields++;
    if ((userData['bloodGroup']?.toString() ?? '').isNotEmpty) filledFields++;
    if ((userData['height']?.toString() ?? '').isNotEmpty) filledFields++;
    if ((userData['weight']?.toString() ?? '').isNotEmpty) filledFields++;
    
    // Check address info
    if ((userData['address']?.toString() ?? '').isNotEmpty) filledFields++;
    if ((userData['city']?.toString() ?? '').isNotEmpty) filledFields++;
    
    // Check profile image
    if ((userData['profileImageUrl']?.toString() ?? '').isNotEmpty) filledFields++;
    
    return (filledFields / totalFields) * 100;
  }

  // Helper method to compare maps (deep comparison)
  bool _areMapContentsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    
    for (String key in map1.keys) {
      if (!map2.containsKey(key)) return false;
      
      if (map1[key] is Map && map2[key] is Map) {
        if (!_areMapContentsEqual(
            Map<String, dynamic>.from(map1[key] as Map),
            Map<String, dynamic>.from(map2[key] as Map))) {
          return false;
        }
      } else if (map1[key] != map2[key]) {
        return false;
      }
    }
    
    return true;
  }

  Future<void> _refreshData() async {
    try {
      setState(() {
        isRefreshing = true;
      });
      await _fetchUserData();
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    } finally {
      setState(() {
        isRefreshing = false;
      });
    }
  }

  void _initializeMenuItems() {
    menuItems = [
      MenuItem("Edit Profile", LucideIcons.user, CompleteProfilePatient1Screen(
        profileData: _userData,
        isEditing: true,
      )),
      MenuItem("Payment Methods", LucideIcons.creditCard, PaymentMethodsScreen(userType: widget.userType)),
      MenuItem("FAQs", LucideIcons.info, FAQScreen(userType: UserType.patient)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushNamedAndRemoveUntil('/patient/bottom_navigation', (route) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        // Remove SafeArea to allow content to extend into status bar
        body: Stack(
          children: [
            // Header background that extends to top of screen
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 200 + statusBarHeight, // Reduce height to prevent overlap
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(screenSize.width * 0.08),
                    bottomRight: Radius.circular(screenSize.width * 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTeal.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            
            RefreshIndicator(
              onRefresh: _refreshData,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        children: [
                          // Header content with padding for status bar
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 
                              statusBarHeight + verticalPadding, // Add status bar height to top padding
                              horizontalPadding, 
                              verticalPadding * 1.8 // Adjust padding at bottom 
                            ),
                            child: Column(
                              children: [
                                // Back button and title
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).pushNamedAndRemoveUntil('/patient/bottom_navigation', (route) => false);
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.arrow_back, color: Colors.white),
                                      ),
                                    ),
                                    Text(
                                      'Profile',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 40), // Balance the layout
                                  ],
                                ),
                                SizedBox(height: verticalPadding * 1.2),
                                
                                // Profile section
                                Row(
                                  children: [
                                    // Profile image with border
                                    Hero(
                                      tag: 'profileImage',
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: screenSize.width * 0.1,
                                          backgroundImage: profileImageUrl != null
                                              ? NetworkImage(profileImageUrl!)
                                              : const AssetImage("assets/images/User.png") as ImageProvider,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: horizontalPadding),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              userName,
                                              style: GoogleFonts.poppins(
                                                fontSize: screenSize.width * 0.055,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                shadows: const [
                                                  Shadow(
                                                    color: Colors.black12,
                                                    offset: Offset(0, 2),
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Text(
                                            userRole,
                                            style: GoogleFonts.poppins(
                                              fontSize: screenSize.width * 0.035,
                                              color: Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                          SizedBox(height: verticalPadding * 0.6),
                                          
                                          // View detailed profile button
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => const PatientDetailProfileScreen(),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: horizontalPadding * 0.8, 
                                                vertical: verticalPadding * 0.4
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(screenSize.width * 0.03),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.1),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    LucideIcons.user,
                                                    color: AppTheme.primaryTeal,
                                                    size: screenSize.width * 0.04,
                                                  ),
                                                  SizedBox(width: horizontalPadding * 0.4),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      "View Medical Profile",
                                                      style: GoogleFonts.poppins(
                                                        fontSize: screenSize.width * 0.03,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppTheme.primaryTeal,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Space to prevent overlap with header
                          SizedBox(height: verticalPadding * 1.5), // Reduced space here
                          
                          // Profile completion card
                          _buildProfileCompletionCard(screenSize),
                          
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: verticalPadding * 1.25),
                                
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    "Settings",
                                    style: GoogleFonts.poppins(
                                      fontSize: screenSize.width * 0.05,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(height: verticalPadding * 0.8),
                                
                                // Menu items
                                ...menuItems.map((item) => _buildMenuItem(item, screenSize)).toList(),
                                
                                // Logout button
                                _buildLogoutButton(screenSize),
                                
                                SizedBox(height: verticalPadding * 1.25),
                                
                                // App version info
                                Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        "Specialist Doctors App",
                                        style: GoogleFonts.poppins(
                                          fontSize: screenSize.width * 0.035,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryTeal,
                                        ),
                                      ),
                                      SizedBox(height: verticalPadding * 0.2),
                                      Text(
                                        "Version 1.0.0",
                                        style: GoogleFonts.poppins(
                                          fontSize: screenSize.width * 0.03,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: verticalPadding),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Subtle loading indicator at bottom
            if (isLoading || isRefreshing)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(MenuItem item, Size screenSize) {
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;
    
    return Container(
      margin: EdgeInsets.only(bottom: verticalPadding * 0.6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenSize.width * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(screenSize.width * 0.05),
          onTap: () {
            if (item.screen != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => item.screen!),
              );
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, 
              vertical: verticalPadding * 0.8
            ),
            child: Row(
              children: [
                Container(
                  width: screenSize.width * 0.11,
                  height: screenSize.width * 0.11,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FF),
                    borderRadius: BorderRadius.circular(screenSize.width * 0.035),
                  ),
                  child: Icon(
                    item.icon,
                    color: AppTheme.primaryTeal,
                    size: screenSize.width * 0.05,
                  ),
                ),
                SizedBox(width: horizontalPadding * 0.75),
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.038,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  color: Colors.grey.shade400,
                  size: screenSize.width * 0.05,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(Size screenSize) {
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;
    
    return Container(
      margin: EdgeInsets.only(
        top: verticalPadding * 0.25, 
        bottom: verticalPadding
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(screenSize.width * 0.05),
        boxShadow: [
          BoxShadow(
            color: AppTheme.error.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: AppTheme.error.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(screenSize.width * 0.05),
          onTap: () => _showLogoutDialog(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, 
              vertical: verticalPadding * 0.8
            ),
            child: Row(
              children: [
                Container(
                  width: screenSize.width * 0.11,
                  height: screenSize.width * 0.11,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB),
                    borderRadius: BorderRadius.circular(screenSize.width * 0.035),
                  ),
                  child: Icon(
                    LucideIcons.logOut,
                    color: AppTheme.error,
                    size: screenSize.width * 0.05,
                  ),
                ),
                SizedBox(width: horizontalPadding * 0.75),
                Expanded(
                  child: Text(
                    "Logout",
                    style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.038,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFFF5252),
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  color: Color(0xFFFF9E9E),
                  size: screenSize.width * 0.05,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenSize.width * 0.05),
        ),
        contentPadding: EdgeInsets.all(horizontalPadding),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: screenSize.width * 0.18,
              height: screenSize.width * 0.18,
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.logOut,
                color: AppTheme.error,
                size: screenSize.width * 0.08,
              ),
            ),
            SizedBox(height: verticalPadding),
            Text(
              "Logout",
              style: GoogleFonts.poppins(
                fontSize: screenSize.width * 0.055,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: verticalPadding * 0.5),
            Text(
              "Are you sure you want to logout?",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: screenSize.width * 0.038,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: verticalPadding * 1.5),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(screenSize.width * 0.04),
                      child: Ink(
                        padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F1F1),
                          borderRadius: BorderRadius.circular(screenSize.width * 0.04),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Cancel",
                              style: GoogleFonts.poppins(
                                fontSize: screenSize.width * 0.04,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: horizontalPadding * 0.6),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        
                        try {
                          // Clear cache and sign out directly without showing a loading dialog
                          await CacheService.clearAllCache();
                          await FirebaseAuth.instance.signOut();
                        } catch (e) {
                          print('Error during signout: $e');
                          // Continue with navigation even if signout fails
                        } finally {
                          // Always navigate to onboarding screen, regardless of signout success/failure
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const Onboarding3()),
                              (route) => false,
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(screenSize.width * 0.04),
                      child: Ink(
                        padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.8),
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius: BorderRadius.circular(screenSize.width * 0.04),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Logout",
                              style: GoogleFonts.poppins(
                                fontSize: screenSize.width * 0.04,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // New widget for profile completion card
  Widget _buildProfileCompletionCard(Size screenSize) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: profileCompletionPercentage < 100
              ? [AppTheme.primaryPink, AppTheme.primaryPink]
              : [AppTheme.success, AppTheme.success.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (profileCompletionPercentage < 100
                    ? AppTheme.primaryPink
                    : AppTheme.success)
                .withOpacity(0.2),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  profileCompletionPercentage < 100
                      ? LucideIcons.user
                      : LucideIcons.userCheck,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  profileCompletionPercentage < 100
                      ? "Complete Your Profile"
                      : "Profile Complete",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${profileCompletionPercentage.round()}%",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: profileCompletionPercentage < 100
                        ? AppTheme.primaryPink
                        : AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: profileCompletionPercentage / 100,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 5,
            ),
          ),
          if (profileCompletionPercentage < 100) ...[
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CompleteProfilePatient1Screen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Complete Now",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryPink,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          LucideIcons.arrowRight,
                          size: 12,
                          color: AppTheme.primaryPink,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class MenuItem {
  final String title;
  final IconData icon;
  final Widget? screen;

  MenuItem(this.title, this.icon, this.screen);
}
