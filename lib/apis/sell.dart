import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_end_points.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import 'api.dart';

class SellApi extends Api {
  //create a sell in api
  Future<Map<String, dynamic>?> create(data) async {
    String url = this.baseUrl + this.apiUrl + "/sell";
    var token = await System().getToken();

    String body = jsonEncode(data);
    
    try {
      var response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );


      if (response.statusCode != 200 && response.statusCode != 201) {
        print('SellApi.create failed: ${response.statusCode} - ${response.body}');
        return null;
      }

      var info = jsonDecode(response.body);
      print('SellApi.create response body: $info');
      
      Map<String, dynamic>? first;
      if (info is List && info.isNotEmpty) {
        var firstItem = info[0];
        // Handle wrapped Laravel response objects
        if (firstItem is Map && firstItem.containsKey('original')) {
          var original = firstItem['original'];
          if (original is Map) {
             if (original.containsKey('error')) {
                return null;
             }
             first = Map<String, dynamic>.from(original);
          }
        } else if (firstItem is Map) {
          first = Map<String, dynamic>.from(firstItem);
        }
      } else if (info is Map) {
        if (info.containsKey('data') &&
            info['data'] is List &&
            info['data'].isNotEmpty) {
          first = Map<String, dynamic>.from(info['data'][0]);
        } else {
          first = Map<String, dynamic>.from(info);
        }
      }

      if (first == null) return null;

      if (first.containsKey('error') || first.containsKey('msg')) {
        print('SellApi.create server error: ${first['error'] ?? first['msg']}');
      }

      var result;
      if (first.containsKey('payment_lines')) {
        result = {
          'transaction_id': first['id'],
          'payment_lines': first['payment_lines'],
          'invoice_url': first['invoice_url']
        };
      } else if (first.containsKey('is_quotation') ||
          first.containsKey('invoice_url')) {
        result = {
          'transaction_id': first['id'],
          'invoice_url': first['invoice_url']
        };
      } else if (first.containsKey('id')) {
        result = {
          'transaction_id': first['id'],
          'invoice_url': first['invoice_url']
        };
      } else {
        result = null;
      }

      return result;
    } catch (e) {
      print('SellApi.create exception: $e');
      return null;
    }
  }

  //update a sell in api
  Future<Map<String, dynamic>> update(transactionId, data) async {
    String url = this.baseUrl + this.apiUrl + "/sell/$transactionId?_method=PUT";
    var token = await System().getToken();

    
    try {
      var response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: jsonEncode(data),
      );
      
      print('SellApi.update response: ${response.statusCode} - ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        return {
          'error': 'Server returned ${response.statusCode}',
          'body': response.body
        };
      }
      
      var sellResponse = jsonDecode(response.body);
      if (sellResponse is List && sellResponse.isNotEmpty) {
        sellResponse = sellResponse[0];
        if (sellResponse is Map && sellResponse.containsKey('original')) {
          sellResponse = sellResponse['original'];
        }
      }

      return {
        'payment_lines': sellResponse['payment_lines'],
        'invoice_url': sellResponse['invoice_url']
      };
    } catch (e) {
      print('SellApi.update exception: $e');
      rethrow;
    }
  }

  //delete sell
  delete(transactionId) async {
    String url = this.baseUrl + this.apiUrl + "/sell/$transactionId";
    var token = await System().getToken();
    
    try {
      var response = await http.delete(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('SellApi.delete exception: $e');
      return null;
    }
  }

  //get specified sell
  getSpecifiedSells(List transactionIds) async {
    String ids = transactionIds.join(",");
    String url = this.baseUrl + this.apiUrl + "/sell/$ids";
    var token = await System().getToken();
    
    try {
      var value = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      var response = [];
      var body = jsonDecode(value.body);
      
      if (body is Map && body.containsKey('data')) {
        response = body['data'];
        var responseTransactionIds = [];
        response.forEach((element) {
          responseTransactionIds.add(element['id']);
        });
        transactionIds.forEach((id) async {
          if (!responseTransactionIds.contains(id)) {
            await SellDatabase().getSellByTransactionId(id).then((val) {
              if (val.isNotEmpty) {
                SellDatabase().deleteSell(val[0]['id']);
              }
            });
          }
        });
      }
      return response;
    } catch (e) {
      print('SellApi.getSpecifiedSells exception: $e');
      return [];
    }
  }

  Future<String?> getLatestOnlineInvoiceNumber(int locationId) async {
    String url = this.baseUrl + this.apiUrl + "/sell?location_id=$locationId&per_page=1&order_by_date=desc";
    var token = await System().getToken();

    try {
      var response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        var body = jsonDecode(response.body);
        if (body is Map && body.containsKey('data')) {
          List data = body['data'];
          if (data.isNotEmpty) {
            return data[0]['invoice_no'];
          }
        }
      }
    } catch (e) {
      print('SellApi.getLatestOnlineInvoiceNumber exception: $e');
    }
    return null;
  }

  Future<bool> postSellPayment(Map<String, dynamic> paymentData) async {
    String url = ApiEndPoints.addSellPayment;
    var token = await System().getToken();

    try {
      var response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(paymentData),
      );

      print('SellApi.postSellPayment response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('SellApi.postSellPayment exception: $e');
      return false;
    }
  }
}
