import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/views/screens/patient/appointment/payment_options.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Import for timer functionality
import 'package:healthcare/utils/app_theme.dart'; // Import AppTheme
import '../../../../widgets/firebase_cached_image.dart';

// Responsive utilities
class ResponsiveUtils {
  static bool isSmallScreen(BuildContext context) => MediaQuery.of(context).size.width < 600;
  static bool isMediumScreen(BuildContext context) => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
  static bool isLargeScreen(BuildContext context) => MediaQuery.of(context).size.width >= 900;
  
  static double getScreenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double getScreenHeight(BuildContext context) => MediaQuery.of(context).size.height;

  // Font size scaling based on screen width
  static double scaleFontSize(BuildContext context, double fontSize) {
    double width = getScreenWidth(context);
    if (width < 360) return fontSize * 0.8;
    if (width > 1200) return fontSize * 1.2;
    return fontSize;
  }
  
  // Padding scaling based on screen width
  static double scalePadding(BuildContext context, double padding) {
    double width = getScreenWidth(context);
    if (width < 360) return padding * 0.8;
    if (width > 900) return padding * 1.2;
    return padding;
  }
  
  // Icon size scaling based on screen width
  static double scaleIconSize(BuildContext context, double size) {
    double width = getScreenWidth(context);
    if (width < 360) return size * 0.8;
    if (width > 900) return size * 1.2;
    return size;
  }
  
  // Get responsive column count for grids
  static int getColumnCount(BuildContext context) {
    double width = getScreenWidth(context);
    if (width < 600) return 2;
    if (width < 900) return 3;
    return 4;
  }
}

class SimplifiedBookingFlow extends StatefulWidget {
  final String? specialty;
  final Map<String, dynamic>? preSelectedDoctor;
  
  const SimplifiedBookingFlow({
    super.key, 
    this.specialty,
    this.preSelectedDoctor,
  });

  @override
  _SimplifiedBookingFlowState createState() => _SimplifiedBookingFlowState();
}

class _SimplifiedBookingFlowState extends State<SimplifiedBookingFlow> with SingleTickerProviderStateMixin {
  // App colors - for patients, primary is teal and secondary is pink
  Color get primaryColor => AppTheme.primaryTeal;
  Color get primaryLightColor => AppTheme.lightTeal;
  Color get secondaryColor => AppTheme.primaryPink;
  Color get backgroundColor => AppTheme.background;
  Color get surfaceColor => Colors.white;
  Color get errorColor => AppTheme.error;
  Color get successColor => AppTheme.success;
  
  // Get primary gradient
  LinearGradient get primaryGradient => AppTheme.getPrimaryGradient();
  
