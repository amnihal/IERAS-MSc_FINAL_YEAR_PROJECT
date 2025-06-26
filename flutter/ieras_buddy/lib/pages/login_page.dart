import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ieras_buddy/config.dart';
import 'package:ieras_buddy/pages/ambulance/amb_home.dart';
import 'package:ieras_buddy/pages/signup_page.dart';
import 'package:ieras_buddy/pages/user/user_home.dart';
import 'package:ieras_buddy/pages/vehicle/vehicle_home.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> loginUser() async {
    final response = await http.post(
      Uri.parse('http://$baseUrl/user/login/'), // Change IP if needed
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contact': phoneController.text,
        'password': passwordController.text,
      }),
    );

    if (response.statusCode == 200) {
      print('Response body: ${response.body}');
      final data = jsonDecode(response.body);
      final userType = data['user_type'];
      final userId = data['id'];

      // Store user_id and user_type locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', userId);
      await prefs.setString('user_type', userType);

      if (userType == 'normal') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserHome()),
        );
      } else if (userType == 'driver') {
        final ambulanceId = data['ambulance_id'];
        final ambulanceType = data['ambulance_type'];

        if (ambulanceId != null) {
          await prefs.setInt('ambulance_id', ambulanceId);
          await prefs.setString('ambulance_type', ambulanceType ?? '');
          print('Saved ambulance_id: $ambulanceId');
          print('Saved ambulance_type: $ambulanceType');

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DriverHomePage()),
          );
        } else {
          // Ambulance ID is null, show message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ambulance not assigned')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid credentials')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          margin: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _header(),
              _inputField(),
              // _forgotPassword(),
              _signup(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            // Navigate to CarInfotainmentUI when "Welcome Back" is tapped
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CarInfotainmentUI()),
            );
          },
          child: const Text(
            "Welcome Back",
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent, // Optional: give it some style
            ),
          ),
        ),
        const Text("Enter your credential to login"),
      ],
    );
  }


  Widget _inputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: phoneController,
          decoration: InputDecoration(
            hintText: "Phone number",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            fillColor: Colors.redAccent.withValues(alpha: 0.1),
            filled: true,
            prefixIcon: const Icon(Icons.phone),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: passwordController,
          decoration: InputDecoration(
            hintText: "Password",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            fillColor: Colors.redAccent.withValues(alpha: 0.1),
            filled: true,
            prefixIcon: const Icon(Icons.password),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: loginUser,
          style: ElevatedButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.redAccent,
          ),
          child: const Text(
            "Login",
            style: TextStyle(fontSize: 20),
          ),
        ),
      ],
    );
  }

  // Widget _forgotPassword() {
  //   return TextButton(
  //     onPressed: () {},
  //     child: const Text(
  //       "Forgot password?",
  //       style: TextStyle(color: Colors.redAccent),
  //     ),
  //   );
  // }

  Widget _signup() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account? "),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignupPage()),
            );
          },
          child: const Text(
            "Sign Up",
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}
