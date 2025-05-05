import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/views/components/onboarding.dart';
import 'package:healthcare/views/screens/patient/appointment/successfull_appoinment.dart';
import 'package:healthcare/views/screens/patient/dashboard/finance.dart';
import 'package:healthcare/views/screens/menu/appointment_history.dart';
import 'package:healthcare/views/screens/patient/appointment/completed_appointments_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthcare/utils/patient_navigation_helper.dart';
import 'package:healthcare/views/screens/appointment/all_appoinments.dart';

class EasypaisaPaymentScreen extends StatefulWidget {
  final Map<String, dynamic>? appointmentDetails;
  
  const EasypaisaPaymentScreen({
    super.key,
    this.appointmentDetails,
  });

  @override
  _EasypaisaPaymentScreenState createState() => _EasypaisaPaymentScreenState();
}

class _EasypaisaPaymentScreenState extends State<EasypaisaPaymentScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  void _confirmPayment() {
    String phoneNumber = _phoneController.text;
    if (phoneNumber.isNotEmpty && phoneNumber.length >= 10) {
      setState(() {
        _isLoading = true;
      });

      // Simulate API call
      Future.delayed(Duration(seconds: 2), () async {
        // Get the current user ID
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userId = user.uid;
          
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
              'paymentMethod': 'EasyPaisa',
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
              'description': 'Consultation with ${widget.appointmentDetails?['doctorName'] ?? widget.appointmentDetails?['doctor']}',
              'amount': amountValue,
              'date': Timestamp.now(),
              'type': 'payment',
              'status': 'completed',
              'paymentMethod': 'EasyPaisa',
              'doctorName': widget.appointmentDetails?['doctor'] ?? "Doctor",
              'hospitalName': widget.appointmentDetails?['hospital'] ?? "Hospital",
              'createdAt': Timestamp.now(),
              'updatedAt': Timestamp.now(),
            });
            
            print('Appointment and transaction saved successfully');
            
            // Show success dialog
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
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
                                                Navigator.pop(context);
                                                PatientNavigationHelper.navigateToHome(context);
                                                Future.delayed(Duration(milliseconds: 100), () {
                                                  PatientNavigationHelper.navigateToTab(context, 2); // Navigate to Finances tab
                                                });
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
                                                Navigator.pop(context); // Close the dialog
                                                // Navigate directly to appointments screen
                                                Navigator.pushAndRemoveUntil(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const AppointmentsScreen(),
                                                  ),
                                                  (route) => route.isFirst, // Keep only the first route
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
            
            // Show error message
            if (mounted) {
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
              
        setState(() {
          _isLoading = false;
        });
            }
          }
        } else {
          // User not signed in
          if (mounted) {
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
            
            setState(() {
              _isLoading = false;
            });
          }
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text("Please enter a valid phone number"),
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
      appBar: AppBarOnboarding(isBackButtonVisible: true, text: "Easypaisa Payment"),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderImage(),
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
                  
                  Text(
                    "Easypaisa Details",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Phone number field with validation pattern
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Phone Number",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: InputDecoration(
                          hintText: "03XX-XXXXXXX",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                          ),
                          prefixIcon: Icon(
                            LucideIcons.smartphone,
                            color: Color(0xFF00822B),
                            size: 20,
                          ),
                          prefixText: _phoneController.text.isNotEmpty && !_phoneController.text.startsWith('03') ? '03' : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Color(0xFF00822B),
                              width: 1.5,
                            ),
                          ),
                          errorText: _phoneController.text.isNotEmpty && !RegExp(r'^03\d{2}[0-9]{7}$').hasMatch(_phoneController.text) 
                              ? 'Enter a valid 11-digit Easypaisa number' 
                              : null,
                          errorStyle: GoogleFonts.poppins(
                            color: Colors.red.shade600,
                            fontSize: 12,
                          ),
                          helperText: "Enter your 11-digit Easypaisa number",
                          helperStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
                            "Your payment is secure. We do not store any payment details.",
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
                  
                  // Submit Button
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
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
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

  Widget _buildHeaderImage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Color(0xFFF4FFF5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/easypaisa_logo.png',
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 60,
                width: 120,
                decoration: BoxDecoration(
                  color: Color(0xFF00822B),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Easypaisa",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 16),
          Text(
            "Fast and secure mobile payments",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, IconData icon, {bool isAmount = false}) {
    return Row(
      children: [
        Icon(
          icon,
          color: isAmount ? Color(0xFF00822B) : Colors.grey[600],
          size: 20,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isAmount ? Color(0xFF00822B) : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _confirmPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF4CAF50),
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
                    "Confirm Payment",
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
