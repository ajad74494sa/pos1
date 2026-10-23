import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../apis/profit_loss_report.dart';
import '../helpers/AppTheme.dart';
import '../locale/MyLocalizations.dart';
import '../models/profit_loss_report_model.dart';

class ProfitLossReportScreen extends StatefulWidget {
  static const String routeName = '/ProfitLossReport';
  const ProfitLossReportScreen({Key? key}) : super(key: key);

  static const int themeType = 1;

  @override
  State<ProfitLossReportScreen> createState() => _ProfitLossReportScreenState();
}

class _ProfitLossReportScreenState extends State<ProfitLossReportScreen> {
  ProfitLossReportModel? profitLossReportModel;
  bool loading = true;
  List myReports = [];

  final ThemeData themeData = AppTheme.getThemeFromThemeMode(ProfitLossReportScreen.themeType);

  Future<void> _getProfitLossReport() async {
    setState(() => loading = true);
    var result = await ProfitLossReportService().getProfitLossReport();
    if (result != null && result is ProfitLossReportModel) {
      setState(() {
        profitLossReportModel = result;
        myReports = [];
        var map = result.toJson();
        map.forEach((key, value) {
          if (value != null && value.toString() != 'null') {
            myReports.add({"title": key, "data": value});
          }
        });
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    _getProfitLossReport();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xff732a13),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context).translate('profit_and_loss'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xff732a13)))
          : Column(
              children: [
                _buildSummaryHeader(),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: myReports.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildReportItem(myReports[index]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      decoration: const BoxDecoration(
        color: Color(0xff732a13),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context).translate('net_profit').toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            profitLossReportModel?.netProfit?.toStringAsFixed(2) ?? '0.00',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(Map<String, dynamic> item) {
    bool isProfit = item['title'].toString().contains('profit') || item['title'].toString().contains('recovered');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              AppLocalizations.of(context).translate(item['title']),
              style: TextStyle(fontSize: 13, color: Colors.blueGrey[700], fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            item['data'].toString(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isProfit ? Colors.green[700] : Colors.blueGrey[900],
            ),
          ),
        ],
      ),
    );
  }
}
