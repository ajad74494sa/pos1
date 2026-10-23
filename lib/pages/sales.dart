import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:krpos/config.dart';
import 'package:search_choices/search_choices.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../apis/api.dart';
import '../apis/sell.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/contact_model.dart';
import '../models/paymentDatabase.dart';
import '../models/sell.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import '../services/whatsapp_service.dart';

import '../widgets/windows_menu.dart';

class Sales extends StatefulWidget {
  @override
  _SalesState createState() => _SalesState();
}

class _SalesState extends State<Sales> {
  List sellList = [], draftList = [], unSyncedList = [];
  List<String> paymentStatuses = ['all'], invoiceStatuses = ['final', 'draft'];
  ScrollController _scrollController = new ScrollController();
  bool isLoading = false,
      synced = true,
      canViewSell = false,
      canEditSell = false,
      canDeleteSell = false,
      showFilter = false,
      changeUrl = false,
      isSharing = false;
  Map<dynamic, dynamic> selectedLocation = {'id': 0, 'name': 'All'},
      selectedCustomer = {'id': 0, 'name': 'All', 'mobile': ''};
  String selectedPaymentStatus = '';
  String? startDateRange, endDateRange; // selectedInvoiceStatus = 'all';
  List<Map<dynamic, dynamic>> allSalesListMap = [],
      customerListMap = [
        {'id': 0, 'name': 'All', 'mobile': ''},
      ],
      locationListMap = [
        {'id': 0, 'name': 'All'},
      ];
  String symbol = '';
  String? nextPage = '',
      url = Api().baseUrl + Api().apiUrl + "/sell?order_by_date=desc";
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    setCustomers();
    setLocations();
    if ((synced)) refreshSales();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        setAllSalesList();
      }
    });
    Helper().syncCallLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  setCustomers() async {
    customerListMap.addAll(await Contact().get());
    setState(() {});
  }

  setLocations() async {
    await System().get('location').then((value) {
      value.forEach((element) {
        setState(() {
          locationListMap.add({'id': element['id'], 'name': element['name']});
        });
      });
    });
    await System().refreshPermissionList().then((value) async {
      await getPermission().then((value) {
        changeUrl = true;
        onFilter();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    themeData = Theme.of(context);
    return DefaultTabController(
      length: 4,
      initialIndex: 0,
      child: Stack(
        children: [
          Scaffold(
            key: _scaffoldKey,
            drawer: WindowsMenu(
              accessExpenses: true, 
              isAdmin: true, 
              userName: "",
            ),
            appBar: AppBar(
              backgroundColor: const Color(0xff732a13),
              elevation: 0,
              centerTitle: false,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                AppLocalizations.of(context).translate('sales'),
                style: AppTheme.getTextStyle(
                  themeData.textTheme.titleLarge,
                  fontWeight: 600,
                  color: Colors.white,
                ),
              ),
              leading: IconButton(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu, color: Colors.white),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () async {
                    if (await Helper().checkConnectivity()) {
                      showDialog(
                        barrierDismissible: true,
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            content: Row(
                              children: [
                                CircularProgressIndicator(),
                                Container(
                                  margin: const EdgeInsets.only(left: 5),
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).translate('sync_in_progress'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                      await Sell().createApiSell(syncAll: true).then((value) {
                        Navigator.pop(context);
                        setState(() {
                          synced = true;
                          sells();
                        });
                      });
                    } else
                      Helper().showNotification(
                        context,
                        AppLocalizations.of(
                          context,
                        ).translate('check_connectivity'),
                        isError: true,
                      );
                  },
                  child: Text(
                    AppLocalizations.of(context).translate('sync'),
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.titleMedium,
                      fontWeight: (synced) ? 500 : 900,
                      letterSpacing: -0.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              bottom: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                isScrollable: false,
                labelPadding: EdgeInsets.zero,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.line_weight, size: 20),
                    text: AppLocalizations.of(context).translate('recent_sales'),
                  ),
                  Tab(
                    icon: const Icon(Icons.sync_problem, size: 20),
                    text: 'Unsynced',
                  ),
                  Tab(
                    icon: const Icon(Icons.edit_document, size: 20),
                    text: 'Drafts',
                  ),
                  Tab(
                    icon: const Icon(Icons.line_style, size: 20),
                    text: AppLocalizations.of(context).translate('all_sales'),
                  ),
                ],
              ),
            ),
            body: TabBarView(children: [currentSales(), unSyncedSales(), draftSales(), allSales()]),
          ),
          if (isLoading) Helper().loadingIndicator(context, subTitle: 'LOADING SALES...'),
          if (isSharing) Helper().loadingIndicator(context, subTitle: 'SHARING...'),
        ],
      ),
    );
  }

  //Fetch permission from database
  getPermission() async {
    var activeSubscriptionDetails = await System().get('active-subscription');
    if (activeSubscriptionDetails.length > 0) {
      if (await Helper().getPermission("sell.update")) {
        canEditSell = true;
      }
      if (await Helper().getPermission("sell.delete")) {
        canDeleteSell = true;
      }
    }
    if (await Helper().getPermission("view_paid_sells_only")) {
      paymentStatuses.add('paid');
      selectedPaymentStatus = 'paid';
    }
    if (await Helper().getPermission("view_due_sells_only")) {
      paymentStatuses.add('due');
      selectedPaymentStatus = 'due';
    }
    if (await Helper().getPermission("view_partial_sells_only")) {
      paymentStatuses.add('partial');
      selectedPaymentStatus = 'partial';
    }
    if (await Helper().getPermission("view_overdue_sells_only")) {
      paymentStatuses.add('overdue');
      selectedPaymentStatus = 'all';
    }
    //await Helper().getPermission("sell.view")
    if (await Helper().getPermission("direct_sell.view")) {
      url = Api().baseUrl + Api().apiUrl + "/sell?order_by_date=desc";
      if (paymentStatuses.length < 2) {
        paymentStatuses.addAll(['paid', 'due', 'partial', 'overdue']);
        selectedPaymentStatus = 'all';
      }
      setState(() {
        canViewSell = true;
      });
    } else if (await Helper().getPermission("view_own_sell_only")) {
      url =
          Api().baseUrl +
          Api().apiUrl +
          "/sell?order_by_date=desc&user_id=${Config.userId}";
      if (paymentStatuses.length < 2) {
        paymentStatuses.addAll(['paid', 'due', 'partial', 'overdue']);
        selectedPaymentStatus = 'all';
      }
      setState(() {
        canViewSell = true;
      });
    }
  }

  refreshSales() async {
    if (await Helper().checkConnectivity()) {
      showDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                Container(
                  margin: EdgeInsets.only(left: 5),
                  child: Text(
                    AppLocalizations.of(context).translate('loading'),
                  ),
                ),
              ],
            ),
          );
        },
      );
      //update sells from api
      // await updateSellsFromApi().then((value) {
      sells();
      Navigator.pop(context);
      // });
    } else {
      sells();
      Helper().showNotification(
        context,
        AppLocalizations.of(context).translate('check_connectivity'),
        isError: true,
      );
    }
  }

  //fetch current sales from database
  sells() async {
    sellList = [];
    draftList = [];
    unSyncedList = [];
    await SellDatabase().getSells(all: true).then((value) {
      value.forEach((element) async {
        if (element['is_synced'] == 0) synced = false;
        var customerDetail = await Contact().getCustomerDetailById(
          element['contact_id'],
        );
        var locationName = await Helper().getLocationNameById(
          element['location_id'],
        );
        List payments = await PaymentDatabase().get(element['id']);
        String paymentMethod = '';
        payments.forEach((p) {
          if (paymentMethod.isNotEmpty) paymentMethod += ', ';
          paymentMethod += p['method'] ?? '';
        });
        Map<String, dynamic> saleItem = {
          'id': element['id'],
          'transaction_date': element['transaction_date'],
          'invoice_no': element['invoice_no'],
          'customer_name': (customerDetail != null)
              ? (customerDetail['name'] ?? '')
              : '',
          'mobile': (customerDetail != null)
              ? (customerDetail['mobile'] ?? '')
              : '',
          'contact_id': element['contact_id'],
          'location_id': element['location_id'],
          'location_name': locationName,
          'status': element['status'],
          'tax_rate_id': element['tax_rate_id'],
          'discount_amount': element['discount_amount'],
          'discount_type': element['discount_type'],
          'sale_note': element['sale_note'],
          'staff_note': element['staff_note'],
          'invoice_amount': element['invoice_amount'],
          'pending_amount': element['pending_amount'],
          'is_synced': element['is_synced'],
          'is_quotation': element['is_quotation'],
          'invoice_url': element['invoice_url'],
          'transaction_id': element['transaction_id'],
          'payment_method': paymentMethod,
        };
        setState(() {
          if (element['is_synced'] == 0) {
            unSyncedList.add(saleItem);
          }
          if (element['status']?.toString().toLowerCase() == 'draft' ||
              element['status']?.toString().toLowerCase() == 'quotation') {
            draftList.add(saleItem);
          } else {
            sellList.add(saleItem);
          }
        });
      });
    });
    await Helper().getFormattedBusinessDetails().then((value) {
      symbol = value['symbol'];
    });
  }

  //refresh sales list
  updateSellsFromApi() async {
    //get synced sells transactionId
    List transactionIds = await SellDatabase().getTransactionIds();

    if (transactionIds.isNotEmpty) {
      //fetch specified sells by transactionId from api
      List specificSales = await SellApi().getSpecifiedSells(transactionIds);

      specificSales.forEach((element) async {
        //fetch sell from database with respective transactionId
        List sell = await SellDatabase().getSellByTransactionId(element['id']);

        if (sell.length > 0) {
          //Updating latest data in sell_payments
          //delete payment lines with reference to its sellId
          await PaymentDatabase().delete(sell[0]['id']);
          element['payment_lines'].forEach((value) async {
            //store payment lines from response
            await PaymentDatabase().store({
              'sell_id': sell[0]['id'],
              'method': value['method'],
              'amount': value['amount'],
              'note': value['note'],
              'payment_id': value['id'],
              'is_return': value['is_return'],
              'account_id': value['account_id'],
            });
          });

          //Updating latest data in sell_lines
          //delete sell_lines with reference to its sellId
          await SellDatabase().deleteSellLineBySellId(sell[0]['id']);

          element['sell_lines'].forEach((value) async {
            //   //store sell lines from response
            await SellDatabase().store({
              'sell_id': sell[0]['id'],
              'product_id': value['product_id'],
              'variation_id': value['variation_id'],
              'quantity': value['quantity'],
              'unit_price': value['unit_price_before_discount'],
              'tax_rate_id': value['tax_id'],
              'discount_amount': value['line_discount_amount'],
              'discount_type': value['line_discount_type'],
              'note': value['sell_line_note'],
              'is_completed': 1,
            });
          });
          //update latest sells details
          updateSells(element);
        }
      });
    }
  }

  //update sells
  updateSells(sells) async {
    var changeReturn = 0.0;
    var pendingAmount = 0.0;
    var totalAmount = 0.0;
    List sell = await SellDatabase().getSellByTransactionId(sells['id']);
    await PaymentDatabase().get(sell[0]['id'], allColumns: true).then((value) {
      value.forEach((element) {
        if (element['is_return'] == 1) {
          changeReturn += element['amount'];
        } else {
          totalAmount += element['amount'];
        }
      });
    });
    if (double.parse(sells['final_total']) > totalAmount) {
      pendingAmount = double.parse(sells['final_total']) - totalAmount;
    }
    Map<String, dynamic> sellMap = Sell().createSellMap(
      sells,
      changeReturn,
      pendingAmount,
    );
    await SellDatabase().updateSells(sell[0]['id'], sellMap);
  }

  onFilter() {
    nextPage = url;
    if (selectedLocation['id'] != 0) {
      nextPage = nextPage! + "&location_id=${selectedLocation['id']}";
    }
    if (selectedCustomer['id'] != 0) {
      nextPage = nextPage! + "&contact_id=${selectedCustomer['id']}";
    }
    if (selectedPaymentStatus != 'all') {
      nextPage = nextPage! + "&payment_status=$selectedPaymentStatus";
    } else if (selectedPaymentStatus == 'all') {
      List<String> status = List.from(paymentStatuses);
      status.remove('all');
      String statuses = status.join(',');
      nextPage = nextPage! + "&payment_status=$statuses";
    }
    if (startDateRange != null && endDateRange != null) {
      nextPage =
          nextPage! + "&start_date=$startDateRange&end_date=$endDateRange";
    }
    changeUrl = true;
    setAllSalesList();
  }

  //Retrieve sales list from api
  void setAllSalesList() async {
    if (nextPage == null || nextPage!.isEmpty) return;
    
    setState(() {
      if (changeUrl) {
        allSalesListMap = [];
        changeUrl = false;
        showFilter = false;
      }
      isLoading = true;
    });

    try {
      final dio = new Dio();
      var token = await System().getToken();
      dio.options.headers['content-Type'] = 'application/json';
      dio.options.headers["Authorization"] = "Bearer $token";
      
      final response = await dio.get(nextPage!);
      
      if (response.statusCode == 200 && response.data != null) {
        List sales = response.data['data'] ?? [];
        Map? links = response.data['links'];
        nextPage = links != null ? links['next'] : null;
        
        for (var sell in sales) {
          var paidAmount;
          List payments = sell['payment_lines'] ?? [];
          double totalPaid = 0.00;
          
          Map<String, dynamic>? customer = await Contact().getCustomerDetailById(sell['contact_id']);
          var location = await Helper().getLocationNameById(sell['location_id']);
          String paymentMethod = '';
          
          for (var element in payments) {
            totalPaid += double.tryParse(element['amount']?.toString() ?? '0') ?? 0.0;
            if (paymentMethod.isNotEmpty) paymentMethod += ', ';
            paymentMethod += element['method'] ?? '';
          }
          
          double finalTotal = double.tryParse(sell['final_total']?.toString() ?? '0') ?? 0.0;
          if (totalPaid <= finalTotal) {
             paidAmount = Helper().formatCurrency(totalPaid);
          } else {
             paidAmount = Helper().formatCurrency(finalTotal);
          }
              
          allSalesListMap.add({
            'id': sell['id'],
            'location_name': location,
            'contact_name': (customer != null)
                ? ("${(customer['name'] != null) ? customer['name'] : ''} "
                      "${(customer['supplier_business_name'] != null) ? customer['supplier_business_name'] : ''}")
                : null,
            'mobile': (customer != null) ? customer['mobile'] : null,
            'invoice_no': sell['invoice_no'],
            'invoice_url': sell['invoice_url'],
            'date_time': sell['transaction_date'],
            'invoice_amount': finalTotal,
            'status': sell['payment_status'] ?? sell['status'],
            'paid_amount': paidAmount,
            'is_quotation': sell['is_quotation'].toString(),
            'payment_method': paymentMethod,
          });
        }
      }
    } catch (e) {
      print("Error fetching sales: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  //progress indicator
  Widget _buildProgressIndicator() {
    return new Padding(
      padding: const EdgeInsets.all(8.0),
      child: new Center(
        child: FutureBuilder<bool>(
          future: Helper().checkConnectivity(),
          builder: (context, AsyncSnapshot<bool> snapshot) {
            if (snapshot.data == false) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(
                      context,
                    ).translate('check_connectivity'),
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.titleMedium,
                      fontWeight: 700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Icon(
                    Icons.error_outline,
                    color: themeData.colorScheme.onSurface,
                  ),
                ],
              );
            } else {
              return CircularProgressIndicator();
            }
          },
        ),
      ),
    );
  }

  //widget for listing sales from database
  Widget currentSales() {
    return (sellList.length > 0)
        ? ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 10),
            controller: _scrollController,
            shrinkWrap: true,
            itemCount: sellList.length, 
            itemBuilder: (context, index) {
              return recentSellItem(
                price: Helper().formatCurrency(
                  sellList[index]['invoice_amount'],
                ),
                number: sellList[index]['invoice_no'],
                status: checkStatus(
                  sellList[index]['invoice_amount'],
                  sellList[index]['pending_amount'],
                ),
                time: sellList[index]['transaction_date'],
                paid: Helper().formatCurrency(
                  sellList[index]['invoice_amount'] -
                      sellList[index]['pending_amount'],
                ),
                isSynced: sellList[index]['is_synced'],
                customerName: sellList[index]['customer_name'],
                locationName: sellList[index]['location_name'],
                isQuotation: sellList[index]['is_quotation'],
                paymentMethod: sellList[index]['payment_method'],
                index: index,
              );
            },
          )
        : Helper().noDataWidget(context);
  }

  //widget for listing unsynced sales from database
  Widget unSyncedSales() {
    return (unSyncedList.length > 0)
        ? ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 10),
            shrinkWrap: true,
            itemCount: unSyncedList.length,
            itemBuilder: (context, index) {
              return recentSellItem(
                price: Helper().formatCurrency(
                  unSyncedList[index]['invoice_amount'],
                ),
                number: unSyncedList[index]['invoice_no'],
                status: checkStatus(
                  unSyncedList[index]['invoice_amount'],
                  unSyncedList[index]['pending_amount'],
                ),
                time: unSyncedList[index]['transaction_date'],
                paid: Helper().formatCurrency(
                  unSyncedList[index]['invoice_amount'] -
                      unSyncedList[index]['pending_amount'],
                ),
                isSynced: unSyncedList[index]['is_synced'],
                customerName: unSyncedList[index]['customer_name'],
                locationName: unSyncedList[index]['location_name'],
                isQuotation: unSyncedList[index]['is_quotation'],
                paymentMethod: unSyncedList[index]['payment_method'],
                index: index,
                isUnSyncedList: true,
              );
            },
          )
        : Helper().noDataWidget(context);
  }

  //widget for listing drafts from database
  Widget draftSales() {
    return (draftList.length > 0)
        ? ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 10),
            controller: _scrollController,
            shrinkWrap: true,
            itemCount: draftList.length,
            itemBuilder: (context, index) {
              return recentSellItem(
                price: Helper().formatCurrency(
                  draftList[index]['invoice_amount'],
                ),
                number: draftList[index]['invoice_no'],
                status: 'draft',
                time: draftList[index]['transaction_date'],
                paid: Helper().formatCurrency(
                  draftList[index]['invoice_amount'] -
                      draftList[index]['pending_amount'],
                ),
                isSynced: draftList[index]['is_synced'],
                customerName: draftList[index]['customer_name'],
                locationName: draftList[index]['location_name'],
                isQuotation: draftList[index]['is_quotation'],
                paymentMethod: draftList[index]['payment_method'],
                index: index,
                isDraft: true,
              );
            },
          )
        : Helper().noDataWidget(context);
  }

  //widget for listing sales from api
  Widget allSales() {
    return (canViewSell)
        ? Column(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    showFilter = !showFilter;
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(MySize.size12!),
                  decoration: BoxDecoration(
                    color: customAppTheme.bgLayer1,
                    border: Border(bottom: BorderSide(
                      color: customAppTheme.bgLayer4,
                      width: 1.2,
                    )),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            (showFilter)
                                ? Symbols.expand_less
                                : Symbols.expand_more,
                            color: themeData.colorScheme.primary,
                          ),
                          Row(
                            children: [
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).translate('filter'),
                                style: AppTheme.getTextStyle(
                                  themeData.textTheme.titleLarge,
                                  color: themeData.colorScheme.primary,
                                  fontWeight: 700,
                                ),
                              ),
                              Icon(
                                Symbols.filter,
                                color: themeData.colorScheme.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                      (showFilter)
                          ? Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "${AppLocalizations.of(context).translate('location')} : ",
                                      style: AppTheme.getTextStyle(
                                        themeData.textTheme.bodyLarge,
                                        fontWeight: 600,
                                      ),
                                    ),
                                    locations(),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      "${AppLocalizations.of(context).translate('customer')} : ",
                                      style: AppTheme.getTextStyle(
                                        themeData.textTheme.bodyLarge,
                                        fontWeight: 600,
                                      ),
                                    ),
                                    Expanded(child: customers()),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      new MaterialPageRoute<Null>(
                                        builder: (BuildContext context) {
                                          return dateRangePicker();
                                        },
                                        fullscreenDialog: true,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(MySize.size8!),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(MySize.size8!),
                                      ),
                                      color: customAppTheme.bgLayer1,
                                      border: Border.all(
                                        color: customAppTheme.bgLayer4,
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          (startDateRange != null &&
                                                  endDateRange != null)
                                              ? "$startDateRange   -   $endDateRange"
                                              : "Date range",
                                          style: AppTheme.getTextStyle(
                                            themeData.textTheme.bodyText1,
                                            fontWeight: 600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: MySize.size6!,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      "${AppLocalizations.of(context).translate('payment_status')} : ",
                                      style: AppTheme.getTextStyle(
                                        themeData.textTheme.bodyLarge,
                                        fontWeight: 600,
                                      ),
                                    ),
                                    (paymentStatuses.length > 0)
                                        ? paymentStatus()
                                        : Container(),
                                  ],
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: MySize.size6!,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            MySize.size20!,
                                          ),
                                          side: BorderSide(
                                            color:
                                                themeData.colorScheme.primary,
                                          ),
                                        ),
                                        foregroundColor:
                                            themeData.colorScheme.primary,
                                      ),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).translate('reset'),
                                        style: AppTheme.getTextStyle(
                                          themeData.textTheme.button,
                                          color:
                                              themeData.colorScheme.onPrimary,
                                          fontWeight: 600,
                                        ),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          selectedLocation = locationListMap[0];
                                          selectedCustomer = customerListMap[0];
                                          startDateRange = null;
                                          endDateRange = null;
                                          selectedPaymentStatus =
                                              paymentStatuses[0];
                                        });
                                        onFilter();
                                      },
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            MySize.size20!,
                                          ),
                                          side: BorderSide(
                                            color:
                                                themeData.colorScheme.primary,
                                          ),
                                        ),
                                        foregroundColor:
                                            themeData.colorScheme.primary,
                                      ),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).translate('ok'),
                                        style: AppTheme.getTextStyle(
                                          themeData.textTheme.button,
                                          color:
                                              themeData.colorScheme.onPrimary,
                                          fontWeight: 600,
                                        ),
                                      ),
                                      onPressed: () {
                                        onFilter();
                                      },
                                    ),
                                  ],
                                ),
                                // Padding(padding: EdgeInsets.symmetric(vertical: MySize.size6),), Row(children: [Text("${AppLocalizations.of(context).translate('invoice_status')} : ", style: AppTheme.getTextStyle(themeData.textTheme.bodyText1, fontWeight: 600),), invoiceStatus()],),
                              ],
                            )
                          : Container(),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: (allSalesListMap.length > 0)
                    ? ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shrinkWrap: true,
                        controller: _scrollController,
                        itemCount: allSalesListMap.length,
                        itemBuilder: (context, index) {
                          if (index == allSalesListMap.length) {
                            return (isLoading)
                                ? _buildProgressIndicator()
                                : Container();
                          } else {
                            return allSellItem(
                              index: index,
                              price: allSalesListMap[index]['invoice_amount'],
                              number: allSalesListMap[index]['invoice_no'],
                              time: allSalesListMap[index]['date_time'],
                              status: allSalesListMap[index]['status'],
                              paid: allSalesListMap[index]['paid_amount'],
                              customerName:
                                  allSalesListMap[index]['contact_name'],
                              locationName:
                                  allSalesListMap[index]['location_name'],
                              isQuotation: int.parse(
                                allSalesListMap[index]['is_quotation']
                                    .toString(),
                              ),
                              paymentMethod: allSalesListMap[index]['payment_method'],
                            );
                          }
                        },
                      )
                    : Helper().noDataWidget(context),
              ),
            ],
          )
        : Center(
            child: Text(
              AppLocalizations.of(context).translate('unauthorised'),
              style: TextStyle(color: Colors.black),
            ),
          );
  }

  Widget dateRangePicker() {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('select_range')),
        elevation: 0,
      ),
      body: Column(
        children: [
          SfDateRangePicker(
            view: DateRangePickerView.year,
            selectionMode: DateRangePickerSelectionMode.range,
            onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
              if (args.value.startDate != null) {
                setState(() {
                  startDateRange = DateFormat(
                    'yyyy-MM-dd',
                  ).format(args.value.startDate).toString();
                });
              }
              if (args.value.endDate != null) {
                setState(() {
                  endDateRange = DateFormat(
                    'yyyy-MM-dd',
                  ).format(args.value.endDate).toString();
                });
              }
            },
          ),
          Padding(padding: EdgeInsets.symmetric(vertical: MySize.size30!)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MySize.size20!),
                    side: BorderSide(color: themeData.colorScheme.primary),
                  ),
                  foregroundColor: themeData.colorScheme.primary,
                ),
                onPressed: () {
                  setState(() {
                    startDateRange = null;
                    endDateRange = null;
                  });
                  Navigator.pop(context);
                },
                child: Text(
                  AppLocalizations.of(context).translate('reset'),
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.titleLarge,
                    color: themeData.colorScheme.onPrimary,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MySize.size20!),
                    side: BorderSide(color: themeData.colorScheme.primary),
                  ),
                  foregroundColor: themeData.colorScheme.primary,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  AppLocalizations.of(context).translate('ok'),
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.titleLarge,
                    color: themeData.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  //recent sales listing widget
  Widget recentSellItem({
    number,
    time,
    status,
    price,
    paid,
    isSynced,
    customerName,
    locationName,
    isQuotation,
    index,
    bool isDraft = false,
    bool isUnSyncedList = false,
    required paymentMethod,
  }) {
    //Logic for row items
    double space = MySize.size12!;
    var currentList = isDraft
        ? draftList
        : isUnSyncedList
            ? unSyncedList
            : sellList;
    return Container(
      padding: EdgeInsets.all(space),
      margin: EdgeInsets.only(bottom: space),
      decoration: BoxDecoration(
        color: customAppTheme.bgLayer1,
        border: Border(bottom: BorderSide(color: customAppTheme.bgLayer4, width: 1.2)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                time,
                style: AppTheme.getTextStyle(
                  themeData.textTheme.bodyText2,
                  fontWeight: 600,
                  letterSpacing: -0.2,
                  color: themeData.colorScheme.onSurface.withAlpha(160),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        (isQuotation == 0)
                            ? AppLocalizations.of(
                                    context,
                                  ).translate('invoice_no') +
                                  " $number"
                            : AppLocalizations.of(context).translate('ref_no') +
                                  " $number",
                        style: AppTheme.getTextStyle(
                          themeData.textTheme.subtitle1,
                          fontWeight: 700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(
                              context,
                            ).translate('invoice_amount') +
                            " $symbol $price",
                        style: AppTheme.getTextStyle(
                          themeData.textTheme.bodyText2,
                          fontWeight: 600,
                          letterSpacing: 0,
                        ),
                      ),
                      (isQuotation == 0)
                          ? Text(
                              AppLocalizations.of(
                                    context,
                                  ).translate('paid_amount') +
                                  " $symbol $paid",
                              style: AppTheme.getTextStyle(
                                themeData.textTheme.bodyText2,
                                fontWeight: 600,
                                letterSpacing: 0,
                              ),
                            )
                          : SizedBox(),
                      if (paymentMethod != null &&
                          paymentMethod.toString().isNotEmpty)
                        Text(
                          AppLocalizations.of(context)
                                  .translate('payment_method') +
                              ": $paymentMethod",
                          style: AppTheme.getTextStyle(
                            themeData.textTheme.bodyText2,
                            fontWeight: 600,
                            letterSpacing: 0,
                          ),
                        ),
                      Text(
                        AppLocalizations.of(
                              context,
                            ).translate('customer_name') +
                            ": $customerName",
                        style: AppTheme.getTextStyle(
                          themeData.textTheme.bodyText2,
                          fontWeight: 600,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(
                              context,
                            ).translate('location_name') +
                            ": $locationName",
                        style: AppTheme.getTextStyle(
                          themeData.textTheme.bodyText2,
                          fontWeight: 600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Visibility(
                visible: index != null,
                child: Row(
                  children: [
                    (canEditSell)
                        ? IconButton(
                            icon: Icon(
                              Symbols.edit,
                              color: themeData.colorScheme.onSurface,
                            ),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/edit_sale',
                                arguments: Helper().argument(
                                  locId: currentList[index]['location_id'],
                                  sellId: currentList[index]['id'],
                                  isQuotation: currentList[index]['is_quotation'],
                                  customerId: currentList[index]['contact_id'],
                                ),
                              ).then((value) {
                                if (value == true) {
                                  refreshSales();
                                }
                              });
                            },
                          )
                        : Container(),
                    (canDeleteSell)
                        ? IconButton(
                            icon: Icon(
                              Symbols.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              showDialog(
                                barrierDismissible: true,
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Icon(
                                      Symbols.warning,
                                      color: Colors.red,
                                      size: MySize.size50,
                                    ),
                                    content: Text(
                                      AppLocalizations.of(
                                        context,
                                      ).translate('are_you_sure'),
                                      textAlign: TextAlign.center,
                                      style: AppTheme.getTextStyle(
                                        themeData.textTheme.bodyMedium,
                                        fontWeight: 600,
                                        muted: true,
                                      ),
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor:
                                              themeData.colorScheme.onPrimary,
                                          foregroundColor:
                                              themeData.colorScheme.primary,
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).translate('cancel'),
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor:
                                              themeData.colorScheme.onError,
                                        ),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          await SellDatabase().deleteSell(
                                            currentList[index]['id'],
                                          );
                                          refreshSales();
                                        },
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).translate('ok'),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          )
                        : Container(),
                    IconButton(
                      icon: Icon(Symbols.print, color: Colors.deepPurple),
                      onPressed: () async {
                        if (await Helper().checkConnectivity() &&
                            currentList[index]['invoice_url'] != null) {
                          final response = await http.Client().get(
                            Uri.parse(currentList[index]['invoice_url']),
                          );
                          if (response.statusCode == 200) {
                            await Helper().printDocument(
                              currentList[index]['id'],
                              currentList[index]['tax_rate_id'],
                              context,
                              invoice: response.body,
                              isManual: true,
                            );
                          } else {
                            await Helper().printDocument(
                              currentList[index]['id'],
                              currentList[index]['tax_rate_id'],
                              context,
                              isManual: true,
                            );
                          }
                        } else {
                          await Helper().printDocument(
                            currentList[index]['id'],
                            currentList[index]['tax_rate_id'],
                            context,
                            isManual: true,
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.restaurant_menu, color: Colors.orange),
                      tooltip: 'Kitchen Print',
                      onPressed: () async {
                        await Helper().printKitchenDocument(currentList[index]['id'], context);
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Symbols.share,
                        color: themeData.colorScheme.primary,
                      ),
                      onPressed: () async {
                        setState(() => isSharing = true);
                        try {
                          // Trigger WhatsApp Notification
                          await Helper().sendWhatsAppNotification(currentList[index]['id'], isServerId: false, force: true);

                          if (await Helper().checkConnectivity() &&
                              currentList[index]['invoice_url'] != null) {
                            final response = await http.Client().get(
                              Uri.parse(currentList[index]['invoice_url']),
                            );
                            if (response.statusCode == 200) {
                              await Helper().savePdf(
                                currentList[index]['id'],
                                currentList[index]['tax_rate_id'],
                                context,
                                currentList[index]['invoice_no'],
                                invoice: response.body,
                              );
                            } else {
                              await Helper().savePdf(
                                currentList[index]['id'],
                                currentList[index]['tax_rate_id'],
                                context,
                                currentList[index]['invoice_no'],
                              );
                            }
                          } else {
                            await Helper().savePdf(
                              currentList[index]['id'],
                              currentList[index]['tax_rate_id'],
                              context,
                              currentList[index]['invoice_no'],
                            );
                          }
                        } catch (e) {
                          Helper().showNotification(context, 'Error sharing: $e', isError: true);
                        } finally {
                          setState(() => isSharing = false);
                        }
                      },
                    ),
                    ((currentList[index]['pending_amount'] > 0) && canEditSell)
                        ? IconButton(
                            icon: Icon(
                              Symbols.credit_card,
                              color: Colors.purpleAccent,
                            ),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/checkout',
                                arguments: Helper().argument(
                                  invoiceAmount:
                                      currentList[index]['invoice_amount'],
                                  customerId: currentList[index]['contact_id'],
                                  locId: currentList[index]['location_id'],
                                  discountAmount:
                                      currentList[index]['discount_amount'],
                                  discountType:
                                      currentList[index]['discount_type'],
                                  isQuotation: currentList[index]['is_quotation'],
                                  taxId: currentList[index]['tax_rate_id'],
                                  sellId: currentList[index]['id'],
                                ),
                              );
                            },
                          )
                        : Container(),
                    (((currentList[index]['pending_amount'] > 0) && canEditSell) &&
                            (currentList[index]['mobile'] != null))
                        ? IconButton(
                            icon: Icon(
                              Icons.call_outlined,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              // call
                              await launchUrl(
                                Uri.parse('tel:${currentList[index]['mobile']}'),
                              );
                            },
                          )
                        : Container(),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.all(MySize.size5!),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.circular(MySize.size4!),
                      ),
                      color: (isQuotation == 0)
                          ? checkStatusColor(status)
                          : Colors.yellowAccent,
                    ),
                    child: Text(
                      (isQuotation == 0) ? status.toUpperCase() : 'DRAFT',
                      style: AppTheme.getTextStyle(
                        themeData.textTheme.bodySmall,
                        fontSize: 14,
                        fontWeight: 700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: index != null,
                    child: Padding(
                      padding: EdgeInsets.all(MySize.size8!),
                      child: (isSynced == 0)
                          ? Icon(Symbols.sync_problem, color: Colors.black)
                          : Container(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  //all sales listing widget
  Widget allSellItem({
    number,
    time,
    status,
    price,
    paid,
    isSynced,
    customerName,
    locationName,
    isQuotation,
    index,
    paymentMethod,
  }) {
    //Logic for row items
    double space = MySize.size12!;
    return Container(
      padding: EdgeInsets.all(space),
      margin: EdgeInsets.only(bottom: space),
      decoration: BoxDecoration(
        color: customAppTheme.bgLayer1,
        border: Border(bottom: BorderSide(color: customAppTheme.bgLayer4, width: 1.2)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                time,
                style: AppTheme.getTextStyle(
                  themeData.textTheme.bodyMedium,
                  fontWeight: 600,
                  letterSpacing: -0.2,
                  color: themeData.colorScheme.onSurface.withAlpha(160),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        (isQuotation == 0)
                            ? AppLocalizations.of(
                                    context,
                                  ).translate('invoice_no') +
                                  " $number"
                            : AppLocalizations.of(context).translate('ref_no') +
                                  " $number",
                        style: AppTheme.getTextStyle(
                          themeData.textTheme.subtitle1,
                          fontWeight: 700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(
                              context,
                            ).translate('invoice_amount') +
                            " $symbol $price",
                        style: AppTheme.getTextStyle(
                          themeData.textTheme.bodyText2,
                          fontWeight: 600,
                          letterSpacing: 0,
                        ),
                      ),
                      (isQuotation == 0)
                          ? Text(
                              AppLocalizations.of(
                                    context,
                                  ).translate('paid_amount') +
                                  " $symbol $paid",
                              style: AppTheme.getTextStyle(
                                themeData.textTheme.bodyText2,
                                fontWeight: 600,
                                letterSpacing: 0,
                              ),
                            )
                          : SizedBox(),
                      if (paymentMethod != null &&
                          paymentMethod.toString().isNotEmpty)
                        Text(
                          AppLocalizations.of(context)
                                  .translate('payment_method') +
                              ": $paymentMethod",
                          style: AppTheme.getTextStyle(
                            themeData.textTheme.bodyText2,
                            fontWeight: 600,
                            letterSpacing: 0,
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${AppLocalizations.of(context).translate('customer_name')}: ",
                            style: AppTheme.getTextStyle(
                              themeData.textTheme.bodyText2,
                              fontWeight: 600,
                              letterSpacing: 0,
                            ),
                          ),
                          SizedBox(
                            width: MySize.screenWidth! * 0.6,
                            child: Text(
                              "$customerName",
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.getTextStyle(
                                themeData.textTheme.bodyText2,
                                fontWeight: 600,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        AppLocalizations.of(
                              context,
                            ).translate('location_name') +
                            ": $locationName",
                        maxLines: 3,
                        style: AppTheme.getTextStyle(
                          themeData.textTheme.bodyText2,
                          fontWeight: 600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Visibility(
                    visible: index != null,
                    child: Row(
                      children: [
                        // (canEditSell) ? IconButton(icon: Icon(Symbols.fileDocumentEditOutline, color: themeData.colorScheme.onBackground,), onPressed: () {Navigator.push(context, '/cart', arguments: Helper().argument(locId: sellList[index]['location_id'], sellId: sellList[index]['id'], isQuotation: sellList[index]['is_quotation']));}) : Container(),
                        (canDeleteSell)
                            ? IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  showDialog(
                                    barrierDismissible: true,
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Icon(
                                          Icons.add_alert,
                                          color: Colors.red,
                                          size: MySize.size50,
                                        ),
                                        content: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).translate('are_you_sure'),
                                          textAlign: TextAlign.center,
                                          style: AppTheme.getTextStyle(
                                            themeData.textTheme.bodyText1,
                                            color:
                                                themeData.colorScheme.onSurface,
                                            fontWeight: 600,
                                            muted: true,
                                          ),
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              backgroundColor: themeData
                                                  .colorScheme
                                                  .onPrimary,
                                              foregroundColor:
                                                  themeData.colorScheme.primary,
                                            ),
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).translate('cancel'),
                                            ),
                                          ),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor:
                                                  themeData.colorScheme.onError,
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await SellApi()
                                                  .delete(
                                                    allSalesListMap[index]['id'],
                                                  )
                                                  .then((value) {
                                                    if (value != null) {
                                                      setState(() {
                                                        allSalesListMap
                                                            .removeAt(index);
                                                      });
                                                      Helper().showNotification(
                                                        context,
                                                        '${value['msg']}',
                                                      );
                                                    }
                                                  });
                                            },
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).translate('ok'),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              )
                            : Container(),
                        Visibility(
                          visible:
                              allSalesListMap[index]['invoice_url'] != null,
                          child: IconButton(
                            icon: Icon(
                              Icons.print,
                              color: Colors.deepPurple,
                            ),
                            onPressed: () async {
                              // Trigger WhatsApp Notification
                              Helper().sendWhatsAppNotification(allSalesListMap[index]['id'], isServerId: true);

                              if (await Helper().checkConnectivity()) {
                                final response = await http.Client().get(
                                  Uri.parse(
                                    allSalesListMap[index]['invoice_url'],
                                  ),
                                );
                                if (response.statusCode == 200) {
                                  await Helper().printDocument(
                                    0,
                                    0,
                                    context,
                                    invoice: response.body,
                                    isManual: true,
                                  );
                                } else {
                                  Helper().showNotification(
                                    context,
                                    AppLocalizations.of(
                                      context,
                                    ).translate('something_went_wrong'),
                                    isError: true,
                                  );
                                }
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
                        ),
                        Visibility(
                          visible:
                              allSalesListMap[index]['invoice_url'] != null,
                          child: IconButton(
                            icon: Icon(
                              Icons.share,
                              color: themeData.colorScheme.primary,
                            ),
                            onPressed: () async {
                              setState(() => isSharing = true);
                              try {
                                // Trigger WhatsApp Notification
                                await Helper().sendWhatsAppNotification(allSalesListMap[index]['id'], isServerId: true, force: true);

                                if (await Helper().checkConnectivity()) {
                                  // print(allSalesListMap[index]
                                  // ['invoice_url']);
                                  final response = await http.Client().get(
                                    Uri.parse(
                                      allSalesListMap[index]['invoice_url'],
                                    ),
                                  );
                                  // print(response.body);
                                  if (response.statusCode == 200) {
                                    await Helper().savePdf(
                                      0,
                                      0,
                                      context,
                                      allSalesListMap[index]['invoice_no'],
                                      invoice: response.body,
                                    );
                                  } else {
                                    Helper().showNotification(
                                      context,
                                      AppLocalizations.of(
                                        context,
                                      ).translate('something_went_wrong'),
                                      isError: true,
                                    );
                                  }
                                } else {
                                  Helper().showNotification(
                                    context,
                                    AppLocalizations.of(
                                      context,
                                    ).translate('check_connectivity'),
                                    isError: true,
                                  );
                                }
                              } catch (e) {
                                Helper().showNotification(context, 'Error sharing: $e', isError: true);
                              } finally {
                                setState(() => isSharing = false);
                              }
                            },
                          ),
                        ),
                        Visibility(
                          visible:
                              (allSalesListMap[index]['mobile'] != null &&
                              allSalesListMap[index]['status']
                                      .toString()
                                      .toLowerCase() !=
                                  'paid'),
                          child: IconButton(
                            icon: Icon(
                              Icons.call_outlined,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              await launch(
                                'tel:${allSalesListMap[index]['mobile']}',
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.only(
                  left: MySize.size12!,
                  right: MySize.size12!,
                  top: MySize.size8!,
                  bottom: MySize.size8!,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.circular(MySize.size4!),
                  ),
                  color: (isQuotation == 0)
                      ? checkStatusColor(status)
                      : Colors.yellowAccent,
                ),
                child: Text(
                  (isQuotation == 0) ? status.toUpperCase() : 'DRAFT',
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.caption,
                    fontSize: 12,
                    fontWeight: 700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget customers() {
    return SearchChoices.single(
      underline: Visibility(child: Container(), visible: false),
      displayClearIcon: false,
      value: jsonEncode(selectedCustomer),
      items: customerListMap.map<DropdownMenuItem<String>>((Map value) {
        return DropdownMenuItem<String>(
          value: jsonEncode(value),
          child: Container(
            width: MySize.screenWidth! * 0.8,
            child: Text(
              "${value['name']} (${value['mobile'] ?? ' - '})",
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodyText2,
                color: themeData.colorScheme.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
      onChanged: (value) async {
        setState(() {
          selectedCustomer = jsonDecode(value);
        });
      },
      isExpanded: true,
    );
  }

  Widget locations() {
    return PopupMenuButton(
      onSelected: (Map<dynamic, dynamic> item) {
        setState(() {
          selectedLocation = item;
        });
      },
      itemBuilder: (BuildContext context) {
        return locationListMap.map((Map value) {
          return PopupMenuItem(
            value: value,
            child: Text(
              value['name'],
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodyText2,
                color: themeData.colorScheme.onSurface,
              ),
            ),
          );
        }).toList();
      },
      color: Colors.white,
      child: Container(
        padding: EdgeInsets.all(MySize.size8!),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(MySize.size8!)),
          color: customAppTheme.bgLayer1,
          border: Border.all(color: customAppTheme.bgLayer3, width: 1),
        ),
        child: Row(
          children: <Widget>[
            Text(
              selectedLocation['name'],
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodyText1,
                color: themeData.colorScheme.onSurface,
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: MySize.size4!),
              child: Icon(
                Symbols.expand_more,
                size: MySize.size22,
                color: themeData.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget paymentStatus() {
    return PopupMenuButton(
      onSelected: (String item) {
        setState(() {
          selectedPaymentStatus = item;
        });
      },
      itemBuilder: (BuildContext context) {
        return paymentStatuses.map((String value) {
          return PopupMenuItem(
            value: value,
            child: Text(
              AppLocalizations.of(context).translate(value).toUpperCase(),
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodyText2,
                color: themeData.colorScheme.onSurface,
              ),
            ),
          );
        }).toList();
      },
      color: Colors.white,
      child: Container(
        padding: EdgeInsets.all(MySize.size8!),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(MySize.size8!)),
          color: customAppTheme.bgLayer1,
          border: Border.all(color: customAppTheme.bgLayer3, width: 1),
        ),
        child: Row(
          children: <Widget>[
            Text(
              AppLocalizations.of(
                context,
              ).translate(selectedPaymentStatus).toUpperCase(),
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodyText1,
                color: themeData.colorScheme.onSurface,
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: MySize.size4!),
              child: Icon(
                Symbols.expand_more,
                size: MySize.size22,
                color: themeData.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget invoiceStatus() {
    return PopupMenuButton(
      onSelected: (item) {
        setState(() {
          // selectedInvoiceStatus = item;
        });
      },
      itemBuilder: (BuildContext context) {
        return invoiceStatuses.map((String value) {
          return PopupMenuItem(
            value: value,
            child: Text(
              AppLocalizations.of(context).translate(value).toUpperCase(),
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodyText2,
                color: themeData.colorScheme.onSurface,
              ),
            ),
          );
        }).toList();
      },
      color: Colors.white,
      child: Container(
        padding: EdgeInsets.all(MySize.size8!),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(MySize.size8!)),
          color: customAppTheme.bgLayer1,
          border: Border.all(color: customAppTheme.bgLayer3, width: 1),
        ),
        child: Row(
          children: <Widget>[
            Text(
              '',
              // AppLocalizations.of(context)
              //     .translate(selectedInvoiceStatus)
              //     .toUpperCase(),
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodyText1,
                color: themeData.colorScheme.onSurface,
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: MySize.size4!),
              child: Icon(
                Symbols.expand_more,
                size: MySize.size22,
                color: themeData.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //status color
  Color checkStatusColor(String? status) {
    if (status != null) {
      if (status.toLowerCase() ==
          AppLocalizations.of(context).translate('paid'))
        return Colors.green;
      else if (status.toLowerCase() == 'due')
        return Colors.red;
      else
        return Colors.orange;
    } else {
      return Colors.black12;
    }
  }

  //status status of recent sales
  String checkStatus(double invoiceAmount, double pendingAmount) {
    if (pendingAmount == invoiceAmount)
      return 'due';
    else if (pendingAmount >= 0.01)
      return AppLocalizations.of(context).translate('partial');
    else
      return AppLocalizations.of(context).translate('paid');
  }
}
