import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:http/http.dart' as http;
import 'web_profile.dart';
import 'web_login.dart';
import 'add_hotels_page.dart';
import 'Add_PGs_Page.dart';
import 'View_Hotels_Page.dart';
import 'View_Bookings_Page.dart';
import 'about_us_page.dart';
import 'Web_Finance_Page.dart';
import 'View_PGs_Page.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class WebDashboardPage extends StatefulWidget {
  final Map<String, String> partnerDetails;

  const WebDashboardPage({
    Key? key,
    required this.partnerDetails,
  }) : super(key: key);

  @override
  State<WebDashboardPage> createState() => _WebDashboardPageState();
}

class _WebDashboardPageState extends State<WebDashboardPage> with SingleTickerProviderStateMixin {
  bool isSidebarCollapsed = false;
  bool manageBusinessExpanded = false;

  // Dashboard fields (populated from backend)
  int totalBookings = 0;
  int pending = 0;
  int confirmed = 0;
  int cancelled = 0;
  int completed = 0;

  double totalRevenue = 0.0;
  double netRevenue = 0.0;

  // Notification counts
  int pendingNotif = 0;
  int financeNotif = 0;

  // Bell animation controller
  late final AnimationController bellController;

  final String apiBase = 'http://127.0.0.1:8080';

  bool isLoading = false;
  String? lastError;
  DateTime? lastUpdated;

  @override
  void initState() {
    super.initState();
    bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      lowerBound: 0.98,
      upperBound: 1.02,
    );

