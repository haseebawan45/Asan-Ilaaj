import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/views/components/onboarding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthcare/views/screens/doctor/prescription/prescription_screen.dart';
import 'package:healthcare/views/screens/doctor/prescription/prescription_view_screen.dart';
import 'package:healthcare/views/screens/common/chat/chat_detail_screen.dart';
import 'package:healthcare/models/chat_room_model.dart';
import 'package:healthcare/services/chat_service.dart';
import 'package:healthcare/utils/app_theme.dart';
import 'package:healthcare/views/screens/patient/appointment/simplified_booking_flow.dart';

class AppointmentDetailsScreen extends StatefulWidget {
  final String? appointmentId;
  final Map<String, dynamic>? appointmentDetails;
  
  const AppointmentDetailsScreen({
    super.key,
    this.appointmentId,
    this.appointmentDetails,
  });

  @override
  State<AppointmentDetailsScreen> createState() => _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  Map<String, dynamic> _appointmentData = {};
  String _doctorName = "Doctor";
  String _appointmentDate = "Upcoming";
  String _appointmentTime = "";
  String _doctorSpecialty = "";
  String _hospitalName = "";
  String _fee = "0";
  String _paymentStatus = "Pending";
  String _paymentMethod = "Not specified";
  String _appointmentType = "Regular Consultation";
  String _appointmentStatus = "Upcoming";
  String _reason = "No reason provided";
  String _appointmentId = "";
  bool _isCancelled = false;
  bool _isUpcoming = true;
  String? _cancellationReason;
  String _doctorImage = 'assets/images/User.png';
  static const String _appointmentDetailsCacheKey = 'appointment_details_';
  
  // User role detection
  bool _isDoctor = false;
  bool _isPatient = false;
  String _currentUserId = '';
  
  @override
  void initState() {
    super.initState();
    _loadUserRoleAndData();
  }
  
