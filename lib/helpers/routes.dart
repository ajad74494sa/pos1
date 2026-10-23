import 'package:flutter/material.dart';
import 'package:krpos/config.dart';
import 'package:krpos/helpers/bottomNav.dart';
import 'package:krpos/pages/brands/brands.dart';
import 'package:krpos/pages/category_screen.dart';
import 'package:krpos/pages/create_order.dart';
import 'package:krpos/pages/home/home_screen.dart';
import 'package:krpos/pages/login/login_screen.dart';
import 'package:krpos/pages/notifications/notify.dart';
import 'package:krpos/pages/on_boarding/on_boarding.dart';
import 'package:krpos/pages/product_stock_report.dart';
import 'package:krpos/pages/profit_loss_report.dart';
import 'package:krpos/pages/purchases/view/purchases_screen.dart';
import 'package:krpos/pages/units.dart';

import '../pages/cart.dart';
import '../pages/checkout.dart';
import '../pages/contact_payment.dart';
import '../pages/contacts.dart';
import '../pages/customer.dart';
import '../pages/expenses.dart';
import '../pages/field_force.dart';
import '../pages/follow_up.dart';
import '../pages/products.dart';
import '../pages/edit_sale.dart';
import '../pages/report.dart';
import '../pages/sales.dart';
import '../pages/shipment.dart';
import '../pages/splash.dart';
import '../pages/printer_config.dart';
import '../pages/customer_display.dart';
import '../pages/profile.dart';

class Routes {
  static Map<String, WidgetBuilder> generateRoute() {
    final Map<String, WidgetBuilder> routeMap = {
      '/splash': (context) => Splash(),
      '/onBoarding': (context) => OnBoardingScreen(),
      '/login': (context) => LoginScreen(),
      '/home': (context) => HomeScreen(),
      '/products': (context) => Products(),
      '/edit_sale': (context) => EditSale(),
      '/layout': (context) => Layout(),
      '/Categories': (context) => CategoryScreen(),
      '/BrandsScreen': (context) => BrandsScreen(),
      '/notify': (context) => NotificationScreen(),
      '/sale': (context) => Sales(),
      '/createOrder': (context) => CreateOrderPage(),
      '/customerDisplay': (context) => CustomerDisplay(),
      // '/cart': (context) => Cart(),
      '/customer': (context) => Customer(),
      '/checkout': (context) => CheckOut(),
      '/expense': (context) => Expense(),
      '/contactPayment': (context) => ContactPayment(),
      '/shipment': (context) => Shipment(),
      '/leads': (context) => Contacts(),
      '/followUp': (context) => FollowUp(),
      '/fieldForce': (context) => FieldForce(),
      '/purchases': (context) => PurchasesScreen(),
      ReportScreen.routeName: (context) => ReportScreen(),
      ProfitLossReportScreen.routeName: (context) => ProfitLossReportScreen(),
      ProductStockReportScreen.routeName: (context) =>
          ProductStockReportScreen(),
      UnitsScreen.routeName: (context) => UnitsScreen(),
      '/printerConfig': (context) => PrinterConfigPage(),
      '/profile': (context) => UserProfile(),
    };

    return routeMap.map((key, builder) {
      // List of public routes that don't require login
      if (key == '/splash' || key == '/login' || key == '/onBoarding' || key == '/customerDisplay') {
        return MapEntry(key, builder);
      }

      // Return a wrapper that checks for authentication
      return MapEntry(key, (context) {
        if (Config.userId == null) {
          // If not logged in, show LoginScreen
          return const LoginScreen();
        }
        return builder(context);
      });
    });
  }
}
