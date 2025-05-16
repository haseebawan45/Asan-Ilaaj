import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/views/screens/patient/dashboard/patient_profile_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:healthcare/models/appointment_model.dart';
import 'package:healthcare/services/appointment_service.dart';
import 'package:healthcare/utils/app_theme.dart';
import 'package:healthcare/views/screens/appointment/appointment_detail.dart';
import 'package:healthcare/utils/ui_helper.dart';

class AppointmentHistoryScreen extends StatefulWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  State<AppointmentHistoryScreen> createState() => _AppointmentHistoryScreenState();
}

class _AppointmentHistoryScreenState extends State<AppointmentHistoryScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';
  
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppointmentService _appointmentService = AppointmentService();
  
  // Cache key for appointments
  static const String _appointmentsCacheKey = 'appointments_history_cache';
  static const Duration _cacheValidDuration = Duration(hours: 24);
  
  // Appointment data structure 
  List<AppointmentModel> _appointments = [];

  // Search query
  String _searchQuery = '';
  String _selectedFilter = 'All';

  // Pagination variables
  bool _isLoadingMore = false;
  bool _hasMoreAppointments = true;
  int _appointmentsLimit = 10;
  DocumentSnapshot? _lastDocument;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _loadAppointmentsWithCache();
    
    // Apply pink status bar consistently
    UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure pink status bar is maintained when returning to this screen
    UIHelper.applyPinkStatusBar();
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    
    super.dispose();
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when we're at 80% of the list
      if (!_isLoadingMore && !_isRefreshing && _hasMoreAppointments) {
        _loadMoreAppointments();
      }
    }
  }
  
  // Load appointments with caching strategy
  Future<void> _loadAppointmentsWithCache() async {
    if (mounted) {
    setState(() {
      _isLoading = true;
        _lastDocument = null;
        _appointments = [];
        _hasMoreAppointments = true;
      });
    }

    // First try to load from cache
    await _loadFromCache();

    // Then start background refresh
    _refreshDataInBackground();
  }
  
  // Load more appointments when scrolling
  Future<void> _loadMoreAppointments() async {
    if (!_hasMoreAppointments || _isLoadingMore || _lastDocument == null) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      print("Loading more appointments after document: ${_lastDocument?.id}");
      
      // Query more appointments
      QuerySnapshot appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_appointmentsLimit)
          .get();
      
      if (appointmentsSnapshot.docs.isEmpty) {
        setState(() {
          _hasMoreAppointments = false;
          _isLoadingMore = false;
        });
        return;
      }
      
      print("Loaded ${appointmentsSnapshot.docs.length} more appointments");
      
      List<AppointmentModel> moreAppointments = [];
      
      // Process each appointment document
      for (var doc in appointmentsSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          
          // Get patient details
          String patientName = "Unknown Patient";
          String? patientImageUrl;
          
          if (data['patientId'] != null) {
            // First try the patients collection for profile image
            final patientDoc = await _firestore
                .collection('patients')
                .doc(data['patientId'] as String)
                .get();
            
            if (patientDoc.exists) {
              final patientData = patientDoc.data() ?? {};
              patientName = patientData['fullName'] ?? patientData['name'] ?? 'Unknown Patient';
              
              // Try to get and validate patient profile image
              if (patientData.containsKey('profileImageUrl') && 
                  patientData['profileImageUrl'] != null &&
                  patientData['profileImageUrl'].toString().isNotEmpty) {
                patientImageUrl = _validateAndFixImageUrl(patientData['profileImageUrl'].toString());
              }
            }
            
            // If patient wasn't found in patients collection, try users collection as fallback
            if (patientName == "Unknown Patient" || patientImageUrl == null) {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(data['patientId'] as String)
                  .get();
              
              if (userDoc.exists) {
                final userData = userDoc.data() ?? {};
                if (patientName == "Unknown Patient") {
                  patientName = userData['fullName'] ?? userData['name'] ?? 'Unknown Patient';
                }
                
                // Try to get profile image
                if (userData.containsKey('profileImageUrl') && 
                    userData['profileImageUrl'] != null) {
                  patientImageUrl = _validateAndFixImageUrl(userData['profileImageUrl'].toString());
                }
              }
            }
          }
          
          // Parse date and time (reusing existing functionality)
          DateTime appointmentDate;
          if (data['date'] is Timestamp) {
            appointmentDate = (data['date'] as Timestamp).toDate();
          } else if (data['date'] is String) {
            try {
              appointmentDate = DateTime.parse(data['date'] as String);
            } catch (e) {
              print("Error parsing date: $e");
              appointmentDate = DateTime.now();
            }
          } else {
            appointmentDate = DateTime.now();
          }
          
          // Try to add time if available
          if (data['time'] is String && (data['time'] as String).isNotEmpty) {
            try {
              final timeStr = (data['time'] as String).trim();
              final isPM = timeStr.toLowerCase().contains('pm');
              final timeParts = timeStr
                  .toLowerCase()
                  .replaceAll('am', '')
                  .replaceAll('pm', '')
                  .trim()
                  .split(':');
              
              if (timeParts.length >= 2) {
                int hour = int.parse(timeParts[0]);
                int minute = int.parse(timeParts[1]);
                
                if (isPM && hour < 12) hour += 12;
                if (!isPM && hour == 12) hour = 0;
                
                appointmentDate = DateTime(
                  appointmentDate.year,
                  appointmentDate.month,
                  appointmentDate.day,
                  hour,
                  minute,
                );
              }
            } catch (e) {
              print("Error parsing time: $e");
            }
          }
          
          // Handle fee
          double? fee;
          if (data['fee'] != null) {
            if (data['fee'] is num) {
              fee = (data['fee'] as num).toDouble();
            } else if (data['fee'] is String) {
              try {
                fee = double.parse(data['fee'] as String);
              } catch (e) {
                print("Error parsing fee: $e");
              }
            }
          }
          
          // Create appointment model with patientImageUrl
          final appointment = AppointmentModel(
            id: doc.id,
            doctorName: patientName, // This is the patient name for doctor's view
            specialty: data['type'] ?? data['specialty'] ?? 'Consultation',
            hospital: data['hospitalName'] ?? data['hospital'] ?? data['location'] ?? 'Not specified',
            date: appointmentDate,
            status: data['status'] ?? 'pending',
            diagnosis: data['diagnosis'] as String?,
            prescription: data['prescription'] as String?,
            notes: data['notes'] as String?,
            fee: fee,
            patientImageUrl: patientImageUrl, // Add the patient image URL
          );
          
          moreAppointments.add(appointment);
        } catch (e) {
          print("Error processing additional appointment: $e");
        }
      }
      
      // Update the last document for next pagination query
      _lastDocument = appointmentsSnapshot.docs.last;
      
      // Add new appointments to the list
      if (mounted) {
        setState(() {
          _appointments.addAll(moreAppointments);
          _isLoadingMore = false;
        });
      }
      
    } catch (e) {
      print("Error loading more appointments: $e");
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }
  
  // Load data from cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString(_appointmentsCacheKey);
      
      if (cachedData != null) {
        final Map<String, dynamic> cached = json.decode(cachedData);
        final DateTime lastUpdated = DateTime.parse(cached['lastUpdated']);
        
        // Check if cache is still valid (less than 24 hours old)
        if (DateTime.now().difference(lastUpdated) < _cacheValidDuration) {
          final List<dynamic> appointmentsData = cached['appointments'];
          final List<AppointmentModel> appointments = appointmentsData
              .map((data) => AppointmentModel.fromJson(data))
              .toList();
            
        if (mounted) {
      setState(() {
              _appointments = appointments;
            _isLoading = false;
              // Assume we might have more appointments beyond the cache
              _hasMoreAppointments = appointments.length >= _appointmentsLimit;
          });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading from cache: $e');
    } finally {
      if (mounted && _isLoading) {
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
      _lastDocument = null;
      _hasMoreAppointments = true;
    });

    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get fresh data from Firebase - first batch only
      List<AppointmentModel> freshAppointments = [];
      
      try {
        // Load doctor appointments directly from Firestore to ensure we get data
        print("Fetching appointments for doctor ID: $userId");
        
        final QuerySnapshot appointmentsSnapshot = await _firestore
            .collection('appointments')
            .where('doctorId', isEqualTo: userId)
            .orderBy('date', descending: true)
            .limit(_appointmentsLimit)
            .get();
        
        print("Found ${appointmentsSnapshot.docs.length} appointments");
        
        // Save the last document for pagination
        if (appointmentsSnapshot.docs.isNotEmpty) {
          _lastDocument = appointmentsSnapshot.docs.last;
          // We likely have more if we hit our limit
          _hasMoreAppointments = appointmentsSnapshot.docs.length >= _appointmentsLimit;
        } else {
          _lastDocument = null;
          _hasMoreAppointments = false;
        }
        
        // Process each appointment document
        for (var doc in appointmentsSnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            
            // Get patient details
            String patientName = "Unknown Patient";
            String patientSpecialty = "General";
            String? patientImageUrl;
            
            if (data['patientId'] != null) {
              // First try the patients collection for the most reliable data
              final patientDoc = await _firestore
                  .collection('patients')
                  .doc(data['patientId'] as String)
                  .get();
              
              if (patientDoc.exists) {
                final patientData = patientDoc.data() ?? {};
                patientName = patientData['fullName'] ?? patientData['name'] ?? 'Unknown Patient';
                
                // Try to get and validate the profile image URL
                if (patientData.containsKey('profileImageUrl') && 
                    patientData['profileImageUrl'] != null &&
                    patientData['profileImageUrl'].toString().isNotEmpty) {
                  patientImageUrl = _validateAndFixImageUrl(patientData['profileImageUrl'].toString());
                  print('Found patient image URL: $patientImageUrl');
                }
              }
              
              // If patient wasn't found in patients collection, try users collection as fallback
              if (patientName == "Unknown Patient" || patientImageUrl == null) {
                final userDoc = await _firestore
                    .collection('users')
                    .doc(data['patientId'] as String)
                    .get();
                
                if (userDoc.exists) {
                  final userData = userDoc.data() ?? {};
                  if (patientName == "Unknown Patient") {
                    patientName = userData['fullName'] ?? userData['name'] ?? 'Unknown Patient';
                  }
                  
                  // Try to get profile image if we don't have one yet
                  if (patientImageUrl == null && 
                      userData.containsKey('profileImageUrl') && 
                      userData['profileImageUrl'] != null) {
                    patientImageUrl = _validateAndFixImageUrl(userData['profileImageUrl'].toString());
                    print('Found patient image from users collection: $patientImageUrl');
                  }
                }
              }
            }
            
            // Parse date and time
            DateTime appointmentDate;
            if (data['date'] is Timestamp) {
              appointmentDate = (data['date'] as Timestamp).toDate();
            } else if (data['date'] is String) {
              try {
                appointmentDate = DateTime.parse(data['date'] as String);
              } catch (e) {
                print("Error parsing date: $e");
                appointmentDate = DateTime.now();
              }
            } else {
              appointmentDate = DateTime.now();
            }
            
            // Try to add time if available
            if (data['time'] is String && (data['time'] as String).isNotEmpty) {
              try {
                final timeStr = (data['time'] as String).trim();
                final isPM = timeStr.toLowerCase().contains('pm');
                final timeParts = timeStr
                    .toLowerCase()
                    .replaceAll('am', '')
                    .replaceAll('pm', '')
                    .trim()
                    .split(':');
                
                if (timeParts.length >= 2) {
                  int hour = int.parse(timeParts[0]);
                  int minute = int.parse(timeParts[1]);
                  
                  if (isPM && hour < 12) hour += 12;
                  if (!isPM && hour == 12) hour = 0;
                  
                  appointmentDate = DateTime(
                    appointmentDate.year,
                    appointmentDate.month,
                    appointmentDate.day,
                    hour,
                    minute,
                  );
                }
              } catch (e) {
                print("Error parsing time: $e");
              }
            }
            
            // Handle fee
            double? fee;
            if (data['fee'] != null) {
              if (data['fee'] is num) {
                fee = (data['fee'] as num).toDouble();
              } else if (data['fee'] is String) {
                try {
                  fee = double.parse(data['fee'] as String);
                } catch (e) {
                  print("Error parsing fee: $e");
                }
              }
            }
            
            // Create appointment model with patientImageUrl
            final appointment = AppointmentModel(
              id: doc.id,
              doctorName: patientName, // This is the patient name for doctor's view
              specialty: data['type'] ?? data['specialty'] ?? 'Consultation',
              hospital: data['hospitalName'] ?? data['hospital'] ?? data['location'] ?? 'Not specified',
              date: appointmentDate,
              status: data['status'] ?? 'pending',
              diagnosis: data['diagnosis'] as String?,
              prescription: data['prescription'] as String?,
              notes: data['notes'] as String?,
              fee: fee,
              patientImageUrl: patientImageUrl, // Add the patient image URL
            );
            
            freshAppointments.add(appointment);
          } catch (e) {
            print("Error processing appointment: $e");
          }
        }
      } catch (e) {
        print("Error fetching appointments directly: $e");
        // Fallback to using service
        try {
          freshAppointments = await _appointmentService.getAppointmentHistory(userId);
          _hasMoreAppointments = false; // No pagination support in the service fallback
        } catch (e) {
          print("Error using appointment service fallback: $e");
        }
      }
      
      print("Processed ${freshAppointments.length} appointments successfully");

      // Prepare data for caching
      final Map<String, dynamic> cacheData = {
        'lastUpdated': DateTime.now().toIso8601String(),
        'appointments': freshAppointments.map((app) => app.toJson()).toList(),
      };
      
      // Save to cache
        final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_appointmentsCacheKey, json.encode(cacheData));
      
      // Update UI if new data is different
      if (mounted) {
        setState(() {
          _appointments = freshAppointments;
      });
      }
    } catch (e) {
      debugPrint('Error refreshing appointments: $e');
    } finally {
      if (mounted) {
      setState(() {
          _isRefreshing = false;
      });
      }
    }
  }
  
  // Filter appointments based on search query and selected filter
  List<AppointmentModel> get filteredAppointments {
    List<AppointmentModel> result = _appointments;
    
    // Apply search query
    if (_searchQuery.isNotEmpty) {
      result = result.where((appointment) {
        final patientName = appointment.doctorName.toLowerCase();
        final hospital = appointment.hospital.toLowerCase();
        final diagnosis = appointment.diagnosis?.toLowerCase() ?? '';
        final date = appointment.date.toString().toLowerCase();
      
      final query = _searchQuery.toLowerCase();
      
        return patientName.contains(query) || 
               hospital.contains(query) ||
               diagnosis.contains(query) ||
             date.contains(query);
    }).toList();
  }
  
    // Apply filter
    if (_selectedFilter != 'All') {
      final now = DateTime.now();
      
      result = result.where((appointment) {
        // Get appointment date
        final String dateStr = appointment.date.toString();
        final String timeStr = DateFormat('hh:mm a').format(appointment.date);
        
        // Parse the appointment date
        DateTime? appointmentDateTime = _parseAppointmentDateTime(dateStr, timeStr);
        
        if (_selectedFilter == 'Upcoming') {
          // If we couldn't parse the date, check the status
          if (appointmentDateTime == null) {
            final status = appointment.status.toLowerCase();
            return status == 'upcoming' || status == 'scheduled' || status == 'confirmed' || status == 'pending';
          }
          
          // Check if appointment is in the future
          return appointmentDateTime.isAfter(now);
        } else if (_selectedFilter == 'Completed') {
          // If we couldn't parse the date, check the status
          if (appointmentDateTime == null) {
            final status = appointment.status.toLowerCase();
            return status == 'completed' || status == 'done' || status == 'cancelled';
          }
          
          // Check if appointment is in the past
          return appointmentDateTime.isBefore(now);
        }
        
        return true;
      }).toList();
    }
    
    return result;
  }
  
  // Helper to parse appointment date and time
  DateTime? _parseAppointmentDateTime(String dateStr, String timeStr) {
    if (dateStr.isEmpty) return null;
    
    try {
      DateTime? appointmentDate;
      
      // Try to parse date in different formats
      if (dateStr.contains('/')) {
        // Format: dd/MM/yyyy
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          appointmentDate = DateTime(
            int.parse(parts[2]),  // year
            int.parse(parts[1]),  // month
            int.parse(parts[0]),  // day
          );
        }
      } else if (dateStr.contains('-')) {
        // Format: yyyy-MM-dd
        appointmentDate = DateTime.parse(dateStr);
      } else {
        // Try to parse as text date (e.g., "15 Oct 2023")
        final months = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
        };
        
        final parts = dateStr.split(' ');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = months[parts[1].toLowerCase().substring(0, 3)] ?? 1;
          final year = int.parse(parts[2]);
          
          appointmentDate = DateTime(year, month, day);
        }
      }
      
      // Add time if available
      if (appointmentDate != null && timeStr.isNotEmpty) {
        // Clean up time string
        String cleanTime = timeStr.toUpperCase().trim();
        bool isPM = cleanTime.contains('PM');
        cleanTime = cleanTime.replaceAll('AM', '').replaceAll('PM', '').trim();
        
        final timeParts = cleanTime.split(':');
        if (timeParts.length >= 2) {
          int hour = int.parse(timeParts[0]);
          int minute = int.parse(timeParts[1]);
          
          // Convert to 24-hour format
          if (isPM && hour < 12) {
            hour += 12;
          }
          if (!isPM && hour == 12) {
            hour = 0;
          }
          
          appointmentDate = DateTime(
            appointmentDate.year,
            appointmentDate.month,
            appointmentDate.day,
            hour,
            minute,
          );
        }
      }
      
      return appointmentDate;
    } catch (e) {
      print('Error parsing appointment date/time: $e');
      return null;
    }
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment,
            size: 70,
            color: AppTheme.lightText,
          ),
          SizedBox(height: 20),
          Text(
            "No appointments found",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.mediumText,
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _searchQuery.isNotEmpty
                ? "No results matching \"$_searchQuery\""
                : "Your appointments will appear here",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.lightText,
              ),
            ),
          ),
          SizedBox(height: 30),
          if (_searchQuery.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedFilter = 'All';
                });
              },
              icon: Icon(Icons.refresh, size: 18),
              label: Text(
                "Clear filters",
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 70,
            color: AppTheme.warning,
          ),
          SizedBox(height: 20),
          Text(
            "Error Loading Appointments",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.mediumText,
              ),
            ),
          ),
          SizedBox(height: 30),
          Container(
            width: MediaQuery.of(context).size.width * 0.8,
            child: ElevatedButton(
            onPressed: _loadAppointmentsWithCache,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Try Again",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Progress indicator for visual appeal
          Container(
            margin: EdgeInsets.only(top: 30),
            width: MediaQuery.of(context).size.width * 0.5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.25,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primaryPink.withOpacity(0.7),
                minHeight: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ensure consistent status bar appearance
    UIHelper.applyPinkStatusBar();

    return WillPopScope(
      onWillPop: () async {
        // Ensure status bar is properly maintained when popping
        UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
        return true;
      },
      child: UIHelper.ensureStatusBarStyle(
        style: UIHelper.pinkStatusBarStyle,
        child: Scaffold(
      backgroundColor: Colors.white,
          body: Stack(
            children: [
              _isLoading 
        ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Loading appointments...",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                color: AppTheme.primaryPink,
                          ),
                        ),
                        SizedBox(height: 20),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.7,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              color: AppTheme.primaryPink,
                              backgroundColor: AppTheme.primaryPink.withOpacity(0.2),
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ],
            ),
          )
        : _errorMessage.isNotEmpty
          ? _buildErrorView()
                  : SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                      // Custom app bar with matching style
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPink,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryPink.withOpacity(0.3),
                              spreadRadius: 0,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back button
                            GestureDetector(
                                  onTap: () {
                                    // Ensure pink status bar is maintained when popping
                                    UIHelper.applyPinkStatusBar();
                                    Navigator.pop(context);
                                  },
                              child: Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                            ),
                            
                            // Title
                            Text(
                              "Appointments History",
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            
                            // Refresh icon
                            GestureDetector(
                              onTap: _loadAppointmentsWithCache,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                // Search and filter section
                _buildSearchAndFilterSection(),
                
                // Results count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        "${filteredAppointments.length} ${filteredAppointments.length == 1 ? 'result' : 'results'}",
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.mediumText,
                        fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(),
                      Text(
                            _selectedFilter != 'All' ? _selectedFilter : "Appointments history",
                        style: GoogleFonts.poppins(
                        fontSize: 14,
                              color: _selectedFilter == 'Upcoming' 
                                  ? AppTheme.primaryPink 
                                  : _selectedFilter == 'Completed'
                                    ? AppTheme.success
                                    : AppTheme.primaryPink,
                          fontWeight: FontWeight.w500,
                    ),
                  ),
                    ],
                ),
                ),
                
                // Appointment list
                Expanded(
                  child: filteredAppointments.isEmpty
                    ? _buildEmptyView()
                    : _buildAppointmentsList(),
                    ),
                  ],
                  ),
                ),
                
              // Bottom progress indicator when refreshing
                if (_isRefreshing)
                  Positioned(
                  bottom: 0,
                    left: 0,
                    right: 0,
                      child: Container(
                    height: 3,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                              ),
                              ),
                            ),
                          ],
                        ),
                      ),
            ),
    );
  }
  
  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: "Search by patient, condition, or location",
                hintStyle: GoogleFonts.poppins(
                  color: AppTheme.lightText,
                        fontSize: 14,
                      ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: AppTheme.lightText,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18, color: AppTheme.mediumText),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
              ),
            ),
          ),
          
          SizedBox(height: 15),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All'),
                SizedBox(width: 10),
                _buildFilterChip('Upcoming'),
                SizedBox(width: 10),
                _buildFilterChip('Completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPink.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryPink : Colors.grey.shade300,
            ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? AppTheme.primaryPink : AppTheme.mediumText,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
  
  Widget _buildAppointmentsList() {
    return ListView.builder(
      controller: _scrollController,
              padding: EdgeInsets.all(20),
      itemCount: filteredAppointments.length + (_hasMoreAppointments ? 1 : 0),
              itemBuilder: (context, index) {
        if (index == filteredAppointments.length) {
          return _buildLoadingIndicator();
        }
        return _buildAppointmentCard(filteredAppointments[index]);
              },
          );
  }
  
  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: _isLoadingMore
        ? Column(
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.5,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: LinearProgressIndicator(
                  backgroundColor: AppTheme.primaryPink.withOpacity(0.2),
                  color: AppTheme.primaryPink,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Loading more appointments...",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.mediumText,
                ),
              ),
            ],
          )
        : TextButton(
            onPressed: _loadMoreAppointments,
            child: Text(
              "Load More",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryPink,
              ),
            ),
          ),
          );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    // Get color based on appointment status
    Color statusColor = _getStatusColor(appointment.status);
    
    // Create value notifiers for image loading state
    final ValueNotifier<bool> imageLoadingNotifier = ValueNotifier<bool>(true);
    final ValueNotifier<bool> imageErrorNotifier = ValueNotifier<bool>(false);
    final String? patientImageUrl = appointment.patientImageUrl;
    
    return GestureDetector(
      onTap: () {
        // Apply pink status bar before navigating away
        UIHelper.applyPinkStatusBar();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentDetailsScreen(
              appointmentId: appointment.id,
            ),
          ),
        ).then((_) {
          // Re-apply pink status bar when returning
          UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.1),
              blurRadius: 15,
              offset: Offset(0, 8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            // Patient info header
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      statusColor.withOpacity(0.8),
                      statusColor.withOpacity(0.6),
                    ],
                  ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
              ),
              child: Row(
                children: [
                  // Patient image with proper loading/error handling
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                        ),
                      ],
                        color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: patientImageUrl != null && patientImageUrl.isNotEmpty
                          ? Image.network(
                              patientImageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  // Image is loaded - update loading state
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    imageLoadingNotifier.value = false;
                                  });
                                  return child;
                                } else {
                                  // Image is still loading - show progress
                                  return Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: statusColor,
                                        strokeWidth: 2,
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                }
                              },
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint('Error loading patient image: $error');
                                // Update error state
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  imageErrorNotifier.value = true;
                                  imageLoadingNotifier.value = false;
                                });
                                return Image.asset(
                                  'assets/images/User.png',
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.asset(
                              'assets/images/User.png',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.doctorName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                              color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          appointment.specialty,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status indicator
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          appointment.status,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                              color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 5),
                      // Patient profile button
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientDetailProfileScreen(
                                    name: appointment.doctorName,
                                    age: "N/A",
                                    bloodGroup: "Not Available",
                                    diseases: [appointment.diagnosis ?? 'Not specified'],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                              color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Appointment details
            Padding(
              padding: EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date, time and type row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                    children: [
                      _buildInfoTag(
                        Icons.calendar_today,
                          DateFormat('MMM dd, yyyy').format(appointment.date),
                        Colors.blue.shade700,
                      ),
                      SizedBox(width: 10),
                      _buildInfoTag(
                        Icons.access_time,
                          DateFormat('hh:mm a').format(appointment.date),
                        Colors.orange.shade700,
                      ),
                      SizedBox(width: 10),
                      _buildInfoTag(
                          Icons.medical_services,
                          appointment.specialty,
                          Colors.green.shade700,
                      ),
                    ],
                    ),
                  ),
                  
                  SizedBox(height: 15),
                  
                  // Facility and reason
                  _buildDetailRow(
                    "Facility",
                    appointment.hospital,
                    Icons.business,
                  ),
                  SizedBox(height: 10),
                  _buildDetailRow(
                    "Reason",
                    "Consultation",
                    Icons.assignment,
                  ),
                  
                  // Only show diagnosis if available
                  if (appointment.diagnosis != null && appointment.diagnosis!.isNotEmpty)
                    Column(
                      children: [
                  SizedBox(height: 10),
                  _buildDetailRow(
                    "Diagnosis",
                          appointment.diagnosis!,
                    Icons.medical_services,
                  ),
                  ],
                    ),
                  
                  // Only show prescription if available
                  if (appointment.prescription != null && appointment.prescription!.isNotEmpty)
                    Column(
                      children: [
                  SizedBox(height: 10),
                  _buildDetailRow(
                    "Prescription",
                          appointment.prescription!,
                    Icons.medication,
                        ),
                  ],
                  ),
                  
                  SizedBox(height: 15),
                  
                  // Clinical notes - only show if available
                  if (appointment.notes != null && appointment.notes!.isNotEmpty)
                    Column(
                      children: [
                  Container(
                    width: double.infinity,
                        padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                              spreadRadius: 1,
                            ),
                          ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.notes,
                                    size: 18,
                                    color: AppTheme.primaryPink,
                                  ),
                                  SizedBox(width: 8),
                          Text(
                            "Clinical Notes",
                            style: GoogleFonts.poppins(
                                      fontSize: 14,
                              fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryPink,
                            ),
                          ),
                                ],
                              ),
                              Divider(height: 16),
                          Text(
                                  appointment.notes!,
                            style: GoogleFonts.poppins(
                                      fontSize: 14,
                              color: Colors.grey.shade800,
                                      height: 1.5,
                            ),
                              ),
                        ],
                      ),
                    ),
                        SizedBox(height: 15),
                      ],
                  ),
                  
                  SizedBox(height: 15),
                  
                  // Bottom row: Fee
                  if (appointment.fee != null)
                    Container(
                      margin: EdgeInsets.only(top: 5),
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Color(0xFF3366CC).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(0xFF3366CC).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                  Row(
                    children: [
                              Icon(
                                Icons.payments_outlined,
                                size: 20,
                                color: Color(0xFF3366CC),
                              ),
                              SizedBox(width: 8),
                          Text(
                            "Consultation Fee",
                            style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.darkText,
                          ),
                              ),
                            ],
                          ),
                          Text(
                              "Rs ${appointment.fee!.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3366CC),
                            ),
                          ),
                        ],
                    ),
                    ),
                    
                  // View Details Button
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(0, 15, 0, 0),
                    child: TextButton.icon(
                      onPressed: () {
                        // Apply pink status bar before navigating away
                        UIHelper.applyPinkStatusBar();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AppointmentDetailsScreen(
                              appointmentId: appointment.id,
                            ),
                          ),
                        ).then((_) {
                          // Re-apply pink status bar when returning
                          UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
                        });
                      },
                      icon: Icon(Icons.visibility, size: 18),
                      label: Text("View Appointment Details"),
                      style: TextButton.styleFrom(
                        backgroundColor: statusColor.withOpacity(0.1),
                        foregroundColor: statusColor,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String text, Color color) {
    // Use AppTheme colors based on context
    Color tagColor = AppTheme.primaryPink;
    if (icon == Icons.calendar_today) {
      tagColor = AppTheme.primaryPink;
    } else if (icon == Icons.access_time) {
      tagColor = AppTheme.primaryTeal;
    } else if (icon == Icons.medical_services) {
      tagColor = AppTheme.success;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
        color: tagColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: tagColor.withOpacity(0.15),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: tagColor.withOpacity(0.3),
          width: 1,
        ),
          ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: tagColor,
        ),
          SizedBox(width: 6),
              Text(
            text,
                style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tagColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
            color: AppTheme.primaryPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPink.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                  spreadRadius: 1,
                ),
              ],
        ),
        child: Icon(
          icon,
              size: 18,
            color: AppTheme.primaryPink,
          ),
      ),
          SizedBox(width: 12),
        Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                label,
              style: GoogleFonts.poppins(
                    fontSize: 13,
                  color: AppTheme.mediumText,
                    fontWeight: FontWeight.w500,
              ),
            ),
                SizedBox(height: 3),
            Text(
                value,
              style: GoogleFonts.poppins(
                    fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkText,
              ),
            ),
            ],
              ),
            ),
          ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      case 'confirmed':
        return AppTheme.primaryPink;
      case 'pending':
        return AppTheme.warning;
      default:
        return AppTheme.mediumText;
    }
  }

  // Add helper method to validate and fix image URLs
  String? _validateAndFixImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    
    // Trim any whitespace
    url = url.trim();
    
    // Check if URL starts with http:// or https://
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Try to fix if it's a firebase storage URL missing the protocol
      if (url.contains('firebasestorage.googleapis.com')) {
        return 'https://$url';
      }
      return null; // Can't fix, return null
    }
    
    // Check for extra whitespace or quotes in the URL
    if (url.contains(' ') || url.contains('"') || url.contains("'")) {
      // Remove quotes and encode whitespace
      url = url.replaceAll('"', '').replaceAll("'", '').replaceAll(' ', '%20');
    }
    
    return url;
  }
}
