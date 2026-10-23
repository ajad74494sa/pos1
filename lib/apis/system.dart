import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../apis/tax.dart';
import '../models/system.dart';
import '../helpers/otherHelpers.dart';
import 'api.dart';
import 'contact.dart';

class SystemApi {
  Future<void> store() async {
    // Priority 1: Essential business and user data
    await Future.wait<dynamic>([
      Business().get(),
      Permissions().get(),
      ActiveSubscription().get(),
      Location().get(),
      Tax().get(),
      Payment().get(),
    ]);
    unawaited(Helper().preloadBusinessLogo());

    // Priority 2: Large datasets (Can run in background)
    // We don't await these to finish the login faster
    _loadBackgroundData();
  }

  Future<void> _loadBackgroundData() async {
    try {
      await Future.wait<dynamic>([
        CustomerApi().get(),
        Brand().get(),
        Category().get(),
        PaymentAccounts().get(),
      ]);
    } catch (e) {
      print("Background loading error: $e");
    }
  }
}

class Brand extends Api {
  var brands;

  Future<List> get() async {
    try {
      String url = this.baseUrl + this.apiUrl + "/brand";
      var token = await System().getToken();
      var response = await http.get(
        Uri.parse(url),
        headers: this.getHeader('$token'),
      );
      brands = jsonDecode(response.body);
      var brandList = brands['data'];
      await System().insert('brand', jsonEncode(brandList));
      return brandList;
    } catch (e) {
      return [];
    }
  }
}

class Category extends Api {
  var taxonomy;

  Future<List> get() async {
    try {
      String url = this.baseUrl + this.apiUrl + "/taxonomy?type=product";
      var token = await System().getToken();
      var response = await http.get(
        Uri.parse(url),
        headers: this.getHeader('$token'),
      );
      taxonomy = jsonDecode(response.body);
      var categoryList = taxonomy['data'];

      List<Map<String, dynamic>> batchData = [];
      batchData.add({'key': 'taxonomy', 'value': jsonEncode(categoryList)});

      taxonomy['data'].forEach((element) {
        if (element['sub_categories'].isNotEmpty) {
          element['sub_categories'].forEach((value) {
            batchData.add({
              'key': 'sub_categories',
              'keyId': value['parent_id'],
              'value': jsonEncode({'id': value['id'], 'name': value['name']}),
            });
          });
        }
      });
      await System().batchInsert(batchData);
      return categoryList;
    } catch (e) {
      return [];
    }
  }
}

class Payment extends Api {
  late Map payment;

  Future<List> get() async {
    try {
      String url = this.baseUrl + this.apiUrl + "/payment-methods";
      var token = await System().getToken();
      var response = await http.get(
        Uri.parse(url),
        headers: this.getHeader('$token'),
      );
      payment = jsonDecode(response.body);
      List paymentList = [];
      payment.forEach((key, value) {
        paymentList.add({key: value});
      });
      await System().insert('payment_methods', jsonEncode(paymentList));
      return paymentList;
    } catch (e) {
      return [];
    }
  }
}

class Permissions extends Api {
  Future<void> get() async {
    try {
      String url = this.baseUrl + this.apiUrl + "/user/loggedin";
      var token = await System().getToken();
      var response = await http.get(
        Uri.parse(url),
        headers: this.getHeader(token),
      );
      var userDetails = jsonDecode(response.body);
      Map userDetailsMap = userDetails['data'];
      if (userDetailsMap.containsKey('all_permissions')) {
        var userData = jsonEncode(userDetailsMap['all_permissions']);
        await System().insert('user_permissions', userData);
      }
    } catch (e) {}
  }
}

class Location extends Api {
  var locations;

  Future<List?> get() async {
    try {
      String url = this.baseUrl + this.apiUrl + "/business-location";
      var token = await System().getToken();
      var response = await http.get(
        Uri.parse(url),
        headers: this.getHeader('$token'),
      );
      locations = jsonDecode(response.body);

      List? locationList = locations['data'];

      List<Map<String, dynamic>> batchData = [];
      batchData.add({'key': 'location', 'value': jsonEncode(locationList)});

      if (locationList != null) {
        locationList.forEach((element) {
          batchData.add({
            'key': 'payment_method',
            'keyId': element['id'],
            'value': jsonEncode(element['payment_methods']),
          });
        });
      }
      await System().batchInsert(batchData);
      return locationList;
    } catch (e) {
      return [];
    }
  }
}

class Business extends Api {
  var business;

  Future<List> get() async {
    try {
      String url = this.baseUrl + this.apiUrl + "/business-details";
      var token = await System().getToken();
      var response = await http.get(
        Uri.parse(url),
        headers: this.getHeader('$token'),
      );
      business = jsonDecode(response.body);
      List businessDetails = [business['data']];
      await System().insert('business', jsonEncode(businessDetails));

      // Auto-sync WhatsApp config from fetched business settings
      await Helper().syncWhatsAppFromBusinessSettings();

      return businessDetails;
    } catch (e) {
      return [];
    }
  }
}

class ActiveSubscription extends Api {
  var activeSubscription;

  Future<List> get() async {
    try {
      String url = this.baseUrl + this.apiUrl + "/active-subscription";
      var token = await System().getToken();
      var response = await http.get(
        Uri.parse(url),
        headers: this.getHeader('$token'),
      );
      activeSubscription = jsonDecode(response.body);
      List activeSubscriptionDetails = (activeSubscription['data'].isNotEmpty)
          ? [activeSubscription['data']]
          : [];
      System().insert(
        'active-subscription',
        jsonEncode(activeSubscriptionDetails),
      );
      return activeSubscriptionDetails;
    } catch (e) {
      return [];
    }
  }
}

class PaymentAccounts extends Api {
  Future<List> get() async {
    try {
      var accounts;
      String url = this.baseUrl + this.apiUrl + "/payment-accounts";
      var token = await System().getToken();
      var response = await http.get(
        Uri.parse(url),
        headers: this.getHeader('$token'),
      );
      accounts = jsonDecode(response.body);
      List paymentAccounts = accounts['data'];
      System().insert('payment_accounts', jsonEncode(paymentAccounts));
      return paymentAccounts;
    } catch (e) {
      return [];
    }
  }
}
