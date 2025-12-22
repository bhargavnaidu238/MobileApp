import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'web_dashboard_page.dart';
import 'package:hotel_booking_app/services/api_service.dart';

enum ProfileMenuOption { viewProfile, editProfile, changePassword, deleteAccount }

class WebProfilePage extends StatefulWidget {
  final String email;
  final Map<String, String> partnerDetails;

  const WebProfilePage({required this.email, required this.partnerDetails, Key? key}) : super(key: key);

  @override
  State<WebProfilePage> createState() => _WebProfilePageState();
}

class _WebProfilePageState extends State<WebProfilePage> {
  Map<String, TextEditingController> controllers = {};
  bool isLoading = true;
  Map<String, String> profileData = {};
  ProfileMenuOption selectedOption = ProfileMenuOption.viewProfile;

  // Change password controllers
  TextEditingController currentPasswordController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();

  // Password visibility toggles
  bool showCurrentPassword = false;
  bool showNewPassword = false;

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  String normalizeKey(String key) {
    switch (key) {
      case 'Registration_Date':
        return 'Registration Date';
      case 'GST_Number':
        return 'GST Number';
      default:
        return key.replaceAll("_", " ");
    }
  }

  Future<void> fetchProfile() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/webgetprofile');

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'loggedInEmail=${Uri.encodeComponent(widget.email.trim().toLowerCase())}',
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['status'] == 'success') {
          final Map<String, dynamic> data = decoded['data'];
          setState(() {
            profileData = data.map((k, v) => MapEntry(normalizeKey(k), v?.toString() ?? ''));
            controllers.clear();
            for (var key in profileData.keys) {
              controllers[key] = TextEditingController(text: profileData[key] ?? '');
            }
            isLoading = false;
          });
        } else {
          showSnack(decoded['message'] ?? 'Error fetching profile');
          setState(() => isLoading = false);
        }
      } else {
        showSnack("Failed to fetch profile: ${res.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      showSnack("Error fetching profile: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> saveProfile() async {
    try {
      Map<String, String> updatedData = {};
      for (var key in profileData.keys) {
        if (!['Email', 'Status', 'Registration Date'].contains(key)) {
          updatedData[key.replaceAll(" ", "_")] = controllers[key]?.text.trim() ?? '';
        }
      }
      updatedData['loggedInEmail'] = widget.email.trim().toLowerCase();

      final url = Uri.parse("http://localhost:8080/webupdateprofile");
      final bodyString = updatedData.entries
          .map((e) => "${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}")
          .join("&");

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: bodyString,
      );

      final data = jsonDecode(res.body);
      if (data['status'] == 'success') {
        showSnack("Profile updated successfully");
        fetchProfile(); // Refresh data
      } else {
        showSnack(data['message'] ?? "Update failed");
      }
    } catch (e) {
      showSnack("Error updating profile: $e");
    }
  }

  Future<void> changePassword() async {
    try {
      final url = Uri.parse("http://localhost:8080/webchangepassword");
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
        "loggedInEmail=${Uri.encodeComponent(widget.email.trim().toLowerCase())}"
            "&currentPassword=${Uri.encodeComponent(currentPasswordController.text.trim())}"
            "&newPassword=${Uri.encodeComponent(newPasswordController.text.trim())}",
      );
      final data = jsonDecode(res.body);
      if (data['status'] == 'success') {
        showSnack("Password updated successfully");
        currentPasswordController.clear();
        newPasswordController.clear();
      } else {
        showSnack(data['message'] ?? "Password update failed");
      }
    } catch (e) {
      showSnack("Error updating password: $e");
    }
  }

  Future<void> deleteAccount() async {
    try {
      final url = Uri.parse("http://localhost:8080/webdeleteprofile");
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: "loggedInEmail=${Uri.encodeComponent(widget.email.trim())}",
      );
      final data = jsonDecode(res.body);
      if (data['status'] == 'success') {
        showSnack("Account deleted (status set to Inactive)");
        fetchProfile();
      } else {
        showSnack(data['message'] ?? "Delete failed");
      }
    } catch (e) {
      showSnack("Error deleting account: $e");
    }
  }

  void showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget buildFieldCard(String label, TextEditingController? controller,
      {bool isEditable = true, IconData? icon, bool obscureText = false, VoidCallback? toggleVisibility}) {
    return Card(
      elevation: 3,
      shadowColor: Colors.greenAccent.shade200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        child: Row(
          children: [
            if (icon != null)
              Icon(icon, color: Colors.green.shade900, size: 28),
            if (icon != null) const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller ?? TextEditingController(),
                readOnly: !isEditable,
                obscureText: obscureText,
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                      color: isEditable ? Colors.green.shade900 : Colors.grey),
                  border: InputBorder.none,
                  suffixIcon: toggleVisibility != null
                      ? IconButton(
                    icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: toggleVisibility,
                  )
                      : null,
                ),
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isEditable ? Colors.black87 : Colors.grey.shade700),
              ),
            ),
            if (isEditable && toggleVisibility == null)
              Icon(Icons.edit, color: Colors.green.shade700, size: 20),
          ],
        ),
      ),
    );
  }

  Widget buildMenuOption(ProfileMenuOption option, String title) {
    bool selected = selectedOption == option;
    return ListTile(
      selected: selected,
      selectedTileColor: Colors.green.shade100,
      leading: Icon(
        option == ProfileMenuOption.editProfile
            ? Icons.edit
            : option == ProfileMenuOption.changePassword
            ? Icons.lock
            : option == ProfileMenuOption.deleteAccount
            ? Icons.delete
            : Icons.person,
        color: Colors.green.shade900,
      ),
      title: Text(title, style: TextStyle(color: Colors.green.shade900)),
      onTap: () {
        setState(() {
          selectedOption = option;
        });
      },
    );
  }

  Widget buildRightPanel() {
    switch (selectedOption) {
      case ProfileMenuOption.editProfile:
        return SingleChildScrollView(
          child: Column(
            children: [
              buildSection("Personal Info", [
                buildFieldCard("Partner Name", controllers["Partner Name"]),
                buildFieldCard("Email", controllers["Email"], isEditable: false),
              ]),
              buildSection("Business Info", [
                buildFieldCard("Business Name", controllers["Business Name"], icon: Icons.business),
                buildFieldCard("GST Number", controllers["GST Number"], icon: Icons.receipt_long),
              ]),
              buildSection("Address Info", [
                buildFieldCard("Address", controllers["Address"], icon: Icons.home),
                buildFieldCard("City", controllers["City"], icon: Icons.location_city),
                buildFieldCard("State", controllers["State"], icon: Icons.map),
                buildFieldCard("Country", controllers["Country"], icon: Icons.public),
                buildFieldCard("Pincode", controllers["Pincode"], icon: Icons.pin_drop),
              ]),
              buildSection("Contact Info", [
                buildFieldCard("Contact Number", controllers["Contact Number"], icon: Icons.phone),
              ]),
              buildSection("Account Info", [
                buildFieldCard("Status", controllers["Status"], isEditable: false),
                buildFieldCard("Registration Date", controllers["Registration Date"], isEditable: false),
              ]),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Save Changes"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                onPressed: saveProfile,
              ),
            ],
          ),
        );

      case ProfileMenuOption.changePassword:
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                buildFieldCard("Current Password", currentPasswordController, isEditable: true, icon: Icons.lock,
                    obscureText: !showCurrentPassword, toggleVisibility: () {
                      setState(() => showCurrentPassword = !showCurrentPassword);
                    }),
                buildFieldCard("New Password", newPasswordController, isEditable: true, icon: Icons.lock_outline,
                    obscureText: !showNewPassword, toggleVisibility: () {
                      setState(() => showNewPassword = !showNewPassword);
                    }),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("Update Password"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                  onPressed: changePassword,
                ),
              ],
            ),
          ),
        );

      case ProfileMenuOption.deleteAccount:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 80),
                const SizedBox(height: 20),
                const Text("Are you sure you want to delete your account?",
                    style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text("Delete Account"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: deleteAccount,
                ),
              ],
            ),
          ),
        );

      case ProfileMenuOption.viewProfile:
      default:
        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Colors.green.shade300, Colors.green.shade100]),
                  boxShadow: [BoxShadow(color: Colors.green.shade200, blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 50, color: Colors.green),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                profileData["Partner Name"] ?? "",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade900),
              ),
              const SizedBox(height: 30),
              buildSection("Business Info", [
                buildFieldCard("Business Name", controllers["Business Name"], isEditable: false, icon: Icons.business),
                buildFieldCard("GST Number", controllers["GST Number"], isEditable: false, icon: Icons.receipt_long),
              ]),
              buildSection("Address Info", [
                buildFieldCard("Address", controllers["Address"], isEditable: false, icon: Icons.home),
                buildFieldCard("City", controllers["City"], isEditable: false, icon: Icons.location_city),
                buildFieldCard("State", controllers["State"], isEditable: false, icon: Icons.map),
                buildFieldCard("Country", controllers["Country"], isEditable: false, icon: Icons.public),
                buildFieldCard("Pincode", controllers["Pincode"], isEditable: false, icon: Icons.pin_drop),
              ]),
              buildSection("Contact Info", [
                buildFieldCard("Contact Number", controllers["Contact Number"], isEditable: false, icon: Icons.phone),
              ]),
              buildSection("Account Info", [
                buildFieldCard("Status", controllers["Status"], isEditable: false),
                buildFieldCard("Registration Date", controllers["Registration Date"], isEditable: false),
              ]),
            ],
          ),
        );
    }
  }

  Widget buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
        const SizedBox(height: 10),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => WebDashboardPage(partnerDetails: widget.partnerDetails)),
            );
          },
        ),
        title: const Text("My Profile"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
        children: [
          Container(
            width: 250,
            color: Colors.green.shade50,
            child: ListView(
              children: [
                const SizedBox(height: 20),
                buildMenuOption(ProfileMenuOption.viewProfile, "View Profile"),
                buildMenuOption(ProfileMenuOption.editProfile, "Edit Profile"),
                buildMenuOption(ProfileMenuOption.changePassword, "Change Password"),
                buildMenuOption(ProfileMenuOption.deleteAccount, "Delete Account"),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: buildRightPanel(),
            ),
          ),
        ],
      ),
    );
  }
}
