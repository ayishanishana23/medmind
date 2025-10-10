import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Utils {
  // 📅 Format Date (e.g. "02 Sep 2025")
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  // ⏰ Format Time (e.g. "08:00 PM")
  static String formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  // ✅ Show Snackbar
  static void showSnack(BuildContext context, String message,
      {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

// ✅ Pick an Image (Future feature)
// You can use image_picker package later
// static Future<File?> pickImage() async {}
}
