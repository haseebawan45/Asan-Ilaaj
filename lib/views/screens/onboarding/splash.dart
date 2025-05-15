import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/views/screens/onboarding/onboarding_1.dart';
import 'package:healthcare/utils/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    
    _animationController.forward();
    
    // Navigate to onboarding after delay
    Timer(
      Duration(seconds: 3),
      () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Onboarding1()),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryTeal,
              AppTheme.primaryPink.withOpacity(0.9),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background design elements
            Positioned(
              top: 0,
              right: 0,
              child: _buildDecorativeCircle(
                size: 200,
                color: Colors.white.withOpacity(0.1),
                alignment: Alignment.topRight,
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: _buildDecorativeCircle(
                size: 250,
                color: Colors.white.withOpacity(0.1),
                alignment: Alignment.bottomLeft,
              ),
            ),
            
            // Medical icons with opacity
            Positioned(
              top: MediaQuery.of(context).size.height * 0.15,
              right: 30,
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  "assets/images/capsules.png",
                  width: 80,
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              left: 20,
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  "assets/images/tablets.png",
                  width: 70,
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.1,
              right: 30,
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  "assets/images/bandage.png",
                  width: 90,
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.15,
              left: 20,
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  "assets/images/sethoscope.png",
                  width: 90,
                ),
              ),
            ),
            
            // Main content with animations
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeInAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with glow effect
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        "assets/images/logo.png",
                        width: MediaQuery.of(context).size.width * 0.35,
                      ),
                    ),
                    SizedBox(height: 24),
                    
                    // App name
                    Text(
                      "Specialist Doctors",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black12,
                            offset: Offset(1, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    
                    // Tagline
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Your Health, Our Priority",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                    
                    // Loading indicator
                    Padding(
                      padding: const EdgeInsets.only(top: 40.0),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
  
  // Helper method to create decorative circles
  Widget _buildDecorativeCircle({required double size, required Color color, required Alignment alignment}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
