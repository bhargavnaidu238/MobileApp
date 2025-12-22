import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'web_login.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class WebRegisterPage extends StatefulWidget {
  const WebRegisterPage({Key? key}) : super(key: key);

  @override
  State<WebRegisterPage> createState() => _WebRegisterPageState();
}

class _WebRegisterPageState extends State<WebRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController businessController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController countryController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController gstController = TextEditingController();

  bool isLoading = false;

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = nameController.text.trim();
    final business = businessController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final phone = phoneController.text.trim();
    final address = addressController.text.trim();
    final city = cityController.text.trim();
    final state = stateController.text.trim();
    final country = countryController.text.trim();
    final pincode = pincodeController.text.trim();
    final gst = gstController.text.trim();

    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/registerlogin');

      final body = 'partner_name=${Uri.encodeComponent(name)}'
          '&business_name=${Uri.encodeComponent(business)}'
          '&email=${Uri.encodeComponent(email)}'
          '&password=${Uri.encodeComponent(password)}'
          '&contact_number=${Uri.encodeComponent(phone)}'
          '&address=${Uri.encodeComponent(address)}'
          '&city=${Uri.encodeComponent(city)}'
          '&state=${Uri.encodeComponent(state)}'
          '&country=${Uri.encodeComponent(country)}'
          '&pincode=${Uri.encodeComponent(pincode)}'
          '&gst_number=${Uri.encodeComponent(gst)}';

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Registration failed")),
        );

        if (data['status'] == 'success') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const WebLoginPage()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error: ${res.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    IconData? icon,
    bool obscure = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.white70)
            : const SizedBox(),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        errorStyle: const TextStyle(color: Colors.redAccent),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white70),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white38),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00C853), Color(0xFFB2FF59)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(40),
              margin: const EdgeInsets.symmetric(horizontal: 60),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border:
                Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Partner Registration",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black45, blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ---- FIELDS ----
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth > 900
                          ? 380.0
                          : double.infinity;

                      return Wrap(
                        spacing: 25,
                        runSpacing: 20,
                        children: [
                          SizedBox(
                            width: width,
                            child: buildTextField(
                              controller: nameController,
                              label: "Full Name",
                              icon: Icons.person,
                              validator: (value) =>
                              value!.isEmpty ? "Full Name required" : null,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: buildTextField(
                              controller: businessController,
                              label: "Business Name",
                              icon: Icons.business,
                              validator: (value) => value!.isEmpty
                                  ? "Business Name required"
                                  : null,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: buildTextField(
                              controller: emailController,
                              label: "Email",
                              icon: Icons.email,
                              validator: (value) =>
                              value!.isEmpty ? "Email required" : null,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: buildTextField(
                              controller: passwordController,
                              label: "Password",
                              icon: Icons.lock,
                              obscure: true,
                              validator: (value) =>
                              value!.isEmpty ? "Password required" : null,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: buildTextField(
                              controller: phoneController,
                              label: "Phone Number",
                              icon: Icons.phone,
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return "Phone number required";
                                }
                                if (!RegExp(r'^[0-9]{10}$')
                                    .hasMatch(value.trim())) {
                                  return "Enter valid 10-digit phone number";
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: buildTextField(
                              controller: addressController,
                              label: "Address",
                              icon: Icons.home,
                              validator: (value) =>
                              value!.isEmpty ? "Address required" : null,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: buildTextField(
                              controller: cityController,
                              label: "City",
                              icon: Icons.location_city,
                              validator: (value) =>
                              value!.isEmpty ? "City required" : null,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: buildTextField(
                              controller: stateController,
                              label: "State",
                              icon: Icons.map,
                              validator: (value) =>
                              value!.isEmpty ? "State required" : null,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: buildTextField(
                              controller: countryController,
                              label: "Country",
                              icon: Icons.flag,
                              validator: (value) =>
                              value!.isEmpty ? "Country required" : null,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: buildTextField(
                              controller: pincodeController,
                              label: "Pincode",
                              icon: Icons.pin_drop,
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return "Pincode required";
                                }
                                if (!RegExp(r'^[0-9]{6}$')
                                    .hasMatch(value.trim())) {
                                  return "Enter valid 6-digit pincode";
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: buildTextField(
                              controller: gstController,
                              label: "GST Number",
                              icon: Icons.receipt_long,
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return "GST Number required";
                                }
                                if (!RegExp(r'^[A-Za-z0-9]{15}$')
                                    .hasMatch(value.trim())) {
                                  return "GST must be 15 alphanumeric characters";
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : ElevatedButton(
                    onPressed: register,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(260, 50),
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Register",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WebLoginPage()),
                      );
                    },
                    child: const Text(
                      "Already have an account? Login",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
