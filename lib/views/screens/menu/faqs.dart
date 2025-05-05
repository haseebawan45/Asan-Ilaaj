import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:healthcare/views/screens/dashboard/menu.dart'; // Import for UserType enum

class FAQScreen extends StatefulWidget {
  final UserType? userType; // Make parameter nullable
  
  const FAQScreen({
    super.key,
    this.userType, // Remove default value to make it truly nullable
  });

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  int _selectedCategoryIndex = 0;
  
  // Categories for FAQs
  final List<Map<String, dynamic>> _categories = [
    {
      "name": "All",
      "icon": LucideIcons.info,
      "color": 0xFF3366FF,
    },
    {
      "name": "Appointments",
      "icon": LucideIcons.calendar,
      "color": 0xFF4CAF50,
    },
    {
      "name": "Payments",
      "icon": LucideIcons.creditCard,
      "color": 0xFFFF9800,
    },
    {
      "name": "Medical",
      "icon": LucideIcons.stethoscope,
      "color": 0xFFE74C3C,
    },
    {
      "name": "Doctors",
      "icon": LucideIcons.userCheck,
      "color": 0xFF9C27B0,
    },
    {
      "name": "Account",
      "icon": LucideIcons.user,
      "color": 0xFF00BCD4,
    },
  ];
  
