import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class RegisterPage extends StatefulWidget {
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final countryCodeController = TextEditingController(text: "91");
  final mobileController = TextEditingController();
  final passwordController = TextEditingController();
  final addressController = TextEditingController();

  String gender = 'Male';
  bool isConsentGiven = false;

  bool emailEmpty = false;
  bool firstNameEmpty = false;
  bool lastNameEmpty = false;
  bool mobileEmpty = false;
  bool passwordEmpty = false;
  bool addressEmpty = false;

  void _showMessage(BuildContext context, String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isSuccess ? Colors.green : Colors.red),
    );
  }

  bool _validateInputs() {
    setState(() {
      emailEmpty = emailController.text.trim().isEmpty;
      firstNameEmpty = firstNameController.text.trim().isEmpty;
      lastNameEmpty = lastNameController.text.trim().isEmpty;
      mobileEmpty = mobileController.text.trim().isEmpty;
      passwordEmpty = passwordController.text.trim().isEmpty;
      addressEmpty = addressController.text.trim().isEmpty;
    });

    if (emailEmpty || firstNameEmpty || lastNameEmpty || mobileEmpty || passwordEmpty || addressEmpty) {
      _showMessage(context, "Please fill all the fields");
      return false;
    }

    if (!emailController.text.trim().toLowerCase().endsWith("@gmail.com")) {
      _showMessage(context, "Invalid Email Address (must end with @gmail.com)");
      return false;
    }

    if (mobileController.text.trim().length != 10 || !RegExp(r'^[0-9]+$').hasMatch(mobileController.text.trim())) {
      _showMessage(context, "Mobile Number must be exactly 10 digits");
      return false;
    }

    if (!isConsentGiven) {
      _showMessage(context, "Please accept the Terms & Conditions");
      return false;
    }

    return true;
  }

  Future<void> _register() async {
    if (!_validateInputs()) return;

    String mobile = "+${countryCodeController.text.trim()}-${mobileController.text.trim()}";

    final success = await ApiService.registerUser(
      email: emailController.text.toLowerCase().trim(),
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      gender: gender,
      mobile: mobile,
      address: addressController.text.trim(),
      password: passwordController.text.trim(),
      consent: isConsentGiven ? "Yes" : "No",
    );

    if (success) {
      _showMessage(context, "Registration Successful", isSuccess: true);
      Navigator.pop(context);
    } else {
      _showMessage(context, "Registration Failed or Email Already Exists");
    }
  }

  InputDecoration _inputDecoration(String hint, bool isEmpty) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.black54, fontSize: 14),
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      counterText: "", // 👈 Removed "10/10" counter label
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isEmpty ? Colors.red : Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.blueAccent, width: 2),
      ),
    );
  }

  void _showConsentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Terms & Conditions"),
        content: SingleChildScrollView(
          child: Text(
            "Here will be the full consent text. Users must read and accept before proceeding.",
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Decline")),
          TextButton(
            onPressed: () {
              setState(() => isConsentGiven = true);
              Navigator.pop(context);
            },
            child: Text("Accept"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: constraints.maxHeight * 0.25,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/LoginTheme.png'),
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                        ),
                      ),
                      Column(
                        children: [
                          SizedBox(height: 10),
                          TextField(controller: emailController, decoration: _inputDecoration('Email', emailEmpty)),
                          SizedBox(height: 8),
                          TextField(controller: firstNameController, decoration: _inputDecoration('First Name', firstNameEmpty)),
                          SizedBox(height: 8),
                          TextField(controller: lastNameController, decoration: _inputDecoration('Last Name', lastNameEmpty)),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: gender,
                            items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (val) => setState(() => gender = val!),
                            decoration: _inputDecoration('Gender', false),
                          ),
                          SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: countryCodeController,
                                  decoration: _inputDecoration('Code (91)', false),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                flex: 5,
                                child: TextField(
                                  controller: mobileController,
                                  decoration: _inputDecoration('Mobile Number', mobileEmpty),
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,  // 👈 still enforces length
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 8),
                          TextField(controller: addressController, decoration: _inputDecoration('Address', addressEmpty)),
                          SizedBox(height: 8),
                          TextField(controller: passwordController, decoration: _inputDecoration('Password', passwordEmpty), obscureText: true),
                          SizedBox(height: 8),

                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Text('Agree to '),
                                GestureDetector(
                                  onTap: () => _showConsentDialog(context),
                                  child: Text('Terms & Conditions', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                                ),
                              ],
                            ),
                            value: isConsentGiven,
                            onChanged: (val) => setState(() => isConsentGiven = val ?? false),
                          ),

                          SizedBox(height: 8),
                          Container(
                            height: 45,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(colors: [Colors.blueAccent, Colors.lightBlueAccent]),
                            ),
                            child: ElevatedButton(
                              onPressed: isConsentGiven ? _register : null,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text("Register", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),

                          SizedBox(height: 5),
                          TextButton(
                            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage())),
                            child: Text("Back to Login", style: TextStyle(color: Colors.blueAccent, fontSize: 14)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
