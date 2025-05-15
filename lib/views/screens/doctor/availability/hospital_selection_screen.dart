import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:healthcare/utils/navigation_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'package:healthcare/utils/app_theme.dart';
import 'package:healthcare/utils/ui_helper.dart';

class HospitalSelectionScreen extends StatefulWidget {
  final List<String> selectedHospitals;
  
  const HospitalSelectionScreen({
    super.key, 
    required this.selectedHospitals,
  });

  @override
  State<HospitalSelectionScreen> createState() => _HospitalSelectionScreenState();
}

class _HospitalSelectionScreenState extends State<HospitalSelectionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<String> _selectedHospitals;
  bool _isLoading = false;
  
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // City and hospital selection
  String? _selectedCity;
  String _hospitalName = ""; // Changed from String? to String with empty default
  final TextEditingController _hospitalNameController = TextEditingController();
  
  // List of Pakistani cities
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
    "Rahimyar Khan", "Rajanpur", "Rani Pur", "Rawalpindi", "Risalpur", "Rohri",
    "Sadiqabad", "Sahiwal", "Saidu Sharif", "Sakrand", "Samundri", "Sanghar", "Sargodha", "Sheikhupura", "Shikarpur", "Sialkot", "Sibi", "Sukkur", "Swabi", "Swat",
    "Talagang", "Tandlianwala", "Tando Adam", "Tando Allahyar", "Tando Muhammad Khan", "Tank", "Taunsa", "Taxila", "Toba Tek Singh", "Turbat",
    "Vehari",
    "Wah Cantonment", "Wazirabad"
  ];
  
  @override
  void initState() {
    super.initState();
    _selectedHospitals = List.from(widget.selectedHospitals);
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..forward();
    
    // Apply pink status bar for this screen
    UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
    
    // Add listener for hospital name changes
    _hospitalNameController.addListener(() {
      setState(() {
        _hospitalName = _hospitalNameController.text.trim();
      });
    });
    
    // Load hospitals from Firestore
    _loadHospitalsFromFirestore();
  }
  
  // Load doctor's selected hospitals from Firestore
  Future<void> _loadHospitalsFromFirestore() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current user ID
      final String? doctorId = _auth.currentUser?.uid;
      
      if (doctorId == null) {
        throw Exception('User not authenticated');
      }
      
      // Get doctor's hospital associations from Firestore
      final associationsSnapshot = await _firestore
          .collection('doctor_hospitals')
          .where('doctorId', isEqualTo: doctorId)
          .get();
      
      if (associationsSnapshot.docs.isNotEmpty) {
        // Extract hospital names from the documents
        final List<String> hospitalNames = associationsSnapshot.docs
            .map((doc) => (doc.data() as Map<String, dynamic>)['hospitalName'] as String)
            .toList();
        
        if (mounted) {
          setState(() {
            // Replace any initially passed hospitals with those from Firestore
            _selectedHospitals = hospitalNames;
            _isLoading = false;
          });
        }
      } else {
        // No hospitals found in Firestore, keep the ones passed to the widget
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading hospitals from Firestore: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _hospitalNameController.dispose();
    
    // Don't set system UI style in dispose - let parent screen handle it
    
    super.dispose();
  }

  // Format hospital name with city
  String _formatHospitalName(String hospitalName, String city) {
    return "$hospitalName, $city";
  }

  // Add hospital to selection
  void _addHospital() {
    // Get the latest value from the text controller
    String hospitalName = _hospitalNameController.text.trim();
    
    if (_selectedCity == null) {
      // Show error for missing city
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a city first')),
      );
      return;
    }
    
    if (hospitalName.isEmpty) {
      // Show error for empty hospital name
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a hospital name')),
      );
      return;
    }
    
    // Format hospital name with city
    String fullHospitalName = _formatHospitalName(hospitalName, _selectedCity!);
    
    // Add to selected hospitals if not already there
    if (!_selectedHospitals.contains(fullHospitalName)) {
      setState(() {
        _selectedHospitals.add(fullHospitalName);
      });
      
      // Save this hospital to Firestore immediately
      _saveHospitalToFirestore(fullHospitalName);
    } else {
      // Show error for duplicate hospital
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This hospital is already in your list')),
      );
      return;
    }
    
    // Clear the text field
    _hospitalNameController.clear();
    
    // Reset city selection if needed
    setState(() {
      _selectedCity = null;
    });
  }
  
  // Save a single hospital to Firestore
  Future<void> _saveHospitalToFirestore(String hospitalName) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current user ID
      final String? doctorId = _auth.currentUser?.uid;
      
      if (doctorId == null) {
        throw Exception('User not authenticated');
      }
      
      // Extract city from the hospital name format "Hospital Name, City"
      List<String> parts = hospitalName.split(', ');
      String city = "";
      String rawHospitalName = hospitalName;
      
      if (parts.length > 1) {
        city = parts.last;
        rawHospitalName = parts.sublist(0, parts.length - 1).join(', ');
      }
      
      // Create a unique ID for the hospital
      String cityPrefix = city.isNotEmpty ? city.substring(0, math.min(3, city.length)).toUpperCase() : "HSP";
      String hospitalId = 'custom_${cityPrefix}_${DateTime.now().millisecondsSinceEpoch}';
        
      // Save to Firestore
      final docRef = _firestore.collection('doctor_hospitals').doc();
      await docRef.set({
        'doctorId': doctorId,
        'hospitalId': hospitalId,
        'hospitalName': hospitalName, // Full name with city
        'rawHospitalName': rawHospitalName,
        'city': city,
        'created': FieldValue.serverTimestamp(),
        'isCustom': true, // All entries are custom now
      });
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hospital added successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error saving hospital to Firestore: $e');
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        // Remove the hospital from the list since saving failed
        _selectedHospitals.remove(hospitalName);
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save hospital: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
  
  // Remove hospital from selection
  void _removeHospital(String hospital) {
    setState(() {
      _selectedHospitals.remove(hospital);
    });
    
    // Remove from Firestore immediately
    _removeHospitalFromFirestore(hospital);
  }
  
  // Remove a hospital from Firestore
  Future<void> _removeHospitalFromFirestore(String hospitalName) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current user ID
      final String? doctorId = _auth.currentUser?.uid;
      
      if (doctorId == null) {
        throw Exception('User not authenticated');
      }
      
      // Find the document to delete
      final querySnapshot = await _firestore
          .collection('doctor_hospitals')
          .where('doctorId', isEqualTo: doctorId)
          .where('hospitalName', isEqualTo: hospitalName)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        // Delete the document
        await querySnapshot.docs.first.reference.delete();
      }
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hospital removed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error removing hospital from Firestore: $e');
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        // Add the hospital back to the list since deletion failed
        if (!_selectedHospitals.contains(hospitalName)) {
          _selectedHospitals.add(hospitalName);
        }
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove hospital: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apply status bar style on build
    UIHelper.applyPinkStatusBar();
    
    // Wrap the main Scaffold with UIHelper.ensureStatusBarStyle for extra reliability
    return UIHelper.ensureStatusBarStyle(
      style: UIHelper.pinkStatusBarStyle,
      child: WillPopScope(
        onWillPop: () async {
          // Ensure pink status bar is applied when navigating back
          UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
          return true;
        },
        child: Scaffold(
      backgroundColor: Color(0xFFF8FAFF),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                // Apply pink status bar before popping
                UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
                Navigator.pop(context);
              },
        ),
        title: Text(
          "Hospital Selection",
          style: GoogleFonts.poppins(
            fontSize: 20,
                fontWeight: FontWeight.w600,
            color: Colors.white,
              ),
          ),
            centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
              Navigator.pop(context, _selectedHospitals);
            },
            child: Text(
              "Done",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: null,
      body: Stack(
        children: [
          // Background gradient and design elements
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryPink,
                  AppTheme.primaryPink.withOpacity(0.8),
                ],
              ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
              ),
            child: Stack(
              children: [
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -80,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Title and info card
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 15, 20, 5),
                    child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryPink,
                                    AppTheme.primaryPink.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                                      child: Icon(
                                        LucideIcons.building2,
                                color: Colors.white,
                                size: 24,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                    "Hospital Affiliations",
                                      style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkText,
                                      height: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                    "Add any hospital where you practice",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFFF1F5FE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryPink.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                LucideIcons.info,
                                color: AppTheme.primaryPink,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                  "You can now enter any hospital name where you practice. First select a city, then type your hospital name, and add it to your list.",
                                            style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                          ),
                                    ),
                                  ],
                                ),
                              ),
                ),
                
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    child: Container(
                      color: Colors.white,
                      child: _buildMainContent(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Updating hospital data...",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
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
  ));
}

