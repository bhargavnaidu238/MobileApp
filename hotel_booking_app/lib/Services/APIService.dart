import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Replace with your local backend IP and port
  static const String baseUrl = 'https://test-host-server-tamg.onrender.com;

  // ------------------ User Registration ------------------
  static Future<bool> registerUser({
    required String email,
    required String firstName,
    required String lastName,
    required String gender,
    required String mobile,
    required String address,
    required String password,
    required String consent,
  }) async {
    final url = Uri.parse('$baseUrl/register');

    final body = jsonEncode({
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'mobile': mobile,
      'address': address,
      'password': password,
      'consent': consent,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Registration error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception: $e');
      return false;
    }
  }
}