import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  // ===================== Social Media icons Section or Row ========================

  Widget _socialIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      splashColor: color.withOpacity(0.3),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Center(child: FaIcon(icon, color: color, size: 22)),
      ),
    );
  }

  // Header / NavBar
  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.green.shade700,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "partner.com",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/weblogin'),
                child: const Text("Login", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                onPressed: () => Navigator.pushNamed(context, '/registerlogin'),
                child: Text(
                  "Register",
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Hero Section
  Widget _heroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 900;
          return isWide
              ? Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Simplifying Hotel Management for You",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Manage bookings, increase revenue, and get real-time insights — all in one platform.",
                      style: TextStyle(color: Colors.white70, fontSize: 20),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      onPressed: () => Navigator.pushNamed(context, '/registerlogin'),
                      child: Text(
                        "Get Started",
                        style: TextStyle(color: Colors.green.shade700, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 50),
              Expanded(
                child: Image.asset(
                  'assets/LandingPageImages/LandingImage.png',
                  fit: BoxFit.contain,
                  height: 400,
                ),
              ),
            ],
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Simplifying Hotel Management for You",
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                "Manage bookings, increase revenue, and get real-time insights — all in one platform.",
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: () => Navigator.pushNamed(context, '/registerlogin'),
                child: Text(
                  "Get Started",
                  style: TextStyle(color: Colors.green.shade700, fontSize: 18),
                ),
              ),
              const SizedBox(height: 40),
              Image.asset(
                'assets/LandingPageImages/LandingImage.png',
                fit: BoxFit.contain,
                height: 300,
              ),
            ],
          );
        },
      ),
    );
  }

  // Offerings / Benefits Section
  Widget _offeringsSection() {
    final offerings = [
      {"title": "Partner Hotel Management", "desc": "Easily manage all your hotels from one platform.", "icon": Icons.hotel},
      {"title": "Real-Time Dashboard", "desc": "See bookings and revenue in real-time.", "icon": Icons.dashboard},
      {"title": "Analytics & Insights", "desc": "Make data-driven decisions to increase revenue.", "icon": Icons.show_chart},
      {"title": "Multi-Platform Access", "desc": "Web and mobile apps accessible anywhere.", "icon": Icons.devices},
    ];

    return Container(
      color: Colors.green.shade50,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          Text(
            "Why Partner With Us",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade700),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 30,
            runSpacing: 30,
            children: offerings.map((offer) {
              return Container(
                width: 250,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.green.shade100, blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(offer["icon"] as IconData, size: 48, color: Colors.green.shade700),
                    const SizedBox(height: 12),
                    Text(
                      offer["title"] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      offer["desc"] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Testimonials Section
  Widget _testimonialsSection() {
    final testimonials = [
      {"name": "Hotel XYZ", "feedback": "Partnering with this platform increased our bookings by 25%!" },
      {"name": "Hotel ABC", "feedback": "The dashboard is super intuitive and helped us save time." },
      {"name": "Hotel 123", "feedback": "Highly recommend to all hotels looking to streamline operations." },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          Text(
            "What Our Partners Say",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade700),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 30,
            runSpacing: 30,
            children: testimonials.map((t) {
              return Container(
                width: 280,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.green.shade100, blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    Text(
                      "\"${t['feedback']}\"",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t['name']!,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Business Contact Section
  Widget _businessSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.green.shade100, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: const [
          Text(
            "Want to do business with us?",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          SizedBox(height: 12),
          Text(
            "📧 business@yourcompany.com\n📞 +91-99999-99999",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _header(context),
            _heroSection(context),
            _offeringsSection(),
            _testimonialsSection(),
            _businessSection(),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 22,
              runSpacing: 10,
              children: [
                _socialIcon(FontAwesomeIcons.facebookF, Colors.blue, () {}),
                _socialIcon(FontAwesomeIcons.instagram, Colors.pinkAccent, () {}),
                _socialIcon(FontAwesomeIcons.xTwitter, Colors.lightBlueAccent, () {}),
                _socialIcon(FontAwesomeIcons.linkedinIn, Colors.blueAccent, () {}),
                _socialIcon(FontAwesomeIcons.youtube, Colors.red, () {}),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              "© 2025 YourCompany. All rights reserved.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
