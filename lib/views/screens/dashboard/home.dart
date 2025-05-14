import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/utils/app_theme.dart';
import 'package:healthcare/utils/ui_helper.dart';
import 'package:healthcare/views/screens/appointment/all_appoinments.dart';
import 'package:healthcare/views/screens/appointment/appointment_detail.dart';
import 'package:healthcare/views/screens/complete_profile/profile1.dart';
import 'package:healthcare/views/screens/dashboard/analytics.dart';
import 'package:healthcare/views/screens/dashboard/finances.dart';
import 'package:healthcare/views/screens/dashboard/menu.dart';
import 'package:healthcare/views/screens/doctor/complete_profile/doctor_profile_page1.dart';
import 'package:healthcare/views/screens/doctor/availability/hospital_selection_screen.dart';
import 'package:healthcare/views/screens/doctor/availability/doctor_availability_screen.dart';
import 'package:healthcare/views/screens/menu/appointment_history.dart';
import 'package:healthcare/views/screens/menu/settings.dart';
import 'package:healthcare/views/screens/doctor/reviews/doctor_reviews_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:healthcare/utils/navigation_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthcare/services/auth_service.dart';
import 'package:healthcare/services/doctor_profile_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notifications/notification_screen.dart';
import 'package:healthcare/views/screens/menu/help_center.dart';
import 'package:healthcare/views/screens/common/chat/chat_list_screen.dart';
import 'package:healthcare/views/screens/onboarding/onboarding_3.dart';

