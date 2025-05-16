import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/utils/app_theme.dart';
import 'package:healthcare/utils/ui_helper.dart';
import 'package:healthcare/views/screens/menu/appointment_history.dart';
import 'package:healthcare/views/screens/menu/availability.dart';
import 'package:healthcare/views/screens/menu/faqs.dart';
import 'package:healthcare/views/screens/menu/payment_method.dart';
import 'package:healthcare/views/screens/menu/profile_update.dart';
import 'package:healthcare/views/screens/onboarding/onboarding_3.dart';
import 'package:healthcare/views/screens/onboarding/signupoptions.dart';
import 'package:healthcare/views/screens/patient/appointment/available_doctors.dart';
import 'package:healthcare/views/screens/doctor/availability/doctor_availability_screen.dart';
import 'package:healthcare/views/screens/doctor/hospitals/manage_hospitals_screen.dart';
import 'package:healthcare/views/screens/doctor/complete_profile/doctor_profile_page1.dart';
import 'package:healthcare/utils/navigation_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthcare/services/auth_service.dart';
import 'package:healthcare/services/doctor_profile_service.dart';
import 'package:healthcare/views/screens/bottom_navigation_bar.dart';
import 'package:healthcare/views/screens/patient/bottom_navigation_patient.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthcare/views/screens/dashboard/home.dart';
import 'package:healthcare/views/screens/doctor/complete_profile/doctor_profile_page1.dart';
import 'package:flutter/services.dart';

enum UserType { doctor, patient }

class MenuScreen extends StatefulWidget {
  final UserType userType;
  final String name;
  final String role;
  
  const MenuScreen({
    super.key, 
    this.userType = UserType.doctor,
    this.name = "Loading...",
    this.role = "Please wait...",
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late List<MenuItem> menuItems;
  
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final DoctorProfileService _doctorProfileService = DoctorProfileService();
  
  // User profile data
  String _userName = "";
  String _userRole = "";
  String? _profileImageUrl;
  bool _isLoading = true;
  
  // Doctor profile data
  String _specialty = "";
  double _rating = 0.0;
  String _experience = "";
  String _consultationFee = "";
  
  // Stats for doctors
  int _appointmentsCount = 0;
  double _totalEarnings = 0;
  
  // Cache keys
  static const String _userDataCacheKey = 'user_data_cache';
  static const String _doctorProfileCacheKey = 'doctor_profile_cache';
  bool _isRefreshing = false;
  
  @override
  void initState() {
    super.initState();
    
    // Use UIHelper for consistent status bar styling
    UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
    
    // Set up global error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('FLUTTER ERROR: ${details.exception}');
      debugPrint('STACK TRACE: ${details.stack}');
      FlutterError.presentError(details);
    };
    
    _initializeMenuItems();
    _loadUserDataWithCache();
  }
  
  // Load user data with caching strategy
  Future<void> _loadUserDataWithCache() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    // First try to load from cache
    await _loadFromCache();

    // Then start background refresh
    _refreshDataInBackground();
  }

  // Load data from cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load user data from cache
      final String? userDataJson = prefs.getString(_userDataCacheKey);
      if (userDataJson != null) {
        final userData = json.decode(userDataJson);
        _updateUIWithUserData(userData);
      }

