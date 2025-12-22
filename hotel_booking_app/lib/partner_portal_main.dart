import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_strategy/url_strategy.dart';
import 'partner_portal/web_screens/web_login.dart';
import 'partner_portal/web_screens/web_register.dart';
import 'partner_portal/web_screens/web_dashboard_page.dart';
import 'partner_portal/web_screens/Domain_Landing_Page.dart';
import 'package:hotel_booking_app/services/api_service.dart';

// Mobile
import 'screens/login_page.dart';

void main() {
  if (kIsWeb) {
    setPathUrlStrategy();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Hotel Booking App",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      initialRoute: '/',
      onGenerateRoute: _generateRoute,
    );
  }

  Route<dynamic> _noTransitionRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  Route<dynamic> _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _noTransitionRoute(const LandingPage());

      case '/weblogin':
        return _noTransitionRoute(const WebLoginPage());

      case '/registerlogin':
        return _noTransitionRoute(const WebRegisterPage());

      case '/login':
        return _noTransitionRoute(LoginPage());

      case '/dashboard':
        final args = settings.arguments as Map<String, String>?;
        if (args == null) {
          return _errorScreen("Missing partnerDetails for Dashboard");
        }
        return _noTransitionRoute(
          WebDashboardPage(partnerDetails: args),
        );

      default:
        return _errorScreen("Route not found: ${settings.name}");
    }
  }

  MaterialPageRoute _errorScreen(String msg) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Text(
            msg,
            style: const TextStyle(color: Colors.red, fontSize: 20),
          ),
        ),
      ),
    );
  }
}
