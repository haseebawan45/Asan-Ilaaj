import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:healthcare/views/screens/dashboard/home.dart';
import 'package:image_picker/image_picker.dart';
import 'package:healthcare/views/screens/bottom_navigation_bar.dart';
import 'package:healthcare/utils/navigation_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:healthcare/utils/app_theme.dart';
import 'package:healthcare/utils/ui_helper.dart';
import 'dart:io';

class DoctorProfilePage2Screen extends StatefulWidget {
  final String fullName;
  final String email;
  final String address;
  final String city;
  final XFile? profileImage;
  final XFile? medicalLicenseFront;
  final XFile? medicalLicenseBack;
  final XFile? cnicFront;
  final XFile? cnicBack;
  final bool isEditing;
  final String? profileImageUrl;
  final String? medicalLicenseFrontUrl;
  final String? medicalLicenseBackUrl;
  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final String gender;
  
  const DoctorProfilePage2Screen({
    super.key, 
    required this.fullName,
    required this.email,
    required this.address,
    required this.city,
    this.profileImage,
    this.medicalLicenseFront,
    this.medicalLicenseBack,
    this.cnicFront,
    this.cnicBack,
    this.isEditing = false,
    this.profileImageUrl,
    this.medicalLicenseFrontUrl,
    this.medicalLicenseBackUrl,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.gender = "",
  });

  @override
  State<DoctorProfilePage2Screen> createState() => _DoctorProfilePage2ScreenState();
}

class _DoctorProfilePage2ScreenState extends State<DoctorProfilePage2Screen> {
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _qualificationController = TextEditingController();
  final TextEditingController _consultationFeeController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _degreeInstitutionController = TextEditingController();
  final TextEditingController _degreeCompletionDateController = TextEditingController();

  // Specialization dropdown
  String? _selectedSpecialization;

  // List of specialties from PatientHomeScreen
  final List<Map<String, dynamic>> _specialties = [
    {"name": "Cardiology", "nameUrdu": "امراض قلب", "icon": LucideIcons.heartPulse, "color": Color(0xFFF44336)},
    {"name": "Neurology", "nameUrdu": "امراض اعصاب", "icon": LucideIcons.brain, "color": Color(0xFF2196F3)},
    {"name": "Dermatology", "nameUrdu": "جلدی امراض", "icon": Icons.face_retouching_natural, "color": Color(0xFFFF9800)},
    {"name": "Pediatrics", "nameUrdu": "اطفال", "icon": Icons.child_care, "color": Color(0xFF4CAF50)},
    {"name": "Orthopedics", "nameUrdu": "ہڈیوں کے امراض", "icon": LucideIcons.bone, "color": Color(0xFF9C27B0)},
    {"name": "ENT", "nameUrdu": "کان ناک گلے کے امراض", "icon": LucideIcons.ear, "color": Color(0xFF00BCD4)},
    {"name": "Gynecology", "nameUrdu": "نسائی امراض", "icon": Icons.pregnant_woman, "color": Color(0xFFE91E63)},
    {"name": "Ophthalmology", "nameUrdu": "آنکھوں کے امراض", "icon": LucideIcons.eye, "color": Color(0xFF3F51B5)},
    {"name": "Dentistry", "nameUrdu": "دانتوں کے امراض", "icon": Icons.healing, "color": Color(0xFF607D8B)},
    {"name": "Psychiatry", "nameUrdu": "نفسیاتی امراض", "icon": LucideIcons.brain, "color": Color(0xFF795548)},
    {"name": "Pulmonology", "nameUrdu": "پھیپھڑوں کے امراض", "icon": Icons.air, "color": Color(0xFF009688)},
    {"name": "Gastrology", "nameUrdu": "معدے کے امراض", "icon": Icons.local_dining, "color": Color(0xFFFF5722)},
  ];

  XFile? _degreeImage;
  String? _degreeImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Set transparent status bar for this screen (white app bar)
    UIHelper.applyTransparentStatusBar(withPostFrameCallback: true);
    
