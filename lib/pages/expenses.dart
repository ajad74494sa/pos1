import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../apis/expenses.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/expenses.dart';
import '../models/system.dart';

class Expense extends StatefulWidget {
  @override
  _ExpenseState createState() => _ExpenseState();
}

class _ExpenseState extends State<Expense> {
  final _formKey = GlobalKey<FormState>();

  List expenseCategories = [],
      expenseSubCategories = [],
      paymentMethods = [],
      paymentAccounts = [],
      locationListMap = [
        {'id': 0, 'name': 'set location'},
      ],
      taxListMap = [
        {'id': 0, 'name': 'Tax rate', 'amount': 0},
      ];
  Map<String, dynamic> selectedLocation = {'id': 0, 'name': 'set location'},
      selectedTax = {'id': 0, 'name': 'Tax rate', 'amount': 0},
      selectedExpenseCategoryId = {'id': 0, 'name': 'Select'},
      selectedExpenseSubCategoryId = {'id': 0, 'name': 'Select'};
  TextEditingController expenseAmount = new TextEditingController(),
      expenseNote = new TextEditingController(),
      payingAmount = new TextEditingController();

  Map<String, dynamic> selectedPaymentAccount = {'id': null, 'name': "None"},
      selectedPaymentMethod = {
        'name': 'name',
        'value': 'value',
        'account_id': null,
      };
  String symbol = '';

  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  @override
  void initState() {
    super.initState();
    setLocationMap();
    setTaxMap();
    setPaymentDetails(selectedLocation['id']);
    Helper().syncCallLogs();
  }

