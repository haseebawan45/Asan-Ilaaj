# Specialist Doctors App Theme Documentation

## Overview
This document provides guidance on using the app's color scheme and theme system. The app uses a consistent color palette based on two primary colors: Pink and Teal. The theme is defined centrally in `lib/utils/app_theme.dart`.

## Color Palette

### Primary Colors
- **Primary Pink (`AppTheme.primaryPink`)**: `#FF3F80` - Used for doctor-related UI elements
- **Primary Teal (`AppTheme.primaryTeal`)**: `#30A9C7` - Used for patient-related UI elements

### Background Colors
- **Light Pink (`AppTheme.lightPink`)**: `#FFE6F0` - Light background for pink elements
- **Light Teal (`AppTheme.lightTeal`)**: `#E6F7FB` - Light background for teal elements
- **Very Light Pink (`AppTheme.veryLightPink`)**: `#FFF5F9` - Very subtle pink for large backgrounds
- **Very Light Teal (`AppTheme.veryLightTeal`)**: `#F0FBFF` - Very subtle teal for large backgrounds

### Text Colors
- **Dark Text (`AppTheme.darkText`)**: `#333333` - Main text color
- **Medium Text (`AppTheme.mediumText`)**: `#6F7478` - Secondary text color
- **Light Text (`AppTheme.lightText`)**: `#9E9E9E` - Hint text, disabled text

### Status Colors
- **Success (`AppTheme.success`)**: `#4CAF50` - Success states, confirmation
- **Warning (`AppTheme.warning`)**: `#FFA726` - Warning states, caution
- **Error (`AppTheme.error`)**: `#E53935` - Error states, danger
- **Info (`AppTheme.info`)**: `#2196F3` - Information states

## Usage Guidelines

### User Type Specific Colors
The app uses different color accents for doctors and patients:

```dart
// Get primary color based on user type
Color primaryColor = AppTheme.getPrimaryColor(isDoctor);

// Get secondary color based on user type
Color secondaryColor = AppTheme.getSecondaryColor(isDoctor);

// Get light background color based on user type
Color lightBackgroundColor = AppTheme.getLightColor(isDoctor);
```

### Gradients
For hero elements or sections requiring visual emphasis:

```dart
// Standard gradient (pink to teal)
decoration: BoxDecoration(
  gradient: AppTheme.getPrimaryGradient(),
  borderRadius: BorderRadius.circular(20),
),

// Reversed gradient (teal to pink)
decoration: BoxDecoration(
  gradient: AppTheme.getPrimaryGradient(reversed: true),
  borderRadius: BorderRadius.circular(20),
),
```

### Text Styling
Use the app's text colors for consistent hierarchical structure:

```dart
Text(
  'Main Header',
  style: GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppTheme.darkText,
  ),
)

Text(
  'Subheader text',
  style: GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppTheme.mediumText,
  ),
)

Text(
  'Hint text',
  style: GoogleFonts.poppins(
    fontSize: 14,
    color: AppTheme.lightText,
  ),
)
```

### Buttons & Interactive Elements
Use theme colors for interactive elements:

```dart
// Primary button
ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    backgroundColor: AppTheme.primaryTeal,
    foregroundColor: Colors.white,
  ),
  child: Text('Submit'),
)

// Secondary/outline button
OutlinedButton(
  onPressed: () {},
  style: OutlinedButton.styleFrom(
    foregroundColor: AppTheme.primaryTeal,
    side: BorderSide(color: AppTheme.primaryTeal),
  ),
  child: Text('Cancel'),
)

// Text button
TextButton(
  onPressed: () {},
  style: TextButton.styleFrom(
    foregroundColor: AppTheme.primaryTeal,
  ),
  child: Text('Learn more'),
)
```

### Form Elements
For input fields and form controls:

```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Email',
    hintText: 'Enter your email',
    prefixIcon: Icon(
      Icons.email,
      color: AppTheme.primaryTeal,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppTheme.primaryTeal, width: 2),
    ),
  ),
)
```

## Best Practices

1. **Consistency**: Always use the centralized AppTheme rather than hardcoded colors
2. **User Type**: Consider the user type (isDoctor) when selecting colors
3. **Accessibility**: Ensure text has sufficient contrast with backgrounds
4. **Subtlety**: Use vibrant colors sparingly for important elements only
5. **Gradients**: Reserve gradients for hero sections or special emphasis areas
6. **Hierarchy**: Use text color system to establish clear information hierarchy

## Updating the Theme

When updating the theme, only make changes to the `app_theme.dart` file to ensure consistency across the app. After changes, test on multiple screens to ensure the updates look good in all contexts. 