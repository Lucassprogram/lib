import 'package:flutter/material.dart';

import 'screens/add_skill_page.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/forgot_password_page.dart';
import 'screens/message_page.dart';
import 'screens/signup_page.dart';

void main() {
  runApp(const SkillSwapApp());
}

class SkillSwapApp extends StatelessWidget {
  const SkillSwapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkillSwap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/login': (BuildContext context) => const LoginPage(),
        '/forgotpassword': (BuildContext context) => const ForgotPasswordPage(),
        '/signup': (BuildContext context) => const SignupPage(),
        '/home': (BuildContext context) => const HomePage(),
        '/addskill': (BuildContext context) => const AddSkillPage(),
        '/messages': (BuildContext context) => const MessagePage(),
      },
    );
  }
}
