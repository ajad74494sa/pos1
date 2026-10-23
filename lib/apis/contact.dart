import 'dart:convert';

import 'package:http/http.dart' as http;
import '../api_end_points.dart';

import '../models/contact_model.dart';
import '../models/system.dart';
import 'api.dart';

class CustomerApi extends Api {
  var customers;

  Future<void> get() async {
    String? url = ApiEndPoints.getContact;
    var token = await System().getToken();
    do {
      try {
        var response =
            await http.get(Uri.parse(url!), headers: this.getHeader('$token'));
        var decoded = jsonDecode(response.body);
        url = decoded['links']['next'];
        List<Map<String, dynamic>> contacts = [];
        for (var element in decoded['data']) {
          contacts.add(Contact().contactModel(element));
        }
        if (contacts.isNotEmpty) {
          await Contact().insertContactsBatch(contacts);
        }
      } catch (e) {
        return null;
      }
    } while (url != null);
  }

  Future<dynamic> add(Map customer) async {
    try {
      String url = ApiEndPoints.addContact;
      var body = json.encode(customer);
      var token = await System().getToken();

      var response = await http.post(Uri.parse(url),
          headers: this.getHeader('$token'), body: body);
      var result = await jsonDecode(response.body);
      // print("result");
      // print(result);
      return result;
    } catch (e) {

      // print(e);
      return null;
    }
  }

  Future<dynamic> getContactDetails(int id) async {
    try {
      String url = '${ApiEndPoints.contact}/$id';
      var token = await System().getToken();
      var response = await http.get(Uri.parse(url), headers: this.getHeader('$token'));
      return jsonDecode(response.body);
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> search(String term) async {
    try {
      String url = '${ApiEndPoints.contact}?type=customer&name=$term';
      var token = await System().getToken();
      var response = await http.get(Uri.parse(url), headers: this.getHeader('$token'));
      return jsonDecode(response.body);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getContactByCardUid(String cardUid) async {
    try {
      String url = '${ApiEndPoints.contact}?type=customer&name=$cardUid';
      var token = await System().getToken();
      var response = await http.get(Uri.parse(url), headers: this.getHeader('$token'));
      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        if (decoded != null && decoded['data'] != null && decoded['data'].isNotEmpty) {
          List dataList = decoded['data'];
          for (var element in dataList) {
            String customField = (element['custom_field1'] ?? element['nfc_card_id'] ?? '').toString().trim().toLowerCase();
            String name = (element['name'] ?? '').toString().trim().toLowerCase();
            String contactId = (element['contact_id'] ?? '').toString().trim().toLowerCase();
            String mobile = (element['mobile'] ?? '').toString().trim().toLowerCase();
            String searchCardUid = cardUid.trim().toLowerCase();

            if (customField == searchCardUid || name == searchCardUid || contactId == searchCardUid || mobile == searchCardUid) {
              Map<String, dynamic> customer = Contact().contactModel(element);
              await Contact().insertContact(customer);
              return customer;
            }
          }
          var element = dataList[0];
          Map<String, dynamic> customer = Contact().contactModel(element);
          await Contact().insertContact(customer);
          return customer;
        }
      }
    } catch (e) {
      print('Error fetching contact by Card UID from server: $e');
    }
    return null;
  }
}
