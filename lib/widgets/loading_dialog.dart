import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoadingDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? accentColor;

  const LoadingDialog({
    Key? key,
    required this.title,
    this.subtitle = "Please wait...",
    this.accentColor,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required String title,
    String subtitle = "Please wait...",
    Color? accentColor,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return LoadingDialog(
          title: title,
          subtitle: subtitle,
          accentColor: accentColor,
        );
      },
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = accentColor ?? const Color(0xFF3366CC);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double dialogWidth = constraints.maxWidth * 0.8;
          return Center(
            child: Container(
              padding: EdgeInsets.all(dialogWidth * 0.08),
              width: dialogWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(dialogWidth * 0.08),
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
                    padding: EdgeInsets.all(dialogWidth * 0.07),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: dialogWidth * 0.08),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: dialogWidth * 0.07,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  SizedBox(height: dialogWidth * 0.02),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: dialogWidth * 0.05,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
} 