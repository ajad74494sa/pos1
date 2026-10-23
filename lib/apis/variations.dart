import 'dart:convert';

import 'package:http/http.dart' as http;

import '../apis/api.dart';
import '../models/system.dart';

class VariationsApi extends Api {
//get variation list from api
  Future<Map<String, dynamic>> get(String link) async {
    var variations;
    String url = link;
    String token = await System().getToken();
    var response =
        await http.get(Uri.parse(url), headers: this.getHeader(token));
    
    if (response.statusCode != 200) {
      return {"nextLink": null, "products": []};
    }

    variations = jsonDecode(response.body);
    List variationList = [];
    if (variations != null && variations['data'] != null) {
      variations['data'].forEach((value) {
        variationList.add(value);
      });
    }
    
    Map<String, dynamic> apiResponse = {
      "nextLink": (variations != null && variations['links'] != null) ? variations['links']['next'] : null,
      "products": variationList
    };
    return apiResponse;
  }
}