  // Comprehensive FAQ data
  // Structure:
  // - "category": Category the FAQ belongs to (matches one of the category names above)
  // - "question": The FAQ question text
  // - "answer": The detailed answer text
  // - "forUserType": (Optional) If specified, FAQ will only show for this user type:
  //    * "doctor" - Only visible to doctors
  //    * "patient" - Only visible to patients
  //    * If not specified, FAQ is visible to all user types
  final List<Map<String, dynamic>> _faqData = [
    // Appointment FAQs
    {
      "category": "Appointments",
      "question": "How do I schedule an appointment?",
      "answer": "You can schedule an appointment through the app by navigating to the Appointments section, selecting your preferred doctor, and choosing an available time slot. You'll receive a confirmation once your appointment is booked.",
      "forUserType": "patient"
    },
    {
      "category": "Appointments",
      "question": "How can I reschedule or cancel my appointment?",
      "answer": "To reschedule or cancel an appointment, go to the Appointments section, locate your upcoming appointment, and select the reschedule or cancel option. Please note that cancellations within 24 hours may incur a fee.",
      "forUserType": "patient"
    },
    {
      "category": "Appointments",
      "question": "How far in advance can I book an appointment?",
      "answer": "You can book appointments up to 30 days in advance, depending on doctor availability. Some specialists may have longer booking windows available.",
      "forUserType": "patient"
    },
    {
      "category": "Appointments",
      "question": "What happens if I miss my appointment?",
      "answer": "Missed appointments without prior cancellation may be subject to a no-show fee. Repeated missed appointments may affect your ability to book with certain healthcare providers.",
      "forUserType": "patient"
    },
    {
      "category": "Appointments",
      "question": "Can I book an appointment for someone else?",
      "answer": "Yes, you can book appointments for family members or dependents by selecting 'Book for someone else' during the booking process. You'll need to provide their basic information.",
      "forUserType": "patient"
    },
    {
      "category": "Appointments",
      "question": "How do I view my appointment history?",
      "answer": "You can view your appointment history by going to Menu > Appointment History. This section displays all your past, current, and upcoming appointments.",
      "forUserType": "patient"
    },
    {
      "category": "Appointments",
      "question": "What should I do if I need immediate medical attention?",
      "answer": "This app is not designed for emergency situations. If you require immediate medical attention, please call emergency services (911) or visit your nearest emergency room.",
      "forUserType": "patient"
    },
    {
      "category": "Appointments",
      "question": "Can I request a specific doctor?",
      "answer": "Yes, you can search for and select specific doctors based on their specialties, availability, and ratings. Simply use the search function in the doctor selection screen.",
      "forUserType": "patient"
    },
    {
      "category": "Appointments",
      "question": "How long before my appointment will I receive a reminder?",
      "answer": "You'll receive appointment reminders 24 hours and 1 hour before your scheduled appointment time. You can adjust notification settings in your profile.",
      "forUserType": "patient"
    },
    {
      "category": "Appointments",
      "question": "How do I know if my appointment is confirmed?",
      "answer": "Once your appointment is confirmed, you'll receive a confirmation notification and email. You can also check the status in your Appointments section, where confirmed appointments will be clearly marked.",
      "forUserType": "patient"
    },

    // Payment FAQs - patient specific
    {
      "category": "Payments",
      "question": "What payment methods are accepted?",
      "answer": "We accept various payment methods including credit/debit cards (Visa, Mastercard, American Express), mobile wallets (JazzCash, EasyPaisa), and bank transfers. You can manage your payment methods in the Payment section of your profile.",
      "forUserType": "patient"
    },
    {
      "category": "Payments",
      "question": "How do I add a new payment method?",
      "answer": "To add a new payment method, go to the Payment Methods section in your profile, tap the '+' button, and follow the prompts to add your card or wallet details. Your information is securely encrypted.",
      "forUserType": "patient"
    },
    
    // Payment FAQs - doctor specific
    {
      "category": "Payments",
      "question": "How do I set up my payment account?",
      "answer": "As a doctor, you can set up your payment account by going to Menu > Payment Account. Add your bank account details, which will be used to receive payments from patient consultations.",
      "forUserType": "doctor"
    },
    {
      "category": "Payments",
      "question": "When will I receive payments for consultations?",
      "answer": "Payments for consultations are typically processed and transferred to your registered bank account every two weeks. You can view your earnings and payment history in the Finances section of your dashboard.",
      "forUserType": "doctor"
    },
    
    // Common payment FAQs - for both user types
    {
      "category": "Payments",
      "question": "Is payment information secure?",
      "answer": "Yes, we use industry-standard encryption and security measures to protect all payment information. We comply with PCI DSS standards and do not store complete card details on our servers."
    },
    {
      "category": "Payments",
      "question": "How do I delete a saved payment method?",
      "answer": "To delete a saved payment method, go to Menu > Payment Methods, select the payment method you want to remove, and tap the 'Remove' button."
    },
    {
      "category": "Payments",
      "question": "Are there any hidden fees?",
      "answer": "No, all applicable fees are clearly displayed before you confirm your appointment. You'll see the doctor's consultation fee and any applicable service charges before payment."
    },

    // Medical FAQs - Patient specific
    {
      "category": "Medical",
      "question": "How can I access my medical records?",
      "answer": "Your medical records are available in the Records section of your profile. You can view your history of consultations, prescriptions, and test results. All information is confidential and only accessible to you and your healthcare providers.",
      "forUserType": "patient"
    },
    {
      "category": "Medical",
      "question": "How do I request a prescription refill?",
      "answer": "You can request a prescription refill by navigating to the Prescriptions section, selecting the medication you need refilled, and submitting a request. Your doctor will review and approve if appropriate.",
      "forUserType": "patient"
    },
    {
      "category": "Medical",
      "question": "How are my medical records secured?",
      "answer": "Your medical records are protected by multiple layers of security, including encryption and strict access controls. Only authorized healthcare providers and you can access your complete records.",
      "forUserType": "patient"
    },
    {
      "category": "Medical",
      "question": "Can I share my medical records with other healthcare providers?",
      "answer": "Yes, you can share your medical records with other healthcare providers through the app. Go to Medical Records, select the records you want to share, and use the 'Share' option to send them securely.",
      "forUserType": "patient"
    },
    {
      "category": "Medical",
      "question": "How long are my medical records kept?",
      "answer": "Your medical records are stored securely for as long as you maintain an account with us, in accordance with medical record retention laws and regulations."
    },
    {
      "category": "Medical",
      "question": "Can I upload my existing medical records to the app?",
      "answer": "Yes, you can upload existing medical records, lab results, and other health documents through the Medical Records section. Simply use the upload feature and categorize your documents appropriately.",
      "forUserType": "patient"
    },
    {
      "category": "Medical",
      "question": "How do I view my prescription history?",
      "answer": "Your prescription history is available in the Prescriptions section of your profile. You can view current and past prescriptions, including dosage information and refill history.",
      "forUserType": "patient"
    },
    {
      "category": "Medical",
      "question": "Can I get lab tests through the app?",
      "answer": "Yes, doctors can request lab tests through the app. You'll receive instructions on where to get the tests done, and results will be available in your Medical Records section once completed.",
      "forUserType": "patient"
    },
    {
      "category": "Medical",
      "question": "How do I prepare for a video consultation?",
      "answer": "For video consultations, ensure you have a stable internet connection, find a quiet and private space, test your camera and microphone beforehand, and have a list of your symptoms and questions ready. Log in at least 5 minutes before your appointment time.",
      "forUserType": "patient"
    },
    {
      "category": "Medical",
      "question": "What should I do if I experience technical issues during a video consultation?",
      "answer": "If you experience technical issues during a video consultation, try refreshing the page or restarting the app. If problems persist, you can message the doctor through the chat feature or call our technical support team.",
      "forUserType": "patient"
    },
    
    // Medical FAQs - Doctor specific
    {
      "category": "Medical",
      "question": "How do I issue a prescription?",
      "answer": "To issue a prescription, go to the patient's consultation record, select 'New Prescription', add the medication details including dosage and instructions, then save and send to the patient. They will receive a notification when the prescription is ready.",
      "forUserType": "doctor"
    },
    {
      "category": "Medical",
      "question": "How do I view a patient's medical history?",
      "answer": "You can view a patient's medical history by accessing their profile from your appointment details or patient list. Their medical records, past consultations, and prescription history will be available for your review.",
      "forUserType": "doctor"
    },
    {
      "category": "Medical",
      "question": "How do I request lab tests for a patient?",
      "answer": "To request lab tests, go to the patient's consultation record, select 'Request Tests', choose the tests needed from the available list, add any special instructions, and submit. The patient will receive instructions on how to complete the requested tests.",
      "forUserType": "doctor"
    },

    // Doctor-specific FAQs (These will only show for doctor users)
    {
      "category": "Doctors",
      "question": "How do I set up my doctor profile?",
      "answer": "To set up your doctor profile, go to Menu > Profile Update and complete all required fields including your specialties, qualifications, experience, and hospital affiliations. Upload necessary documents for verification.",
      "forUserType": "doctor"
    },
    {
      "category": "Doctors",
      "question": "How do I manage my appointment schedule?",
      "answer": "Doctors can manage their appointment schedule by going to Menu > Availability. Here you can set your working days, hours, appointment duration, and block out times when you're unavailable.",
      "forUserType": "doctor"
    },
    {
      "category": "Doctors",
      "question": "How are payments processed for doctors?",
      "answer": "Payments from patient consultations are processed and transferred to your registered bank account according to our payment cycle (typically every 2 weeks). You can view your earnings and payment history in the Finances section.",
      "forUserType": "doctor"
    },
    
    // Questions about doctors (for patients)
    {
      "category": "Doctors",
      "question": "How are doctors verified on the platform?",
      "answer": "All doctors on our platform undergo a comprehensive verification process, including license verification, credential checks, and professional reference verification to ensure they are qualified healthcare providers.",
      "forUserType": "patient"
    },
    {
      "category": "Doctors",
      "question": "How can I find doctors by specialty?",
      "answer": "You can find doctors by specialty using the search filter on the doctor selection screen. Select the specialty you're looking for, and you'll see a list of qualified doctors in that field.",
      "forUserType": "patient"
    },
    
    // Common doctor-related questions (for both user types)
    {
      "category": "Doctors",
      "question": "What information is available on a doctor's profile?",
      "answer": "A doctor's profile includes their qualifications, specialties, experience, hospital affiliations, languages spoken, consultation fees, available time slots, and patient reviews."
    },

    // Account FAQs - Common for both users
    {
      "category": "Account",
      "question": "How do I create an account?",
      "answer": "To create an account, download the app and select 'Sign Up'. You can register using your email, phone number, or social media accounts. Follow the prompts to complete your profile with necessary health information."
    },
    {
      "category": "Account",
      "question": "How do I reset my password?",
      "answer": "To reset your password, go to the login screen and select 'Forgot Password'. Enter your registered email, and we'll send you a password reset link. Follow the instructions in the email to create a new password."
    },
    {
      "category": "Account",
      "question": "Is my personal information secure?",
      "answer": "Yes, we take data security very seriously. Your personal information is encrypted and stored securely. We comply with all relevant data protection regulations and never share your information without your consent."
    },
    {
      "category": "Account",
      "question": "How do I delete my account?",
      "answer": "To delete your account, go to Menu > Settings > Account > Delete Account. Please note that this action is permanent and will remove all your data from our systems after the required retention period."
    },
    
    // Account FAQs - Patient specific
    {
      "category": "Account",
      "question": "How do I update my profile information?",
      "answer": "You can update your profile information by going to Menu > Profile Update. Here you can edit your personal details, contact information, address, and other relevant information.",
      "forUserType": "patient"
    },
    {
      "category": "Account",
      "question": "Can I have multiple profiles for family members?",
      "answer": "Yes, you can add family members to your account. Go to Menu > Profile > Family Members and select 'Add Family Member'. Each family member will have their own medical records and appointment history.",
      "forUserType": "patient"
    },
    {
      "category": "Account",
      "question": "How do I change my notification settings?",
      "answer": "To change your notification settings, go to Menu > Settings > Notifications. Here you can customize which notifications you receive, including appointment reminders, doctor messages, and system updates.",
      "forUserType": "patient"
    },
    
    // Account FAQs - Doctor specific
    {
      "category": "Account",
      "question": "How do I update my professional information?",
      "answer": "You can update your professional information by going to Menu > Profile Update. Here you can edit your qualifications, specialties, experience, hospital affiliations, and other professional details.",
      "forUserType": "doctor"
    },
    {
      "category": "Account",
      "question": "How are my credentials verified?",
      "answer": "When you sign up as a doctor, you'll need to provide your professional license, certificates, and other credentials. Our verification team will review these documents and may contact you for additional information if needed.",
      "forUserType": "doctor"
    },
    {
      "category": "Account",
      "question": "How do I update my availability schedule?",
      "answer": "To update your availability, go to Menu > Availability and set your working days and hours. You can also block specific dates when you're unavailable. These settings will determine when patients can book appointments with you.",
      "forUserType": "doctor"
    },

    // Doctor-specific FAQs (for doctor users)
    {
      "category": "Doctors",
      "question": "How do I view my patient appointments?",
      "answer": "You can view your patient appointments by going to the Appointments tab on your dashboard. This shows all upcoming and past appointments, with patient details and medical history for each scheduled consultation.",
      "forUserType": "doctor"
    },
    {
      "category": "Doctors",
      "question": "Can I issue prescriptions through the app?",
      "answer": "Yes, you can issue digital prescriptions through the app. During or after a consultation, go to the Prescriptions section, select the patient, and create a prescription with medication details. Patients can access these in their Prescriptions section.",
      "forUserType": "doctor"
    },
    {
      "category": "Doctors",
      "question": "How do I access patient medical records?",
      "answer": "You can access the medical records of your patients before or during consultations. These include their medical history, previous consultations, prescriptions, and any uploaded documents, helping you provide informed care.",
      "forUserType": "doctor"
    },
    {
      "category": "Doctors",
      "question": "How do I request time off or vacation?",
      "answer": "To set vacation time or days off, go to Menu > Availability > Block Time. Select the dates you'll be unavailable, and patients won't be able to book appointments during these periods.",
      "forUserType": "doctor"
    },
    {
      "category": "Appointments",
      "question": "How do I manage my appointment calendar?",
      "answer": "As a doctor, you can manage your appointment calendar by going to Menu > Availability. Here you can set your working days, hours, appointment duration, and block out times when you're unavailable.",
      "forUserType": "doctor"
    },
    {
      "category": "Appointments",
      "question": "How do I view my upcoming appointments?",
      "answer": "You can view all your upcoming appointments on your doctor dashboard. The appointments are color-coded based on their status (confirmed, pending, completed) and you can click on any appointment to see patient details.",
      "forUserType": "doctor"
    }
  ];
  
