import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:search_choices/search_choices.dart';

import '../apis/contact_payment.dart';
import '../apis/contact.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/contact_model.dart';
import '../models/system.dart';
import '../models/sellDatabase.dart';

class ContactPayment extends StatefulWidget {
  @override
  _ContactPaymentState createState() => _ContactPaymentState();
}

class _ContactPaymentState extends State<ContactPayment> {
  final _formKey = GlobalKey<FormState>();
  int selectedCustomerId = 0;
  List<Map<String, dynamic>> customerListMap = [],
      paymentAccounts = [],
      paymentMethods = [],
      locationListMap = [];
  Map<String, dynamic> selectedLocation = {'id': 0, 'name': 'Select Location'},
      selectedCustomer = {'id': 0, 'name': 'Select Customer', 'mobile': ' - '};
  String due = '0.00';
  Map<String, dynamic> selectedPaymentAccount = {'id': null, 'name': "None"},
      selectedPaymentMethod = {
        'name': 'name',
        'value': 'value',
        'account_id': 1,
      };

  String symbol = '';
  var payingAmount = TextEditingController();
  bool isLoadingDue = false;

  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  @override
  void initState() {
    super.initState();
    selectCustomer().then((_) {
       _handleArguments();
    });
    setPaymentDetails();
    setLocationMap();
    Helper().syncCallLogs();
  }

