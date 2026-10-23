import 'package:flutter/material.dart';
import 'package:krpos/helpers/AppTheme.dart';
import 'package:krpos/pages/product_stock_report.dart';
import 'package:krpos/pages/profit_loss_report.dart';

import '../locale/MyLocalizations.dart';

class ReportScreen extends StatelessWidget {
  static const String routeName = '/ReportScreen';
  const ReportScreen({super.key});

  static const int themeType = 1;

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xff732a13),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context).translate('reports'),
          style: AppTheme.getTextStyle(
            themeData.textTheme.titleLarge,
            fontWeight: 700,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(20),
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              children: [
                _buildReportCard(
                  context,
                  title: 'profit_and_loss',
                  icon: Icons.trending_up_rounded,
                  color: Colors.green,
                  onTap: () => Navigator.pushNamed(
                    context,
                    ProfitLossReportScreen.routeName,
                  ),
                ),
                _buildReportCard(
                  context,
                  title: 'products_stock',
                  icon: Icons.inventory_2_outlined,
                  color: Colors.blue,
                  onTap: () => Navigator.pushNamed(
                    context,
                    ProductStockReportScreen.routeName,
                  ),
                ),
                // Placeholders for future reports to make the UI look complete
                _buildReportCard(
                  context,
                  title: 'Sales Report',
                  icon: Icons.bar_chart_rounded,
                  color: Colors.orange,
                  isPlaceholder: true,
                  onTap: () {},
                ),
                _buildReportCard(
                  context,
                  title: 'Expense Report',
                  icon: Icons.money_off_rounded,
                  color: Colors.red,
                  isPlaceholder: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 40),
      decoration: const BoxDecoration(
        color: Color(0xff732a13),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Insights',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track your business performance and inventory',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPlaceholder = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                isPlaceholder ? title : AppLocalizations.of(context).translate(title),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800],
                ),
              ),
            ),
            if (isPlaceholder)
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
