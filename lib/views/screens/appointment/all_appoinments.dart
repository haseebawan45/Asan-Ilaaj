import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/views/screens/appointment/appointment_detail.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../services/cache_service.dart';
import 'package:healthcare/utils/app_theme.dart';
import 'dart:async';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String _searchQuery = '';
  bool _isShowingUpcoming = true; // Default to showing upcoming appointments
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  static const String _appointmentsCacheKey = 'all_appointments_data';
  
  // Pagination variables
  static const int _itemsPerPage = 5;
  int _currentPage = 1;
  bool _hasMoreItems = true;
  
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _completedAppointments = [];
  List<Map<String, dynamic>> _filteredAppointments = [];
  List<Map<String, dynamic>> _paginatedAppointments = [];
  
  // ScrollController for detecting when user scrolls to bottom
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    
    // Add scroll listener for pagination
    _scrollController.addListener(_scrollListener);
    
    // Clean up expired cache entries when app starts
    _cleanupCache();
    _loadData();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore && 
        _hasMoreItems) {
      _loadMoreAppointments();
    }
  }

  // Clean up expired cache
  Future<void> _cleanupCache() async {
    try {
      await CacheService.cleanupExpiredCache();
    } catch (e) {
      debugPrint('Error cleaning up cache: $e');
    }
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    try {
      if (!mounted) return;
      
      debugPrint('===== _loadData started =====');
      
      setState(() {
        _isLoading = true;
        _isRefreshing = false;
      });

      // First try to load data from cache
      final bool hasCachedData = await _loadCachedData();
      
      if (!hasCachedData) {
        debugPrint('No cached data found, fetching from Firestore directly');
        // If no cached data, keep loading indicator visible
        // until we get data from Firestore
        await _fetchAppointments();
      } else {
        // If we have cached data, fetch fresh data in background
        // (linearProgressIndicator will show at bottom)
        if (!mounted) return;
        debugPrint('Cached data loaded, fetching fresh data in background');
        _fetchAppointments();
      }
      
      debugPrint('===== _loadData finished =====');
    } catch (e) {
      debugPrint('Error in _loadData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<bool> _loadCachedData() async {
    try {
      debugPrint('===== _loadCachedData started =====');
      
      // Use a longer maxAge for appointments data (1 day)
      final cachedData = await CacheService.getData(
        _appointmentsCacheKey,
        maxAge: CacheService.longCacheTime
      );
      
      if (cachedData != null && mounted) {
        debugPrint('Found valid cached data');
        // Convert the cached data back to List<Map<String, dynamic>>
        final Map<String, dynamic> dataMap = cachedData as Map<String, dynamic>;
        final List<dynamic> dataList = dataMap['appointments'] as List<dynamic>;
        final List<Map<String, dynamic>> appointments = 
            dataList.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        
        debugPrint('Processing ${appointments.length} appointments from cache');
        _processAppointments(appointments);
        setState(() {
          _isLoading = false;
        });
        debugPrint('===== _loadCachedData finished with data =====');
        return true;
      }
      debugPrint('No valid cached data found');
      debugPrint('===== _loadCachedData finished without data =====');
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
    return false;
  }
  
  // Fetch appointment data from Firebase
  Future<void> _fetchAppointments() async {
    if (!mounted) return;
    
    debugPrint('===== _fetchAppointments started =====');
    
    // Always set _isRefreshing to true when fetching appointments
    setState(() {
      _isRefreshing = true;
    });
    debugPrint('Setting _isRefreshing to true in _fetchAppointments');
    
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final String? userId = FirebaseAuth.instance.currentUser?.uid;
      
      if (userId == null) {
        debugPrint('User ID is null, exiting fetch');
        setState(() {
          _isRefreshing = false;
          _isLoading = false;
        });
        return;
      }
      
      // Artificial delay to ensure progress indicator is visible for testing
      // You can remove this in production
      await Future.delayed(Duration(seconds: 1));
      
      debugPrint('Fetching appointments for user: $userId');
      
      // Query appointments collection
      final QuerySnapshot appointmentsSnapshot = await firestore
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .get();
      
      debugPrint('Found ${appointmentsSnapshot.docs.length} appointments in database');
      
      List<Map<String, dynamic>> appointments = [];
      
      for (var doc in appointmentsSnapshot.docs) {
        try {
          Map<String, dynamic> appointment = doc.data() as Map<String, dynamic>;
          appointment['id'] = doc.id;
          
          // Fetch doctor details for this appointment
          if (appointment['doctorId'] != null) {
            final doctorDoc = await firestore
                .collection('doctors')
                .doc(appointment['doctorId'].toString())
                .get();
            
            if (doctorDoc.exists) {
              final doctorData = doctorDoc.data() as Map<String, dynamic>;
              // Merge doctor data into appointment
              appointment['doctorName'] = doctorData['fullName'] ?? doctorData['name'] ?? 'Doctor';
              appointment['specialty'] = doctorData['specialty'] ?? 'Specialist';
              
              // Process the doctor profile image with validation
              if (doctorData.containsKey('profileImageUrl') && doctorData['profileImageUrl'] != null) {
                String imageUrl = doctorData['profileImageUrl'].toString().trim();
                
                // Validate URL format
                if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
                  appointment['doctorImage'] = imageUrl;
                  debugPrint('Valid doctor image URL found: $imageUrl');
                } else if (imageUrl.contains('firebasestorage.googleapis.com')) {
                  // Try to fix Firebase Storage URLs missing protocol
                  appointment['doctorImage'] = 'https://' + imageUrl;
                  debugPrint('Fixed Firebase Storage URL: https://$imageUrl');
                } else {
                  debugPrint('Invalid doctor image URL format: $imageUrl');
                  appointment['doctorImage'] = 'assets/images/User.png';
                }
              } else {
                debugPrint('No doctor profile image found for doctor ${doctorData['fullName'] ?? doctorData['name']}');
                appointment['doctorImage'] = 'assets/images/User.png';
              }
            }
          }

          // Ensure all required fields exist and include the completed flag
          appointment = {
            ...appointment,
            'date': appointment['date'] ?? DateTime.now().toString().split(' ')[0],
            'time': appointment['time'] ?? '00:00',
            'status': appointment['status']?.toString().toLowerCase() ?? 'upcoming',
            'doctorName': appointment['doctorName'] ?? 'Doctor',
            'specialty': appointment['specialty'] ?? 'Specialist',
            'hospitalName': appointment['hospitalName'] ?? 'Hospital',
            'type': appointment['type'] ?? 'Consultation',
            'doctorImage': appointment['doctorImage'] ?? 'assets/images/User.png',
            'completed': appointment['completed'] == true,
          };

          // Debug the completed status
          debugPrint('Appointment ${appointment['id']} completed status: ${appointment['completed']}');
          
          debugPrint('Processing appointment: ${appointment['id']} for ${appointment['doctorName']} on ${appointment['date']} at ${appointment['time']}');
          appointments.add(appointment);
        } catch (e) {
          debugPrint('Error processing individual appointment: $e');
        }
      }

      // Check if data has changed before updating
      bool hasDataChanged = _appointments.isEmpty || 
          !_areListContentsEqual(_appointments, appointments);

      if (hasDataChanged) {
        debugPrint('Data has changed, saving to cache and updating UI');
        // Save to cache with longer expiry
        await CacheService.saveData(
          _appointmentsCacheKey,
          {
            'appointments': appointments.map((e) => Map<String, dynamic>.from(e)).toList(),
            'lastUpdated': DateTime.now().toIso8601String(),
          },
          expiry: CacheService.longCacheTime
        );

        if (!mounted) return;

        debugPrint('Successfully processed ${appointments.length} appointments');
        _processAppointments(appointments);
      } else {
        debugPrint('No changes in appointments data');
        if (mounted) {
          debugPrint('Setting _isRefreshing and _isLoading to false (no changes)');
          setState(() {
            _isRefreshing = false;
            _isLoading = false;
          });
        }
      }
      
      debugPrint('===== _fetchAppointments finished =====');
      
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
      if (mounted) {
        debugPrint('Setting _isRefreshing and _isLoading to false (error)');
        setState(() {
          _isRefreshing = false;
          _isLoading = false;
        });
      }
    }
  }
  
  void _processAppointments(List<Map<String, dynamic>> appointments) {
    if (!mounted) return;
    
    debugPrint('===== _processAppointments started with ${appointments.length} appointments =====');
    
    // Clear existing lists
    _upcomingAppointments.clear();
    _completedAppointments.clear();
    
    // Process each appointment
    for (var appointment in appointments) {
      try {
        // Primary filter: Use the completed flag
        final bool isCompleted = appointment['completed'] == true;
        final String status = appointment['status']?.toString().toLowerCase() ?? '';
        final bool isCancelled = status == 'cancelled';
        
        // Cancelled appointments should always go to completed list
        if (isCancelled) {
          debugPrint('Adding to completed (cancelled): ${appointment['id']}');
          _completedAppointments.add(appointment);
          continue;
        }
        
        // Use completed field as the primary source of truth
        if (isCompleted) {
          debugPrint('Adding to completed (completed flag): ${appointment['id']}');
          _completedAppointments.add(appointment);
        } else {
          debugPrint('Adding to upcoming (not completed): ${appointment['id']}');
          _upcomingAppointments.add(appointment);
        }
      } catch (e) {
        debugPrint('Error processing appointment ${appointment['id']}: $e');
      }
    }
    
    debugPrint('Processed ${appointments.length} appointments:');
    debugPrint('Upcoming: ${_upcomingAppointments.length}');
    debugPrint('Completed: ${_completedAppointments.length}');
    
    setState(() {
      _appointments = appointments;
      
      // Reset pagination
      _currentPage = 1;
      _hasMoreItems = true;
      
      // Apply current filters and pagination
      _filterAppointments();
      
      debugPrint('Setting _isLoading and _isRefreshing to false in _processAppointments');
      _isLoading = false;
      _isRefreshing = false;
    });
    
    debugPrint('===== _processAppointments finished =====');
  }

  Future<void> _onRefresh() async {
    if (_isLoading) {
      debugPrint('Already loading, skipping refresh');
      return;
    }
    
    debugPrint('===== _onRefresh started =====');
    
    // Show only bottom progress indicator
    if (mounted) {
      debugPrint('Setting _isRefreshing to true for pull-to-refresh');
      setState(() {
        _isRefreshing = true;
        // Reset pagination
        _currentPage = 1;
        _hasMoreItems = true;
      });
    }
    
    try {
      // Add a small delay to ensure the refresh indicator is visible
      await Future.delayed(Duration(milliseconds: 500));
      await _fetchAppointments();
    } finally {
      // Ensure refreshing state is reset
      if (mounted) {
        debugPrint('Ensuring _isRefreshing is reset to false');
        setState(() {
          _isRefreshing = false;
        });
      }
    }
    
    debugPrint('===== _onRefresh finished =====');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building UI with _isRefreshing: $_isRefreshing, _isLoading: $_isLoading');
    
    return WillPopScope(
      onWillPop: () async {
        debugPrint('***** BACK BUTTON PRESSED - NAVIGATING TO PATIENT BOTTOM NAVIGATION *****');
        Navigator.of(context).pushNamedAndRemoveUntil('/patient/bottom_navigation', (route) => false);
        return false;
      },
      child: Scaffold(
      backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryTeal,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              debugPrint('***** BACK BUTTON PRESSED - NAVIGATING TO PATIENT BOTTOM NAVIGATION *****');
              Navigator.of(context).pushNamedAndRemoveUntil('/patient/bottom_navigation', (route) => false);
            },
          ),
          title: Text(
            "My Appointments",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
        children: [
            Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildSearchBar(),
                ),
                
                // Toggle buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.lightTeal,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isShowingUpcoming = true;
                                // Reset pagination for tab change
                                _currentPage = 1;
                                _hasMoreItems = true;
                                _paginatedAppointments = [];
                                _filterAppointments();
                              });
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _isShowingUpcoming
                                    ? AppTheme.primaryTeal
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                "Upcoming",
                                style: GoogleFonts.poppins(
                                  color: _isShowingUpcoming
                                      ? Colors.white
                                      : AppTheme.primaryTeal,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  ),
                                ),
                              ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isShowingUpcoming = false;
                                // Reset pagination for tab change
                                _currentPage = 1;
                                _hasMoreItems = true;
                                _paginatedAppointments = [];
                                _filterAppointments();
                              });
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: !_isShowingUpcoming
                                    ? AppTheme.primaryTeal
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                "Completed",
                                style: GoogleFonts.poppins(
                                  color: !_isShowingUpcoming
                                      ? Colors.white
                                      : AppTheme.primaryTeal,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ),
                ),
              ],
            ),
          ),
                ),
                
                // Appointment list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: _buildAppointmentList(
                      _filteredAppointments,
                      _isShowingUpcoming ? "upcoming" : "completed"
                    ),
                  ),
                ),
              ],
            ),
            
            // Loading indicator at bottom, above the bottom navigation bar
            if (_isRefreshing)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2, // Increased height for better visibility
                  decoration: BoxDecoration(
                    // Add shadow above the indicator for better visibility
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentList(List<Map<String, dynamic>> appointments, String status) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Loading appointments...",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    
    if (appointments.isEmpty) {
      return _buildNoAppointmentsFound(status);
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: _paginatedAppointments.length + (_hasMoreItems ? 1 : 0), // +1 for loading indicator
      itemBuilder: (context, index) {
        // Show loading indicator at the end
        if (index == _paginatedAppointments.length && _hasMoreItems) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                  strokeWidth: 3,
                ),
              ),
            ),
          );
        }
        
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Interval(
                0.1 + (index * 0.1 > 0.5 ? 0.5 : index * 0.1),
                0.6 + (index * 0.1 > 0.5 ? 0.5 : index * 0.1),
                curve: Curves.easeOut,
              ),
            ),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0.2),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Interval(
                  0.1 + (index * 0.1 > 0.5 ? 0.5 : index * 0.1),
                  0.6 + (index * 0.1 > 0.5 ? 0.5 : index * 0.1),
                  curve: Curves.easeOut,
                ),
              ),
            ),
            child: _buildAppointmentCard(
              context,
              _paginatedAppointments[index],
              index,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.lightTeal,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            // Reset pagination for new search
            _currentPage = 1;
            _hasMoreItems = true;
            _paginatedAppointments = [];
            _filterAppointments();
          });
        },
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: "Search appointments",
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            LucideIcons.search,
            color: AppTheme.primaryTeal,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    LucideIcons.x,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      // Reset pagination when clearing search
                      _currentPage = 1;
                      _hasMoreItems = true;
                      _paginatedAppointments = [];
                      _filterAppointments();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildNoAppointmentsFound(String status) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.calendar,
            size: 60,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 20),
          Text(
            "No appointments found",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 10),
          Text(
            _searchQuery.isNotEmpty
                ? "Try a different search term"
                : "You don't have any appointments yet",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(BuildContext context, Map<String, dynamic> appointment, int index) {
    final String statusText = appointment['status']?.toString().toLowerCase() ?? 'upcoming';
    final bool isCompleted = appointment['completed'] == true; 
    final bool isCancelled = statusText == 'cancelled';
    
    // When showing upcoming tab, we should only display appointments that are not completed
    // When showing completed tab, we should only display appointments that are completed
    // This logic verifies that appointment's completed status matches the selected tab
    final bool matchesSelectedTab = _isShowingUpcoming ? !isCompleted : isCompleted;
    if (!matchesSelectedTab) {
      debugPrint('Appointment ${appointment['id']} does not match selected tab. Tab: ${_isShowingUpcoming ? "Upcoming" : "Completed"}, Completed: $isCompleted');
    }
    
    final Color statusColor = isCancelled
        ? AppTheme.error
        : isCompleted
            ? AppTheme.success // Green for completed appointments
            : AppTheme.primaryTeal; // Blue for upcoming
            
    final String displayStatus = isCancelled
        ? "Cancelled"
        : isCompleted
            ? "Completed"
            : "Upcoming";
    
    final String doctorName = appointment['doctorName']?.toString() ?? 'Doctor';
    final String specialty = appointment['specialty']?.toString() ?? 'Specialist';
    final String date = appointment['date']?.toString() ?? 'No date';
    final String time = appointment['time']?.toString() ?? 'No time';
    final String hospitalName = appointment['hospitalName']?.toString() ?? 'Hospital';
    final String appointmentType = appointment['type']?.toString() ?? 'Consultation';
    
    // Check if appointment has been reviewed
    final bool hasReview = appointment['isRated'] == true;
    
    // Only show review options for appointments in the completed tab
    final bool canReview = isCompleted && !isCancelled && !hasReview;
    
    // Track doctor image loading state
    final ValueNotifier<bool> isImageLoading = ValueNotifier<bool>(true);
    final ValueNotifier<bool> hasImageError = ValueNotifier<bool>(false);
    final ImageProvider? doctorImage = _getDoctorImageSafely(appointment);
    
    // If we have no image to load or using a default asset, don't show loading state
    if (doctorImage == null || 
        (appointment['doctorImage'] is String && 
         appointment['doctorImage'].toString().startsWith('assets/'))) {
      isImageLoading.value = false;
    } else if (doctorImage is NetworkImage) {
      // Handle network image loading state
      final imageStream = doctorImage.resolve(ImageConfiguration.empty);
      final imageStreamListener = ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          // Image loaded successfully
          isImageLoading.value = false;
        },
        onError: (exception, stackTrace) {
          // Error loading image
          hasImageError.value = true;
          isImageLoading.value = false;
          debugPrint('Network error loading doctor image: $exception');
          
          // Try to retry image load if we have doctorId
          if (appointment.containsKey('doctorId') && 
              appointment['doctorId'] != null && 
              appointment['doctorId'].toString().isNotEmpty) {
            // Delay retry to avoid spamming requests
            Future.delayed(Duration(seconds: 1), () {
              _retryDoctorImageLoad(
                appointment['id'].toString(), 
                appointment['doctorId'].toString()
              );
            });
          }
        },
      );
      
      // Add listener to track when image finishes loading
      imageStream.addListener(imageStreamListener);
      
      // Clean up listener after a timeout (in case image never loads)
      Future.delayed(Duration(seconds: 10), () {
        imageStream.removeListener(imageStreamListener);
        isImageLoading.value = false;
      });
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withOpacity(0.08),
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
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
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
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isImageLoading,
                    builder: (context, loading, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: hasImageError,
                        builder: (context, hasError, _) {
                          return CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey.shade200,
                            backgroundImage: hasError ? null : doctorImage,
                            onBackgroundImageError: (exception, stackTrace) {
                              debugPrint('Error loading doctor image for appointment ${appointment['id']}: $exception');
                              hasImageError.value = true;
                              isImageLoading.value = false;
                              
                              // Try to retry image load if we have doctorId
                              if (appointment.containsKey('doctorId') && 
                                  appointment['doctorId'] != null && 
                                  appointment['doctorId'].toString().isNotEmpty) {
                                // Delay retry to avoid spamming requests
                                Future.delayed(Duration(seconds: 1), () {
                                  _retryDoctorImageLoad(
                                    appointment['id'].toString(), 
                                    appointment['doctorId'].toString()
                                  );
                                });
                              }
                            },
                            child: hasError || doctorImage == null
                              ? Icon(
                      LucideIcons.user,
                      color: Colors.white,
                      size: 22,
                                )
                              : loading
                                ? CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : null,
                          );
                        }
                      );
                    }
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        specialty,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    displayStatus,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildAppointmentDetail(
                      LucideIcons.calendar,
                      "Date",
                      date,
                    ),
                    SizedBox(width: 15),
                    _buildAppointmentDetail(
                      LucideIcons.clock,
                      "Time",
                      time,
                    ),
                  ],
                ),
                SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAppointmentDetail(
                      LucideIcons.building2,
                      "Hospital",
                      hospitalName,
                      maxLines: 3,
                    ),
                    SizedBox(width: 15),
                    _buildAppointmentDetail(
                      LucideIcons.tag,
                      "Appointment Type",
                      appointmentType,
                    ),
                  ],
                ),
                
                // If cancelled, show reason
                if (isCancelled && appointment['cancellationReason'] != null) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.info,
                          color: AppTheme.error,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            appointment['cancellationReason']?.toString() ?? 'Cancelled by user',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                SizedBox(height: 16),
                
                // Action buttons row
                Row(
                        children: [
                          Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AppointmentDetailsScreen(
                                      appointmentDetails: appointment,
                                    ),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: statusColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          shadowColor: statusColor.withOpacity(0.3),
                        ),
                        icon: Icon(LucideIcons.clipboardList, size: 18),
                        label: Text(
                              "View Details",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    
                    // Add Review button for completed appointments that haven't been reviewed
                    if (canReview) ...[
                            SizedBox(width: 12),
                            Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRatingDialog(context, appointment),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warning,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                            shadowColor: AppTheme.warning.withOpacity(0.3),
                          ),
                          icon: Icon(LucideIcons.star, size: 18),
                          label: Text(
                            "Add Review",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    // Show rating if review exists
                    if (isCompleted && hasReview) ...[
                      SizedBox(width: 12),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                LucideIcons.star,
                              size: 16,
                              color: AppTheme.warning,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "${appointment['userRating']?.toString() ?? '0'}/5",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.warning,
                              ),
                            ),
                          ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAppointmentDetail(IconData icon, String label, String value, {int maxLines = 1}) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppTheme.primaryTeal,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: maxLines,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
        shadowColor: color.withOpacity(0.3),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context, Map<String, dynamic> appointment) {
    double _rating = appointment['userRating']?.toDouble() ?? 0;
    TextEditingController _feedbackController = TextEditingController();
    _feedbackController.text = appointment['userFeedback'] ?? '';
    bool _isSubmitting = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.star,
                        size: 35,
                        color: AppTheme.warning,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Rate Your Experience",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "How was your appointment with Dr. ${appointment['doctorName'].split(' ').last}?",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.mediumText,
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: index < _rating ? AppTheme.warning : Colors.grey,
                            size: 36,
                          ),
                          onPressed: () {
                            setState(() {
                              _rating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                    SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.lightTeal,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.divider,
                        ),
                      ),
                      child: TextField(
                        controller: _feedbackController,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Share your feedback (optional)",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting 
                                ? null 
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.mediumText,
                              side: BorderSide(color: AppTheme.divider),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Cancel",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting || _rating == 0
                                ? null
                                : () async {
                                    setState(() {
                                      _isSubmitting = true;
                                    });
                                    
                                    await _submitRating(
                                      appointment['id'],
                                      appointment['doctorName'],
                                      _rating,
                                      _feedbackController.text,
                                    );
                                    
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: Colors.grey,
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    "Submit",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
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
      },
    );
  }
  
  Future<void> _submitRating(
    String appointmentId, 
    String doctorName,
    double rating, 
    String feedback
  ) async {
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final userId = auth.currentUser?.uid;
      
      if (userId == null) return;
      
      // Get appointment document
      final appointmentDoc = await firestore
          .collection('appointments')
          .doc(appointmentId)
          .get();
      
      if (!appointmentDoc.exists) {
        debugPrint('Appointment document not found');
        return;
      }
      
      final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      final doctorId = appointmentData['doctorId'];
      
      if (doctorId == null) {
        debugPrint('Doctor ID not found in appointment');
        return;
      }
      
      // Create review document in doctor_reviews collection
      await firestore.collection('doctor_reviews').add({
        'appointmentId': appointmentId,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'feedback': feedback,
        'patientId': userId,
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Update appointment with rating status
      await firestore.collection('appointments').doc(appointmentId).update({
        'userRating': rating,
        'userFeedback': feedback,
        'isRated': true,
        'ratingTimestamp': FieldValue.serverTimestamp(),
      });
      
      // Update local state
      if (mounted) {
        setState(() {
          for (var appointment in _appointments) {
            if (appointment['id'] == appointmentId) {
              appointment['userRating'] = rating;
              appointment['userFeedback'] = feedback;
              appointment['isRated'] = true;
              break;
            }
          }
          _filterAppointments();
        });
      }
      
      debugPrint('Review submitted successfully');
    } catch (e) {
      debugPrint('Error submitting review: $e');
      throw e;
    }
  }

  void _filterAppointments() {
    if (!mounted) return;
    
    setState(() {
      final List<Map<String, dynamic>> sourceList = 
          _isShowingUpcoming ? _upcomingAppointments : _completedAppointments;
      
      if (_searchQuery.isEmpty) {
        _filteredAppointments = List.from(sourceList);
      } else {
      // Apply search filter
      _filteredAppointments = sourceList.where((appointment) {
        final searchLower = _searchQuery.toLowerCase();
        final nameMatch = appointment['doctorName']?.toString().toLowerCase().contains(searchLower) ?? false;
        final dateMatch = appointment['date']?.toString().toLowerCase().contains(searchLower) ?? false;
        final typeMatch = appointment['type']?.toString().toLowerCase().contains(searchLower) ?? false;
        final hospitalMatch = appointment['hospitalName']?.toString().toLowerCase().contains(searchLower) ?? false;
        return nameMatch || dateMatch || typeMatch || hospitalMatch;
      }).toList();
      }
      
      // Reset pagination
      _currentPage = 1;
      _hasMoreItems = _filteredAppointments.length > _itemsPerPage;
      
      // Initialize paginated appointments with first page
      _paginatedAppointments = _filteredAppointments.length > _itemsPerPage 
          ? _filteredAppointments.sublist(0, _itemsPerPage)
          : List.from(_filteredAppointments);
    });
  }

  // Helper method to handle doctor image safely
  ImageProvider? _getDoctorImageSafely(Map<String, dynamic> appointment) {
    try {
      // Check if doctor image URL exists
      if (!appointment.containsKey('doctorImage') || 
          appointment['doctorImage'] == null || 
          appointment['doctorImage'].toString().trim().isEmpty) {
    return null;
      }
      
      String imageUrl = appointment['doctorImage'].toString().trim();
      
      // If it's an asset path, return an AssetImage
      if (imageUrl.startsWith('assets/')) {
        return AssetImage(imageUrl);
      }
      
      // Validate URL format
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        // Try to fix Firebase Storage URLs missing protocol
        if (imageUrl.contains('firebasestorage.googleapis.com')) {
          imageUrl = 'https://' + imageUrl;
          debugPrint('Fixed malformed Firebase Storage URL: $imageUrl');
        } else {
          debugPrint('Invalid image URL format: $imageUrl');
          return null;
        }
      }
      
      // Clean URL by removing unwanted characters
      if (imageUrl.contains(' ') || imageUrl.contains("'")) {
        imageUrl = imageUrl.replaceAll('"', '')
                          .replaceAll("'", '')
                          .replaceAll(' ', '%20');
        debugPrint('Cleaned doctor image URL: $imageUrl');
      }
      
      // Return the NetworkImage with the validated URL
      return NetworkImage(imageUrl);
    } catch (e) {
      debugPrint('Error processing doctor image: $e');
      return null;
    }
  }

  // Helper method to compare lists (deep comparison)
  bool _areListContentsEqual(List<Map<String, dynamic>> list1, List<Map<String, dynamic>> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (!_areMapContentsEqual(list1[i], list2[i])) return false;
    }
    
    return true;
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

  // Load more appointments for pagination
  Future<void> _loadMoreAppointments() async {
    if (_isLoadingMore || !_hasMoreItems) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final List<Map<String, dynamic>> sourceList = 
        _isShowingUpcoming ? _upcomingAppointments : _completedAppointments;
    
    List<Map<String, dynamic>> filteredList = sourceList;
    if (_searchQuery.isNotEmpty) {
      filteredList = sourceList.where((appointment) {
        final searchLower = _searchQuery.toLowerCase();
        final nameMatch = appointment['doctorName']?.toString().toLowerCase().contains(searchLower) ?? false;
        final dateMatch = appointment['date']?.toString().toLowerCase().contains(searchLower) ?? false;
        final typeMatch = appointment['type']?.toString().toLowerCase().contains(searchLower) ?? false;
        final hospitalMatch = appointment['hospitalName']?.toString().toLowerCase().contains(searchLower) ?? false;
        return nameMatch || dateMatch || typeMatch || hospitalMatch;
      }).toList();
    }
    
    // Calculate next page items
    final int startIndex = _itemsPerPage * _currentPage;
    
    if (startIndex >= filteredList.length) {
      setState(() {
        _hasMoreItems = false;
        _isLoadingMore = false;
      });
      return;
    }
    
    final int endIndex = (startIndex + _itemsPerPage) > filteredList.length 
        ? filteredList.length 
        : startIndex + _itemsPerPage;
    
    final List<Map<String, dynamic>> nextPageItems = 
        filteredList.sublist(startIndex, endIndex);
    
    setState(() {
      _paginatedAppointments.addAll(nextPageItems);
      _currentPage++;
      _isLoadingMore = false;
      _hasMoreItems = endIndex < filteredList.length;
    });
  }

  // Attempt to retry loading a doctor image by fetching updated URL 
  Future<void> _retryDoctorImageLoad(String appointmentId, String doctorId) async {
    if (appointmentId.isEmpty || doctorId.isEmpty) return;
    
    debugPrint('Retrying image load for doctor ID: $doctorId');
    
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final doctorDoc = await firestore.collection('doctors').doc(doctorId).get();
      
      if (!doctorDoc.exists || doctorDoc.data() == null) return;
      
      final doctorData = doctorDoc.data()!;
      String? updatedImageUrl;
      
      // Try different image fields that might exist
      if (doctorData.containsKey('profileImageUrl') && doctorData['profileImageUrl'] != null) {
        updatedImageUrl = doctorData['profileImageUrl'].toString();
      } else if (doctorData.containsKey('imageUrl') && doctorData['imageUrl'] != null) {
        updatedImageUrl = doctorData['imageUrl'].toString();
      } else if (doctorData.containsKey('photoURL') && doctorData['photoURL'] != null) {
        updatedImageUrl = doctorData['photoURL'].toString();
      }
      
      if (updatedImageUrl == null || updatedImageUrl.isEmpty) {
        debugPrint('No valid image URL found in doctor document');
        return;
      }
      
      // Validate URL format
      if (!updatedImageUrl.startsWith('http://') && !updatedImageUrl.startsWith('https://')) {
        if (updatedImageUrl.contains('firebasestorage.googleapis.com')) {
          updatedImageUrl = 'https://' + updatedImageUrl;
        } else {
          debugPrint('Invalid image URL format after retry: $updatedImageUrl');
          return;
        }
      }
      
      // Update appointment in our lists
      for (var appointment in _appointments) {
        if (appointment['id'] == appointmentId) {
          appointment['doctorImage'] = updatedImageUrl;
          debugPrint('Updated doctor image URL: $updatedImageUrl');
          break;
        }
      }
      
      // Force UI update by triggering filter
      if (mounted) {
        _filterAppointments();
      }
      
    } catch (e) {
      debugPrint('Error retrying doctor image load: $e');
    }
  }
}