Widget _buildMainContent() {
  return SingleChildScrollView(
    physics: BouncingScrollPhysics(),
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 25, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // City selector
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFFF1F5FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          LucideIcons.mapPin,
                          color: AppTheme.primaryPink,
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Select City",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedCity != null 
                          ? AppTheme.primaryPink
                          : AppTheme.primaryPink.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPink.withOpacity(0.08),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                    gradient: _selectedCity != null 
                        ? LinearGradient(
                            colors: [
                              Colors.white,
                              AppTheme.primaryPink.withOpacity(0.05),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : null,
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      popupMenuTheme: PopupMenuThemeData(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      canvasColor: Colors.white,
                      dividerColor: Colors.transparent,
                      shadowColor: AppTheme.primaryPink.withOpacity(0.2),
                    ),
                    child: ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCity,
                        isExpanded: true,
                        isDense: false,
                        icon: Container(
                          padding: EdgeInsets.all(8),
                          margin: EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: _selectedCity != null
                                ? AppTheme.primaryPink.withOpacity(0.15)
                                : AppTheme.primaryPink.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.chevronDown,
                            color: _selectedCity != null
                                ? AppTheme.primaryPink
                                : AppTheme.primaryPink.withOpacity(0.7),
                            size: 16,
                          ),
                        ),
                        dropdownColor: Colors.white,
                        menuMaxHeight: 350,
                        itemHeight: 50,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
                        decoration: InputDecoration(
                          hintText: "Select a city",
                          hintStyle: GoogleFonts.poppins(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          prefixIcon: Container(
                            padding: EdgeInsets.all(12),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_selectedCity != null)
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryPink.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Icon(
                                  LucideIcons.mapPin,
                                  color: AppTheme.primaryPink,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          suffixIcon: _selectedCity != null
                              ? GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCity = null;
                                    });
                                  },
                                  child: Container(
                                    margin: EdgeInsets.only(right: 46),
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      LucideIcons.x,
                                      color: Colors.grey.shade700,
                                      size: 12,
                                    ),
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        selectedItemBuilder: (BuildContext context) {
                          return _pakistaniCities.map<Widget>((String city) {
                            return Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                city,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList();
                        },
                        items: _pakistaniCities.map((String city) {
                          // Group cities by first letter for better organization
                          bool isFirstWithLetter = _pakistaniCities.indexOf(city) == 0 || 
                              _pakistaniCities[_pakistaniCities.indexOf(city) - 1][0] != city[0];
                          
                          return DropdownMenuItem<String>(
                            value: city,
                            child: SizedBox(
                              height: 40,
                              child: Row(
                                children: [
                                  // Section for the letter grouping indicator (if first letter)
                                  if (isFirstWithLetter)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      margin: EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryPink.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        city[0],
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppTheme.primaryPink,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  
                                  // Checkbox indicator
                                  Container(
                                    width: 16,
                                    height: 16,
                                    margin: EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: _selectedCity == city
                                          ? AppTheme.primaryPink
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _selectedCity == city
                                            ? AppTheme.primaryPink
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: _selectedCity == city
                                        ? Center(
                                            child: Icon(
                                              Icons.check,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                  
                                  // City name
                                  Expanded(
                            child: Text(
                              city,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                        color: _selectedCity == city
                                            ? AppTheme.primaryPink
                                            : Colors.black87,
                                        fontWeight: _selectedCity == city
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCity = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Hospital selector
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFFF1F5FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          LucideIcons.building2,
                          color: AppTheme.primaryPink,
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Enter Hospital Name",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hospitalName.isNotEmpty
                          ? AppTheme.primaryPink
                          : AppTheme.primaryPink.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPink.withOpacity(0.08),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                    gradient: _hospitalName.isNotEmpty
                        ? LinearGradient(
                            colors: [
                              Colors.white,
                              AppTheme.primaryPink.withOpacity(0.05),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : null,
                  ),
                  child: TextField(
                    controller: _hospitalNameController,
                    decoration: InputDecoration(
                      hintText: "Enter hospital name",
                      hintStyle: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                            ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefixIcon: Container(
                        padding: EdgeInsets.all(12),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_hospitalName.isNotEmpty)
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPink.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            _selectedCity == null
                          ? Icon(
                              Icons.error_outline,
                              color: Color(0xFFEF4444),
                              size: 20,
                            )
                          : Icon(
                              LucideIcons.building2,
                                  color: AppTheme.primaryPink,
                                size: 20,
                                    ),
                          ],
                        ),
                          ),
                      suffixIcon: _hospitalName.isNotEmpty
                          ? Container(
                              margin: EdgeInsets.only(right: 12),
                              child: IconButton(
                                icon: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                LucideIcons.x,
                                    color: Colors.grey.shade700,
                                    size: 12,
                                  ),
                              ),
                              onPressed: () {
                                _hospitalNameController.clear();
                              },
                              ),
                            )
                          : null,
                      enabled: _selectedCity != null,
                    ),
                  ),
                ),
                
                // Add helper text
                Container(
                  margin: EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.info,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedCity == null
                              ? "Please select a city first"
                              : "Enter any hospital name where you practice in ${_selectedCity!}",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Add Button
                Container(
                  margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (_selectedCity == null || _hospitalName.isEmpty)
                            ? Colors.transparent
                            : AppTheme.primaryPink.withOpacity(0.25),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: (_selectedCity == null || _hospitalName.isEmpty) 
                        ? null 
                        : _addHospital,
                      borderRadius: BorderRadius.circular(12),
                      splashColor: AppTheme.primaryPink.withOpacity(0.1),
                      highlightColor: AppTheme.primaryPink.withOpacity(0.2),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: (_selectedCity == null || _hospitalName.isEmpty)
                              ? Color(0xFFE2E8F0)
                              : AppTheme.primaryPink,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_selectedCity == null || _hospitalName.isEmpty)
                                ? Colors.transparent
                                : AppTheme.primaryPink.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: (_selectedCity == null || _hospitalName.isEmpty)
                                    ? Color(0xFF94A3B8).withOpacity(0.3)
                                    : Colors.white.withOpacity(0.25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.plus, 
                                size: 16,
                                color: (_selectedCity == null || _hospitalName.isEmpty)
                                    ? Color(0xFF94A3B8)
                                    : Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                      "Add To My Hospitals",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                                fontSize: 15,
                                color: (_selectedCity == null || _hospitalName.isEmpty)
                                    ? Color(0xFF94A3B8)
                                    : Colors.white,
                              ),
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
          
          SizedBox(height: 24),
          
          // Selected hospitals
          if (_selectedHospitals.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.listChecks,
                    color: AppTheme.primaryPink,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Selected Hospitals",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${_selectedHospitals.length}",
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
            
            // List of selected hospitals
            ...List.generate(
              _selectedHospitals.length,
              (index) {
                final hospital = _selectedHospitals[index];
                List<String> parts = hospital.split(', ');
                String hospitalName = parts.length > 1 
                    ? parts.sublist(0, parts.length - 1).join(', ') 
                    : hospital;
                String cityName = parts.length > 1 ? parts.last : "";
                
                return AnimatedScale(
                  scale: 1.0,
                  duration: Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 16),
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
                      border: Border.all(
                        color: Color(0xFFEDF2F7),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryPink.withOpacity(0.1),
                                  AppTheme.primaryTeal.withOpacity(0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryPink.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              LucideIcons.building2,
                              color: AppTheme.primaryPink,
                              size: 24,
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      LucideIcons.mapPin,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      cityName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _removeHospital(hospital),
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFFFEE2E2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.trash2,
                                color: Color(0xFFEF4444),
                                size: 20,
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
          ] else ...[
            // Empty state
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(40),
              margin: EdgeInsets.only(top: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color(0xFFEDF2F7),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5FE),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.building2,
                      size: 50,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    "No Hospitals Selected",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Choose your city and hospital, then tap 'Add' to include it in your profile.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<bool?> _showSuccessDialog() {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  Positioned(
                    top: -10,
                    right: -10,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(0xFF1E74FD),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          LucideIcons.building2,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Text(
                'Hospitals Updated',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Your hospital selections have been saved successfully.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1E74FD),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showErrorDialog(String errorMessage) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
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
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_rounded,
                  color: Color(0xFFEF4444),
                  size: 40,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Oops! Something went wrong',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Failed to save hospital selections. Please try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF8FAFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  errorMessage,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1E74FD),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
} 