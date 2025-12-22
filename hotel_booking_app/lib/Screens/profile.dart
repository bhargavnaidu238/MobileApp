import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hotel_booking_app/screens/booking_history_page.dart';
import 'package:hotel_booking_app/screens/Customize_Preference_Page.dart';
import '../screens/rewards_wallet_page.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class ProfilePage extends StatefulWidget {
  final String email;
  final String userId;

  const ProfilePage({required this.email, required this.userId, Key? key})
      : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isFetching = true;
  Map<String, dynamic> profileData = {};

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    if (widget.email.isEmpty) {
      debugPrint('❌ ProfilePage: Email is empty.');
      setState(() => isFetching = false);
      return;
    }

    try {
      final data = await ProfileApiService.fetchProfile(email: widget.email);

      profileData = data ?? {
        "firstName": "",
        "lastName": "",
        "email": widget.email,
        "phone": "",
        "address": "",
      };

      debugPrint("📌 Loaded Profile UserID: ${widget.userId}");
    } catch (e) {
      debugPrint("❌ Error fetching profile: $e");
    }

    if (mounted) setState(() => isFetching = false);
  }

  String capitalize(String text) =>
      text.isEmpty ? '' : text[0].toUpperCase() + text.substring(1).toLowerCase();

  String get fullName {
    final first = capitalize(profileData['firstName'] ?? '');
    final last = capitalize(profileData['lastName'] ?? '');
    return (first + ' ' + last).trim().isEmpty ? 'Guest User' : "$first $last";
  }

  @override
  Widget build(BuildContext context) {
    return isFetching
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : Scaffold(
      backgroundColor: Colors.lime.shade50,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 20),
          Expanded(child: _buildDashboardGrid()),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 30),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.green.shade400, Colors.green.shade700],
      ),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(40),
        bottomRight: Radius.circular(40),
      ),
    ),
    child: Column(
      children: [
        CircleAvatar(
          radius: 45,
          backgroundColor: Colors.white,
          child: CircleAvatar(
            radius: 42,
            backgroundColor: Colors.green[700],
            child: Text(
              fullName[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(fullName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(profileData['email'],
            style: const TextStyle(color: Colors.white70)),
      ],
    ),
  );

  Widget _buildDashboardGrid() => GridView.count(
    padding: const EdgeInsets.all(20),
    crossAxisCount: 2,
    crossAxisSpacing: 20,
    mainAxisSpacing: 20,
    children: [
      _buildDashboardCard(
        Icons.person,
        "View / Edit\nProfile",
        [Colors.green.shade400, Colors.green.shade700],
            () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProfileDetailsPage(email: widget.email, userId: widget.userId),
            ),
          );
          fetchProfile();
        },
      ),
      _buildDashboardCard(
        Icons.settings,
        "Customize\nPreferences",
        [Colors.purpleAccent, Colors.deepPurple],
            () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CustomizePreferencesPage(email: widget.email, userId: widget.userId),
            ),
          );
          fetchProfile();
        },
      ),
      _buildDashboardCard(
        Icons.card_giftcard,
        "Rewards &\nWallets",
        [Colors.orangeAccent, Colors.deepOrange],
            () {
          if (widget.userId.isEmpty || widget.userId == "null") {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("⚠ User session invalid. Please log in again."),
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RewardsWalletPage(email: widget.email, userId: widget.userId),
            ),
          );
        },
      ),
      _buildDashboardCard(
        Icons.history,
        "Booking\nHistory",
        [Colors.blueAccent, Colors.blue.shade700],
            () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    BookingHistoryPage(email: widget.email, userId: widget.userId)),
          );
        },
      ),
      _buildDashboardCard(
        Icons.info_outline,
        "About Us",
        [Colors.purpleAccent, Colors.deepPurple],
            () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutUsPage()),
          );
        },
      ),
      _buildDashboardCard(
        Icons.logout,
        "Logout",
        [Colors.redAccent, Colors.red.shade700],
            () {
          Navigator.pushReplacementNamed(context, '/');
        },
      ),
    ],
  );

  Widget _buildDashboardCard(
      IconData icon, String label, List<Color> gradient, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 10),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}

