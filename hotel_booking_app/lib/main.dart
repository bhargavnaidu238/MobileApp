import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/home_page.dart' as home;
import 'screens/booking_function.dart';
import 'screens/profile.dart';
import 'screens/booking_history_page.dart';
import 'screens/hotels_page.dart';
import 'screens/paying_guests_page.dart' as pgs;


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hotel Booking App',
      theme: ThemeData(
        primarySwatch: Colors.lime,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => LoginPage());

          case '/register':
            return MaterialPageRoute(builder: (_) => RegisterPage());

          case '/home':
            final user = settings.arguments as Map<String, dynamic>? ?? {
              'userId': '',
              'name': 'Guest User',
              'email': '',
              'mobile': ''
            };
            return MaterialPageRoute(builder: (_) => home.HomePage(user: user));

          case '/hotels':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final user = args['user'] as Map<String, dynamic>? ?? {
              'userId': '',
              'name': 'Guest User',
              'email': '',
              'mobile': ''
            };
            final type = args['type'] ?? "all";
            return MaterialPageRoute(
              builder: (_) => HotelsPage(user: user, type: type),
            );

          case '/paying_guest':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final user = args['user'] as Map<String, dynamic>? ?? {
              'userId': '',
              'name': 'Guest User',
              'email': '',
              'mobile': ''
            };
            final type = args['type'] ?? "PG";
            return MaterialPageRoute(
              builder: (_) => pgs.PgsPage(user: user, type: type),
            );

        // ✅ FIXED UNIVERSAL BOOKING NAVIGATION
          case '/booking':
            final args = settings.arguments as Map<String, dynamic>? ?? {};

            // 1. Extract Hotel or PG data from arguments
            final Map<String, dynamic> hotelOrPg =
                args['hotel'] as Map<String, dynamic>? ??
                    args['pg'] as Map<String, dynamic>? ?? {};

            // 2. Extract User data from arguments
            final Map<String, dynamic> userData =
                args['user'] as Map<String, dynamic>? ?? {
                  'userId': '',
                  'name': 'Guest User',
                  'email': '',
                  'mobile': ''
                };

            // 3. Get userId explicitly
            final String userId = (args['userId'] ?? userData['userId'] ?? '').toString();

            return MaterialPageRoute(
              builder: (context) => BookingPage(
                hotel: hotelOrPg,
                user: userData,
                userId: userId,
              ),
            );

          case '/history':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final email = args['email'] ?? '';
            final userId = args['userId'] ?? '';
            return MaterialPageRoute(
              builder: (_) => BookingHistoryPage(email: email, userId: userId),
            );

          case '/profile':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final email = args['email'] ?? '';
            final userId = args['userId'] ?? '';
            return MaterialPageRoute(
              builder: (_) => ProfilePage(email: email, userId: userId),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(child: Text('Route not found')),
              ),
            );
        }
      },
      debugShowCheckedModeBanner: false,
    );
  }
}