import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:krpos/apis/profit_loss_report.dart';
import 'package:krpos/models/profit_loss_report_model.dart';
import 'package:krpos/pages/home/widgets/greeting_widget.dart';
import 'package:krpos/pages/home/widgets/sales_chart.dart';
import 'package:krpos/pages/home/widgets/statistics_widget.dart';
import 'package:krpos/pages/notifications/view_model_manger/notifications_cubit.dart';
import 'package:krpos/pages/report.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/futuristic_loader.dart';
import '../helpers/icons.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/attendance.dart';
import '../models/database.dart';
import '../models/paymentDatabase.dart';
import '../models/sell.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import '../models/variations.dart';
import '../services/connectivity_service.dart';
import '../widgets/windows_menu.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  var user,
      note = new TextEditingController(),
      clockInTime = DateTime.now(),
      selectedLanguage;
  LatLng? currentLoc;

  String businessSymbol = '',
      businessLogo = '',
      defaultImage = 'assets/images/default_product.png',
      businessName = '',
      userName = '';

  ProfitLossReportModel? profitLossReport, userReport;
  List<FlSpot> chartSpots = [];
  List<String> chartLabels = [];
  DateTimeRange? selectedDateRange;

  double totalSalesAmount = 0.00,
      totalReceivedAmount = 0.00,
      totalDueAmount = 0.00,
      byCash = 0.00,
      byCard = 0.00,
      byCheque = 0.00,
      byBankTransfer = 0.00,
      byOther = 0.00,
      byCustomPayment_1 = 0.00,
      byCustomPayment_2 = 0.00,
      byCustomPayment_3 = 0.00;

  bool accessExpenses = false,
      attendancePermission = false,
      notPermitted = false,
      syncPressed = false,
      isAdmin = true;
  bool? checkedIn;

  // List sells;
  Map<String, dynamic>? paymentMethods;
  int? totalSales;
  List<Map> method = [], payments = [];

  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  @override
  void initState() {
    super.initState();
    // Set default date range to Today
    DateTime now = DateTime.now();
    selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day),
    );
    getPermission();
    homepageData();
    fetchReport();
    Helper().syncCallLogs();
  }

  fetchReport() async {
    if (await Helper().checkConnectivity()) {
      String? start, end;
      if (selectedDateRange != null) {
        start = DateFormat('yyyy-MM-dd').format(selectedDateRange!.start);
        end = DateFormat('yyyy-MM-dd').format(selectedDateRange!.end);
      }

      // Fetch global report
      ProfitLossReportService()
          .getProfitLossReport(startDate: start, endDate: end)
          .then((value) {
            if (value is ProfitLossReportModel) {
              setState(() {
                profitLossReport = value;
              });
            }
          });

      // Fetch current user report
      if (Config.userId != null) {
        ProfitLossReportService()
            .getProfitLossReport(startDate: start, endDate: end, userId: Config.userId)
            .then((value) {
              if (value is ProfitLossReportModel) {
                setState(() {
                  userReport = value;
                });
              }
            });
      }
    }
  }

  void onFilterSelected(String choice) async {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTimeRange? range;

    switch (choice) {
      case 'Today':
        range = DateTimeRange(start: today, end: today);
        break;
      case 'Yesterday':
        DateTime yesterday = today.subtract(Duration(days: 1));
        range = DateTimeRange(start: yesterday, end: yesterday);
        break;
      case 'Last 7 Days':
        range = DateTimeRange(
          start: today.subtract(Duration(days: 6)),
          end: today,
        );
        break;
      case 'Last 30 Days':
        range = DateTimeRange(
          start: today.subtract(Duration(days: 29)),
          end: today,
        );
        break;
      case 'This Month':
        range = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: today,
        );
        break;
      case 'Last Month':
        DateTime firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
        DateTime lastDayLastMonth = DateTime(now.year, now.month, 0);
        range = DateTimeRange(start: firstDayLastMonth, end: lastDayLastMonth);
        break;
      case 'This month last year':
        range = DateTimeRange(
          start: DateTime(now.year - 1, now.month, 1),
          end: DateTime(now.year - 1, now.month + 1, 0),
        );
        break;
      case 'This Year':
        range = DateTimeRange(start: DateTime(now.year, 1, 1), end: today);
        break;
      case 'Last Year':
        range = DateTimeRange(
          start: DateTime(now.year - 1, 1, 1),
          end: DateTime(now.year - 1, 12, 31),
        );
        break;
      case 'Current financial year':
        int startYear = now.month >= 4 ? now.year : now.year - 1;
        range = DateTimeRange(start: DateTime(startYear, 4, 1), end: today);
        break;
      case 'Last financial year':
        int startYear = now.month >= 4 ? now.year - 1 : now.year - 2;
        range = DateTimeRange(
          start: DateTime(startYear, 4, 1),
          end: DateTime(startYear + 1, 3, 31),
        );
        break;
      case 'Custom Range':
        range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(Duration(days: 365)),
          initialDateRange: selectedDateRange,
          builder: (context, child) {
            return Theme(
              data: themeData.copyWith(
                colorScheme: themeData.colorScheme.copyWith(
                  primary: Color(0xff732a13),
                  onPrimary: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        break;
    }

    if (range != null) {
      setState(() {
        selectedDateRange = range;
        profitLossReport = null; // Clear old report to show fallback/loading
        // Reset local statistics immediately to reflect change in UI
        totalSalesAmount = 0.0;
        totalReceivedAmount = 0.0;
        totalDueAmount = 0.0;
        totalSales = 0;
      });
      fetchReport();
      loadStatistics();
    }
  }

  //function to set homepage details
  homepageData() async {
    var prefs = await SharedPreferences.getInstance();
    user = await System().get('loggedInUser');
    if (user is Map && user.isNotEmpty) {
      userName =
          ((user['surname'] != null) ? user['surname'] : "") +
          ' ' +
          user['first_name'];
    } else {
      userName = "User";
    }
    await loadPaymentDetails();
    await Helper().getFormattedBusinessDetails().then((value) {
      businessSymbol = value['symbol'];
      businessLogo = value['logo'] ?? Config().defaultBusinessImage;
      businessName = value['name'];
      Config.quantityPrecision = value['quantityPrecision'] ?? 2;
      Config.currencyPrecision = value['currencyPrecision'] ?? 2;
    });
    selectedLanguage =
        prefs.getString('language_code') ?? Config().defaultLanguage;
    loadChartDataFromApi();
    setState(() {});
  }

  loadChartDataFromApi() async {
    if (!(await Helper().checkConnectivity())) return;

    DateTime now = DateTime.now();
    List<Future<dynamic>> requests = [];
    List<String> labels = [];

    for (int i = 11; i >= 0; i--) {
      DateTime monthStart = DateTime(now.year, now.month - i, 1);
      DateTime monthEnd = DateTime(now.year, now.month - i + 1, 0);

      String start = DateFormat('yyyy-MM-dd').format(monthStart);
      String end = DateFormat('yyyy-MM-dd').format(monthEnd);

      labels.add(DateFormat('MMM').format(monthStart));
      requests.add(ProfitLossReportService()
          .getProfitLossReport(startDate: start, endDate: end));
    }

    try {
      var results = await Future.wait(requests);
      List<FlSpot> newSpots = [];

      for (int i = 0; i < results.length; i++) {
        double sales = 0.0;
        if (results[i] is ProfitLossReportModel) {
          sales = double.tryParse(results[i].totalSell ?? '0') ?? 0.0;
        }
        newSpots.add(FlSpot(i.toDouble(), sales));
      }

      if (mounted) {
        setState(() {
          chartSpots = newSpots;
          chartLabels = labels;
        });
      }
    } catch (e) {
      print('Error fetching yearly chart data: $e');
    }
  }

  //permission for displaying Attendance Button
  checkIOButtonDisplay() async {
    await Attendance().getCheckInTime(Config.userId).then((value) {
      if (value != null) {
        clockInTime = DateTime.parse(value);
      }
    });
    //if someone has forget to check-in
    //check attendance status
    var activeSubscriptionDetails = await System().get('active-subscription');
    if (activeSubscriptionDetails.length > 0 &&
        activeSubscriptionDetails[0].containsKey('package_details')) {
      Map<String, dynamic> packageDetails =
          activeSubscriptionDetails[0]['package_details'];
      if (packageDetails.containsKey('essentials_module') &&
          packageDetails['essentials_module'].toString() == '1') {
        //get attendance status(check-In/check-Out)
        checkedIn = await Attendance().getAttendanceStatus(Config.userId);
        setState(() {});
      } else {
        setState(() {
          checkedIn = null;
        });
      }
    } else {
      setState(() {
        checkedIn = null;
      });
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    MySize().init(context);
    themeData = Theme.of(context);
    return Scaffold(
      key: _scaffoldKey,
      drawer: WindowsMenu(
        accessExpenses: accessExpenses,
        isAdmin: isAdmin,
        userName: userName,
      ),
      backgroundColor: themeData.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xff732a13), // Brown color from screenshot
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu, color: Colors.white),
        ),
        title: Text(
          AppLocalizations.of(context).translate('home'),
          style: AppTheme.getTextStyle(
            themeData.textTheme.titleLarge,
            fontWeight: 700,
            color: Colors.white,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: <Widget>[
          Consumer<ConnectivityService>(
            builder: (context, connectivity, child) {
              if (connectivity.lowInternetMode) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange, width: 0.5),
                    ),
                    child: const Text(
                      "LOW INTERNET",
                      style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }
              return IconButton(
                onPressed: connectivity.isSyncing
                    ? null
                    : () async {
                        if (connectivity.isOnline) {
                          await sync();
                        } else {
                          Helper().showNotification(
                            context,
                            AppLocalizations.of(
                              context,
                            ).translate('check_connectivity'),
                            isError: true,
                          );
                        }
                      },
                icon: connectivity.isSyncing
                    ? FuturisticLoader(
                        size: 20,
                        title: '',
                        subTitle: '',
                        showGrid: false,
                      )
                    : Icon(
                        Symbols.sync,
                        color: connectivity.isOnline ? Colors.white : Colors.white54,
                      ),
              );
            },
          ),
          IconButton(
            onPressed: () async {
              List unsyncedSells = await SellDatabase().getNotSyncedSells();
              if (unsyncedSells.isNotEmpty) {
                Helper().showNotification(
                  context,
                  AppLocalizations.of(context).translate('sync_all_sales_before_logout'),
                  isError: true,
                );
                return;
              }
              SharedPreferences prefs = await SharedPreferences.getInstance();
              prefs.setInt('prevUserId', Config.userId!);
              prefs.remove('userId');
              Config.userId = null; // Clear session data
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: Icon(Icons.logout, color: Colors.red),
          ),
        ],
      ),
      body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  GreetingWidget(
                    themeData: themeData,
                    userName: userName,
                    onFilterSelected: onFilterSelected,
                    selectedRangeText: selectedDateRange == null
                        ? 'Filter by date'
                        : '${DateFormat('MMM d').format(selectedDateRange!.start)} - ${DateFormat('MMM d').format(selectedDateRange!.end)}',
                  ),
                  Statistics(
                    themeData: themeData,
                    businessSymbol: businessSymbol,
                    totalDueAmount: totalDueAmount,
                    totalReceivedAmount: totalReceivedAmount,
                    totalSales: totalSales,
                    totalSalesAmount: totalSalesAmount,
                    report: profitLossReport,
                    userReport: userReport,
                  ),
                  SalesChart(
                    themeData: themeData,
                    spots: chartSpots,
                    xLabels: chartLabels,
                  ),
                  SizedBox(height: 20),
                  // Navigation shortcuts
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildShortcut(
                          context,
                          label: 'expenses',
                          icon: Icons.money_off,
                          onTap: () async {
                            if (await Helper().checkConnectivity()) {
                              Navigator.pushNamed(context, '/expense');
                            }
                          },
                        ),
                        _buildShortcut(
                          context,
                          label: 'reports',
                          icon: Icons.bar_chart,
                          onTap: () =>
                              Navigator.pushNamed(context, ReportScreen.routeName),
                        ),
                        _buildShortcut(
                          context,
                          label: 'printer',
                          icon: Icons.print_outlined,
                          onTap: () =>
                              Navigator.pushNamed(context, '/printerConfig'),
                        ),
                        _buildShortcut(
                          context,
                          label: 'settings',
                          icon: Icons.settings_outlined,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  paymentDetails(),
                ],
              ),
            ),
    );
  }

  Widget _buildShortcut(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: (MediaQuery.of(context).size.width - 64) / 4,
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xff732a13).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Color(0xff732a13), size: 20),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                AppLocalizations.of(context).translate(label),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //homepage drawer
  Widget homePageDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: <Widget>[
            Container(height: MySize.scaleFactorHeight! * 70),
            Expanded(
              flex: 9,
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: <Widget>[
                  ListTile(
                    leading: Icon(
                      Icons.person_outline,
                      color: themeData.colorScheme.onSurface,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/profile');
                    },
                    title: Text(
                      AppLocalizations.of(context).translate('profile') ?? 'Profile',
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.language,
                      color: themeData.colorScheme.onSurface,
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Close'),
                            ),
                          ],
                          title: Text(
                            AppLocalizations.of(context).translate('language'),
                          ),
                          content: changeAppLanguage(),
                        ),
                      );
                    },
                    title: Text(
                      AppLocalizations.of(context).translate('language'),
                    ),
                  ),
                  Visibility(
                    visible: accessExpenses,
                    child: ListTile(
                      leading: Image.asset(
                        'assets/images/money.png',
                        color: Color(0xff42855B),
                        width: 30,
                      ),
                      onTap: () async {
                        if (await Helper().checkConnectivity()) {
                          Navigator.pushNamed(context, '/expense');
                        } else {
                          Helper().showNotification(
                            context,
                            AppLocalizations.of(
                              context,
                            ).translate('check_connectivity'),
                            isError: true,
                          );
                        }
                      },
                      title: Text(
                        AppLocalizations.of(context).translate('expenses'),
                        style: AppTheme.getTextStyle(
                          themeData.textTheme.titleSmall,
                          fontWeight: 600,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/payed_money.png',
                      color: Color(0xff820000),
                      width: 30,
                    ),
                    title: Text(
                      AppLocalizations.of(context).translate('contact_payment'),
                      style: AppTheme.getTextStyle(
                        themeData.textTheme.titleSmall,
                        fontWeight: 600,
                      ),
                    ),
                    onTap: () async {
                      if (await Helper().checkConnectivity()) {
                        Navigator.pushNamed(context, '/contactPayment');
                      } else {
                        Helper().showNotification(
                          context,
                          AppLocalizations.of(
                            context,
                          ).translate('check_connectivity'),
                          isError: true,
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/support.png',
                      color: Color(0xff301E67),
                      width: 30,
                    ),
                    title: Text(
                      AppLocalizations.of(context).translate('follow_ups'),
                      style: AppTheme.getTextStyle(
                        themeData.textTheme.titleSmall,
                        fontWeight: 600,
                      ),
                    ),
                    onTap: () async {
                      if (await Helper().checkConnectivity()) {
                        Navigator.pushNamed(context, '/followUp');
                        // await CallLog.get().then((value) =>
                        //     Navigator.push(context, '/followUp'));
                      } else {
                        Helper().showNotification(
                          context,
                          AppLocalizations.of(
                            context,
                          ).translate('check_connectivity'),
                          isError: true,
                        );
                      }
                    },
                  ),
                  Visibility(
                    visible: Config().showFieldForce,
                    child: ListTile(
                      leading: Icon(
                        Symbols.male,
                        color: themeData.colorScheme.onSurface,
                      ),
                      onTap: () async {
                        if (await Helper().checkConnectivity()) {
                          Navigator.pushNamed(context, '/fieldForce');
                        } else {
                          Helper().showNotification(
                            context,
                            AppLocalizations.of(
                              context,
                            ).translate('check_connectivity'),
                            isError: true,
                          );
                        }
                      },
                      title: Text(
                        AppLocalizations.of(
                          context,
                        ).translate('field_force_visits'),
                        style: AppTheme.getTextStyle(
                          themeData.textTheme.titleSmall,
                          fontWeight: 600,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/contact.png',
                      color: Color(0xff0064e5),
                      width: 30,
                    ),
                    title: Text(
                      AppLocalizations.of(context).translate('contacts'),
                      style: AppTheme.getTextStyle(
                        themeData.textTheme.titleSmall,
                        fontWeight: 600,
                      ),
                    ),
                    onTap: () async {
                      if (await Helper().checkConnectivity()) {
                        Navigator.pushNamed(context, '/leads');
                        // await CallLog.get().then(
                        //         (value) =>
                        //         Navigator.push(context, '/leads'));
                      } else {
                        Helper().showNotification(
                          context,
                          AppLocalizations.of(
                            context,
                          ).translate('check_connectivity'),
                          isError: true,
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/delivery.png',
                      color: Color(0xffF2921D),
                      width: 30,
                    ),
                    title: Text(
                      AppLocalizations.of(context).translate('shipment'),
                      style: AppTheme.getTextStyle(
                        themeData.textTheme.titleSmall,
                        fontWeight: 600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/shipment');
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.print,
                      color: themeData.colorScheme.onSurface,
                    ),
                    title: Text(
                      AppLocalizations.of(
                        context,
                      ).translate('printer_configuration'),
                      style: AppTheme.getTextStyle(
                        themeData.textTheme.titleSmall,
                        fontWeight: 600,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, '/printerConfig');
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    // title: Text(
                    //   'Clear Local Data',
                    //   style: AppTheme.getTextStyle(
                    //     themeData.textTheme.titleSmall,
                    //     fontWeight: 600,
                    //     color: Colors.red,
                    //   ),
                    // ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Clear All Local Data?'),
                          content: Text(
                              'This will delete all unsynced sales and local settings. This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await DbProvider().clearDatabase();
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                
                                // Selective clear: Keep printer and business settings
                                final keysToKeep = [
                                  'customer_printer',
                                  'kitchen_printer',
                                  'print_customer_copy',
                                  'print_kitchen_copy',
                                  'is_printing_enabled',
                                  'use_separate_kitchen_printer',
                                  'prompt_before_printing',
                                  'arb_id',
                                  'arb_password',
                                  'arb_resource_key',
                                  'arb_is_live',
                                  'whatsapp_base_url',
                                  'whatsapp_api_key',
                                  'whatsapp_session_id',
                                  'language_code'
                                ];

                                Map<String, dynamic> backups = {};
                                for (String key in keysToKeep) {
                                  if (prefs.containsKey(key)) {
                                    backups[key] = prefs.get(key);
                                  }
                                }

                                await prefs.clear();

                                // Restore important settings
                                for (var entry in backups.entries) {
                                  if (entry.value is String) await prefs.setString(entry.key, entry.value);
                                  else if (entry.value is bool) await prefs.setBool(entry.key, entry.value);
                                  else if (entry.value is int) await prefs.setInt(entry.key, entry.value);
                                  else if (entry.value is double) await prefs.setDouble(entry.key, entry.value);
                                }

                                Navigator.pushNamedAndRemoveUntil(
                                    context, '/login', (route) => false);
                              },
                              child: Text(
                                'Clear Everything',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.logout,
                      color: Colors.red,
                    ),
                    title: Text(
                      AppLocalizations.of(context).translate('logout'),
                      style: AppTheme.getTextStyle(
                        themeData.textTheme.titleSmall,
                        fontWeight: 600,
                        color: Colors.red,
                      ),
                    ),
                    onTap: () async {
                      List unsyncedSells = await SellDatabase().getNotSyncedSells();
                      if (unsyncedSells.isNotEmpty) {
                        Helper().showNotification(
                          context,
                          AppLocalizations.of(context).translate('sync_all_sales_before_logout'),
                          isError: true,
                        );
                        return;
                      }
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      prefs.setInt('prevUserId', Config.userId!);
                      prefs.remove('userId');
                      Config.userId = null; // Clear session data
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                  /*ListTile(
                    leading: Image.asset(
                      'assets/images/money.png',
                      color: Color(0xff42855B),
                      width: 30,
                    ),
                    onTap: () async {
                      if (await Helper().checkConnectivity()) {
                        Navigator.pushNamed(context, '/purchases');
                      } else {
                        Helper().showNotification(
                            context,
                            AppLocalizations.of(context)
                                .translate('check_connectivity'),
                            isError: true);
                      }
                    },
                    title: Text(
                      AppLocalizations.of(context).translate('purchases'),
                      style: AppTheme.getTextStyle(
                          themeData.textTheme.titleSmall,
                          fontWeight: 600),
                    ),
                  )*/
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                alignment: Alignment.bottomCenter,
                margin: EdgeInsets.all(10),
                child: Text(AppLocalizations.of(context).translate('version')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //multi language option
  Widget changeAppLanguage() {
    var appLanguage = Provider.of<AppLanguage>(context);
    return Container(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: themeData.colorScheme.onPrimary,
          onChanged: (String? newValue) {
            appLanguage.changeLanguage(Locale(newValue!), newValue);
            selectedLanguage = newValue;
            Navigator.pop(context);
          },
          value: selectedLanguage,
          items: Config().lang.map<DropdownMenuItem<String>>((Map locale) {
            return DropdownMenuItem<String>(
              value: locale['languageCode'],
              child: Text(
                locale['name'],
                style: AppTheme.getTextStyle(
                  themeData.textTheme.titleSmall,
                  fontWeight: 600,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  sync() async {
    if (!syncPressed) {
      setState(() {
        syncPressed = true;
      });
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return PopScope(
            canPop: false,
            child: Helper().loadingIndicator(
              context,
              subTitle: 'SYNCING...',
              showBackground: true, // Show the dark background and grid
            ),
          );
        },
      );
      await Sell().createApiSell(syncAll: true).then((value) async {
        await Variations().refresh().then((value) {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          setState(() {
            syncPressed = false;
          });
        });
      });
    }
  }

  //widget for payment details
  Widget paymentDetails() {
    if (method.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: Color(0xff732a13),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).translate('payment_details'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 115,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 12),
            itemCount: method.length,
            itemBuilder: (context, index) {
              final item = method[index];
              final String label = item['key'].toString();
              final String labelLower = label.toLowerCase();
              
              IconData icon = Icons.payments_outlined;
              Color color = Colors.blue;

              if (labelLower.contains('cash')) {
                icon = Icons.account_balance_wallet_outlined;
                color = Colors.green;
              } else if (labelLower.contains('card')) {
                icon = Icons.credit_card_outlined;
                color = Colors.indigo;
              } else if (labelLower.contains('cheque')) {
                icon = Icons.description_outlined;
                color = Colors.orange;
              } else if (labelLower.contains('bank')) {
                icon = Icons.account_balance_outlined;
                color = Colors.teal;
              } else if (labelLower.contains('other')) {
                icon = Icons.more_horiz_outlined;
                color = Colors.blueGrey;
              }

              return Container(
                width: 145,
                margin: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.08),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: color.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        Icon(Icons.trending_up, size: 14, color: Colors.green.withOpacity(0.5)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$businessSymbol ' + Helper().formatCurrency(item['value']),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  //get permission
  getPermission() async {
    List<PermissionStatus> status = [
      await Permission.location.status,
      await Permission.storage.status,
      await Permission.camera.status,
      // await Permission.phone.status,
    ];
    notPermitted = status.contains(PermissionStatus.denied);
    await Helper()
        .getPermission('essentials.allow_users_for_attendance_from_api')
        .then((value) {
          if (value == true) {
            checkIOButtonDisplay();
            setState(() {
              attendancePermission = true;
            });
          } else {
            setState(() {
              checkedIn = null;
            });
          }
        });

    if (await Helper().getPermission('all_expense.access') ||
        await Helper().getPermission('view_own_expense')) {
      setState(() {
        accessExpenses = true;
      });
    }

    isAdmin = await Helper().getPermission('all');
    setState(() {});
  }

  //checkIn and checkOut button

  //load statistics
  Future<List> loadStatistics() async {
    List result = await SellDatabase().getSells();

    // Reset totals
    double newTotalSalesAmount = 0.00;
    double newTotalReceivedAmount = 0.00;
    double newTotalDueAmount = 0.00;
    int filteredSalesCount = 0;
    payments.clear();

    // Calculate chart spots for last 12 months
    Map<int, double> monthlySales = {};
    DateTime now = DateTime.now();

    List<String> labels = [];
    for (int i = 11; i >= 0; i--) {
      DateTime d = DateTime(now.year, now.month - i, 1);
      labels.add(DateFormat('MMM').format(d));
      monthlySales[11 - i] = 0.0;
    }

    for (var sell in result) {
      DateTime? date;
      if (sell['transaction_date'] != null) {
        try {
          date = DateTime.parse(sell['transaction_date']);
        } catch (e) {}
      }

      // Filter for statistics
      bool inRange = true;
      if (selectedDateRange != null && date != null) {
        // Normalize date to compare only date parts or handle time correctly
        // selectedDateRange!.start and end are usually at 00:00:00
        if (date.isBefore(selectedDateRange!.start)) {
          inRange = false;
        }

        // End date should be inclusive of the entire day
        DateTime endOfDay = DateTime(
          selectedDateRange!.end.year,
          selectedDateRange!.end.month,
          selectedDateRange!.end.day,
          23,
          59,
          59,
          999,
        );
        if (date.isAfter(endOfDay)) {
          inRange = false;
        }
      }

      // Chart logic - last 12 months
      if (date != null) {
        int monthsAgo = (now.year - date.year) * 12 + (now.month - date.month);
        if (monthsAgo >= 0 && monthsAgo < 12) {
          monthlySales[11 - monthsAgo] =
              (monthlySales[11 - monthsAgo] ?? 0) +
              (sell['invoice_amount'] ?? 0.0);
        }
      }

      if (inRange) {
        filteredSalesCount++;

        List payment = await PaymentDatabase().get(
          sell['id'],
          allColumns: true,
        );
        var paidAmount = 0.0;
        var returnAmount = 0.0;
        payment.forEach((element) {
          if (element['is_return'] == 0) {
            paidAmount += element['amount'];
            payments.add({
              'key': element['method'],
              'value': element['amount'],
            });
          } else {
            returnAmount += element['amount'];
          }
        });
        newTotalSalesAmount += (sell['invoice_amount'] ?? 0.0);
        newTotalReceivedAmount += (paidAmount - returnAmount);
        newTotalDueAmount += (sell['pending_amount'] ?? 0.0);
      }
    }

    List<FlSpot> newSpots = [];
    monthlySales.forEach((monthIndex, amount) {
      newSpots.add(FlSpot(monthIndex.toDouble(), amount));
    });

    if (this.mounted) {
      setState(() {
        totalSales = filteredSalesCount;
        totalSalesAmount = newTotalSalesAmount;
        totalReceivedAmount = newTotalReceivedAmount;
        totalDueAmount = newTotalDueAmount;
        chartSpots = newSpots;
        chartLabels = labels;
      });
    }
    return result;
  }

  //load payment details
  loadPaymentDetails() async {
    var paymentMethod = [];
    method.clear();
    byCash = 0.00;
    byCard = 0.00;
    byCheque = 0.00;
    byBankTransfer = 0.00;
    byOther = 0.00;
    byCustomPayment_1 = 0.00;
    byCustomPayment_2 = 0.00;
    byCustomPayment_3 = 0.00;

    //fetch different payment methods
    await System().get('payment_methods').then((value) {
      //Add all PaymentMethods into a List according to key value pair
      value.forEach((element) {
        element.forEach((k, v) {
          paymentMethod.add({'key': '$k', 'value': '$v'});
        });
      });
    });

    await loadStatistics().then((value) {
      payments.forEach((row) {
        if (row['key'] == 'cash') {
          byCash += row['value'];
        }

        if (row['key'] == 'card') {
          byCard += row['value'];
        }

        if (row['key'] == 'cheque') {
          byCheque += row['value'];
        }

        if (row['key'] == 'bank_transfer') {
          byBankTransfer += row['value'];
        }

        if (row['key'] == 'other') {
          byOther += row['value'];
        }

        if (row['key'] == 'custom_pay_1') {
          byCustomPayment_1 += row['value'];
        }

        if (row['key'] == 'custom_pay_2') {
          byCustomPayment_2 += row['value'];
        }
        if (row['key'] == 'custom_pay_3') {
          byCustomPayment_3 += row['value'];
        }
      });
      paymentMethod.forEach((row) {
        if (byCash > 0 && row['key'] == 'cash')
          method.add({'key': row['value'], 'value': byCash});
        if (byCard > 0 && row['key'] == 'card')
          method.add({'key': row['value'], 'value': byCard});
        if (byCheque > 0 && row['key'] == 'cheque')
          method.add({'key': row['value'], 'value': byCheque});
        if (byBankTransfer > 0 && row['key'] == 'bank_transfer')
          method.add({'key': row['value'], 'value': byBankTransfer});
        if (byOther > 0 && row['key'] == 'other')
          method.add({'key': row['value'], 'value': byOther});
        if (byCustomPayment_1 > 0 && row['key'] == 'custom_pay_1')
          method.add({'key': row['value'], 'value': byCustomPayment_1});
        if (byCustomPayment_2 > 0 && row['key'] == 'custom_pay_2')
          method.add({'key': row['value'], 'value': byCustomPayment_2});
        if (byCustomPayment_3 > 0 && row['key'] == 'custom_pay_3')
          method.add({'key': row['value'], 'value': byCustomPayment_3});
      });
      if (this.mounted) {
        setState(() {});
      }
    });
  }
}