      // Load doctor profile from cache if user is a doctor
      if (widget.userType == UserType.doctor) {
        final String? doctorProfileJson = prefs.getString(_doctorProfileCacheKey);
        if (doctorProfileJson != null) {
          final doctorProfile = json.decode(doctorProfileJson);
          _updateUIWithDoctorProfile(doctorProfile);
        }
      }
    } catch (e) {
      debugPrint('Error loading from cache: $e');
    } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
    }
      }
      
  // Refresh data in background
  Future<void> _refreshDataInBackground() async {
    if (!mounted) return;
      
          setState(() {
      _isRefreshing = true;
    });

    try {
      // Get current user ID
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get user data from Firestore
      final userData = await _authService.getUserData();
      if (userData != null) {
        // Convert any Timestamps to ISO strings before caching
        final Map<String, dynamic> processedUserData = _processDataForCache(userData);
        
        // Cache user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userDataCacheKey, json.encode(processedUserData));
        _updateUIWithUserData(userData);
      }
      
      // Get user role
      final UserRole userRole = await _authService.getUserRole();
      
      // Load doctor-specific data if user is a doctor
      if (userRole == UserRole.doctor) {
        final doctorProfile = await _doctorProfileService.getDoctorProfile();
        final doctorStats = await _doctorProfileService.getDoctorStats();

        // Combine profile and stats
        final Map<String, dynamic> fullDoctorProfile = {
          ...doctorProfile,
          ...doctorStats,
        };

        // Process data for caching (convert Timestamps)
        final processedDoctorProfile = _processDataForCache(fullDoctorProfile);

        // Cache doctor profile
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_doctorProfileCacheKey, json.encode(processedDoctorProfile));
        _updateUIWithDoctorProfile(fullDoctorProfile);
      }
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    } finally {
        if (mounted) {
          setState(() {
          _isRefreshing = false;
          });
        }
      }
  }

  // Helper method to process data for caching
  Map<String, dynamic> _processDataForCache(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toIso8601String());
      } else if (value is Map) {
        return MapEntry(key, _processDataForCache(Map<String, dynamic>.from(value)));
      } else if (value is List) {
        return MapEntry(key, value.map((item) {
          if (item is Map) {
            return _processDataForCache(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList());
      }
      return MapEntry(key, value);
    });
  }

  // Update UI with user data
  void _updateUIWithUserData(Map<String, dynamic> userData) {
      if (mounted) {
        setState(() {
        _userName = userData['fullName'] ?? userData['name'] ?? widget.name;
        _userRole = widget.userType == UserType.doctor ? _specialty : "Patient";
        _profileImageUrl = userData['profileImageUrl'];
      });
    }
  }

  // Update UI with doctor profile
  void _updateUIWithDoctorProfile(Map<String, dynamic> profile) {
      if (mounted) {
        setState(() {
        _specialty = profile['specialty'] ?? "";
        _userRole = _specialty.isNotEmpty ? _specialty : widget.role;
        _rating = (profile['rating'] ?? 0.0).toDouble();
        _experience = profile['experience'] != null ? "${profile['experience']} years" : "";
        _consultationFee = profile['fee'] != null ? "Rs. ${profile['fee']}" : "";
        _appointmentsCount = profile['totalAppointments'] ?? 0;
        _totalEarnings = (profile['totalEarnings'] ?? 0.0).toDouble();
      });
    }
  }
  
  void _initializeMenuItems() {
    if (widget.userType == UserType.doctor) {
      menuItems = [
        MenuItem("Edit Profile", Icons.person, () => const DoctorProfilePage1Screen(isEditing: true), category: "Account"),
        MenuItem("Payment Methods", Icons.credit_card, () => PaymentMethodsScreen(userType: widget.userType), category: "Payment"),
        MenuItem("FAQs", Icons.info_outline, () => FAQScreen(userType: widget.userType), category: "Support"),
        MenuItem("Logout", Icons.logout, () => Container(), category: ""),
      ];
    } else {
      // Patient menu items
      menuItems = [
        MenuItem("Edit Profile", Icons.person, () => const ProfileEditorScreen(), category: "Account"),
        MenuItem("Medical Records", Icons.description, () => const Scaffold(body: Center(child: Text("Medical Records Coming Soon"))), category: "Health"),
        MenuItem("Payment Methods", Icons.credit_card, () => PaymentMethodsScreen(userType: widget.userType), category: "Payment"),
        MenuItem("FAQs", Icons.info_outline, () => FAQScreen(userType: widget.userType), category: "Support"),
        MenuItem("Logout", Icons.logout, () => Container(), category: ""),
      ];
    }
  }

  // Group the menu items by category
  Map<String, List<MenuItem>> get _groupedMenuItems {
    final Map<String, List<MenuItem>> result = {};
    
    for (var item in menuItems) {
      if (item.category.isEmpty) continue; // Skip the logout item for grouping
      
      if (!result.containsKey(item.category)) {
        result[item.category] = [];
      }
      
      result[item.category]!.add(item);
    }
    
    return result;
  }

  // Navigate directly to a specific screen with web-friendly routing
  void _navigateToSpecificScreen(String screenType) {
    // Show loading dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 200,
                  child: LinearProgressIndicator(
                  color: AppTheme.primaryPink,
                    backgroundColor: AppTheme.primaryPink.withOpacity(0.2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading $screenType...',
                  style: GoogleFonts.poppins(
                    color: AppTheme.darkText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Use microtask to ensure UI updates before heavy computation
    Future.microtask(() async {
      try {
        // Ensure dialog is shown
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Create the appropriate screen based on type
        late Widget screen;
        
        switch (screenType) {
          case "Edit Profile":
            screen = const ProfileEditorScreen();
            break;
          case "Appointments History":
            screen = const AppointmentHistoryScreen();
            break;
          case "Payment Methods":
            screen = PaymentMethodsScreen(userType: widget.userType);
            break;
          case "FAQs":
            screen = FAQScreen(userType: widget.userType);
            break;
          case "Help Center":
            screen = Scaffold(
              appBar: AppBar(title: const Text("Help Center")),
              body: const Center(child: Text("Help Center Coming Soon")),
            );
            break;
          case "Medical Records":
            screen = Scaffold(
              appBar: AppBar(title: const Text("Medical Records")),
              body: const Center(child: Text("Medical Records Coming Soon")),
            );
            break;
          default:
            // Close loading dialog
            if (context.mounted) Navigator.of(context).pop();
            throw Exception("Unknown screen type: $screenType");
        }
        
        // Close loading dialog
        if (context.mounted) Navigator.of(context).pop();
        
        // Navigate using direct MaterialPageRoute
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => screen,
              settings: RouteSettings(name: '/${screenType.toLowerCase().replaceAll(' ', '_')}'),
            ),
          );
        }
      } catch (e) {
        // Close loading dialog if there's an error
        if (context.mounted) Navigator.of(context).pop();
        
        debugPrint('Error navigating to $screenType: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to navigate to $screenType: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  // Fallback method for direct navigation if named routes fail
  void _fallbackToDirectNavigation(String screenType) {
    try {
      debugPrint('Using fallback navigation for: $screenType');
      
      // Create the appropriate screen based on type
      late Widget screen;
      
      switch (screenType) {
        case "Edit Profile":
          screen = const ProfileEditorScreen();
          break;
        case "Appointments History":
          screen = const AppointmentHistoryScreen();
          break;
        case "Payment Methods":
          screen = PaymentMethodsScreen(userType: widget.userType);
          break;
        case "FAQs":
          screen = FAQScreen(userType: widget.userType);
          break;
        case "Help Center":
          screen = Scaffold(
            appBar: AppBar(title: const Text("Help Center")),
            body: const Center(child: Text("Help Center Coming Soon")),
          );
          break;
        case "Medical Records":
          screen = Scaffold(
            appBar: AppBar(title: const Text("Medical Records")),
            body: const Center(child: Text("Medical Records Coming Soon")),
          );
          break;
        default:
          throw Exception("Unknown screen type: $screenType");
      }
      
      // Navigate to the screen
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => screen,
            settings: RouteSettings(name: '/${screenType.toLowerCase().replaceAll(' ', '_')}'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in fallback navigation: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigation error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use UIHelper for consistent status bar styling
    UIHelper.applyPinkStatusBar();
    
    return UIHelper.ensureStatusBarStyle(
      style: UIHelper.pinkStatusBarStyle,
      child: WillPopScope(
        onWillPop: () async {
          // Navigate to the bottom navigation bar with home tab selected
          if (widget.userType == UserType.doctor) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BottomNavigationBarScreen(
                  profileStatus: "complete",
                  initialIndex: 0, // Home tab index
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BottomNavigationBarPatientScreen(
                  profileStatus: "complete",
                  initialIndex: 0, // Home tab index
                ),
              ),
            );
          }
          return false; // Prevent default back button behavior
        },
        child: Scaffold(
          // This "invisible" AppBar is wrapped in UIHelper now
          appBar: PreferredSize(
            preferredSize: Size.zero,
            child: AppBar(
              backgroundColor: AppTheme.primaryPink,
              elevation: 0,
            ),
          ),
          backgroundColor: Colors.grey.shade50,
          body: Stack(
            children: [
              SafeArea(
                child: _isLoading 
                  ? Center(
                      child: LinearProgressIndicator(
                        color: AppTheme.primaryPink,
                        backgroundColor: Colors.transparent,
                        minHeight: 4,
                      ),
                    )
                  : Column(
                      children: [
                        _buildProfileHeader(),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 25),
                                  ..._groupedMenuItems.entries.map((entry) => 
                                    _buildCategorySection(entry.key, entry.value)
                                  ).toList(),
                                  _buildLogoutButton(),
                                  const SizedBox(height: 25),
                                  Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          "Specialist Doctors App",
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryTeal,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Version 1.0.0",
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppTheme.mediumText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
              
              // Bottom refresh indicator
              if (_isRefreshing)
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
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.primaryPink,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, widget.userType == UserType.patient ? 20 : 35),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back arrow
              InkWell(
                onTap: () {
                  // Navigate to the bottom navigation bar with home tab selected
                  if (widget.userType == UserType.doctor) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BottomNavigationBarScreen(
                          profileStatus: "complete",
                          initialIndex: 0, // Home tab index
                        ),
                      ),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BottomNavigationBarPatientScreen(
                          profileStatus: "complete",
                          initialIndex: 0, // Home tab index
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              Text(
                "My Profile",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              // Empty SizedBox for layout balance
              const SizedBox(width: 38),
            ],
          ),
          const SizedBox(height: 20),
          
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
                  child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? CircleAvatar(
                        radius: widget.userType == UserType.patient ? 40 : 55,
                        backgroundImage: NetworkImage(_profileImageUrl!),
                      )
                    : CircleAvatar(
                    radius: widget.userType == UserType.patient ? 40 : 55,
                    backgroundColor: Colors.grey.shade200,
                    child: Icon(
                      Icons.person,
                      color: Colors.grey.shade400,
                      size: widget.userType == UserType.patient ? 30 : 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
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
                    Text(
                      _userRole,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Only show stats for doctors
          if (widget.userType == UserType.doctor) ...[
            const SizedBox(height: 20),
            // Stats cards
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard(
                    "Appointments", 
                    _appointmentsCount.toString(),
                    Icons.calendar_today,
                  ),
                  Container(
                    height: 50,
                    width: 1,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _buildStatCard(
                    "Earnings", 
                    "Rs ${_totalEarnings.toStringAsFixed(0)}",
                    Icons.account_balance_wallet,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              title, 
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySection(String category, List<MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12, top: 5),
          child: Text(
            category,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.mediumText,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final int index = entry.key;
              final MenuItem item = entry.value;
              final bool isLast = index == items.length - 1;
              
              return Column(
                children: [
                  _buildMenuItem(item),
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 65,
                      endIndent: 20,
                      color: Colors.grey.shade100,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _buildMenuItem(MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: Colors.grey.withOpacity(0.1),
        highlightColor: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          debugPrint('Menu item clicked: ${item.title}');
          
          // Capture the current context for navigation
          final BuildContext currentContext = context;
          
          if (item.title == "Logout") {
            _showLogoutDialog();
          } else if (item.title == "Edit Profile") {
            // Direct navigation for Edit Profile
            debugPrint('Direct navigation to Edit Profile');
            
            // Use async/await for better navigation flow
            Future.microtask(() async {
              try {
                // Show loading indicator using the captured context
                showDialog(
                  context: currentContext,
                  barrierDismissible: false,
                  builder: (dialogContext) => Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 4,
                            width: 200,
                            child: LinearProgressIndicator(
                            color: AppTheme.primaryPink,
                              backgroundColor: AppTheme.primaryPink.withOpacity(0.2),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Loading Profile Editor...',
                            style: GoogleFonts.poppins(
                              color: AppTheme.darkText,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                
                // Wait a bit for dialog to show
                await Future.delayed(const Duration(milliseconds: 100));
                
                // Close the dialog first if the context is still valid
                if (currentContext.mounted) {
                  Navigator.of(currentContext).pop();
                }
                
                // Navigate to the appropriate profile editor based on user type
                if (currentContext.mounted) {
                  if (widget.userType == UserType.doctor) {
                    Navigator.of(currentContext).push(
                      MaterialPageRoute(
                        builder: (context) => const DoctorProfilePage1Screen(isEditing: true),
                      ),
                    );
                  } else {
                    Navigator.of(currentContext).push(
                      MaterialPageRoute(
                        builder: (context) => const ProfileEditorScreen(),
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Navigation error: $e');
                // Try to show error if context is still valid
                if (currentContext.mounted) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'), 
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            });
          } else {
            // Use the web-friendly navigation for all other screens
            _navigateToSpecificScreen(item.title);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: AppTheme.veryLightTeal,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  color: AppTheme.primaryTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 15),
              Text(
                item.title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkText,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                color: AppTheme.lightText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.only(top: 5, bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFFE5E5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showLogoutDialog(),
          splashColor: Colors.red.withOpacity(0.1),
          highlightColor: Colors.red.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: Color(0xFFFF5252),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 15),
                Text(
                  "Logout",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFFF5252),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFFF9E9E),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout,
                    color: AppTheme.error,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Log Out",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Are you sure you want to log out of your account?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.mediumText,
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.darkText,
                          backgroundColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Close the dialog
                          Navigator.pop(context);
                          
                          try {
                            // Perform signout without showing any loading indicator
                            await _authService.signOut();
                          } catch (e) {
                            print('Error during signout: $e');
                            // Continue with navigation even if signout fails
                          } finally {
                            // Always navigate to onboarding screen, regardless of signout success/failure
                            if (context.mounted) {
                              // Use pushReplacement instead of pushAndRemoveUntil to avoid stack issues
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const Onboarding3()),
                                (route) => false,
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: Text(
                          "Log Out",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
      },
    );
  }
}

class MenuItem {
  final String title;
  final IconData icon;
  final Widget Function() screenBuilder;
  final String category;

  MenuItem(this.title, this.icon, this.screenBuilder, {this.category = ""});
}
