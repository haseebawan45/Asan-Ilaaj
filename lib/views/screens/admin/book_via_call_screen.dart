import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// Admin theme colors - copied from admin_dashboard.dart for consistency
class AdminTheme {
  static const Color primaryPurple = Color(0xFF6200EA);
  static const Color lightPurple = Color(0xFFB388FF);
  static const Color accentPurple = Color(0xFF9D46FF);
  static const Color darkPurple = Color(0xFF4A148C);
  
  static LinearGradient primaryGradient = LinearGradient(
    colors: [darkPurple, primaryPurple, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// Custom Phone Number Formatter
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue
  ) {
    // If the input is being deleted, just return as is
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }
    
    String text = newValue.text.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // Handle starting with +
    if (text.isNotEmpty && text[0] == '+') {
      // For international format (+92xxxxxxxxxx)
      if (text.length > 3) {
        // Format international number with spaces after country code
        // +92 xxx xxx xxxx
        String formattedText = '+${text.substring(1, 3)}';
        
        // Add space after country code
        if (text.length > 5) {
          formattedText += ' ${text.substring(3, 6)}';
          
          // Add space after first group of digits
          if (text.length > 9) {
            formattedText += ' ${text.substring(6, 10)}';
            
            // Add remaining digits
            if (text.length > 10) {
              formattedText += ' ${text.substring(10)}';
            }
          } else if (text.length > 6) {
            formattedText += ' ${text.substring(6)}';
          }
        } else if (text.length > 3) {
          formattedText += ' ${text.substring(3)}';
        }
        
        return TextEditingValue(
          text: formattedText,
          selection: TextSelection.collapsed(offset: formattedText.length),
        );
      }
    } 
    // Handle starting with 0
    else if (text.isNotEmpty && text[0] == '0') {
      // For local format (03xxxxxxxxx)
      // Format as 03xx xxx xxxx
      String formattedText = '0';
      
      if (text.length > 4) {
        formattedText += '${text.substring(1, 4)}';
        
        if (text.length > 7) {
          formattedText += ' ${text.substring(4, 7)}';
          
          if (text.length > 7) {
            formattedText += ' ${text.substring(7)}';
          }
        } else if (text.length > 4) {
          formattedText += ' ${text.substring(4)}';
        }
      } else if (text.length > 1) {
        formattedText += '${text.substring(1)}';
      }
      
      return TextEditingValue(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length),
      );
    }
    
    // Default case
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class BookViaCallScreen extends StatefulWidget {
  const BookViaCallScreen({Key? key}) : super(key: key);

  @override
  State<BookViaCallScreen> createState() => _BookViaCallScreenState();
}

class _BookViaCallScreenState extends State<BookViaCallScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isBooking = false;
  bool _isLoadingHospitals = false;
  bool _isLoadingTimeSlots = false;
  bool _isLoadingSpecialties = false;
  bool _isLoadingCities = false;
  
  // Patient data
  Map<String, dynamic>? _patientData;
  String? _errorMessage;
  
  // Filtering data
  List<String> _specialties = [];
  List<String> _cities = [];
  String? _selectedSpecialty;
  String? _selectedCity;
  
  // Doctors data
  List<Map<String, dynamic>> _availableDoctors = [];
  Map<String, dynamic>? _selectedDoctor;
  
  // Hospital data
  List<Map<String, dynamic>> _doctorHospitals = [];
  Map<String, dynamic>? _selectedHospitalData;
  
  // Appointment data
  DateTime _selectedDate = DateTime.now().add(Duration(days: 1));
  List<String> _availableTimeSlots = [];
  String? _selectedTimeSlot;
  final TextEditingController _reasonController = TextEditingController();
  
  // Track booked time slots
  List<String> _bookedTimeSlots = [];
  
  @override
  void dispose() {
    _phoneController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
  
  String _convertToInternationalFormat(String phoneNumber) {
    // Remove any spaces, hyphens or other characters
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Check if it starts with 0
    if (phoneNumber.startsWith('0')) {
      // Remove the leading 0 and add +92 (Pakistan)
      return '+92${phoneNumber.substring(1)}';
    } 
    // If it starts with 92
    else if (phoneNumber.startsWith('92')) {
      return '+$phoneNumber';
    }
    // If it already has the + sign
    else if (phoneNumber.startsWith('+')) {
      return phoneNumber;
    }
    // Default case, assume it's without the leading zero
    else {
      return '+92$phoneNumber';
    }
  }
  
  // Search for patient by phone number
  Future<void> _searchPatient() async {
    final phoneNumber = _phoneController.text.trim();
    
    if (phoneNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a phone number';
      });
      return;
    }
    
