import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:search_choices/search_choices.dart';

import '../apis/contact.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/contact_model.dart';
import '../models/sell.dart';
import '../models/sellDatabase.dart';
import '../services/whatsapp_service.dart';
import 'elements.dart';

class Customer extends StatefulWidget {
  @override
  _CustomerState createState() => _CustomerState();
}

class _CustomerState extends State<Customer> {
  Map? argument;
  final _formKey = GlobalKey<FormState>();

  String transactionDate = DateFormat(
    "yyyy-MM-dd HH:mm:ss",
  ).format(DateTime.now());
  List<Map<String, dynamic>> customerListMap = [];
  Map<String, dynamic> selectedCustomer = {
    'id': 0,
    'name': 'select customer',
    'mobile': ' - ',
  };
  TextEditingController prefix = new TextEditingController(),
      firstName = new TextEditingController(),
      middleName = new TextEditingController(),
      lastName = new TextEditingController(),
      mobile = new TextEditingController(),
      addressLine1 = new TextEditingController(),
      addressLine2 = new TextEditingController(),
      city = new TextEditingController(),
      state = new TextEditingController(),
      country = new TextEditingController(),
      zip = new TextEditingController();
  bool isLoading = false;
  double selectedCustomerDue = 0.0;
  String symbol = '';

  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  @override
  void initState() {
    super.initState();
    Helper().getFormattedBusinessDetails().then((value) {
      if (mounted) {
        setState(() {
          symbol = value['symbol'] ?? '';
        });
      }
    });
    selectCustomer();
  }

