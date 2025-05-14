import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/services/auth_service.dart';
import 'package:healthcare/views/components/onboarding.dart';
import 'package:healthcare/views/components/signup.dart';
import 'package:healthcare/views/screens/common/OTPVerification.dart';
import 'package:healthcare/views/screens/common/signin.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

class SignUp extends StatefulWidget {
  final String type;
  const SignUp({super.key, required this.type});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  late String type;
  bool privacyAccepted = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isValidPhoneInput = false;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  
  // Add a regular expression pattern for Pakistani phone numbers
  final RegExp _pakistaniPhonePattern = RegExp(r'^3\d{2}\s\d{7}$');

  @override
  void initState() {
    super.initState();
    type = widget.type;
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  
  // Validate phone number
  bool _isValidPhoneNumber(String phone) {
    return _pakistaniPhonePattern.hasMatch(phone.trim());
  }
  
  // Send OTP to the provided phone number
  Future<void> _sendOTP() async {
    // Validate inputs
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your full name';
      });
      return;
    }

    // Check name has at least 3 characters and is properly formatted
    final name = _nameController.text.trim();
    if (name.length < 3) {
      setState(() {
        _errorMessage = 'Name should be at least 3 characters';
      });
      return;
    }
    
    // Check for invalid characters in name
    if (name.contains(RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]'))) {
      setState(() {
        _errorMessage = 'Name should not contain numbers or special characters';
      });
      return;
    }
    
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
    
    print('***** SIGNUP PROCESS FOR USER TYPE: $type *****');
    
    try {
      // Check if this phone number already exists in our database
      final userCheck = await _authService.getUserByPhoneNumber(formattedPhoneNumber);
      
      if (userCheck.containsKey('error')) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error checking user account: ${userCheck['error']}';
        });
        return;
      }
      
      if (userCheck['exists'] == true) {
        // Phone number already exists
        setState(() {
          _isLoading = false;
        });
        
        // Get user role
        final userRole = userCheck['userRole'] as UserRole;
        String userRoleDisplay = 'account';
        switch (userRole) {
          case UserRole.doctor: userRoleDisplay = 'Doctor account'; break;
          case UserRole.patient: userRoleDisplay = 'Patient account'; break;
          case UserRole.ladyHealthWorker: userRoleDisplay = 'Lady Health Worker account'; break;
          case UserRole.admin: userRoleDisplay = 'Admin account'; break;
          default: userRoleDisplay = 'account'; break;
        }
        
        // Show a dialog to inform the user
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Account Already Exists'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This phone number is already registered as a $userRoleDisplay.'),
                SizedBox(height: 8),
                Text('Would you like to sign in instead?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  
                  // Redirect to sign in screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignIN()),
                  );
                },
                child: Text('Go to Sign In'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
            ],
          ),
        );
        return;
      }
      
      // Phone number doesn't exist, proceed with OTP sending
      final result = await _authService.sendOTP(
        phoneNumber: formattedPhoneNumber,
      );
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success']) {
        print('***** OTP SENT SUCCESSFULLY FOR USER TYPE: $type *****');
        
        // Navigate to OTP verification screen with verification ID
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              text: "Sign Up as a $type",
              phoneNumber: formattedPhoneNumber,
              verificationId: result['verificationId'],
              fullName: _nameController.text.trim(),
              userType: type,
            ),
          ),
        );
        
        // Show a snackbar indicating OTP was sent
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code has been sent to $formattedPhoneNumber'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
            _errorMessage = result['message'];
          });
          
          // Show a snackbar with error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send verification code: ${result['message']}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to send OTP. Please try again.';
      });
      
      print('***** ERROR IN _sendOTP: $e *****');
      
      // Show more detailed error in snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarOnboarding(isBackButtonVisible: true, text: ''),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 20),
                  child: Column(
                    children: [
                      Center(child: Image.asset("assets/images/logo.png", height: 100)),
                      const SizedBox(height: 16),
                      Text(
                        'Create Account',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign up as a $type',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppTheme.mediumText,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 30),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Name',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: "Enter your full name",
                          prefixIcon: Icon(LucideIcons.user),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.primaryPink, width: 1.5),
                          ),
                        ),
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 20),
                      
                      Text(
                        'Phone Number',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _errorMessage != null && _errorMessage!.contains('phone')
                                ? AppTheme.error.withOpacity(0.8)
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Flag and country code
                            Container(
                              margin: const EdgeInsets.only(left: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    "🇵🇰",
                                    style: TextStyle(
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "+92",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Phone number input
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
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                                decoration: InputDecoration(
                                  hintText: "3XX XXXXXXX",
                                  hintStyle: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppTheme.lightText,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 16,
                                  ),
                                  suffixIcon: _phoneController.text.isNotEmpty ? 
                                    (_isValidPhoneInput ? 
                                      Icon(Icons.check_circle, color: AppTheme.success, size: 20) : 
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
                      const SizedBox(height: 8),
                      Text(
                        'We\'ll send a verification code to this number',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.lightText,
                        ),
                      ),
                      
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                PrivacyPolicy(
                  isselected: privacyAccepted,
                  onChanged: (newValue) {
                    setState(() {
                      privacyAccepted = newValue;
                    });
                  },
                ),
                
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 24),
                  child: InkWell(
                    onTap: privacyAccepted && !_isLoading
                        ? _sendOTP
                        : null,
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryPink,
                            ),
                          )
                        : ProceedButton(
                            isEnabled: privacyAccepted,
                            text: 'Send OTP',
                          ),
                  ),
                ),
                
                Container(
                  margin: const EdgeInsets.only(bottom: 40),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignIN()),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: GoogleFonts.poppins(
                            color: AppTheme.mediumText,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sign In',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryPink,
                            fontSize: 14,
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
      ),
    );
  }
}
