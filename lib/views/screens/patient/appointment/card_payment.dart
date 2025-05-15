import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/views/components/onboarding.dart';
import 'package:healthcare/views/screens/patient/appointment/successfull_appoinment.dart';
import 'package:healthcare/views/screens/menu/appointment_history.dart';
import 'package:healthcare/views/screens/patient/dashboard/finance.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthcare/utils/patient_navigation_helper.dart';
import 'package:healthcare/views/screens/patient/appointment/completed_appointments_screen.dart';
import 'package:healthcare/views/screens/appointment/all_appoinments.dart';
import 'package:healthcare/views/screens/patient/bottom_navigation_patient.dart';

class CardPaymentScreen extends StatefulWidget {
  final Map<String, dynamic>? appointmentDetails;
  
  const CardPaymentScreen({
    super.key,
    this.appointmentDetails,
  });

  @override
  _CardPaymentScreenState createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final TextEditingController _cardNameController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  
  bool _isLoading = false;
  CardType _cardType = CardType.Invalid;
  
  // Focus nodes for form fields
  final FocusNode _cardNumberFocus = FocusNode();
  final FocusNode _expiryDateFocus = FocusNode();
  final FocusNode _cvvFocus = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(_getCardTypeFrmNumber);
  }
  
  @override
  void dispose() {
    _cardNumberController.removeListener(_getCardTypeFrmNumber);
    _cardNumberController.dispose();
    _cardNameController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _cardNumberFocus.dispose();
    _expiryDateFocus.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }
  
  void _getCardTypeFrmNumber() {
    if (_cardNumberController.text.length <= 4) {
      String input = _cardNumberController.text.trim();
      CardType type = CardType.Invalid;
      
      if (input.startsWith(RegExp(r'[4]'))) {
        type = CardType.Visa;
      } else if (input.startsWith(RegExp(r'[5]'))) {
        type = CardType.MasterCard;
      } else if (input.startsWith(RegExp(r'[3]'))) {
        type = CardType.AmericanExpress;
      } else if (input.startsWith(RegExp(r'[6]'))) {
        type = CardType.Discover;
      }
      
      setState(() {
        _cardType = type;
      });
    }
  }

  String _getCardIcon() {
    switch (_cardType) {
      case CardType.Visa:
        return '💳 Visa';
      case CardType.MasterCard:
        return '💳 MasterCard';
      case CardType.AmericanExpress:
        return '💳 Amex';
      case CardType.Discover:
        return '💳 Discover';
      default:
        return '💳 Card';
    }
  }

  Color _getCardTypeColor() {
    switch (_cardType) {
      case CardType.Visa:
        return Color(0xFF1A1F71);
      case CardType.MasterCard:
        return Color(0xFFFF5F00);
      case CardType.AmericanExpress:
        return Color(0xFF2E77BC);
      case CardType.Discover:
        return Color(0xFFFF6000);
      default:
        return Color(0xFF3366CC);
    }
  }

  bool _validateCardNumber(String number) {
    // Remove spaces and non-digit characters
    String cleanNumber = number.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a valid length
    if (cleanNumber.length < 13 || cleanNumber.length > 19) {
      return false;
    }
    
    // Luhn algorithm
    int sum = 0;
    bool alternate = false;
    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cleanNumber[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }
      sum += digit;
      alternate = !alternate;
    }
    return (sum % 10 == 0);
  }

  bool _validateExpiryDate(String date) {
    if (date.length != 5) return false;
    
    try {
      int month = int.parse(date.substring(0, 2));
      int year = int.parse(date.substring(3));
      
      if (month < 1 || month > 12) return false;
      
      // Get current year and month
      DateTime now = DateTime.now();
      int currentYear = now.year % 100;
      int currentMonth = now.month;
      
      // Check if card is expired
      if (year < currentYear || (year == currentYear && month < currentMonth)) {
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  bool _validateCVV(String cvv) {
    return cvv.length >= 3 && cvv.length <= 4 && RegExp(r'^\d+$').hasMatch(cvv);
  }

  void _processPayment() {
    // Validate card number
    if (!_validateCardNumber(_cardNumberController.text)) {
      _showError("Invalid card number");
      return;
    }
    
    // Validate expiry date
    if (!_validateExpiryDate(_expiryDateController.text)) {
      _showError("Invalid or expired card");
      return;
    }
    
    // Validate CVV
    if (!_validateCVV(_cvvController.text)) {
      _showError("Invalid CVV");
      return;
    }
    
    // Validate cardholder name
    if (_cardNameController.text.isEmpty) {
      _showError("Please enter cardholder name");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    Future.delayed(Duration(seconds: 2), () async {
      // Get the current user ID
      final user = FirebaseAuth.instance.currentUser;
      final String? userId = user?.uid;
      
      if (userId != null) {
        try {
          // Get the appointment ID from the details
          String? appointmentId = widget.appointmentDetails?['id'];
          
          if (appointmentId == null) {
            throw Exception("Appointment ID is missing");
          }
          
          // Get the appointment document reference
          final appointmentRef = FirebaseFirestore.instance.collection('appointments').doc(appointmentId);
          
          // Get the current appointment data
          final appointmentDoc = await appointmentRef.get();
          if (!appointmentDoc.exists) {
            throw Exception("Appointment not found");
          }
          
          // Get the fee amount 
          int amountValue = 0;
          if (widget.appointmentDetails?['fee'] != null) {
            // Handle both string and int fee values
            if (widget.appointmentDetails!['fee'] is int) {
              amountValue = widget.appointmentDetails!['fee'];
            } else if (widget.appointmentDetails!['fee'] is String) {
              // Try to parse the string to get the number
              String feeStr = widget.appointmentDetails!['fee'];
              // Remove non-numeric characters like "Rs. " or commas
              feeStr = feeStr.replaceAll(RegExp(r'[^0-9]'), '');
              if (feeStr.isNotEmpty) {
                amountValue = int.parse(feeStr);
              }
            }
          }
          
          // Update the appointment to mark it as booked and paid
          await appointmentRef.update({
            'status': 'confirmed',
            'paymentStatus': 'completed',
            'paymentMethod': 'Credit Card',
            'cardType': _getCardType(_cardNumberController.text),
            'paymentDate': FieldValue.serverTimestamp(),
            'isBooked': true, // Mark as booked
            'updatedAt': FieldValue.serverTimestamp(),
            'hasFinancialTransaction': true,
          });
          
          // Save the transaction to Firestore
          await FirebaseFirestore.instance.collection('transactions').add({
            'userId': userId,
            'patientId': userId,
            'doctorId': widget.appointmentDetails?['doctorId'],
            'appointmentId': appointmentId,
            'title': 'Appointment Payment',
            'description': 'Consultation with ${widget.appointmentDetails?['doctor'] ?? "Doctor"}',
            'amount': amountValue,
            'date': Timestamp.now(),
            'type': 'payment',
            'status': 'completed',
            'paymentMethod': 'Card',
            'doctorName': widget.appointmentDetails?['doctor'] ?? "Doctor",
            'hospitalName': widget.appointmentDetails?['hospital'] ?? "Hospital",
            'cardType': _getCardType(_cardNumberController.text),
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
          
          print('Appointment and transaction saved successfully');
          
          setState(() {
            _isLoading = false;
          });
          
          // Using a completely different dialog approach with AlertDialog
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              final Size screenSize = MediaQuery.of(context).size;
              final double horizontalPadding = screenSize.width * 0.06;
              final double verticalPadding = screenSize.height * 0.03;
              final double iconSize = screenSize.width * 0.12;
              final double titleFontSize = screenSize.width * 0.055;
              final double subtitleFontSize = screenSize.width * 0.035;
              final double buttonHeight = screenSize.height * 0.06;
              
              return Dialog(
                insetPadding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(screenSize.width * 0.06),
                ),
                elevation: 10,
                shadowColor: Colors.black38,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate responsive dimensions based on available space
                    final maxWidth = constraints.maxWidth;
                    final maxHeight = constraints.maxHeight;
                    final isSmallScreen = maxWidth < 360;
                    
                    // Adjust sizes based on available space
                    final adjustedIconSize = maxWidth * 0.15;
                    final adjustedTitleSize = maxWidth * (isSmallScreen ? 0.045 : 0.055);
                    final adjustedSubtitleSize = maxWidth * (isSmallScreen ? 0.032 : 0.035);
                    final adjustedButtonHeight = maxHeight * 0.08;
                    
                    return Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxWidth: 450,
                        maxHeight: screenSize.height * 0.8,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                vertical: verticalPadding,
                                horizontal: horizontalPadding
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF2754C3),
                                    Color(0xFF4B7BFB),
                                  ],
                                ),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(screenSize.width * 0.06)),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(maxWidth * 0.035),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 12,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      LucideIcons.checkCheck,
                                      color: Color(0xFF2754C3),
                                      size: adjustedIconSize,
                                    ),
                                  ),
                                  SizedBox(height: verticalPadding * 0.7),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "Payment Successful!",
                                      style: GoogleFonts.poppins(
                                        fontSize: adjustedTitleSize,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: verticalPadding * 0.3),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "Your appointment has been confirmed",
                                      style: GoogleFonts.poppins(
                                        fontSize: adjustedSubtitleSize,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.all(horizontalPadding),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(screenSize.width * 0.06)),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(maxWidth * 0.04),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF5F7FF),
                                      borderRadius: BorderRadius.circular(maxWidth * 0.04),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 10,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(maxWidth * 0.025),
                                          decoration: BoxDecoration(
                                            color: Color(0xFF2754C3).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(maxWidth * 0.03),
                                          ),
                                          child: Icon(
                                            LucideIcons.creditCard,
                                            size: maxWidth * 0.06,
                                            color: Color(0xFF2754C3),
                                          ),
                                        ),
                                        SizedBox(width: maxWidth * 0.03),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Amount Paid",
                                                style: GoogleFonts.poppins(
                                                  fontSize: adjustedSubtitleSize,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  "Rs. ${widget.appointmentDetails?['fee'] ?? '0'}",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: adjustedTitleSize,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: verticalPadding * 0.5),
                                  Container(
                                    padding: EdgeInsets.all(maxWidth * 0.04),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF5F7FF),
                                      borderRadius: BorderRadius.circular(maxWidth * 0.04),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 10,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(maxWidth * 0.025),
                                          decoration: BoxDecoration(
                                            color: Color(0xFF2754C3).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(maxWidth * 0.03),
                                          ),
                                          child: Icon(
                                            LucideIcons.userCheck,
                                            size: maxWidth * 0.06,
                                            color: Color(0xFF2754C3),
                                          ),
                                        ),
                                        SizedBox(width: maxWidth * 0.03),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Doctor",
                                                style: GoogleFonts.poppins(
                                                  fontSize: adjustedSubtitleSize,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  "${widget.appointmentDetails?['doctor'] ?? 'Doctor'}",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: adjustedSubtitleSize * 1.2,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: verticalPadding),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: adjustedButtonHeight,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.pop(dialogContext);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => PatientFinancesScreen(),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(0xFF2754C3),
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(vertical: maxHeight * 0.015),
                                              elevation: 2,
                                              shadowColor: Color(0xFF2754C3).withOpacity(0.3),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(maxWidth * 0.035),
                                              ),
                                            ),
                                            icon: Icon(LucideIcons.wallet, size: maxWidth * 0.045),
                                            label: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                "View Payment",
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: adjustedSubtitleSize,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: maxWidth * 0.03),
                                      Expanded(
                                        child: SizedBox(
                                          height: adjustedButtonHeight,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.pop(dialogContext);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => const AppointmentsScreen(),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: Color(0xFF2754C3),
                                              padding: EdgeInsets.symmetric(vertical: maxHeight * 0.015),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(maxWidth * 0.035),
                                                side: BorderSide(color: Color(0xFF2754C3).withOpacity(0.5), width: 1.5),
                                              ),
                                            ),
                                            icon: Icon(LucideIcons.calendarCheck, size: maxWidth * 0.045),
                                            label: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                "View Booking",
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: adjustedSubtitleSize,
                                                ),
                                              ),
                                            ),
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
                  },
                ),
              );
            },
          );
        } catch (e) {
          print('Error saving appointment and transaction: $e');
          setState(() {
            _isLoading = false;
          });
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Text("Payment failed: ${e.toString()}"),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // User not signed in
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Text("You must be signed in to book an appointment"),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  // Helper method to determine card type based on number
  String _getCardType(String cardNumber) {
    String cleanNumber = cardNumber.replaceAll(RegExp(r'\s+\b|\b\s'), '');
    if (cleanNumber.isEmpty) return "Unknown";
    
    // Visa
    if (cleanNumber.startsWith('4')) {
      return "Visa";
    }
    // Mastercard
    else if (cleanNumber.startsWith('5')) {
      return "Mastercard";
    }
    // Amex
    else if (cleanNumber.startsWith('3')) {
      return "Amex";
    }
    // Discover
    else if (cleanNumber.startsWith('6')) {
      return "Discover";
    }
    
    return "Unknown";
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the appropriate fee from appointment details
    String fee = widget.appointmentDetails != null 
        ? (widget.appointmentDetails!.containsKey('displayFee') 
          ? widget.appointmentDetails!['displayFee'] 
          : (widget.appointmentDetails!.containsKey('fee')
              ? (widget.appointmentDetails!['fee'] is int 
                  ? "Rs. ${widget.appointmentDetails!['fee']}" 
                  : widget.appointmentDetails!['fee'])
              : 'Rs. 2,000'))
        : 'Rs. 2,000';
    
    String doctor = widget.appointmentDetails != null && widget.appointmentDetails!.containsKey('doctor') 
        ? widget.appointmentDetails!['doctor'] 
        : 'Doctor';
    
    return Scaffold(
      appBar: AppBarOnboarding(isBackButtonVisible: true, text: "Card Payment"),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Credit Card Visualization
                  _buildCreditCardWidget(),
                  
                  SizedBox(height: 30),
                  
                  // Payment Information
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Payment Summary",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 15),
                        _buildSummaryRow(
                          "Appointment",
                          "Consultation with $doctor",
                          LucideIcons.calendar,
                        ),
                        Divider(height: 20),
                        _buildSummaryRow(
                          "Amount",
                          fee,
                          LucideIcons.creditCard,
                          isAmount: true,
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Card Details Section
                  Text(
                    "Card Details",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Card Name Field
                  _buildTextField(
                    controller: _cardNameController,
                    label: "Cardholder Name",
                    hint: "John Smith",
                    icon: LucideIcons.user,
                    onEditingComplete: () => _cardNumberFocus.requestFocus(),
                  ),
                  
                  // Card Number Field with formatting
                  _buildTextField(
                    controller: _cardNumberController,
                    label: "Card Number",
                    hint: "1234 5678 9012 3456",
                    icon: LucideIcons.creditCard,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                      CardNumberFormatter(),
                    ],
                    focusNode: _cardNumberFocus,
                    onEditingComplete: () => _expiryDateFocus.requestFocus(),
                  ),
                  
                  // Expiry Date and CVV Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _expiryDateController,
                          label: "Expiry Date",
                          hint: "MM/YY",
                          icon: LucideIcons.calendar,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            ExpiryDateFormatter(),
                          ],
                          focusNode: _expiryDateFocus,
                          onEditingComplete: () => _cvvFocus.requestFocus(),
                        ),
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: _buildTextField(
                          controller: _cvvController,
                          label: "CVV",
                          hint: "123",
                          icon: LucideIcons.lock,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          focusNode: _cvvFocus,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 40),
                  
                  // Security Message
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.shield,
                          color: Colors.green,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Your payment is secure. We use SSL encryption to protect your data.",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),

                  // Process Payment Button
                  _buildSubmitButton(),
                  
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_getCardTypeColor()),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Processing payment...",
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
    );
  }

  Widget _buildCreditCardWidget() {
    return Container(
      height: 200,
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getCardTypeColor(),
            _getCardTypeColor().withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getCardTypeColor().withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getCardIcon(),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Icon(
                LucideIcons.wifi,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _cardNumberController.text.isEmpty 
                    ? "•••• •••• •••• ••••" 
                    : _cardNumberController.text,
                style: GoogleFonts.sourceCodePro(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "CARD HOLDER",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        _cardNameController.text.isEmpty 
                            ? "YOUR NAME" 
                            : _cardNameController.text.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "EXPIRES",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        _expiryDateController.text.isEmpty 
                            ? "MM/YY" 
                            : _expiryDateController.text,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    VoidCallback? onEditingComplete,
    FocusNode? focusNode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              inputFormatters: inputFormatters,
              onEditingComplete: onEditingComplete,
              focusNode: focusNode,
              style: GoogleFonts.poppins(
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: Icon(
                  icon,
                  color: _getCardTypeColor(),
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _getCardTypeColor(),
                    width: 1,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAmount ? _getCardTypeColor().withOpacity(0.1) : Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isAmount ? _getCardTypeColor() : Colors.grey.shade700,
              size: 16,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: isAmount ? FontWeight.w700 : FontWeight.w500,
                    color: isAmount ? _getCardTypeColor() : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getCardTypeColor(),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 15),
        ),
        child: _isLoading
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Pay Now",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(LucideIcons.arrowRight, size: 18),
                ],
              ),
      ),
    );
  }
}

enum CardType {
  MasterCard,
  Visa,
  AmericanExpress,
  Discover,
  Invalid
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    
    // Remove all non-digits
    String value = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    // Limit to 16 digits
    if (value.length > 16) {
      value = value.substring(0, 16);
    }
    
    // Format with spaces
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < value.length; i++) {
      buffer.write(value[i]);
      if ((i + 1) % 4 == 0 && i != value.length - 1) {
        buffer.write(' ');
      }
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.toString().length),
    );
  }
}

class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    
    // Remove all non-digits
    String value = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    // Limit to 4 digits
    if (value.length > 4) {
      value = value.substring(0, 4);
    }
    
    // Format with slash
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < value.length; i++) {
      buffer.write(value[i]);
      if (i == 1 && i != value.length - 1) {
        buffer.write('/');
      }
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.toString().length),
    );
  }
} 
