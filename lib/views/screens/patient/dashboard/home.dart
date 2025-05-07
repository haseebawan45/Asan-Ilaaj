import 'dart:ui';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/views/screens/patient/appointment/available_doctors.dart';
import 'package:healthcare/views/screens/patient/appointment/appointment_booking_flow.dart';
import 'package:healthcare/views/screens/patient/complete_profile/profile_page1.dart';
import 'package:healthcare/views/screens/patient/appointment/payment_options.dart';
import 'package:healthcare/views/screens/appointment/all_appoinments.dart';
import 'package:healthcare/views/screens/appointment/appointment_detail.dart';
import 'package:healthcare/views/screens/patient/appointment/phone_booking.dart';
import 'package:healthcare/views/screens/menu/faqs.dart';
import 'package:healthcare/views/screens/patient/signup/patient_signup.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthcare/views/screens/patient/appointment/simplified_booking_flow.dart';
import 'package:healthcare/views/screens/patient/dashboard/profile.dart';
import 'package:healthcare/views/screens/menu/help_center.dart';
import 'package:healthcare/views/screens/menu/settings.dart';
import 'package:healthcare/views/screens/common/chat/chat_list_screen.dart';
import 'package:healthcare/views/screens/patient/nursing/home_nursing_services.dart';
import 'package:healthcare/utils/app_theme.dart';
import 'package:healthcare/views/screens/common/signin.dart';

// Disease category model
class DiseaseCategory {
  final String name;
  final String nameUrdu;
  final IconData icon;
  final Color color;
  final String description;