/* -------------------------------------------------------------------------
         ⭐ UPDATED PROFILE DETAILS PAGE WITH COUNTRY CODE FEATURE ⭐
--------------------------------------------------------------------------- */

class ProfileDetailsPage extends StatefulWidget {
  final String email;
  final String userId;

  const ProfileDetailsPage({required this.email, required this.userId, Key? key})
      : super(key: key);

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  late TextEditingController firstNameController,
      lastNameController,
      emailController,
      phoneController,
      countryCodeController,
      addressController;

  bool isEditing = false, isLoading = false, isFetching = true, isDeleting = false;

  @override
  void initState() {
    super.initState();

    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    emailController = TextEditingController(text: widget.email);
    phoneController = TextEditingController();
    countryCodeController = TextEditingController(text: '+91');
    addressController = TextEditingController();

    fetchProfile();
  }

  String capitalize(String text) =>
      text.isEmpty ? '' : text[0].toUpperCase() + text.substring(1).toLowerCase();

  Future<void> fetchProfile() async {
    final data = await ProfileApiService.fetchProfile(email: widget.email);

    if (mounted) {
      setState(() {
        firstNameController.text = capitalize(data?['firstName'] ?? '');
        lastNameController.text = capitalize(data?['lastName'] ?? '');

        final phone = data?['phone'] ?? '';
        if (phone.contains("-")) {
          final parts = phone.split("-");
          countryCodeController.text = parts[0];
          phoneController.text = parts[1];
        } else {
          phoneController.text = phone;
        }

        addressController.text = data?['address'] ?? '';
        isFetching = false;
      });
    }
  }

  Future<void> updateProfile() async {
    final mobile = phoneController.text.trim();
    final formattedPhone = "${countryCodeController.text}-$mobile";

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number must be exactly 10 digits")),
      );
      return;
    }

    setState(() => isLoading = true);

    final success = await ProfileApiService.updateProfile(
      email: widget.email,
      userId: widget.userId,
      firstName: capitalize(firstNameController.text),
      lastName: capitalize(lastNameController.text),
      phone: formattedPhone,
      address: addressController.text,
    );

    setState(() {
      isLoading = false;
      isEditing = !success;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? "Profile Updated" : "Update Failed")),
    );
  }

  Future<void> deleteAccount() async {
    setState(() => isDeleting = true);

    final success = await ProfileApiService.deactivateAccount(
      email: widget.email,
      userId: widget.userId,
      status: "Inactive",
    );

    setState(() => isDeleting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Account Deleted")));
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    }
  }

  void confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account", style: TextStyle(color: Colors.red)),
        content: const Text("This action is permanent. Continue?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              deleteAccount();
            },
          ),
        ],
      ),
    );
  }

  Widget buildPhoneField() {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: TextField(
            controller: countryCodeController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: "Code",
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: phoneController,
            enabled: isEditing,
            keyboardType: TextInputType.number,
            maxLength: 10,
            buildCounter: (_, {required currentLength, maxLength, required isFocused}) => null,
            decoration: const InputDecoration(
              labelText: "Mobile Number",
              border: OutlineInputBorder(),
            ),
          ),
        )
      ],
    );
  }

  Widget buildField(String label, TextEditingController controller,
      {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        enabled: enabled,
        controller: controller,
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          labelText: label,
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade200,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isFetching) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => isEditing = !isEditing),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    buildField("First Name", firstNameController, enabled: isEditing),
                    buildField("Last Name", lastNameController, enabled: isEditing),
                    buildField("Email", emailController, enabled: false),
                    buildPhoneField(),
                    buildField("Address", addressController, enabled: isEditing),
                  ],
                ),
              ),
            ),
            if (isEditing)
              ElevatedButton(
                onPressed: isLoading ? null : updateProfile,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Changes"),
              ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: isDeleting ? null : confirmDelete,
              icon: isDeleting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete, color: Colors.red),
              label: const Text("Delete Account", style: TextStyle(color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }
}

/* ------------------------- ABOUT US PAGE ------------------------- */

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
      AppBar(title: const Text("About Us"), backgroundColor: Colors.purple),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("About Us",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.instagram),
                  onPressed: () {},
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