  // Track expanded state for each FAQ
  late List<bool> _expanded;
  // Animation controllers for each FAQ
  late List<AnimationController> _controllers;
  
  @override
  void initState() {
    super.initState();
    _expanded = List.generate(_faqData.length, (index) => false);
    _controllers = List.generate(
      _faqData.length, 
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      )
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Get filtered FAQs based on search query, selected category, and user type
  List<Map<String, dynamic>> get filteredFAQs {
    return _faqData.where((faq) {
      // Filter by category
      final categoryMatch = _selectedCategoryIndex == 0 || faq["category"] == _categories[_selectedCategoryIndex]["name"];
      
      // Filter by search query
      final queryMatch = _searchQuery.isEmpty || 
          faq["question"].toLowerCase().contains(_searchQuery.toLowerCase()) || 
          faq["answer"].toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Filter by user type
      bool userTypeMatch = true;
      
      // If a user type is provided (patient or doctor), filter accordingly
      if (widget.userType != null) {
        if (faq.containsKey("forUserType")) {
          // Show only FAQs that match the current user type
          if (faq["forUserType"] == "doctor") {
            userTypeMatch = widget.userType == UserType.doctor;
          } else if (faq["forUserType"] == "patient") {
            userTypeMatch = widget.userType == UserType.patient;
          }
        } else {
          // FAQs without a forUserType are shown to everyone (general FAQs)
          userTypeMatch = true;
        }
      } else {
        // When no user type is specified, show all FAQs
        userTypeMatch = true;
      }
      
      return categoryMatch && queryMatch && userTypeMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
          "Frequently Asked Questions",
          style: GoogleFonts.poppins(
            color: Color(0xFF333333),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
            ),
            if (widget.userType == null)
              Text(
                "(Showing all FAQs)",
                style: GoogleFonts.poppins(
                  color: Color(0xFF777777),
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            if (widget.userType == UserType.doctor)
              Text(
                "(Doctor view)",
                style: GoogleFonts.poppins(
                  color: Color(0xFFFF3F80), // Pink for doctor
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            if (widget.userType == UserType.patient)
              Text(
                "(Patient view)",
                style: GoogleFonts.poppins(
                  color: Color(0xFF30A9C7), // Teal for patient
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            color: Colors.white,
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFFF5F7FF),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Color(0xFF333333),
                ),
                decoration: InputDecoration(
                  hintText: "Search FAQs",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade400,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    LucideIcons.search,
                    color: Color(0xFF3366FF),
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                    icon: Icon(LucideIcons.x, size: 18),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = "";
                      });
                    },
                  ) : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
          
          // Categories
          Container(
            height: 90,
            padding: EdgeInsets.symmetric(vertical: 16),
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedCategoryIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                  },
                  child: Container(
                    width: 100,
                    margin: EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Color(_categories[index]["color"]).withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Color(_categories[index]["color"]).withOpacity(0.5)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _categories[index]["icon"],
                          color: Color(_categories[index]["color"]),
                          size: 24,
                        ),
                        SizedBox(height: 8),
                        Text(
                          _categories[index]["name"],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Color(_categories[index]["color"])
                                : Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // FAQ list header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  "FAQs",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF3366FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${filteredFAQs.length}",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3366FF),
                    ),
                  ),
                ),
                Spacer(),
                // Debug button
                GestureDetector(
                  onTap: () {
                    // Count FAQ types
                    int doctorFAQs = 0;
                    int patientFAQs = 0;
                    int generalFAQs = 0;
                    
                    // Count by category
                    Map<String, int> doctorFAQsByCategory = {};
                    Map<String, int> patientFAQsByCategory = {};
                    Map<String, int> generalFAQsByCategory = {};
                    
                    for (var category in _categories) {
                      if (category["name"] != "All") {
                        doctorFAQsByCategory[category["name"]] = 0;
                        patientFAQsByCategory[category["name"]] = 0;
                        generalFAQsByCategory[category["name"]] = 0;
                      }
                    }
                    
                    for (var faq in _faqData) {
                      String category = faq["category"];
                      if (faq.containsKey("forUserType")) {
                        if (faq["forUserType"] == "doctor") {
                          doctorFAQs++;
                          doctorFAQsByCategory[category] = (doctorFAQsByCategory[category] ?? 0) + 1;
                        } else if (faq["forUserType"] == "patient") {
                          patientFAQs++;
                          patientFAQsByCategory[category] = (patientFAQsByCategory[category] ?? 0) + 1;
                        }
                      } else {
                        generalFAQs++;
                        generalFAQsByCategory[category] = (generalFAQsByCategory[category] ?? 0) + 1;
                      }
                    }
                    
                    // Show dialog with counts
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text("FAQ Type Counts", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Current user type: ${widget.userType == null ? 'None (showing all)' : (widget.userType == UserType.doctor ? 'Doctor' : 'Patient')}",
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                              ),
                              Divider(),
                              Text("Summary:", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                              Text("Doctor-specific FAQs: $doctorFAQs", 
                                style: GoogleFonts.poppins(color: Color(0xFFFF3F80)),
                              ),
                              Text("Patient-specific FAQs: $patientFAQs", 
                                style: GoogleFonts.poppins(color: Color(0xFF30A9C7)),
                              ),
                              Text("General FAQs: $generalFAQs", 
                                style: GoogleFonts.poppins(color: Color(0xFF3366FF)),
                              ),
                              Text("Total FAQs: ${_faqData.length}", 
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                              ),
                              
                              Divider(),
                              Text("By category:", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                              SizedBox(height: 8),
                              
                              // Show counts by category
                              for (var category in _categories)
                                if (category["name"] != "All") ...[
                                  Text(
                                    category["name"], 
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500, 
                                      color: Color(category["color"]),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        child: Text(
                                          "Doctor:", 
                                          style: GoogleFonts.poppins(fontSize: 12),
                                        ),
                                      ),
                                      Text(
                                        "${doctorFAQsByCategory[category["name"]] ?? 0}", 
                                        style: GoogleFonts.poppins(color: Color(0xFFFF3F80)),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        child: Text(
                                          "Patient:", 
                                          style: GoogleFonts.poppins(fontSize: 12),
                                        ),
                                      ),
                                      Text(
                                        "${patientFAQsByCategory[category["name"]] ?? 0}", 
                                        style: GoogleFonts.poppins(color: Color(0xFF30A9C7)),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        child: Text(
                                          "General:", 
                                          style: GoogleFonts.poppins(fontSize: 12),
                                        ),
                                      ),
                                      Text(
                                        "${generalFAQsByCategory[category["name"]] ?? 0}", 
                                        style: GoogleFonts.poppins(color: Color(0xFF3366FF)),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                ],
                              
                              Divider(),
                              Text("Filtering logic:", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                              SizedBox(height: 4),
                              Text(
                                "• Doctor view: Shows doctor-specific + general FAQs = ${doctorFAQs + generalFAQs} FAQs", 
                                style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFFFF3F80)),
                              ),
                              Text(
                                "• Patient view: Shows patient-specific + general FAQs = ${patientFAQs + generalFAQs} FAQs", 
                                style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF30A9C7)),
                              ),
                              Text(
                                "• All view: Shows all FAQs = ${_faqData.length} FAQs", 
                                style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF3366FF)),
                              ),
                              SizedBox(height: 8),
                              Divider(),
                              Text("Current view summary:", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                              if (widget.userType == null)
                                Text("Currently showing all FAQs (${_faqData.length})", 
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                              if (widget.userType == UserType.doctor)
                                Text("Currently showing ${doctorFAQs} doctor FAQs + ${generalFAQs} general FAQs = ${doctorFAQs + generalFAQs} total", 
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFFF3F80))),
                              if (widget.userType == UserType.patient)
                                Text("Currently showing ${patientFAQs} patient FAQs + ${generalFAQs} general FAQs = ${patientFAQs + generalFAQs} total", 
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF30A9C7))),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("Close", style: GoogleFonts.poppins()),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.info,
                      size: 20,
                      color: Color(0xFF3366FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // FAQ list
          Expanded(
            child: filteredFAQs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.search,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No FAQs found",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF666666),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Try changing your search or category",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredFAQs.length,
          itemBuilder: (context, index) {
                      final originalIndex = _faqData.indexOf(filteredFAQs[index]);
                      return _buildFAQItem(filteredFAQs[index], originalIndex);
          },
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(Map<String, dynamic> faq, int index) {
    // Set up animations
    final Animation<double> heightAnimation = CurvedAnimation(
      parent: _controllers[index],
      curve: Curves.easeInOut,
    );
    
    final Animation<double> iconRotationAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(heightAnimation);
    
    // Determine user type badge text and color
    String? userTypeBadge;
    Color userTypeBadgeColor = Colors.grey;
    
    if (faq.containsKey("forUserType")) {
      if (faq["forUserType"] == "doctor") {
        userTypeBadge = "Doctor";
        userTypeBadgeColor = Color(0xFFFF3F80); // Pink for doctor
      } else if (faq["forUserType"] == "patient") {
        userTypeBadge = "Patient";
        userTypeBadgeColor = Color(0xFF30A9C7); // Teal for patient
      }
    } else {
      userTypeBadge = "All";
      userTypeBadgeColor = Color(0xFF3366FF); // Blue for general
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
          onTap: () {
            setState(() {
              _expanded[index] = !_expanded[index];
                if (_expanded[index]) {
                  _controllers[index].forward();
                } else {
                  _controllers[index].reverse();
                }
            });
          },
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category indicator
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(faq["category"]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: 12),
                      // Question
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User type badge
                            if (userTypeBadge != null)
                              Container(
                                margin: EdgeInsets.only(bottom: 6),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: userTypeBadgeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: userTypeBadgeColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                          child: Text(
                                  userTypeBadge,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: userTypeBadgeColor,
                                  ),
                                ),
                              ),
                            // Question text
                            Text(
                          faq["question"],
                            style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                            ),
                          ],
                        ),
                      ),
                      // Rotation animation for the expand icon
                      RotationTransition(
                        turns: iconRotationAnimation,
                        child: Icon(
                          LucideIcons.chevronDown,
                          color: Color(0xFF3366FF),
                          size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
                // Animated expand
                SizeTransition(
                  sizeFactor: heightAnimation,
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 32,
                      right: 16,
                      bottom: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Divider
                        Container(
                          height: 1,
                          color: Colors.grey.shade200,
                          margin: EdgeInsets.only(bottom: 16),
                        ),
                        // Answer
                        Text(
                          faq["answer"],
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Color(0xFF666666),
                            height: 1.5,
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

  Color _getCategoryColor(String category) {
    final categoryData = _categories.firstWhere(
      (cat) => cat["name"] == category,
      orElse: () => _categories[0],
    );
    return Color(categoryData["color"]);
  }
}
