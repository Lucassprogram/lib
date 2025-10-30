import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();

  bool isSubmitting = false;
  String feedbackMessage = '';
  bool isError = false;

  Future<void> _submitResetRequest() async {
    FocusScope.of(context).unfocus();
    final String email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        feedbackMessage =
            'Please enter the email associated with your account.';
        isError = true;
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      feedbackMessage = '';
      isError = false;
    });

    try {
      final Map<String, dynamic> result =
          await ApiService.requestPasswordReset(email);

      if (!mounted) {
        return;
      }

      final String? error = result['error']?.toString();
      if (error != null && error.isNotEmpty) {
        final String normalizedError = error.toLowerCase();
        final bool hideDetails = normalizedError.contains('no user') ||
            normalizedError.contains('not found');
        setState(() {
          feedbackMessage = hideDetails
              ? "If that account exists, we'll email a reset link shortly."
              : error;
          isError = !hideDetails;
          isSubmitting = false;
        });
        return;
      }

      final String successMessage = result['message']?.toString() ??
          "If that account exists, we'll email a reset link shortly.";

      setState(() {
        feedbackMessage = successMessage;
        isError = false;
        isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        feedbackMessage = 'Unable to send reset link: $error';
        isError = true;
        isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F2),
        elevation: 0,
        foregroundColor: const Color(0xFF3A4DA3),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: 340,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Center(
                    child: Icon(
                      Icons.lock_reset,
                      color: Color(0xFF3A4DA3),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Forgot Password',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3A4DA3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Enter your account email. If it exists, you'll receive a link "
                    "to reset your password.",
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email_outlined),
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3A4DA3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isSubmitting ? null : _submitResetRequest,
                      child: Text(
                        isSubmitting ? 'Sending...' : 'Send Reset Link',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Back to sign in',
                      style: TextStyle(color: Color(0xFF3A4DA3)),
                    ),
                  ),
                  if (feedbackMessage.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      feedbackMessage,
                      style: TextStyle(
                        color: isError ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
