import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';


class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool isLoading = false;

  Future<void> resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword != confirmPassword) {
      _showSnackBar("❌ Passwords do not match", Colors.red);
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await user.updatePassword(newPassword);
        _showSnackBar("✅ Password updated successfully!", Colors.green);
        Navigator.pop(context);
      } else {
        _showSnackBar("❌ User not logged in", Colors.red);
      }
    } catch (e) {
      _showSnackBar("❌ Error: ${e.toString()}", Colors.red);
    }

    setState(() => isLoading = false);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Reset Password"),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Text(
                  "Change Your Password",
                  style: AppTextStyles.heading,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter your current password and a new one.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),

                // Current Password
                _buildPasswordField(
                  currentPasswordController,
                  "Current Password",
                  _obscureCurrent,
                      () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
                const SizedBox(height: 16),

                // New Password
                _buildPasswordField(
                  newPasswordController,
                  "New Password",
                  _obscureNew,
                      () => setState(() => _obscureNew = !_obscureNew),
                ),
                const SizedBox(height: 16),

                // Confirm Password
                _buildPasswordField(
                  confirmPasswordController,
                  "Confirm Password",
                  _obscureConfirm,
                      () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                const SizedBox(height: 24),

                // Reset Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "Update Password",
                      style: TextStyle(fontSize: 18, color: Colors.white),
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

  Widget _buildPasswordField(
      TextEditingController controller,
      String hint,
      bool obscure,
      VoidCallback toggle) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
      ),
      validator: Validator.validatePassword,
    );
  }
}