    fetchDashboardData();
  }

  @override
  void dispose() {
    bellController.dispose();
    super.dispose();
  }

  // ============= Fetch Dashboard Data ==============
  Future<void> fetchDashboardData() async {
    final partnerId = widget.partnerDetails['Partner_ID'] ?? '';
    if (partnerId.isEmpty) {
      setState(() {
        lastError = 'Missing Partner_ID in partnerDetails';
      });
      return;
    }

    setState(() {
      isLoading = true;
      lastError = null;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}/api/partner/$partnerId/dashboard');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> d = json.decode(response.body);

        setState(() {
          totalBookings = _toInt(d['totalBookings']);
          pending = _toInt(d['pending']);
          confirmed = _toInt(d['confirmed']);
          cancelled = _toInt(d['cancelled']);
          completed = _toInt(d['completed']);

          totalRevenue = _toDouble(d['totalRevenue']);
          netRevenue = _toDouble(d['netRevenue']);

          pendingNotif = _toInt(d['pendingNotifications']);
          financeNotif = _toInt(d['financeNotifications']);

          lastUpdated = DateTime.now();

          if (pendingNotif + financeNotif > 0) {
            if (!bellController.isAnimating) bellController.repeat(reverse: true);
          } else {
            if (bellController.isAnimating) bellController.stop();
          }

          isLoading = false;
        });
      } else {
        setState(() {
          lastError = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        lastError = 'Failed to fetch dashboard: $e';
        isLoading = false;
      });
    }
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  // ================ POP-UP UNDER BELL + RESET COUNT LOGIC ================
  void _onNotificationTap(GlobalKey iconKey) async {
    if (pendingNotif == 0 && financeNotif == 0) return;

    // RESET NOTIFICATION COUNT BEFORE OPENING MENU
    int pendingBefore = pendingNotif;
    int financeBefore = financeNotif;

    setState(() {
      pendingNotif = 0;
      financeNotif = 0;
    });

    // Position of bell icon
    final RenderBox renderBox = iconKey.currentContext!.findRenderObject() as RenderBox;
    final Offset position = renderBox.localToGlobal(Offset.zero);

    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx + renderBox.size.width - 10,
        position.dy + renderBox.size.height,
        0,
        0,
      ),
      items: [
        if (pendingBefore > 0)
          PopupMenuItem(
            value: 'pending',
            child: Text("You have $pendingBefore pending bookings"),
          ),
        if (financeBefore > 0)
          const PopupMenuItem(
            value: 'finance',
            child: Text("Your payout status is updated, check now."),
          ),
      ],
    );

    if (result == 'pending') {
      final partnerId = widget.partnerDetails['Partner_ID'] ?? '';
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookingPage(partnerId: partnerId)),
      ).then((_) => fetchDashboardData());
    }

    if (result == 'finance') {
      final partnerId = widget.partnerDetails['Partner_ID'] ?? '';
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FinancePage(partnerId: partnerId)),
      ).then((_) => fetchDashboardData());
    }
  }

  void _onMenuClick(String option) {
    final partnerId = widget.partnerDetails['Partner_ID'] ?? '';
    if (option == 'Add Hotels') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AddHotelsPage(partnerId: partnerId)));
    } else if (option == 'Add Paying Guests') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AddPGSPage(partnerId: partnerId)));
    } else if (option == 'View Hotels') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ViewHotelsPage(partnerId: partnerId)));
    } else if (option == 'View PGs') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ViewPGsPage(partnerId: partnerId)));
    }else if (option == 'Bookings') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => BookingPage(partnerId: partnerId)))
          .then((_) => fetchDashboardData());
    } else if (option == 'Finance') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => FinancePage(partnerId: partnerId)));
    } else if (option == 'About Us') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsPage()));
    } else if (option == 'Home') {
      fetchDashboardData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dashboard refreshed')));
    }
  }

  void _onProfileMenuSelected(String value) {
    if (value == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebProfilePage(
            email: widget.partnerDetails['Email'] ?? '',
            partnerDetails: widget.partnerDetails,
          ),
        ),
      );
    } else if (value == 'logout') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WebLoginPage()));
    }
  }

  Widget infoText(String label, dynamic value) {
    final val = value is double ? value.toStringAsFixed(2) : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text('$label : $val', style: const TextStyle(color: Colors.white, fontSize: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;
    final partnerName = widget.partnerDetails['Partner_Name'] ?? 'Partner';

    final GlobalKey bellKey = GlobalKey(); // KEY ADDED FOR POPUP LOCATION

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isMobile ? 0 : (isSidebarCollapsed ? 80 : 220),
            color: Colors.white,
            child: isMobile
                ? null
                : Column(
              children: [
                const SizedBox(height: 40),
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: isSidebarCollapsed ? 16 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 30),
                _SideMenuItem(icon: Icons.home, title: 'Home', collapsed: isSidebarCollapsed, onTap: () => _onMenuClick('Home')),
                _SideMenuItem(icon: Icons.book, title: 'Bookings', collapsed: isSidebarCollapsed, onTap: () => _onMenuClick('Bookings')),
                _SideMenuItem(icon: Icons.business, title: 'Manage Business', collapsed: isSidebarCollapsed, onTap: () {
                  setState(() => manageBusinessExpanded = !manageBusinessExpanded);
                }),
                if (manageBusinessExpanded)
                  Padding(
                    padding: EdgeInsets.only(left: isSidebarCollapsed ? 8 : 24),
                    child: Column(
                      children: [
                        _SideMenuItem(icon: Icons.add, title: 'Add Hotels', collapsed: isSidebarCollapsed, onTap: () => _onMenuClick('Add Hotels')),
                        _SideMenuItem(icon: Icons.add, title: 'Add Paying Guests', collapsed: isSidebarCollapsed, onTap: () => _onMenuClick('Add Paying Guests')),
                        _SideMenuItem(icon: Icons.view_list, title: 'View Hotels', collapsed: isSidebarCollapsed, onTap: () => _onMenuClick('View Hotels')),
                        _SideMenuItem(icon: Icons.view_list, title: 'View PGs', collapsed: isSidebarCollapsed, onTap: () => _onMenuClick('View PGs')),
                      ],
                    ),
                  ),
                _SideMenuItem(icon: Icons.account_balance_wallet, title: 'Finance', collapsed: isSidebarCollapsed, onTap: () => _onMenuClick('Finance')),
                _SideMenuItem(icon: Icons.settings, title: 'Settings', collapsed: isSidebarCollapsed, onTap: () => _onMenuClick('Settings')),
                _SideMenuItem(icon: Icons.info_outline, title: 'About Us', collapsed: isSidebarCollapsed, onTap: () => _onMenuClick('About Us')),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => isSidebarCollapsed = !isSidebarCollapsed),
                  icon: Icon(isSidebarCollapsed ? Icons.arrow_forward_ios : Icons.arrow_back_ios),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C853), Color(0xFFB2FF59)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (isMobile)
                            IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () => setState(() => isSidebarCollapsed = !isSidebarCollapsed),
                            ),
                          Text('Welcome, $partnerName!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      Row(
                        children: [
                          ScaleTransition(
                            scale: bellController,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  key: bellKey,
                                  onPressed: () => _onNotificationTap(bellKey),
                                  icon: const Icon(Icons.notifications, color: Colors.white),
                                ),
                                if (pendingNotif + financeNotif > 0)
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${pendingNotif + financeNotif}',
                                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          PopupMenuButton<String>(
                            onSelected: _onProfileMenuSelected,
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'profile', child: Text('View Profile')),
                              const PopupMenuItem(value: 'logout', child: Text('Logout', style: TextStyle(color: Colors.red))),
                            ],
                            child: CircleAvatar(backgroundColor: Colors.green.shade900, child: const Icon(Icons.person, color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = 3;
                        if (constraints.maxWidth < 1200) crossAxisCount = 2;
                        if (constraints.maxWidth < 800) crossAxisCount = 1;

                        double childAspectRatio = (constraints.maxWidth / crossAxisCount) / 200;
                        if (childAspectRatio < 1.2) childAspectRatio = 1.2;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (isLoading) const Text('Loading dashboard...', style: TextStyle(color: Colors.black54)),
                                if (lastError != null) Text('Error: $lastError', style: const TextStyle(color: Colors.red)),
                                if (lastUpdated != null) Text('Last updated: ${lastUpdated!.toLocal().toString().split('.').first}', style: const TextStyle(color: Colors.black54)),
                                ElevatedButton.icon(
                                  onPressed: fetchDashboardData,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Refresh'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: GridView.count(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                                childAspectRatio: childAspectRatio,
                                children: [
                                  DashboardFlipCard(
                                    title: 'Total Bookings',
                                    value: '$totalBookings',
                                    color: Colors.green.shade700,
                                    backWidget: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        infoText('Pending', pending),
                                        infoText('Confirmed', confirmed),
                                        infoText('Cancelled', cancelled),
                                        infoText('Completed', completed),
                                      ],
                                    ),
                                  ),
                                  DashboardFlipCard(
                                    title: 'Pending Requests',
                                    value: '$pending',
                                    color: Colors.lime.shade700,
                                    backWidget: Center(
                                      child: Text('Pending bookings: $pending', style: const TextStyle(color: Colors.white, fontSize: 16)),
                                    ),
                                  ),
                                  DashboardFlipCard(
                                    title: 'Revenue',
                                    value: '₹ ${totalRevenue.toStringAsFixed(2)}',
                                    color: Colors.teal.shade700,
                                    backWidget: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        infoText('Total Revenue', totalRevenue),
                                        infoText('Net Revenue', netRevenue),
                                      ],
                                    ),
                                  ),
                                  DashboardFlipCard(
                                    title: 'Users',
                                    value: '0',
                                    color: Colors.purple.shade700,
                                    backWidget: const Center(child: Text('Users (no data)', style: TextStyle(color: Colors.white))),
                                  ),
                                  DashboardFlipCard(
                                    title: 'Reviews',
                                    value: '0',
                                    color: Colors.orange.shade700,
                                    backWidget: const Center(child: Text('Reviews (no data)', style: TextStyle(color: Colors.white))),
                                  ),
                                  DashboardFlipCard(
                                    title: 'Misc',
                                    value: '-',
                                    color: Colors.red.shade700,
                                    backWidget: const Center(child: Text('Misc', style: TextStyle(color: Colors.white))),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======== Dashboard Side Menu ================
class _SideMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool collapsed;
  final VoidCallback? onTap;

  const _SideMenuItem({required this.icon, required this.title, this.collapsed = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: title,
      child: ListTile(
        leading: Icon(icon, color: Colors.green.shade900),
        title: collapsed ? null : Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        hoverColor: Colors.green.shade100,
        onTap: onTap,
      ),
    );
  }
}

// ================= Dashboard Flipping Card ======================
class DashboardFlipCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final Widget backWidget;

  const DashboardFlipCard({required this.title, required this.value, required this.color, required this.backWidget});

  @override
  Widget build(BuildContext context) {
    return FlipCard(
      direction: FlipDirection.HORIZONTAL,
      speed: 450,
      front: Container(
        height: 150,
        decoration: _boxDecoration(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const Spacer(),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      back: Container(
        height: 150,
        decoration: _boxDecoration(),
        padding: const EdgeInsets.all(20),
        child: backWidget,
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withOpacity(0.85), color],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
    );
  }
}
