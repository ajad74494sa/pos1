import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:krpos/api_end_points.dart';

import 'api.dart';

class User extends Api {
  Future<Map?> get(token) async {
    try {
      String url = ApiEndPoints.getUser;
      var response =
          await http.get(Uri.parse(url), headers: this.getHeader(token));
      
      if (response.statusCode == 200) {
        var userDetails = jsonDecode(response.body);
        // Handle both cases: wrapped in 'data' or direct response
        if (userDetails is Map && userDetails.containsKey('data')) {
          return userDetails['data'];
        } else if (userDetails is Map) {
          return userDetails;
        }
      }
      print('User API Error: Status ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('User API Exception: $e');
      return null;
    }
  }

  Future<Map?> updatePassword(String token, Map body) async {
    try {
      String url = ApiEndPoints.updatePassword;
      var response = await http.post(
        Uri.parse(url),
        headers: this.getHeader(token),
        body: jsonEncode(body),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Update Password Exception: $e');
      return null;
    }
  }
}
