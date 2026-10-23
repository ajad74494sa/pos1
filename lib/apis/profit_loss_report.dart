import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../models/profit_loss_report_model.dart';
import '../models/system.dart';
import 'api.dart';

class ProfitLossReportService extends Api {
  Future<dynamic> getProfitLossReport({String? startDate, String? endDate, int? userId}) async {
    try {
      String url = this.baseUrl + this.apiUrl + '/profit-loss-report';
      
      List<String> params = [];
      if (startDate != null && endDate != null) {
        params.add('start_date=$startDate');
        params.add('end_date=$endDate');
      }
      if (userId != null) {
        params.add('user_id=$userId');
      }

      if (params.isNotEmpty) {
        url += '?' + params.join('&');
      }

      var token = await System().getToken();

      var response =
          await http.get(Uri.parse(url), headers: this.getHeader('$token'));

      var profitLossReport = jsonDecode(response.body);

      log(profitLossReport.runtimeType.toString());
      ProfitLossReportModel myData =
          ProfitLossReportModel.fromJson(profitLossReport['data']);

      return myData;
    } catch (e) {
      log("ERROR ${e.toString()}");
      return null;
    }
  }
}