  // Get shadow
  List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: primaryColor.withOpacity(0.08),
      blurRadius: 15,
      offset: Offset(0, 4),
      spreadRadius: 2,
    ),
  ];

  // Step tracking
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Doctor and Location Selection
  String? _selectedDoctor;
  String? _selectedLocation;
  String? _selectedHospitalId;
  List<Map<String, dynamic>> _doctorHospitals = [];
  Map<String, dynamic> _doctorData = {};
  
  // Date and Time Selection
  DateTime? _selectedDate;
  String? _selectedTime;
  List<String> _availableTimesForSelectedDate = [];
  Map<String, List<String>> _dateTimeSlots = {};
  bool _loadingTimeSlots = false;
  List<String> _bookedTimeSlots = [];
  
  // Review & Payment
  String? _selectedReason;
  final List<String> _appointmentReasons = [
    "Regular Checkup – باقاعدہ طبی معائنہ",
  "Follow-up Visit – بعد از ملاقات",
  "New Symptoms – نئی علامات",
  "Prescription Refill – نسخے کی تجدید",
  "Test Results Review – ٹیسٹ نتائج کا جائزہ",
  "Emergency Consultation – ہنگامی مشورہ"

  ];
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _animatingStep = false;
  
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    
    // Initialize doctor data if pre-selected
    if (widget.preSelectedDoctor != null) {
      _doctorData = widget.preSelectedDoctor!;
      _selectedDoctor = widget.preSelectedDoctor!['name'];
      
      // Fetch hospitals from doctor_hospitals collection
      if (widget.preSelectedDoctor!.containsKey('id')) {
        _fetchDoctorHospitals(widget.preSelectedDoctor!['id']);
      } else {
        debugPrint('Warning: Doctor ID not found in preSelectedDoctor data');
      }
    } else if (widget.specialty != null) {
      // If only specialty is provided, fetch doctors for that specialty
      _fetchDoctorsBySpecialty(widget.specialty!);
    } else {
      // Otherwise fetch all doctors
      _fetchAllDoctors();
    }
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Fetch doctors by specialty
  Future<void> _fetchDoctorsBySpecialty(String specialty) async {
    try {
      final QuerySnapshot doctorsSnapshot = await _firestore
          .collection('doctors')
          .where('specialty', isEqualTo: specialty)
          .where('isVerified', isEqualTo: true)
          .limit(1)
          .get();

      if (doctorsSnapshot.docs.isNotEmpty) {
        final doctorDoc = doctorsSnapshot.docs.first;
        final doctorData = doctorDoc.data() as Map<String, dynamic>;
        
        setState(() {
          _doctorData = {
            'id': doctorDoc.id,
            'name': doctorData['fullName'] ?? doctorData['name'] ?? 'Doctor',
            'specialty': doctorData['specialty'] ?? specialty,
            'profileImageUrl': doctorData['profileImageUrl'],
            'image': doctorData['image'],
            'fee': doctorData['fee'] ?? doctorData['consultationFee'] ?? 'Rs. 2000',
          };
          _selectedDoctor = _doctorData['name'];
        });
        
        // Fetch hospitals for this doctor
        _fetchDoctorHospitals(doctorDoc.id);
      }
    } catch (e) {
      debugPrint('Error fetching doctors by specialty: $e');
    }
  }

  // Fetch all available doctors
  Future<void> _fetchAllDoctors() async {
    try {
      final QuerySnapshot doctorsSnapshot = await _firestore
          .collection('doctors')
          .where('isVerified', isEqualTo: true)
          .limit(1)
          .get();
          
      if (doctorsSnapshot.docs.isNotEmpty) {
        final doctorDoc = doctorsSnapshot.docs.first;
        final doctorData = doctorDoc.data() as Map<String, dynamic>;
        
        setState(() {
          _doctorData = {
            'id': doctorDoc.id,
            'name': doctorData['fullName'] ?? doctorData['name'] ?? 'Doctor',
            'specialty': doctorData['specialty'] ?? doctorData['specialization'] ?? 'General Physician',
            'profileImageUrl': doctorData['profileImageUrl'],
            'image': doctorData['image'],
            'fee': doctorData['fee'] ?? doctorData['consultationFee'] ?? 'Rs. 2000',
          };
          _selectedDoctor = _doctorData['name'];
        });
        
        // Fetch hospitals for this doctor
        _fetchDoctorHospitals(doctorDoc.id);
      }
    } catch (e) {
      debugPrint('Error fetching doctors: $e');
    }
  }

  // Fetch hospitals for a specific doctor
  Future<void> _fetchDoctorHospitals(String doctorId) async {
    setState(() {
      _doctorHospitals = [];
    });
    
    try {
      // Get doctor hospitals from the doctor_hospitals collection
      final QuerySnapshot hospitalSnapshot = await _firestore
          .collection('doctor_hospitals')
          .where('doctorId', isEqualTo: doctorId)
          .get();
      
      if (hospitalSnapshot.docs.isEmpty) {
        debugPrint('No hospitals found for doctor $doctorId');
        return;
      }
      
      List<Map<String, dynamic>> hospitals = [];
      
      for (var doc in hospitalSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        hospitals.add({
          'id': data['hospitalId'] ?? '',
          'name': data['hospitalName'] ?? '',
          'city': data['city'] ?? '',
          'address': data['hospitalName'] ?? '', // Using hospitalName as address for now
        });
      }
      
      setState(() {
        _doctorHospitals = hospitals;
      });
    } catch (e) {
      debugPrint('Error fetching doctor hospitals: $e');
    }
  }

  // Fetch available time slots for a specific date and hospital
  Future<void> _fetchTimeSlotsForDate(String hospitalId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    debugPrint('⌚ Fetching time slots for date: $dateStr');
    debugPrint('🏥 Hospital ID: $hospitalId');
    
    setState(() {
      _loadingTimeSlots = true;
      _errorMessage = null;
    });
    
    try {
      final doctorId = widget.preSelectedDoctor != null 
          ? widget.preSelectedDoctor!['id']
          : _doctorData['id'];
      
      debugPrint('👨‍⚕️ Doctor ID: $doctorId');
      
      // Step 1: Fetch doctor's availability from doctor_availability collection
      final QuerySnapshot availabilitySnapshot = await _firestore
          .collection('doctor_availability')
          .where('doctorId', isEqualTo: doctorId)
          .where('hospitalId', isEqualTo: hospitalId)
          .where('date', isEqualTo: dateStr)
          .get();
      
      debugPrint('📝 Found ${availabilitySnapshot.docs.length} availability documents');
      
      // Initialize available time slots
      List<String> availableTimeSlots = [];
      
      if (availabilitySnapshot.docs.isNotEmpty) {
        // Specific date availability found
        final availabilityData = availabilitySnapshot.docs.first.data() as Map<String, dynamic>;
        debugPrint('📄 Availability data: $availabilityData');
        
        if (availabilityData.containsKey('timeSlots') && availabilityData['timeSlots'] is List) {
          availableTimeSlots = List<String>.from(availabilityData['timeSlots']);
          debugPrint('🕒 Raw time slots: $availableTimeSlots');
        }
      } else {
        // No specific date availability found
        debugPrint('No availability found for doctor $doctorId at hospital $hospitalId on date $dateStr');
        setState(() {
          _loadingTimeSlots = false;
          _availableTimesForSelectedDate = [];
        });
        return;
      }
      
      // If there are no time slots set for this date
      if (availableTimeSlots.isEmpty) {
        debugPrint('Doctor has no time slots available for date $dateStr');
        setState(() {
          _loadingTimeSlots = false;
          _availableTimesForSelectedDate = [];
        });
        return;
      }
      
      // Step 2: Get booked slots from appointments collection
      final QuerySnapshot appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: dateStr)
          .where('isBooked', isEqualTo: true)
          .get();
          
      debugPrint('🔒 Found ${appointmentsSnapshot.docs.length} booked appointments');
      
      List<String> bookedTimeSlots = [];
      
      for (var doc in appointmentsSnapshot.docs) {
        final appointmentData = doc.data() as Map<String, dynamic>;
        if (appointmentData['time'] != null && appointmentData['time'] is String) {
          bookedTimeSlots.add(appointmentData['time']);
          debugPrint('📅 Booked slot from appointments: ${appointmentData['time']}');
        }
      }
      
      // For backward compatibility, we'll also check appointments with status
      final QuerySnapshot pendingAppointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('hospitalId', isEqualTo: hospitalId)
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: dateStr)
          .where('status', whereIn: ['confirmed', 'pending_payment', 'In Progress'])
          .get();
      
      for (var doc in pendingAppointmentsSnapshot.docs) {
        final appointmentData = doc.data() as Map<String, dynamic>;
        if (appointmentData['time'] != null && appointmentData['time'] is String &&
            !bookedTimeSlots.contains(appointmentData['time'])) {
          bookedTimeSlots.add(appointmentData['time']);
          debugPrint('📅 Booked slot from appointments with status: ${appointmentData['time']}');
        }
      }
      
      // Filter out booked and past slots
      final now = DateTime.now();
      final bool isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      final TimeOfDay currentTime = TimeOfDay.fromDateTime(now);
      
      List<String> filteredTimeSlots = availableTimeSlots.where((timeSlot) {
        // Check if slot is booked
        if (bookedTimeSlots.contains(timeSlot)) {
          return false;
        }
        
        // If today, check if time has passed
        if (isToday) {
          final slotTime = _parseTimeOfDay(timeSlot);
          if (slotTime.hour < currentTime.hour || 
              (slotTime.hour == currentTime.hour && slotTime.minute <= currentTime.minute)) {
            return false;
          }
        }
        
        return true;
      }).toList();
      
      // Sort time slots
      filteredTimeSlots.sort((a, b) {
        final TimeOfDay timeA = _parseTimeOfDay(a);
        final TimeOfDay timeB = _parseTimeOfDay(b);
        
        if (timeA.hour != timeB.hour) {
          return timeA.hour - timeB.hour;
        }
        return timeA.minute - timeB.minute;
      });
      
      debugPrint('🕓 Available filtered time slots: $filteredTimeSlots');
      
      // Cache the results for this date and hospital
      _dateTimeSlots['${hospitalId}_$dateStr'] = filteredTimeSlots;
      
      setState(() {
        _loadingTimeSlots = false;
        _availableTimesForSelectedDate = filteredTimeSlots;
        _bookedTimeSlots = bookedTimeSlots;
      });
    } catch (e) {
      debugPrint('Error fetching time slots: $e');
      setState(() {
        _errorMessage = 'Failed to load available times. Please try again.';
        _loadingTimeSlots = false;
        _availableTimesForSelectedDate = [];
      });
    }
  }

  // Format TimeOfDay to string
  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt); // Format as "9:30 AM"
  }

  // Parse time string to TimeOfDay
  TimeOfDay _parseTimeOfDay(String timeString) {
    try {
      if (timeString.contains('AM') || timeString.contains('PM')) {
        final isPM = timeString.contains('PM');
        final timeParts = timeString.replaceAll(RegExp(r'[APM]'), '').trim().split(':');
        var hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        
        if (isPM && hour != 12) {
          hour += 12;
        } else if (!isPM && hour == 12) {
          hour = 0;
        }
        
        return TimeOfDay(hour: hour, minute: minute);
      } else {
        final timeParts = timeString.split(':');
        return TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      }
    } catch (e) {
      debugPrint('Error parsing time: $e');
      return TimeOfDay.now();
    }
  }

  // Process payment and create appointment
  Future<void> _processPayment() async {
    // Prevent multiple clicks
    if (_isLoading) {
      return;
    }
    
    if (_selectedDoctor == null || _selectedLocation == null || 
        _selectedDate == null || _selectedTime == null || 
        _selectedReason == null) {
      setState(() {
        _errorMessage = 'Please complete all required fields';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get doctor info
      final doctorId = widget.preSelectedDoctor != null ? widget.preSelectedDoctor!['id'] : _doctorData['id'];
      final hospitalId = _selectedHospitalId;
      final hospitalName = _selectedLocation;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      // Create appointment ID
      final appointmentId = FirebaseFirestore.instance.collection('appointments').doc().id;
      
      // Create a timestamp for payment expiration (15 minutes from now)
      final DateTime paymentExpirationTime = DateTime.now().add(Duration(minutes: 15));
      
      // Check if slot is available before proceeding
      final slotDoc = await _firestore.collection('appointments')
          .where('date', isEqualTo: dateStr)
          .where('time', isEqualTo: _selectedTime)
          .where('hospitalId', isEqualTo: hospitalId)
          .where('isBooked', isEqualTo: true)
          .get();
      
      if (slotDoc.docs.isNotEmpty) {
        setState(() {
          _errorMessage = 'This time slot has already been booked. Please select another time.';
          _isLoading = false;
        });
        return;
      }
      
      // Parse the appointment date time for better organization
      DateTime appointmentDateTime;
      try {
        // Convert time to 24-hour format for DateTime parsing
        String time24Format = _selectedTime!;
        if (_selectedTime!.contains('AM') || _selectedTime!.contains('PM')) {
          String timeStr = _selectedTime!.replaceAll(' AM', '').replaceAll(' PM', '');
          time24Format = timeStr;
          
          // Convert from 12-hour to 24-hour if PM and not 12
          if (_selectedTime!.contains('PM') && !timeStr.startsWith('12')) {
            final hour = int.parse(timeStr.split(':')[0]);
            time24Format = '${hour + 12}:${time24Format.split(':')[1]}';
          }
        } else {
          time24Format = _selectedTime!;
        }
        
        // Create DateTime object
        appointmentDateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$dateStr $time24Format');
        debugPrint('Set appointment date to: $appointmentDateTime');
      } catch (e) {
        debugPrint('Error parsing appointment date: $e');
        // Fallback to just using the date
        appointmentDateTime = _selectedDate!;
      }
      
      // Create a temporary appointment with pending_payment status and payment expiration
      await _firestore.collection('appointments').doc(appointmentId).set({
        'id': appointmentId,
        'patientId': _auth.currentUser!.uid,
        'doctorId': doctorId,
        'hospitalId': hospitalId,
        'hospitalName': hospitalName,
        'date': dateStr,
        'time': _selectedTime,
        'reason': _selectedReason,
        'status': 'pending_payment',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'doctorDetails': {
          'name': _doctorData['name'] ?? 'Doctor',
          'specialty': _doctorData['specialty'] ?? 'Specialist',
          'profileImageUrl': _doctorData['profileImageUrl'],
          'image': _doctorData['image'],
        },
        'fee': _doctorData['fee'] ?? 'Rs. 2000',
        'paymentStatus': 'pending',
        'notificationSent': false,
        'reminderSent': false,
        'notes': '',
        'cancellationReason': '',
        'isBooked': false, // Slot is temporarily held but not fully booked
        'appointmentDate': Timestamp.fromDate(appointmentDateTime),
        'bookingDate': FieldValue.serverTimestamp(),
        'hasFinancialTransaction': false,
        'paymentExpiresAt': Timestamp.fromDate(paymentExpirationTime), // Add expiration time
        'temporaryHold': true, // Flag to indicate this is a temporary hold
        'completed': false, // Boolean flag to indicate appointment completion status
      });

      debugPrint('Created temporary appointment with ID: $appointmentId');
      
      // Set up a Cloud Function trigger to automatically release the slot if payment is not completed
      // This is already handled by the Firestore payment expiration timestamp above
      // A Cloud Function would check for expired pending payments and release slots
      
      // Set up a background operation to track payment flow
      _trackPaymentProgress(appointmentId);

      // Navigate to payment screen after the current frame is rendered
      // This fixes the MediaQuery dependency error in PaymentMethodScreen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Builder(
                builder: (context) => PaymentMethodScreen(
                  appointmentDetails: {
                    'id': appointmentId,
                    'doctor': _selectedDoctor,
                    'hospital': _selectedLocation,
                    'date': dateStr,
                    'time': _selectedTime,
                    'fee': _doctorData['fee'] ?? 'Rs. 2000',
                    'doctorId': doctorId,
                    'hospitalId': hospitalId,
                    'paymentExpiresAt': paymentExpirationTime.millisecondsSinceEpoch, // Pass expiration time
                  },
                ),
              ),
            ),
          ).then((result) {
            // Reset loading state after returning from payment screen
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              
              // Handle return from payment screen
              _handlePaymentResult(result, appointmentId);
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error creating appointment: $e');
      setState(() {
        _errorMessage = 'Failed to process appointment. Please try again.';
        _isLoading = false;
      });
    }
  }
  
  // Track the payment progress for abandoned flows
  void _trackPaymentProgress(String appointmentId) {
    // Create a timer to check payment status after a delay
    // This is a client-side implementation to complement the server-side timeout
    Timer(Duration(minutes: 1), () async {
      if (!mounted) return; // Check if widget is still mounted
      
      try {
        // Check if the appointment still exists and is in pending_payment status
        final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
        
        if (appointmentDoc.exists) {
          final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
          final String status = appointmentData['status'] as String? ?? '';
          
          if (status == 'pending_payment') {
            debugPrint('Payment still pending for appointment $appointmentId after 1 minute');
            
            // You could implement a notification to remind the user to complete payment
            // This is optional and would depend on your UX requirements
          }
        }
      } catch (e) {
        debugPrint('Error checking payment status: $e');
      }
    });
  }
  
  // Handle the result returned from the payment screen
  void _handlePaymentResult(dynamic result, String appointmentId) {
    if (result == null) {
      // User navigated back without completing payment
      _checkAndReleaseSlot(appointmentId);
      return;
    }
    
    // Check if payment was successful based on the result
    if (result is Map<String, dynamic> && result['paymentCompleted'] == true) {
      // Payment completed successfully
      _showPaymentSuccessMessage();
    } else {
      // Payment was not completed
      _checkAndReleaseSlot(appointmentId);
    }
  }
  
  // Check and potentially release a slot if payment wasn't completed
  Future<void> _checkAndReleaseSlot(String appointmentId) async {
    try {
      // Ask user if they want to abandon the booking
      final bool shouldRelease = await _showAbandonPaymentDialog();
      
      if (shouldRelease) {
        // User confirmed they want to abandon, release the slot immediately
        await _firestore.collection('appointments').doc(appointmentId).update({
          'status': 'cancelled',
          'paymentStatus': 'cancelled',
          'temporaryHold': false,
          'cancellationReason': 'Payment abandoned by user',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking cancelled'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // User wants to keep the booking, provide a link back to payment
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Your slot is still on hold. Complete payment soon.'),
            action: SnackBarAction(
              label: 'Pay Now',
              onPressed: () => _resumePayment(appointmentId),
            ),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling abandoned payment: $e');
    }
  }
  
  // Show a dialog asking user if they want to abandon their booking
  Future<bool> _showAbandonPaymentDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Abandon Booking?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Your appointment slot will be held for 15 minutes. Would you like to cancel this booking or continue with payment later?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Keep the booking
              child: Text(
                'Keep Slot',
                style: GoogleFonts.poppins(
                  color: primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // Release the slot
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
              ),
              child: Text(
                'Cancel Booking',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
    
    return result ?? false; // Default to keeping the booking if dialog is dismissed
  }
  
  // Resume a payment flow
  void _resumePayment(String appointmentId) async {
    try {
      final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
      
      if (!appointmentDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This appointment is no longer available'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      
      // Check if the payment has expired
      final Timestamp? expiresAt = appointmentData['paymentExpiresAt'] as Timestamp?;
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This payment session has expired. Please book again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Continue with payment
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentMethodScreen(
            appointmentDetails: {
              'id': appointmentId,
              'doctor': appointmentData['doctorDetails']?['name'] ?? 'Doctor',
              'hospital': appointmentData['hospitalName'] ?? 'Hospital',
              'date': appointmentData['date'] ?? '',
              'time': appointmentData['time'] ?? '',
              'fee': appointmentData['fee'] ?? 'Rs. 2000',
              'doctorId': appointmentData['doctorId'] ?? '',
              'hospitalId': appointmentData['hospitalId'] ?? '',
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error resuming payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resume payment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Show payment success message
  void _showPaymentSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment completed successfully!'),
        backgroundColor: successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Build the steps for the stepper
  List<Step> _buildSteps() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return [
      Step(
        title: Text(
          'Doctor & Location',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 12 : 14,
          ),
        ),
        subtitle: _selectedDoctor != null && _selectedLocation != null
            ? Text(
                '$_selectedDoctor at $_selectedLocation',
                style: GoogleFonts.poppins(
                  fontSize: isSmallScreen ? 10 : 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        content: _buildDoctorLocationStep(),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text(
          'Date & Time',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 12 : 14,
          ),
        ),
        subtitle: _selectedDate != null && _selectedTime != null
            ? Text(
                '${DateFormat('MMM d').format(_selectedDate!)} at $_selectedTime',
                style: GoogleFonts.poppins(
                  fontSize: isSmallScreen ? 10 : 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        content: _buildDateTimeStep(),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text(
          'Review',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 12 : 14,
          ),
        ),
        content: _buildReviewStep(),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
    ];
  }

  // Build the doctor and location selection step
  Widget _buildDoctorLocationStep() {
    final bool isSmall = ResponsiveUtils.isSmallScreen(context);
    final double padding = ResponsiveUtils.scalePadding(context, isSmall ? 16 : 20);
    final double fontSize = ResponsiveUtils.scaleFontSize(context, isSmall ? 16 : 18);
    final double iconSize = ResponsiveUtils.scaleIconSize(context, isSmall ? 20 : 24);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with gradient accent
        Container(
          padding: EdgeInsets.only(left: ResponsiveUtils.scalePadding(context, 10)),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: primaryColor,
                width: 3,
              ),
            ),
          ),
          child: Text(
            'Select Hospital ہسپتال منتخب کریں',
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(height: padding * 0.8),
        
        // Doctor info card (if pre-selected)
        if (widget.preSelectedDoctor != null) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(padding * 0.7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEBF0FF),
                  Color(0xFFF5F8FF),
                ],
                stops: [0.0, 1.0],
              ),
              borderRadius: BorderRadius.circular(padding * 0.8),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.08),
                  blurRadius: 15,
                  offset: Offset(0, 4),
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: primaryColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Doctor image
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: (_doctorData.containsKey('profileImageUrl') && _doctorData['profileImageUrl'] != null)
                        ? FirebaseCachedImage(
                            imageUrl: _doctorData['profileImageUrl'],
                            fit: BoxFit.cover,
                          )
                        : (_doctorData.containsKey('image') && _doctorData['image'] != null)
                            ? FirebaseCachedImage(
                                imageUrl: _doctorData['image'],
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.person,
                                  color: Colors.grey.shade400,
                                  size: 30,
                                ),
                              ),
                  ),
                ),
                SizedBox(width: padding * 0.8),
                
                // Doctor info (name, specialty, stats)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                  children: [
                      // Doctor name and specialty
                    Text(
                      _doctorData['name'] ?? 'Doctor',
                      style: GoogleFonts.poppins(
                          fontSize: ResponsiveUtils.scaleFontSize(context, 16),
            fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: padding * 0.5,
                          vertical: padding * 0.2,
                        ),
                        decoration: BoxDecoration(
                          gradient: primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _doctorData['specialty'] ?? 'Specialist',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveUtils.scaleFontSize(context, 12),
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      
                      // Stats in a row
                      Row(
                        children: [
                          _buildCompactStat(
                            icon: Icons.medical_services_rounded, 
                            value: _doctorData['experience']?.toString() ?? '0',
                            suffix: ' yrs',
                            iconColor: secondaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Fee
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: padding * 0.5,
                    vertical: padding * 0.3,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rs ' + (_doctorData['fee']?.toString() ?? '0'),
                    style: GoogleFonts.poppins(
                          fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                      Text(
                        'Fee',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveUtils.scaleFontSize(context, 10),
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: padding * 0.6),
        ],
        
        // Hospital selection
        if (_doctorHospitals.isEmpty)
          Center(
            child: Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    MdiIcons.hospitalBuilding,
                    color: Colors.grey.shade400,
                    size: iconSize * 2,
                  ),
                  SizedBox(height: 16),
                  Text(
              'No locations available',
              style: GoogleFonts.poppins(
                      fontSize: ResponsiveUtils.scaleFontSize(context, 16),
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please try again later or contact support',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                      color: Colors.grey[500],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              // For wider screens, show locations in a grid
              if (constraints.maxWidth > 600) {
                return GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: ResponsiveUtils.getColumnCount(context),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
            itemCount: _doctorHospitals.length,
                  itemBuilder: (context, index) => _buildHospitalCard(
                    hospital: _doctorHospitals[index],
                    isGridView: true,
                  ),
                );
              } else {
                // For smaller screens, show in a list
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _doctorHospitals.length,
                  itemBuilder: (context, index) => _buildHospitalCard(
                    hospital: _doctorHospitals[index],
                    isGridView: false,
                  ),
                );
              }
            },
          ),
      ],
    );
  }
  
  // Extract hospital card widget for better reuse in list and grid views
  Widget _buildHospitalCard({required Map<String, dynamic> hospital, required bool isGridView}) {
              final hospitalId = hospital['id']?.toString() ?? '';
              final hospitalName = hospital['name']?.toString() ?? '';
              final hospitalAddress = hospital['address']?.toString();
              final isSelected = hospitalId == _selectedHospitalId;
    final double iconSize = ResponsiveUtils.scaleIconSize(context, 24);
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: isGridView ? 0 : 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? primaryColor : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected 
                ? primaryColor.withOpacity(0.15)
                : Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
            spreadRadius: isSelected ? 2 : 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () {
                    if (hospitalId.isNotEmpty && hospitalName.isNotEmpty) {
                      setState(() {
                        _selectedHospitalId = hospitalId;
                        _selectedLocation = hospitalName;
                      });
                      
                      if (_isStepValid()) {
                        _animateToStep(_currentStep + 1);
                      }
                    }
                  },
          borderRadius: BorderRadius.circular(14),
                  child: Padding(
            padding: EdgeInsets.all(ResponsiveUtils.scalePadding(context, 16)),
            child: isGridView 
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                        padding: EdgeInsets.all(ResponsiveUtils.scalePadding(context, 12)),
                          decoration: BoxDecoration(
                          gradient: isSelected 
                              ? primaryGradient
                              : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey.shade100,
                                    Colors.grey.shade200,
                                  ],
                                ),
                          shape: BoxShape.circle,
                          boxShadow: isSelected 
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ]
                              : null,
                          ),
                          child: Icon(
                            MdiIcons.hospitalBuilding,
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                          size: iconSize,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        hospitalName,
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveUtils.scaleFontSize(context, 16),
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hospitalAddress != null && hospitalAddress.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: ResponsiveUtils.scaleIconSize(context, 14),
                              color: isSelected ? primaryColor : Colors.grey.shade600,
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                hospitalAddress,
                                style: GoogleFonts.poppins(
                                  fontSize: ResponsiveUtils.scaleFontSize(context, 12),
                                  color: isSelected ? primaryColor : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 10),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? primaryColor : Colors.grey.shade200,
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(ResponsiveUtils.scalePadding(context, 12)),
                        decoration: BoxDecoration(
                          gradient: isSelected 
                              ? primaryGradient
                              : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey.shade100,
                                    Colors.grey.shade200,
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isSelected 
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          MdiIcons.hospitalBuilding,
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                          size: iconSize,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hospitalName,
                                style: GoogleFonts.poppins(
                                fontSize: ResponsiveUtils.scaleFontSize(context, 16),
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                ),
                              ),
                              if (hospitalAddress != null && hospitalAddress.isNotEmpty) ...[
                                SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: ResponsiveUtils.scaleIconSize(context, 14),
                                    color: isSelected ? primaryColor : Colors.grey.shade600,
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                  hospitalAddress,
                                  style: GoogleFonts.poppins(
                                        fontSize: ResponsiveUtils.scaleFontSize(context, 13),
                                        color: isSelected ? primaryColor : Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? primaryColor : Colors.grey.shade200,
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                          ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  // Build the date and time selection step
  Widget _buildDateTimeStep() {
    final bool isSmall = ResponsiveUtils.isSmallScreen(context);
    final double padding = ResponsiveUtils.scalePadding(context, isSmall ? 16 : 20);
    final double fontSize = ResponsiveUtils.scaleFontSize(context, isSmall ? 16 : 18);
    final double iconSize = ResponsiveUtils.scaleIconSize(context, isSmall ? 20 : 24);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with gradient accent
        Container(
          padding: EdgeInsets.only(left: ResponsiveUtils.scalePadding(context, 10)),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: primaryColor,
                width: 3,
              ),
            ),
          ),
          child: Text(
          'Select Date تاریخ منتخب کریں',
          style: GoogleFonts.poppins(
              fontSize: fontSize,
            fontWeight: FontWeight.w600,
              color: Colors.black87,
          ),
        ),
        ),
        SizedBox(height: padding * 0.8),
        
        // Premium calendar
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.08),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          // Set a fixed height constraint to ensure the calendar doesn't expand too much
          constraints: BoxConstraints(
            maxHeight: ResponsiveUtils.getScreenHeight(context) * 0.45,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
          child: TableCalendar(
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(Duration(days: 90)),
            focusedDay: _selectedDate ?? DateTime.now(),
            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = selectedDay;
                _selectedTime = null;
              });
              
              if (_selectedHospitalId != null) {
                _fetchTimeSlotsForDate(_selectedHospitalId!, selectedDay);
              }
            },
              // Prevent calendar from capturing scroll events
              pageJumpingEnabled: false,
              // Use a fixed height to prevent scrolling issues
              rowHeight: 48,
              // Disable any gestures in the calendar that interfere with page scrolling
              calendarBuilders: CalendarBuilders(),
              // Disable page navigation through swipe to prevent interference with parent scrolling
              availableGestures: AvailableGestures.none,
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                  gradient: primaryGradient,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
                outsideDaysVisible: false,
                // Adjust text sizes based on screen size
                defaultTextStyle: GoogleFonts.poppins(
                  fontSize: ResponsiveUtils.scaleFontSize(context, isSmall ? 13 : 14)
                ),
                weekendTextStyle: GoogleFonts.poppins(
                  fontSize: ResponsiveUtils.scaleFontSize(context, isSmall ? 13 : 14),
                  color: Colors.black87
                ),
                selectedTextStyle: GoogleFonts.poppins(
                  fontSize: ResponsiveUtils.scaleFontSize(context, isSmall ? 13 : 14),
                  color: Colors.white,
                  fontWeight: FontWeight.bold
                ),
                todayTextStyle: GoogleFonts.poppins(
                  fontSize: ResponsiveUtils.scaleFontSize(context, isSmall ? 13 : 14),
                  color: primaryColor,
                  fontWeight: FontWeight.bold
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
                titleTextStyle: GoogleFonts.poppins(
                  fontSize: ResponsiveUtils.scaleFontSize(context, isSmall ? 16 : 18),
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: primaryColor),
                rightChevronIcon: Icon(Icons.chevron_right, color: primaryColor),
                headerPadding: EdgeInsets.symmetric(vertical: ResponsiveUtils.scalePadding(context, 16)),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.05),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                ),
            ),
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
            },
            calendarFormat: CalendarFormat.month,
            onFormatChanged: (format) {
              // Not used but required by the widget
            },
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: GoogleFonts.poppins(
                  fontSize: ResponsiveUtils.scaleFontSize(context, isSmall ? 12 : 13),
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                weekendStyle: GoogleFonts.poppins(
                  fontSize: ResponsiveUtils.scaleFontSize(context, isSmall ? 12 : 13),
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.03),
                ),
              ),
            ),
          ),
        ),
        
        SizedBox(height: padding * 1.2),
        
        // Time slot section
        Container(
          padding: EdgeInsets.only(left: ResponsiveUtils.scalePadding(context, 10)),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: primaryColor,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
        Text(
          'Select Time وقت منتخب کریں',
          style: GoogleFonts.poppins(
                  fontSize: fontSize,
            fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (_selectedDate != null) ...[
                SizedBox(width: 10),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('MMM d').format(_selectedDate!),
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveUtils.scaleFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: padding * 0.8),
        
        // Time slots
        if (_loadingTimeSlots)
          _buildLoadingTimeSlots(padding, fontSize)
        else if (_selectedDate == null)
          _buildNoDateSelected(padding, fontSize, iconSize)
        else if (_availableTimesForSelectedDate.isEmpty)
          _buildNoTimeSlotsAvailable(padding, fontSize, iconSize)
        else
          _buildAvailableTimeSlots(padding, fontSize),
      ],
    );
  }
  
  // Loading time slots widget
  Widget _buildLoadingTimeSlots(double padding, double fontSize) {
    return Center(
      child: Column(
        children: [
          SizedBox(height: padding),
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  strokeWidth: 3,
                ),
                SizedBox(height: padding * 0.8),
                Text(
                  'Loading available time slots...',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // No date selected widget
  Widget _buildNoDateSelected(double padding, double fontSize, double iconSize) {
    return Center(
            child: Container(
        margin: EdgeInsets.only(top: padding),
        padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
            Container(
              padding: EdgeInsets.all(padding * 0.8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                    Icons.calendar_today,
                color: primaryColor.withOpacity(0.7),
                size: iconSize * 1.5,
                  ),
            ),
            SizedBox(height: padding * 0.8),
                  Text(
                    'Please select a date first',
                    style: GoogleFonts.poppins(
                fontSize: fontSize * 0.9,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: padding * 0.4),
            Text(
              'Available time slots will appear here',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                      color: Colors.grey.shade600,
                    ),
              textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
  
  // No time slots available widget
  Widget _buildNoTimeSlotsAvailable(double padding, double fontSize, double iconSize) {
    final bool isSmall = ResponsiveUtils.isSmallScreen(context);
    
    return Center(
            child: Container(
        margin: EdgeInsets.only(top: padding),
        padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
              ),
              child: Column(
                children: [
            Container(
              padding: EdgeInsets.all(padding * 0.8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                    Icons.event_busy,
                color: Colors.orange,
                size: iconSize * 1.5,
                  ),
            ),
            SizedBox(height: padding),
                  Text(
                    'No slots available',
                    style: GoogleFonts.poppins(
                fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
            SizedBox(height: padding * 0.6),
                  Text(
                    'The doctor is not available on this date.\nPlease try another date or hospital.',
                    style: GoogleFonts.poppins(
                fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
            SizedBox(height: padding),
            LayoutBuilder(
              builder: (context, constraints) {
                // For smaller screens, stack buttons vertically
                if (constraints.maxWidth < 400 || isSmall) {
                  return Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_selectedDate != null && _selectedDate!.add(Duration(days: 1)).isAfter(DateTime.now())) {
                            final nextDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day + 1);
                            setState(() {
                              _selectedDate = nextDay;
                            });
                            if (_selectedHospitalId != null) {
                              _fetchTimeSlotsForDate(_selectedHospitalId!, nextDay);
                            }
                          }
                        },
                        icon: Icon(Icons.arrow_forward, size: ResponsiveUtils.scaleIconSize(context, 18)),
                        label: Text('Try Next Day'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: padding * 0.8, 
                            vertical: padding * 0.6
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                      SizedBox(height: padding * 0.6),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Go back to first step to select another hospital
                          _animateToStep(0);
                        },
                        icon: Icon(Icons.local_hospital, size: ResponsiveUtils.scaleIconSize(context, 18)),
                        label: Text('Try Another Hospital'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          padding: EdgeInsets.symmetric(
                            horizontal: padding * 0.8, 
                            vertical: padding * 0.6
                          ),
                          side: BorderSide(color: primaryColor, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // For larger screens, use a row
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_selectedDate != null && _selectedDate!.add(Duration(days: 1)).isAfter(DateTime.now())) {
                            final nextDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day + 1);
                            setState(() {
                              _selectedDate = nextDay;
                            });
                            if (_selectedHospitalId != null) {
                              _fetchTimeSlotsForDate(_selectedHospitalId!, nextDay);
                            }
                          }
                        },
                        icon: Icon(Icons.arrow_forward, size: ResponsiveUtils.scaleIconSize(context, 18)),
                        label: Text('Try Next Day'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: padding * 0.8, 
                            vertical: padding * 0.6
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                      SizedBox(width: padding * 0.8),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Go back to first step to select another hospital
                          _animateToStep(0);
                        },
                        icon: Icon(Icons.local_hospital, size: ResponsiveUtils.scaleIconSize(context, 18)),
                        label: Text('Try Another Hospital'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          padding: EdgeInsets.symmetric(
                            horizontal: padding * 0.8, 
                            vertical: padding * 0.6
                          ),
                          side: BorderSide(color: primaryColor, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            SizedBox(height: padding * 0.8),
            Container(
              padding: EdgeInsets.all(padding * 0.6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.support_agent,
                    color: primaryColor,
                    size: iconSize,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                    'Need help? Call our support team at +92-300-1234567',
                    style: GoogleFonts.poppins(
                        fontSize: ResponsiveUtils.scaleFontSize(context, 12),
                        color: Colors.grey.shade700,
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
  
  // Available time slots widget
  Widget _buildAvailableTimeSlots(double padding, double fontSize) {
    return Container(
      margin: EdgeInsets.only(top: padding * 0.5),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Time Slots دستیاب وقت کے اوقات',
            style: GoogleFonts.poppins(
              fontSize: fontSize * 0.9,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: padding * 0.8),
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate optimal item count per row based on width
              int itemsPerRow = (constraints.maxWidth / 100).floor();
              itemsPerRow = itemsPerRow < 2 ? 2 : (itemsPerRow > 5 ? 5 : itemsPerRow);
              
              // Calculate spacing
              double spacing = ResponsiveUtils.scalePadding(context, 10);
              
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
            children: _availableTimesForSelectedDate.map((time) {
              final isSelected = time == _selectedTime;
              
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedTime = time;
                  });
                  
                  if (_isStepValid()) {
                    _animateToStep(_currentStep + 1);
                  }
                },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.scalePadding(context, 16),
                        vertical: ResponsiveUtils.scalePadding(context, 10),
                  ),
                      width: (constraints.maxWidth - (spacing * (itemsPerRow - 1))) / itemsPerRow,
                  decoration: BoxDecoration(
                        gradient: isSelected ? primaryGradient : null,
                        color: isSelected ? null : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                          color: isSelected ? Colors.transparent : Colors.grey.shade300,
                          width: 1.5,
                    ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                  ),
                        ] : null,
                      ),
                      child: Center(
                  child: Text(
                    time,
                    style: GoogleFonts.poppins(
                            fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }).toList(),
              );
            },
          ),
          
          SizedBox(height: padding * 0.8),
          Row(
            children: [
              Icon(Icons.info_outline, size: ResponsiveUtils.scaleIconSize(context, 16), color: Colors.grey.shade600),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Select a time slot that works best for you.',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveUtils.scaleFontSize(context, 12),
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build the review and payment step
  Widget _buildReviewStep() {
    final bool isSmall = ResponsiveUtils.isSmallScreen(context);
    final double padding = ResponsiveUtils.scalePadding(context, isSmall ? 16 : 20);
    final double fontSize = ResponsiveUtils.scaleFontSize(context, isSmall ? 16 : 18);
    final double iconSize = ResponsiveUtils.scaleIconSize(context, isSmall ? 20 : 24);
    
    // Don't build the review step if required data is missing
    if (_selectedDoctor == null || _selectedLocation == null || 
        _selectedDate == null || _selectedTime == null) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: iconSize * 2,
              ),
              SizedBox(height: padding * 0.8),
              Text(
          'Please complete previous steps first',
          style: GoogleFonts.poppins(
                  fontSize: fontSize * 0.9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: padding * 0.4),
              Text(
                'Go back and select doctor, location, date and time',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with gradient accent
        Container(
          padding: EdgeInsets.only(left: ResponsiveUtils.scalePadding(context, 10)),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: primaryColor,
                width: 3,
              ),
            ),
          ),
          child: Text(
          'Appointment Summary ملاقات کا خلاصہ',
          style: GoogleFonts.poppins(
              fontSize: fontSize,
            fontWeight: FontWeight.w600,
              color: Colors.black87,
          ),
        ),
        ),
        SizedBox(height: padding * 0.8),
        
        // Summary card
        Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.08),
                blurRadius: 15,
                offset: Offset(0, 5),
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: primaryColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: padding * 0.8),
                decoration: BoxDecoration(
                  gradient: primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Booking Details',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveUtils.scaleFontSize(context, 16),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Verify your appointment information',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveUtils.scaleFontSize(context, 12),
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: padding),
              
              // Doctor info
              _buildSummaryItem(
                icon: MdiIcons.doctor,
                title: 'Doctor',
                value: _selectedDoctor!,
                subtitle: _doctorData['specialty'] ?? 'Specialist',
              ),
              Divider(height: padding * 1.2, color: Colors.grey.shade200),
              
              // Location
              _buildSummaryItem(
                icon: MdiIcons.hospitalBuilding,
                title: 'Location',
                value: _selectedLocation!,
              ),
              Divider(height: padding * 1.2, color: Colors.grey.shade200),
              
              // Date & Time
              _buildSummaryItem(
                icon: MdiIcons.calendar,
                title: 'Date & Time',
                value: DateFormat('EEEE, MMMM d').format(_selectedDate!),
                subtitle: 'at $_selectedTime',
              ),
              
              if (_doctorData.containsKey('fee') && _doctorData['fee'] != null) ...[
                Divider(height: padding * 1.2, color: Colors.grey.shade200),
                // Fee
                _buildSummaryItem(
                  icon: MdiIcons.cash,
                  title: 'Consultation Fee',
                  value: _doctorData['fee'],
                  isHighlighted: true,
                ),
              ],
            ],
          ),
        ),
        
        SizedBox(height: padding * 1.2),
        
        // Reason section
        Container(
          padding: EdgeInsets.only(left: ResponsiveUtils.scalePadding(context, 10)),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: primaryColor,
                width: 3,
              ),
            ),
          ),
          child: Text(
          'Reason for Visit ملاقات کا وجہ',
          style: GoogleFonts.poppins(
              fontSize: fontSize,
            fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(height: padding * 0.8),
        
        Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select your primary reason for this appointment:',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: padding * 0.8),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: ResponsiveUtils.scalePadding(context, 12),
                    runSpacing: ResponsiveUtils.scalePadding(context, 12),
          children: _appointmentReasons.map((reason) {
            final isSelected = reason == _selectedReason;
            
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        child: InkWell(
              onTap: () {
                setState(() {
                  _selectedReason = reason;
                });
              },
                          borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.scalePadding(context, 16),
                              vertical: ResponsiveUtils.scalePadding(context, 10),
                ),
                decoration: BoxDecoration(
                              gradient: isSelected ? primaryGradient : null,
                              color: isSelected ? null : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                                color: isSelected ? Colors.transparent : Colors.grey.shade300,
                                width: 1.5,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ] : null,
                ),
                child: Text(
                  reason,
                  style: GoogleFonts.poppins(
                                fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                              ),
                  ),
                ),
              ),
            );
          }).toList(),
                  );
                }
              ),
              
              if (_selectedReason == null) ...[
                SizedBox(height: padding * 0.8),
                Container(
                  padding: EdgeInsets.all(padding * 0.6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.amber.shade800,
                        size: iconSize,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Please select a reason to continue',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        
        SizedBox(height: padding * 1.2),
        
        // Final notes
        Container(
          padding: EdgeInsets.all(padding * 0.8),
          decoration: BoxDecoration(
            color: successColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user,
                color: successColor,
                size: iconSize,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Almost Done!',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveUtils.scaleFontSize(context, 16),
                        fontWeight: FontWeight.w600,
                        color: successColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Please review all details before proceeding to payment. You\'ll receive a confirmation after successful payment.',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Enhanced summary item widget
  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    bool isHighlighted = false,
  }) {
    final bool isSmall = ResponsiveUtils.isSmallScreen(context);
    final double iconSize = ResponsiveUtils.scaleIconSize(context, isSmall ? 20 : 22);
    
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(ResponsiveUtils.scalePadding(context, 12)),
          decoration: BoxDecoration(
            color: isHighlighted 
                ? primaryColor
                : primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isHighlighted ? [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ] : null,
          ),
          child: Icon(
            icon,
            color: isHighlighted ? Colors.white : primaryColor,
            size: iconSize,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveUtils.scaleFontSize(context, 16),
                  fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
                  color: isHighlighted ? primaryColor : Colors.black87,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Validate current step
  bool _isStepValid() {
    switch (_currentStep) {
      case 0:
        return _selectedDoctor != null && _selectedLocation != null;
      case 1:
        return _selectedDate != null && _selectedTime != null;
      case 2:
        return _selectedReason != null;
      default:
        return false;
    }
  }

  // Check if we can navigate to a step
  bool _canNavigateToStep(int step) {
    // Can always go back
    if (step < _currentStep) return true;
    
    // Check all previous steps are complete
    for (int i = 0; i < step; i++) {
      if (!_isStepValid()) return false;
    }
    
    return true;
  }

  // Animate to next/previous step
  void _animateToStep(int step) {
    if (_currentStep == step || _animatingStep) return;
    
    // Don't allow navigation to future steps if current step is not valid
    if (step > _currentStep && !_canNavigateToStep(step)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete the current step first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _animatingStep = true;
    });
    
    _animationController.reverse().then((_) {
      setState(() {
        _currentStep = step;
        _errorMessage = null;
      });
      
      _animationController.forward().then((_) {
        setState(() {
          _animatingStep = false;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSmall = ResponsiveUtils.isSmallScreen(context);
    final double screenWidth = ResponsiveUtils.getScreenWidth(context);
    final double horizontalPadding = ResponsiveUtils.scalePadding(context, 16);
    final double verticalPadding = ResponsiveUtils.scalePadding(context, isSmall ? 12 : 16);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: Text(
          'Book Appointment',
          style: GoogleFonts.poppins(
            fontSize: ResponsiveUtils.scaleFontSize(context, 20),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new, 
            color: primaryColor, 
            size: ResponsiveUtils.scaleIconSize(context, 20)
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.help_outline, 
              color: primaryColor, 
              size: ResponsiveUtils.scaleIconSize(context, 22)
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Help information will be displayed here',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                    ),
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // For tablet and larger screens, constrain the width to avoid stretching too much
          if (constraints.maxWidth >= 600) {
            return Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 800),
                child: _buildMainContent(context),
              ),
            );
          }
          // For smaller screens, use the full width
          return _buildMainContent(context);
        }
      ),
    );
  }
  
  // Extract the main content to a separate method
  Widget _buildMainContent(BuildContext context) {
    final double horizontalPadding = ResponsiveUtils.scalePadding(context, 16);
    final double verticalPadding = ResponsiveUtils.scalePadding(context, 16);
    
    return Column(
        children: [
        // Enhanced stepper header
          Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding, 
            vertical: verticalPadding
          ),
          decoration: BoxDecoration(
            color: surfaceColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                offset: Offset(0, 2),
                blurRadius: 5,
              ),
            ],
          ),
            child: Row(
              children: [
                _buildStepperHeader(0, 'Doctor'),
                _buildStepperDivider(_currentStep > 0),
                _buildStepperHeader(1, 'Date & Time'),
                _buildStepperDivider(_currentStep > 1),
                _buildStepperHeader(2, 'Review'),
              ],
            ),
          ),
          // Main content area
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
              // Ensure scrolling works properly through the entire page
              physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                padding: EdgeInsets.all(horizontalPadding),
                  child: _buildStepContent(),
                ),
              ),
            ),
          ),
          // Error message
          if (_errorMessage != null)
            Container(
            margin: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 8),
            padding: EdgeInsets.all(horizontalPadding * 0.75),
              decoration: BoxDecoration(
              color: errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                Icon(
                  Icons.error_outline, 
                  color: errorColor,
                  size: ResponsiveUtils.scaleIconSize(context, 24),
                ),
                SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                      fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                      color: errorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Navigation buttons
          Container(
          padding: EdgeInsets.all(horizontalPadding),
            decoration: BoxDecoration(
            color: surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                offset: Offset(0, -3),
                blurRadius: 10,
                ),
              ],
            ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isSmall = ResponsiveUtils.isSmallScreen(context);
              final double maxWidth = constraints.maxWidth;
              final double buttonHeight = ResponsiveUtils.scalePadding(
                context, 
                isSmall ? 52 : 58
              );
              final double fontSize = ResponsiveUtils.scaleFontSize(
                context, 
                isSmall ? 14 : 15
              );
              final double iconSize = ResponsiveUtils.scaleIconSize(
                context, 
                isSmall ? 16 : 18
              );
              
              // For very narrow screens, stack the buttons vertically
              if (maxWidth < 320 && _currentStep > 0) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildContinueButton(
                      buttonHeight: buttonHeight,
                      fontSize: fontSize,
                      iconSize: iconSize,
                      isFullWidth: true,
                    ),
                    SizedBox(height: 12),
                    _buildBackButton(
                      buttonHeight: buttonHeight,
                      fontSize: fontSize,
                      isFullWidth: true,
                    ),
                  ],
                );
              }
              
              // Standard layout for wider screens
              return Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                      child: _buildBackButton(
                        buttonHeight: buttonHeight,
                        fontSize: fontSize,
                      ),
                    ),
                  if (_currentStep > 0)
                    SizedBox(width: 12),
                  Expanded(
                    flex: _currentStep > 0 ? 2 : 1,  // Give continue button more space when both buttons are shown
                    child: _buildContinueButton(
                      buttonHeight: buttonHeight,
                      fontSize: fontSize,
                      iconSize: iconSize,
                    ),
                  ),
                ],
              );
            }
          ),
        ),
      ],
    );
  }
  
  // Extract the back button widget
  Widget _buildBackButton({
    required double buttonHeight,
    required double fontSize,
    bool isFullWidth = false,
  }) {
    return SizedBox(
      height: buttonHeight,
      width: isFullWidth ? double.infinity : null,
                    child: OutlinedButton(
                      onPressed: () => _animateToStep(_currentStep - 1),
                      style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.scalePadding(context, 14)
          ),
          side: BorderSide(color: primaryColor, width: 1.5),
                        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Back',
                        style: GoogleFonts.poppins(
            fontSize: fontSize,
                          fontWeight: FontWeight.w500,
            color: primaryColor,
                        ),
                      ),
                    ),
    );
  }
  
  // Extract the continue/payment button widget
  Widget _buildContinueButton({
    required double buttonHeight,
    required double fontSize,
    required double iconSize,
    bool isFullWidth = false,
  }) {
    final bool isPaymentStep = _currentStep == 2;
    final bool canProceed = _isStepValid();
    final String buttonText = isPaymentStep ? 'Proceed to Payment' : 'Continue';
    final IconData buttonIcon = isPaymentStep ? Icons.payment_rounded : Icons.arrow_forward;
    
    return SizedBox(
      height: buttonHeight,
      width: isFullWidth ? double.infinity : null,
                  child: ElevatedButton(
        onPressed: !canProceed 
          ? null 
          : () {
              if (isPaymentStep) {
                _processPayment();
              } else {
                _animateToStep(_currentStep + 1);
              }
            },
                    style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.scalePadding(context, 14)
          ),
                      shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
                      ),
          elevation: 0,
          shadowColor: primaryColor.withOpacity(0.4),
                    ).copyWith(
                      overlayColor: MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.pressed)) {
                return primaryColor.withOpacity(0.2);
                          }
                          return null;
                        },
                      ),
                    ),
        child: _isLoading && isPaymentStep
            ? Center(
                child: SizedBox(
                  width: ResponsiveUtils.scalePadding(context, 24),
                  height: ResponsiveUtils.scalePadding(context, 24),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    buttonText,
                            style: GoogleFonts.poppins(
                      fontSize: fontSize,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                  if (!_isLoading) ...[
                    SizedBox(width: 8),
                    Icon(
                      buttonIcon,
                      size: iconSize,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  // Build stepper header item
  Widget _buildStepperHeader(int step, String title) {
    final bool isActive = _currentStep >= step;
    final bool isCompleted = _currentStep > step;
    final bool isSmall = ResponsiveUtils.isSmallScreen(context);
    final double iconSize = ResponsiveUtils.scaleIconSize(context, isSmall ? 28 : 32);
    final double innerIconSize = ResponsiveUtils.scaleIconSize(context, isSmall ? 24 : 28);
    final double fontSize = ResponsiveUtils.scaleFontSize(context, isSmall ? 12 : 13);
    
    return Expanded(
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer container with gradient or solid color
          Container(
                width: iconSize,
                height: iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
                  gradient: isActive ? primaryGradient : null,
                  color: isActive ? null : Colors.grey.shade100,
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.25),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ] : null,
                ),
              ),
              // Inner content
              isCompleted
                ? Icon(Icons.check, color: Colors.white, size: ResponsiveUtils.scaleIconSize(context, 16))
                : Container(
                    width: isActive ? innerIconSize : innerIconSize * 0.95,
                    height: isActive ? innerIconSize : innerIconSize * 0.95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? Colors.white.withOpacity(0.25) : Colors.white,
              border: Border.all(
                        color: isActive ? Colors.white.withOpacity(0.5) : Colors.grey.shade300,
                        width: 1.5,
              ),
            ),
            child: Center(
                      child: Text(
                    '${step + 1}',
                    style: GoogleFonts.poppins(
                          color: isActive ? Colors.white : Colors.grey.shade500,
                          fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
          ),
            ],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
              title,
              style: GoogleFonts.poppins(
                    fontSize: fontSize,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? primaryColor : Colors.grey.shade500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
                ),
                if (isCompleted && !isSmall) ...[
                  SizedBox(height: 2),
                  Text(
                    'Completed',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveUtils.scaleFontSize(context, 10),
                      color: successColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build divider between steps
  Widget _buildStepperDivider(bool isActive) {
    return Container(
      width: ResponsiveUtils.scalePadding(context, 30),
      height: 2,
      decoration: BoxDecoration(
        gradient: isActive ? primaryGradient : null,
        color: isActive ? null : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  // Build content for current step
  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildDoctorLocationStep();
      case 1:
        return _buildDateTimeStep();
      case 2:
        return _buildReviewStep();
      default:
        return SizedBox.shrink();
    }
  }

  // Add this helper method at the end of the class
  Widget _buildCompactStat({
    required IconData icon,
    required String value,
    required Color iconColor,
    String? suffix,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: ResponsiveUtils.scaleIconSize(context, 14),
        ),
        SizedBox(width: 4),
        Text(
          value + (suffix ?? ''),
          style: GoogleFonts.poppins(
            fontSize: ResponsiveUtils.scaleFontSize(context, 12),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
} 