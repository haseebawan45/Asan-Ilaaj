import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/services/auth_service.dart';
import 'package:healthcare/views/components/onboarding.dart';
import 'package:healthcare/views/components/signup.dart';
import 'package:healthcare/views/screens/bottom_navigation_bar.dart';
import 'package:healthcare/views/screens/common/OTPVerification.dart';
import 'package:healthcare/views/screens/common/signup.dart';
import 'package:healthcare/views/screens/patient/bottom_navigation_patient.dart';
import 'package:healthcare/views/screens/patient/complete_profile/profile_page1.dart';
import 'package:healthcare/views/screens/doctor/complete_profile/doctor_profile_page1.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthcare/utils/app_theme.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

// Custom formatter for Pakistani phone numbers
class PakistaniPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Only process if the value has actually changed
    if (newValue.text == oldValue.text) {
      return newValue;
    }

    // Clean the input (remove all non-digit characters)
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    
    // Remove leading zero if present (convert 03xx to 3xx)
    String processedDigits = digitsOnly;
    if (processedDigits.startsWith('0')) {
      processedDigits = processedDigits.substring(1);
    }
    
    // Format as 3xx xxxxxxx
    String formatted = '';
    
    if (processedDigits.length <= 3) {
      // Just show the first 3 digits (area code)
      formatted = processedDigits;
    } else {
      // Format as 3xx xxxxxxx
      formatted = processedDigits.substring(0, 3);
      formatted += ' ' + processedDigits.substring(3, math.min(processedDigits.length, 10));
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class SignIN extends StatefulWidget {
  const SignIN({super.key});

  @override
  State<SignIN> createState() => _SignINState();
}

class _SignINState extends State<SignIN> with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isValidPhoneInput = false;

  // Add a regular expression pattern for Pakistani phone numbers
  final RegExp _pakistaniPhonePattern = RegExp(r'^3\d{2}\s\d{7}$');

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.1, 0.8, curve: Curves.easeOut),
      ),
    );
    
    // Start animation after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  // Validate phone number
  bool _isValidPhoneNumber(String phone) {
    return _pakistaniPhonePattern.hasMatch(phone.trim());
  }
  
  // Send OTP for sign in
  Future<void> _sendOTP() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a valid phone number';
      });
      return;
    }
    
    // Validate phone number format
    if (!_isValidPhoneNumber(phoneNumber)) {
      setState(() {
        _errorMessage = 'Please enter a valid Pakistani mobile number (3xx xxxxxxx)';
      });
      return;
    }
    
    // Clean the phone number by removing all spaces
    final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    
    // Ensure it starts with 3xx format and format for Firebase (+923xx...)
    final formattedPhoneNumber = '+92$cleanPhoneNumber';
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First check if this phone number exists in our database
      final userCheck = await _authService.getUserByPhoneNumber(formattedPhoneNumber);
      
      if (userCheck.containsKey('error')) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error checking user account: ${userCheck['error']}';
        });
        return;
      }
      
      if (userCheck['exists'] == true) {
        final userRole = userCheck['userRole'] as UserRole;
        final isProfileComplete = userCheck['isProfileComplete'] as bool;
        
        // Show a success message about the found account
        String userRoleDisplay = 'User';
        switch (userRole) {
          case UserRole.doctor: userRoleDisplay = 'Doctor'; break;
          case UserRole.patient: userRoleDisplay = 'Patient'; break;
          case UserRole.ladyHealthWorker: userRoleDisplay = 'Lady Health Worker'; break;
          case UserRole.admin: userRoleDisplay = 'Admin'; break;
          default: userRoleDisplay = 'User'; break;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account found for $userRoleDisplay'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Check if this is an admin phone number
      final isAdmin = await _authService.isAdminPhoneNumber(formattedPhoneNumber);
      if (isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin verification required'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Always proceed with OTP for real security - don't skip verification
      _proceedWithOTP(formattedPhoneNumber);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to sign in. Please try again.';
      });
    }
  }
  
  // Continue with OTP verification
  Future<void> _proceedWithOTP(String formattedPhoneNumber) async {
    try {
      // Send real OTP using Firebase
      final result = await _authService.sendOTP(
        phoneNumber: formattedPhoneNumber,
      );
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success']) {
        // If admin verification
        bool isAdmin = result['isAdmin'] == true;
        
        // If auto-verified (rare, but happens on some Android devices)
        if (result['autoVerified'] == true) {
          // Auto verification succeeded, navigate to home
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign in successful!'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate to appropriate screen based on user role
          _navigateAfterLogin();
        } else {
          // Navigate to OTP verification screen with verification ID
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(
                text: isAdmin ? "Admin Verification" : "Welcome Back",
                phoneNumber: formattedPhoneNumber,
                verificationId: result['verificationId'],
              ),
            ),
          );
        }
      } else {
        // Check if this is a billing issue
        if (result['billingIssue'] == true) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Firebase Authentication'),
              content: Text('To use phone authentication, please enable billing in your Firebase project. Contact the app administrator for assistance.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        } else {
          setState(() {
            _errorMessage = result['error'] ?? 'Failed to send OTP.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to sign in. Please try again.';
      });
    }
  }
  
  // Navigate after successful login
  Future<void> _navigateAfterLogin() async {
    // Get the current user role from Firestore
    final userRole = await _authService.getUserRole();
      final isProfileComplete = await _authService.isProfileComplete();
      
    // Store login info in shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    
    // Navigate based on user role and profile completion status
    if (userRole == UserRole.doctor) {
      if (isProfileComplete) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BottomNavigationBarScreen(
              profileStatus: "complete",
              userType: "Doctor",
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorProfilePage1Screen(),
          ),
        );
      }
    } else if (userRole == UserRole.patient) {
      if (isProfileComplete) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BottomNavigationBarScreen(
              profileStatus: "complete",
              userType: "Patient",
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CompleteProfilePatient1Screen(),
          ),
        );
      }
    } else if (userRole == UserRole.admin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BottomNavigationBarScreen(
            profileStatus: "complete",
            userType: "Admin",
          ),
        ),
      );
    } else {
      // Default case
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SignUp(type: "Patient"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back button
                    Padding(
                      padding: EdgeInsets.only(
                        top: screenHeight * 0.02,
                        left: screenWidth * 0.05,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                          },
                child: Container(
                            padding: EdgeInsets.all(screenWidth * 0.02),
                  decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(screenWidth * 0.02),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_rounded,
                              size: screenWidth * 0.05,
                              color: Colors.black87,
                    ),
                  ),
                ),
              ),
                    ),
                    
                    // Logo
                    Padding(
                      padding: EdgeInsets.only(top: screenHeight * 0.04),
                      child: Center(
                        child: Image.asset(
                          "assets/images/logo.png",
                          width: screenWidth * 0.4,
                          fit: BoxFit.contain,
                  ),
                ),
              ),
              
                    // Welcome text
                    FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                        child: Container(
                          padding: EdgeInsets.only(
                            left: screenWidth * 0.08,
                            right: screenWidth * 0.08,
                            top: screenHeight * 0.04,
                          ),
                    child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                              Text(
                                "Welcome Back",
                                style: GoogleFonts.poppins(
                                  fontSize: screenWidth * 0.075,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryPink,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.015),
                              Text(
                                "Sign in to continue with your Specialist Doctors account",
                                style: GoogleFonts.poppins(
                                  fontSize: screenWidth * 0.04,
                                  color: AppTheme.mediumText,
                ),
              ),
            ],
          ),
        ),
      ),
                    ),
                    
                    // Phone input container
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
      child: Container(
                          margin: EdgeInsets.only(
                            top: screenHeight * 0.04,
                            left: screenWidth * 0.08,
                            right: screenWidth * 0.08,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.05,
                            vertical: screenHeight * 0.01,
                          ),
          decoration: BoxDecoration(
            color: Colors.white,
                            borderRadius: BorderRadius.circular(screenWidth * 0.03),
                            border: Border.all(
                              color: _errorMessage != null 
                                  ? AppTheme.error.withOpacity(0.8)
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
            boxShadow: [
              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Flag and country code
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.02,
                                  vertical: screenHeight * 0.008,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                                ),
                                child: Row(
                                  children: [
        Text(
                                      "🇵🇰",
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.05,
                                      ),
                                    ),
                                    SizedBox(width: screenWidth * 0.01),
        Text(
                                      "+92",
          style: GoogleFonts.poppins(
                                        fontSize: screenWidth * 0.04,
                                        fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
                              ),
                              
                              SizedBox(width: screenWidth * 0.03),
                              
                              // Phone number input
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: [
                                          // Custom formatter for Pakistani phone numbers
                                          PakistaniPhoneFormatter(),
                                          // Limit total length (including space)
                                          LengthLimitingTextInputFormatter(11),
                                        ],
                                        style: GoogleFonts.poppins(
                                          fontSize: screenWidth * 0.045,
                                          letterSpacing: 0.5,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: "3XX XXXXXXX",
                                          hintStyle: GoogleFonts.poppins(
                                            fontSize: screenWidth * 0.04,
                                            color: AppTheme.lightText,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.02,
                                            vertical: screenHeight * 0.015,
                                          ),
                                          suffixIcon: _phoneController.text.isNotEmpty ? 
                                            (_isValidPhoneInput ? 
                                              Icon(Icons.check_circle, color: AppTheme.success, size: screenWidth * 0.05) : 
                                              null) : 
                                            null,
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            // Check if the input is a valid phone number
                                            _isValidPhoneInput = _isValidPhoneNumber(value);
                                            
                                            // Clear error message when user types
                                            if (_errorMessage != null) {
                                              _errorMessage = null;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Error message
                    if (_errorMessage != null)
                      Container(
                        margin: EdgeInsets.only(
                          top: screenHeight * 0.01,
                          left: screenWidth * 0.09,
                          right: screenWidth * 0.09,
                        ),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                            color: AppTheme.error,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                      ),
                    
                    // Continue Button
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
      child: Container(
                          margin: EdgeInsets.only(
                            top: screenHeight * 0.035,
                            left: screenWidth * 0.08,
                            right: screenWidth * 0.08,
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPink,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(screenWidth * 0.03),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: screenHeight * 0.018,
                              ),
                              elevation: 0,
                              disabledBackgroundColor: AppTheme.primaryPink.withOpacity(0.5),
                            ),
          child: _isLoading 
              ? SizedBox(
                                    width: screenWidth * 0.06,
                                    height: screenWidth * 0.06,
                  child: CircularProgressIndicator(
                                      color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                                : Text(
                                    "Continue",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                                      fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    
                    // OR continue with
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: EdgeInsets.only(
                          top: screenHeight * 0.04,
                          bottom: screenHeight * 0.02,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                                height: 1,
                                color: Colors.grey.shade300,
                              ),
                            ),
                            Text(
                              "OR",
                              style: GoogleFonts.poppins(
                                color: AppTheme.lightText,
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                                height: 1,
                                color: Colors.grey.shade300,
                              ),
                    ),
                  ],
                ),
        ),
      ),
                    
                    // Sign up link
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: EdgeInsets.only(
                          top: screenHeight * 0.02,
                          bottom: screenHeight * 0.04,
                        ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: GoogleFonts.poppins(
                                fontSize: screenWidth * 0.038,
              color: AppTheme.mediumText,
            ),
          ),
                            InkWell(
                              onTap: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => SignUp(type: "Patient"),
                                  ),
                                );
                              },
                              child: Text(
            "Sign Up",
            style: GoogleFonts.poppins(
                                  fontSize: screenWidth * 0.038,
              fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryPink,
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}