  DiseaseCategory({
    required this.name,
    required this.nameUrdu,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class PatientHomeScreen extends StatefulWidget {
  final String profileStatus;
  final bool suppressProfilePrompt;
  final double profileCompletionPercentage;
  
  const PatientHomeScreen({
    super.key, 
    this.profileStatus = "incomplete",
    this.suppressProfilePrompt = false,
    this.profileCompletionPercentage = 0.0,
  });

  @override
  _PatientHomeScreenState createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> with SingleTickerProviderStateMixin {
  late String profileStatus;
  late bool suppressProfilePrompt;
  late double profileCompletionPercentage;
  late TabController _tabController;
  final List<String> _categories = ["All", "Upcoming", "Completed", "Cancelled"];
  int _selectedCategoryIndex = 0;
  
  // User data
  String userName = "User";
  String? profileImageUrl;
  bool isLoading = true;
  bool isRefreshing = false; // Flag for background refresh
  List<Map<String, dynamic>> upcomingAppointments = [];
  Map<String, dynamic> userData = {};
  static const String _userCacheKey = 'patient_home_data';
  bool _showAllSpecialties = false; // Added state variable to track whether to show all specialties

  // Updated disease categories data with 12 specialties
  final List<DiseaseCategory> _diseaseCategories = [
    DiseaseCategory(
      name: "Home Nursing",
      nameUrdu: "گھریلو نرسنگ",
      icon: LucideIcons.stethoscope,
      color: Color(0xFF8E44AD), // Purple color
      description: "Home nursing and medical care services",
    ),
    DiseaseCategory(
      name: "Cardiology",
      nameUrdu: "امراض قلب",
      icon: LucideIcons.heartPulse,
      color: Color(0xFFF44336),
      description: "Heart and cardiovascular system specialists",
    ),
    DiseaseCategory(
      name: "Neurology",
      nameUrdu: "امراض اعصاب",
      icon: LucideIcons.brain,
      color: Color(0xFF2196F3),
      description: "Brain and nervous system specialists",
    ),
    DiseaseCategory(
      name: "Dermatology",
      nameUrdu: "جلدی امراض",
      icon: Icons.face_retouching_natural,
      color: Color(0xFFFF9800),
      description: "Skin and hair specialists",
    ),
    DiseaseCategory(
      name: "Pediatrics",
      nameUrdu: "اطفال",
      icon: Icons.child_care,
      color: Color(0xFF4CAF50),
      description: "Child health specialists",
    ),
    DiseaseCategory(
      name: "Orthopedics",
      nameUrdu: "ہڈیوں کے امراض",
      icon: LucideIcons.bone,
      color: Color(0xFF9C27B0),
      description: "Bone and joint specialists",
    ),
    DiseaseCategory(
      name: "ENT",
      nameUrdu: "کان ناک گلے کے امراض",
      icon: LucideIcons.ear,
      color: Color(0xFF00BCD4),
      description: "Ear, nose and throat specialists",
    ),
    DiseaseCategory(
      name: "Gynecology",
      nameUrdu: "نسائی امراض",
      icon: Icons.pregnant_woman,
      color: Color(0xFFE91E63),
      description: "Women's health specialists",
    ),
    DiseaseCategory(
      name: "Ophthalmology",
      nameUrdu: "آنکھوں کے امراض",
      icon: LucideIcons.eye,
      color: Color(0xFF3F51B5),
      description: "Eye care specialists",
    ),
    DiseaseCategory(
      name: "Dentistry",
      nameUrdu: "دانتوں کے امراض",
      icon: Icons.healing,
      color: Color(0xFF607D8B),
      description: "Dental care specialists",
    ),
    DiseaseCategory(
      name: "Psychiatry",
      nameUrdu: "نفسیاتی امراض",
      icon: LucideIcons.brain,
      color: Color(0xFF795548),
      description: "Mental health specialists",
    ),
    DiseaseCategory(
      name: "Pulmonology",
      nameUrdu: "پھیپھڑوں کے امراض",
      icon: Icons.air,
      color: Color(0xFF009688),
      description: "Lung and respiratory specialists",
    ),
    DiseaseCategory(
      name: "Gastrology",
      nameUrdu: "معدے کے امراض",
      icon: Icons.local_dining,
      color: Color(0xFFFF5722),
      description: "Digestive system specialists",
    ),
  ];

  // Sample doctors by specialty for quick access
  final Map<String, List<Map<String, dynamic>>> _doctorsBySpecialty = {
    "Cardiology": [
      {
        "name": "Dr. Arshad Khan",
        "specialty": "Cardiology",
        "rating": "4.9",
        "experience": "15 years",
        "fee": "Rs 2500",
        "location": "Shifa International Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
      {
        "name": "Dr. Saima Malik",
        "specialty": "Cardiology",
        "rating": "4.7",
        "experience": "12 years",
        "fee": "Rs 2200",
        "location": "Pakistan Institute of Medical Sciences",
        "image": "assets/images/User.png",
        "available": true
      },
    ],
    "Neurology": [
      {
        "name": "Dr. Imran Rashid",
        "specialty": "Neurology",
        "rating": "4.8",
        "experience": "10 years",
        "fee": "Rs 2000",
        "location": "Agha Khan Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
      {
        "name": "Dr. Nadia Ahmed",
        "specialty": "Neurology",
        "rating": "4.6",
        "experience": "8 years",
        "fee": "Rs 1800",
        "location": "CMH Rawalpindi",
        "image": "assets/images/User.png",
        "available": false
      },
    ],
    "Dermatology": [
      {
        "name": "Dr. Amina Khan",
        "specialty": "Dermatology",
        "rating": "4.7",
        "experience": "9 years",
        "fee": "Rs 1900",
        "location": "Quaid-e-Azam International Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
      {
        "name": "Dr. Hassan Ali",
        "specialty": "Dermatology",
        "rating": "4.5",
        "experience": "7 years",
        "fee": "Rs 1700",
        "location": "Maroof International Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
    ],
    "Pediatrics": [
      {
        "name": "Dr. Fatima Zaidi",
        "specialty": "Pediatrics",
        "rating": "4.9",
        "experience": "14 years",
        "fee": "Rs 2300",
        "location": "Children's Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
      {
        "name": "Dr. Adeel Raza",
        "specialty": "Pediatrics",
        "rating": "4.8",
        "experience": "11 years",
        "fee": "Rs 2100",
        "location": "Shifa International Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
    ],
    "Orthopedics": [
      {
        "name": "Dr. Farhan Khan",
        "specialty": "Orthopedics",
        "rating": "4.8",
        "experience": "13 years",
        "fee": "Rs 2200",
        "location": "Shaukat Khanum Memorial Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
      {
        "name": "Dr. Sana Siddiqui",
        "specialty": "Orthopedics",
        "rating": "4.7",
        "experience": "10 years",
        "fee": "Rs 1900",
        "location": "PIMS Islamabad",
        "image": "assets/images/User.png",
        "available": false
      },
    ],
    "ENT": [
      {
        "name": "Dr. Ahmad Raza",
        "specialty": "ENT",
        "rating": "4.6",
        "experience": "9 years",
        "fee": "Rs 1800",
        "location": "KRL Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
      {
        "name": "Dr. Zainab Tariq",
        "specialty": "ENT",
        "rating": "4.5",
        "experience": "8 years",
        "fee": "Rs 1700",
        "location": "Holy Family Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
    ],
    "Gynecology": [
      {
        "name": "Dr. Samina Khan",
        "specialty": "Gynecology",
        "rating": "4.9",
        "experience": "15 years",
        "fee": "Rs 2400",
        "location": "Lady Reading Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
      {
        "name": "Dr. Ayesha Malik",
        "specialty": "Gynecology",
        "rating": "4.8",
        "experience": "12 years",
        "fee": "Rs 2200",
        "location": "Shifa International Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
    ],
    "Ophthalmology": [
      {
        "name": "Dr. Zulfiqar Ali",
        "specialty": "Ophthalmology",
        "rating": "4.7",
        "experience": "11 years",
        "fee": "Rs 1900",
        "location": "Al-Shifa Eye Trust Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
      {
        "name": "Dr. Maryam Aziz",
        "specialty": "Ophthalmology",
        "rating": "4.6",
        "experience": "9 years",
        "fee": "Rs 1700",
        "location": "LRBT Eye Hospital",
        "image": "assets/images/User.png",
        "available": false
      },
    ],
    "Dentistry": [
      {
        "name": "Dr. Faisal Khan",
        "specialty": "Dentistry",
        "rating": "4.8",
        "experience": "10 years",
        "fee": "Rs 1800",
        "location": "Islamabad Dental Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
      {
        "name": "Dr. Hina Nasir",
        "specialty": "Dentistry",
        "rating": "4.7",
        "experience": "8 years",
        "fee": "Rs 1600",
        "location": "Pearl Dental Clinic",
        "image": "assets/images/User.png",
        "available": true
      },
    ],
    "Psychiatry": [
      {
        "name": "Dr. Sohail Ahmed",
        "specialty": "Psychiatry",
        "rating": "4.8",
        "experience": "12 years",
        "fee": "Rs 2100",
        "location": "Institute of Psychiatry",
        "image": "assets/images/User.png",
        "available": true
      },
      {
        "name": "Dr. Nazia Hameed",
        "specialty": "Psychiatry",
        "rating": "4.7",
        "experience": "9 years",
        "fee": "Rs 1900",
        "location": "Fountain House",
        "image": "assets/images/User.png",
        "available": false
      },
    ],
    "Pulmonology": [
      {
        "name": "Dr. Tariq Mehmood",
        "specialty": "Pulmonology",
        "rating": "4.8",
        "experience": "13 years",
        "fee": "Rs 2200",
        "location": "National Institute of Chest Diseases",
        "image": "assets/images/User.png",
        "available": true
      },
      {
        "name": "Dr. Sadia Khan",
        "specialty": "Pulmonology",
        "rating": "4.6",
        "experience": "10 years",
        "fee": "Rs 2000",
        "location": "Gulab Devi Chest Hospital",
        "image": "assets/images/User.png",
        "available": true
      },
    ],
    "Gastrology": [
      {
        "name": "Dr. Adnan Qureshi",
        "specialty": "Gastrology",
        "rating": "4.7",
        "experience": "11 years",
        "fee": "Rs 2100",
        "location": "Pakistan Kidney and Liver Institute",
        "image": "assets/images/User.png",
        "available": true
      },
      {
        "name": "Dr. Rabia Saleem",
        "specialty": "Gastrology",
        "rating": "4.6",
        "experience": "9 years",
        "fee": "Rs 1900",
        "location": "Shifa International Hospital",
        "image": "assets/images/User.png",
        "available": false
      },
    ],
  };

  // Quick access doctors list
  List<Map<String, dynamic>> _quickAccessDoctors = [];

  // Add this at the top with other class variables
  Map<String, List<Map<String, dynamic>>> _cachedDoctors = {};

  // Cities for location filter
  final List<String> _pakistanCities = [
    'Abbottabad', 'Adilpur', 'Ahmadpur East', 'Alipur', 'Arifwala', 'Attock',
    'Badin', 'Bahawalnagar', 'Bahawalpur', 'Bannu', 'Battagram', 'Bhakkar', 'Bhalwal', 'Bhera', 'Bhimbar', 'Bhit Shah', 'Bhopalwala', 'Burewala',
    'Chaman', 'Charsadda', 'Chichawatni', 'Chiniot', 'Chishtian', 'Chitral', 'Chunian',
    'Dadu', 'Daharki', 'Daska', 'Dera Ghazi Khan', 'Dera Ismail Khan', 'Dinga', 'Dipalpur', 'Duki',
    'Faisalabad', 'Fateh Jang', 'Fazilpur', 'Fort Abbas',
    'Gambat', 'Ghotki', 'Gilgit', 'Gojra', 'Gwadar',
    'Hafizabad', 'Hala', 'Hangu', 'Haripur', 'Haroonabad', 'Hasilpur', 'Haveli Lakha', 'Hazro', 'Hub', 'Hyderabad',
    'Islamabad',
    'Jacobabad', 'Jahanian', 'Jalalpur Jattan', 'Jampur', 'Jamshoro', 'Jatoi', 'Jauharabad', 'Jhelum',
    'Kabirwala', 'Kahror Pakka', 'Kalat', 'Kamalia', 'Kamoke', 'Kandhkot', 'Karachi', 'Karak', 'Kasur', 'Khairpur', 'Khanewal', 'Khanpur', 'Kharian', 'Khushab', 'Kohat', 'Kot Addu', 'Kotri', 'Kumbar', 'Kunri',
    'Lahore', 'Laki Marwat', 'Larkana', 'Layyah', 'Liaquatpur', 'Lodhran', 'Loralai',
    'Mailsi', 'Malakwal', 'Mandi Bahauddin', 'Mansehra', 'Mardan', 'Mastung', 'Matiari', 'Mian Channu', 'Mianwali', 'Mingora', 'Mirpur', 'Mirpur Khas', 'Multan', 'Muridke', 'Muzaffarabad', 'Muzaffargarh',
    'Narowal', 'Nawabshah', 'Nowshera',
    'Okara',
    'Pakpattan', 'Pasrur', 'Pattoki', 'Peshawar', 'Pir Mahal',
    'Quetta',
    'Rahimyar Khan', 'Rajanpur', 'Rani Pur', 'Rawalpindi', 'Rohri', 'Risalpur',
    'Sadiqabad', 'Sahiwal', 'Saidu Sharif', 'Sakrand', 'Samundri', 'Sanghar', 'Sargodha', 'Sheikhupura', 'Shikarpur', 'Sialkot', 'Sibi', 'Sukkur', 'Swabi', 'Swat',
    'Talagang', 'Tandlianwala', 'Tando Adam', 'Tando Allahyar', 'Tando Muhammad Khan', 'Tank', 'Taunsa', 'Taxila', 'Toba Tek Singh', 'Turbat',
    'Vehari',
    'Wah Cantonment', 'Wazirabad'
  ];

  // Add this method to format rating
  String _formatRating(double rating) {
    return rating.toStringAsFixed(1); // This will show only one decimal place
  }

  @override
  void initState() {
    super.initState();
    profileStatus = widget.profileStatus;
    suppressProfilePrompt = widget.suppressProfilePrompt;
    profileCompletionPercentage = widget.profileCompletionPercentage;
    _tabController = TabController(length: _categories.length, vsync: this);
    
    // Initialize quick access doctors with a selection from different specialties
    _initializeQuickAccessDoctors();
    
    // Load data with caching
    _loadData();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (profileStatus.toLowerCase() != "complete" && !suppressProfilePrompt) {
        // Directly navigate to profile completion screen instead of showing popup
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const CompleteProfilePatient1Screen(),
          ),
        );
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    // Try to load data from cache first
    await _loadCachedData();
    
    // Then fetch fresh data from Firestore
    await _fetchUserData();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString(_userCacheKey);
      
      if (cachedData != null) {
        Map<String, dynamic> data = json.decode(cachedData);
        
        setState(() {
          userData = data;
          userName = data['fullName'] ?? data['name'] ?? "User";
          profileImageUrl = data['profileImageUrl'];
          profileStatus = data['profileComplete'] == true ? "complete" : "incomplete";
          profileCompletionPercentage = (data['completionPercentage'] as num?)?.toDouble() ?? 0.0;
          upcomingAppointments = List<Map<String, dynamic>>.from(data['appointments'] ?? []);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  Future<void> _fetchUserData() async {
    try {
      setState(() {
        isRefreshing = true;
      });

      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final userId = auth.currentUser?.uid;
      
      if (userId == null) {
        setState(() {
          isRefreshing = false;
          isLoading = false;
        });
        return;
      }

      // First try to get data from patients collection for medical details
      final patientDoc = await firestore.collection('patients').doc(userId).get();
      
      // Then get basic data from users collection (fallback)
      final userDoc = await firestore.collection('users').doc(userId).get();
      
      Map<String, dynamic> mergedData = {};
      
      // Check if either document exists
      if (!patientDoc.exists && !userDoc.exists) {
        debugPrint('No user data found in either collection');
        setState(() => isLoading = false);
        return;
      }
      
      // Merge data, prioritizing patients collection for medical info
      if (userDoc.exists) {
        mergedData.addAll(userDoc.data() ?? {});
      }
      
      if (patientDoc.exists) {
        mergedData.addAll(patientDoc.data() ?? {});
      }

      // Get appointments
      List<Map<String, dynamic>> appointments = [];
      try {
        final appointmentsSnapshot = await firestore
            .collection('appointments')
            .where('patientId', isEqualTo: userId)
            .get();

        final DateTime now = DateTime.now();

        for (var appointmentDoc in appointmentsSnapshot.docs) {
          final appointmentData = appointmentDoc.data();
          
          // Fetch doctor details
          if (appointmentData['doctorId'] != null) {
            final doctorDoc = await firestore
                .collection('doctors')
                .doc(appointmentData['doctorId'].toString())
                .get();
            
            if (doctorDoc.exists) {
              final doctorData = doctorDoc.data() as Map<String, dynamic>;
              
              // Get appointment date and time
              final String dateStr = appointmentData['date']?.toString() ?? '';
              final String timeStr = appointmentData['time']?.toString() ?? '';
              
              DateTime? appointmentDateTime;
              
              // Try to parse date and time
              try {
                if (dateStr.contains('/')) {
                  // Parse dd/MM/yyyy format
                  final parts = dateStr.split('/');
                  if (parts.length == 3) {
                    appointmentDateTime = DateTime(
                      int.parse(parts[2]),  // year
                      int.parse(parts[1]),  // month
                      int.parse(parts[0]),  // day
                    );
                  }
                } else {
                  // Try parsing ISO format
                  appointmentDateTime = DateTime.parse(dateStr);
                }

                // Add time if available
                if (appointmentDateTime != null && timeStr.isNotEmpty) {
                  // Clean up time string and handle AM/PM
                  String cleanTime = timeStr.toUpperCase().trim();
                  bool isPM = cleanTime.contains('PM');
                  cleanTime = cleanTime.replaceAll('AM', '').replaceAll('PM', '').trim();
                  
                  final timeParts = cleanTime.split(':');
                  if (timeParts.length >= 2) {
                    int hour = int.parse(timeParts[0]);
                    int minute = int.parse(timeParts[1]);
                    
                    // Convert to 24-hour format if PM
                    if (isPM && hour < 12) {
                      hour += 12;
                    }
                    // Handle 12 AM case
                    if (!isPM && hour == 12) {
                      hour = 0;
                    }
                    
                    appointmentDateTime = DateTime(
                      appointmentDateTime.year,
                      appointmentDateTime.month,
                      appointmentDateTime.day,
                      hour,
                      minute,
                    );
                  }
                }
              } catch (e) {
                print('Error parsing date/time for appointment: $e');
                print('Date string: $dateStr');
                print('Time string: $timeStr');
              }

              // Determine appointment status based on date/time and the 'completed' field
              String status;
              bool isCompleted = appointmentData['completed'] == true;
              
              if (isCompleted) {
                status = 'completed';
              } else if (appointmentDateTime != null) {
                status = appointmentDateTime.isAfter(now) ? 'upcoming' : 'completed';
                print('Appointment DateTime: $appointmentDateTime');
                print('Current DateTime: $now');
                print('Status determined: $status');
              } else {
                status = appointmentData['status']?.toString().toLowerCase() ?? 'upcoming';
                print('Using fallback status: $status');
              }
              
              appointments.add({
                'id': appointmentDoc.id,
                'date': dateStr,
                'time': timeStr,
                'status': status,
                'completed': isCompleted, // Add the completed field to the appointment data
                'doctorName': doctorData['fullName'] ?? doctorData['name'] ?? 'Unknown Doctor',
                'specialty': doctorData['specialty'] ?? 'General',
                'hospitalName': appointmentData['hospitalName'] ?? 'Unknown Hospital',
                'reason': appointmentData['reason'] ?? 'Consultation',
                'doctorImage': doctorData['profileImageUrl'] ?? 'assets/images/User.png',
                'fee': appointmentData['fee']?.toString() ?? '0',
                'paymentStatus': appointmentData['paymentStatus'] ?? 'pending',
                'paymentMethod': appointmentData['paymentMethod'] ?? 'Not specified',
                'isPanelConsultation': appointmentData['isPanelConsultation'] ?? false,
                'type': 'In-Person Visit',
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching appointments: $e');
      }

      // Calculate profile completion percentage if not available
      double completionPercentage = 0.0;
      if (mergedData['completionPercentage'] == null) {
        int fieldsCompleted = 0;
        int totalFields = 10; // Adjust based on your required fields
        
        // Check basic fields
        if (mergedData['fullName'] != null && mergedData['fullName'].toString().isNotEmpty) fieldsCompleted++;
        if (mergedData['email'] != null && mergedData['email'].toString().isNotEmpty) fieldsCompleted++;
        if (mergedData['phoneNumber'] != null && mergedData['phoneNumber'].toString().isNotEmpty) fieldsCompleted++;
        if (mergedData['address'] != null && mergedData['address'].toString().isNotEmpty) fieldsCompleted++;
        if (mergedData['city'] != null && mergedData['city'].toString().isNotEmpty) fieldsCompleted++;
        
        // Check medical fields
        if (mergedData['age'] != null && mergedData['age'].toString().isNotEmpty) fieldsCompleted++;
        if (mergedData['bloodGroup'] != null && mergedData['bloodGroup'].toString().isNotEmpty) fieldsCompleted++;
        if (mergedData['height'] != null && mergedData['height'].toString().isNotEmpty) fieldsCompleted++;
        if (mergedData['weight'] != null && mergedData['weight'].toString().isNotEmpty) fieldsCompleted++;
        if (mergedData['profileImageUrl'] != null && mergedData['profileImageUrl'].toString().isNotEmpty) fieldsCompleted++;
        
        completionPercentage = ((fieldsCompleted / totalFields) * 100).toDouble();
      } else {
        completionPercentage = (mergedData['completionPercentage'] is double)
            ? mergedData['completionPercentage']
            : (mergedData['completionPercentage'] is int)
                ? mergedData['completionPercentage'].toDouble()
                : double.tryParse(mergedData['completionPercentage'].toString()) ?? 0.0;
      }

      // Convert Timestamps to strings in mergedData to make it cacheable
      Map<String, dynamic> cacheableData = Map<String, dynamic>.from(mergedData);
      _convertTimestampsToStrings(cacheableData);

      // Save to cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userCacheKey, json.encode({
          ...cacheableData,
          'appointments': appointments,
        }));
      } catch (e) {
        debugPrint('Error saving to cache: $e');
      }
      
      setState(() {
        userData = mergedData;
        userName = mergedData['fullName'] ?? mergedData['name'] ?? "User";
        profileImageUrl = mergedData['profileImageUrl'];
        profileStatus = mergedData['profileComplete'] == true ? "complete" : "incomplete";
        profileCompletionPercentage = completionPercentage;
        upcomingAppointments = appointments;
        isLoading = false;
        isRefreshing = false;
      });
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
    }
  }

  // Helper method to convert Timestamps to strings in a map
  void _convertTimestampsToStrings(Map<String, dynamic> data) {
    data.forEach((key, value) {
      if (value is Timestamp) {
        data[key] = value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        _convertTimestampsToStrings(value);
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          if (value[i] is Map<String, dynamic>) {
            _convertTimestampsToStrings(value[i]);
          }
        }
      }
    });
  }

  Future<void> _refreshData() async {
    await _fetchUserData();
  }

  void _initializeQuickAccessDoctors() {
    // Get one doctor from each of the top 3 specialties
    _quickAccessDoctors = [
      _doctorsBySpecialty["Cardiology"]![0],
      _doctorsBySpecialty["Gynecology"]![0],
      _doctorsBySpecialty["Pediatrics"]![0],
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    
    return WillPopScope(
      onWillPop: () async {
        return await _showExitConfirmationDialog(context);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppTheme.primaryTeal,
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatListScreen(isDoctor: false),
                  ),
                );
              },
              tooltip: 'Chat with doctors',
            ),
          ],
        ),
        drawer: Container(
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
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl!)
                          : AssetImage('assets/images/User.png') as ImageProvider,
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
                      userName,
                      style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      userData['email'] ?? 'No email provided',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                            SizedBox(height: 15),
                            // Profile completion indicator
                            if (profileCompletionPercentage < 100)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Profile Completion",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        "${profileCompletionPercentage.toInt()}%",
                  style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                  ),
                ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: profileCompletionPercentage / 100,
                                      backgroundColor: Colors.white.withOpacity(0.3),
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      minHeight: 6,
              ),
                                  ),
                                ],
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
                          title: 'Home',
                          onTap: () => Navigator.pop(context),
                        ),
                        _buildMenuItem(
                          icon: Icons.person,
                          title: 'My Profile',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PatientMenuScreen(
                        name: userName,
                        profileCompletionPercentage: profileCompletionPercentage,
                      ),
                    ),
                  );
                },
              ),
                        _buildMenuItem(
                          icon: Icons.calendar_today,
                          title: 'My Appointments',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppointmentsScreen(),
                    ),
                  );
                },
              ),
                        _buildMenuItem(
                          icon: Icons.medical_services,
                          title: 'Find Doctors',
                onTap: () {
                  Navigator.pop(context);
                  _showFindDoctorsDialog();
                },
              ),
                        
                        _buildMenuSection("Settings & Support"),
                        _buildMenuItem(
                          icon: Icons.headset_mic,
                          title: 'Help Center',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                                builder: (context) => const HelpCenterScreen(),
                    ),
                  );
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
                  // Show logout confirmation dialog first
                  final shouldLogout = await _showLogoutConfirmationDialog(context);
                  if (shouldLogout) {
                    try {
                      await FirebaseAuth.instance.signOut();
                      // Clear any cached data
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      
                      if (context.mounted) {
                        // Navigate to login screen and clear all routes
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const SignIN(),
                          ),
                          (Route<dynamic> route) => false,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error logging out. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
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
        ),
        body: SafeArea(
          child: isLoading && userData.isEmpty
              ? Center(
                  child: CircularProgressIndicator(
                    color: const Color(0xFF3366CC),
                  ),
                )
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _refreshData,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(),
                                _buildBanner(),
                                _buildDiseaseCategories(),
                                _buildAppointmentsSection(),
                                SizedBox(height: screenSize.height * 0.025),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (isRefreshing)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3366CC)),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;

    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding, 
        verticalPadding, 
        horizontalPadding, 
        verticalPadding * 1.5
      ),
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
          bottomLeft: Radius.circular(screenSize.width * 0.09),
          bottomRight: Radius.circular(screenSize.width * 0.09),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                    "Hello,",
                    style: GoogleFonts.poppins(
                          fontSize: screenSize.width * 0.04,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                    userName,
                    style: GoogleFonts.poppins(
                          fontSize: screenSize.width * 0.07,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      height: 1.2,
                        ),
                    ),
                  ),
                ],
                ),
              ),
              
              // Profile Photo
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PatientMenuScreen(
                        name: userName,
                        profileCompletionPercentage: profileCompletionPercentage,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Hero(
                    tag: 'profileImageHeader',
                    child: CircleAvatar(
                      radius: screenSize.width * 0.07,
                      backgroundColor: Colors.white,
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl!)
                          : AssetImage('assets/images/User.png') as ImageProvider,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: verticalPadding),
          
          // Profile Completion Tab - Only show when not 100% complete
          if (profileCompletionPercentage < 100)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding * 0.8, 
                vertical: verticalPadding * 0.6
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryPink,
                    AppTheme.primaryPink.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(screenSize.width * 0.04),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPink.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Removed profile icon here
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                              "Profile Completion",
                              style: GoogleFonts.poppins(
                                  fontSize: screenSize.width * 0.035,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding * 0.4, 
                                vertical: verticalPadding * 0.1
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(screenSize.width * 0.025),
                              ),
                              child: Text(
                                "${profileCompletionPercentage.toInt()}%",
                                style: GoogleFonts.poppins(
                                  fontSize: screenSize.width * 0.03,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF7043),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: verticalPadding * 0.3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(screenSize.width * 0.01),
                          child: LinearProgressIndicator(
                            value: profileCompletionPercentage / 100,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: horizontalPadding * 0.6),
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
                      padding: EdgeInsets.all(screenSize.width * 0.02),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        color: Color(0xFFFF7043),
                        size: screenSize.width * 0.04,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          SizedBox(height: verticalPadding),
          
          // "Find Doctors" Card
          InkWell(
            onTap: () => _showFindDoctorsDialog(),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding * 0.9, 
                vertical: verticalPadding * 0.8
              ),
              decoration: BoxDecoration(
                color: AppTheme.darkTeal,
                borderRadius: BorderRadius.circular(screenSize.width * 0.045),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: screenSize.width * 0.12,
                    width: screenSize.width * 0.12,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(screenSize.width * 0.03),
                    ),
                    child: Icon(
                      LucideIcons.search,
                      color: Colors.white,
                      size: screenSize.width * 0.06,
                    ),
                  ),
                  SizedBox(width: horizontalPadding * 0.75),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Find Doctors",
                          style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.04,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: verticalPadding * 0.1),
                        Text(
                          "Search for doctors by specialty and location",
                          style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.035,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    color: Colors.white,
                    size: screenSize.width * 0.05,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;

    return Column(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(
            horizontalPadding, 
            verticalPadding, 
            horizontalPadding, 
            0
          ),
          padding: EdgeInsets.all(horizontalPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3366CC),
                Color(0xFF3366CC),
              ],
            ),
            borderRadius: BorderRadius.circular(screenSize.width * 0.05),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF3366CC).withOpacity(0.3),
                blurRadius: screenSize.width * 0.025,
                offset: Offset(0, screenSize.height * 0.006),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                      userData.containsKey('bloodGroup') ? 
                        "Your Blood Group: ${userData['bloodGroup']}" :
                        "Complete Your Profile",
                      style: GoogleFonts.poppins(
                          fontSize: screenSize.width * 0.04,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    ),
                    SizedBox(height: verticalPadding * 0.3),
                    Text("Book your appointment here.",
                      style: GoogleFonts.poppins(
                        fontSize: screenSize.width * 0.033,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: verticalPadding * 0.3), // Reduced from 0.5
                    // Button Section
                    Container(
                      margin: EdgeInsets.only(top: verticalPadding * 0.1), // Reduced from 0.25
                      child: Column(
                        children: [
                          // First row of buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DoctorsScreen(
                                          specialty: "Cardiology",
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.calendar_today, size: screenSize.width * 0.032), // Reduced from 0.035
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                    "Book Online",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                        fontSize: screenSize.width * 0.028, // Reduced from 0.03
                                      ),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Color(0xFF3366CC),
                                    padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.35), // Reduced from 0.5
                                    minimumSize: Size(screenSize.width * 0.25, screenSize.height * 0.04), // Reduced height from 0.045
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(screenSize.width * 0.02),
                                    ),
                                    elevation: 1,
                                    shadowColor: Colors.black.withOpacity(0.1),
                                  ),
                                ),
                              ),
                              SizedBox(width: horizontalPadding * 0.5),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PhoneBookingScreen(),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.phone, size: screenSize.width * 0.032), // Reduced from 0.035
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                    "Book via Call",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                        fontSize: screenSize.width * 0.028, // Reduced from 0.03
                                      ),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF204899),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.35), // Reduced from 0.5
                                    minimumSize: Size(screenSize.width * 0.25, screenSize.height * 0.04), // Reduced height from 0.045
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(screenSize.width * 0.02),
                                    ),
                                    elevation: 1,
                                    shadowColor: Color(0xFF3366CC).withOpacity(0.3),
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
              SizedBox(width: horizontalPadding * 0.8),
              Container(
                height: screenSize.width * 0.18,
                width: screenSize.width * 0.18,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(screenSize.width * 0.03),
                ),
                child: Icon(
                  profileStatus == "complete" ? LucideIcons.stethoscope : LucideIcons.userPlus,
                  color: Colors.white,
                  size: screenSize.width * 0.1,
                ),
              ),
            ],
          ),
        ),
        
        // Add Home Nursing Services Banner
        Container(
          margin: EdgeInsets.fromLTRB(
            horizontalPadding, 
            verticalPadding, 
            horizontalPadding, 
            0
          ),
          padding: EdgeInsets.all(horizontalPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryPink,
                AppTheme.primaryPink,
              ],
            ),
            borderRadius: BorderRadius.circular(screenSize.width * 0.05),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPink.withOpacity(0.3),
                blurRadius: screenSize.width * 0.025,
                offset: Offset(0, screenSize.height * 0.006),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => HomeNursingServicesScreen(),
                )
              );
            },
            borderRadius: BorderRadius.circular(screenSize.width * 0.05),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Home Nursing Services",
                          style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.04,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: verticalPadding * 0.3),
                      Text(
                        "Professional care in comfort of your home",
                        style: GoogleFonts.poppins(
                          fontSize: screenSize.width * 0.033,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: verticalPadding * 0.4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding * 0.7,
                          vertical: verticalPadding * 0.3
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(screenSize.width * 0.04),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Book Now",
                              style: GoogleFonts.poppins(
                                fontSize: screenSize.width * 0.03,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8E44AD),
                              ),
                            ),
                            SizedBox(width: horizontalPadding * 0.2),
                            Icon(
                              Icons.arrow_forward,
                              color: Color(0xFF8E44AD),
                              size: screenSize.width * 0.03,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: horizontalPadding * 0.8),
                Container(
                  height: screenSize.width * 0.18,
                  width: screenSize.width * 0.18,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(screenSize.width * 0.03),
                  ),
                  child: Icon(
                    LucideIcons.stethoscope,
                    color: Colors.white,
                    size: screenSize.width * 0.09,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiseaseCategories() {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding, 
        verticalPadding * 1.25, 
        horizontalPadding,
        0
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Specialties",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.045,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showAllSpecialties = !_showAllSpecialties;
                  });
                },
                child: Text(
                  _showAllSpecialties ? "Show Less" : "See All",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.035,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF3366CC),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: verticalPadding),
          LayoutBuilder(
            builder: (context, constraints) {
              // Adapt grid columns based on screen width
              final int crossAxisCount = screenSize.width > 600 ? 4 : 3;
              // Calculate how many specialties to show based on the state
              final int itemCount = _showAllSpecialties 
                  ? _diseaseCategories.length
                  : _diseaseCategories.length > 6 ? 6 : _diseaseCategories.length;
              
              return GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.0, // Changed from 0.8 to 1.0 to make cards square
                  crossAxisSpacing: screenSize.width * 0.025,
                  mainAxisSpacing: screenSize.width * 0.025,
                ),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  final category = _diseaseCategories[index];
                  return _buildDiseaseCategoryCard(category);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseCategoryCard(DiseaseCategory category) {
    final Size screenSize = MediaQuery.of(context).size;
    
    return InkWell(
      onTap: () async {
        try {
          // Show a bottom sheet for gender selection
          final String? selectedGender = await _showGenderFilterDialog();
          // Check if dialog was dismissed with close button or back button
          if (selectedGender == null) {
            // Just return without doing anything - this means user canceled the dialog
            return;
          }
          
          // Check if we have cached data
          if (_cachedDoctors.containsKey(category.name)) {
            // Filter doctors based on gender if needed
            List<Map<String, dynamic>> filteredDoctors = _cachedDoctors[category.name]!;
            
            if (selectedGender != null && selectedGender != "All") {
              filteredDoctors = filteredDoctors
                .where((doctor) => doctor['gender'] == selectedGender)
                .toList();
            }
            
            // If we have cached data, show it immediately
            if (context.mounted && filteredDoctors.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctorsScreen(
                    specialty: category.name,
                    doctors: filteredDoctors,
                    initialGenderFilter: selectedGender == "All" ? null : selectedGender,
                  ),
                ),
              );
              // Fetch fresh data in background
              _fetchDoctorsData(
                category.name, 
                showLoading: false, 
                genderFilter: selectedGender == "All" ? null : selectedGender
              );
              return;
            }
          }

          // Show loading dialog only for first load
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return Center(
                child: Container(
                  padding: EdgeInsets.all(screenSize.width * 0.05),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(screenSize.width * 0.038),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3366CC)),
                      ),
                      SizedBox(height: screenSize.height * 0.02),
                      Text(
                        "Loading doctors...",
                        style: GoogleFonts.poppins(
                          fontSize: screenSize.width * 0.035,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

          await _fetchDoctorsData(
            category.name, 
            showLoading: true,
            genderFilter: selectedGender == "All" ? null : selectedGender,
          );

        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context); // Pop loading dialog if showing
            
            // Show error dialog
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(
                    "Error",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  content: Text(
                    "Failed to load doctors. Please try again later.",
                    style: GoogleFonts.poppins(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "OK",
                        style: GoogleFonts.poppins(
                          color: Color(0xFF3366CC),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(screenSize.width * 0.03),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenSize.width * 0.03),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade100,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(screenSize.width * 0.025),
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.icon,
                color: category.color,
                size: screenSize.width * 0.06,
              ),
            ),
            SizedBox(height: screenSize.height * 0.005), // Reduced spacing
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
              category.name,
              style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.028, // Slightly reduced font size
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
              category.nameUrdu,
              style: GoogleFonts.poppins(
                  fontSize: screenSize.width * 0.022, // Slightly reduced font size
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this new method for fetching doctors data
  Future<void> _fetchDoctorsData(String specialty, {required bool showLoading, String? genderFilter, String? cityFilter}) async {
    try {
      // Fetch doctors from Firestore based on specialty
      Query doctorsQuery = FirebaseFirestore.instance
          .collection('doctors')
          .where('specialty', isEqualTo: specialty)
          .where('isApproved', isEqualTo: true);
      
      // Apply gender filter if specified
      if (genderFilter != null) {
        doctorsQuery = doctorsQuery.where('gender', isEqualTo: genderFilter);
      }
      
      // Get the query snapshot
      final QuerySnapshot doctorsSnapshot = await doctorsQuery.get();

      List<Map<String, dynamic>> doctors = [];
      
      for (var doc in doctorsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Get doctor's rating from reviews
        final QuerySnapshot reviewsSnapshot = await FirebaseFirestore.instance
            .collection('doctor_reviews')
            .where('doctorId', isEqualTo: doc.id)
            .get();
        
        double averageRating = 0.0;
        if (reviewsSnapshot.docs.isNotEmpty) {
          double totalRating = 0;
          for (var review in reviewsSnapshot.docs) {
            totalRating += (review.data() as Map<String, dynamic>)['rating'] ?? 0;
          }
          averageRating = (totalRating / reviewsSnapshot.docs.length);
        }

        // Get doctor's hospital affiliations
        List<String> hospitals = [];
        if (data['hospitalIds'] != null) {
          for (String hospitalId in List<String>.from(data['hospitalIds'])) {
            final hospitalDoc = await FirebaseFirestore.instance
                .collection('hospitals')
                .doc(hospitalId)
                .get();
            if (hospitalDoc.exists) {
              hospitals.add(hospitalDoc.get('name'));
            }
          }
        }

        // Check city filter
        bool includeDoctor = true;
        if (cityFilter != null) {
          // If doctor's city matches the filter
          bool cityMatch = (data['city'] != null && 
              data['city'].toString().toLowerCase() == cityFilter.toLowerCase());
          
          // Or if any of doctor's hospitals are in that city
          bool hospitalMatch = hospitals.any((hospital) => 
              hospital.toLowerCase().contains(cityFilter.toLowerCase()));
          
          includeDoctor = cityMatch || hospitalMatch;
        }
        
        if (includeDoctor) {
          doctors.add({
            'id': doc.id,
            'name': data['fullName'] ?? 'Dr. Unknown',
            'specialty': data['specialty'] ?? specialty,
            'rating': averageRating.toStringAsFixed(1),
            'experience': data['experience'] ?? '0 years',
            'fee': data['consultationFee']?.toString() ?? 'Not specified',
            'location': hospitals.isNotEmpty ? hospitals.first : 'Location not specified',
            'image': data['profileImageUrl'] ?? 'assets/images/User.png',
            'available': data['isAvailable'] ?? true,
            'hospitals': hospitals,
            'education': data['education'] ?? [],
            'about': data['about'] ?? 'No information available',
            'languages': data['languages'] ?? ['English'],
            'services': data['services'] ?? [],
            'gender': data['gender'] ?? 'Not specified',
            'city': data['city'],
          });
        }
      }

      // Update cache
      _cachedDoctors[specialty] = doctors;

      if (showLoading) {
        // Pop loading dialog if it was shown
        if (context.mounted) {
          Navigator.pop(context);
        }

        // Navigate to doctors screen with fetched data
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DoctorsScreen(
                specialty: specialty,
                doctors: doctors,
                initialGenderFilter: genderFilter,
              ),
            ),
          );
        }
      }
    } catch (e) {
      rethrow; // Let the calling method handle the error
    }
  }

  Widget _buildAppointmentsSection() {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;
    
    // Filter appointments based on the 'completed' field
    final List<Map<String, dynamic>> upcoming = upcomingAppointments.where((a) => 
      a['completed'] != true).toList();
    final List<Map<String, dynamic>> completed = upcomingAppointments.where((a) => 
      a['completed'] == true).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding, 
        verticalPadding * 1.25, 
        horizontalPadding, 
        0
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                  "My Appointments",
                  style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.045,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AppointmentsScreen()),
                      );
                    },
                    child: Text(
                      "See All",
                      style: GoogleFonts.poppins(
                        fontSize: screenSize.width * 0.035,
                        color: Color(0xFF3366CC),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: verticalPadding),
          Container(
            height: screenSize.height * 0.05,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryIndex = 0;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: horizontalPadding / 2),
                      decoration: BoxDecoration(
                        color: _selectedCategoryIndex == 0
                            ? AppTheme.primaryTeal
                            : Color(0xFFF5F7FF),
                        borderRadius: BorderRadius.circular(screenSize.width * 0.05),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                      child: Text(
                        "Upcoming",
                        style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.035,
                          fontWeight: FontWeight.w500,
                          color: _selectedCategoryIndex == 0
                              ? Colors.white
                              : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryIndex = 1;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedCategoryIndex == 1
                            ? AppTheme.primaryTeal
                            : Color(0xFFF5F7FF),
                        borderRadius: BorderRadius.circular(screenSize.width * 0.05),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                      child: Text(
                        "Completed",
                        style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.035,
                          fontWeight: FontWeight.w500,
                          color: _selectedCategoryIndex == 1
                              ? Colors.white
                              : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: verticalPadding),
          if ((_selectedCategoryIndex == 0 ? upcoming : completed).isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(verticalPadding),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.calendar,
                      size: screenSize.width * 0.12,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: verticalPadding),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                      "No ${_selectedCategoryIndex == 0 ? 'upcoming' : 'completed'} appointments",
                      style: GoogleFonts.poppins(
                          fontSize: screenSize.width * 0.04,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (var appointment in (_selectedCategoryIndex == 0 ? upcoming : completed).take(2))
              _buildAppointmentCard(appointment),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;
    
    final bool isCompleted = appointment['completed'] == true;
    
    final Color statusColor =  Color(0xFFFFFFFF);  // Blue for upcoming
            
    final String displayStatus = isCompleted ? "Completed" : "Upcoming";
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentDetailsScreen(
              appointmentDetails: appointment,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: verticalPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenSize.width * 0.045),
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
              padding: EdgeInsets.all(horizontalPadding * 0.8),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(screenSize.width * 0.045),
                  topRight: Radius.circular(screenSize.width * 0.045),
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
                    child: CircleAvatar(
                      radius: screenSize.width * 0.06,
                      backgroundImage: appointment['doctorImage'].startsWith('assets/')
                          ? AssetImage(appointment['doctorImage'])
                          : NetworkImage(appointment['doctorImage']) as ImageProvider,
                    ),
                  ),
                  SizedBox(width: horizontalPadding * 0.75),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                          appointment['doctorName'],
                          style: GoogleFonts.poppins(
                              fontSize: screenSize.width * 0.04,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        ),
                        SizedBox(height: verticalPadding * 0.1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                          appointment['specialty'],
                          style: GoogleFonts.poppins(
                              fontSize: screenSize.width * 0.035,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding * 0.6,
                      vertical: verticalPadding * 0.3
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(screenSize.width * 0.05),
                      border: Border.all(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                    child: Text(
                      displayStatus,
                      style: GoogleFonts.poppins(
                          fontSize: screenSize.width * 0.03,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(horizontalPadding * 0.8),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildAppointmentDetail(
                        LucideIcons.calendar,
                        "Appointment Date",
                        appointment['date'],
                      ),
                      SizedBox(width: horizontalPadding * 0.75),
                      _buildAppointmentDetail(
                        LucideIcons.clock,
                        "Appointment Time",
                        appointment['time'],
                      ),
                    ],
                  ),
                  SizedBox(height: verticalPadding * 0.6),
                  Row(
                    children: [
                      _buildAppointmentDetail(
                        LucideIcons.building2,
                        "Hospital",
                        appointment['hospitalName'] ?? "Unknown Hospital",
                      ),
                      SizedBox(width: horizontalPadding * 0.75),
                      _buildAppointmentDetail(
                        LucideIcons.tag,
                        "Type",
                        appointment['type'],
                      ),
                    ],
                  ),
                  SizedBox(height: verticalPadding * 0.9),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to appointment details
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
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(screenSize.width * 0.03),
                            ),
                            elevation: 3,
                            shadowColor: AppTheme.primaryTeal.withOpacity(0.3),
                          ),
                          icon: Icon(LucideIcons.building2, size: screenSize.width * 0.045),
                          label: Text(
                            "View Details",
                            style: GoogleFonts.poppins(
                              fontSize: screenSize.width * 0.035,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
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

  Widget _buildAppointmentDetail(IconData icon, String label, String value) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;
    
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(screenSize.width * 0.02),
            decoration: BoxDecoration(
              color: Color.fromRGBO(64, 124, 226, 0.1),
              borderRadius: BorderRadius.circular(screenSize.width * 0.02),
            ),
            child: Icon(
              icon,
              size: screenSize.width * 0.04,
              color: Color.fromRGBO(64, 124, 226, 1),
            ),
          ),
          SizedBox(width: horizontalPadding * 0.5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                  label,
                  style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.03,
                    color: Colors.grey.shade600,
                  ),
                ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                  value,
                  style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.035,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Add exit confirmation dialog
  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissal when clicking outside
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenSize.width * 0.05),
          ),
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(horizontalPadding * 0.75),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.exit_to_app,
                    color: AppTheme.error,
                    size: screenSize.width * 0.075,
                  ),
                ),
                SizedBox(height: verticalPadding),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                  "Exit App",
                  style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                ),
                SizedBox(height: verticalPadding * 0.5),
                Text(
                  "Are you sure you want to exit the app?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.035,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: verticalPadding * 1.25),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade800,
                          backgroundColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(screenSize.width * 0.03),
                          ),
                          padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.6),
                        ),
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.035,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: horizontalPadding * 0.75),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(true);
                          SystemNavigator.pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(screenSize.width * 0.03),
                          ),
                          padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.6),
                          elevation: 0,
                        ),
                        child: Text(
                          "Exit",
                          style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.035,
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
    ) ?? false;
  }

  // Add a gender filter dialog
  Future<String?> _showGenderFilterDialog() async {
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;
    
    return await showDialog<String?>(
      context: context,
      barrierDismissible: true, // Allow dismissal when clicking outside
      barrierColor: Colors.black54.withOpacity(0.7), // Darker background for better contrast
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenSize.width * 0.05),
          ),
          elevation: 12,
          backgroundColor: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxWidth = constraints.maxWidth;
              final double buttonSize = maxWidth * 0.1;
              
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Color(0xFFF5F7FF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(screenSize.width * 0.05),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
          ),
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding * 1.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                      // Header with curved background
                      Container(
                        margin: EdgeInsets.only(bottom: verticalPadding * 0.8),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: verticalPadding),
                                child: Column(
                  children: [
                    Text(
                      "Filter Doctors",
                      style: GoogleFonts.poppins(
                                        fontSize: maxWidth * 0.06,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryTeal,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(height: verticalPadding * 0.3),
                Text(
                  "Select Gender Preference",
                  style: GoogleFonts.poppins(
                                        fontSize: maxWidth * 0.042,
                    fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Close button at top right
                            Positioned(
                              right: 0,
                              top: 0,
                              child: SizedBox(
                                width: buttonSize,
                                height: buttonSize,
                                child: Material(
                                  color: Colors.grey.shade100,
                                  shape: CircleBorder(),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(buttonSize),
                                    onTap: () => Navigator.pop(context, null),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.grey.shade700,
                                      size: buttonSize * 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Divider(color: Colors.grey.shade300, thickness: 1),
                      SizedBox(height: verticalPadding * 0.5),
                      
                      // All Doctors Button with animation
                      TweenAnimationBuilder(
                        duration: Duration(milliseconds: 300),
                        tween: Tween<double>(begin: 0.8, end: 1.0),
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, "All"),
                            splashColor: Colors.purple.withOpacity(0.1),
                            highlightColor: Colors.purple.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(maxWidth * 0.04),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                                horizontal: maxWidth * 0.04,
                                vertical: verticalPadding * 0.9,
                      ),
                      decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white, Color(0xFFF8F0FC)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(maxWidth * 0.04),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(color: Colors.purple.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                                    height: maxWidth * 0.13,
                                    width: maxWidth * 0.13,
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.purple.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                            ),
                            child: Icon(
                              Icons.people,
                              color: Colors.purple,
                                      size: maxWidth * 0.06,
                            ),
                          ),
                                  SizedBox(width: maxWidth * 0.04),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "All Doctors",
                                  style: GoogleFonts.poppins(
                                            fontSize: maxWidth * 0.043,
                                    fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                  ),
                                ),
                                        SizedBox(height: verticalPadding * 0.2),
                                Text(
                                  "View all available doctors",
                                  style: GoogleFonts.poppins(
                                            fontSize: maxWidth * 0.034,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                                  Icon(
                                    LucideIcons.chevronRight,
                                    color: Colors.purple.withOpacity(0.7),
                                    size: maxWidth * 0.05,
                          ),
                        ],
                              ),
                      ),
                    ),
                  ),
                ),
                
                      SizedBox(height: verticalPadding * 0.8),
                      
                      // Male Doctors Button with animation
                      TweenAnimationBuilder(
                        duration: Duration(milliseconds: 400),
                        tween: Tween<double>(begin: 0.8, end: 1.0),
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, "Male"),
                            splashColor: Colors.blue.withOpacity(0.1),
                            highlightColor: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(maxWidth * 0.04),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                                horizontal: maxWidth * 0.04,
                                vertical: verticalPadding * 0.9,
                      ),
                      decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white, Color(0xFFE6F0FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(maxWidth * 0.04),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                                    height: maxWidth * 0.13,
                                    width: maxWidth * 0.13,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.blue.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                            ),
                            child: Icon(
                              Icons.male,
                              color: Colors.blue,
                                      size: maxWidth * 0.06,
                            ),
                          ),
                                  SizedBox(width: maxWidth * 0.04),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Male Doctors",
                                  style: GoogleFonts.poppins(
                                            fontSize: maxWidth * 0.043,
                                    fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                  ),
                                ),
                                        SizedBox(height: verticalPadding * 0.2),
                                Text(
                                  "View only male doctors",
                                  style: GoogleFonts.poppins(
                                            fontSize: maxWidth * 0.034,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                                  Icon(
                                    LucideIcons.chevronRight,
                                    color: Colors.blue.withOpacity(0.7),
                                    size: maxWidth * 0.05,
                          ),
                        ],
                              ),
                      ),
                    ),
                  ),
                ),
                
                      SizedBox(height: verticalPadding * 0.8),
                      
                      // Female Doctors Button with animation
                      TweenAnimationBuilder(
                        duration: Duration(milliseconds: 500),
                        tween: Tween<double>(begin: 0.8, end: 1.0),
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, "Female"),
                            splashColor: Colors.pink.withOpacity(0.1),
                            highlightColor: Colors.pink.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(maxWidth * 0.04),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                                horizontal: maxWidth * 0.04,
                                vertical: verticalPadding * 0.9,
                      ),
                      decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white, Color(0xFFFCE4EC)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(maxWidth * 0.04),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pink.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(color: Colors.pink.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                                    height: maxWidth * 0.13,
                                    width: maxWidth * 0.13,
                            decoration: BoxDecoration(
                              color: Colors.pink.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.pink.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                            ),
                            child: Icon(
                              Icons.female,
                              color: Colors.pink,
                                      size: maxWidth * 0.06,
                            ),
                          ),
                                  SizedBox(width: maxWidth * 0.04),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Female Doctors",
                                  style: GoogleFonts.poppins(
                                            fontSize: maxWidth * 0.043,
                                    fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                  ),
                                ),
                                        SizedBox(height: verticalPadding * 0.2),
                                Text(
                                  "View only female doctors",
                                  style: GoogleFonts.poppins(
                                            fontSize: maxWidth * 0.034,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                                  Icon(
                                    LucideIcons.chevronRight,
                                    color: Colors.pink.withOpacity(0.7),
                                    size: maxWidth * 0.05,
                          ),
                        ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // City list for filter

  
  // Method to show multi-step find doctors dialog
  Future<void> _showFindDoctorsDialog() async {
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;
    
    // Selection state variables for the dialog
    DiseaseCategory? selectedSpecialty;
    String? selectedCity;
    String? selectedGender = "All"; // Default to All
    
    bool result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54.withOpacity(0.7), // Darker background for better contrast
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(screenSize.width * 0.05),
              ),
              elevation: 24, // Increased elevation for more pronounced shadow
              clipBehavior: Clip.antiAlias, // Ensure content respects rounded corners
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate proportional sizes based on the dialog's constraints
                  final double maxWidth = constraints.maxWidth;
                  final double maxHeight = constraints.maxHeight;
                  final double buttonSize = maxWidth * 0.1;
                  
                  return Container(
                    width: screenSize.width * 0.9,
                    constraints: BoxConstraints(
                      maxHeight: screenSize.height * 0.8, // Ensure dialog doesn't exceed 80% of screen height
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(screenSize.width * 0.05),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Color(0xFFF0F8FF)], // Subtle blue gradient background
                        stops: [0.0, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      minimum: EdgeInsets.all(horizontalPadding * 0.5),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(horizontalPadding * 0.8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Dialog Header with decoration
                              Container(
                                margin: EdgeInsets.only(bottom: verticalPadding),
                                child: Stack(
                                  children: [
                                    // Centered title with decorative elements
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(
                                        padding: EdgeInsets.only(
                                          top: verticalPadding * 0.5,
                                          bottom: verticalPadding * 0.5
                                        ),
                                        child: Column(
                                          children: [
                                            // Icon above title
                                            Container(
                                              padding: EdgeInsets.all(maxWidth * 0.03),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFF3366CC).withOpacity(0.8),
                                                    Color(0xFF3366CC),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Color(0xFF3366CC).withOpacity(0.25),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                    offset: Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                LucideIcons.search,
                                                color: Colors.white,
                                                size: maxWidth * 0.06,
                                              ),
                                            ),
                                            SizedBox(height: verticalPadding * 0.5),
                                            // Animated title
                                            TweenAnimationBuilder(
                                              duration: Duration(milliseconds: 500),
                                              tween: Tween<double>(begin: 0.8, end: 1.0),
                                              builder: (context, value, child) {
                                                return Transform.scale(
                                                  scale: value,
                                                  child: child,
                                                );
                                              },
                                              child: Text(
                                                "Find Doctors",
                                                style: GoogleFonts.poppins(
                                                  fontSize: maxWidth * 0.06,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF3366CC),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: verticalPadding * 0.2),
                                            Text(
                                              "Customize your search preferences",
                                              style: GoogleFonts.poppins(
                                                fontSize: maxWidth * 0.035,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Close button - positioned at the top right
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: SizedBox(
                                        width: buttonSize,
                                        height: buttonSize,
                                        child: Material(
                                          color: Colors.grey.shade200,
                                          shape: CircleBorder(),
                                          elevation: 2,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(buttonSize),
                                            onTap: () => Navigator.pop(context, false),
                                            child: Icon(
                                              Icons.close,
                                              color: Colors.grey.shade700,
                                              size: buttonSize * 0.6,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Divider with gradient
                              Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey.shade200,
                                      Color(0xFF3366CC).withOpacity(0.3),
                                      Colors.grey.shade200,
                                    ],
                                    stops: [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                              SizedBox(height: verticalPadding * 0.8),
                              
                              // Specialty Selection Section with enhanced design
                              TweenAnimationBuilder<Offset>(
                                duration: Duration(milliseconds: 600),
                                tween: Tween<Offset>(begin: Offset(0.05, 0), end: Offset.zero),
                                builder: (context, offset, child) {
                                  return Transform.translate(
                                    offset: offset,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  margin: EdgeInsets.only(bottom: verticalPadding * 0.5),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(maxWidth * 0.025),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF3366CC).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(maxWidth * 0.02),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Color(0xFF3366CC).withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              LucideIcons.stethoscope,
                                              color: Color(0xFF3366CC),
                                              size: maxWidth * 0.05,
                                            ),
                                          ),
                                          SizedBox(width: maxWidth * 0.03),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                "Select Specialty",
                                                style: GoogleFonts.poppins(
                                                  fontSize: maxWidth * 0.04,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: verticalPadding * 0.5),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(15),
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 10,
                                              offset: Offset(0, 5),
                                            ),
                                          ],
                                          border: Border.all(
                                            color: selectedSpecialty != null 
                                                ? Color(0xFF3366CC).withOpacity(0.3) 
                                                : Colors.grey.shade200,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<DiseaseCategory>(
                                            isExpanded: true,
                                            value: selectedSpecialty,
                                            icon: Container(
                                              padding: EdgeInsets.all(maxWidth * 0.01),
                                              decoration: BoxDecoration(
                                                color: Color(0xFF3366CC).withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                LucideIcons.chevronDown,
                                                color: Color(0xFF3366CC),
                                                size: maxWidth * 0.04,
                                              ),
                                            ),
                                            hint: Text(
                                              "Choose a specialty",
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey[600],
                                                fontSize: maxWidth * 0.035,
                                              ),
                                            ),
                                            menuMaxHeight: screenSize.height * 0.5,
                                            dropdownColor: Colors.white,
                                            elevation: 8,
                                            borderRadius: BorderRadius.circular(15),
                                            itemHeight: 48.0, // Fixed value to meet minimum requirements
                                            style: GoogleFonts.poppins(
                                              color: Colors.black87,
                                              fontSize: maxWidth * 0.035,
                                            ),
                                            items: _diseaseCategories.map((category) {
                                              return DropdownMenuItem<DiseaseCategory>(
                                                value: category,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(
                                                        color: Colors.grey.shade200,
                                                        width: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                  padding: EdgeInsets.symmetric(vertical: 5),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        padding: EdgeInsets.all(maxWidth * 0.015),
                                                        decoration: BoxDecoration(
                                                          color: category.color.withOpacity(0.1),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          category.icon,
                                                          color: category.color,
                                                          size: maxWidth * 0.05,
                                                        ),
                                                      ),
                                                      SizedBox(width: maxWidth * 0.02),
                                                      Flexible(
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment.centerLeft,
                                                          child: Text(
                                                            category.name,
                                                            style: GoogleFonts.poppins(
                                                              fontSize: maxWidth * 0.035,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                selectedSpecialty = value;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: verticalPadding * 1.2),
                              
                              // City Selection Section with enhanced design
                              TweenAnimationBuilder(
                                duration: Duration(milliseconds: 700),
                                tween: Tween<Offset>(begin: Offset(0.05, 0), end: Offset.zero),
                                builder: (context, offset, child) {
                                  return Transform.translate(
                                    offset: offset,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  margin: EdgeInsets.only(bottom: verticalPadding * 0.5),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(maxWidth * 0.025),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF4CAF50).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(maxWidth * 0.02),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Color(0xFF4CAF50).withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              LucideIcons.mapPin,
                                              color: Color(0xFF4CAF50),
                                              size: maxWidth * 0.05,
                                            ),
                                          ),
                                          SizedBox(width: maxWidth * 0.03),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                "Select City",
                                                style: GoogleFonts.poppins(
                                                  fontSize: maxWidth * 0.04,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: verticalPadding * 0.5),
                                      InkWell(
                                        onTap: () {
                                          _showCitySelectionBottomSheet(context, (city) {
                                            setState(() {
                                              selectedCity = city;
                                            });
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(15),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(15),
                                            color: Colors.white,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.05),
                                                blurRadius: 10,
                                                offset: Offset(0, 5),
                                              ),
                                            ],
                                            border: Border.all(
                                              color: selectedCity != null 
                                                  ? Color(0xFF4CAF50).withOpacity(0.3) 
                                                  : Colors.grey.shade200,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                LucideIcons.mapPin,
                                                color: Color(0xFF4CAF50),
                                                size: maxWidth * 0.05,
                                              ),
                                              SizedBox(width: maxWidth * 0.02),
                                              Expanded(
                                                child: Text(
                                                  selectedCity ?? "Choose a city",
                                                  style: GoogleFonts.poppins(
                                                    color: selectedCity != null ? Colors.black87 : Colors.grey[600],
                                                    fontSize: maxWidth * 0.035,
                                                    fontWeight: selectedCity != null ? FontWeight.w500 : FontWeight.normal,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.all(maxWidth * 0.01),
                                                decoration: BoxDecoration(
                                                  color: Color(0xFF4CAF50).withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  LucideIcons.chevronDown,
                                                  color: Color(0xFF4CAF50),
                                                  size: maxWidth * 0.04,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: verticalPadding * 1.2),
                              
                              // Gender Selection Section with enhanced design
                               TweenAnimationBuilder(
                                 duration: Duration(milliseconds: 800),
                                 tween: Tween<Offset>(begin: Offset(0.05, 0), end: Offset.zero),
                                 builder: (context, offset, child) {
                                   return Transform.translate(
                                     offset: offset,
                                     child: child,
                                   );
                                 },
                                 child: Container(
                                   margin: EdgeInsets.only(bottom: verticalPadding * 0.5),
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                        Row(
                                          children: [
                                            Container(
                                             padding: EdgeInsets.all(maxWidth * 0.025),
                                              decoration: BoxDecoration(
                                                color: Color(0xFFE91E63).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(maxWidth * 0.02),
                                               boxShadow: [
                                                 BoxShadow(
                                                   color: Color(0xFFE91E63).withOpacity(0.1),
                                                   blurRadius: 4,
                                                   offset: Offset(0, 2),
                                                 ),
                                               ],
                                              ),
                                              child: Icon(
                                                LucideIcons.users,
                                                color: Color(0xFFE91E63),
                                                size: maxWidth * 0.05,
                                              ),
                                            ),
                                            SizedBox(width: maxWidth * 0.03),
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  "Select Gender",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: maxWidth * 0.04,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: verticalPadding * 0.7),
                                        
                                       // Custom Radio Buttons for Gender with improved visuals
                                        Container(
                                          child: AspectRatio(
                                            aspectRatio: 3.5, // Maintain consistent aspect ratio
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                // All Option
                                                Expanded(
                                                 child: _buildGenderOption(
                                                   context,
                                                   icon: Icons.people,
                                                   label: "All",
                                                   color: Color(0xFF9C27B0),
                                                   isSelected: selectedGender == "All",
                                                    onTap: () {
                                                      setState(() {
                                                        selectedGender = "All";
                                                      });
                                                    },
                                                   maxWidth: maxWidth,
                                                  ),
                                                ),
                                                
                                                // Male Option
                                                Expanded(
                                                 child: _buildGenderOption(
                                                   context,
                                                   icon: Icons.male,
                                                   label: "Male",
                                                   color: Color(0xFF2196F3),
                                                   isSelected: selectedGender == "Male",
                                                    onTap: () {
                                                      setState(() {
                                                        selectedGender = "Male";
                                                      });
                                                    },
                                                   maxWidth: maxWidth,
                                                  ),
                                                ),
                                                
                                                // Female Option
                                                Expanded(
                                                 child: _buildGenderOption(
                                                   context,
                                                   icon: Icons.female,
                                                   label: "Female",
                                                   color: Color(0xFFE91E63),
                                                   isSelected: selectedGender == "Female",
                                                    onTap: () {
                                                      setState(() {
                                                        selectedGender = "Female";
                                                      });
                                                    },
                                                   maxWidth: maxWidth,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                     ],
                                   ),
                                 ),
                               ),
                              
                              SizedBox(height: verticalPadding * 1.8),
                              
                              // Search Button with enhanced design and animation
                              TweenAnimationBuilder(
                                duration: Duration(milliseconds: 900),
                                tween: Tween<double>(begin: 0.9, end: 1.0),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: child,
                                  );
                                },
                                child: Center(
                                  child: Container(
                                    width: maxWidth * 0.7,
                                    height: maxWidth * 0.12,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(maxWidth * 0.06),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF3366CC).withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.primaryTeal,
                                          Color(0xFF1A54C9), // Darker shade for depth
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(maxWidth * 0.06),
                                        splashColor: Colors.white.withOpacity(0.2),
                                        highlightColor: Colors.white.withOpacity(0.1),
                                        onTap: () {
                                          if (selectedSpecialty != null) {
                                            Navigator.pop(context, true);
                                          } else {
                                            // Show error about required selection
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Please select a specialty',
                                                  style: GoogleFonts.poppins(),
                                                ),
                                                backgroundColor: Colors.red.shade800,
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                action: SnackBarAction(
                                                  label: 'OK',
                                                  textColor: Colors.white,
                                                  onPressed: () {},
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                LucideIcons.search,
                                                color: Colors.white,
                                                size: maxWidth * 0.045,
                                              ),
                                              SizedBox(width: maxWidth * 0.02),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  "Find Doctors",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: maxWidth * 0.04,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: verticalPadding),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }
        );
      },
    ) ?? false;

    // User cancelled or dialog was dismissed
    if (!result || !context.mounted) return;
    
    // Show loading dialog with enhanced design
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54.withOpacity(0.7),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double dialogWidth = constraints.maxWidth * 0.8;
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 400),
                tween: Tween<double>(begin: 0.8, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(dialogWidth * 0.08),
                    width: dialogWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(dialogWidth * 0.08),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(dialogWidth * 0.07),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF3366CC).withOpacity(0.8),
                                Color(0xFF3366CC),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF3366CC).withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: dialogWidth * 0.08),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Finding Doctors...",
                            style: GoogleFonts.poppins(
                              fontSize: dialogWidth * 0.07,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(height: dialogWidth * 0.02),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Please wait while we search",
                            style: GoogleFonts.poppins(
                              fontSize: dialogWidth * 0.05,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    try {
      // Fetch doctors based on criteria
      await _fetchDoctorsData(
        selectedSpecialty!.name, 
        showLoading: true,
        genderFilter: selectedGender == "All" ? null : selectedGender,
        cityFilter: selectedCity
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Show enhanced error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Error finding doctors. Please try again.',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _showFindDoctorsDialog(),
            ),
          )
        );
      }
    }
  }

  // Helper method to build gender option buttons with improved design
  Widget _buildGenderOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required double maxWidth,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: EdgeInsets.symmetric(horizontal: maxWidth * 0.01),
        padding: EdgeInsets.symmetric(vertical: maxWidth * 0.02),
        decoration: BoxDecoration(
          gradient: isSelected 
              ? LinearGradient(
                  colors: [
                    color.withOpacity(0.1),
                    color.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(maxWidth * 0.025),
          border: Border.all(
            color: isSelected
                ? color
                : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 3),
            )
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: EdgeInsets.all(isSelected ? maxWidth * 0.015 : maxWidth * 0.01),
              decoration: BoxDecoration(
                color: color.withOpacity(isSelected ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: maxWidth * 0.06,
              ),
            ),
            SizedBox(height: maxWidth * 0.01),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: maxWidth * 0.03,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? color
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to show the city selection bottom sheet with all available cities
  void _showCitySelectionBottomSheet(BuildContext context, Function(String) onCitySelected) async {
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;
    
    // Get user's city before showing the sheet
    final String? userCity = await _getUserCity();
    
    // Create a sorted copy of the cities list
    List<String> displayCities = List.from(_pakistanCities);
    displayCities.sort();
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(width * 0.05),
          topRight: Radius.circular(width * 0.05),
        ),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: height * 0.8,
              ),
              padding: EdgeInsets.all(width * 0.05),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Select Location",
                        style: GoogleFonts.poppins(
                          fontSize: width * 0.05,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          LucideIcons.x,
                          size: width * 0.06,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(),
                  SizedBox(height: height * 0.01),
                  
                  // Show user's city option if available
                  if (userCity != null)
                    ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.building,
                          color: Colors.blue,
                        ),
                      ),
                      title: Text(
                        "My City ($userCity)",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        onCitySelected(userCity);
                        Navigator.pop(context);
                      },
                    ),
                  
                  if (userCity != null)
                    Divider(),
                  
                  // Search bar
                  Container(
                    margin: EdgeInsets.symmetric(vertical: height * 0.01),
                    padding: EdgeInsets.symmetric(horizontal: width * 0.03),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(width * 0.02),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search cities...",
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          LucideIcons.search, 
                          size: width * 0.05,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      onChanged: (value) {
                        // Filter the list based on search text
                        setState(() {
                          if (value.isEmpty) {
                            displayCities = List.from(_pakistanCities)..sort();
                          } else {
                            displayCities = _pakistanCities
                              .where((city) => city.toLowerCase().contains(value.toLowerCase()))
                              .toList()
                              ..sort();
                          }
                        });
                      },
                    ),
                  ),
                  
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.02, 
                      vertical: height * 0.01
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "All Cities (${displayCities.length})",
                          style: GoogleFonts.poppins(
                            fontSize: width * 0.04,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // City list
                  Expanded(
                    child: ListView.builder(
                      itemCount: displayCities.length,
                      itemBuilder: (context, index) {
                        String city = displayCities[index];
                        bool isUserCity = city == userCity;
                        
                        return ListTile(
                          leading: Icon(
                            LucideIcons.mapPin, 
                            color: isUserCity ? Colors.blue : Colors.green.shade600,
                            size: width * 0.05,
                          ),
                          title: Text(
                            city,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: width * 0.035,
                              color: Colors.black87,
                            ),
                          ),
                          trailing: isUserCity ? Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: width * 0.02,
                              vertical: height * 0.004,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(width * 0.01),
                            ),
                            child: Text(
                              "My City",
                              style: GoogleFonts.poppins(
                                fontSize: width * 0.025,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ) : null,
                          onTap: () {
                            onCitySelected(city);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

  // Helper method to build menu items
  Widget _buildMenuItem({
    required IconData icon, 
    required String title, 
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        onTap: onTap,
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
                  color: AppTheme.primaryTeal,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? AppTheme.primaryTeal : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add this method to fetch user's city
  Future<String?> _getUserCity() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final patientDoc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(user.uid)
            .get();
        
        if (patientDoc.exists) {
          final data = patientDoc.data();
          if (data != null && data['city'] != null) {
            return data['city'];
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user city: $e');
      return null;
    }
  }

  // Add this method to the class
  Future<bool> _showLogoutConfirmationDialog(BuildContext context) async {
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.05;
    final double verticalPadding = screenSize.height * 0.02;
    
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenSize.width * 0.05),
          ),
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(horizontalPadding * 0.75),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: AppTheme.error,
                    size: screenSize.width * 0.075,
                  ),
                ),
                SizedBox(height: verticalPadding),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                  "Logout",
                  style: GoogleFonts.poppins(
                      fontSize: screenSize.width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                ),
                SizedBox(height: verticalPadding * 0.5),
                Text(
                  "Are you sure you want to logout?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.035,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: verticalPadding * 1.25),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade800,
                          backgroundColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(screenSize.width * 0.03),
                          ),
                          padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.6),
                        ),
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.035,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: horizontalPadding * 0.75),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(screenSize.width * 0.03),
                          ),
                          padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.6),
                          elevation: 0,
                        ),
                        child: Text(
                          "Logout",
                          style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.035,
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
    ) ?? false;
  }
}

void showPopup(BuildContext context) {
  final Size screenSize = MediaQuery.of(context).size;
  final double horizontalPadding = screenSize.width * 0.05;
  final double verticalPadding = screenSize.height * 0.02;
  
  showDialog(
    context: context,
    barrierDismissible: false, // Already set correctly
    builder: (BuildContext context) {
      return Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 5,
              sigmaY: 5,
            ),
            child: Container(
              color: const Color.fromARGB(30, 0, 0, 0),
            ),
          ),
          AlertDialog(
            backgroundColor: const Color.fromRGBO(64, 124, 226, 1),
            title: Padding(
              padding: EdgeInsets.only(top: verticalPadding * 1.5, bottom: verticalPadding),
              child: Center(
                child: Text(
                  "Please Complete Your Profile first",
                  style: GoogleFonts.poppins(
                    fontSize: screenSize.width * 0.05, 
                    color: Colors.white
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            actions: [
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CompleteProfilePatient1Screen(),
                    ),
                  );
                },
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(screenSize.width * 0.08),
                      color: const Color.fromRGBO(217, 217, 217, 1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromRGBO(0, 0, 0, 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    width: screenSize.width * 0.25,
                    padding: EdgeInsets.symmetric(vertical: verticalPadding * 0.5),
                    child: Center(
                      child: Text(
                        "Proceed",
                        style: GoogleFonts.poppins(
                          fontSize: screenSize.width * 0.04,
                          color: Colors.black,
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
    },
  );
}