  @override
  void dispose() {
    expenseAmount.dispose();
    expenseNote.dispose();
    payingAmount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xff732a13),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context).translate('expenses'),
          style: AppTheme.getTextStyle(
            themeData.textTheme.titleLarge,
            fontWeight: 700,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: EdgeInsets.all(MySize.size16!),
              child: Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    _buildSectionCard(
                      title: 'General Information',
                      icon: Icons.info_outline,
                      children: [
                        _buildLabel(AppLocalizations.of(context).translate('location')),
                        locations(),
                        SizedBox(height: 16),
                        _buildLabel(AppLocalizations.of(context).translate('tax')),
                        taxes(),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Expense Category',
                      icon: Icons.category_outlined,
                      children: [
                        _buildLabel(AppLocalizations.of(context).translate('expense_categories')),
                        expenseCategory(),
                        SizedBox(height: 16),
                        _buildLabel(AppLocalizations.of(context).translate('sub_categories')),
                        expenseSubCategory(),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Amount & Details',
                      icon: Icons.receipt_long_outlined,
                      children: [
                        TextFormField(
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(context).translate('please_enter_expense_amount');
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            label: AppLocalizations.of(context).translate('expense_amount'),
                            prefixIcon: Icons.attach_money,
                            prefixText: symbol + ' ',
                          ),
                          controller: expenseAmount,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          onChanged: (val) {
                            setState(() {
                              payingAmount.text = val;
                            });
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          decoration: _inputDecoration(
                            label: AppLocalizations.of(context).translate('expense_note'),
                            prefixIcon: Icons.note_alt_outlined,
                          ),
                          controller: expenseNote,
                          maxLines: 2,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Payment Information',
                      icon: Icons.payment_outlined,
                      children: [
                        TextFormField(
                          validator: (value) {
                            if (value == null || value.isEmpty) value = '0.00';
                            if (expenseAmount.text.isEmpty || double.parse(value) > double.parse(expenseAmount.text)) {
                              return AppLocalizations.of(context).translate('enter_valid_payment_amount');
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            label: AppLocalizations.of(context).translate('payment_amount'),
                            prefixIcon: Icons.payments_outlined,
                            prefixText: symbol + ' ',
                          ),
                          controller: payingAmount,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        ),
                        SizedBox(height: 16),
                        _buildLabel(AppLocalizations.of(context).translate('payment_method')),
                        paymentMethodWidget(),
                        SizedBox(height: 16),
                        _buildLabel(AppLocalizations.of(context).translate('payment_account')),
                        paymentAccount(),
                      ],
                    ),
                    SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xff732a13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        onPressed: () async {
                          if (await Helper().checkConnectivity()) {
                            if (_formKey.currentState!.validate()) {
                              onSubmit();
                            }
                          } else {
                            Helper().showNotification(context, AppLocalizations.of(context).translate('check_connectivity'), isError: true);
                          }
                        },
                        child: Text(
                          AppLocalizations.of(context).translate('submit').toUpperCase(),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        color: Color(0xff732a13),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Expense',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Record your business expenses easily',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Color(0xff732a13)),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
                ),
              ],
            ),
            Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blueGrey[600]),
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData prefixIcon, String? prefixText}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(prefixIcon, color: Color(0xff732a13), size: 20),
      prefixText: prefixText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xff732a13))),
      filled: true,
      fillColor: Colors.white,
    );
  }

  setLocationMap() async {
    locationListMap = [];
    await System().get('location').then((value) {
      value.forEach((element) {
        setState(() {
          locationListMap.add({'id': element['id'], 'name': element['name']});
        });
      });
    });
  }

  onSubmit() async {
    if (selectedLocation['id'] != 0) {
      if (expenseAmount.text == '') {
        expenseAmount.text = '0.00';
      }
      if (payingAmount.text == '') {
        payingAmount.text = '0.00';
      }
      var expenseMap = ExpenseManagement().createExpense(
        locId: selectedLocation['id'],
        finalTotal: double.parse(expenseAmount.text),
        amount: double.parse(payingAmount.text),
        method: selectedPaymentMethod['name'],
        accountId: selectedPaymentAccount['id'],
        expenseCategoryId: selectedExpenseCategoryId['id'],
        expenseSubCategoryId: selectedExpenseSubCategoryId['id'],
        taxId: (selectedTax['id'] != 0) ? selectedTax['id'] : null,
        note: expenseNote.text,
      );
      await ExpenseApi().create(expenseMap).then((value) {
        Navigator.pop(context);
        Helper().showNotification(
          context,
          AppLocalizations.of(
            context,
          ).translate('expense_added_successfully'),
        );
      });
    } else {
      Helper().showNotification(
        context,
        AppLocalizations.of(context).translate('error_invalid_location'),
        isError: true,
      );
    }
  }

  Widget locations() {
    return PopupMenuButton(
      onSelected: (item) {
        final Map<String, dynamic> selectedItem = item as Map<String, dynamic>;
        setState(() {
          selectedLocation = selectedItem;
          setExpenseCategories();
          setPaymentDetails(selectedLocation['id']).then((value) {
            if (paymentMethods.isNotEmpty) {
              selectedPaymentMethod = paymentMethods[0];
              selectedPaymentAccount = paymentAccounts[0];
              paymentAccounts.forEach((element) {
                if (selectedPaymentMethod['account_id'] == element['id']) {
                  selectedPaymentAccount = element;
                }
              });
            }
          });
        });
      },
      itemBuilder: (BuildContext context) {
        return locationListMap.map((value) {
          return PopupMenuItem(
            value: value,
            height: MySize.size36!,
            child: Text(
              value['name'],
              style: TextStyle(fontSize: 14),
            ),
          );
        }).toList();
      },
      child: _customDropdownField(selectedLocation['name']),
    );
  }

  setTaxMap() {
    System().get('tax').then((value) {
      value.forEach((element) {
        setState(() {
          taxListMap.add({
            'id': element['id'],
            'name': element['name'],
            'amount': element['amount'],
          });
        });
      });
    });
  }

  Widget taxes() {
    return PopupMenuButton(
      onSelected: (item) {
        setState(() {
          selectedTax = item as Map<String, dynamic>;
        });
      },
      itemBuilder: (BuildContext context) {
        return taxListMap.map((value) {
          return PopupMenuItem(
            value: value,
            height: MySize.size36!,
            child: Text(
              value['name'],
              style: TextStyle(fontSize: 14),
            ),
          );
        }).toList();
      },
      child: _customDropdownField(selectedTax['name']),
    );
  }

  Widget expenseCategory() {
    return PopupMenuButton(
      onSelected: (item) {
        final Map<String, dynamic> selectedItem = item as Map<String, dynamic>;
        setState(() {
          selectedExpenseCategoryId = selectedItem;
          selectedExpenseSubCategoryId = {'id': 0, 'name': 'Select'};
          expenseSubCategories = [];
          if (selectedItem.containsKey('sub_categories') && selectedItem['sub_categories'].length > 0) {
            selectedItem['sub_categories'].forEach((element) {
              expenseSubCategories.add({
                'id': element['id'],
                'name': element['name'],
              });
            });
          }
        });
      },
      itemBuilder: (BuildContext context) {
        return expenseCategories.map((value) {
          return PopupMenuItem(
            value: value,
            height: MySize.size36!,
            child: Text(
              value['name'],
              style: TextStyle(fontSize: 14),
            ),
          );
        }).toList();
      },
      child: _customDropdownField(selectedExpenseCategoryId['name']),
    );
  }

  Widget expenseSubCategory() {
    return PopupMenuButton(
      onSelected: (item) {
        setState(() {
          selectedExpenseSubCategoryId = item as Map<String, dynamic>;
        });
      },
      itemBuilder: (BuildContext context) {
        return expenseSubCategories.map((value) {
          return PopupMenuItem(
            value: value,
            height: MySize.size36!,
            child: Text(
              value['name'],
              style: TextStyle(fontSize: 14),
            ),
          );
        }).toList();
      },
      child: _customDropdownField(selectedExpenseSubCategoryId['name']),
    );
  }

  setExpenseCategories() async {
    await ExpenseApi().get().then((value) {
      setState(() {
        expenseCategories = [];
        value.forEach((element) {
          expenseCategories.add({
            'id': element['id'],
            'name': element['name'],
            'sub_categories': element['sub_categories'],
          });
        });
      });
    });
  }

  setPaymentDetails(int locId) async {
    await Helper().getFormattedBusinessDetails().then((value) {
      setState(() {
        symbol = value['symbol'];
      });
    });
    List payments = await System().get('payment_method', selectedLocation['id']);
    paymentAccounts = [{'id': null, 'name': "None"}];
    await System().getPaymentAccounts().then((value) {
      List<String> accIds = [];
      value.forEach((element) {
        payments.forEach((payment) {
          if ((payment['account_id'].toString() == element['id'].toString()) &&
              !accIds.contains(element['id'].toString())) {
            accIds.add(element['id'].toString());
            paymentAccounts.add({'id': element['id'], 'name': element['name']});
          }
        });
      });
    });
    setState(() {
      paymentMethods = [];
      payments.forEach((element) {
        paymentMethods.add({
          'name': element['name'],
          'value': element['label'],
          'account_id': (element['account_id'] != null) ? int.tryParse(element['account_id'].toString()) : null,
        });
      });
    });
  }

  Widget paymentMethodWidget() {
    return PopupMenuButton(
      onSelected: (item) {
        final Map<String, dynamic> selectedItem = item as Map<String, dynamic>;
        setState(() {
          selectedPaymentMethod = selectedItem;
          selectedPaymentAccount = paymentAccounts[0];
          paymentAccounts.forEach((element) {
            if (selectedPaymentMethod['account_id'] == element['id']) {
              selectedPaymentAccount = element;
            }
          });
        });
      },
      itemBuilder: (BuildContext context) {
        return paymentMethods.map((value) {
          return PopupMenuItem(
            value: value,
            height: MySize.size36!,
            child: Text(
              value['value'],
              style: TextStyle(fontSize: 14),
            ),
          );
        }).toList();
      },
      child: _customDropdownField(selectedPaymentMethod['value']),
    );
  }

  Widget paymentAccount() {
    return PopupMenuButton(
      onSelected: (item) {
        final Map<String, dynamic> selectedItem = item as Map<String, dynamic>;
        setState(() {
          selectedPaymentAccount = selectedItem;
          selectedPaymentMethod['account_id'] = selectedItem['id'];
        });
      },
      itemBuilder: (BuildContext context) {
        return paymentAccounts.map((value) {
          return PopupMenuItem(
            value: value,
            height: MySize.size36!,
            child: Text(
              value['name'],
              style: TextStyle(fontSize: 14),
            ),
          );
        }).toList();
      },
      child: _customDropdownField(selectedPaymentAccount['name']),
    );
  }

  Widget _customDropdownField(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: Colors.blueGrey[800]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.keyboard_arrow_down, color: Color(0xff732a13)),
        ],
      ),
    );
  }
}
