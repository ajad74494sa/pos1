import 'package:flutter/material.dart';
import 'package:krpos/helpers/SizeConfig.dart';
import 'package:krpos/helpers/otherHelpers.dart';
import 'package:krpos/locale/MyLocalizations.dart';
import 'package:krpos/models/profit_loss_report_model.dart';

import 'block_widget.dart';

class Statistics extends StatelessWidget {
  Statistics({
    this.businessSymbol = '',
    this.totalSales,
    this.totalSalesAmount = 0,
    this.totalReceivedAmount = 0,
    this.totalDueAmount = 0,
    required this.themeData,
    this.report,
    this.userReport,
  });

  final String businessSymbol;
  final int? totalSales;
  final double totalSalesAmount, totalReceivedAmount, totalDueAmount;
  final ThemeData themeData;
  final ProfitLossReportModel? report, userReport;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {
        'subject': 'total_sell',
        'amount': report?.totalSell ?? Helper().formatCurrency(totalSalesAmount),
        'icon': Icons.shopping_cart_outlined,
        'color': Colors.blue,
      },
      {
        'subject': 'user_sales',
        'amount': userReport?.totalSell ?? '0.00',
        'icon': Icons.person_outline,
        'color': Colors.purple,
      },
      {
        'subject': 'net',
        'amount': report?.netProfit?.toString() ?? Helper().formatCurrency(totalReceivedAmount),
        'icon': Icons.account_balance_wallet_outlined,
        'color': Colors.green,
      },
      {
        'subject': 'invoice_due',
        'amount': Helper().formatCurrency(totalDueAmount),
        'icon': Icons.description_outlined,
        'color': Colors.orange,
      },
      {
        'subject': 'total_sell_return',
        'amount': report?.totalSellReturn ?? '0.00',
        'icon': Icons.swap_horiz,
        'color': Colors.red,
      },
      {
        'subject': 'total_purchase',
        'amount': report?.totalPurchase ?? '0.00',
        'icon': Icons.file_download_outlined,
        'color': Colors.lightBlue,
      },
      {
        'subject': 'purchase_due',
        'amount': '0.00', // Still need a way to get this or keep it mock
        'icon': Icons.warning_amber_rounded,
        'color': Colors.amber,
      },
      {
        'subject': 'total_purchase_return',
        'amount': report?.totalPurchaseReturn ?? '0.00',
        'icon': Icons.assignment_return_outlined,
        'color': Colors.pink,
      },
      {
        'subject': 'expense',
        'amount': report?.totalExpense?.toString() ?? '0.00',
        'icon': Icons.money_off,
        'color': Colors.redAccent,
      },
    ];

    return Container(
      color: Color(0xff732a13), // Match the header background
      child: Container(
        decoration: BoxDecoration(
          color: themeData.scaffoldBackgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive grid columns based on width
            int crossAxisCount = 2; // Default for phones
            double aspectRatio = 1.8;

            if (constraints.maxWidth > 1200) {
              crossAxisCount = 6; // Desktop
              aspectRatio = 2.2;
            } else if (constraints.maxWidth > 800) {
              crossAxisCount = 4; // Tablet
              aspectRatio = 2.0;
            } else if (constraints.maxWidth > 500) {
              crossAxisCount = 3; // Large phones/Small tablets
              aspectRatio = 1.9;
            }

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: aspectRatio,
              ),
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              // itemCount: 2,
              itemCount: items.length,
              padding: EdgeInsets.all(MySize.size10!),
              itemBuilder: (context, index) {
                final item = items[index];
                return Block(
                  themeData: themeData,
                  icon: item['icon'],
                  iconColor: item['color'],
                  backgroundColor: item['color'], // Using the same color for background
                  subject: AppLocalizations.of(context).translate(item['subject']),
                  amount: (item['amount'].toString().startsWith(businessSymbol)) 
                    ? item['amount'].toString() 
                    : '$businessSymbol ${item['amount']}',
                );
              },
            );
          },
        ),
      ),
    );
  }
}
