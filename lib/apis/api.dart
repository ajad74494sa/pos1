import 'dart:convert' as convert;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api_end_points.dart';
import '../config.dart';

class Api {
  String baseUrl = Config.baseUrl,
      apiUrl = ApiEndPoints.apiUrl,
      clientId = Config().clientId,
      clientSecret = Config().clientSecret;

  //validate the login details
  Future<Map?> login(String username, String password) async {
    String url = ApiEndPoints.loginUrl;

    // Use a strict Map<String, String> for urlencoded body
    Map<String, String> body = {
      'grant_type': 'password',
      'client_id': clientId.toString(),
      'client_secret': clientSecret,
      'username': username,
      'password': password,
    };

    try {
      debugPrint("Attempting Login: $url");
      debugPrint("Login Body: $body");

      var response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      debugPrint("Login Status Code: ${response.statusCode}");
      debugPrint("Login Response Body: ${response.body}");

      var jsonResponse = convert.jsonDecode(response.body);

      if (response.statusCode == 200) {
        //logged in successfully
        return {'success': true, 'access_token': jsonResponse['access_token']};
      } else {
        // Return the error from server if exists, else generic error
        String errorMsg = jsonResponse['message'] ?? jsonResponse['error'] ?? 'Authentication Failed';
        return {'success': false, 'error': errorMsg};
      }
    } catch (e) {
      debugPrint("Login Exception: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  getHeader(String token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Requested-With': 'XMLHttpRequest'
    };
  }
}
