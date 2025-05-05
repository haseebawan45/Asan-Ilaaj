import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Terms of Service",
          style: GoogleFonts.poppins(
            color: Color(0xFF333333),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Acceptance of Terms',
              'By accessing and using the Specialist Doctors application, you agree to be bound by these Terms of Service and all applicable laws and regulations.',
            ),
            _buildSection(
              'Service Description',
              '''Specialist Doctors provides:
• Online doctor appointment booking
• Medical consultation services
• Health information access
• Digital health records management
• Payment processing for medical services''',
            ),
            _buildSection(
              'User Responsibilities',
              '''You agree to:
• Provide accurate personal information
• Maintain the confidentiality of your account
• Not misuse or abuse the service
• Keep scheduled appointments or cancel in advance
• Make timely payments for services
• Respect healthcare providers and staff''',
            ),
            _buildSection(
              'Medical Disclaimer',
              'The information provided through our service is for general informational purposes only. It is not a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider.',
            ),
            _buildSection(
              'Appointment Policies',
              '''Our appointment policies include:
• 24-hour cancellation notice required
• Late arrival may result in rescheduling
• No-shows may incur a fee
• Emergency situations will be prioritized
• Rescheduling subject to availability''',
            ),
            _buildSection(
              'Payment Terms',
              '''Payment terms include:
• Fees are due at time of service
• Accepted payment methods
• Cancellation and refund policies
• Insurance billing procedures
• Additional charges for special services''',
            ),
            _buildSection(
              'Limitation of Liability',
              'We strive to provide reliable services but cannot guarantee uninterrupted access. We are not liable for any damages arising from service use or interruption.',
            ),
            _buildSection(
              'Changes to Terms',
              'We reserve the right to modify these terms at any time. Continued use of the service after changes constitutes acceptance of new terms.',
            ),
            SizedBox(height: 16),
            Text(
              'Last Updated: March 2024',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
} 