    // If in editing mode, load existing data from Firestore
    if (widget.isEditing) {
      _loadDoctorData();
    }
  }
  
  // Load doctor data from Firestore
  Future<void> _loadDoctorData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Get doctor document from Firestore
      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(userId)
          .get();
      
      if (!doctorDoc.exists) {
        throw Exception('Doctor profile not found');
      }
      
      final data = doctorDoc.data() as Map<String, dynamic>;
      
      // Populate form fields with existing data
      setState(() {
        _experienceController.text = data['experience'] ?? '';
        _consultationFeeController.text = data['fee'] != null ? 'Rs ${data['fee']}' : '';
        _bioController.text = data['bio'] ?? '';
        
        // Set qualification from the qualifications array if available
        if (data['qualifications'] != null && data['qualifications'] is List && data['qualifications'].isNotEmpty) {
          _qualificationController.text = data['qualifications'][0] ?? '';
        }
        
        // Set specialization
        _selectedSpecialization = data['specialty'];
        
        // Get education details if available
        if (data['education'] != null && data['education'] is List && data['education'].isNotEmpty) {
          final education = data['education'][0] as Map<String, dynamic>;
          _degreeInstitutionController.text = education['institution'] ?? '';
          _degreeCompletionDateController.text = education['completionDate'] ?? '';
        }
        
        // Get degree image URL
        _degreeImageUrl = data['degreeImageUrl'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDocument() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _degreeImage = image;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _degreeCompletionDateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  bool _isValidNumber(String value) {
    return RegExp(r'^\d+$').hasMatch(value);
  }

  bool _isValidDate(String date) {
    return RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(date);
  }

  String _formatCurrency(String value) {
    if (value.isEmpty) return '';
    final number = int.tryParse(value);
    if (number == null) return value;
    return 'Rs ${number.toString()}';
  }

  bool _validateFields() {
    // Commenting out validation for debugging
    /*
    if (_selectedSpecialization == null ||
        _experienceController.text.isEmpty ||
        _qualificationController.text.isEmpty ||
        _consultationFeeController.text.isEmpty ||
        _degreeInstitutionController.text.isEmpty ||
        _degreeCompletionDateController.text.isEmpty ||
        _degreeImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and upload all required documents'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (!_isValidNumber(_experienceController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number for years of experience'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (!_isValidNumber(_consultationFeeController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid consultation fee'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (!_isValidDate(_degreeCompletionDateController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid date in DD/MM/YYYY format'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    */
    return true;
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isDateField = false,
    bool isNumberField = false,
    bool isCurrencyField = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.1),
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
        readOnly: isDateField,
        keyboardType: isNumberField ? TextInputType.number : TextInputType.text,
        onTap: isDateField ? () => _selectDate(context) : null,
        onChanged: (value) {
          if (isCurrencyField && value.isNotEmpty) {
            final formattedValue = _formatCurrency(value);
            if (formattedValue != value) {
              controller.text = formattedValue;
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: formattedValue.length),
              );
            }
          }
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: AppTheme.primaryPink,
              size: 20,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // Build specialization dropdown
  Widget _buildSpecializationDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedSpecialization,
        hint: Text(
          "Select Specialization",
          style: GoogleFonts.poppins(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        decoration: InputDecoration(
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              LucideIcons.stethoscope,
              color: AppTheme.primaryPink,
              size: 20,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        isExpanded: true,
        elevation: 8,
        style: GoogleFonts.poppins(
          color: Colors.black87,
          fontSize: 14,
        ),
        onChanged: (String? value) {
          setState(() {
            _selectedSpecialization = value;
          });
        },
        items: _specialties.map<DropdownMenuItem<String>>((Map<String, dynamic> specialty) {
          return DropdownMenuItem<String>(
            value: specialty["name"],
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (specialty["color"] as Color).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    specialty["icon"] as IconData,
                    color: specialty["color"] as Color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  specialty["name"],
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  "(${specialty["nameUrdu"]})",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Submit the profile data to Firestore
  Future<void> _submitProfile() async {
    if (!_validateFields()) return;

    try {
      // Show loading indicator
      setState(() {
        // Set loading state if needed
      });

      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final userId = auth.currentUser?.uid;

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get user data from the users collection
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User profile not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Update the user's fullName in the users collection
      await firestore.collection('users').doc(userId).update({
        'fullName': widget.fullName,
        'email': widget.email,
      });

      // Upload images to Firebase Storage and get URLs
      String? profileImageUrl = widget.profileImageUrl;
      String? medicalLicenseFrontUrl = widget.medicalLicenseFrontUrl;
      String? medicalLicenseBackUrl = widget.medicalLicenseBackUrl;
      String? cnicFrontUrl = widget.cnicFrontUrl;
      String? cnicBackUrl = widget.cnicBackUrl;
      String? degreeImageUrl;
      
      // Upload profile image if available and changed
      if (widget.profileImage != null) {
        final ref = firebase_storage.FirebaseStorage.instance
            .ref()
            .child('doctors')
            .child(userId)
            .child('profile_image.jpg');
        await ref.putFile(File(widget.profileImage!.path));
        profileImageUrl = await ref.getDownloadURL();
      }
      
      // Upload medical license images if available and changed
      if (widget.medicalLicenseFront != null) {
        final ref = firebase_storage.FirebaseStorage.instance
            .ref()
            .child('doctors')
            .child(userId)
            .child('medical_license_front.jpg');
        await ref.putFile(File(widget.medicalLicenseFront!.path));
        medicalLicenseFrontUrl = await ref.getDownloadURL();
      }
      
      if (widget.medicalLicenseBack != null) {
        final ref = firebase_storage.FirebaseStorage.instance
            .ref()
            .child('doctors')
            .child(userId)
            .child('medical_license_back.jpg');
        await ref.putFile(File(widget.medicalLicenseBack!.path));
        medicalLicenseBackUrl = await ref.getDownloadURL();
      }
      
      // Upload CNIC images if available and changed
      if (widget.cnicFront != null) {
        final ref = firebase_storage.FirebaseStorage.instance
            .ref()
            .child('doctors')
            .child(userId)
            .child('cnic_front.jpg');
        await ref.putFile(File(widget.cnicFront!.path));
        cnicFrontUrl = await ref.getDownloadURL();
      }
      
      if (widget.cnicBack != null) {
        final ref = firebase_storage.FirebaseStorage.instance
            .ref()
            .child('doctors')
            .child(userId)
            .child('cnic_back.jpg');
        await ref.putFile(File(widget.cnicBack!.path));
        cnicBackUrl = await ref.getDownloadURL();
      }
      
      // Upload degree image if available
      if (_degreeImage != null) {
        final ref = firebase_storage.FirebaseStorage.instance
            .ref()
            .child('doctors')
            .child(userId)
            .child('degree_image.jpg');
        await ref.putFile(File(_degreeImage!.path));
        degreeImageUrl = await ref.getDownloadURL();
      }

      // Create/update a complete doctor profile document
      Map<String, dynamic> doctorData = {
        // Basic information
        'id': userId,
        'fullName': widget.fullName,
        'email': widget.email,
        'phoneNumber': userData['phoneNumber'] ?? '',
        'address': widget.address,
        'city': widget.city,
        'gender': widget.gender,
        
        // Professional information
        'specialty': _selectedSpecialization,
        'experience': _experienceController.text,
        'qualifications': [_qualificationController.text],
        'fee': int.tryParse(_consultationFeeController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0,
        'bio': _bioController.text,
        
        // Education
        'education': [
          {
            'degree': _qualificationController.text,
            'institution': _degreeInstitutionController.text,
            'completionDate': _degreeCompletionDateController.text,
          }
        ],
        
        // Image URLs
        'profileImageUrl': profileImageUrl,
        'medicalLicenseFrontUrl': medicalLicenseFrontUrl,
        'medicalLicenseBackUrl': medicalLicenseBackUrl,
        'cnicFrontUrl': cnicFrontUrl,
        'cnicBackUrl': cnicBackUrl,
        
        // Profile management
        'updatedAt': FieldValue.serverTimestamp(),
        'profileComplete': true,
      };
      
      // Add degree image URL if available
      if (degreeImageUrl != null) {
        doctorData['degreeImageUrl'] = degreeImageUrl;
      }
      
      // If not in editing mode, add these fields as well
      if (!widget.isEditing) {
        doctorData.addAll({
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': false, // Admin needs to verify
          'isActive': true,
          'rating': 5.0, // Default rating for new doctors
          'languages': ['English', 'Urdu'],
          'availableDays': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        });
      }

      // Set or update the doctor document
      await firestore.collection('doctors').doc(userId).set(
        doctorData,
        SetOptions(merge: widget.isEditing), // Use merge if editing
      );

      // Update the user document to mark profile as complete
      await firestore.collection('users').doc(userId).update({
        'profileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? 'Profile updated successfully' : 'Profile completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Apply pink status bar before navigation
      UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
      
      // Navigate back or to home screen
      if (widget.isEditing) {
        // If editing mode, return to previous screens
        Navigator.pop(context); // Close current screen
        Navigator.pop(context); // Close previous screen
      } else {
        // If new profile, navigate to home screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const BottomNavigationBarScreen(profileStatus: "complete")),
          (route) => false,
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        // Unset loading state if needed
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Ensure pink status bar is applied when returning
        UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
        return true;
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          "Professional Information",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: AppTheme.primaryPink),
            onPressed: () {
              // Apply pink status bar before popping
              UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
              Navigator.pop(context);
            },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppTheme.veryLightPink,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPink.withOpacity(0.1),
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
                            color: AppTheme.primaryPink.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            LucideIcons.briefcase,
                            color: AppTheme.primaryPink,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Professional Details",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSpecializationDropdown(),
                    _buildTextField(
                      hint: "Years of Experience",
                      icon: LucideIcons.calendar,
                      controller: _experienceController,
                      isNumberField: true,
                    ),
                    _buildTextField(
                      hint: "Highest Qualification",
                      icon: LucideIcons.graduationCap,
                      controller: _qualificationController,
                    ),
                    _buildTextField(
                      hint: "Consultation Fee (Rs)",
                      icon: LucideIcons.banknote,
                      controller: _consultationFeeController,
                      isNumberField: true,
                      isCurrencyField: true,
                    ),
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
                      color: AppTheme.primaryPink.withOpacity(0.1),
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
                            color: AppTheme.primaryPink.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            LucideIcons.graduationCap,
                            color: AppTheme.primaryPink,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Education",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      hint: "Degree Institution",
                      icon: LucideIcons.building2,
                      controller: _degreeInstitutionController,
                    ),
                    _buildTextField(
                      hint: "Degree Completion Date",
                      icon: LucideIcons.calendar,
                      controller: _degreeCompletionDateController,
                      isDateField: true,
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPink.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        onTap: _pickDocument,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPink.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  LucideIcons.fileImage,
                                  color: AppTheme.primaryPink,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Degree Certificate",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Upload your degree certificate",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_degreeImage != null)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    LucideIcons.check,
                                    color: Colors.green,
                                    size: 20,
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
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPink.withOpacity(0.1),
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
                            color: AppTheme.primaryPink.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            LucideIcons.fileText,
                            color: AppTheme.primaryPink,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "About Yourself",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPink.withOpacity(0.1),
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
                        controller: _bioController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: "Write a brief bio about yourself...",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPink.withOpacity(0.2),
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
                      if (_validateFields()) {
                        _submitProfile();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPink,
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
                          widget.isEditing ? "Update Profile" : "Save Profile",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.check, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Ensure pink status bar is applied when the screen is disposed
    UIHelper.applyPinkStatusBar();
    super.dispose();
  }
} 