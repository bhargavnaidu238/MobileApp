import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({Key? key}) : super(key: key);

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
        child: Center(
          child: FaIcon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        elevation: 4,
        title: const Text("About Us", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade50,
                Colors.green.shade100.withOpacity(0.6),
                Colors.white,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Company Intro Section
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: const [
                    Text(
                      "Who We Are",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "We are a forward-thinking hotel booking platform connecting partners and travelers with seamless solutions. Our aim is to simplify hotel management and deliver outstanding experiences for guests and businesses alike.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Offerings Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Text(
                      "Our Offerings",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "✔️ Partner Hotel Management\n"
                          "✔️ Real-Time Booking Dashboard\n"
                          "✔️ Analytics and Revenue Insights\n"
                          "✔️ Multi-Platform Access (Web + Mobile)",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),

              // Business Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: const [
                    Text(
                      "Want to do business with us?",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "📧 business@yourcompany.com\n📞 +91-99999-99999",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              const Divider(thickness: 1.2),
              const SizedBox(height: 20),

              // Social Icons Row
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

              // Footer
              const Text(
                "© 2025 YourCompany. All rights reserved.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
