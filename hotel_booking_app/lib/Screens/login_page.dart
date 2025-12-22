import 'package:flutter/material.dart';
import 'package:hotel_booking_app/services/api_service.dart';
import 'register_page.dart';

/// ===================== SHARED UI HELPERS =====================

Widget authThemedScaffold({required Widget child}) {
  return Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('assets/LoginTheme.png', fit: BoxFit.cover),
      Container(color: Colors.black.withOpacity(0.3)),
      Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    ],
  );
}

InputDecoration authInput(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.black),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black),
    ),
  );
}

Widget authButton(String text, VoidCallback onTap) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFA8E063), Color(0xFF56AB2F)],
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    ),
  );
}

/// ===================== LOGIN PAGE =====================

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool passwordVisible = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = usernameController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      snack("Please enter email and password");
      return;
    }

    setState(() => isLoading = true);

    final res = await ApiService.loginUser(
      email: email,
      password: password,
    );

    setState(() => isLoading = false);

    if (res == null || res.containsKey('error')) {
      snack("Login failed");
      return;
    }

    Navigator.pushReplacementNamed(context, '/home', arguments: res);
  }

  void snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: authThemedScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: authInput("Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: !passwordVisible,
              decoration: authInput("Password").copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    passwordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.black,
                  ),
                  onPressed: () =>
                      setState(() => passwordVisible = !passwordVisible),
                ),
              ),
            ),
            const SizedBox(height: 16),
            isLoading
                ? const CircularProgressIndicator(color: Colors.black)
                : authButton("Login", login),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ForgotPasswordPage()),
                  ),
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RegisterPage()),
                  ),
                  child: const Text(
                    "Register Here?",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ===================== FORGOT PASSWORD =====================

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();
  final mobile = TextEditingController();
  final newPass = TextEditingController();
  final confirmPass = TextEditingController();

  bool verified = false;
  bool loading = false;

  void snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> verifyUser() async {
    setState(() => loading = true);

    final res = await ApiService.verifyForgotPassword(
      email: email.text.trim(),
      mobile: mobile.text.trim(),
    );

    setState(() => loading = false);

    if (res['matched'] == true) {
      setState(() => verified = true);
    } else {
      snack("Email or mobile number not matching");
    }
  }

  Future<void> changePassword() async {
    if (newPass.text != confirmPass.text) {
      snack("Passwords do not match");
      return;
    }

    setState(() => loading = true);

    final res = await ApiService.changePassword(
      email: email.text.trim(),
      newPassword: newPass.text,
    );

    setState(() => loading = false);

    if (res['success'] == true) {
      snack("Password changed successfully");
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: authThemedScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 🔹 TITLE
            Text(
              verified
                  ? "Enter Password"
                  : "Enter Email and Mobile Number",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 16),

            /// 🔹 STEP 1
            if (!verified) ...[
              TextField(
                controller: email,
                decoration: authInput("Email"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobile,
                decoration: authInput("Mobile Number"),
              ),
            ],

            /// 🔹 STEP 2
            if (verified) ...[
              TextField(
                controller: newPass,
                obscureText: true,
                decoration: authInput("New Password"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPass,
                obscureText: true,
                decoration: authInput("Confirm Password"),
              ),
            ],

            const SizedBox(height: 20),

            loading
                ? const Center(
              child: CircularProgressIndicator(color: Colors.black),
            )
                : authButton(
              verified ? "Change Password" : "Next",
              verified ? changePassword : verifyUser,
            ),
          ],
        ),
      ),
    );
  }
}