  @override
  void didChangeDependencies() {
    argument = ModalRoute.of(context)!.settings.arguments as Map?;

    if (argument != null && argument!['customerId'] != null) {
      Future.delayed(Duration(milliseconds: 400), () async {
        await Contact().getCustomerDetailById(argument!['customerId']).then((
          value,
        ) {
          if (this.mounted) {
            setState(() {
              selectedCustomer = {
                'id': argument!['customerId'],
                'name': value['name'],
                'mobile': value['mobile'],
              };
            });
            _updateCustomerDue();
          }
        });
      });
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: customAppTheme.bgLayer1,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: themeData.colorScheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context).translate('customer'),
          style: AppTheme.getTextStyle(
            themeData.textTheme.headline6,
            color: Colors.white,
            fontWeight: 600,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            new MaterialPageRoute<Null>(
              builder: (BuildContext context) {
                return newCustomer();
              },
              fullscreenDialog: true,
            ),
          );
        },
        child: Icon(Symbols.person_add, color: Colors.white),
        backgroundColor: themeData.colorScheme.primary,
        elevation: 4,
      ),
      body: Column(
        children: <Widget>[
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: MySize.size20),
                  _buildCustomerSelector(),
                  if (selectedCustomer['id'] != 0) _buildCustomerDetails(),
                  if (selectedCustomer['id'] == 0) _buildEmptyState(),
                  SizedBox(height: MySize.size80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildTopBar() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: MySize.size30!, left: MySize.size24!, right: MySize.size24!),
      decoration: BoxDecoration(
        color: themeData.colorScheme.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(MySize.size30!),
          bottomRight: Radius.circular(MySize.size30!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).translate('select_customer'),
            style: AppTheme.getTextStyle(
              themeData.textTheme.bodyLarge,
              color: Colors.white.withAlpha(200),
              fontWeight: 500,
            ),
          ),
          SizedBox(height: MySize.size4),
          Text(
            selectedCustomer['id'] == 0 
              ? "No Customer Selected" 
              : selectedCustomer['name'],
            style: AppTheme.getTextStyle(
              themeData.textTheme.headlineSmall,
              color: Colors.white,
              fontWeight: 700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSelector() {
    return Transform.translate(
      offset: Offset(0, -MySize.size24!),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: MySize.size20!),
        child: Card(
          elevation: 10,
          shadowColor: themeData.colorScheme.primary.withAlpha(40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MySize.size16!)),
          child: Padding(
            padding: EdgeInsets.all(MySize.size4!),
            child: customerList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerDetails() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: MySize.size20!),
      child: Column(
        children: [
          _buildInfoCard(),
          SizedBox(height: MySize.size20),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(MySize.size20!),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MySize.size20!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(MySize.size12!),
                decoration: BoxDecoration(
                  color: themeData.colorScheme.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(Symbols.person, color: themeData.colorScheme.primary, size: MySize.size30),
              ),
              SizedBox(width: MySize.size16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedCustomer['name'],
                      style: AppTheme.getTextStyle(
                        themeData.textTheme.titleLarge,
                        fontWeight: 700,
                      ),
                    ),
                    Text(
                      selectedCustomer['mobile'],
                      style: AppTheme.getTextStyle(
                        themeData.textTheme.bodyMedium,
                        color: themeData.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (selectedCustomerDue > 0) ...[
            Divider(height: MySize.size40),
            Container(
              padding: EdgeInsets.all(MySize.size16!),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(10),
                borderRadius: BorderRadius.circular(MySize.size12!),
                border: Border.all(color: Colors.red.withAlpha(30)),
              ),
              child: Row(
                children: [
                  Icon(Symbols.account_balance_wallet, color: Colors.red, size: MySize.size24),
                  SizedBox(width: MySize.size12),
                  Text(
                    AppLocalizations.of(context).translate('due_amount'),
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.bodyLarge,
                      fontWeight: 600,
                      color: Colors.red[700],
                    ),
                  ),
                  Spacer(),
                  Text(
                    "$symbol${Helper().formatCurrency(selectedCustomerDue)}",
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.titleLarge,
                      fontWeight: 800,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            Symbols.call, 
            AppLocalizations.of(context).translate('call'), 
            Colors.green, 
            () => Helper().makePhoneCall(selectedCustomer['mobile'])
          ),
        ),
        SizedBox(width: MySize.size12),
        Expanded(
          child: _actionButton(
            Symbols.payments, 
            AppLocalizations.of(context).translate('payments'), 
            Colors.orange, 
            () => Navigator.pushNamed(context, '/contact_payment', arguments: {'customer': selectedCustomer})
          ),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: MySize.size16!),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(MySize.size16!),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: MySize.size28),
            SizedBox(height: MySize.size8),
            Text(
              label,
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodyMedium,
                color: color,
                fontWeight: 700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(MySize.size40!),
        child: Column(
          children: [
            Icon(Symbols.person_search, size: MySize.size80, color: themeData.colorScheme.onSurface.withAlpha(30)),
            SizedBox(height: MySize.size20),
            Text(
              AppLocalizations.of(
                context,
              ).translate('please_select_a_customer_for_checkout_option'),
              textAlign: TextAlign.center,
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodyMedium,
                color: Colors.red.withAlpha(200),
                fontWeight: 500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (selectedCustomer['id'] == 0 || argument == null) return Container(height: 0);

    return Container(
      padding: EdgeInsets.all(MySize.size16!),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (argument?['is_quotation'] == null)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: MySize.size8!),
                child: TextButton(
                  onPressed: addQuotation,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: MySize.size12!),
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MySize.size12!),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('add_quotation'),
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.bodyLarge,
                      fontWeight: 700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            flex: 2,
            child: cartBottomBar(
              '/checkout',
              AppLocalizations.of(context).translate('pay_&_checkout'),
              context,
              Helper().argument(
                locId: argument?['locationId'],
                taxId: argument?['taxId'],
                discountType: argument?['discountType'],
                discountAmount: argument?['discountAmount'],
                invoiceAmount: argument?['invoiceAmount'],
                customerId: selectedCustomer['id'],
                sellId: argument?['sellId'],
              ),
            ),
          ),
        ],
      ),
    );
  }

  //add quotation
  addQuotation() async {
    if (argument == null) return;
    Map sell = await Sell().createSell(
      changeReturn: 0.00,
      transactionDate: transactionDate,
      pending: argument?['invoiceAmount'],
      shippingCharges: 0.00,
      shippingDetails: '',
      invoiceNo: await Helper().generateRefNumber('sell', locationId: argument?['locationId']),
      contactId: selectedCustomer['id'],
      discountAmount: argument?['discountAmount'],
      discountType: argument?['discountType'],
      invoiceAmount: argument?['invoiceAmount'],
      locId: argument?['locationId'],
      saleStatus: 'draft',
      sellId: argument?['sellId'],
      taxId: argument?['taxId'],
      isQuotation: 1,
    );
    confirmDialog(sell);
  }

  //confirmation dialogBox
  confirmDialog(sell) {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: customAppTheme.bgLayer1,
          title: Text(
            AppLocalizations.of(context).translate('quotation'),
            style: AppTheme.getTextStyle(
              themeData.textTheme.headline6,
              color: themeData.colorScheme.onSurface,
              fontWeight: 700,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeData.colorScheme.primary,
              ),
              onPressed: isLoading ? null : () async {
                setState(() => isLoading = true);
                try {
                  if (argument?['sellId'] != null) {
                    //update sell
                  } else {
                    await SellDatabase().storeSell(sell).then((value) async {
                      SellDatabase().updateSellLine({
                        'sell_id': value,
                        'is_completed': 1,
                      });
                      if (await Helper().checkConnectivity()) {
                        await Sell().createApiSell(sellId: value);
                      }
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/products',
                        ModalRoute.withName('/home'),
                      );
                    });
                  }
                } finally {
                  setState(() => isLoading = false);
                }
              },
              child: Text(AppLocalizations.of(context).translate('save')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeData.colorScheme.primary,
              ),
              onPressed: isLoading ? null : () async {
                setState(() => isLoading = true);
                try {
                  await SellDatabase().storeSell(sell).then((value) async {
                    SellDatabase().updateSellLine({
                      'sell_id': value,
                      'is_completed': 1,
                    });
                    if (await Helper().checkConnectivity()) {
                      await Sell().createApiSell(sellId: value);
                    }
                    Helper()
                        .printDocument(value, argument?['taxId'], context, isManual: true)
                        .then((value) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/products',
                        ModalRoute.withName('/home'),
                      );
                      Helper().showNotification(
                        context,
                        AppLocalizations.of(
                          context,
                        ).translate('draft_added_successfully'),
                      );
                    });
                  });
                } finally {
                  setState(() => isLoading = false);
                }
              },
              child: Text(
                AppLocalizations.of(context).translate('save_n_print'),
              ),
            ),
          ],
        );
      },
    );
  }

  //show add customer alert box
  Widget newCustomer() {
    return Scaffold(
      appBar: new AppBar(
        title: Text(AppLocalizations.of(context).translate('create_contact')),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        padding: EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 64,
                          child: Center(
                            child: Icon(
                              Symbols.account_child,
                              color: themeData.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            margin: EdgeInsets.only(left: 16),
                            child: Column(
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Container(
                                      width: 50,
                                      child: TextFormField(
                                        controller: prefix,
                                        style: themeData.textTheme.subtitle2!
                                            .merge(
                                              TextStyle(
                                                color: themeData
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                        decoration: InputDecoration(
                                          hintStyle: themeData
                                              .textTheme
                                              .subtitle2!
                                              .merge(
                                                TextStyle(
                                                  color: themeData
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                          hintText: AppLocalizations.of(
                                            context,
                                          ).translate('prefix'),
                                          border: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: themeData
                                                  .inputDecorationTheme
                                                  .border!
                                                  .borderSide
                                                  .color,
                                            ),
                                          ),
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: themeData
                                                  .inputDecorationTheme
                                                  .enabledBorder!
                                                  .borderSide
                                                  .color,
                                            ),
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: themeData
                                                  .inputDecorationTheme
                                                  .focusedBorder!
                                                  .borderSide
                                                  .color,
                                            ),
                                          ),
                                        ),
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: firstName,
                                        validator: (value) {
                                          if (value!.length < 1) {
                                            return AppLocalizations.of(
                                              context,
                                            ).translate(
                                              'please_enter_your_name',
                                            );
                                          } else {
                                            return null;
                                          }
                                        },
                                        style: themeData.textTheme.subtitle2!
                                            .merge(
                                              TextStyle(
                                                color: themeData
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                        decoration: InputDecoration(
                                          hintStyle: themeData
                                              .textTheme
                                              .subtitle2!
                                              .merge(
                                                TextStyle(
                                                  color: themeData
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                          hintText: AppLocalizations.of(
                                            context,
                                          ).translate('first_name'),
                                          border: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: themeData
                                                  .inputDecorationTheme
                                                  .border!
                                                  .borderSide
                                                  .color,
                                            ),
                                          ),
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: themeData
                                                  .inputDecorationTheme
                                                  .enabledBorder!
                                                  .borderSide
                                                  .color,
                                            ),
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: themeData
                                                  .inputDecorationTheme
                                                  .focusedBorder!
                                                  .borderSide
                                                  .color,
                                            ),
                                          ),
                                        ),
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Container(
                                      width: MySize.screenWidth! * 0.35,
                                      child: TextFormField(
                                        controller: middleName,
                                        style: themeData.textTheme.subtitle2!
                                            .merge(
                                              TextStyle(
                                                color: themeData
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                        decoration: InputDecoration(
                                          hintStyle: themeData
                                              .textTheme
                                              .subtitle2!
                                              .merge(
                                                TextStyle(
                                                  color: themeData
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                          hintText: AppLocalizations.of(
                                            context,
                                          ).translate('middle_name'),
                                          border: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: themeData
                                                  .inputDecorationTheme
                                                  .border!
                                                  .borderSide
                                                  .color,
                                            ),
                                          ),
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: themeData
                                                  .inputDecorationTheme
                                                  .enabledBorder!
                                                  .borderSide
                                                  .color,
                                            ),
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: themeData
                                                  .inputDecorationTheme
                                                  .focusedBorder!
                                                  .borderSide
                                                  .color,
                                            ),
                                          ),
                                        ),
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                      ),
                                    ),
                                    Container(
                                      width: MySize.screenWidth! * 0.35,
                                      child: TextFormField(
                                        controller: lastName,
                                        style: themeData.textTheme.subtitle2!
                                            .merge(
                                              TextStyle(
                                                color: themeData
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                        decoration: InputDecoration(
                                          hintStyle: themeData
                                              .textTheme
                                              .subtitle2!
                                              .merge(
                                                TextStyle(
                                                  color: themeData
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                          hintText: AppLocalizations.of(
                                            context,
                                          ).translate('last_name'),
                                          border: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: themeData
                                                  .inputDecorationTheme
                                                  .border!
                                                  .borderSide
                                                  .color,
                                            ),
                                          ),
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: themeData
                                                  .inputDecorationTheme
                                                  .enabledBorder!
                                                  .borderSide
                                                  .color,
                                            ),
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: themeData
                                                  .inputDecorationTheme
                                                  .focusedBorder!
                                                  .borderSide
                                                  .color,
                                            ),
                                          ),
                                        ),
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: 64,
                            child: Center(
                              child: Icon(
                                Symbols.location_city,
                                color: themeData.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Container(
                              margin: EdgeInsets.only(left: 16),
                              child: Column(
                                children: <Widget>[
                                  TextFormField(
                                    controller: addressLine1,
                                    style: themeData.textTheme.subtitle2!.merge(
                                      TextStyle(
                                        color: themeData.colorScheme.onSurface,
                                      ),
                                    ),
                                    decoration: InputDecoration(
                                      hintStyle: themeData.textTheme.subtitle2!
                                          .merge(
                                            TextStyle(
                                              color: themeData
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                      hintText: AppLocalizations.of(
                                        context,
                                      ).translate('address_line_1'),
                                      border: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: themeData
                                              .inputDecorationTheme
                                              .border!
                                              .borderSide
                                              .color,
                                        ),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: themeData
                                              .inputDecorationTheme
                                              .enabledBorder!
                                              .borderSide
                                              .color,
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: themeData
                                              .inputDecorationTheme
                                              .focusedBorder!
                                              .borderSide
                                              .color,
                                        ),
                                      ),
                                    ),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                  ),
                                  TextFormField(
                                    controller: addressLine2,
                                    style: themeData.textTheme.subtitle2!.merge(
                                      TextStyle(
                                        color: themeData.colorScheme.onSurface,
                                      ),
                                    ),
                                    decoration: InputDecoration(
                                      hintStyle: themeData.textTheme.subtitle2!
                                          .merge(
                                            TextStyle(
                                              color: themeData
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                      hintText: AppLocalizations.of(
                                        context,
                                      ).translate('address_line_2'),
                                      border: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: themeData
                                              .inputDecorationTheme
                                              .border!
                                              .borderSide
                                              .color,
                                        ),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: themeData
                                              .inputDecorationTheme
                                              .enabledBorder!
                                              .borderSide
                                              .color,
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: themeData
                                              .inputDecorationTheme
                                              .focusedBorder!
                                              .borderSide
                                              .color,
                                        ),
                                      ),
                                    ),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: 64,
                            child: Center(
                              child: Icon(
                                Symbols.phone,
                                color: themeData.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Container(
                              margin: EdgeInsets.only(left: 16),
                              child: Column(
                                children: <Widget>[
                                  TextFormField(
                                    controller: mobile,
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value!.length < 1) {
                                        return AppLocalizations.of(
                                          context,
                                        ).translate('please_enter_your_number');
                                      } else {
                                        return null;
                                      }
                                    },
                                    style: themeData.textTheme.subtitle2!.merge(
                                      TextStyle(
                                        color: themeData.colorScheme.onSurface,
                                      ),
                                    ),
                                    decoration: InputDecoration(
                                      hintStyle: themeData.textTheme.subtitle2!
                                          .merge(
                                            TextStyle(
                                              color: themeData
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                      hintText: AppLocalizations.of(
                                        context,
                                      ).translate('phone'),
                                      border: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: themeData
                                              .inputDecorationTheme
                                              .border!
                                              .borderSide
                                              .color,
                                        ),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: themeData
                                              .inputDecorationTheme
                                              .enabledBorder!
                                              .borderSide
                                              .color,
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: themeData
                                              .inputDecorationTheme
                                              .focusedBorder!
                                              .borderSide
                                              .color,
                                        ),
                                      ),
                                    ),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: 64,
                            child: Center(
                              child: Icon(
                                Symbols.location_city,
                                color: themeData.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Container(
                              margin: EdgeInsets.only(left: 16),
                              child: Column(
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Container(
                                        width: MySize.screenWidth! * 0.35,
                                        child: TextFormField(
                                          controller: city,
                                          style: themeData.textTheme.subtitle2!
                                              .merge(
                                                TextStyle(
                                                  color: themeData
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                          decoration: InputDecoration(
                                            hintStyle: themeData
                                                .textTheme
                                                .subtitle2!
                                                .merge(
                                                  TextStyle(
                                                    color: themeData
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                            hintText: AppLocalizations.of(
                                              context,
                                            ).translate('city'),
                                            border: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: themeData
                                                    .inputDecorationTheme
                                                    .border!
                                                    .borderSide
                                                    .color,
                                              ),
                                            ),
                                            enabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: themeData
                                                    .inputDecorationTheme
                                                    .enabledBorder!
                                                    .borderSide
                                                    .color,
                                              ),
                                            ),
                                            focusedBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: themeData
                                                    .inputDecorationTheme
                                                    .focusedBorder!
                                                    .borderSide
                                                    .color,
                                              ),
                                            ),
                                          ),
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                        ),
                                      ),
                                      Container(
                                        width: MySize.screenWidth! * 0.35,
                                        child: TextFormField(
                                          controller: state,
                                          style: themeData.textTheme.subtitle2!
                                              .merge(
                                                TextStyle(
                                                  color: themeData
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                          decoration: InputDecoration(
                                            hintStyle: themeData
                                                .textTheme
                                                .subtitle2!
                                                .merge(
                                                  TextStyle(
                                                    color: themeData
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                            hintText: AppLocalizations.of(
                                              context,
                                            ).translate('state'),
                                            border: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: themeData
                                                    .inputDecorationTheme
                                                    .border!
                                                    .borderSide
                                                    .color,
                                              ),
                                            ),
                                            enabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: themeData
                                                    .inputDecorationTheme
                                                    .enabledBorder!
                                                    .borderSide
                                                    .color,
                                              ),
                                            ),
                                            focusedBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: themeData
                                                    .inputDecorationTheme
                                                    .focusedBorder!
                                                    .borderSide
                                                    .color,
                                              ),
                                            ),
                                          ),
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Container(
                                        width: MySize.screenWidth! * 0.35,
                                        child: TextFormField(
                                          controller: country,
                                          style: themeData.textTheme.subtitle2!
                                              .merge(
                                                TextStyle(
                                                  color: themeData
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                          decoration: InputDecoration(
                                            hintStyle: themeData
                                                .textTheme
                                                .subtitle2!
                                                .merge(
                                                  TextStyle(
                                                    color: themeData
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                            hintText: AppLocalizations.of(
                                              context,
                                            ).translate('country'),
                                            border: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: themeData
                                                    .inputDecorationTheme
                                                    .border!
                                                    .borderSide
                                                    .color,
                                              ),
                                            ),
                                            enabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: themeData
                                                    .inputDecorationTheme
                                                    .enabledBorder!
                                                    .borderSide
                                                    .color,
                                              ),
                                            ),
                                            focusedBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: themeData
                                                    .inputDecorationTheme
                                                    .focusedBorder!
                                                    .borderSide
                                                    .color,
                                              ),
                                            ),
                                          ),
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                        ),
                                      ),
                                      Container(
                                        width: MySize.screenWidth! * 0.35,
                                        child: TextFormField(
                                          controller: zip,
                                          keyboardType: TextInputType.number,
                                          style: themeData.textTheme.subtitle2!
                                              .merge(
                                                TextStyle(
                                                  color: themeData
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                          decoration: InputDecoration(
                                            hintStyle: themeData
                                                .textTheme
                                                .subtitle2!
                                                .merge(
                                                  TextStyle(
                                                    color: themeData
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                            hintText: AppLocalizations.of(
                                              context,
                                            ).translate('zip_code'),
                                            border: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: themeData
                                                    .inputDecorationTheme
                                                    .border!
                                                    .borderSide
                                                    .color,
                                              ),
                                            ),
                                            enabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: themeData
                                                    .inputDecorationTheme
                                                    .enabledBorder!
                                                    .borderSide
                                                    .color,
                                              ),
                                            ),
                                            focusedBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: themeData
                                                    .inputDecorationTheme
                                                    .focusedBorder!
                                                    .borderSide
                                                    .color,
                                              ),
                                            ),
                                          ),
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 16),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 48,
                          ),
                          backgroundColor: themeData.colorScheme.primary,
                        ),
                        onPressed: () async {
                          if (await Helper().checkConnectivity()) {
                            if (_formKey.currentState!.validate()) {
                              String finalName = firstName.text.trim();
                              String mobileNum = mobile.text.trim();

                              // 1. If name is blank, try to fetch from WhatsApp automatically
                              if (finalName.isEmpty && mobileNum.isNotEmpty) {
                                Helper().showNotification(context, "Fetching name from WhatsApp...");
                                var waContact = await WhatsAppService().getContactDetails(mobileNum);
                                if (waContact != null && waContact['name'] != null && waContact['name'].toString().isNotEmpty) {
                                  finalName = waContact['name'];
                                  Helper().showNotification(context, "Found: $finalName");
                                }
                              }

                              // 2. If still blank, use phone number as name
                              if (finalName.isEmpty) {
                                finalName = mobileNum;
                              }

                              Map newCustomer = {
                                'type': 'customer',
                                'prefix': prefix.text,
                                'first_name': finalName,
                                'middle_name': middleName.text,
                                'last_name': lastName.text,
                                'mobile': mobileNum,
                                'address_line_1': addressLine1.text,
                                'address_line_2': addressLine2.text,
                                'city': city.text,
                                'state': state.text,
                                'country': country.text,
                                'zip_code': zip.text,
                              };
                              await CustomerApi().add(newCustomer).then((
                                value,
                              ) {
                                if (value['data'] != null) {
                                  Contact()
                                      .insertContact(
                                        Contact().contactModel(value['data']),
                                      )
                                      .then((value) {
                                        selectCustomer();
                                        selectedCustomer = customerListMap[0];
                                        Navigator.pop(context);
                                        _formKey.currentState!.reset();
                                      });
                                }
                              });
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
                        child: Text(
                          AppLocalizations.of(
                            context,
                          ).translate('add_to_contact').toUpperCase(),
                          style: AppTheme.getTextStyle(
                            themeData.textTheme.bodyText1,
                            color: themeData.colorScheme.onPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //dropdown widget for selecting customer
  Widget customerList() {
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
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodyText2,
                color: themeData.colorScheme.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
      iconEnabledColor: Colors.blue,
      iconDisabledColor: Colors.black,
      onChanged: (newValue) {
        setState(() {
          selectedCustomer = jsonDecode(newValue);
        });
        _updateCustomerDue();
      },
      isExpanded: true,
    );
  }

  _updateCustomerDue() async {
    if (selectedCustomer['id'] != 0) {
      double due = 0.0;
      if (await Helper().checkConnectivity()) {
        try {
          var response = await CustomerApi().getContactDetails(selectedCustomer['id']);
          if (response != null && response['data'] != null && response['data'].isNotEmpty) {
            var contactData = response['data'][0];
            due = double.tryParse((contactData['total_due'] ?? 0).toString()) ?? 0.0;
          } else {
            due = await SellDatabase().getCustomerDue(selectedCustomer['id']);
          }
        } catch (e) {
          due = await SellDatabase().getCustomerDue(selectedCustomer['id']);
        }
      } else {
        due = await SellDatabase().getCustomerDue(selectedCustomer['id']);
      }

      if (mounted) {
        setState(() {
          selectedCustomerDue = due;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          selectedCustomerDue = 0.0;
        });
      }
    }
  }

  selectCustomer() async {
    customerListMap = [
      {'id': 0, 'name': 'select customer', 'mobile': ' - '},
    ];
    List customers = await Contact().get();

    customers.forEach((value) {
      setState(() {
        customerListMap.add({
          'id': value['id'],
          'name': value['name'],
          'mobile': value['mobile'],
        });
      });
      if (value['name'] == 'Walk-In Customer') {
        selectedCustomer = {
          'id': value['id'],
          'name': value['name'],
          'mobile': value['mobile'],
        };
      }
    });
    _updateCustomerDue();
  }
}
