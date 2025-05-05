import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthcare/utils/app_theme.dart';

/// A utility class for managing system UI appearance consistently across the app
class UIHelper {
  /// Pink status bar style used in primary screens
  static const SystemUiOverlayStyle pinkStatusBarStyle = SystemUiOverlayStyle(
    statusBarColor: AppTheme.primaryPink,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark, // For iOS
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );
  
  /// Transparent/white status bar style used in secondary screens
  static const SystemUiOverlayStyle transparentStatusBarStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light, // For iOS
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );
  
  /// Apply the pink status bar style with option to force update
  static void applyPinkStatusBar({bool withPostFrameCallback = false}) {
    // Apply immediately
    SystemChrome.setSystemUIOverlayStyle(pinkStatusBarStyle);
    
    // Optionally apply after frame is built for more reliable application
    if (withPostFrameCallback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemChrome.setSystemUIOverlayStyle(pinkStatusBarStyle);
      });
    }
  }
  
  /// Apply the transparent/white status bar style with option to force update
  static void applyTransparentStatusBar({bool withPostFrameCallback = false}) {
    // Apply immediately
    SystemChrome.setSystemUIOverlayStyle(transparentStatusBarStyle);
    
    // Optionally apply after frame is built for more reliable application
    if (withPostFrameCallback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemChrome.setSystemUIOverlayStyle(transparentStatusBarStyle);
      });
    }
  }
  
  /// Create a widget that ensures consistent status bar style for a screen
  /// This combines AnnotatedRegion with post-frame callbacks for maximum reliability
  static Widget ensureStatusBarStyle({
    required Widget child,
    required SystemUiOverlayStyle style,
  }) {
    return Builder(
      builder: (context) {
        // Apply style via post-frame callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SystemChrome.setSystemUIOverlayStyle(style);
        });
        
        // Return annotated region with consistent style
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: style,
          child: child,
        );
      }
    );
  }
} 