  // Load user role first, then load appointment data
  Future<void> _loadUserRoleAndData() async {
    try {
      // First check user role
      await _checkUserRole();
      
      // Then load appointment data
    if (widget.appointmentDetails != null) {
      // Use provided appointment details directly
      _processAppointmentDetails(widget.appointmentDetails!);
      setState(() {
        _isLoading = false;
      });
    } else if (widget.appointmentId != null) {
      // Load data from cache first, then fetch from Firebase
      _loadData();
    } else {
      // No appointment ID or details provided, show default data
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in _loadUserRoleAndData: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Check if the current user is a doctor or patient
  Future<void> _checkUserRole() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      _currentUserId = currentUser.uid;
      
      // Check if user is a doctor
      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(currentUser.uid)
          .get();
      
      if (doctorDoc.exists) {
        setState(() {
          _isDoctor = true;
        });
        return;
      }
      
      // Check if user is a patient
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(currentUser.uid)
          .get();
      
      if (patientDoc.exists) {
        setState(() {
          _isPatient = true;
        });
      }
    } catch (e) {
      print('Error checking user role: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      // First try to load data from cache
      await _loadCachedData();
      
      // Then fetch fresh data from Firebase
      if (mounted) {
        await _fetchAppointmentData();
      }
    } catch (e) {
      print('Error in _loadData: $e');
      // Ensure loading is set to false if an error occurs
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCachedData() async {
    if (widget.appointmentId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString(_appointmentDetailsCacheKey + widget.appointmentId!);
      
      if (cachedData != null) {
        final Map<String, dynamic> decoded = json.decode(cachedData);
        _processAppointmentDetails(decoded);
        
        // Don't set _isLoading to false here - wait for Firebase data
      } else {
        // Don't set _isLoading to false if there's no cached data
        // We'll still need to wait for Firebase data
      }
    } catch (e) {
      print('Error loading cached data: $e');
      // Don't set _isLoading to false - we'll still try to fetch from Firebase
    }
  }

  void _processAppointmentDetails(Map<String, dynamic> details) {
    _appointmentData = details;
    
    // Set appointment date and time
    if (details['date'] != null && details['time'] != null) {
      // Use the date and time directly from the appointment
      _appointmentDate = details['date'];
      _appointmentTime = details['time'];
    } else if (details.containsKey('appointmentDate') && details['appointmentDate'] is Timestamp) {
      // Fallback to appointmentDate if date/time not available
      final DateTime appointmentDate = (details['appointmentDate'] as Timestamp).toDate();
      _appointmentDate = DateFormat('MMM dd, yyyy').format(appointmentDate);
      _appointmentTime = DateFormat('h:mm a').format(appointmentDate);
    } else {
      // Default values if no date/time information available
      _appointmentDate = "Not specified";
      _appointmentTime = "Not specified";
    }
    
    // Set doctor info
    _doctorName = details['doctorName'] ?? "Unknown Doctor";
    _doctorSpecialty = details['specialty'] ?? details['doctorSpecialty'] ?? "General";
    
    // Process doctor image with validation
    if (details.containsKey('doctorImage') && details['doctorImage'] != null) {
      String imageUrl = details['doctorImage'].toString();
      // Validate and fix URL
      String? validatedUrl = _validateAndFixImageUrl(imageUrl);
      if (validatedUrl != null) {
        _doctorImage = validatedUrl;
        print('Set doctor image to validated URL: $validatedUrl');
      } else {
        _doctorImage = 'assets/images/User.png';
        print('Using default doctor image due to invalid URL: $imageUrl');
      }
    } else {
      _doctorImage = 'assets/images/User.png';
    }
    
    // Set hospital name - use direct value without fallback
    _hospitalName = details['hospitalName'] ?? "Unknown Hospital";
    
    // Set payment details
    if (details.containsKey('fee') && details['fee'] is num) {
      _fee = "Rs. ${details['fee']}";
    } else if (details.containsKey('displayFee')) {
      _fee = details['displayFee'];
    } else {
      _fee = details['fee']?.toString() ?? "0";
    }
    
    _paymentStatus = details['paymentStatus'] ?? "Pending";
    _paymentMethod = details['paymentMethod'] ?? "Not specified";
    
    // Convert to title case
    _paymentStatus = _capitalize(_paymentStatus);
    _paymentMethod = _capitalize(_paymentMethod);
    
    // Set appointment details
    _appointmentType = details['type'] ?? "Regular Consultation";
    _appointmentStatus = details['status'] ?? "Upcoming";
    _appointmentStatus = _capitalize(_appointmentStatus);
    _appointmentId = details['id'] ?? "";
    
    // Set status flags
    _isCancelled = _appointmentStatus.toLowerCase() == 'cancelled';
    _isUpcoming = _appointmentStatus.toLowerCase() == 'upcoming';
    
    // Set reason
    if (details.containsKey('reason') && details['reason'] != null && details['reason'].toString().isNotEmpty) {
      _reason = details['reason'];
    } else if (details.containsKey('notes') && details['notes'] != null && details['notes'].toString().isNotEmpty) {
      _reason = details['notes'];
    }
    
    // Set cancellation reason
    if (_isCancelled && details.containsKey('cancellationReason') && details['cancellationReason'] != null) {
      _cancellationReason = details['cancellationReason'];
    }
    
    // Validate patient image URLs
    if (details.containsKey('patientImageUrl') && details['patientImageUrl'] != null) {
      String imageUrl = details['patientImageUrl'].toString();
      String? validatedUrl = _validateAndFixImageUrl(imageUrl);
      if (validatedUrl != null) {
        details['patientImageUrl'] = validatedUrl;
        print('Validated patient image URL: $validatedUrl');
      } else {
        // Remove invalid URL
        details['patientImageUrl'] = '';
        print('Removed invalid patient image URL: $imageUrl');
      }
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.substring(0, 1).toUpperCase() + text.substring(1);
  }
  
  // Helper method to validate and fix image URLs
  String? _validateAndFixImageUrl(String url) {
    if (url.isEmpty) return null;
    
    // Trim any whitespace
    url = url.trim();
    
    // Check if URL starts with http:// or https://
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Try to fix if it's a firebase storage URL missing the protocol
      if (url.contains('firebasestorage.googleapis.com')) {
        return 'https://' + url;
      }
      return null; // Can't fix, return null
    }
    
    // Check for extra whitespace or quotes in the URL
    if (url.contains(' ') || url.contains('"') || url.contains("'")) {
      // Remove quotes and whitespace
      url = url.replaceAll('"', '').replaceAll("'", '').replaceAll(' ', '%20');
    }
    
    // Check if URL ends with valid image extension (optional)
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'];
    bool hasValidExtension = validExtensions.any((ext) => url.toLowerCase().endsWith(ext));
    
    // For Firebase Storage URLs, we don't need to enforce extensions
    bool isFirebaseStorage = url.contains('firebasestorage.googleapis.com');
    
    if (!hasValidExtension && !isFirebaseStorage) {
      print('Warning: URL may not be an image: $url');
      // Still return it, but log a warning
    }
    
    return url;
  }

  Future<void> _fetchAppointmentData() async {
    if (!mounted || widget.appointmentId == null) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Fetch appointment data
      final appointmentDoc = await firestore
          .collection('appointments')
          .doc(widget.appointmentId)
          .get();
      
      if (!appointmentDoc.exists || appointmentDoc.data() == null) {
        setState(() {
          _isRefreshing = false;
          _isLoading = false; // Ensure loading state is set to false
        });
        return;
      }
      
      final data = appointmentDoc.data()!;
      
      // Create a structured map from the Firestore data
      Map<String, dynamic> appointmentDetails = {
        'id': appointmentDoc.id,
      };
      
      // Process all fields from the document, converting Timestamps to strings
      data.forEach((key, value) {
        if (value is Timestamp) {
          appointmentDetails[key] = value.toDate().toIso8601String();
        } else {
          appointmentDetails[key] = value;
        }
      });
      
      // Format date and time if not already handled
      if (data.containsKey('appointmentDate')) {
        if (data['appointmentDate'] is Timestamp) {
          appointmentDetails['appointmentDate'] = (data['appointmentDate'] as Timestamp).toDate().toIso8601String();
        } else {
          appointmentDetails['appointmentDate'] = data['appointmentDate'];
        }
      } else if (data.containsKey('date')) {
        if (data['date'] is Timestamp) {
          appointmentDetails['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
        } else {
          appointmentDetails['date'] = data['date'];
        }
      } else {
        appointmentDetails['date'] = "Unknown";
      }
      
      if (data.containsKey('time')) {
        appointmentDetails['time'] = data['time'];
      } else {
        appointmentDetails['time'] = "Unknown";
      }
      
      // Ensure hospital name is set
      if (!data.containsKey('hospitalName') || data['hospitalName'] == null || data['hospitalName'].toString().isEmpty) {
        if (data.containsKey('location') && data['location'] != null) {
          appointmentDetails['hospitalName'] = data['location'];
        } else {
          appointmentDetails['hospitalName'] = "Unknown Hospital";
        }
      }
      
      // Ensure doctor specialty is set
      if (!data.containsKey('specialty') && data.containsKey('doctorSpecialty')) {
        appointmentDetails['specialty'] = data['doctorSpecialty'];
      }
      
      // If isPanelConsultation exists, set type accordingly
      if (data.containsKey('isPanelConsultation')) {
        appointmentDetails['type'] = data['isPanelConsultation'] ? 'In-Person Visit' : 'Regular Consultation';
      }
      
      // Get doctor information if doctorId is available but name/specialty is missing
      // For patients (non-doctors), we want to always ensure doctorId is properly set
      if (data.containsKey('doctorId') && 
          (!_isDoctor || // Always try to ensure doctorId is valid for patients  
           !data.containsKey('doctorName') || data['doctorName'] == null || 
           !data.containsKey('specialty') || data['specialty'] == null)) {
        
        try {
          final doctorDoc = await firestore
              .collection('doctors')
              .doc(data['doctorId'])
              .get();
          
          if (doctorDoc.exists && doctorDoc.data() != null) {
            final doctorData = doctorDoc.data() as Map<String, dynamic>;
            
            // Ensure doctorId is correctly set in appointment details
            appointmentDetails['doctorId'] = doctorDoc.id;
            
            if (!data.containsKey('doctorName') || data['doctorName'] == null) {
              appointmentDetails['doctorName'] = doctorData['fullName'] ?? doctorData['name'] ?? "Unknown Doctor";
            }
            
            if (!data.containsKey('specialty') && !data.containsKey('doctorSpecialty')) {
              appointmentDetails['specialty'] = doctorData['specialty'] ?? "General";
            }
            
            // Get doctor profile image with improved validation
            if (doctorData.containsKey('profileImageUrl') && doctorData['profileImageUrl'] != null) {
              String imageUrl = doctorData['profileImageUrl'].toString();
              // Validate URL format
              if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
                appointmentDetails['doctorImage'] = imageUrl;
                
                // Also update the class variable for direct use
                _doctorImage = imageUrl;
                print('Found valid doctor image URL: $imageUrl');
              } else {
                print('Invalid doctor image URL format: $imageUrl');
              }
            } else {
              print('No doctor profile image URL found');
            }
          }
        } catch (e) {
          print('Error fetching doctor information: $e');
        }
      }
      // If we don't have doctorId but have doctorName, try to look up the doctor
      else if (!_isDoctor && (!data.containsKey('doctorId') || data['doctorId'] == null) && 
               data.containsKey('doctorName') && data['doctorName'] != null) {
        try {
          // Try to find doctor by name
          final doctorQuery = await firestore
              .collection('doctors')
              .where('fullName', isEqualTo: data['doctorName'])
              .limit(1)
              .get();
              
          if (doctorQuery.docs.isNotEmpty) {
            final doctorData = doctorQuery.docs.first.data();
            appointmentDetails['doctorId'] = doctorQuery.docs.first.id;
            
            if (!data.containsKey('specialty') && !data.containsKey('doctorSpecialty')) {
              appointmentDetails['specialty'] = doctorData['specialty'] ?? "General";
            }
            
            // Get doctor profile image with validation
            if (doctorData.containsKey('profileImageUrl') && doctorData['profileImageUrl'] != null) {
              String imageUrl = doctorData['profileImageUrl'].toString();
              // Validate URL format
              if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
                appointmentDetails['doctorImage'] = imageUrl;
                
                // Also update the class variable for direct use
                _doctorImage = imageUrl;
                print('Found valid doctor image URL from name lookup: $imageUrl');
              } else {
                print('Invalid doctor image URL format from name lookup: $imageUrl');
              }
            }
          }
        } catch (e) {
          print('Error looking up doctor by name: $e');
        }
      }
      
      // Get patient information if patientId is available but patient info is missing
      if (data.containsKey('patientId') && 
          (_isDoctor || // Always try to fetch patient data when viewing as a doctor
           !data.containsKey('patientName') || data['patientName'] == null || 
           !data.containsKey('patientPhone') || data['patientPhone'] == null)) {
        
        try {
          final patientDoc = await firestore
              .collection('patients')
              .doc(data['patientId'])
              .get();
          
          if (patientDoc.exists && patientDoc.data() != null) {
            final patientData = patientDoc.data() as Map<String, dynamic>;
            
            // Always update with the latest patient data when viewing as a doctor
            if (_isDoctor || !data.containsKey('patientName') || data['patientName'] == null) {
              appointmentDetails['patientName'] = patientData['fullName'] ?? patientData['name'] ?? "Unknown Patient";
            }
            
            if (_isDoctor || !data.containsKey('patientPhone') || data['patientPhone'] == null) {
              appointmentDetails['patientPhone'] = patientData['phone'] ?? patientData['phoneNumber'] ?? "No contact info";
            }
            
            // Get patient profile image with validation
            if (patientData.containsKey('profileImageUrl') && patientData['profileImageUrl'] != null) {
              String imageUrl = patientData['profileImageUrl'].toString().trim();
              // Validate URL format
              if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
                appointmentDetails['patientImageUrl'] = imageUrl;
                print('Found valid patient image URL: $imageUrl');
              } else if (patientData.containsKey('imageUrl') && 
                         patientData['imageUrl'] != null && 
                         patientData['imageUrl'].toString().isNotEmpty) {
                // Try fallback to imageUrl field
                String fallbackUrl = patientData['imageUrl'].toString().trim();
                if (fallbackUrl.startsWith('http://') || fallbackUrl.startsWith('https://')) {
                  appointmentDetails['patientImageUrl'] = fallbackUrl;
                  print('Found valid patient fallback image URL: $fallbackUrl');
                } else {
                  print('Invalid patient fallback image URL format: $fallbackUrl');
                }
              } else {
                print('Invalid patient image URL format: $imageUrl');
              }
            } else if (patientData.containsKey('imageUrl') && 
                       patientData['imageUrl'] != null && 
                       patientData['imageUrl'].toString().isNotEmpty) {
              // Try imageUrl field
              String imageUrl = patientData['imageUrl'].toString().trim();
              if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
                appointmentDetails['patientImageUrl'] = imageUrl;
                print('Using patient imageUrl field: $imageUrl');
              } else {
                print('Invalid patient image URL in imageUrl field: $imageUrl');
              }
            } else {
              print('No patient profile image URL found');
            }
          }
        } catch (e) {
          print('Error fetching patient information: $e');
        }
      }

      // Save to cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_appointmentDetailsCacheKey + widget.appointmentId!, json.encode(appointmentDetails));
      } catch (e) {
        print('Error saving to cache: $e');
      }
      
      if (!mounted) return;
      
      // Process the appointment details
      _processAppointmentDetails(appointmentDetails);
      
      setState(() {
        _isRefreshing = false;
        _isLoading = false; // Set loading to false after data is processed
      });
      
    } catch (e) {
      print('Error fetching appointment data: $e');
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _isLoading = false; // Ensure loading state is set to false even on error
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_isDoctor && !_isCancelled && _appointmentStatus.toLowerCase() == 'completed')
            IconButton(
              icon: Icon(LucideIcons.clipboard, color: Colors.white),
              tooltip: "Update Prescription",
              onPressed: _handlePrescription,
            ),
          IconButton(
            icon: Icon(LucideIcons.refreshCw, color: Colors.white),
            onPressed: _fetchAppointmentData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading appointment details...',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryTeal,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  if (_isDoctor)
                    Text(
                      'Setting up doctor view',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    )
                  else if (_isPatient)
                    Text(
                      'Setting up patient view',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    )
                  else
                    Text(
                      'Checking user role...',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppTheme.primaryTeal,
              onRefresh: () => _fetchAppointmentData(),
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateTimeHeader(),
                    Transform.translate(
                      offset: Offset(0, -25),
                      child: _buildAppointmentTimeSection(),
                    ),
                    Transform.translate(
                      offset: Offset(0, -15),
                      child: _isDoctor ? _buildPatientInfoSection() : _buildDoctorInfoSection(),
                    ),
                    _buildHospitalSection(),
                    _buildReasonSection(),
                    _buildPaymentSection(),
                    _buildAppointmentDetailsSection(),
                    
                    // Prescription section if available
                    _buildPrescriptionSection(),
                    
                    // Cancellation reason if cancelled
                    if (_isCancelled && _cancellationReason != null)
                      _buildCancellationSection(),
                    
                    // Action buttons based on status
                    _buildActionButtons(),
                    
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateTimeHeader() {
    final Color statusColor = _isCancelled
        ? AppTheme.error // Red for cancelled
        : AppTheme.primaryTeal; // Teal for all other statuses (both upcoming and completed)
    
    final String statusText = _appointmentStatus;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isCancelled 
              ? [AppTheme.error.withOpacity(0.8), AppTheme.error]
              : [AppTheme.primaryTeal.withOpacity(0.9), AppTheme.primaryTeal],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 60, 20, 50),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              statusText,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 20),
          
          // Add doctor image with proper error handling
          if (!_isDoctor) // Only show image for patient view
            Container(
              width: 75,
              height: 75,
              margin: EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: _doctorImage.startsWith('assets')
                  ? Image.asset(
                      _doctorImage,
                      fit: BoxFit.cover,
                      width: 75,
                      height: 75,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading doctor asset image: $error');
                        return Icon(
                          LucideIcons.user,
                          size: 35,
                          color: Colors.grey.shade400,
                        );
                      },
                    )
                  : Image.network(
                      _doctorImage,
                      fit: BoxFit.cover,
                      width: 75,
                      height: 75,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading doctor network image: $error');
                        // Schedule retry if it's a network error
                        _retryDoctorImageLoad();
                        return Icon(
                          LucideIcons.user,
                          size: 35,
                          color: Colors.grey.shade400,
                        );
                      },
                    ),
              ),
            ),
          
          Text(
            _isDoctor ? "Patient Appointment" : "Appointment with",
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _doctorName,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black12,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 5),
          Text(
            _doctorSpecialty,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  // Method to retry loading doctor image
  void _retryDoctorImageLoad() {
    if (_doctorImage.startsWith('assets')) return;
    
    // Add a small delay before retrying
    Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;
      
      // Try to fetch the doctor information again if we have doctorId
      if (_appointmentData.containsKey('doctorId') && _appointmentData['doctorId'] != null) {
        try {
          FirebaseFirestore.instance
              .collection('doctors')
              .doc(_appointmentData['doctorId'])
              .get()
              .then((doctorDoc) {
                if (doctorDoc.exists && doctorDoc.data() != null) {
                  final doctorData = doctorDoc.data()!;
                  
                  if (doctorData.containsKey('profileImageUrl') && 
                      doctorData['profileImageUrl'] != null && 
                      doctorData['profileImageUrl'].toString().isNotEmpty) {
                    
                    String imageUrl = doctorData['profileImageUrl'].toString();
                    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
                      setState(() {
                        _doctorImage = imageUrl;
                        print('Retried and found valid doctor image: $imageUrl');
                      });
                    }
                  }
                }
              });
        } catch (e) {
          print('Error in retry doctor image load: $e');
        }
      }
    });
  }

  Widget _buildAppointmentTimeSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTimeInfoItem(
            LucideIcons.calendar,
            "Date",
            _appointmentDate,
            AppTheme.primaryTeal,
          ),
          Container(
            height: 45,
            width: 1,
            color: Colors.grey.withOpacity(0.3),
          ),
          _buildTimeInfoItem(
            LucideIcons.clock,
            "Time",
            _appointmentTime,
            AppTheme.primaryTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfoItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
        SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorInfoSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
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
            child: CircleAvatar(
              radius: 35,
              backgroundImage: _getDoctorImageProvider(),
              backgroundColor: Colors.grey.shade200,
              onBackgroundImageError: (exception, stackTrace) {
                print('Error loading doctor image: $exception');
                // If network image fails, fall back to asset image
                setState(() {
                  _doctorImage = 'assets/images/User.png';
                });
              },
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Doctor Information",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  _doctorName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                  _doctorSpecialty,
                  style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryTeal,
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
    );
  }

  // Helper method to get doctor image provider with proper error handling
  ImageProvider _getDoctorImageProvider() {
    if (_doctorImage.startsWith('assets')) {
      return AssetImage(_doctorImage);
    } else {
      try {
        return NetworkImage(_doctorImage);
      } catch (e) {
        print('Error creating NetworkImage provider: $e');
        return AssetImage('assets/images/User.png');
      }
    }
  }

  Widget _buildPatientInfoSection() {
    bool isPatientDataLoading = _isRefreshing && (_appointmentData['patientName'] == null || _appointmentData['patientPhone'] == null);
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
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
            child: CircleAvatar(
              radius: 35,
              backgroundImage: _getPatientImageProvider(),
              backgroundColor: Colors.grey.shade200,
              onBackgroundImageError: (exception, stackTrace) {
                print('Error loading patient image: $exception');
                setState(() {
                  // Remove the problematic image URL
                  _appointmentData['patientImageUrl'] = '';
                });
              },
              child: (!_appointmentData.containsKey('patientImageUrl') || 
                     _appointmentData['patientImageUrl'] == null ||
                     _appointmentData['patientImageUrl'].toString().isEmpty)
                ? Icon(
                LucideIcons.user,
                    color: Colors.grey.shade500,
                    size: 28,
                  )
                : null,
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
              children: [
                Text(
                  "Patient Information",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                        ),
                        if (_isDoctor || !_appointmentData.containsKey('patientName') || 
                            _appointmentData['patientName'] == null || 
                            !_appointmentData.containsKey('patientPhone') || 
                            _appointmentData['patientPhone'] == null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: InkWell(
                              onTap: () async {
                                // Manually fetch patient information
                                if (_appointmentData['patientId'] != null) {
                                  try {
                                    setState(() {
                                      _isRefreshing = true;
                                    });
                                    
                                    final FirebaseFirestore firestore = FirebaseFirestore.instance;
                                    final patientDoc = await firestore
                                        .collection('patients')
                                        .doc(_appointmentData['patientId'])
                                        .get();
                                        
                                    if (patientDoc.exists && patientDoc.data() != null) {
                                      final patientData = patientDoc.data()!;
                                      
                                      setState(() {
                                        _appointmentData['patientName'] = patientData['fullName'] ?? patientData['name'] ?? 'Patient';
                                        _appointmentData['patientPhone'] = patientData['phone'] ?? patientData['phoneNumber'] ?? 'No contact info';
                                        _appointmentData['patientImageUrl'] = patientData['profileImageUrl'] ?? patientData['imageUrl'] ?? '';
                                        _isRefreshing = false;
                                      });
                                      
                                      // Show success message
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Patient information updated'),
                                          backgroundColor: AppTheme.primaryTeal,
                                        ),
                                      );
                                    } else {
                                      setState(() {
                                        _isRefreshing = false;
                                      });
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Patient information not found'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() {
                                      _isRefreshing = false;
                                    });
                                    
                                    print('Error fetching patient information: $e');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error fetching patient information'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryTeal.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.refreshCw,
                                  size: 14,
                                  color: AppTheme.primaryTeal,
                                ),
                              ),
                            ),
                          ),
                      ],
                ),
                SizedBox(height: 5),
                Text(
                  _appointmentData['patientName'] ?? "Patient",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      LucideIcons.phone,
                      size: 16,
                      color: AppTheme.primaryTeal,
                    ),
                    SizedBox(width: 6),
                    Text(
                      _appointmentData['patientPhone'] ?? "No contact info",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_appointmentData['patientId'] != null)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
              icon: Icon(
                LucideIcons.userSearch,
                color: AppTheme.primaryTeal,
                  size: 20,
              ),
              tooltip: "View Patient Profile",
              onPressed: () {
                // View patient profile logic
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Patient profile view will be added soon"),
                    backgroundColor: AppTheme.primaryTeal,
                  ),
                );
              },
                  ),
                ),
            ],
          ),
          if (isPatientDataLoading)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(15),
              ),
              width: double.infinity,
              height: 100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Loading patient data...",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // Helper method to get patient image provider with proper error handling
  ImageProvider? _getPatientImageProvider() {
    if (!_appointmentData.containsKey('patientImageUrl') || 
        _appointmentData['patientImageUrl'] == null ||
        _appointmentData['patientImageUrl'].toString().isEmpty) {
      return null;
    }
    
    try {
      String imageUrl = _appointmentData['patientImageUrl'].toString();
      // Retry loading if the URL doesn't start with http or https
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        print('Invalid patient image URL format: $imageUrl');
        return null;
      }
      return NetworkImage(imageUrl);
    } catch (e) {
      print('Error creating patient image provider: $e');
      return null;
    }
  }

  Widget _buildHospitalSection() {
    return _buildInfoSection(
      "Hospital Information",
      LucideIcons.building2,
      [
        _buildInfoRow(LucideIcons.building2, "Hospital Name", _hospitalName),
        _buildInfoRow(LucideIcons.bookmark, "Appointment Type", _appointmentType),
      ],
    );
  }

  Widget _buildReasonSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.clipboardList,
                  size: 18,
                  color: AppTheme.primaryTeal,
                ),
              ),
              SizedBox(width: 10),
              Text(
                "Reason for Visit",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: Text(
              _reason,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    // Determine payment status color
    Color statusColor;
    if (_paymentStatus.toLowerCase() == 'paid' || _paymentStatus.toLowerCase() == 'completed') {
      statusColor = AppTheme.primaryTeal;
    } else if (_paymentStatus.toLowerCase() == 'pending') {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }
    
    return _buildInfoSection(
      "Payment Information",
      LucideIcons.creditCard,
      [
        _buildInfoRow(LucideIcons.banknote, "Fee", _fee),
        _buildInfoRow(
          LucideIcons.wallet, 
          "Payment Method", 
          _paymentMethod,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.creditCard, 
                    size: 16, 
                    color: statusColor,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  "Payment Status:",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _paymentStatus,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            // Add update payment status button for doctors when status is pending
            if (_isDoctor && _paymentStatus.toLowerCase() == 'pending') 
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Center(
                  child: Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _updatePaymentStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        shadowColor: AppTheme.primaryTeal.withOpacity(0.4),
                      ),
                      icon: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.check, size: 16),
                      ),
                      label: Text(
                        "Mark Payment as Completed",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppointmentDetailsSection() {
    return _buildInfoSection(
      "Appointment Information",
      LucideIcons.fileText,
      [
        _buildInfoRow(LucideIcons.fileText, "Appointment ID", _appointmentId),
        _buildInfoRow(LucideIcons.tag, "Status", _appointmentStatus),
      ],
    );
  }

  Widget _buildCancellationSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.red.shade100,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade100.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
        border: Border.all(
          color: Colors.red.shade100,
                width: 1,
              ),
            ),
            child: Icon(
              LucideIcons.x, 
              color: Colors.red.shade700,
              size: 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cancellation Reason",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  _cancellationReason!,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.red.shade800,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // If appointment is already cancelled, show no buttons
    if (_isCancelled) {
      return SizedBox.shrink();
    }
    
    // Create a list of buttons to show
    List<Widget> buttons = [];
    
    // APPOINTMENT STATUS ACTIONS
    
    // For upcoming appointments
    if (_appointmentStatus.toLowerCase() == 'upcoming' || 
        _appointmentStatus.toLowerCase() == 'confirmed' ||
        _appointmentStatus.toLowerCase() == 'pending') {
      
      // Patient cancel button
      if (_isPatient) {
        buttons.add(
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showCancellationDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                shadowColor: Colors.red.shade200,
              ),
              icon: Icon(LucideIcons.trash, size: 18),
              label: Text(
                "Cancel Appointment",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        );
      }
      
      // Doctor actions
      if (_isDoctor) {
        buttons.add(
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _markAppointmentAsCompleted();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                shadowColor: AppTheme.primaryTeal.withOpacity(0.3),
              ),
              icon: Icon(LucideIcons.check, size: 18),
              label: Text(
                "Mark as Completed",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        );
      }
    }
    
    // For completed appointments
    if (_appointmentStatus.toLowerCase() == 'completed' && _isPatient) {
      buttons.add(_buildBookAgainButton());
    }
    
    // PRESCRIPTION ACTIONS - REGARDLESS OF STATUS
    
    // Prescription button (for doctors only) - shown for both upcoming and completed
    if (_isDoctor) {
      buttons.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _handlePrescription();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              shadowColor: AppTheme.primaryTeal.withOpacity(0.3),
            ),
            icon: Icon(LucideIcons.stethoscope, size: 18),
            label: Text(
              "Manage Prescription",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
      );
    }
    
    // View prescription button (for patients) - if prescription exists
    if (_isPatient && (_appointmentData.containsKey('prescription') || 
        (_appointmentData.containsKey('prescriptionImages') && 
         (_appointmentData['prescriptionImages'] as List?)?.isNotEmpty == true) ||
        (_appointmentData.containsKey('voiceNotes') && 
         (_appointmentData['voiceNotes'] as List?)?.isNotEmpty == true))) {
      buttons.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrescriptionViewScreen(
                    patientName: _appointmentData['patientName'] ?? 'Patient',
                    prescription: _appointmentData['prescription'],
                    prescriptionImages: _getExistingPrescriptionImages(),
                    prescriptionDate: _appointmentData.containsKey('prescriptionUpdatedAt') ? 
                        _formatPrescriptionDate(_appointmentData['prescriptionUpdatedAt']) : null,
                    voiceNotes: _getExistingVoiceNotes(),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              shadowColor: AppTheme.primaryTeal.withOpacity(0.3),
            ),
            icon: Icon(LucideIcons.fileText, size: 18),
            label: Text(
              "View Prescription",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
      );
    }
    
    // Chat button
    buttons.add(
      Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _handleChat,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryTeal,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            shadowColor: AppTheme.primaryTeal.withOpacity(0.3),
          ),
          icon: Icon(LucideIcons.messageSquare, size: 18),
          label: Text(
            _isDoctor ? "Chat with Patient" : "Chat with Doctor",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
    
    return Column(children: buttons);
  }

  Widget _buildBookAgainButton() {
    // Check if this is a past appointment
    if (_appointmentStatus.toLowerCase() == 'completed' || 
        _appointmentStatus.toLowerCase() == 'cancelled') {
      return Container(
        margin: EdgeInsets.fromLTRB(20, 10, 20, 0),
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            // Prepare doctor data for booking
            Map<String, dynamic> doctorData = {
              'id': _appointmentData['doctorId'],
              'name': _doctorName,
              'specialty': _doctorSpecialty,
              'profileImageUrl': _doctorImage.startsWith('assets') ? '' : _doctorImage,
            };
            
            // Navigate to booking flow with pre-selected doctor
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SimplifiedBookingFlow(
                  preSelectedDoctor: doctorData,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryTeal,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            shadowColor: AppTheme.primaryTeal.withOpacity(0.3),
          ),
          icon: Icon(LucideIcons.refreshCw, size: 18),
          label: Text(
            "Book Again",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildInfoSection(String title, IconData titleIcon, List<Widget> children) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  titleIcon,
                  size: 18,
                  color: AppTheme.primaryTeal,
                ),
              ),
              SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
              ),
            ],
          ),
          SizedBox(height: 15),
          ...children.map((child) => Padding(
            padding: EdgeInsets.only(bottom: 15),
            child: child,
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: Icon(
          icon, 
            size: 16, 
          color: AppTheme.primaryTeal,
          ),
        ),
        SizedBox(width: 10),
        Text(
          "$label:",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.mediumText,
          ),
        ),
        SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.darkText,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // Build prescription section if available
  Widget _buildPrescriptionSection() {
    final bool hasPrescription = _appointmentData.containsKey('prescription') && 
                                 _appointmentData['prescription'] != null &&
                                 _appointmentData['prescription'].toString().isNotEmpty;
    
    final bool hasPrescriptionImages = _appointmentData.containsKey('prescriptionImages') && 
                                       _appointmentData['prescriptionImages'] is List &&
                                       (_appointmentData['prescriptionImages'] as List).isNotEmpty;
    
    final bool hasVoiceNotes = _appointmentData.containsKey('voiceNotes') && 
                               _appointmentData['voiceNotes'] is List &&
                               (_appointmentData['voiceNotes'] as List).isNotEmpty;
    
    if (!hasPrescription && !hasPrescriptionImages && !hasVoiceNotes) {
      return SizedBox.shrink(); // No prescription available
    }
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 12,
            children: [
                // Title section
              Row(
                  mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                    LucideIcons.stethoscope,
                    color: AppTheme.primaryTeal,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Prescription",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
                
                // Actions section
              Row(
                  mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isDoctor && !_isCancelled && 
                      (_appointmentStatus.toLowerCase() == 'completed' || 
                       _appointmentStatus.toLowerCase() == 'confirmed' ||
                       _appointmentStatus.toLowerCase() == 'upcoming'))
                    Container(
                        margin: EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: _handlePrescription,
                        child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF3366CC).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        child: Row(
                              mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.pencil,
                              size: 14,
                              color: Color(0xFF3366CC),
                            ),
                            SizedBox(width: 4),
                            Text(
                              "Edit",
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                color: Color(0xFF3366CC),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      // View prescription details
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrescriptionViewScreen(
                            patientName: _appointmentData['patientName'] ?? 'Patient',
                            prescription: _appointmentData['prescription'],
                            prescriptionImages: _getExistingPrescriptionImages(),
                            prescriptionDate: _appointmentData.containsKey('prescriptionUpdatedAt') ? 
                                _formatPrescriptionDate(_appointmentData['prescriptionUpdatedAt']) : null,
                            voiceNotes: _getExistingVoiceNotes(),
                          ),
                        ),
                      );
                    },
                    child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF3366CC).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.eye,
                            size: 14,
                            color: Color(0xFF3366CC),
                          ),
                          SizedBox(width: 4),
                          Text(
                              "View",
                      style: GoogleFonts.poppins(
                              fontSize: 13,
                        color: Color(0xFF3366CC),
                        fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            ),
          ),
          if (hasPrescription) ...[
            SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Color(0xFFF5F7FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Text(
              _appointmentData['prescription'].toString(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                  height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (hasPrescriptionImages) ...[
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF5F7FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Row(
              children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          spreadRadius: 1,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                  LucideIcons.image,
                      size: 18,
                  color: Color(0xFF3366CC),
                ),
                  ),
                  SizedBox(width: 12),
                Text(
                  "${(_appointmentData['prescriptionImages'] as List).length} ${(_appointmentData['prescriptionImages'] as List).length == 1 ? 'image' : 'images'} attached",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                      fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
              ),
            ),
          ],
          if (hasVoiceNotes) ...[
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF5F7FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PrescriptionViewScreen(
                        patientName: _appointmentData['patientName'] ?? 'Patient',
                        prescription: _appointmentData['prescription'],
                        prescriptionImages: _getExistingPrescriptionImages(),
                        prescriptionDate: _appointmentData.containsKey('prescriptionUpdatedAt') ? 
                            _formatPrescriptionDate(_appointmentData['prescriptionUpdatedAt']) : null,
                        voiceNotes: _getExistingVoiceNotes(),
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            spreadRadius: 1,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        LucideIcons.mic,
                        size: 18,
                        color: Color(0xFF3366CC),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Voice Notes",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            "${(_appointmentData['voiceNotes'] as List?)?.length ?? 0} ${(_appointmentData['voiceNotes'] as List?)?.length == 1 ? 'voice note' : 'voice notes'} available",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_appointmentData.containsKey('prescriptionUpdatedAt')) ...[
            SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  LucideIcons.clock,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                SizedBox(width: 6),
            Text(
              "Last updated: ${_formatPrescriptionDate(_appointmentData['prescriptionUpdatedAt'])}",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  // Helper method to format prescription date
  String _formatPrescriptionDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      try {
        date = DateTime.parse(timestamp);
      } catch (e) {
        return 'Unknown';
      }
    } else {
      return 'Unknown';
    }
    
    return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
  }
  
  // Method to show cancellation dialog
  void _showCancellationDialog() {
    TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Cancel Appointment",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Are you sure you want to cancel this appointment?",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: "Reason for cancellation",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "Back",
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _cancelAppointment(reasonController.text);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Cancel Appointment",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Method to cancel appointment
  Future<void> _cancelAppointment(String reason) async {
    if (widget.appointmentId == null) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Update appointment status in Firestore
      await firestore.collection('appointments').doc(widget.appointmentId).update({
        'status': 'cancelled',
        'cancellationReason': reason.isEmpty ? 'No reason provided' : reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      // Refresh appointment data
      await _fetchAppointmentData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment cancelled successfully'),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );
    } catch (e) {
      print('Error cancelling appointment: $e');
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling appointment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Method to mark appointment as completed
  Future<void> _markAppointmentAsCompleted() async {
    if (widget.appointmentId == null) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Update appointment status in Firestore
      await firestore.collection('appointments').doc(widget.appointmentId).update({
        'status': 'completed',
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
      });
      
      // Refresh appointment data
      await _fetchAppointmentData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment marked as completed'),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );
    } catch (e) {
      print('Error marking appointment as completed: $e');
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking appointment as completed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Helper method to extract prescription images
  List<String> _getExistingPrescriptionImages() {
    if (_appointmentData.containsKey('prescriptionImages') && 
        _appointmentData['prescriptionImages'] is List &&
        (_appointmentData['prescriptionImages'] as List).isNotEmpty) {
      
      // Filter out any null or non-string values
      final List<String> validImages = (_appointmentData['prescriptionImages'] as List)
          .where((item) => item != null && item is String)
          .map((item) => item as String)
          .toList();
      
      // Filter out invalid URLs (optional additional validation)
      final List<String> validUrls = validImages
          .where((url) => url.startsWith('http://') || url.startsWith('https://'))
          .toList();
      
      return validUrls;
    }
    return [];
  }

  // Helper method to extract voice notes
  List<String> _getExistingVoiceNotes() {
    if (_appointmentData.containsKey('voiceNotes') && 
        _appointmentData['voiceNotes'] is List &&
        (_appointmentData['voiceNotes'] as List).isNotEmpty) {
      
      // Filter out any null or non-string values
      final List<String> validVoiceNotes = (_appointmentData['voiceNotes'] as List)
          .where((item) => item != null && item is String)
          .map((item) => item as String)
          .toList();
      
      // Filter out invalid URLs (optional additional validation)
      final List<String> validUrls = validVoiceNotes
          .where((url) => url.startsWith('http://') || url.startsWith('https://'))
          .toList();
      
      return validUrls;
    }
    return [];
  }

  // Method to handle prescription
  void _handlePrescription() async {
    // Only doctors can access this functionality
    if (!_isDoctor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only doctors can provide prescriptions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      // Check if we need to fetch more appointment data
      if ((_appointmentData['patientName'] == null || _appointmentData['patientPhone'] == null) && 
          _appointmentData['patientId'] != null) {
        final FirebaseFirestore firestore = FirebaseFirestore.instance;
        final patientDoc = await firestore
            .collection('patients')
            .doc(_appointmentData['patientId'])
            .get();
            
        if (patientDoc.exists && patientDoc.data() != null) {
          final patientData = patientDoc.data()!;
          
          // Update appointment data with patient information
          if (_appointmentData['patientName'] == null) {
            _appointmentData['patientName'] = patientData['fullName'] ?? patientData['name'] ?? 'Patient';
          }
          
          if (_appointmentData['patientPhone'] == null) {
            _appointmentData['patientPhone'] = patientData['phone'] ?? patientData['phoneNumber'] ?? 'No contact info';
          }
          
          if (_appointmentData['patientImageUrl'] == null) {
            _appointmentData['patientImageUrl'] = patientData['profileImageUrl'] ?? patientData['imageUrl'] ?? '';
          }
          
          // Update UI
          setState(() {});
        } else {
          _appointmentData['patientName'] = 'Patient';
          _appointmentData['patientPhone'] = 'No contact info';
        }
      }
      
      // Navigate to prescription screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrescriptionScreen(
            appointmentId: _appointmentId,
            patientName: _appointmentData['patientName'] ?? 'Patient',
            existingPrescription: _appointmentData['prescription'],
            existingPrescriptionImages: _getExistingPrescriptionImages(),
            existingVoiceNotes: _getExistingVoiceNotes(),
          ),
        ),
      );
      
      // If prescription was updated, refresh appointment data
      if (result == true) {
        _fetchAppointmentData();
      }
    } catch (e) {
      print('Error handling prescription: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to update payment status
  Future<void> _updatePaymentStatus() async {
    if (widget.appointmentId == null) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final String appointmentId = widget.appointmentId!;
      final Timestamp currentTimestamp = Timestamp.now();
      
      // Get current fee amount as a number
      double paymentAmount = 0;
      if (_fee.startsWith("Rs. ")) {
        // Parse from "Rs. 3000" format
        paymentAmount = double.tryParse(_fee.substring(4)) ?? 0;
      } else {
        // Try to parse any number from the fee string
        paymentAmount = double.tryParse(_fee.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      }
      
      // Update payment status in Firestore
      await firestore.collection('appointments').doc(appointmentId).update({
        'paymentStatus': 'Completed',
        'paymentUpdatedAt': currentTimestamp,
      });
      
      // Create transaction record
      await firestore.collection('transactions').add({
        'amount': paymentAmount,
        'appointmentId': appointmentId,
        'cardType': 'Cash/Manual Payment',
        'createdAt': currentTimestamp,
        'date': currentTimestamp,
        'description': 'Consultation with $_doctorName',
        'doctorId': _appointmentData['doctorId'] ?? '',
        'doctorName': _doctorName,
        'hospitalName': _hospitalName,
        'patientId': _appointmentData['patientId'] ?? '',
        'paymentMethod': 'Manual Payment',
        'status': 'completed',
        'title': 'Appointment Payment',
        'type': 'payment',
        'updatedAt': currentTimestamp,
        'userId': _appointmentData['patientId'] ?? '',
      });
      
      // Update local state
      setState(() {
        _paymentStatus = 'Completed';
      });
      
      // Refresh appointment data
      await _fetchAppointmentData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment status updated to Completed and transaction recorded'),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );
    } catch (e) {
      print('Error updating payment status: $e');
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating payment status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Method to handle chat
  Future<void> _handleChat() async {
    // For patients, always use the current user ID as the patientId
    if (!_isDoctor && _currentUserId.isNotEmpty) {
      _appointmentData['patientId'] = _currentUserId;
      print('Setting patient ID to current user: $_currentUserId');
    }
    
    // First attempt to retrieve missing IDs based on available data
    if (_appointmentData['doctorId'] == null && _doctorName != "Unknown Doctor" && !_isDoctor) {
      try {
        // Try to find the doctor by name
        final querySnapshot = await FirebaseFirestore.instance
            .collection('doctors')
            .where('fullName', isEqualTo: _doctorName)
            .limit(1)
            .get();
            
        if (querySnapshot.docs.isNotEmpty) {
          _appointmentData['doctorId'] = querySnapshot.docs.first.id;
        }
      } catch (e) {
        print('Error finding doctorId by name: $e');
      }
    }
    
    if (_appointmentData['patientId'] == null && _isDoctor) {
      // For doctors, this shouldn't normally happen but as a fallback
      // we can try to fetch appointment again to get patientId
      await _fetchAppointmentData();
    }
    
    // Check again after attempt to retrieve IDs
    if (_appointmentData['doctorId'] == null || _appointmentData['patientId'] == null) {
      // Log more details for debugging
      print('Missing chat information: doctorId=${_appointmentData['doctorId']}, patientId=${_appointmentData['patientId']}');
      print('Current user is doctor: $_isDoctor, Current user ID: $_currentUserId');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Missing doctor or patient information for chat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // Check if we need to fetch more user data
      if (_isDoctor && (_appointmentData['patientName'] == null || _appointmentData['patientImageUrl'] == null)) {
        // Fetch patient information
        try {
          final patientDoc = await FirebaseFirestore.instance
              .collection('patients')
              .doc(_appointmentData['patientId'])
              .get();
              
          if (patientDoc.exists && patientDoc.data() != null) {
            final patientData = patientDoc.data()!;
            
            _appointmentData['patientName'] = patientData['fullName'] ?? patientData['name'] ?? 'Patient';
            _appointmentData['patientImageUrl'] = patientData['profileImageUrl'] ?? patientData['imageUrl'] ?? '';
          }
        } catch (e) {
          print('Error fetching patient information: $e');
        }
      } else if (!_isDoctor && _doctorImage == 'assets/images/User.png') {
        // Fetch doctor information if needed
        try {
          final doctorDoc = await FirebaseFirestore.instance
              .collection('doctors')
              .doc(_appointmentData['doctorId'])
              .get();
              
          if (doctorDoc.exists && doctorDoc.data() != null) {
            final doctorData = doctorDoc.data()!;
            
            _doctorImage = doctorData['profileImageUrl'] ?? 'assets/images/User.png';
          }
        } catch (e) {
          print('Error fetching doctor information: $e');
        }
      }
      
      // Prepare parameters for chat
      final String doctorId = _isDoctor ? _currentUserId : _appointmentData['doctorId'];
      final String patientId = _isDoctor ? _appointmentData['patientId'] : _currentUserId;
      final String doctorProfilePic = _doctorImage.startsWith('assets') ? '' : _doctorImage;
      final String patientProfilePic = _appointmentData['patientImageUrl'] ?? '';
      
      print('Creating chat with doctorId: $doctorId, patientId: $patientId');
      
      // Check if a chat room already exists
      final chatService = ChatService();
      
      try {
        final existingChatRoom = await chatService.getChatRoom(doctorId, patientId);
        
        if (existingChatRoom != null) {
          // Use existing chat room
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                chatRoom: existingChatRoom,
                isDoctor: _isDoctor,
              ),
            ),
          );
          return;
        }
      } catch (e) {
        print('Error checking for existing chat room: $e');
        // Continue with creating a new room
      }
      
      // Show a snackbar to indicate that a new chat room will be created
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Creating a new chat room...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      
      // Create a new chat room
      final ChatRoom newChatRoom = await chatService.createChatRoom(
        doctorId: doctorId,
        patientId: patientId,
        doctorName: _doctorName,
        patientName: _appointmentData['patientName'] ?? 'Patient',
        doctorProfilePic: doctorProfilePic,
        patientProfilePic: patientProfilePic,
      );
      
      // Navigate to chat detail screen with the new chat room
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatRoom: newChatRoom,
              isDoctor: _isDoctor,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error handling chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }
}
