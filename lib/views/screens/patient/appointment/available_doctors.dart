import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/views/screens/patient/appointment/appointment_booking_flow.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:healthcare/views/screens/patient/appointment/simplified_booking_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class DoctorsScreen extends StatefulWidget {
  final String? specialty;
  final List<Map<String, dynamic>> doctors;
  final String? initialGenderFilter;

  const DoctorsScreen({
    Key? key, 
    this.specialty,
    this.doctors = const [],
    this.initialGenderFilter,
  }) : super(key: key);

  @override
  _DoctorsScreenState createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  late List<Map<String, dynamic>> filteredDoctors;
  bool _isLoading = true;
  bool _isRefreshing = false; // Add this for LinearProgressIndicator
  String? _errorMessage;
  
  // Firestore and Auth instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Filtering options
  int _selectedCategoryIndex = 0;
  String? selectedRating;
  String? selectedLocation;
  String? selectedGender;
  String? selectedSpecialty;
  bool sortByPriceLowToHigh = false;
  bool showOnlyInMyCity = false;
  String? userCity;
  Color genderColor = Colors.grey;
  
  // Cache keys
  static const String DOCTORS_CACHE_KEY = 'cached_doctors_data';
  static const String CACHE_TIMESTAMP_KEY = 'doctors_cache_timestamp';
  
  // Available filter categories
  final List<String> _categories = ["All", "Cardiology", "Neurology", "Dermatology", "Orthopedics", "ENT", "Pediatrics", "Gynecology", "Ophthalmology", "Dentistry", "Psychiatry", "Pulmonology", "Gastrology"];
  
  // Comprehensive list of Pakistani cities
  final List<String> _pakistaniCities = [
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
  
  // Available cities for filtering (will be populated from doctors data)
  List<String> availableCities = [];

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // Initialize filters
    filteredDoctors = [];
    selectedGender = widget.initialGenderFilter; // Set initial gender filter
    
    // If a specific specialty is provided, set the category index and selected specialty
    if (widget.specialty != null && widget.specialty != "All") {
      // If specialty is provided directly from home screen, 
      // we'll fetch only those doctors and won't show the category tabs
      _selectedCategoryIndex = _categories.indexOf(widget.specialty!);
      if (_selectedCategoryIndex == -1) {
        // If specialty is not in our predefined list, add it
        _categories.add(widget.specialty!);
        _selectedCategoryIndex = _categories.indexOf(widget.specialty!);
      }
      // Set selectedSpecialty to widget.specialty initially but allow it to be changed by filters later
      selectedSpecialty = widget.specialty;
    }
    
    // Debug to verify Pakistani cities are loaded
    print("Pakistani cities list has ${_pakistaniCities.length} cities");
    
    // Load cached data, then fetch fresh data
    _loadCachedDataAndFetchFresh();
  }

  // Check if cached data is stale (older than the specified duration)
  Future<bool> _isCacheStale({Duration staleDuration = const Duration(minutes: 15)}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? timestamp = prefs.getInt(CACHE_TIMESTAMP_KEY);
      
      if (timestamp == null) {
        return true; // No timestamp means cache is stale or doesn't exist
      }
      
      final DateTime cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final DateTime now = DateTime.now();
      
      return now.difference(cacheTime) > staleDuration;
    } catch (e) {
      debugPrint('Error checking cache staleness: $e');
      return true; // On error, assume cache is stale to be safe
    }
  }
  
  // Load cached data and fetch fresh data in the background
  Future<void> _loadCachedDataAndFetchFresh() async {
    try {
      // First, get user's city
      await _fetchUserCity();
      
      // Load cached data
      await _loadCachedData();
      
      // Check if we need to refresh the data
      bool needsRefresh = await _isCacheStale();
      
      // If we have no doctors or cache is stale, fetch fresh data
      if (filteredDoctors.isEmpty || needsRefresh) {
        _fetchDoctorsWithRefresh();
      } else {
        // Even if cache is not stale, still refresh data silently after a delay
        // to ensure the user has up-to-date information for their next interaction
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            _fetchDoctorsWithRefresh();
          }
        });
      }
    } catch (e) {
      debugPrint('Error in cache and fetch flow: $e');
      // Fallback to direct fetch if something goes wrong
      _fetchDoctors();
    }
  }

  // Load doctors data from cache
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString(DOCTORS_CACHE_KEY);
      
      if (cachedData != null) {
        final List<dynamic> decodedData = jsonDecode(cachedData);
        final List<Map<String, dynamic>> doctorsList = decodedData
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        
        if (mounted) {
          setState(() {
            if (doctorsList.isNotEmpty) {
              filteredDoctors = doctorsList;
              _isLoading = false; // Stop loading if we have cached data
              _extractAvailableCities(); // Extract cities from cached data
              
              // Apply filters to cached data but without fetching new data
              _applyCachedFilters();
            }
          });
        }
        
        debugPrint('Loaded ${doctorsList.length} doctors from cache');
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
      // If cache loading fails, we'll still have fresh data loading
    }
  }
  
  // Apply filters to cached data without fetching from Firebase
  void _applyCachedFilters() {
    try {
      // Apply client-side filters
      List<Map<String, dynamic>> result = List.from(filteredDoctors);
    
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        result = result.where((doctor) {
          return doctor['name'].toString().toLowerCase().contains(_searchQuery) ||
                doctor['specialty'].toString().toLowerCase().contains(_searchQuery) ||
                doctor['location'].toString().toLowerCase().contains(_searchQuery) ||
                doctor['city'].toString().toLowerCase().contains(_searchQuery);
        }).toList();
      }
      
      // Apply specialty filter
      if (selectedSpecialty != null && selectedSpecialty != "All") {
        result = result.where((doctor) => 
          doctor['specialty'] == selectedSpecialty).toList();
      } else if (_selectedCategoryIndex > 0) {
        final selectedCategory = _categories[_selectedCategoryIndex];
        result = result.where((doctor) => 
          doctor['specialty'] == selectedCategory).toList();
      }
      
      // Apply gender filter
      if (selectedGender != null) {
        result = result.where((doctor) => 
          doctor['gender'] == selectedGender).toList();
      }
      
      // Apply city filter
      if (showOnlyInMyCity && userCity != null) {
        result = result.where((doctor) => 
          doctor['city'] == userCity).toList();
      } else if (selectedLocation != null && selectedLocation!.isNotEmpty) {
        result = result.where((doctor) => 
          doctor['city'] == selectedLocation).toList();
      }
      
      // Apply rating filter
      if (selectedRating != null) {
        final minRating = double.parse(selectedRating!.replaceAll('+', ''));
        result = result.where((doctor) {
          double rating;
          try {
            rating = double.parse(doctor['rating'].toString());
          } catch (e) {
            rating = 0.0;
          }
          return rating >= minRating;
        }).toList();
      }
      
      // Apply sorting
      if (sortByPriceLowToHigh) {
        result.sort((a, b) {
          // Extract fee as numeric value (remove "Rs " and parse)
          double aFee = 0.0;
          double bFee = 0.0;
          try {
            aFee = double.parse(a['fee'].toString().replaceAll('Rs ', ''));
            bFee = double.parse(b['fee'].toString().replaceAll('Rs ', ''));
          } catch (e) {
            // Handle parsing error
          }
          return aFee.compareTo(bFee);
        });
      } else {
        // Sort by rating (highest first)
        result.sort((a, b) {
          double aRating = 0.0;
          double bRating = 0.0;
          try {
            aRating = double.parse(a['rating'].toString());
            bRating = double.parse(b['rating'].toString());
          } catch (e) {
            // Handle parsing error
          }
          return bRating.compareTo(aRating);
        });
      }
      
      if (mounted) {
        setState(() {
          filteredDoctors = result;
        });
      }
    } catch (e) {
      debugPrint('Error applying cached filters: $e');
    }
  }
  
  // Cache the doctors data
  Future<void> _cacheDoctorsData(List<Map<String, dynamic>> doctors) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove complex objects like large lists of hospitals to make caching faster
      final List<Map<String, dynamic>> simplifiedDoctors = doctors.map((doctor) {
        Map<String, dynamic> simplified = Map.from(doctor);
        // Remove or simplify complex nested objects to make JSON serialization easier
        if (simplified.containsKey('hospitals')) {
          // Keep just essential hospital data
          List<Map<String, dynamic>> hospitals = List<Map<String, dynamic>>.from(simplified['hospitals']);
          if (hospitals.isNotEmpty) {
            simplified['hospitalCount'] = hospitals.length;
            simplified['primaryHospital'] = hospitals.first['hospitalName'];
            // Remove the full list
            simplified.remove('hospitals');
          }
        }
        return simplified;
      }).toList();
      
      final String encodedData = jsonEncode(simplifiedDoctors);
      
      await prefs.setString(DOCTORS_CACHE_KEY, encodedData);
      await prefs.setInt(CACHE_TIMESTAMP_KEY, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('Cached ${doctors.length} doctors');
    } catch (e) {
      debugPrint('Error caching doctors data: $e');
    }
  }
  
  // Fetch fresh data with refresh indicator
  Future<void> _fetchDoctorsWithRefresh() async {
    if (mounted) {
      setState(() {
        _isRefreshing = true; // Show the LinearProgressIndicator
      });
    }
    
    try {
      await _fetchDoctors(shouldCache: true);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false; // Hide the LinearProgressIndicator
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
    
    // Debounce search to avoid too many Firestore calls
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _applyFilters();
    });
  }

  // Fetch the user's city from Firestore
  Future<void> _fetchUserCity() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get user data from patients collection
        final patientDoc = await _firestore.collection('patients').doc(user.uid).get();
        
        if (patientDoc.exists) {
          final data = patientDoc.data();
          if (data != null && data['city'] != null) {
            setState(() {
              userCity = data['city'];
              debugPrint('User city found: $userCity');
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching user city: $e');
    }
  }

  // Modified to support caching
  Future<void> _fetchDoctors({bool shouldCache = false}) async {
    if (!shouldCache) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    
    try {
      // If we already have doctors from the widget parameter and a specialty is specified,
      // just use those directly instead of fetching from Firestore
      if (widget.doctors.isNotEmpty && widget.specialty != null && widget.specialty != "All") {
        if (mounted) {
          setState(() {
            filteredDoctors = List.from(widget.doctors);
            _isLoading = false;
            _isRefreshing = false;
            _extractAvailableCities(); // Extract cities from the doctors list
            _applyFilters();
          });
          
          // Cache these doctors if requested
          if (shouldCache) {
            _cacheDoctorsData(filteredDoctors);
          }
        }
        return;
      }
      
      final List<Map<String, dynamic>> doctorsList = [];
      
      // Query doctors collection
      Query doctorsQuery = _firestore.collection('doctors');
      
      // Apply specialty filter if specified
      if (widget.specialty != null && widget.specialty != "All") {
        doctorsQuery = doctorsQuery.where('specialty', isEqualTo: widget.specialty);
      }
      
      // Apply gender filter if specified
      if (selectedGender != null) {
        doctorsQuery = doctorsQuery.where('gender', isEqualTo: selectedGender);
      }
      
      final QuerySnapshot doctorsSnapshot = await doctorsQuery.get();
      
      // Process each doctor document
      for (var doc in doctorsSnapshot.docs) {
        final doctorData = doc.data() as Map<String, dynamic>;
        final doctorId = doc.id;
        
        // Get doctor's hospitals and availability
        final hospitalsQuery = await _firestore
            .collection('doctor_hospitals')
            .where('doctorId', isEqualTo: doctorId)
            .get();
        
        final List<Map<String, dynamic>> hospitalsList = [];
        
        // For each hospital, get today's availability
        for (var hospitalDoc in hospitalsQuery.docs) {
          final hospitalData = hospitalDoc.data();
          final hospitalId = hospitalData['hospitalId'];
          final hospitalName = hospitalData['hospitalName'] ?? 'Unknown Hospital';
          
          // Get today's date in YYYY-MM-DD format
          final today = DateTime.now();
          final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          
          // Query availability for this hospital and date
          final availabilityQuery = await _firestore
              .collection('doctor_availability')
              .where('doctorId', isEqualTo: doctorId)
              .where('hospitalId', isEqualTo: hospitalId)
              .where('date', isEqualTo: dateStr)
              .limit(1)
              .get();
          
          List<String> timeSlots = [];
          if (availabilityQuery.docs.isNotEmpty) {
            final availabilityData = availabilityQuery.docs.first.data();
            timeSlots = List<String>.from(availabilityData['timeSlots'] ?? []);
          }
          
          hospitalsList.add({
            'hospitalId': hospitalId,
            'hospitalName': hospitalName,
            'availableToday': timeSlots.isNotEmpty,
            'timeSlots': timeSlots,
          });
        }
        
        // Determine overall availability
        final bool isAvailableToday = hospitalsList.any((hospital) => hospital['availableToday'] == true);
        
        // Create doctor map with all relevant information
        doctorsList.add({
          'id': doctorId,
          'name': doctorData['fullName'] ?? doctorData['name'] ?? 'Unknown Doctor',
          'specialty': doctorData['specialty'] ?? 'General Practitioner',
          'rating': doctorData['rating']?.toString() ?? "0.0",
          'experience': doctorData['experience']?.toString() ?? "0 years",
          'fee': 'Rs ${doctorData['fee']?.toString() ?? "0"}',
          'location': hospitalsList.isNotEmpty ? hospitalsList.first['hospitalName'] : 'Multiple Hospitals',
          'image': doctorData['profileImageUrl'] ?? "assets/images/User.png",
          'available': isAvailableToday,
          'hospitals': hospitalsList,
          'gender': doctorData['gender'] ?? 'Not specified',
          'city': doctorData['city'] ?? '',
        });
      }
      
      if (mounted) {
        setState(() {
          if (doctorsList.isEmpty && widget.doctors.isNotEmpty) {
            // If no doctors from Firestore but we have doctors from widget
            filteredDoctors = List.from(widget.doctors);
          } else {
            // Use doctors from Firestore
            filteredDoctors = doctorsList;
          }
          _isLoading = false;
          _isRefreshing = false;
          _extractAvailableCities(); // Extract cities from the doctors list
          _applyFilters();
        });
        
        // Cache doctors if requested and we have data
        if (shouldCache && (doctorsList.isNotEmpty || widget.doctors.isNotEmpty)) {
          _cacheDoctorsData(filteredDoctors);
        }
      }
    } catch (e) {
      // Handle errors
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading doctors: $e';
          _isLoading = false;
          _isRefreshing = false;
          
          // If we have doctors from widget parameter, use those
          if (widget.doctors.isNotEmpty) {
            filteredDoctors = List.from(widget.doctors);
            _extractAvailableCities(); // Try to extract cities even in error case
            _applyFilters();
          } else {
            filteredDoctors = [];
          }
        });
      }
      debugPrint('Error fetching doctors: $e');
    }
  }
  
  // Extract all unique cities from the doctors list
  void _extractAvailableCities() {
    Set<String> uniqueCities = {};
    
    // Extract city information from all doctors
    for (var doctor in filteredDoctors) {
      if (doctor['city'] != null && doctor['city'].toString().isNotEmpty) {
        String cityName = doctor['city'].toString();
        // Only add if it's in our official list or add it with a note
        if (_pakistaniCities.contains(cityName)) {
          uniqueCities.add(cityName);
        }
      }
      
      // Also check hospital locations
      if (doctor['hospitals'] != null) {
        for (var hospital in doctor['hospitals']) {
          String hospitalName = hospital['hospitalName'].toString();
          // Try to extract city from hospital name (assuming format like "Hospital Name, City")
          if (hospitalName.contains(',')) {
            String possibleCity = hospitalName.split(',').last.trim();
            if (possibleCity.isNotEmpty && _pakistaniCities.contains(possibleCity)) {
              uniqueCities.add(possibleCity);
            }
          }
        }
      }
    }
    
    // If we found very few cities from doctors data, use popular cities instead
    List<String> popularCities = [
      "Islamabad", "Lahore", "Karachi", "Peshawar", "Quetta",
      "Multan", "Faisalabad", "Rawalpindi", "Gujranwala"
    ];
    
    // If we found no or few cities from doctors, add popular ones
    if (uniqueCities.length < 5) {
      uniqueCities.addAll(popularCities.where((city) => _pakistaniCities.contains(city)));
    }
    
    // Sort cities alphabetically
    List<String> sortedCities = uniqueCities.toList()..sort();
    
    // Update state
    setState(() {
      availableCities = sortedCities;
    });
  }

  // Apply all active filters to the doctors list and reload data from Firestore
  Future<void> _applyFilters({bool refreshData = true}) async {
    setState(() {
      if (refreshData) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _errorMessage = null;
    });
    
    try {
      // Create a base Query
      Query doctorsQuery = _firestore.collection('doctors');
      
      // Apply specialty filter if specified from widget, selected specialty, or category
      // The issue was here - widget.specialty was taking precedence over the selectedSpecialty
      // even after changing the specialty filter in the UI
      if (selectedSpecialty != null && selectedSpecialty != "All") {
        doctorsQuery = doctorsQuery.where('specialty', isEqualTo: selectedSpecialty);
      } else if (_selectedCategoryIndex > 0) {
        final selectedCategory = _categories[_selectedCategoryIndex];
        doctorsQuery = doctorsQuery.where('specialty', isEqualTo: selectedCategory);
      } else if (widget.specialty != null && widget.specialty != "All") {
        doctorsQuery = doctorsQuery.where('specialty', isEqualTo: widget.specialty);
      }
      
      // Apply gender filter directly in query
      if (selectedGender != null) {
        doctorsQuery = doctorsQuery.where('gender', isEqualTo: selectedGender);
      }

      // Apply city filter if enabled
      if (showOnlyInMyCity && userCity != null) {
        doctorsQuery = doctorsQuery.where('city', isEqualTo: userCity);
      } else if (selectedLocation != null && selectedLocation!.isNotEmpty) {
        // Apply specific city filter if selected
        doctorsQuery = doctorsQuery.where('city', isEqualTo: selectedLocation);
      }
      
      final QuerySnapshot doctorsSnapshot = await doctorsQuery.get();
      final List<Map<String, dynamic>> doctorsList = [];
      
      // Process each doctor document
      for (var doc in doctorsSnapshot.docs) {
        final doctorData = doc.data() as Map<String, dynamic>;
        final doctorId = doc.id;
        
        // Get doctor's hospitals and availability
        final hospitalsQuery = await _firestore
            .collection('doctor_hospitals')
            .where('doctorId', isEqualTo: doctorId)
            .get();
        
        final List<Map<String, dynamic>> hospitalsList = [];
        
        // For each hospital, get today's availability
        for (var hospitalDoc in hospitalsQuery.docs) {
          final hospitalData = hospitalDoc.data();
          final hospitalId = hospitalData['hospitalId'];
          final hospitalName = hospitalData['hospitalName'] ?? 'Unknown Hospital';
          
          // Get today's date in YYYY-MM-DD format
          final today = DateTime.now();
          final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          
          // Query availability for this hospital and date
          final availabilityQuery = await _firestore
              .collection('doctor_availability')
              .where('doctorId', isEqualTo: doctorId)
              .where('hospitalId', isEqualTo: hospitalId)
              .where('date', isEqualTo: dateStr)
              .limit(1)
              .get();
          
          List<String> timeSlots = [];
          if (availabilityQuery.docs.isNotEmpty) {
            final availabilityData = availabilityQuery.docs.first.data();
            timeSlots = List<String>.from(availabilityData['timeSlots'] ?? []);
          }
          
          hospitalsList.add({
            'hospitalId': hospitalId,
            'hospitalName': hospitalName,
            'availableToday': timeSlots.isNotEmpty,
            'timeSlots': timeSlots,
          });
        }
        
        // Determine overall availability
        final bool isAvailableToday = hospitalsList.any((hospital) => hospital['availableToday'] == true);
        
        // Create doctor map with all relevant information
        doctorsList.add({
          'id': doctorId,
          'name': doctorData['fullName'] ?? doctorData['name'] ?? 'Unknown Doctor',
          'specialty': doctorData['specialty'] ?? 'General Practitioner',
          'rating': doctorData['rating']?.toString() ?? "0.0",
          'experience': doctorData['experience']?.toString() ?? "0 years",
          'fee': 'Rs ${doctorData['fee']?.toString() ?? "0"}',
          'location': hospitalsList.isNotEmpty ? hospitalsList.first['hospitalName'] : 'Multiple Hospitals',
          'image': doctorData['profileImageUrl'] ?? "assets/images/User.png",
          'available': isAvailableToday,
          'hospitals': hospitalsList,
          'gender': doctorData['gender'] ?? 'Not specified',
          'city': doctorData['city'] ?? '',
          'isInUserCity': doctorData['city'] == userCity,
        });
      }
      
      // Apply client-side filters
      List<Map<String, dynamic>> result = List.from(doctorsList);
    
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        result = result.where((doctor) {
          return doctor['name'].toString().toLowerCase().contains(_searchQuery) ||
                doctor['specialty'].toString().toLowerCase().contains(_searchQuery) ||
                doctor['location'].toString().toLowerCase().contains(_searchQuery) ||
                doctor['city'].toString().toLowerCase().contains(_searchQuery);
        }).toList();
      }
      
      // Apply rating filter
      if (selectedRating != null) {
        final minRating = double.parse(selectedRating!.replaceAll('+', ''));
        result = result.where((doctor) {
          double rating;
          try {
            rating = double.parse(doctor['rating'].toString());
          } catch (e) {
            rating = 0.0;
          }
          return rating >= minRating;
        }).toList();
      }
      
      // Apply sorting
      if (sortByPriceLowToHigh) {
        result.sort((a, b) {
          // Extract fee as numeric value (remove "Rs " and parse)
          double aFee = 0.0;
          double bFee = 0.0;
          try {
            aFee = double.parse(a['fee'].toString().replaceAll('Rs ', ''));
            bFee = double.parse(b['fee'].toString().replaceAll('Rs ', ''));
          } catch (e) {
            // Handle parsing error
          }
          return aFee.compareTo(bFee);
        });
      } else {
        // Sort by rating (highest first)
        result.sort((a, b) {
          double aRating = 0.0;
          double bRating = 0.0;
          try {
            aRating = double.parse(a['rating'].toString());
            bRating = double.parse(b['rating'].toString());
          } catch (e) {
            // Handle parsing error
          }
          return bRating.compareTo(aRating);
        });
      }
      
      if (mounted) {
        setState(() {
          filteredDoctors = result;
          _isLoading = false;
          _isRefreshing = false;
        });
        
        // Cache the filtered results
        if (result.isNotEmpty) {
          _cacheDoctorsData(result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error filtering doctors: $e';
          _isLoading = false;
          _isRefreshing = false;
          filteredDoctors = [];
        });
      }
      debugPrint('Error applying filters: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;
    
    // Determine if we're viewing a specific specialty
    final bool viewingSpecificSpecialty = (widget.specialty != null && widget.specialty != "All") && selectedSpecialty == null;
    
    // Check if we should hide the category tabs - hide them only if viewing specific specialty from widget
    // and no specialty has been selected from the filter
    final bool shouldHideCategoryTabs = viewingSpecificSpecialty;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: const Color(0xFF30A9C7), // Match app bar color
        statusBarIconBrightness: Brightness.light, // White status bar icons
        statusBarBrightness: Brightness.dark, // For iOS
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  _buildSearchBar(context),
                  _buildFilterBar(context),
                  // Removed horizontal specialty tabs section
                  // Show loading indicator, error message, or doctor list
                  _isLoading 
                    ? Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: width * 0.1,
                              height: width * 0.1,
                              child: CircularProgressIndicator(
                                color: const Color(0xFF30A9C7),
                                strokeWidth: width * 0.008,
                              ),
                            ),
                            SizedBox(height: height * 0.02),
                            Text(
                              "Loading doctors...",
                              style: GoogleFonts.poppins(
                                fontSize: width * 0.035,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : _errorMessage != null
                      ? Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade400,
                                  size: width * 0.12,
                                ),
                                SizedBox(height: height * 0.02),
                                Text(
                                  "Oops! Something went wrong",
                                  style: GoogleFonts.poppins(
                                    fontSize: width * 0.04,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: height * 0.01),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: width * 0.035,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: height * 0.025),
                                ElevatedButton.icon(
                                  onPressed: _fetchDoctors,
                                  icon: Icon(Icons.refresh, size: width * 0.045),
                                  label: Text(
                                    "Try Again",
                                    style: GoogleFonts.poppins(
                                      fontSize: width * 0.04,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF30A9C7),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(width * 0.05),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: width * 0.05, 
                                      vertical: height * 0.012
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      : filteredDoctors.isEmpty
                        ? Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.userX,
                                  color: Colors.grey.shade400,
                                  size: width * 0.12,
                                ),
                                SizedBox(height: height * 0.02),
                                Text(
                                  _getEmptyStateText(),
                                  style: GoogleFonts.poppins(
                                    fontSize: width * 0.04,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: height * 0.01),
                                Text(
                                  "Try changing your search criteria",
                                  style: GoogleFonts.poppins(
                                    fontSize: width * 0.035,
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                        : Expanded(
                          child: RefreshIndicator(
                            color: const Color(0xFF30A9C7),
                            backgroundColor: Colors.white,
                            strokeWidth: 2.5,
                            onRefresh: () async {
                              // Refresh data when user pulls down
                              _fetchDoctorsWithRefresh();
                            },
                            child: _buildDoctorsList(context),
                          ),
                        ),
                ],
              ),
              
              // Add LinearProgressIndicator at bottom when refreshing data
              if (_isRefreshing)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF30A9C7)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;

    // Create a more descriptive title based on specialty and gender
    String headerTitle = "Available Doctors";
    if (selectedSpecialty != null) {
      headerTitle = "$selectedSpecialty Specialists";
      
      // Add gender information if present
      if (selectedGender != null) {
        headerTitle = "$selectedGender $selectedSpecialty Specialists";
      }
    } else if (widget.specialty != null && widget.specialty != "All") {
      headerTitle = "${widget.specialty} Specialists";
      
      // Add gender information if present
      if (selectedGender != null) {
        headerTitle = "$selectedGender ${widget.specialty} Specialists";
      }
    } else if (selectedGender != null) {
      headerTitle = "$selectedGender Doctors";
    }

    // Get gender icon and color for badge - fixed nullable issues
    IconData? genderIconTemp;
    if (selectedGender == "Male") {
      genderIconTemp = Icons.male;
    } else if (selectedGender == "Female") {
      genderIconTemp = Icons.female;
    }
    
    if (selectedGender == "Male") {
      genderColor = Colors.blue;
    } else if (selectedGender == "Female") {
      genderColor = Colors.pink;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(width * 0.05, height * 0.02, width * 0.05, height * 0.02),
      decoration: BoxDecoration(
        color: const Color(0xFF30A9C7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
              padding: EdgeInsets.all(width * 0.02),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(width * 0.03),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
                  ),
              child: Icon(
                    LucideIcons.arrowLeft,
                    color: Colors.white,
                size: width * 0.05,
                  ),
                ),
              ),
          SizedBox(width: width * 0.03),
          Expanded(
            child: Row(
              children: [
                Flexible(
            child: Text(
              headerTitle,
            style: GoogleFonts.poppins(
                      fontSize: width * 0.045,
                fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
                    overflow: TextOverflow.ellipsis,
          ),
          ),
                if (selectedGender != null && genderIconTemp != null)
          Container(
                    margin: EdgeInsets.only(left: width * 0.02),
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.02, 
                      vertical: height * 0.004
                    ),
                    decoration: BoxDecoration(
                      color: genderColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(width * 0.03),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          genderIconTemp,
                          color: Colors.white,
                          size: width * 0.035,
                        ),
                        SizedBox(width: width * 0.01),
                        Text(
                          selectedGender!,
                          style: GoogleFonts.poppins(
                            fontSize: width * 0.03,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;

    return Container(
      padding: EdgeInsets.fromLTRB(width * 0.05, height * 0.015, width * 0.05, height * 0.025),
      decoration: BoxDecoration(
        color: const Color(0xFF30A9C7),
        
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: Offset(0, 5),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: "Search doctors, specialties...",
          hintStyle: GoogleFonts.poppins(
            fontSize: width * 0.035,
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: width * 0.03, right: width * 0.01),
            child: Icon(
              LucideIcons.search, 
              color: const Color(0xFF30A9C7),
              size: width * 0.05,
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
            ? Padding(
                padding: EdgeInsets.only(right: width * 0.02),
                child: IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(width * 0.005),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.x, 
                      size: width * 0.04, 
                      color: Colors.grey.shade600
                    ),
                  ),
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
              ) 
            : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(width * 0.06),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(width * 0.06),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(width * 0.06),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: height * 0.018, 
            horizontal: width * 0.03
          ),
          fillColor: Colors.white,
          filled: true,
          isDense: true,
        ),
        style: GoogleFonts.poppins(
          fontSize: width * 0.038,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;

    return Container(
      padding: EdgeInsets.symmetric(vertical: height * 0.015, horizontal: width * 0.04),
      decoration: BoxDecoration(
        color: const Color(0xFF30A9C7).withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row of filters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Specialty filter
              Expanded(
                child: _buildQuickFilterChip(
                  context: context,
                  icon: selectedSpecialty != null 
                      ? getSpecialtyIcon(selectedSpecialty)
                      : LucideIcons.stethoscope,
                  label: selectedSpecialty != null 
                      ? selectedSpecialty!
                      : "Specialty",
                  isActive: selectedSpecialty != null,
                  accentColor: selectedSpecialty != null 
                      ? getSpecialtyColor(selectedSpecialty)
                      : null,
                  onTap: () {
                    _showSpecialtyFilterSheet();
                  },
                  isSmallerSize: true,
                ),
              ),
              
              SizedBox(width: width * 0.02),
              
              // Rating filter
              Expanded(
                child: _buildQuickFilterChip(
                  context: context,
                  icon: Icons.star,
                  label: selectedRating == null ? "Rating" : "$selectedRating Rating",
                  isActive: selectedRating != null,
                  accentColor: Colors.amber,
                  onTap: () {
                    _showRatingFilterSheet();
                  },
                  isSmallerSize: true,
                ),
              ),
              
              SizedBox(width: width * 0.02),
              
              // Gender filter
              Expanded(
                child: _buildQuickFilterChip(
                  context: context,
                  icon: selectedGender == "Male" 
                    ? Icons.male 
                    : selectedGender == "Female" 
                      ? Icons.female 
                      : Icons.person,
                  label: selectedGender ?? "Gender",
                  isActive: selectedGender != null,
                  accentColor: selectedGender == "Male" 
                      ? Colors.blue 
                      : selectedGender == "Female" 
                          ? Colors.pink 
                          : null,
                  onTap: () {
                    _showGenderFilterSheet();
                  },
                  isSmallerSize: true,
                ),
              ),
            ],
          ),
          
          SizedBox(height: height * 0.012),
          
          // Second row of filters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Location filter
              Expanded(
                child: _buildQuickFilterChip(
                  context: context,
                  icon: LucideIcons.mapPin,
                  label: showOnlyInMyCity ? "My City" : (selectedLocation ?? "Location"),
                  isActive: showOnlyInMyCity || selectedLocation != null,
                  accentColor: Colors.orange,
                  onTap: () {
                    _showAllCitiesList();
                  },
                  isSmallerSize: true,
                ),
              ),
              
              SizedBox(width: width * 0.02),
              
              // Price sorting filter
              Expanded(
                child: _buildQuickFilterChip(
                  context: context,
                  icon: sortByPriceLowToHigh ? LucideIcons.arrowDown : LucideIcons.arrowUp,
                  label: sortByPriceLowToHigh ? "Low to High" : "High to Low",
                  isActive: true,
                  accentColor: Colors.green,
                  onTap: () {
                    setState(() {
                      sortByPriceLowToHigh = !sortByPriceLowToHigh;
                      _applyFilters();
                    });
                  },
                  isSmallerSize: true,
                ),
              ),
              
              SizedBox(width: width * 0.02),
              
              // Clear all filters or empty placeholder to maintain alignment
              Expanded(
                child: selectedRating != null || selectedGender != null || showOnlyInMyCity || 
                      selectedLocation != null || selectedSpecialty != null
                  ? _buildQuickFilterChip(
                      context: context,
                      icon: LucideIcons.x,
                      label: "Clear All",
                      isActive: true,
                      backgroundColor: Colors.red.shade400,
                      onTap: () {
                        setState(() {
                          selectedRating = null;
                          selectedGender = null;
                          showOnlyInMyCity = false;
                          selectedLocation = null;
                          selectedSpecialty = null;
                          _selectedCategoryIndex = 0; // Reset category index too
                          _applyFilters();
                        });
                      },
                      isSmallerSize: true,
                    )
                  : Container(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsList(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(width * 0.05, width * 0.025, width * 0.05, width * 0.05),
      itemCount: filteredDoctors.length,
      itemBuilder: (context, index) {
        final doctor = filteredDoctors[index];
        return _buildDoctorCard(context, doctor);
      },
    );
  }

  Widget _buildDoctorCard(BuildContext context, Map<String, dynamic> doctor) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;
    
    // Format doctor data to handle both string and numeric values for rating
    String ratingStr = doctor["rating"] is String ? 
        doctor["rating"] : doctor["rating"].toString();
        
    String experienceStr = doctor["experience"] is String ? 
        doctor["experience"] : "${doctor["experience"]} years";
    
    // Set default values for missing fields to ensure UI doesn't break
    bool isAvailable = doctor["available"] ?? true;
    String fee = doctor["fee"] ?? "Rs 2000";
    String location = doctor["location"] ?? "Not specified";
    String gender = doctor["gender"] ?? "Not specified";
    bool isInUserCity = doctor["isInUserCity"] ?? false;
    String city = doctor["city"] ?? "";
    
    // Get the appropriate gender icon
    IconData genderIcon = Icons.person;
    if (gender == "Male") {
      genderIcon = Icons.male;
    } else if (gender == "Female") {
      genderIcon = Icons.female;
    }
    
    // Get specialty-based color
    Color specialtyColor = const Color(0xFF30A9C7);
    if (doctor["specialty"] != null) {
      specialtyColor = getSpecialtyColor(doctor["specialty"]);
    }
    
    // Get gender-based color
    Color genderColor = Colors.grey;
    if (gender == "Male") {
      genderColor = Colors.blue.shade600;
    } else if (gender == "Female") {
      genderColor = Colors.pink.shade400;
    }

    // Create a gradient based on the specialty color
    List<Color> cardGradient = [
      specialtyColor.withOpacity(0.7),
      specialtyColor.withOpacity(0.4),
    ];
    
    return Container(
      margin: EdgeInsets.only(bottom: height * 0.022),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.05),
        boxShadow: [
          BoxShadow(
            color: specialtyColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(width * 0.05),
        child: InkWell(
          borderRadius: BorderRadius.circular(width * 0.05),
          onTap: () {
            // Navigate to appointment booking
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SimplifiedBookingFlow(
                  preSelectedDoctor: doctor,
                ),
              ),
            );
          },
          child: Column(
            children: [
              // Top section with doctor info
              Container(
                decoration: BoxDecoration(
                  color: specialtyColor.withOpacity(0.85),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(width * 0.05),
                    topRight: Radius.circular(width * 0.05),
                  ),
                ),
                padding: EdgeInsets.all(width * 0.04),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Doctor image with availability indicator
                    Stack(
                      children: [
                        Container(
                          width: width * 0.17,
                          height: width * 0.17,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            image: DecorationImage(
                              image: AssetImage(doctor["image"]),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                        ),
                        if (isAvailable)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: width * 0.045,
                              height: width * 0.045,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                LucideIcons.check,
                                color: Colors.white,
                                size: width * 0.025,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: width * 0.03),
                    
                    // Doctor details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          Text(
                            doctor["name"],
                            style: GoogleFonts.poppins(
                              fontSize: width * 0.042,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          
                          SizedBox(height: height * 0.004),
                          
                          // Specialty with icon
                          Row(
                            children: [
                              Icon(
                                getSpecialtyIcon(doctor["specialty"]),
                                color: Colors.white.withOpacity(0.9),
                                size: width * 0.035,
                              ),
                              SizedBox(width: width * 0.01),
                              Flexible(
                                child: Text(
                                  doctor["specialty"],
                                  style: GoogleFonts.poppins(
                                    fontSize: width * 0.03,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          
                          // Location with icon
                          Row(
                            children: [
                              Icon(
                                LucideIcons.mapPin,
                                color: Colors.white.withOpacity(0.8),
                                size: width * 0.03,
                              ),
                              SizedBox(width: width * 0.01),
                              Flexible(
                                child: Text(
                                  location,
                                  style: GoogleFonts.poppins(
                                    fontSize: width * 0.028,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (isInUserCity)
                                Container(
                                  margin: EdgeInsets.only(left: width * 0.01),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: width * 0.01,
                                    vertical: height * 0.001,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(width * 0.01),
                                  ),
                                  child: Text(
                                    "Local",
                                    style: GoogleFonts.poppins(
                                      fontSize: width * 0.02,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Gender badge in circular container
                    Container(
                      width: width * 0.08,
                      height: width * 0.08,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          genderIcon,
                          color: Colors.white,
                          size: width * 0.045,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Middle section with rating and experience
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.04,
                  vertical: height * 0.014,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Rating section
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(width * 0.015),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(width * 0.015),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.star,
                                color: Colors.amber,
                                size: width * 0.04,
                              ),
                              SizedBox(width: width * 0.01),
                              Text(
                                ratingStr,
                                style: GoogleFonts.poppins(
                                  fontSize: width * 0.032,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: width * 0.02),
                        
                        // Experience badge
                        Container(
                          padding: EdgeInsets.all(width * 0.015),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(width * 0.015),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.briefcase,
                                color: Colors.blue.shade600,
                                size: width * 0.04,
                              ),
                              SizedBox(width: width * 0.01),
                              Text(
                                experienceStr,
                                style: GoogleFonts.poppins(
                                  fontSize: width * 0.032,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Fee badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.03,
                        vertical: height * 0.008,
                      ),
                      decoration: BoxDecoration(
                        color: specialtyColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(width * 0.04),
                        border: Border.all(
                          color: specialtyColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.wallet,
                            color: specialtyColor,
                            size: width * 0.04,
                          ),
                          SizedBox(width: width * 0.01),
                          Text(
                            fee,
                            style: GoogleFonts.poppins(
                              fontSize: width * 0.034,
                              fontWeight: FontWeight.w600,
                              color: specialtyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom section
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.04,
                  vertical: height * 0.013,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(width * 0.05),
                    bottomRight: Radius.circular(width * 0.05),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Availability status
                    Row(
                      children: [
                        Container(
                          width: width * 0.02,
                          height: width * 0.02,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isAvailable ? Colors.green : Colors.red.shade400,
                          ),
                        ),
                        SizedBox(width: width * 0.01),
                        Text(
                          isAvailable ? "Available Today" : "Not Available Today",
                          style: GoogleFonts.poppins(
                            fontSize: width * 0.03,
                            fontWeight: FontWeight.w500,
                            color: isAvailable ? Colors.green : Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                    
                    // Book Now button
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.03,
                        vertical: height * 0.005,
                      ),
                      decoration: BoxDecoration(
                        color: specialtyColor,
                        borderRadius: BorderRadius.circular(width * 0.04),
                        boxShadow: [
                          BoxShadow(
                            color: specialtyColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.calendar,
                            color: Colors.white,
                            size: width * 0.035,
                          ),
                          SizedBox(width: width * 0.01),
                          Text(
                            "Book Now",
                            style: GoogleFonts.poppins(
                              fontSize: width * 0.03,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
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

  // Helper method to build consistent info items
  Widget _buildInfoItem(
    BuildContext context, 
    IconData icon, 
    String text, 
    Color color, 
    {bool withBackground = false}
  ) {
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: withBackground ? width * 0.02 : 0, 
        vertical: withBackground ? width * 0.005 : 0
      ),
      decoration: BoxDecoration(
        color: withBackground ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(width * 0.02),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: width * 0.04,
          ),
          SizedBox(width: width * 0.01),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: width * 0.033,
              fontWeight: withBackground ? FontWeight.w600 : FontWeight.w500,
              color: withBackground ? color : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(BuildContext context, String ratingStr) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    
    double rating = 0.0;
    try {
      rating = double.parse(ratingStr);
    } catch (e) {
      // Handle parsing error
      rating = 0.0;
    }
    
    // Format to one decimal place for display
    String displayRating = rating.toStringAsFixed(1);
    
    return _buildInfoItem(context, Icons.star_rounded, displayRating, Colors.amber, withBackground: true);
  }

  // For simplicity, let's add a direct method to show all cities
  void _showAllCitiesList() {
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;
    
    // Always use the full list of Pakistani cities
    List<String> displayCities = List.from(_pakistaniCities);
    
    // Sort the list alphabetically
    displayCities.sort();
    
    // Debug print to check if cities are loaded
    print("Displaying all ${displayCities.length} cities directly");
    
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
        return Container(
          constraints: BoxConstraints(
            maxHeight: height * 0.8, // Max 80% of screen height
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
              
              // "My city" option
                    if (userCity != null)
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: showOnlyInMyCity 
                          ? const Color(0xFF3366CC).withOpacity(0.1)
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.building,
                      color: showOnlyInMyCity 
                          ? const Color(0xFF3366CC) 
                          : Colors.grey.shade600,
                    ),
                  ),
                  title: Text("My City (${userCity!})",
                        style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: showOnlyInMyCity 
                    ? Icon(Icons.check_circle, color: const Color(0xFF30A9C7))
                    : null,
                  onTap: () {
                    setState(() {
                      showOnlyInMyCity = true;
                      selectedLocation = null;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                ),
              
              // "All Cities" option
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (!showOnlyInMyCity && selectedLocation == null)
                        ? const Color(0xFF3366CC).withOpacity(0.1)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.globe,
                    color: (!showOnlyInMyCity && selectedLocation == null)
                        ? const Color(0xFF3366CC) 
                        : Colors.grey.shade600,
                  ),
                ),
                title: Text("All Cities",
                        style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: (!showOnlyInMyCity && selectedLocation == null)
                  ? Icon(Icons.check_circle, color: const Color(0xFF30A9C7))
                  : null,
                onTap: () {
                  setState(() {
                    showOnlyInMyCity = false;
                    selectedLocation = null;
                        _applyFilters();
                  });
                  Navigator.pop(context);
                },
              ),
              
              Divider(),
              
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
                    return ListTile(
                      leading: Icon(
                        LucideIcons.mapPin, 
                        color: selectedLocation == city 
                            ? Colors.teal
                            : Colors.black87
                      ),
                      title: Text(
                        city,
            style: GoogleFonts.poppins(
                          fontWeight: selectedLocation == city
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selectedLocation == city
                              ? Colors.teal
                              : Colors.black87,
                        ),
                      ),
                      trailing: selectedLocation == city
                        ? Icon(Icons.check_circle, color: Colors.teal)
                        : null,
                onTap: () {
                  setState(() {
                          selectedLocation = city;
                          showOnlyInMyCity = false;
                    _applyFilters();
                  });
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
  }

  // Widget for individual filter chip in the filter bar
  Widget _buildQuickFilterChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? accentColor,
    bool isSmallerSize = false,
  }) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;
    
    // If accent color is provided use it, otherwise use default Color(0xFF30A9C7)
    final Color activeIconColor = backgroundColor != null 
        ? Colors.white 
        : (accentColor ?? const Color(0xFF30A9C7));
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallerSize ? width * 0.02 : width * 0.03,
          vertical: height * 0.008,
        ),
        decoration: BoxDecoration(
          color: isActive 
              ? (backgroundColor ?? Colors.white) 
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(width * 0.05),
          boxShadow: isActive ? [
            BoxShadow(
              color: (backgroundColor ?? activeIconColor).withOpacity(0.3),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isSmallerSize ? width * 0.03 : width * 0.035,
              color: isActive 
                  ? (backgroundColor != null ? Colors.white : activeIconColor) 
                  : Colors.white,
            ),
            SizedBox(width: width * 0.01),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: isSmallerSize ? width * 0.025 : width * 0.03,
                  fontWeight: FontWeight.w500,
                  color: isActive 
                      ? (backgroundColor != null ? Colors.white : activeIconColor) 
                      : Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Method to show rating filter sheet
  void _showRatingFilterSheet() {
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(width * 0.05),
          topRight: Radius.circular(width * 0.05),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.all(width * 0.05),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Select Rating",
                        style: GoogleFonts.poppins(
                          fontSize: width * 0.05,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.02),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      this.setState(() {
                        selectedRating = null;
                        _applyFilters();
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: height * 0.01),
                      child: Row(
                        children: [
                          Text(
                            "All Ratings",
                            style: GoogleFonts.poppins(
                              fontSize: width * 0.035,
                              color: Colors.black87,
                            ),
                          ),
                          Spacer(),
                          if (selectedRating == null)
                            Icon(
                              Icons.check,
                              color: Colors.teal,
                              size: width * 0.05,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Divider(),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      this.setState(() {
                        selectedRating = "4+";
                        _applyFilters();
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: height * 0.01),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              Text(
                                "4+ ",
                                style: GoogleFonts.poppins(
                                  fontSize: width * 0.035,
                                  color: Colors.black87,
                                ),
                              ),
                              Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: width * 0.04,
                              ),
                            ],
                          ),
                          Spacer(),
                          if (selectedRating == "4+")
                            Icon(
                              Icons.check,
                              color: Colors.teal,
                              size: width * 0.05,
                            ),
                        ],
                      ),
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

  // Show gender filter popup
  void _showGenderFilterSheet() {
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(width * 0.05),
          topRight: Radius.circular(width * 0.05),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.all(width * 0.05),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Select Gender",
                        style: GoogleFonts.poppins(
                          fontSize: width * 0.05,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: height * 0.02),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      this.setState(() {
                        selectedGender = null;
                        _applyFilters();
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: height * 0.01),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: Colors.grey.shade700,
                            size: width * 0.05,
                          ),
                          SizedBox(width: width * 0.02),
                          Text(
                            "All",
                            style: GoogleFonts.poppins(
                              fontSize: width * 0.035,
                              color: Colors.black87,
                            ),
                          ),
                          Spacer(),
                          if (selectedGender == null)
                            Icon(
                              Icons.check,
                              color: const Color(0xFF3366CC),
                              size: width * 0.05,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Divider(),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      this.setState(() {
                        selectedGender = "Male";
                        _applyFilters();
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: height * 0.01),
                      child: Row(
                        children: [
                          Icon(
                            Icons.male,
                            color: Colors.blue,
                            size: width * 0.05,
                          ),
                          SizedBox(width: width * 0.02),
                          Text(
                            "Male",
                            style: GoogleFonts.poppins(
                              fontSize: width * 0.035,
                              color: Colors.black87,
                            ),
                          ),
                          Spacer(),
                          if (selectedGender == "Male")
                            Icon(
                              Icons.check,
                              color: const Color(0xFF3366CC),
                              size: width * 0.05,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Divider(),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      this.setState(() {
                        selectedGender = "Female";
                        _applyFilters();
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: height * 0.01),
                      child: Row(
                        children: [
                          Icon(
                            Icons.female,
                            color: Colors.pink,
                            size: width * 0.05,
                          ),
                          SizedBox(width: width * 0.02),
                          Text(
                            "Female",
                            style: GoogleFonts.poppins(
                              fontSize: width * 0.035,
                              color: Colors.black87,
                            ),
                          ),
                          Spacer(),
                          if (selectedGender == "Female")
                            Icon(
                              Icons.check,
                              color: const Color(0xFF3366CC),
                              size: width * 0.05,
                            ),
                        ],
                      ),
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

  // Method to show specialty filter sheet
  void _showSpecialtyFilterSheet() {
    final Size screenSize = MediaQuery.of(context).size;
    final double width = screenSize.width;
    final double height = screenSize.height;
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(width * 0.05),
          topRight: Radius.circular(width * 0.05),
        ),
      ),
      isScrollControlled: true, // Allow more height to fit all specialties
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: height * 0.7, // Max 70% of screen height
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
                    "Select Specialty",
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
              
              // "All Specialties" option
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selectedSpecialty == null
                        ? const Color(0xFF30A9C7).withOpacity(0.1)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.stethoscope,
                    color: selectedSpecialty == null
                        ? const Color(0xFF30A9C7)
                        : Colors.grey.shade600,
                  ),
                ),
                title: Text("All Specialties",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: selectedSpecialty == null
                  ? Icon(Icons.check_circle, color: const Color(0xFF30A9C7))
                  : null,
                onTap: () {
                  setState(() {
                    selectedSpecialty = null;
                    _selectedCategoryIndex = 0;
                    _applyFilters(refreshData: true);
                  });
                  Navigator.pop(context);
                },
              ),
              
              Divider(),
              
              // Specialty list
              Expanded(
                child: ListView.builder(
                  itemCount: _categories.length - 1, // Skip the "All" option
                  itemBuilder: (context, index) {
                    // Since we're skipping "All", add 1 to index
                    final int categoryIndex = index + 1;
                    final String specialty = _categories[categoryIndex];
                    final Color specialtyColor = getSpecialtyColor(specialty);
                    
                    return ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selectedSpecialty == specialty
                              ? specialtyColor.withOpacity(0.1)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          getSpecialtyIcon(specialty),
                          color: selectedSpecialty == specialty
                              ? specialtyColor
                              : Colors.grey.shade600,
                          size: width * 0.05,
                        ),
                      ),
                      title: Text(
                        specialty,
                        style: GoogleFonts.poppins(
                          fontWeight: selectedSpecialty == specialty
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selectedSpecialty == specialty
                              ? specialtyColor
                              : Colors.black87,
                        ),
                      ),
                      trailing: selectedSpecialty == specialty
                        ? Icon(Icons.check_circle, color: specialtyColor)
                        : null,
                      onTap: () {
                        setState(() {
                          selectedSpecialty = specialty;
                          _selectedCategoryIndex = categoryIndex;
                          _applyFilters(refreshData: true);
                        });
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
  }

  // Helper method to get appropriate icon and color for a specialty
  IconData getSpecialtyIcon(String? specialty) {
    if (specialty == null) return LucideIcons.stethoscope;
    
    switch (specialty) {
      case "Cardiology": return LucideIcons.heart;
      case "Neurology": return LucideIcons.brain;
      case "Dermatology": return LucideIcons.scan;
      case "Orthopedics": return LucideIcons.bone;
      case "ENT": return LucideIcons.ear;
      case "Pediatrics": return LucideIcons.baby;
      case "Gynecology": return LucideIcons.heart;
      case "Ophthalmology": return LucideIcons.eye;
      case "Dentistry": return LucideIcons.scissors;
      case "Psychiatry": return LucideIcons.brain;
      case "Pulmonology": return LucideIcons.activity;
      case "Gastrology": return LucideIcons.pill;
      default: return LucideIcons.stethoscope;
    }
  }

  Color getSpecialtyColor(String? specialty) {
    if (specialty == null) return const Color(0xFF30A9C7);
    
    switch (specialty) {
      case "Cardiology": return Colors.red.shade700;
      case "Neurology": return Colors.purple.shade700;
      case "Dermatology": return Colors.pink.shade400;
      case "Orthopedics": return Colors.amber.shade700;
      case "ENT": return Colors.blue.shade700;
      case "Pediatrics": return Colors.green.shade600;
      case "Gynecology": return Colors.pink.shade700;
      case "Ophthalmology": return Colors.blue.shade600;
      case "Dentistry": return Colors.cyan.shade700;
      case "Psychiatry": return Colors.indigo.shade600;
      case "Pulmonology": return Colors.teal.shade700;
      case "Gastrology": return Colors.orange.shade700;
      default: return const Color(0xFF30A9C7);
    }
  }

  // Helper method to get the empty state text based on selected filters
  String _getEmptyStateText() {
    if (selectedSpecialty != null) {
      return "No ${selectedSpecialty} specialists found";
    } else if (widget.specialty != null && widget.specialty != "All") {
      return "No ${widget.specialty} specialists found";
    } else if (selectedGender != null) {
      return "No ${selectedGender?.toLowerCase() ?? ''} doctors found";
    } else {
      return "No doctors found";
    }
  }
}

// This is a placeholder. You'd need to implement this screen properly
class DoctorDetailsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Doctor Details"),
        backgroundColor: const Color(0xFF30A9C7),
      ),
      body: Center(
        child: Text("Doctor details would go here"),
      ),
    );
  }
}