  void _handleArguments() {
    Future.delayed(Duration.zero, () {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null && args['customer'] != null) {
        var customerArg = args['customer'];
        setState(() {
          // Find matching customer in list to keep it consistent with SearchChoices
          for (var item in customerListMap) {
            if (item['id'].toString() == customerArg['id'].toString()) {
              selectedCustomer = item;
              break;
            }
          }
        });
        _fetchDue(selectedCustomer['id']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: customAppTheme.bgLayer1,
      appBar: AppBar(
        elevation: 0.0,
        backgroundColor: themeData.colorScheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context).translate('contact_payment'),
          style: AppTheme.getTextStyle(
            themeData.textTheme.titleLarge,
            color: Colors.white,
            fontWeight: 600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.all(MySize.size20!),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPaymentForm(),
                      SizedBox(height: MySize.size30),
                      _buildSubmitButton(),
                      SizedBox(height: MySize.size50),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: MySize.size40!, left: MySize.size24!, right: MySize.size24!),
      decoration: BoxDecoration(
        color: themeData.colorScheme.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(MySize.size30!),
          bottomRight: Radius.circular(MySize.size30!),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: MySize.size16!, vertical: MySize.size4!),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(MySize.size12!),
            ),
            child: _customerSelector(),
          ),
          SizedBox(height: MySize.size24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    AppLocalizations.of(context).translate('due').toUpperCase(),
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.bodySmall,
                      color: Colors.red.withAlpha(200),
                      fontWeight: 600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: MySize.size4),
                  isLoadingDue 
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                    "$symbol${Helper().formatCurrency(due)}",
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.headlineMedium,
                      color: Colors.red,
                      fontWeight: 800,
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

  Widget _customerSelector() {
    return SearchChoices.single(
      underline: Container(),
      displayClearIcon: false,
      value: jsonEncode(selectedCustomer),
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      iconEnabledColor: Colors.white,
      items: customerListMap.map<DropdownMenuItem<String>>((Map value) {
        return DropdownMenuItem<String>(
          value: jsonEncode(value),
          child: Text(
            "${value['name']} (${value['mobile'] ?? ' - '})",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          ),
        );
      }).toList(),
      onChanged: (value) async {
        var decoded = jsonDecode(value);
        setState(() => selectedCustomer = decoded);
        _fetchDue(selectedCustomer['id']);
      },
      isExpanded: true,
    );
  }

  Future<void> _fetchDue(int customerId) async {
    if (customerId == 0) return;
    
    setState(() => isLoadingDue = true);
    
    try {
      if (await Helper().checkConnectivity()) {
        // Try getting due from contact-payments endpoint
        var response = await ContactPaymentApi().getCustomerDue(customerId);
        if (response != null && response['data'] != null && response['data'].isNotEmpty) {
          due = response['data'][0]['sell_due'].toString();
        } else {
          // Fallback to customer details endpoint if needed
          var details = await CustomerApi().getContactDetails(customerId);
          if (details != null && details['data'] != null && details['data'].isNotEmpty) {
             due = (details['data'][0]['sell_due'] ?? '0.00').toString();
          }
        }
      } else {
        // Offline fallback
        double offlineDue = await SellDatabase().getCustomerDue(customerId);
        due = offlineDue.toString();
      }
    } catch (e) {
      due = '0.00';
    } finally {
      setState(() {
        selectedCustomerId = customerId;
        isLoadingDue = false;
        _formKey.currentState?.reset();
      });
    }
  }

  Widget _buildPaymentForm() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).translate('payment_details'),
            style: AppTheme.getTextStyle(
              themeData.textTheme.titleMedium,
              fontWeight: 700,
            ),
          ),
          Divider(height: MySize.size30),
          TextFormField(
            controller: payingAmount,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: AppTheme.getTextStyle(
              themeData.textTheme.headlineSmall,
              fontWeight: 700,
              color: themeData.colorScheme.primary,
            ),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).translate('payment_amount'),
              prefixText: symbol,
              prefixStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: themeData.colorScheme.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(MySize.size12!)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MySize.size12!),
                borderSide: BorderSide(color: themeData.colorScheme.primary.withAlpha(40)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MySize.size12!),
                borderSide: BorderSide(color: themeData.colorScheme.primary),
              ),
              filled: true,
              fillColor: themeData.colorScheme.primary.withAlpha(5),
            ),
            validator: (newValue) {
              if (newValue == null || newValue.isEmpty) return 'Required';
              double? amount = double.tryParse(newValue);
              if (amount == null || amount < 0.01) return 'Invalid amount';
              // if (amount > double.parse(due.toString())) return 'Cannot exceed due';
              return null;
            },
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          ),
          SizedBox(height: MySize.size20),
          _buildDropdownField(
            AppLocalizations.of(context).translate('location'),
            locations(),
            Symbols.location_on,
          ),
          SizedBox(height: MySize.size16),
          _buildDropdownField(
            AppLocalizations.of(context).translate('payment_method'),
            paymentOptions(),
            Symbols.payments,
          ),
          SizedBox(height: MySize.size16),
          _buildDropdownField(
            AppLocalizations.of(context).translate('payment_account'),
            paymentAccount(),
            Symbols.account_balance,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, Widget dropdown, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: themeData.colorScheme.onSurface.withAlpha(150)),
            SizedBox(width: 8),
            Text(
              label,
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodySmall,
                fontWeight: 600,
                color: themeData.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        dropdown,
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: themeData.colorScheme.primary,
          padding: EdgeInsets.symmetric(vertical: MySize.size16!),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MySize.size16!)),
          elevation: 4,
        ),
        onPressed: onSubmit,
        child: Text(
          AppLocalizations.of(context).translate('submit').toUpperCase(),
          style: AppTheme.getTextStyle(
            themeData.textTheme.titleMedium,
            color: Colors.white,
            fontWeight: 700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  onSubmit() async {
    if (await Helper().checkConnectivity()) {
      if (_formKey.currentState!.validate()) {
        if (selectedLocation['id'] != 0) {
          setState(() => isLoadingDue = true);
          Map<String, dynamic> paymentMap = {
            "contact_id": selectedCustomerId,
            "amount": double.parse(payingAmount.text),
            "method": selectedPaymentMethod['name'],
            "account_id": selectedPaymentAccount['id'] ?? 1,
            "paid_on": DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now()),
          };
          try {
            var statusCode = await ContactPaymentApi().postContactPayment(paymentMap);
            
            if (statusCode == 200 || statusCode == 201) {
              Helper().showNotification(
                context,
                AppLocalizations.of(context).translate('payment_successful'),
              );

              // Immediately update customer's advance balance and credit limit
              double paidAmount = double.parse(payingAmount.text);
              await Contact().updateAdvanceBalanceLocally(selectedCustomerId, paidAmount);
              try {
                if (await Helper().checkConnectivity()) {
                  var details = await CustomerApi().getContactDetails(selectedCustomerId);
                  if (details != null && details['data'] != null && details['data'].isNotEmpty) {
                    Map<String, dynamic> c = Contact().contactModel(details['data'][0]);
                    await Contact().insertContact(c);
                  }
                }
              } catch (e) {
                print("Error refreshing customer details after payment: $e");
              }

              // Wait a brief moment for the server to update the account perspective
              await Future.delayed(Duration(seconds: 1));
              // Use pushNamedAndRemoveUntil to force a refresh of the home page statistics
              Navigator.of(context).pushNamedAndRemoveUntil('/layout', (route) => false);
            } else {
              setState(() => isLoadingDue = false);
              Helper().showNotification(context, "Failed to post payment. Status: $statusCode", isError: true);
            }
          } catch (e) {
            setState(() => isLoadingDue = false);
            Helper().showNotification(context, "Payment failed: $e", isError: true);
          }
        } else {
          Helper().showNotification(context, AppLocalizations.of(context).translate('error_invalid_location'), isError: true);
        }
      }
    } else {
      Helper().showNotification(context, AppLocalizations.of(context).translate('check_connectivity'), isError: true);
    }
  }

  Widget locations() {
    return _buildPopupButton(
      selectedLocation['name'],
      locationListMap,
      (item) {
        setState(() {
          selectedLocation = item;
          setPaymentDetails().then((_) {
            if (paymentMethods.isNotEmpty) selectedPaymentMethod = paymentMethods[0];
            if (paymentAccounts.isNotEmpty) selectedPaymentAccount = paymentAccounts[0];
          });
        });
      },
    );
  }

  Widget paymentOptions() {
    return _buildPopupButton(
      selectedPaymentMethod['value'],
      paymentMethods,
      (item) {
        setState(() {
          selectedPaymentMethod = item;
          selectedPaymentAccount = paymentAccounts[0];
        });
      },
    );
  }

  Widget paymentAccount() {
    return _buildPopupButton(
      selectedPaymentAccount['name'],
      paymentAccounts,
      (item) {
        setState(() {
          selectedPaymentAccount = item;
          selectedPaymentMethod['account_id'] = item['id'];
        });
      },
    );
  }

  Widget _buildPopupButton(String currentLabel, List items, Function(Map<String, dynamic>) onSelect) {
    return PopupMenuButton(
      onSelected: (item) => onSelect(item as Map<String, dynamic>),
      itemBuilder: (context) => items.map((value) => PopupMenuItem(
        value: value,
        child: Text(value['name'] ?? value['value']),
      )).toList(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: customAppTheme.bgLayer2,
          border: Border.all(color: customAppTheme.bgLayer4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(currentLabel, style: AppTheme.getTextStyle(themeData.textTheme.bodyMedium, fontWeight: 600)),
            Icon(Symbols.expand_more, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> selectCustomer() async {
    customerListMap = [{'id': 0, 'name': 'Select Customer', 'mobile': ' - '}];
    var value = await Contact().get();
    setState(() {
      for (var element in value) {
        customerListMap.add({'id': element['id'], 'name': element['name'], 'mobile': element['mobile']});
      }
    });
  }

  setLocationMap() async {
    locationListMap = [];
    var value = await System().get('location');
    setState(() {
      for (var element in value) {
        locationListMap.add({'id': element['id'], 'name': element['name']});
      }
      if (locationListMap.isNotEmpty) selectedLocation = locationListMap[0];
    });
  }

  setPaymentDetails() async {
    var details = await Helper().getFormattedBusinessDetails();
    setState(() => symbol = details['symbol']);
    
    List payments = await System().get('payment_method', selectedLocation['id']);
    paymentAccounts = [{'id': null, 'name': "None"}];
    
    var accounts = await System().getPaymentAccounts();
    List<String> accIds = [];
    for (var element in accounts) {
      for (var payment in payments) {
        if (payment['account_id'].toString() == element['id'].toString() && !accIds.contains(element['id'].toString())) {
          accIds.add(element['id'].toString());
          paymentAccounts.add({'id': element['id'], 'name': element['name']});
        }
      }
    }
    
    setState(() {
      paymentMethods = payments.map((e) => {'name': e['name'], 'value': e['label'], 'account_id': 1}).toList();
      if (paymentMethods.isNotEmpty && selectedPaymentMethod['name'] == 'name') {
        selectedPaymentMethod = paymentMethods[0];
      }
    });
  }
}