class HomeScreen extends StatefulWidget {
  final String profileStatus;
  final String userType;
  const HomeScreen({
    super.key, 
    this.profileStatus = "incomplete", 
    this.userType = "Doctor"
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String profileStatus;
  late String userType;
  int _selectedIndex = 0;
  int _selectedAppointmentCategoryIndex = 0; // For appointment tabs
  
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final DoctorProfileService _doctorProfileService = DoctorProfileService();
  
  // User data
  String _userName = "Dr. Asmara";
  String _specialty = "";
  String? _profileImageUrl;
  bool _isLoading = true;
  bool _isRefreshing = false;
  
  // Financial data
  double _totalEarnings = 0.0;
  
  // Rating data
  double _overallRating = 0.0;
  int _reviewCount = 0;

  // Appointment data
  List<Map<String, dynamic>> _appointments = [];
  List<String> _appointmentCategories = ["Upcoming", "Completed"];
  bool _isLoadingAppointments = false;
  bool _isSyncingAppointments = false;
  DateTime? _lastAppointmentSync;

  // Cache keys
  static const String _doctorCacheKey = 'doctor_home_data';
  static const String _doctorAppointmentsCacheKey = 'doctor_appointments_cache';
  static const String _appointmentLastSyncKey = 'appointment_last_sync';

  @override
  void initState() {
    super.initState();
    profileStatus = widget.profileStatus;
    userType = widget.userType;
    
    // Use UIHelper instead of direct SystemChrome call
    UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
    
    _initializeData();
  }

  @override
  void dispose() {
    // Use UIHelper for consistent status bar management
    UIHelper.applyPinkStatusBar();
    super.dispose();
  }

  Future<void> _initializeData() async {
    print('***** HOME SCREEN INITIALIZED WITH USER TYPE: $userType *****');
    
    // Load data (first from cache, then from Firebase)
    await _loadData();
    
    // Add an additional post-frame callback to ensure the status bar is properly set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure status bar is pink after the screen is fully built
      UIHelper.applyPinkStatusBar();
      
      // Check profile completion status
      if (profileStatus != "complete") {
        print('***** PROFILE IS NOT COMPLETE. USER TYPE: $userType *****');
        if (userType == "Doctor" || userType == "doctor") {
          print('***** REDIRECTING DOCTOR TO PROFILE COMPLETION SCREEN *****');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const DoctorProfilePage1Screen(),
            ),
          );
        } else {
          print('***** REDIRECTING NON-DOCTOR TO PROFILE COMPLETION SCREEN *****');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const CompleteProfileScreen(),
            ),
          );
        }
      } else {
        print('***** PROFILE IS COMPLETE. STAYING ON HOME SCREEN *****');
      }
    });
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // First immediately load data from cache before anything else
      await _loadCachedData();
      await _loadAppointmentsFromCache();
      
      // Ensure status bar is maintained after loading cached data
      UIHelper.applyPinkStatusBar();
      
      // Now we can set isLoading to false since we have cache data
      setState(() {
        _isLoading = false;
      });
      
      // Then fetch fresh data from Firebase in background
      _loadUserData();
      _syncAppointmentsInBackground();
    } catch (e) {
      print('Error in _loadData: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString(_doctorCacheKey);
      
      if (cachedData != null) {
        final Map<String, dynamic> data = json.decode(cachedData);
        
        setState(() {
          _userName = data['userName'] ?? "Doctor";
          _specialty = data['specialty'] ?? "";
          _profileImageUrl = data['profileImageUrl'];
          _totalEarnings = (data['totalEarnings'] as num?)?.toDouble() ?? 0.0;
          _overallRating = (data['overallRating'] as num?)?.toDouble() ?? 0.0;
          _reviewCount = data['reviewCount'] as int? ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    
    // Ensure status bar is maintained before loading data
    UIHelper.applyPinkStatusBar();
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
          setState(() {
          _isRefreshing = false;
            _isLoading = false;
          });
        return;
      }
      
      if (userType == "Doctor") {
        await _loadDoctorProfileData();
      } else {
        await _loadProfileData();
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _isLoading = false;
        });
        
        // Ensure status bar is maintained after loading data
        UIHelper.applyPinkStatusBar();
      }
    }
  }
  
  Future<void> _loadDoctorProfileData() async {
    try {
      final doctorProfile = await _doctorProfileService.getDoctorProfile();
      final doctorStats = await _doctorProfileService.getDoctorStats();
      
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        final String doctorId = currentUser.uid;
        
        final QuerySnapshot reviewsSnapshot = await _firestore
            .collection('doctor_reviews')
            .where('doctorId', isEqualTo: doctorId)
            .get();
        
        double totalRating = 0;
        int reviewCount = reviewsSnapshot.docs.length;
        
        for (var doc in reviewsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('rating')) {
            totalRating += (data['rating'] as num).toDouble();
          }
        }
        
        double averageRating = reviewCount > 0 ? totalRating / reviewCount : 0.0;
      
        // Prepare data for caching
        final Map<String, dynamic> cacheData = {
          'userName': doctorProfile['fullName'] ?? "Doctor",
          'specialty': doctorProfile['specialty'] ?? "",
          'profileImageUrl': doctorProfile['profileImageUrl'],
          'totalEarnings': doctorStats['totalEarnings'] ?? 0.0,
          'overallRating': averageRating,
          'reviewCount': reviewCount,
          'lastUpdated': DateTime.now().toIso8601String(),
        };
        
        // Save to cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_doctorCacheKey, json.encode(cacheData));
        
      if (mounted) {
        setState(() {
            _userName = cacheData['userName'];
            _specialty = cacheData['specialty'];
            _profileImageUrl = cacheData['profileImageUrl'];
            _totalEarnings = cacheData['totalEarnings'];
            _overallRating = cacheData['overallRating'];
            _reviewCount = cacheData['reviewCount'];
        });
        }
      }
    } catch (e) {
      print('Error loading doctor profile data: $e');
      rethrow;
    }
  }
  
  Future<void> _loadProfileData() async {
    try {
      final userData = await _authService.getUserData();
      
      if (userData != null && mounted) {
        setState(() {
          _userName = userData['fullName'] ?? "User";
          _profileImageUrl = userData['profileImageUrl'];
        });
      }
    } catch (e) {
      print('Error loading profile data: $e');
      rethrow;
    }
  }

  Future<void> _loadAppointmentsData() async {
    if (!mounted) return;

    try {
      // First try to load from cache
      await _loadAppointmentsFromCache();
      
      // Then fetch fresh data from Firestore
      await _fetchAppointments();
    } catch (e) {
      print('Error loading appointments data: $e');
    }
  }

  Future<void> _loadAppointmentsFromCache() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get last sync time
      final String? lastSyncStr = prefs.getString(_appointmentLastSyncKey);
      if (lastSyncStr != null) {
        _lastAppointmentSync = DateTime.parse(lastSyncStr);
      }
      
      // Load appointments from cache
      final String? cachedData = prefs.getString(_doctorAppointmentsCacheKey);
      
      if (cachedData != null) {
        final List<dynamic> decodedData = json.decode(cachedData);
        final List<Map<String, dynamic>> appointments = 
            decodedData.map((item) => Map<String, dynamic>.from(item)).toList();
        
        if (mounted) {
          setState(() {
            _appointments = appointments;
            _isLoadingAppointments = false;
          });
          print('Loaded ${appointments.length} appointments from cache');
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingAppointments = false;
          });
        }
      }
    } catch (e) {
      print('Error loading cached appointments: $e');
      if (mounted) {
        setState(() {
          _isLoadingAppointments = false;
        });
      }
    }
  }

  void _syncAppointmentsInBackground() async {
    // Don't sync if already syncing
    if (_isSyncingAppointments) return;
    
    // Don't sync too frequently (at most once every 1 minute)
    if (_lastAppointmentSync != null) {
      final Duration sinceLastSync = DateTime.now().difference(_lastAppointmentSync!);
      if (sinceLastSync.inMinutes < 1) {
        print('Skipping appointment sync, last synced ${sinceLastSync.inSeconds} seconds ago');
        return;
      }
    }
    
    setState(() {
      _isSyncingAppointments = true;
    });
    
    try {
      await _fetchAppointments();
      
      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      final String now = DateTime.now().toIso8601String();
      await prefs.setString(_appointmentLastSyncKey, now);
      
      setState(() {
        _lastAppointmentSync = DateTime.now();
      });
    } catch (e) {
      print('Error syncing appointments in background: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingAppointments = false;
        });
      }
    }
  }

  Future<void> _fetchAppointments() async {
    if (!mounted) return;
    
    // Ensure status bar is maintained before fetching appointments
    UIHelper.applyPinkStatusBar();
    
    try {
      final String? doctorId = _auth.currentUser?.uid;
      if (doctorId == null) {
        return;
      }
      
      // Query appointments where this doctor is assigned
      final QuerySnapshot appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('date', descending: false)  // Sort by date (ascending)
          .limit(50)  // Limit to 50 appointments for performance
          .get();
      
      if (appointmentsSnapshot.docs.isEmpty) {
        print('No appointments found for doctor ID: $doctorId');
      } else {
        print('Found ${appointmentsSnapshot.docs.length} appointments for doctor ID: $doctorId');
      }
      
      final List<Map<String, dynamic>> appointments = [];
      
      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('Processing appointment: ${doc.id}');
        
        // Convert all Timestamp objects to ISO string format
        Map<String, dynamic> processedData = {};
        data.forEach((key, value) {
          if (value is Timestamp) {
            processedData[key] = value.toDate().toIso8601String();
          } else {
            processedData[key] = value;
          }
        });
        
        // Get patient details
        String patientName = "Patient";
        
        if (processedData['patientId'] != null) {
          try {
            final patientDoc = await _firestore
                .collection('users')
                .doc(processedData['patientId'])
                .get();
            
            if (patientDoc.exists) {
              final patientData = patientDoc.data();
              patientName = patientData?['fullName'] ?? "Patient";
            }
          } catch (e) {
            print('Error fetching patient data: $e');
          }
        }
        
        // Get hospital details - check multiple possible field names
        String hospitalName = "Not specified";
        
        // Try different field names for hospital
        if (processedData['hospital'] != null && processedData['hospital'].toString().isNotEmpty) {
          hospitalName = processedData['hospital'].toString();
        } else if (processedData['hospitalName'] != null && processedData['hospitalName'].toString().isNotEmpty) {
          hospitalName = processedData['hospitalName'].toString();
        } else if (processedData['hospitalId'] != null) {
          // If we have hospitalId but no name, try to fetch from hospitals collection
          try {
            final hospitalDoc = await _firestore
                .collection('hospitals')
                .doc(processedData['hospitalId'].toString())
                .get();
            
            if (hospitalDoc.exists) {
              final hospitalData = hospitalDoc.data();
              hospitalName = hospitalData?['name'] ?? hospitalData?['hospitalName'] ?? "Not specified";
              print('Retrieved hospital name from Firestore: $hospitalName');
            }
          } catch (e) {
            print('Error fetching hospital data: $e');
          }
        }

        // Parse appointment date and time
        DateTime? appointmentDateTime;
        try {
          String dateStr = processedData['date'] ?? "";
          String timeStr = processedData['time'] ?? "";
          
          if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
            // Convert AM/PM time to 24-hour format
            int hour = 0;
            int minute = 0;
            
            if (timeStr.contains("AM") || timeStr.contains("PM")) {
              // Parse 12-hour format time
              final isPM = timeStr.contains("PM");
              final timeParts = timeStr.replaceAll(RegExp(r'[APM]'), '').trim().split(':');
              hour = int.parse(timeParts[0]);
              minute = int.parse(timeParts[1]);
              
              // Convert to 24-hour format
              if (isPM && hour != 12) {
                hour += 12;
              } else if (!isPM && hour == 12) {
                hour = 0;
              }
            } else {
              // Parse 24-hour format time
              final timeParts = timeStr.split(':');
              hour = int.parse(timeParts[0]);
              minute = int.parse(timeParts[1]);
            }
            
            // Parse date
            final dateParts = dateStr.split('-');
            if (dateParts.length == 3) {
              final year = int.parse(dateParts[0]);
              final month = int.parse(dateParts[1]);
              final day = int.parse(dateParts[2]);
              
              appointmentDateTime = DateTime(year, month, day, hour, minute);
            }
          }
        } catch (e) {
          print('Error parsing appointment date/time: $e');
        }
        
        // Determine dynamic status based on original status or date/time
        String status = processedData['status'] ?? "Pending";
        DateTime now = DateTime.now();
        
        // Determine dynamic status based on date/time
        if (appointmentDateTime != null) {
          // If appointment is in the past, mark as completed
          if (appointmentDateTime.isBefore(now)) {
            status = "Completed";
          } else {
            // If appointment is in the future, mark as confirmed/upcoming
            if (status.toLowerCase() != "cancelled") {
              status = "Confirmed";
            }
          }
        }
        
        // Format appointment data
        appointments.add({
          'id': doc.id,
          'patientName': patientName,
          'patientImage': 'assets/images/User.png', // Use default image
          'date': processedData['date'] ?? "No date",
          'time': processedData['time'] ?? "No time",
          'type': processedData['type'] ?? "In-person",
          'status': status, // Use dynamically determined status
          'completed': processedData['completed'] == true, // Include completed flag from Firestore
          'reason': processedData['reason'] ?? "General checkup",
          'hospitalName': hospitalName,
          'fee': processedData['fee'] ?? "0",
          'syncedAt': DateTime.now().toIso8601String(),
          'appointmentDateTime': appointmentDateTime?.toIso8601String(),
        });
      }
      
      if (mounted) {
        setState(() {
          _appointments = appointments;
        });
        print('Updated appointments with ${appointments.length} records from server');
        
        // Cache the appointments data
        if (appointments.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_doctorAppointmentsCacheKey, json.encode(appointments));
        }
      }
    } catch (e) {
      print('Error fetching appointments: $e');
    } finally {
      // Ensure status bar is maintained after fetching appointments
      if (mounted) {
        UIHelper.applyPinkStatusBar();
      }
    }
  }

  Future<void> _refreshData() async {
    // Ensure status bar is maintained while refreshing
    UIHelper.applyPinkStatusBar();
    
    await _loadUserData();
    await _fetchAppointments();
  }

  void _onItemTapped(int index) {
    NavigationHelper.navigateToTab(context, index);
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    // Calculate responsive values
    final double headerHeight = screenHeight * 0.25; // Reduced from 0.28
    final double horizontalPadding = screenWidth * 0.06;
    final double verticalSpacing = screenHeight * 0.025;
    
    return WillPopScope(
      onWillPop: () async {
        // Ensure pink status bar is applied when returning to this screen
        UIHelper.applyPinkStatusBar();
        return true;
      },
      child: UIHelper.ensureStatusBarStyle(
        style: UIHelper.pinkStatusBarStyle,
        child: Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primaryPink,
            systemOverlayStyle: UIHelper.pinkStatusBarStyle,
        title: Text(
          "Specialist Doctors",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              LucideIcons.menu,
              color: Colors.white,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          // Add Chat icon
          IconButton(
            icon: Icon(Icons.chat_outlined, color: Colors.white),
            onPressed: () {
                  _navigateWithStatusBar(
                context,
                    ChatListScreen(isDoctor: true),
              );
            },
            tooltip: 'Chat with patients',
          ),
          // Notification icon
          IconButton(
            icon: Icon(
              LucideIcons.bell,
              color: Colors.white,
            ),
            onPressed: () {
                  _navigateWithStatusBar(
                context,
                    const NotificationScreen(),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, screenWidth),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: LinearProgressIndicator(
                  color: AppTheme.primaryPink,
                  backgroundColor: Colors.transparent,
                  minHeight: 4,
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                return Stack(
                  children: [
                      // Main scrollable content
                    SingleChildScrollView(
                        physics: BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with background
                            Container(
                              height: headerHeight,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPink,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(30),
                                  bottomRight: Radius.circular(30),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryPink.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                                vertical: verticalSpacing * 0.6,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Top row with user info
                                  Row(
                                    children: [
                                      // Profile image
                                      GestureDetector(
                                        onTap: () {
                                          NavigationHelper.navigateToTab(context, 3); // Navigate to Menu tab
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 8,
                                                offset: Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Hero(
                                            tag: 'profileImage',
                                            child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                                ? CircleAvatar(
                                                    radius: screenWidth * 0.065,
                                                    backgroundImage: NetworkImage(
                                                      _profileImageUrl!,
                                                      // Add caching headers
                                                      headers: const {
                                                        'Cache-Control': 'max-age=3600',
                                                      },
                                                    ),
                                                    onBackgroundImageError: (exception, stackTrace) {
                                                      print('Error loading profile image: $exception');
                                                      // Use default image on error
                                                      setState(() {
                                                        _profileImageUrl = null;
                                                      });
                                                    },
                                                    child: _isRefreshing
                                                        ? Container(
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: Colors.black26,
                                                            ),
                                                            child: Center(
                                                              child: SizedBox(
                                                                width: screenWidth * 0.03,
                                                                height: screenWidth * 0.03,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth: 2,
                                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                                ),
                                                              ),
                                                            ),
                                                          )
                                                        : null,
                                                  )
                                                : CircleAvatar(
                                                    radius: screenWidth * 0.065,
                                                    backgroundColor: Colors.grey[200],
                                                    backgroundImage: const AssetImage("assets/images/User.png"),
                                                  ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: horizontalPadding * 0.8),
                                      // User name and specialty with flexible width
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Welcome",
                                              style: GoogleFonts.poppins(
                                                fontSize: screenWidth * 0.04,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white.withOpacity(0.9),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              _userName,
                                              style: GoogleFonts.poppins(
                                                fontSize: screenWidth * 0.055,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (_specialty.isNotEmpty)
                                              Text(
                                                _specialty,
                                                style: GoogleFonts.poppins(
                                                  fontSize: screenWidth * 0.035,
                                                  color: Colors.white.withOpacity(0.9),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Earnings info in header
                                  Container(
                                    margin: EdgeInsets.only(top: verticalSpacing * 0.8),
                                    padding: EdgeInsets.all(screenWidth * 0.035),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Icon and labels
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(screenWidth * 0.02),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  Icons.paid_outlined,
                                                  color: AppTheme.primaryTeal,
                                                  size: screenWidth * 0.055,
                                                ),
                                              ),
                                              SizedBox(width: screenWidth * 0.03),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      "Total Earning",
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontSize: screenWidth * 0.032,
                                                      ),
                                                    ),
                                                    Text(
                                                      "Rs ${_totalEarnings.toStringAsFixed(2)}",
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontSize: screenWidth * 0.045,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Arrow button
                                        Container(
                                          width: screenWidth * 0.08,
                                          height: screenWidth * 0.08,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            onPressed: () {
                                              NavigationHelper.navigateToTab(context, 2); // Navigate to Finances tab
                                            },
                                            icon: Icon(
                                              LucideIcons.arrowRight,
                                              color: Colors.white,
                                              size: screenWidth * 0.04,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: verticalSpacing),
                                  
                                  // Redesigned ratings Card with modern design
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(screenWidth * 0.05),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryTeal,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryTeal.withOpacity(0.3),
                                          blurRadius: 15,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Title section
                                            Row(
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.all(screenWidth * 0.02),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Icon(
                                                    LucideIcons.star,
                                                    color: Colors.white,
                                                    size: screenWidth * 0.05,
                                                  ),
                                                ),
                                                SizedBox(width: screenWidth * 0.03),
                                                Text(
                                                  "Doctor Rating",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: screenWidth * 0.04,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // Review count pill
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: screenWidth * 0.03,
                                                vertical: screenWidth * 0.015,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(screenWidth * 0.05),
                                              ),
                                              child: Text(
                                                "$_reviewCount ${_reviewCount == 1 ? 'Review' : 'Reviews'}",
                                                style: GoogleFonts.poppins(
                                                  fontSize: screenWidth * 0.03,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: verticalSpacing * 0.7),
                                        // Rating display
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            // Rating number
                                            Text(
                                              _overallRating.toStringAsFixed(1),
                                              style: GoogleFonts.poppins(
                                                fontSize: screenWidth * 0.09,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(width: screenWidth * 0.03),
                                            // Rating stars
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      for (int i = 1; i <= 5; i++)
                                                        Icon(
                                                          i <= _overallRating
                                                              ? Icons.star
                                                              : i <= _overallRating + 0.5
                                                                  ? Icons.star_half
                                                                  : Icons.star_border,
                                                          color: Colors.amber,
                                                          size: screenWidth * 0.05,
                                                        ),
                                                    ],
                                                  ),
                                                  SizedBox(height: screenWidth * 0.02),
                                                  // Progress indicator
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: LinearProgressIndicator(
                                                      value: _overallRating / 5,
                                                      backgroundColor: Colors.white.withOpacity(0.2),
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: verticalSpacing * 0.7),
                                        // View all reviews button
                                        Center(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => DoctorReviewsScreen(
                                                    doctorId: _auth.currentUser?.uid,
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: AppTheme.primaryTeal,
                                              elevation: 0,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: screenWidth * 0.05,
                                                vertical: screenWidth * 0.025,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(screenWidth * 0.04),
                                              ),
                                            ),
                                            icon: Icon(
                                              LucideIcons.clipboardList,
                                              size: screenWidth * 0.04,
                                            ),
                                            label: Text(
                                              "View All Reviews",
                                              style: GoogleFonts.poppins(
                                                fontSize: screenWidth * 0.035,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  SizedBox(height: verticalSpacing),
                                  
                                  // My Appointments Section
                                  _buildAppointmentsSection(screenWidth, screenHeight, horizontalPadding, verticalSpacing),

                                  // Add extra space at the bottom
                                  SizedBox(height: verticalSpacing),
                                ],
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
                );
              }
                ),
          ),
            ),
      ),
    );
  }
  
  Widget _buildEnhancedActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required double width,
    required double height,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: Offset(0, 6),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Gradient background with accent color in corner
              Positioned(
                right: -width * 0.2,
                bottom: -width * 0.2,
                child: Container(
                  width: width * 0.7,
                  height: width * 0.7,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        color.withOpacity(0.18),
                        color.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.9],
                    ),
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: EdgeInsets.all(width * 0.08),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon container with creative design
                    Container(
                      padding: EdgeInsets.all(width * 0.06),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.1),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: width * 0.13,
                      ),
                    ),
                    Spacer(),
                    // Label with thicker weight for emphasis
                    Text(
                      label.split('\n')[0],
                      style: GoogleFonts.poppins(
                        fontSize: width * 0.12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        height: 0.9,
                      ),
                    ),
                    if (label.contains('\n'))
                      Text(
                        label.split('\n')[1],
                        style: GoogleFonts.poppins(
                          fontSize: width * 0.12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          height: 0.9,
                        ),
                      ),
                    SizedBox(height: width * 0.05),
                    // View button with animation hint
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mini pill-shaped button
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: width * 0.08,
                            vertical: width * 0.04,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(width * 0.1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View',
                                style: GoogleFonts.poppins(
                                  fontSize: width * 0.08,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                              SizedBox(width: width * 0.02),
                              Icon(
                                LucideIcons.arrowRight,
                                color: color,
                                size: width * 0.08,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build the appointments section widget
  Widget _buildAppointmentsSection(
    double screenWidth, 
    double screenHeight, 
    double horizontalPadding, 
    double verticalSpacing
  ) {
    // Filter appointments based on the selected category and current date/time
    List<Map<String, dynamic>> filteredAppointments = [];
    
    if (_appointments.isNotEmpty) {
      // Get current date/time for comparison
      final now = DateTime.now();
      
      if (_selectedAppointmentCategoryIndex == 0) {
        // Upcoming appointments - filter by completed status
        filteredAppointments = _appointments.where((appointment) {
          // First check if appointment has been explicitly marked as completed
          if (appointment['completed'] == true) {
            return false;
          }
          
          // Then check if it's cancelled
          if (appointment['status']?.toString().toLowerCase() == 'cancelled') {
            return false;
          }
          
          return true;
        }).toList();
      } else if (_selectedAppointmentCategoryIndex == 1) {
        // Completed appointments - filter by completed status
        filteredAppointments = _appointments.where((appointment) {
          // Only show appointments explicitly marked as completed
          return appointment['completed'] == true;
        }).toList();
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "My Appointments",
              style: GoogleFonts.poppins(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Row(
              children: [
                if (_isSyncingAppointments)
                  Container(
                    width: screenWidth * 0.04,
                    height: screenWidth * 0.04,
                    margin: EdgeInsets.only(right: screenWidth * 0.02),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryTeal.withOpacity(0.7),
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () {
                    // Navigate to AppointmentHistoryScreen instead of AppointmentsScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AppointmentHistoryScreen()),
                    ).then((_) {
                      // Refresh appointments when returning from the history screen
                      _syncAppointmentsInBackground();
                    });
                  },
                  child: Text(
                    "See all",
                    style: GoogleFonts.poppins(
                      fontSize: screenWidth * 0.035,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_lastAppointmentSync != null)
          Padding(
            padding: EdgeInsets.only(top: verticalSpacing * 0.2),
            child: Text(
              "Last updated: ${_formatLastUpdateTime(_lastAppointmentSync!)}",
              style: GoogleFonts.poppins(
                fontSize: screenWidth * 0.025,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        SizedBox(height: verticalSpacing * 0.5),
        
        // Category tabs
        SizedBox(
          height: screenHeight * 0.05,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _appointmentCategories.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAppointmentCategoryIndex = index;
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(right: horizontalPadding * 0.5),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.7),
                  decoration: BoxDecoration(
                    color: _selectedAppointmentCategoryIndex == index
                        ? AppTheme.primaryPink
                        : AppTheme.lightTeal,
                    borderRadius: BorderRadius.circular(screenWidth * 0.05),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _appointmentCategories[index],
                    style: GoogleFonts.poppins(
                      fontSize: screenWidth * 0.035,
                      fontWeight: FontWeight.w500,
                      color: _selectedAppointmentCategoryIndex == index
                          ? Colors.white
                          : AppTheme.darkTeal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: verticalSpacing),
        
        // Appointments list - only show loading if no cache data and this is first load
        filteredAppointments.isEmpty && _isLoadingAppointments
        ? Center(
            child: SizedBox(
              height: screenHeight * 0.15,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: screenWidth * 0.06,
                    height: screenWidth * 0.06,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryTeal,
                      ),
                    ),
                  ),
                  SizedBox(height: verticalSpacing * 0.5),
                  Text(
                    "Loading appointments...",
                    style: GoogleFonts.poppins(
                      fontSize: screenWidth * 0.035,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
        : filteredAppointments.isEmpty
          ? Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.03,
              horizontal: screenWidth * 0.05
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(screenWidth * 0.04),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  LucideIcons.calendar,
                  size: screenWidth * 0.15,
                  color: Colors.grey.shade300,
                ),
                SizedBox(height: verticalSpacing * 0.5),
                Text(
                  "No ${_appointmentCategories[_selectedAppointmentCategoryIndex].toLowerCase()} appointments",
                  style: GoogleFonts.poppins(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
          : LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: filteredAppointments.take(3).map((appointment) => 
                  _buildAppointmentCard(
                    appointment, 
                    screenWidth, 
                    screenHeight, 
                    horizontalPadding, 
                    verticalSpacing,
                    constraints.maxWidth
                  )
                ).toList(),
              );
            },
          ),
          
        // Only show refresh button if we have appointments to show
        if (filteredAppointments.isNotEmpty) 
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: verticalSpacing),
              child: InkWell(
                onTap: _syncAppointmentsInBackground,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: screenHeight * 0.01, 
                    horizontal: screenWidth * 0.04
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.refreshCw,
                        size: screenWidth * 0.04,
                        color: AppTheme.primaryTeal,
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Text(
                        "Refresh",
                        style: GoogleFonts.poppins(
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Helper function to format the last update time
  String _formatLastUpdateTime(DateTime time) {
    final Duration difference = DateTime.now().difference(time);
    
    if (difference.inMinutes < 1) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago";
    } else {
      return DateFormat('MMM d, h:mm a').format(time);
    }
  }

  // Build a single appointment card
  Widget _buildAppointmentCard(
    Map<String, dynamic> appointment, 
    double screenWidth, 
    double screenHeight, 
    double horizontalPadding, 
    double verticalSpacing,
    [double cardWidth = 0]
  ) {
    // Determine status color and display text based on completed field
    Color statusColor;
    String displayStatus;
    
    // Check completed field first
    if (appointment['completed'] == true) {
      displayStatus = 'Completed';
      statusColor = Colors.green;
    } else if (appointment['status']?.toString().toLowerCase() == 'cancelled') {
      displayStatus = 'Cancelled';
      statusColor = Colors.grey;
    } else {
      // Default to Upcoming/Confirmed for non-completed, non-cancelled appointments
      displayStatus = 'Upcoming';
      statusColor = AppTheme.primaryPink;
    }
    
    // Calculate responsive values based on container width
    final double imageSizeMultiplier = 0.06;
    final double textSizeMultiplier = 0.035;
    final double detailIconSize = screenWidth * 0.04;
    final double detailSpacing = screenWidth * 0.02;
    final bool isSmallScreen = screenWidth < 360;
    
    return GestureDetector(
      onTap: () {
        // Navigate to appointment details using the helper method for status bar preservation
        _navigateWithStatusBar(
          context,
          AppointmentDetailsScreen(
            appointmentId: appointment['id'],
          ),
        );
      },
      child: Container(
        width: cardWidth > 0 ? cardWidth : double.infinity,
        margin: EdgeInsets.only(bottom: verticalSpacing),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPink.withOpacity(0.08),
              blurRadius: 10,
              offset: Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.09),
              blurRadius: 20,
              offset: Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade100,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(horizontalPadding * 0.6),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(screenWidth * 0.04),
                  topRight: Radius.circular(screenWidth * 0.04),
                ),
              ),
              child: Row(
                children: [
                  // Patient image
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: screenWidth * imageSizeMultiplier,
                      backgroundImage: appointment['patientImage'].startsWith('assets/')
                          ? AssetImage(appointment['patientImage'])
                          : NetworkImage(appointment['patientImage']) as ImageProvider,
                    ),
                  ),
                  SizedBox(width: horizontalPadding * 0.6),
                  // Patient name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment['patientName'],
                          style: GoogleFonts.poppins(
                            fontSize: screenWidth * textSizeMultiplier,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: verticalSpacing * 0.1),
                        Text(
                          appointment['reason'],
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen 
                                ? screenWidth * (textSizeMultiplier - 0.01)
                                : screenWidth * (textSizeMultiplier - 0.005),
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding * 0.5,
                      vertical: verticalSpacing * 0.3
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(screenWidth * 0.05),
                      border: Border.all(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      displayStatus,
                      style: GoogleFonts.poppins(
                        fontSize: isSmallScreen 
                            ? screenWidth * 0.025
                            : screenWidth * 0.03,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Appointment details
            Padding(
              padding: EdgeInsets.all(horizontalPadding * 0.6),
              child: Column(
                children: [
                  // Use Wrap instead of Row for better responsiveness on smaller screens
                  Wrap(
                    spacing: horizontalPadding * 0.6,
                    runSpacing: verticalSpacing * 0.6,
                    children: [
                      _buildAppointmentDetail(
                        LucideIcons.calendar,
                        "Date",
                        appointment['date'],
                        screenWidth,
                        detailIconSize,
                        detailSpacing,
                        isSmallScreen
                      ),
                      _buildAppointmentDetail(
                        LucideIcons.clock,
                        "Time",
                        appointment['time'],
                        screenWidth,
                        detailIconSize,
                        detailSpacing,
                        isSmallScreen
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing * 0.6),
                  Wrap(
                    spacing: horizontalPadding * 0.6,
                    runSpacing: verticalSpacing * 0.6,
                    children: [
                      _buildAppointmentDetail(
                        LucideIcons.building2,
                        "Hospital",
                        appointment['hospitalName'],
                        screenWidth,
                        detailIconSize,
                        detailSpacing,
                        isSmallScreen
                      ),
                      _buildAppointmentDetail(
                        LucideIcons.tag,
                        "Type",
                        appointment['type'],
                        screenWidth,
                        detailIconSize,
                        detailSpacing,
                        isSmallScreen
                      ),
                    ],
                  ),
                  SizedBox(height: verticalSpacing * 0.9),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to appointment details using the helper method for status bar preservation
                            _navigateWithStatusBar(
                              context,
                              AppointmentDetailsScreen(
                                appointmentId: appointment['id'],
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: verticalSpacing * 0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(screenWidth * 0.03),
                            ),
                            elevation: 2,
                            shadowColor: AppTheme.primaryTeal.withOpacity(0.3),
                          ),
                          icon: Icon(LucideIcons.fileText, size: screenWidth * 0.045),
                          label: Text(
                            "View Details",
                            style: GoogleFonts.poppins(
                              fontSize: screenWidth * 0.035,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build appointment detail items
  Widget _buildAppointmentDetail(
    IconData icon, 
    String label, 
    String value, 
    double screenWidth,
    double iconSize,
    double spacing,
    bool isSmallScreen
  ) {
    return Container(
      width: isSmallScreen ? double.infinity : screenWidth * 0.38,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.02),
            decoration: BoxDecoration(
              color: AppTheme.lightTeal,
              borderRadius: BorderRadius.circular(screenWidth * 0.02),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: AppTheme.primaryTeal,
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? screenWidth * 0.025 : screenWidth * 0.03,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? screenWidth * 0.03 : screenWidth * 0.035,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build drawer for sidebar navigation - provides quick access to key features
  // This drawer complements the bottom navigation tabs with direct shortcuts
  Widget _buildDrawer(BuildContext context, double screenWidth) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Drawer(
        backgroundColor: Colors.white,
        elevation: 30,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        child: SafeArea(
              child: Column(
                children: [
              // User Profile Card
                      Container(
                        decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryTeal,
                      AppTheme.primaryTeal.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                          boxShadow: [
                            BoxShadow(
                      color: AppTheme.primaryTeal.withOpacity(0.3),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                            ),
                          ],
                        ),
                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 33,
                          backgroundColor: Colors.white,
                          backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                              ? NetworkImage(_profileImageUrl!)
                              : AssetImage("assets/images/User.png") as ImageProvider,
                        ),
                      ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_specialty.isNotEmpty)
                              Text(
                                _specialty,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            SizedBox(height: 5),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "Doctor",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                  ),
                  SizedBox(height: 15),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.wallet,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Rs ${_totalEarnings.toStringAsFixed(0)}",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
            
              // Menu Items
            Expanded(
              child: ListView(
                  padding: EdgeInsets.only(top: 10),
                children: [
                    _buildMenuSection("Main Menu"),
                    _buildMenuItem(
                    icon: Icons.home,
                    title: "Home",
                      isActive: true,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                    _buildMenuItem(
                    icon: LucideIcons.stethoscope,
                    title: "My Appointments",
                    onTap: () {
                      Navigator.pop(context);
                        _navigateWithStatusBar(context, AppointmentHistoryScreen());
                    },
                  ),
                    _buildMenuItem(
                    icon: LucideIcons.calendarClock,
                    title: "Set Availability",
                    onTap: () {
                      Navigator.pop(context);
                        _navigateWithStatusBar(context, DoctorAvailabilityScreen());
                    },
                  ),
                    _buildMenuItem(
                    icon: LucideIcons.building2,
                    title: "Add Hospital",
                    onTap: () {
                      Navigator.pop(context);
                        _navigateWithStatusBar(
                        context,
                          HospitalSelectionScreen(selectedHospitals: []),
                      );
                    },
                  ),
                    _buildMenuItem(
                    icon: Icons.bar_chart,
                    title: "Analytics",
                    onTap: () {
                      Navigator.pop(context);
                      NavigationHelper.navigateToTab(context, 1);
                    },
                  ),
                    _buildMenuItem(
                    icon: LucideIcons.wallet,
                    title: "Finances",
                    onTap: () {
                      Navigator.pop(context);
                      NavigationHelper.navigateToTab(context, 2);
                    },
                  ),
                    
                    _buildMenuSection("Settings & Support"),
                    _buildMenuItem(
                    icon: Icons.help_outline,
                    title: "Help Center",
                    onTap: () {
                      Navigator.pop(context);
                        _navigateWithStatusBar(context, const HelpCenterScreen());
                    },
                  ),
                    
                    SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFEBEE),
                              Color(0xFFFFCDD2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                    onTap: () async {
                            Navigator.pop(context);
                      final shouldLogout = await _showLogoutConfirmationDialog(context);
                      if (shouldLogout) {
                        await _authService.signOut();
                              // Navigate to onboarding_3 screen after logout
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => Onboarding3()),
                          (Route<dynamic> route) => false,
                        );
                      }
                    },
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.logout_rounded,
                                  color: Color(0xFFE53935),
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                'Logout',
                                style: GoogleFonts.poppins(
                                  color: Color(0xFFE53935),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ),
                ],
              ),
            ),
            
              // App Version
            Padding(
                padding: EdgeInsets.all(16),
              child: Text(
                  'Specialist Doctors • Version 1.0.0',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                    fontSize: 12,
                ),
                  textAlign: TextAlign.center,
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  // Helper method to build menu section headers
  Widget _buildMenuSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 20, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
  
  // Build drawer item
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Color iconColor = const Color(0xFF555555),
    Color textColor = const Color(0xFF333333),
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        onTap: () {
          // Ensure pink status bar is maintained for drawer navigation
          UIHelper.applyPinkStatusBar();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryTeal.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                icon,
                  color: isActive ? AppTheme.primaryTeal : iconColor,
                size: 20,
              ),
              ),
              SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? AppTheme.primaryTeal : textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Logout confirmation dialog
  Future<bool> _showLogoutConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Logout",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          content: Text(
            "Are you sure you want to logout?",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.mediumText,
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(
                  color: AppTheme.mediumText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              ),
              child: Text(
                "Logout",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Add this helper method for navigation with status bar handling
  void _navigateWithStatusBar(BuildContext context, Widget screen) {
    // Apply status bar style before navigation
    UIHelper.applyPinkStatusBar();
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) {
      // Restore pink status bar when returning to this screen
      UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
    });
  }
}

Future<bool> showExitDialog(BuildContext context) async {
  final Size screenSize = MediaQuery.of(context).size;
  final double screenWidth = screenSize.width;
  
  return await showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEB),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.exit_to_app,
                  color: Color(0xFFFF5252),
                  size: screenWidth * 0.075,
                ),
              ),
              SizedBox(height: screenWidth * 0.05),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                "Exit App",
                style: GoogleFonts.poppins(
                    fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: screenWidth * 0.025),
              Text(
                "Are you sure you want to exit the app?",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: screenWidth * 0.06),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade800,
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.poppins(
                            fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                        SystemNavigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5252),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                        elevation: 0,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                      child: Text(
                        "Exit",
                        style: GoogleFonts.poppins(
                            fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.w600,
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
    },
  ) ?? false;
}