    // Basic validation for phone number
    if (phoneNumber.length < 10 || !RegExp(r'^[0-9+\s\-\(\)]+$').hasMatch(phoneNumber)) {
      setState(() {
        _errorMessage = 'Please enter a valid phone number';
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _patientData = null;
      // Reset all filters and selections
      _specialties = [];
      _cities = [];
      _selectedSpecialty = null;
      _selectedCity = null;
      _availableDoctors = [];
      _selectedDoctor = null;
      _doctorHospitals = [];
      _selectedHospitalData = null;
      _availableTimeSlots = [];
      _selectedTimeSlot = null;
    });
    
    try {
      // Convert to international format for searching
      final internationalFormat = _convertToInternationalFormat(phoneNumber);
      
      debugPrint('Searching for patient with phone number: $internationalFormat');
      
      // Query Firestore for the patient with the given phone number
      final QuerySnapshot snapshot = await _firestore
          .collection('patients')
          .where('phoneNumber', isEqualTo: internationalFormat)
          .limit(1)
          .get();
      
      // If not found in patients collection, try the users collection
      if (snapshot.docs.isEmpty) {
        final QuerySnapshot usersSnapshot = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: internationalFormat)
            .limit(1)
            .get();
            
        if (usersSnapshot.docs.isEmpty) {
          setState(() {
            _errorMessage = 'No patient found with this phone number';
            _isSearching = false;
          });
          return;
        }
        
        // Get patient data from users collection
        final doc = usersSnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        
        setState(() {
          _patientData = {
            'id': doc.id,
            'name': data['fullName'] ?? data['name'] ?? 'Unknown',
            'email': data['email'] ?? 'N/A',
            'phone': data['phoneNumber'] ?? internationalFormat,
            'gender': data['gender'] ?? 'Not specified',
            'age': data['age'] ?? 'N/A',
            'profileImageUrl': data['profileImageUrl'],
          };
          _isSearching = false;
        });
      } else {
        // Get patient data from the first snapshot
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        
        setState(() {
          _patientData = {
            'id': doc.id,
            'name': data['fullName'] ?? data['name'] ?? 'Unknown',
            'email': data['email'] ?? 'N/A',
            'phone': data['phoneNumber'] ?? internationalFormat,
            'gender': data['gender'] ?? 'Not specified',
            'age': data['age'] ?? 'N/A',
            'profileImageUrl': data['profileImageUrl'],
          };
          _isSearching = false;
        });
      }
      
      // After finding the patient, load specialties and cities
      _loadDoctors();
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching for patient: ${e.toString()}';
        _isSearching = false;
      });
    }
  }
  
  // Calculate age from date of birth
  String _calculateAge(dynamic dob) {
    if (dob is Timestamp) {
      final DateTime birthDate = dob.toDate();
      final DateTime today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month || 
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age.toString();
    }
    return 'N/A';
  }
  
  // New method to load specialties
  Future<void> _loadSpecialties() async {
    setState(() {
      _isLoadingSpecialties = true;
      _specialties = [];
      _selectedSpecialty = null;
      _cities = [];
      _selectedCity = null;
      _availableDoctors = [];
      _selectedDoctor = null;
    });
    
    try {
      // Use the predefined list of specialties instead of querying the database
      final List<String> specialtiesList = [
        "Cardiology",
        "Neurology",
        "Dermatology",
        "Pediatrics",
        "Orthopedics",
        "ENT",
        "Gynecology",
        "Ophthalmology",
        "Dentistry",
        "Psychiatry",
        "Pulmonology",
        "Gastrology",
      ];
      
      setState(() {
        _specialties = specialtiesList;
        _isLoadingSpecialties = false;
      });
      
      // Load cities after specialties
      await _loadCities();
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading specialties: ${e.toString()}';
        _isLoadingSpecialties = false;
      });
    }
  }
  
  // New method to load cities
  Future<void> _loadCities() async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
      _selectedCity = null;
    });
    
    try {
      // Use the comprehensive predefined list of Pakistani cities
      final List<String> citiesList = [
        "Abbottabad", "Adilpur", "Ahmadpur East", "Alipur", "Arifwala", "Attock",
        "Badin", "Bahawalnagar", "Bahawalpur", "Bannu", "Battagram", "Bhakkar", "Bhalwal", "Bhera", "Bhimbar", "Bhit Shah", "Bhopalwala", "Burewala",
        "Chaman", "Charsadda", "Chichawatni", "Chiniot", "Chishtian", "Chitral", "Chunian",
        "Dadu", "Daharki", "Daska", "Dera Ghazi Khan", "Dera Ismail Khan", "Dinga", "Dipalpur", "Duki",
        "Faisalabad", "Fateh Jang", "Fazilpur", "Fort Abbas",
        "Gambat", "Ghotki", "Gilgit", "Gojra", "Gwadar",
        "Hafizabad", "Hala", "Hangu", "Haripur", "Haroonabad", "Hasilpur", "Haveli Lakha", "Hazro", "Hub", "Hyderabad",
        "Islamabad", 
        "Jacobabad", "Jahanian", "Jalalpur Jattan", "Jampur", "Jamshoro", "Jatoi", "Jauharabad", "Jhelum",
        "Kabirwala", "Kahror Pakka", "Kalat", "Kamalia", "Kamoke", "Kandhkot", "Karachi", "Karak", "Kasur", "Khairpur", "Khanewal", "Khanpur", "Kharian", "Khushab", "Kohat", "Kot Addu", "Kotri", "Kumbar", "Kunri",
        "Lahore", "Laki Marwat", "Larkana", "Layyah", "Liaquatpur", "Lodhran", "Loralai",
        "Mailsi", "Malakwal", "Mandi Bahauddin", "Mansehra", "Mardan", "Mastung", "Matiari", "Mian Channu", "Mianwali", "Mingora", "Mirpur", "Mirpur Khas", "Multan", "Muridke", "Muzaffarabad", "Muzaffargarh",
        "Narowal", "Nawabshah", "Nowshera",
        "Okara",
        "Pakpattan", "Pasrur", "Pattoki", "Peshawar", "Pir Mahal",
        "Quetta",
        "Rahimyar Khan", "Rajanpur", "Rani Pur", "Rawalpindi", "Rohri", "Risalpur",
        "Sadiqabad", "Sahiwal", "Saidu Sharif", "Sakrand", "Samundri", "Sanghar", "Sargodha", "Sheikhupura", "Shikarpur", "Sialkot", "Sibi", "Sukkur", "Swabi", "Swat",
        "Talagang", "Tandlianwala", "Tando Adam", "Tando Allahyar", "Tando Muhammad Khan", "Tank", "Taunsa", "Taxila", "Toba Tek Singh", "Turbat",
        "Vehari",
        "Wah Cantonment", "Wazirabad"
      ];
      
      setState(() {
        _cities = citiesList;
        _isLoadingCities = false;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading cities: ${e.toString()}';
        _isLoadingCities = false;
      });
    }
  }
  
  // Modified version of _loadDoctors to filter by specialty and city
  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
      _availableDoctors = [];
      _selectedDoctor = null;
      _doctorHospitals = [];
      _selectedHospitalData = null;
      _availableTimeSlots = [];
      _selectedTimeSlot = null;
    });
    
    if (_patientData == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    try {
      // First, load specialties instead of loading doctors directly
      await _loadSpecialties();
      
      // Don't load doctors here anymore - we'll load them after specialty and city selection
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing filters: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  // New method to load doctors filtered by specialty and city
  Future<void> _loadFilteredDoctors() async {
    if (_selectedSpecialty == null || _selectedCity == null) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _availableDoctors = [];
      _selectedDoctor = null;
      _doctorHospitals = [];
      _selectedHospitalData = null;
      _availableTimeSlots = [];
      _selectedTimeSlot = null;
    });
    
    try {
      // First, query doctors by specialty
      final QuerySnapshot doctorSnapshot = await _firestore
          .collection('doctors')
          .where('isActive', isEqualTo: true)
          .where('specialty', isEqualTo: _selectedSpecialty)
          .get();
      
      if (doctorSnapshot.docs.isEmpty) {
        setState(() {
          _availableDoctors = [];
          _isLoading = false;
        });
        return;
      }
      
      // Get list of doctor IDs
      List<String> doctorIds = doctorSnapshot.docs.map<String>((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['id'] ?? doc.id) as String;
      }).toList();
      
      // Next, find which of these doctors work in the selected city
      List<Map<String, dynamic>> doctors = [];
      
      // For each doctor ID, check if they have hospitals in the selected city
      for (var doctorId in doctorIds) {
        try {
          final QuerySnapshot hospitalSnapshot = await _firestore
              .collection('doctor_hospitals')
              .where('doctorId', isEqualTo: doctorId)
              .where('city', isEqualTo: _selectedCity)
              .limit(1) // We only need to know if at least one exists
              .get();
          
          // If the doctor works in this city, add them to the list
          if (hospitalSnapshot.docs.isNotEmpty) {
            // Get doctor details
            final doctorDoc = doctorSnapshot.docs.firstWhere(
              (doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['id'] ?? doc.id) == doctorId;
              },
              orElse: () => throw Exception('Doctor document not found'),
            );
            
            final data = doctorDoc.data() as Map<String, dynamic>;
            
            doctors.add({
              'id': data['id'] ?? doctorDoc.id,
              'name': data['fullName'] ?? 'Unknown',
              'specialty': data['specialty'] ?? 'General',
              'fee': data['fee'] ?? 0,
              'profileImageUrl': data['profileImageUrl'],
            });
          }
        } catch (e) {
          debugPrint('Error checking hospitals for doctor $doctorId: $e');
          // Continue with the next doctor
          continue;
        }
      }
      
      setState(() {
        _availableDoctors = doctors;
        _isLoading = false;
      });
      
      // If no doctors found that match both specialty and city
      if (doctors.isEmpty) {
        debugPrint('No doctors found for specialty: $_selectedSpecialty in city: $_selectedCity');
      }
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading doctors: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  // Load hospitals for a specific doctor
  Future<void> _loadDoctorHospitals(String doctorId) async {
    setState(() {
      _isLoadingHospitals = true;
      _doctorHospitals = [];
      _selectedHospitalData = null;
      _availableTimeSlots = [];
      _selectedTimeSlot = null;
    });
    
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('doctor_hospitals')
          .where('doctorId', isEqualTo: doctorId)
          .get();
      
      // Process hospital data
      List<Map<String, dynamic>> hospitals = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        hospitals.add({
          'hospitalId': data['hospitalId'],
          'hospitalName': data['hospitalName'],
          'city': data['city'],
        });
      }
      
      setState(() {
        _doctorHospitals = hospitals;
        _isLoadingHospitals = false;
        
        if (hospitals.isNotEmpty) {
          _selectedHospitalData = hospitals.first;
          // Load time slots for the first hospital
          _loadAvailableTimeSlots(doctorId, _selectedHospitalData!['hospitalId'], _selectedDate);
        }
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading hospitals: ${e.toString()}';
        _isLoadingHospitals = false;
      });
    }
  }
  
  // Load available time slots for a specific doctor, hospital, and date
  Future<void> _loadAvailableTimeSlots(String doctorId, String hospitalId, DateTime date) async {
    setState(() {
      _isLoadingTimeSlots = true;
      _availableTimeSlots = [];
      _bookedTimeSlots = [];
      _selectedTimeSlot = null;
    });
    
    try {
      // Format date to YYYY-MM-DD ensuring proper padding of month and day
      final String formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      debugPrint('Fetching time slots for:');
      debugPrint('Doctor ID: $doctorId');
      debugPrint('Hospital ID: $hospitalId');
      debugPrint('Date: $formattedDate');
      
      final QuerySnapshot snapshot = await _firestore
          .collection('doctor_availability')
          .where('doctorId', isEqualTo: doctorId)
          .where('hospitalId', isEqualTo: hospitalId)
          .where('date', isEqualTo: formattedDate)
          .get();
      
      debugPrint('Found ${snapshot.docs.length} availability documents');
      
      List<String> timeSlots = [];
      
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        debugPrint('Availability data: $data');
        
        if (data['timeSlots'] != null && data['timeSlots'] is List) {
          timeSlots = List<String>.from(data['timeSlots']);
          debugPrint('Retrieved time slots: $timeSlots');
        } else {
          debugPrint('No time slots found in the document or invalid format');
        }
      } else {
        debugPrint('No availability document found for the given criteria');
      }
      
      // Fetch booked appointments for this doctor, hospital and date
      await _fetchBookedAppointments(doctorId, hospitalId, formattedDate);
      
      setState(() {
        _availableTimeSlots = timeSlots;
        _isLoadingTimeSlots = false;
        
        // Filter out already booked slots
        List<String> availableSlots = timeSlots.where((slot) => !_bookedTimeSlots.contains(slot)).toList();
        
        // Only select the first time slot if it's not booked and not in the past
        if (availableSlots.isNotEmpty) {
          // Check if first slot is in the past
          bool isFirstSlotInPast = false;
          if (date.year == DateTime.now().year && 
              date.month == DateTime.now().month && 
              date.day == DateTime.now().day) {
            final firstSlotTime = _parseTimeOfDay(availableSlots.first);
            final now = TimeOfDay.now();
            isFirstSlotInPast = firstSlotTime.hour < now.hour || 
                              (firstSlotTime.hour == now.hour && firstSlotTime.minute < now.minute);
          }
          
          if (!isFirstSlotInPast) {
            _selectedTimeSlot = availableSlots.first;
          } else {
            // Find the first slot that is not in the past
            for (var slot in availableSlots) {
              final slotTime = _parseTimeOfDay(slot);
              final now = TimeOfDay.now();
              if (!(slotTime.hour < now.hour || (slotTime.hour == now.hour && slotTime.minute < now.minute))) {
                _selectedTimeSlot = slot;
                break;
              }
            }
          }
        }
      });
      
    } catch (e) {
      debugPrint('Error loading time slots: $e');
      setState(() {
        _errorMessage = 'Error loading time slots: ${e.toString()}';
        _isLoadingTimeSlots = false;
      });
    }
  }
  
  // Fetch booked appointments for a specific doctor, hospital, and date
  Future<void> _fetchBookedAppointments(String doctorId, String hospitalId, String formattedDate) async {
    try {
      List<String> bookedSlots = [];
      
      // Check appointments collection (both with isBooked field and status field for compatibility)
      
      // 1. Check using isBooked field
      final QuerySnapshot isBookedSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('hospitalId', isEqualTo: hospitalId)
          .where('date', isEqualTo: formattedDate)
          .where('isBooked', isEqualTo: true)
          .get();
      
      debugPrint('Found ${isBookedSnapshot.docs.length} appointments with isBooked=true');
      
      for (var doc in isBookedSnapshot.docs) {
        final appointmentData = doc.data() as Map<String, dynamic>;
        if (appointmentData['time'] != null && appointmentData['time'] is String) {
          bookedSlots.add(appointmentData['time']);
        }
      }
      
      // 2. Also check with status field for backward compatibility
      final QuerySnapshot appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('hospitalId', isEqualTo: hospitalId)
          .where('date', isEqualTo: formattedDate)
          .where('status', whereIn: ['Confirmed', 'pending_payment', 'In Progress'])
          .get();
      
      debugPrint('Found ${appointmentsSnapshot.docs.length} existing appointments by status');
      
      for (var doc in appointmentsSnapshot.docs) {
        final appointmentData = doc.data() as Map<String, dynamic>;
        if (appointmentData['time'] != null && appointmentData['time'] is String && 
            !bookedSlots.contains(appointmentData['time'])) {
          bookedSlots.add(appointmentData['time']);
        }
      }
      
      setState(() {
        _bookedTimeSlots = bookedSlots;
        debugPrint('Booked time slots: $_bookedTimeSlots');
      });
    } catch (e) {
      debugPrint('Error fetching booked appointments: $e');
    }
  }
  
  // Create appointment
  Future<void> _createAppointment() async {
    // Validate input
    if (_selectedDoctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a doctor')),
      );
      return;
    }
    
    if (_selectedHospitalData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a hospital')),
      );
      return;
    }
    
    if (_availableTimeSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No time slots are available. Cannot book appointment.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an available time slot')),
      );
      return;
    }
    
    // Check if selected time slot is in the past
    if (_selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day) {
      final selectedTime = _parseTimeOfDay(_selectedTimeSlot!);
      final now = TimeOfDay.now();
      
      if (selectedTime.hour < now.hour || (selectedTime.hour == now.hour && selectedTime.minute < now.minute)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot book an appointment for a time slot that has already passed.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    // Check if selected time slot is already booked
    if (_bookedTimeSlots.contains(_selectedTimeSlot)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This time slot has already been booked. Please select another time slot.'),
          backgroundColor: Colors.red,
        ),
      );
      // Refresh the available time slots
      _loadAvailableTimeSlots(_selectedDoctor!['id'], _selectedHospitalData!['hospitalId'], _selectedDate);
      return;
    }
    
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a reason for appointment')),
      );
      return;
    }
    
    setState(() {
      _isBooking = true;
    });
    
    try {
      // Generate a unique ID for the appointment
      final String appointmentId = Uuid().v4();
      
      // Parse the time slot
      final TimeOfDay timeOfDay = _parseTimeSlot(_selectedTimeSlot!);
      
      // Format date and time
      final DateTime appointmentDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );
      
      final String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      // Create appointment data
      final Map<String, dynamic> appointmentData = {
        'id': appointmentId,
        'doctorId': _selectedDoctor!['id'],
        'patientId': _patientData!['id'],
        'status': 'Confirmed', // Set as confirmed since admin is booking
        'date': formattedDate,
        'time': _selectedTimeSlot,
        'appointmentDate': Timestamp.fromDate(appointmentDateTime),
        'created': Timestamp.now(),
        'reason': _reasonController.text.trim(),
        'fee': _selectedDoctor!['fee'],
        'hospital': _selectedHospitalData!['hospitalName'],
        'hospitalId': _selectedHospitalData!['hospitalId'],
        'hospitalName': _selectedHospitalData!['hospitalName'],
        'hospitalLocation': _selectedHospitalData!['city'] ?? '',
        'specialty': _selectedDoctor!['specialty'],
        'type': 'In-person',
        'bookedBy': 'admin',
        'paymentStatus': 'Pending', // Set payment status as pending
        'notes': 'Booked via customer service call',
        'isBooked': true, // Add isBooked field to mark the appointment as booked
        'completed': false, // Add completed field set to false for the new appointment
      };
      
      // Save to Firestore
      await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .set(appointmentData);
      
      // Reset the form
      setState(() {
        _isBooking = false;
        _patientData = null;
        _selectedDoctor = null;
        _doctorHospitals = [];
        _selectedHospitalData = null;
        _availableTimeSlots = [];
        _selectedTimeSlot = null;
        _phoneController.clear();
        _reasonController.clear();
        _selectedDate = DateTime.now().add(Duration(days: 1));
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment booked successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      setState(() {
        _isBooking = false;
        _errorMessage = 'Error booking appointment: ${e.toString()}';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error booking appointment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Parse time slot string (e.g., "08:00 PM") to TimeOfDay
  TimeOfDay _parseTimeSlot(String timeSlot) {
    final time = DateFormat('hh:mm a').parse(timeSlot);
    return TimeOfDay(hour: time.hour, minute: time.minute);
  }
  
  // Helper method to parse time string into TimeOfDay
  TimeOfDay _parseTimeOfDay(String timeString) {
    final components = timeString.split(' ');
    final timeComponents = components[0].split(':');
    int hour = int.parse(timeComponents[0]);
    final minute = int.parse(timeComponents[1]);
    final isPM = components[1].toUpperCase() == 'PM';
    
    if (isPM && hour != 12) {
      hour += 12;
    } else if (!isPM && hour == 12) {
      hour = 0;
    }
    
    return TimeOfDay(hour: hour, minute: minute);
  }
  
  // Fallback method to load all doctors if no filtered results
  Future<void> _loadAllDoctorsInCity() async {
    if (_selectedCity == null) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _availableDoctors = [];
      _selectedDoctor = null;
      _doctorHospitals = [];
      _selectedHospitalData = null;
      _availableTimeSlots = [];
      _selectedTimeSlot = null;
    });
    
    try {
      // First, find all hospitals in the selected city
      final QuerySnapshot hospitalSnapshot = await _firestore
          .collection('doctor_hospitals')
          .where('city', isEqualTo: _selectedCity)
          .get();
      
      if (hospitalSnapshot.docs.isEmpty) {
        setState(() {
          _availableDoctors = [];
          _isLoading = false;
        });
        return;
      }
      
      // Get unique doctor IDs from the hospitals
      Set<String> doctorIdSet = Set<String>();
      for (var doc in hospitalSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['doctorId'] != null) {
          doctorIdSet.add(data['doctorId'] as String);
        }
      }
      
      List<String> doctorIds = doctorIdSet.toList();
      
      // Next, get doctor details for each ID
      List<Map<String, dynamic>> doctors = [];
      
      for (var doctorId in doctorIds) {
        try {
          // Get doctor details from Firestore
          final doctorDoc = await _firestore
              .collection('doctors')
              .where('id', isEqualTo: doctorId)
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();
          
          if (doctorDoc.docs.isNotEmpty) {
            final data = doctorDoc.docs.first.data() as Map<String, dynamic>;
            
            doctors.add({
              'id': data['id'] ?? doctorDoc.docs.first.id,
              'name': data['fullName'] ?? 'Unknown',
              'specialty': data['specialty'] ?? 'General',
              'fee': data['fee'] ?? 0,
              'profileImageUrl': data['profileImageUrl'],
            });
          }
        } catch (e) {
          debugPrint('Error loading doctor $doctorId: $e');
          // Continue with the next doctor
          continue;
        }
      }
      
      setState(() {
        _availableDoctors = doctors;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading doctors: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  // Update the dropdown selector to show a message and option when no doctors found
  Widget _buildNoDoctorsFoundMessage() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No doctors found for ${_selectedSpecialty} in ${_selectedCity}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Would you like to see all doctors available in ${_selectedCity} regardless of specialty?',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.orange.shade800,
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  // Reset specialty selection but keep city
                  setState(() {
                    _selectedSpecialty = null;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                ),
                child: Text('Cancel'),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _loadAllDoctorsInCity();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primaryPurple,
                  foregroundColor: Colors.white,
                ),
                child: Text('Show All Doctors'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Helper method to check if any doctors are available
  Future<bool> _checkDoctorsAvailability() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('doctors')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking doctors availability: $e');
      return false;
    }
  }
  
  // Helper method to get specialty name if it's not in the predefined list
  String _getSpecialtyDisplayName(String? specialty) {
    if (specialty == null) return 'Unknown';
    
    // Check if the specialty is one of our predefined ones
    if (_specialties.contains(specialty)) {
      return specialty;
    }
    
    // If not, try to format it nicely
    String displayName = specialty.trim();
    if (displayName.isEmpty) return 'General';
    
    // Convert first letter to uppercase
    return displayName[0].toUpperCase() + displayName.substring(1);
  }
  
  // Helper UI to handle error states gracefully
  Widget _buildErrorState(String message, {VoidCallback? onRetry}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.red.shade800,
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primaryPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Book via Call',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              AdminTheme.lightPurple.withOpacity(0.1),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Introduction
              Container(
                decoration: BoxDecoration(
                  gradient: AdminTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AdminTheme.primaryPurple.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone_in_talk, color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Book via Phone Call',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Enter the patient\'s phone number to start booking an appointment for them. Select a doctor, hospital, and available time slot for the consultation.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 30),
              
              // Patient Search Form
              Text(
                'Search Patient by Phone Number',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              hintText: 'Enter phone number (e.g., 03001234567)',
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(Icons.phone, color: AdminTheme.primaryPurple),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AdminTheme.primaryPurple, width: 1.5),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              PhoneNumberFormatter(),
                              LengthLimitingTextInputFormatter(15),
                            ],
                            style: GoogleFonts.poppins(
                              color: Color(0xFF333333),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isSearching ? null : _searchPatient,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primaryPurple,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 3,
                            shadowColor: AdminTheme.primaryPurple.withOpacity(0.5),
                          ),
                          child: _isSearching
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Search',
                                  style: GoogleFonts.poppins(
                                  color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 8),
                    Text(
                      'Enter a phone number in local format (03001234567) or international format (+923001234567)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    
                    if (_errorMessage != null) ...[
                      SizedBox(height: 16),
                      _buildErrorState(
                        _errorMessage!,
                        onRetry: _searchPatient,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Patient Details
              if (_patientData != null) ...[
                SizedBox(height: 36),
                Row(
                  children: [
                    Icon(Icons.person, color: AdminTheme.primaryPurple),
                    SizedBox(width: 8),
                    Text(
                      'Patient Details',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Patient avatar
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AdminTheme.primaryPurple, width: 2),
                              color: Colors.white,
                            ),
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: AdminTheme.lightPurple.withOpacity(0.5),
                              backgroundImage: _patientData!['profileImageUrl'] != null
                                  ? NetworkImage(_patientData!['profileImageUrl'])
                                  : null,
                              child: _patientData!['profileImageUrl'] == null
                                  ? Text(
                                      _patientData!['name'].toString().substring(0, 1),
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        color: AdminTheme.primaryPurple,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 20),
                      // Patient info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _patientData!['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF333333),
                              ),
                            ),
                            SizedBox(height: 16),
                            _buildInfoRow(
                              Icons.email,
                              'Email',
                              _patientData!['email'],
                              Colors.blue.shade700,
                            ),
                            SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.phone,
                              'Phone',
                              _patientData!['phone'],
                              Colors.green.shade700,
                            ),
                            SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.person,
                              'Gender',
                              _patientData!['gender'],
                              Colors.purple.shade700,
                            ),
                            SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.cake,
                              'Age',
                              _patientData!['age'],
                              Colors.orange.shade700,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Appointment Booking Form
                SizedBox(height: 36),
                Row(
                  children: [
                    Icon(Icons.calendar_month, color: AdminTheme.primaryPurple),
                    SizedBox(width: 8),
                    Text(
                      'Appointment Details',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filter badges
                      if (_selectedSpecialty != null || _selectedCity != null) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_selectedSpecialty != null)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AdminTheme.lightPurple.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AdminTheme.primaryPurple.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.medical_services,
                                      size: 16,
                                      color: AdminTheme.primaryPurple,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      _selectedSpecialty!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AdminTheme.primaryPurple,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedSpecialty = null;
                                          _selectedCity = null;
                                          _availableDoctors = [];
                                          _selectedDoctor = null;
                                          _doctorHospitals = [];
                                          _selectedHospitalData = null;
                                          _availableTimeSlots = [];
                                          _selectedTimeSlot = null;
                                        });
                                      },
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: AdminTheme.primaryPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_selectedCity != null)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AdminTheme.lightPurple.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AdminTheme.primaryPurple.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_city,
                                      size: 16,
                                      color: AdminTheme.primaryPurple,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      _selectedCity!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AdminTheme.primaryPurple,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedCity = null;
                                          _availableDoctors = [];
                                          _selectedDoctor = null;
                                          _doctorHospitals = [];
                                          _selectedHospitalData = null;
                                          _availableTimeSlots = [];
                                          _selectedTimeSlot = null;
                                        });
                                      },
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: AdminTheme.primaryPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Reset all filters button
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedSpecialty = null;
                                  _selectedCity = null;
                                  _availableDoctors = [];
                                  _selectedDoctor = null;
                                  _doctorHospitals = [];
                                  _selectedHospitalData = null;
                                  _availableTimeSlots = [];
                                  _selectedTimeSlot = null;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey.shade400),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh,
                                      size: 16,
                                      color: Colors.grey.shade700,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Reset Filters',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                      ],
                      
                      // Specialty Selection
                      Text(
                        'Select Specialty',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF444444),
                        ),
                      ),
                      SizedBox(height: 10),
                      
                      if (_isLoadingSpecialties)
                        Center(
                          child: CircularProgressIndicator(
                            color: AdminTheme.primaryPurple,
                          ),
                        )
                      else if (_specialties.isEmpty)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red),
                              SizedBox(width: 12),
                              Text(
                                'No specialties available',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Select a specialty',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              value: _selectedSpecialty,
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              borderRadius: BorderRadius.circular(10),
                              icon: Icon(Icons.keyboard_arrow_down, color: AdminTheme.primaryPurple),
                              items: _specialties.map((specialty) {
                                return DropdownMenuItem<String>(
                                  value: specialty,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.medical_services, 
                                        color: AdminTheme.primaryPurple,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        specialty,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedSpecialty = value;
                                    // Reset city, doctor and hospital selections
                                    _selectedCity = null;
                                    _selectedDoctor = null;
                                    _selectedHospitalData = null;
                                    _availableTimeSlots = [];
                                    _selectedTimeSlot = null;
                                  });
                                  // Don't load filtered doctors yet since we still need city
                                }
                              },
                            ),
                          ),
                        ),
                      
                      SizedBox(height: 20),
                      
                      // City Selection - show only if specialty is selected
                      if (_selectedSpecialty != null) ...[
                        Text(
                          'Select City',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF444444),
                          ),
                        ),
                        SizedBox(height: 10),
                        
                        if (_isLoadingCities)
                          Center(
                            child: CircularProgressIndicator(
                              color: AdminTheme.primaryPurple,
                            ),
                          )
                        else if (_cities.isEmpty)
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red),
                                SizedBox(width: 12),
                                Text(
                                  'No cities available',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                hint: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'Select a city',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                value: _selectedCity,
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                borderRadius: BorderRadius.circular(10),
                                icon: Icon(Icons.keyboard_arrow_down, color: AdminTheme.primaryPurple),
                                items: _cities.map((city) {
                                  return DropdownMenuItem<String>(
                                    value: city,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_city, 
                                          color: AdminTheme.primaryPurple,
                                          size: 20,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          city,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Color(0xFF333333),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedCity = value;
                                      // Reset doctor and hospital selections
                                      _selectedDoctor = null;
                                      _selectedHospitalData = null;
                                      _availableTimeSlots = [];
                                      _selectedTimeSlot = null;
                                    });
                                    // Now we can load doctors filtered by specialty and city
                                    _loadFilteredDoctors();
                                  }
                                },
                              ),
                            ),
                          ),
                          
                        SizedBox(height: 20),
                      ],
                      
                      // Doctor Selection - show only if specialty and city are selected
                      if (_selectedCity != null && _selectedSpecialty != null) ...[
                        Text(
                          'Select Doctor',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF444444),
                          ),
                        ),
                        SizedBox(height: 10),
                        
                        if (_isLoading)
                          Center(
                            child: CircularProgressIndicator(
                              color: AdminTheme.primaryPurple,
                            ),
                          )
                        else if (_availableDoctors.isEmpty)
                          _buildNoDoctorsFoundMessage()
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Map<String, dynamic>>(
                                isExpanded: true,
                                hint: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'Select a doctor',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                value: _selectedDoctor,
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                borderRadius: BorderRadius.circular(10),
                                icon: Icon(Icons.keyboard_arrow_down, color: AdminTheme.primaryPurple),
                                items: _availableDoctors.map((doctor) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: doctor,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: AdminTheme.lightPurple.withOpacity(0.5),
                                          backgroundImage: doctor['profileImageUrl'] != null
                                              ? NetworkImage(doctor['profileImageUrl'])
                                              : null,
                                          child: doctor['profileImageUrl'] == null
                                              ? Text(
                                                  doctor['name'].toString().substring(0, 1),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AdminTheme.primaryPurple,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                doctor['name'],
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                  color: Color(0xFF333333),
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                '${doctor['specialty']} - Rs. ${doctor['fee']}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedDoctor = value;
                                    });
                                    // Load hospitals for this doctor
                                    _loadDoctorHospitals(value['id']);
                                  }
                                },
                              ),
                            ),
                          ),
                      
                        SizedBox(height: 20),
                      ],
                      
                      // Hospital Selection
                      if (_selectedDoctor != null) ...[
                        Text(
                          'Select Hospital',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF444444),
                          ),
                        ),
                        SizedBox(height: 10),
                        
                        if (_isLoadingHospitals)
                          Center(
                            child: CircularProgressIndicator(
                              color: AdminTheme.primaryPurple,
                            ),
                          )
                        else if (_doctorHospitals.isEmpty)
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No hospitals available for this doctor',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Map<String, dynamic>>(
                                isExpanded: true,
                                value: _selectedHospitalData,
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                borderRadius: BorderRadius.circular(10),
                                icon: Icon(Icons.keyboard_arrow_down, color: AdminTheme.primaryPurple),
                                items: _doctorHospitals.map((hospital) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: hospital,
                                    child: Row(
                                      children: [
                                        Icon(Icons.local_hospital, color: AdminTheme.primaryPurple),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            hospital['hospitalName'],
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Color(0xFF333333),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedHospitalData = value;
                                    });
                                    // Load time slots for this hospital and date
                                    _loadAvailableTimeSlots(_selectedDoctor!['id'], value['hospitalId'], _selectedDate);
                                  }
                                },
                              ),
                            ),
                          ),
                        
                        SizedBox(height: 20),
                      ],
                      
                      // Date Selection
                      if (_selectedHospitalData != null) ...[
                        Text(
                          'Select Date',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF444444),
                          ),
                        ),
                        SizedBox(height: 10),
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(Duration(days: 90)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: AdminTheme.primaryPurple,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            
                            if (picked != null && picked != _selectedDate) {
                              setState(() {
                                _selectedDate = picked;
                              });
                              // Load time slots for this new date
                              _loadAvailableTimeSlots(_selectedDoctor!['id'], _selectedHospitalData!['hospitalId'], picked);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, color: AdminTheme.primaryPurple, size: 20),
                                    SizedBox(width: 12),
                                    Text(
                                      DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(Icons.keyboard_arrow_down, color: AdminTheme.primaryPurple),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 20),
                      ],
                      
                      // Time Slot Selection
                      if (_selectedHospitalData != null) ...[
                        Text(
                          'Select Time Slot',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF444444),
                          ),
                        ),
                        SizedBox(height: 10),
                        
                        if (_isLoadingTimeSlots)
                          Center(
                            child: CircularProgressIndicator(
                              color: AdminTheme.primaryPurple,
                            ),
                          )
                        else if (_availableTimeSlots.isEmpty)
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.access_time, color: Colors.orange.shade800),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No Time Slots Available',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'There are no time slots available for this doctor at this hospital on the selected date. Please select a different date or contact the doctor to set up availability.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Time slots must be manually added to the doctor\'s schedule in the doctor_availability collection.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available Time Slots',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 12,
                                children: _availableTimeSlots.map((time) {
                                  final isSelected = time == _selectedTimeSlot;
                                  
                                  // Check if this slot is in the past
                                  bool isPastTime = false;
                                  
                                  // Only check against current time if the selected date is today
                                  if (_selectedDate.year == DateTime.now().year &&
                                      _selectedDate.month == DateTime.now().month &&
                                      _selectedDate.day == DateTime.now().day) {
                                      
                                    final timeOfDay = _parseTimeOfDay(time);
                                    final now = TimeOfDay.now();
                                    
                                    isPastTime = timeOfDay.hour < now.hour || 
                                              (timeOfDay.hour == now.hour && 
                                               timeOfDay.minute < now.minute);
                                  }
                                  
                                  // Check if slot is already booked
                                  final isBooked = _bookedTimeSlots.contains(time);
                                  
                                  // Whether this slot is available
                                  final isAvailable = !isPastTime && !isBooked;
                                  
                                  return InkWell(
                                    onTap: isAvailable 
                                        ? () {
                                            setState(() {
                                              _selectedTimeSlot = time;
                                            });
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: !isAvailable 
                                            ? Colors.grey.shade200
                                            : isSelected
                                                ? AdminTheme.primaryPurple
                                                : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: !isAvailable
                                              ? Colors.grey.shade300
                                              : isSelected
                                                  ? AdminTheme.primaryPurple
                                                  : Colors.grey.shade200,
                                        ),
                                        boxShadow: isSelected && isAvailable
                                            ? [
                                                BoxShadow(
                                                  color: AdminTheme.primaryPurple.withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: Offset(0, 2),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Text(
                                        time,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          color: !isAvailable
                                              ? Colors.grey.shade500
                                              : isSelected
                                                  ? Colors.white
                                                  : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Grayed out time slots are either already booked or in the past (for today\'s appointments only).',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        
                        SizedBox(height: 20),
                      ],
                      
                      // Reason for Appointment
                      if (_selectedHospitalData != null) ...[
                        Text(
                          'Reason for Appointment',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF444444),
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _reasonController,
                            decoration: InputDecoration(
                              hintText: 'Enter reason for appointment',
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(Icons.edit, color: AdminTheme.primaryPurple),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Color(0xFF333333),
                            ),
                            maxLines: 3,
                          ),
                        ),
                        
                        SizedBox(height: 30),
                        
                        // Book Appointment Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_isBooking || _availableTimeSlots.isEmpty) ? null : _createAppointment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.primaryPurple,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 3,
                              shadowColor: AdminTheme.primaryPurple.withOpacity(0.5),
                              disabledBackgroundColor: AdminTheme.primaryPurple.withOpacity(0.6),
                            ),
                            child: _isBooking
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Booking...',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle),
                                      SizedBox(width: 12),
                                      Text(
                                        _availableTimeSlots.isEmpty
                                            ? 'No Available Time Slots'
                                            : 'Book Appointment',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value, Color iconColor) {
    // Special handling for phone number to add call button
    if (icon == Icons.phone) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
            SizedBox(width: 12),
            Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Color(0xFF333333),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != 'N/A' && value.isNotEmpty)
              GestureDetector(
                onTap: () => _makePhoneCall(value),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.call,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    
    // Default row for other info types
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
          SizedBox(width: 12),
          Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  // Function to make a phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot launch phone dialer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error launching phone dialer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 