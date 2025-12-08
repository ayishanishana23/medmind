import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medmind/screens/auth/forgot_password_screen.dart';
import 'package:medmind/screens/auth/await_approval.dart';
import '../../core/validators.dart';
import '../admin/admin_home.dart';
import '../user/user_home.dart';
import 'signup_screen.dart';
import '../../core/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool isLoading = false;

  Future<void> signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .get();
      final data = userDoc.data();

      if (data == null) {
        _showSnackBar("❌ User record not found", Colors.red);
        return;
      }

      final approved = data['approved'] ?? false;
      final role = data['role'] ?? 'user';

      if (!approved && role != 'admin') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const AwaitApproval()));
      } else if (role == 'admin') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const AdminHome()));
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const UserHome()));
      }
    } on FirebaseAuthException catch (e) {
      String message = "❌ Something went wrong";
      if (e.code == 'user-not-found') {
        message = "⚠️ No user found with this email";
      } else if (e.code == 'wrong-password') {
        message = "⚠️ Incorrect password";
      } else if (e.code == 'invalid-email') {
        message = "⚠️ Invalid email format";
      }
      _showSnackBar(message, Colors.red);
    } catch (e) {
      _showSnackBar("❌ Error: ${e.toString()}", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
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
      body: SafeArea(
        child: SingleChildScrollView( // ✅ Fix for overflow
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40), // instead of Spacer
                Center(
                  child: Image.asset('assets/images/clock.png', height: 180),
                ),
                const SizedBox(height: 30),
                const Text("Welcome Back!", style: AppTextStyles.heading),
                const SizedBox(height: 8),
                const Text("Sign in to continue",
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),

                // Email
                TextFormField(
                  controller: emailController,
                  decoration: _inputDecoration("Email"),
                  validator: Validator.validateEmail,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration("Password").copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: Validator.validatePassword,
                ),
                const SizedBox(height: 12),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen()));
                    },
                    child: const Text("Forgot Password?"),
                  ),
                ),
                const SizedBox(height: 12),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Login",
                        style:
                        TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),

                // Sign Up Link
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    child: const Text.rich(
                      TextSpan(
                        text: "No account? ",
                        children: [
                          TextSpan(
                              text: "Sign Up",
                              style: TextStyle(color: AppColors.primary))
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40), // instead of Spacer
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}
