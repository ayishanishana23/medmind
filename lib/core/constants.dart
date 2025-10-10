import 'package:flutter/material.dart';

/// 🎨 Global App Colors
class AppColors {
  static const Color primary = Color(0xFF4A9ACF); // Main purple
  static const Color background = Color(0xFFF2F8FF); // Light background
  static const Color secondary = Color(0xFFA8E9F4); // Soft blue
  static const Color textDark = Color(0xFF000000);
  static const Color textLight = Color(0xFF888888);
  static const Color error = Color(0xFFE53935); // Red for errors
  static const Color success = Color(0xFF4CAF50); // Green for success
  static const Color shadow = Color(0x1A000000); // Light shadow
}

/// 📝 Global Text Styles
class AppTextStyles {
  static const TextStyle heading = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static const TextStyle subheading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textLight,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.textDark,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}

/// 📐 Global Padding & Radius
class AppSpacing {
  static const double screenPadding = 24.0;
  static const double cardPadding = 16.0;
  static const double cornerRadius = 16.0;

  static const BorderRadius borderRadius = BorderRadius.all(
    Radius.circular(cornerRadius),
  );
}
