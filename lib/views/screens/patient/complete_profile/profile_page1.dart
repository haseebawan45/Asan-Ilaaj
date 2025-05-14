import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/views/screens/patient/complete_profile/profile_page2.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:io';
import 'package:healthcare/views/screens/patient/bottom_navigation_patient.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:healthcare/utils/app_theme.dart';
import 'package:healthcare/services/storage_service.dart';

class CompleteProfilePatient1Screen extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final bool isEditing;
  
  const CompleteProfilePatient1Screen({
    super.key,
    this.profileData,
    this.isEditing = false,
  });

  @override
  State<CompleteProfilePatient1Screen> createState() => _CompleteProfilePatient1ScreenState();
}

class _CompleteProfilePatient1ScreenState extends State<CompleteProfilePatient1Screen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  
  // Selected city from dropdown
  String? _selectedCity;
  
  // Selected gender from dropdown
  String? _selectedGender;
  
  // Gender options list
  final List<String> _genderOptions = ["Male", "Female", "Intersex"];
  
  // Store auth phone number
  String? _authPhoneNumber;
  
  // Profile completion percentage
  double _completionPercentage = 0.0;
  
  // Total number of fields in profile page 1
  final int _totalFieldsPage1 = 6; // name, email, cnic, address, city, gender
  
  // List of Pakistani cities in alphabetical order
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

  @override
  void initState() {
    super.initState();
    
    // Get phone number from Firebase Auth
    _getAuthPhoneNumber();
    
    // Initialize with existing data if available
    if (widget.profileData != null) {
      _nameController.text = widget.profileData!['name'] ?? '';
      _emailController.text = widget.profileData!['email'] ?? '';
      _addressController.text = widget.profileData!['address'] ?? '';
      _cnicController.text = widget.profileData!['cnic'] ?? '';
      _selectedCity = widget.profileData!['city'];
      _selectedGender = widget.profileData!['gender'];
      
      // Initialize profile image if exists
      if (widget.profileData!['profileImagePath'] != null) {
        _image = File(widget.profileData!['profileImagePath']);
      }
    } else {
      // Try to fetch user data from Firestore
      _fetchUserDataFromFirestore();
    }
    
    // Calculate initial completion percentage
    _calculateCompletionPercentage();
    
    // Add listeners to all text controllers
    _nameController.addListener(_updateCompletionPercentage);
    _emailController.addListener(_updateCompletionPercentage);
    _addressController.addListener(_updateCompletionPercentage);
    _cnicController.addListener(_updateCompletionPercentage);
  }
  
  @override
  void dispose() {
    // Remove listeners from all text controllers
    _nameController.removeListener(_updateCompletionPercentage);
    _emailController.removeListener(_updateCompletionPercentage);
    _addressController.removeListener(_updateCompletionPercentage);
    _cnicController.removeListener(_updateCompletionPercentage);
    
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cnicController.dispose();
    super.dispose();
  }

  void _updateCompletionPercentage() {
    _calculateCompletionPercentage();
  }
  
  void _calculateCompletionPercentage() {
    int filledFields = 0;
    int totalFields = _totalFieldsPage1 + 1; // +1 for profile image
    
    // Check each field
    if (_nameController.text.isNotEmpty) filledFields++;
    if (_emailController.text.isNotEmpty) filledFields++;
    if (_addressController.text.isNotEmpty) filledFields++;
    if (_cnicController.text.isNotEmpty) filledFields++;
    if (_selectedCity != null) filledFields++;
    if (_selectedGender != null) filledFields++;
    
    // Count profile image as a very important field
    if (_image != null) {
      filledFields++;
      // Profile image is weighted as an essential part
    } else {
      // If profile image is not provided, we cannot exceed 85% completion
      totalFields += 2; // Give more weight to profile image
    }
    
    // Calculate percentage (out of 50% for first page)
    double completionValue = (filledFields / totalFields) * 50.0;
    
    // Don't let the page 1 percentage exceed 50% of total
    if (completionValue > 50.0) {
      completionValue = 50.0;
    }
    
    setState(() {
      _completionPercentage = completionValue;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _calculateCompletionPercentage(); // Update percentage when image is picked
    }
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: AppTheme.lightText,
            fontSize: 14,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: AppTheme.primaryTeal,
              size: 20,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // Text area widget for address
  Widget _buildTextArea({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryTeal.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
          color: Colors.grey.shade300,
            width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        textAlignVertical: TextAlignVertical.top,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: AppTheme.darkText,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: AppTheme.lightText,
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8, top: 16),
            child: Icon(
              icon,
              color: AppTheme.primaryTeal,
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        ),
      ),
    );
  }
  
  // Pakistani CNIC input field with formatted mask (00000-0000000-0)
  Widget _buildCnicField() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _cnicController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(13),
          _CnicFormatter(),
        ],
        decoration: InputDecoration(
          hintText: "CNIC (00000-0000000-0)",
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          prefixIcon: Container(
              padding: const EdgeInsets.all(12),
            child: Icon(
              LucideIcons.creditCard,
              color: AppTheme.primaryTeal,
              size: 20,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
  
  // City dropdown widget with enhanced design
  Widget _buildCityDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _selectedCity != null 
              ? AppTheme.primaryTeal
              : Colors.grey.shade300,
          width: 1.5,
        ),
        gradient: _selectedCity != null 
            ? LinearGradient(
                colors: [
                  Colors.white,
                  AppTheme.primaryTeal.withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          // Customize dropdown appearance
          popupMenuTheme: PopupMenuThemeData(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          canvasColor: Colors.white,
          dividerColor: Colors.transparent,
          shadowColor: AppTheme.primaryTeal.withOpacity(0.2),
        ),
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButtonFormField<String>(
            value: _selectedCity,
            isExpanded: true,
            isDense: false,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedCity != null
                    ? AppTheme.primaryTeal.withOpacity(0.15)
                    : AppTheme.primaryTeal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.chevronDown,
                color: _selectedCity != null
                    ? AppTheme.primaryTeal
                    : AppTheme.primaryTeal.withOpacity(0.7),
                size: 16,
              ),
            ),
            dropdownColor: Colors.white,
            menuMaxHeight: 350,
            itemHeight: 50,
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            decoration: InputDecoration(
              hintText: "Select City",
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  alignment: Alignment.center,
                children: [
                    if (_selectedCity != null)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    Icon(
                      LucideIcons.building2,
                      color: AppTheme.primaryTeal,
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
                        margin: const EdgeInsets.only(right: 46),
                        padding: const EdgeInsets.all(4),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                // Use a Row instead of Column to avoid vertical overflow
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      // Section for the letter grouping indicator (if first letter)
                      if (isFirstWithLetter)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            city[0],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                              color: AppTheme.primaryTeal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      
                      // Checkbox indicator
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _selectedCity == city
                              ? AppTheme.primaryTeal
                              : Colors.transparent,
                          border: Border.all(
                            color: _selectedCity == city
                                ? AppTheme.primaryTeal
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: _selectedCity == city
                            ? const Center(
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
                                ? AppTheme.primaryTeal
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
    );
  }

  // Gender dropdown widget
  Widget _buildGenderDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _selectedGender != null 
              ? AppTheme.primaryTeal
              : Colors.grey.shade300,
          width: 1.5,
        ),
        gradient: _selectedGender != null 
            ? LinearGradient(
                colors: [
                  Colors.white,
                  AppTheme.primaryTeal.withOpacity(0.05),
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
          shadowColor: AppTheme.primaryTeal.withOpacity(0.2),
        ),
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButtonFormField<String>(
            value: _selectedGender,
            isExpanded: true,
            isDense: false,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedGender != null
                    ? AppTheme.primaryTeal.withOpacity(0.15)
                    : AppTheme.primaryTeal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.chevronDown,
                color: _selectedGender != null
                    ? AppTheme.primaryTeal
                    : AppTheme.primaryTeal.withOpacity(0.7),
                size: 16,
              ),
            ),
            dropdownColor: Colors.white,
            menuMaxHeight: 150,
            itemHeight: 50,
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            decoration: InputDecoration(
              hintText: "Select Gender",
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_selectedGender != null)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    Icon(
                      LucideIcons.userCheck,
                      color: AppTheme.primaryTeal,
                      size: 20,
                    ),
                  ],
                ),
              ),
              suffixIcon: _selectedGender != null
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedGender = null;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 46),
                        padding: const EdgeInsets.all(4),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            selectedItemBuilder: (BuildContext context) {
              return _genderOptions.map<Widget>((String gender) {
                return Container(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    gender,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList();
            },
            items: _genderOptions.map((String gender) {
              return DropdownMenuItem<String>(
                value: gender,
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      // Checkbox indicator
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _selectedGender == gender
                              ? AppTheme.primaryTeal
                              : Colors.transparent,
                          border: Border.all(
                            color: _selectedGender == gender
                                ? AppTheme.primaryTeal
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: _selectedGender == gender
                            ? const Center(
                                child: Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      
                      // Gender option
                      Expanded(
                        child: Text(
                          gender,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _selectedGender == gender
                                ? AppTheme.primaryTeal
                                : Colors.black87,
                            fontWeight: _selectedGender == gender
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
                _selectedGender = newValue;
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? "Edit Profile" : "Complete Your Profile",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryTeal),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Text(
                      "Skip Profile Setup?",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.info,
                            color: AppTheme.primaryTeal,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "You can complete your profile later, but some features may be limited until you do.",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Continue Setup",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BottomNavigationBarPatientScreen(
                                profileStatus: "incomplete",
                                suppressProfilePrompt: true,
                                profileCompletionPercentage: _completionPercentage,
                              ),
                            ),
                            (route) => false,
                          );
                        },
                        child: Text(
                          "Skip Setup",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(LucideIcons.skipForward, size: 18),
            label: Text(
              "Skip",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryTeal,
            ),
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Completion Progress Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTeal.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Profile Completion",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                        Text(
                          "${_completionPercentage.toStringAsFixed(0)}%",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _completionPercentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Complete your profile to get the most out of the app",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
          
              // Rest of the existing UI
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTeal.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            LucideIcons.user,
                            color: AppTheme.primaryTeal,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Personal Information",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Stack(
                          children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryTeal.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryTeal.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _image != null
                                  ? Image.file(
                                      _image!,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryTeal.withOpacity(0.1),
                                            AppTheme.primaryTeal.withOpacity(0.2),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Icon(
                                        LucideIcons.user,
                                        size: 50,
                                        color: AppTheme.primaryTeal.withOpacity(0.5),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryTeal.withOpacity(0.9),
                                      AppTheme.primaryTeal,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryTeal.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _image == null ? LucideIcons.camera : LucideIcons.refreshCw,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      hint: "Full Name",
                      icon: LucideIcons.user,
                      controller: _nameController,
                    ),
                    _buildTextField(
                      hint: "Email",
                      icon: LucideIcons.mail,
                      controller: _emailController,
                    ),
                    _buildCnicField(),
                    _buildGenderDropdown(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTeal.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            LucideIcons.mapPin,
                            color: AppTheme.primaryTeal,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Address Information",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextArea(
                      hint: "Complete Address",
                      icon: LucideIcons.building,
                      controller: _addressController,
                    ),
                    _buildCityDropdown(),
                  ],
                ),
              ),
            const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTeal.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SizedBox(
              width: double.infinity,
                  height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // Show prompt if profile image is missing
                  if (_image == null) {
                    _showProfileImagePrompt(context);
                  } else {
                    _proceedToNextScreen();
                  }
                },
                style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                  ),
                      elevation: 0,
                ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                  "Next",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.arrowRight, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            ),
        ),
      ),
    );
  }

  // Method to show profile image importance prompt
  void _showProfileImagePrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Profile Photo Missing",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryTeal,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.user,
                color: AppTheme.primaryTeal,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Adding a profile photo helps doctors identify you and improves your profile completeness. Your profile won't be 100% complete without a photo.",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.darkText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage();
            },
            child: Text(
              "Add Photo",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryTeal,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _proceedToNextScreen();
            },
            child: Text(
              "Continue Anyway",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Method to proceed to the next screen
  void _proceedToNextScreen() async {
    // Prepare data to pass to the next screen
    Map<String, dynamic> profileData = {
      'name': _nameController.text,
      'email': _emailController.text,
      'cnic': _cnicController.text,
      'address': _addressController.text,
      'city': _selectedCity,
      'gender': _selectedGender,
      'profileImagePath': _image?.path,
      'completionPercentage': _completionPercentage,
      'hasProfileImage': _image != null,
      'phoneNumber': _authPhoneNumber,
      'isEditing': widget.isEditing, // Pass editing status to next screen
    };
    
    try {
      // Save first page data to Firestore
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final userId = auth.currentUser?.uid;
      
      if (userId != null) {
        // Get phone number from auth if not already available
        if (_authPhoneNumber == null) {
          _authPhoneNumber = auth.currentUser?.phoneNumber;
        }
        
        // Update the user record first
        await firestore.collection('users').doc(userId).update({
          'fullName': _nameController.text,
          'email': _emailController.text,
          'phoneNumber': _authPhoneNumber,
        });
        
        // Create/update patient profile in patients collection
        await firestore.collection('patients').doc(userId).set({
          'id': userId,
          'fullName': _nameController.text,
          'email': _emailController.text,
          'phoneNumber': _authPhoneNumber,
          'cnic': _cnicController.text,
          'address': _addressController.text,
          'city': _selectedCity,
          'gender': _selectedGender,
          'profileComplete': false, // Will be set to true after page 2
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        // Upload profile image if available
        if (_image != null) {
          // Create an instance of the StorageService
          final storageService = StorageService();
          
          // Convert File to XFile for the storage service
          final XFile imageXFile = XFile(_image!.path);
          
          // Upload profile image using the service
          String downloadUrl = await storageService.uploadProfileImage(
            file: imageXFile,
            userId: userId,
            isDoctor: false, // This is a patient profile
          );
          
          // Update profile with image URL
          await firestore.collection('patients').doc(userId).update({
            'profileImageUrl': downloadUrl,
          });
          
          // Add the URL to the profile data for next page
          profileData['profileImageUrl'] = downloadUrl;
        }
        
        // Store the userId in the profile data
        profileData['userId'] = userId;
        
        // Print debug info before navigation
        print("Proceeding to next screen with profile data:");
        profileData.forEach((key, value) {
          print("  $key: $value");
        });
      }

      // Always proceed to page 2
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CompleteProfilePatient2Screen(
            profileData: profileData,
          ),
        ),
      );
    } catch (e) {
      print('Error saving profile data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // New method to fetch user data from Firestore
  Future<void> _fetchUserDataFromFirestore() async {
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final userId = auth.currentUser?.uid;
      
      if (userId != null) {
        // Get phone number from auth
        _authPhoneNumber = auth.currentUser?.phoneNumber;
        
        // Check if user profile exists in patients collection
        final patientDoc = await firestore.collection('patients').doc(userId).get();
        
        if (patientDoc.exists) {
          final userData = patientDoc.data() as Map<String, dynamic>;
          
          setState(() {
            _nameController.text = userData['fullName'] ?? '';
            _emailController.text = userData['email'] ?? '';
            _addressController.text = userData['address'] ?? '';
            _cnicController.text = userData['cnic'] ?? '';
            _selectedCity = userData['city'];
            _selectedGender = userData['gender'];
            
            // Use phone from Firestore if available, otherwise keep auth phone
            if (userData['phoneNumber'] != null && userData['phoneNumber'].isNotEmpty) {
              _authPhoneNumber = userData['phoneNumber'];
            }
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  // Add a method to get phone number from FirebaseAuth
  Future<void> _getAuthPhoneNumber() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _authPhoneNumber = user.phoneNumber;
        print("Retrieved phone number from auth: $_authPhoneNumber");
      }
    } catch (e) {
      print("Error getting auth phone number: $e");
    }
  }
}

// Custom formatter for Pakistani CNIC format (00000-0000000-0)
class _CnicFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final newText = StringBuffer();
    final String rawText = newValue.text.replaceAll('-', '');
    
    for (int i = 0; i < rawText.length; i++) {
      if (i == 5 || i == 12) {
        newText.write('-');
      }
      newText.write(rawText[i]);
    }

    return TextEditingValue(
      text: newText.toString(),
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
