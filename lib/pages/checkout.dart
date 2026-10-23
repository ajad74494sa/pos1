import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:krpos/helpers/AppTheme.dart';
import 'package:krpos/helpers/otherHelpers.dart';
import 'package:krpos/models/paymentDatabase.dart';
import 'package:krpos/models/sell.dart';
import 'package:krpos/models/sellDatabase.dart';
import 'package:krpos/models/system.dart';
import 'package:krpos/models/database.dart';
import 'package:krpos/models/contact_model.dart';
import 'package:krpos/apis/contact.dart';
import 'package:krpos/services/printer_service.dart';
import 'package:krpos/services/neoleap_service.dart';
import 'package:krpos/services/whatsapp_service.dart';
import 'package:krpos/services/arb_payment_service.dart';
import 'package:krpos/services/nfc_service.dart';

class CheckOut extends StatefulWidget {
  final Map? initialArgument;
  final bool replaceRootOnComplete;

  CheckOut({Key? key, this.initialArgument, this.replaceRootOnComplete = true})
    : super(key: key);

  @override
  CheckOutState createState() => CheckOutState();
}

class CheckOutState extends State<CheckOut> {
  List<Map> paymentMethods = [];
  int? sellId;
  double totalPaying = 0.0;
  String symbol = '',
      transactionDate = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(DateTime.now());
  Map? argument;
  List<Map> payments = [],
      paymentAccounts = [
        {'id': null, 'name': "None"},
      ];
  List<int> deletedPaymentId = [];
  late Map<String, dynamic> paymentLine;
  double invoiceAmount = 0.00, pendingAmount = 0.00, changeReturn = 0.00;
  int totalItems = 0;
  TextEditingController saleNote = TextEditingController(),
      staffNote = TextEditingController(),
      shippingDetails = TextEditingController(),
      shippingCharges = TextEditingController();
  bool saleCreated = false, isLoading = false, _isInitialized = false;

  ThemeData themeData = AppTheme.getThemeFromThemeMode(1);

  @override
  void initState() {
    super.initState();
    getInitDetails();
  }

  getInitDetails() async {
    setState(() => isLoading = true);
    await Helper().getFormattedBusinessDetails().then((value) {
      symbol = value['symbol'];
    });
  }

  @override
  void dispose() {
    saleNote.dispose();
    staffNote.dispose();
    shippingDetails.dispose();
    shippingCharges.dispose();
    for (var payment in payments) {
      payment['controller']?.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      argument =
          widget.initialArgument ??
          ModalRoute.of(context)!.settings.arguments as Map?;
      invoiceAmount = argument!['invoiceAmount'];
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);
    await Future.wait<void>([setPaymentAccounts(), setPaymentDetails()]);

    // Get item count
    if (argument!['sellId'] != null) {
      String count = await SellDatabase().countSellLines(
        sellId: argument!['sellId'],
      );
      totalItems = int.tryParse(count) ?? 0;
      await onEdit(argument!['sellId']);
    } else {
      // For new sales, we might not have a direct DB count yet if it's incomplete
      totalItems = 1; // Default or pass from cart
    }

    // Always ensure at least one payment row exists on first load
    if (payments.isEmpty) {
      _addDefaultPayment(method: argument!['defaultPaymentMethod']);
    }

    if (mounted) {
      setState(() => isLoading = false);
      if (argument!['autoFinalize'] == true) {
        Timer(const Duration(milliseconds: 300), () {
          if (!saleCreated) onSubmit();
        });
      }
    }
  }

  _addDefaultPayment({String? method}) {
    Map? selectedMethod;
    try {
      if (method != null) {
        selectedMethod = paymentMethods.firstWhere(
          (m) => m['name'].toString().toLowerCase() == method.toLowerCase(),
          orElse: () => {},
        );
      }

      if (selectedMethod == null || selectedMethod.isEmpty) {
        selectedMethod = paymentMethods.firstWhere(
          (m) => m['name'].toString().toLowerCase() == 'cash',
          orElse: () => paymentMethods.isNotEmpty ? paymentMethods[0] : {},
        );
      }
    } catch (_) {}

    // Use remaining balance for new rows, or full amount if it's the first row
    double amountToAdd = payments.isEmpty ? invoiceAmount : pendingAmount;

    payments.add({
      'amount': amountToAdd,
      'controller': TextEditingController(text: amountToAdd.toStringAsFixed(2)),
      'method': selectedMethod?['name'] ?? 'cash',
      'note': '',
      'account_id': selectedMethod?['account_id'],
    });
    calculateMultiPayment();
  }

  Future<void> setPaymentAccounts() async {
    paymentAccounts = [
      {'id': null, 'name': "None"},
    ];
    List methods = await System().get(
      'payment_method',
      argument!['locationId'],
    );
    Set<String> assignedAccountIds = {};
    methods.forEach((m) {
      if (m['account_id'] != null)
        assignedAccountIds.add(m['account_id'].toString());
    });

    var value = await System().getPaymentAccounts();
    value.forEach((element) {
      if (assignedAccountIds.contains(element['id'].toString())) {
        paymentAccounts.add({'id': element['id'], 'name': element['name']});
      }
    });
  }

  Future<void> setPaymentDetails() async {
    paymentMethods = [];
    List methods = await System().get(
      'payment_method',
      argument!['locationId'],
    );
    methods.forEach((e) {
      paymentMethods.add({
        'name': e['name'],
        'value': e['label'],
        'account_id': e['account_id'] != null
            ? int.tryParse(e['account_id'].toString())
            : null,
      });
    });

    // Manually add ARB if not already in the list from the server
    bool hasArb = paymentMethods.any((m) => 
      m['name'].toString().toUpperCase().contains('ARB') || 
      m['name'].toString().toUpperCase().contains('RAJHI')
    );

    if (!hasArb) {
      paymentMethods.add({
        'name': 'ARB Online',
        'value': 'ARB Online Payment',
        'account_id': null,
      });
    }

    // Add NFC Customer Card if not present
    bool hasNfc = paymentMethods.any((m) =>
      m['name'].toString().toUpperCase().contains('NFC')
    );

    if (!hasNfc) {
      paymentMethods.add({
        'name': 'NFC Customer Card',
        'value': 'NFC Customer Card',
        'account_id': null,
      });
    }
  }

  calculateMultiPayment() {
    totalPaying = 0.0;
    payments.forEach((e) => totalPaying += (e['amount'] ?? 0.0));
    if (totalPaying > invoiceAmount) {
      changeReturn = totalPaying - invoiceAmount;
      pendingAmount = 0.0;
    } else {
      pendingAmount = invoiceAmount - totalPaying;
      changeReturn = 0.0;
    }
    if (mounted) setState(() {});
  }

  onEdit(sellId) async {
    this.sellId = sellId;
    await SellDatabase().getSellBySellId(sellId).then((value) {
      shippingCharges.text = value[0]['shipping_charges'].toString();
      shippingDetails.text = value[0]['shipping_details'] ?? '';
      saleNote.text = value[0]['sale_note'] ?? '';
      staffNote.text = value[0]['staff_note'] ?? '';
      invoiceAmount =
          argument!['invoiceAmount'] +
          Helper().validateInput(shippingCharges.text);
    });
    for (var payment in payments) {
      payment['controller']?.dispose();
    }
    payments = [];
    List paymentLines = await PaymentDatabase().get(sellId, allColumns: true);
    paymentLines.forEach((element) {
      if (element['is_return'] == 0) {
        payments.add({
          'id': element['id'],
          'amount': element['amount'],
          'controller': TextEditingController(
            text: element['amount'].toStringAsFixed(2),
          ),
          'method': element['method'],
          'note': element['note'],
          'account_id': element['account_id'],
        });
      }
    });
    calculateMultiPayment();
  }

  @override
  Widget build(BuildContext context) {
    themeData = Theme.of(context);
    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: (event) {
        if (event is! RawKeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.f12) {
          if (!saleCreated && !isLoading) onSubmit();
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xff732a13),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Checkout",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        bool isWide = constraints.maxWidth > 750;
                        return isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 2, child: _buildLeftContent()),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 1,
                                    child: _buildRightSummary(isWide: true),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildLeftContent(),
                                  const SizedBox(height: 20),
                                  _buildRightSummary(isWide: false),
                                ],
                              );
                      },
                    ),
                  ),
                ),
                LayoutBuilder(builder: (context, constraints) => _buildFooter(constraints.maxWidth)),
              ],
            ),
            if (isLoading) Helper().loadingIndicator(context, subTitle: 'PROCESSING...'),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Advance Balance: 0.00 $symbol",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 20),
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: payments.length,
          separatorBuilder: (context, index) =>
              Divider(height: 32, color: Colors.transparent),
          itemBuilder: (context, index) => _buildPaymentRow(index),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5011E1),
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => setState(() => _addDefaultPayment()),
            child: Text(
              "Add Payment Row",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(double width) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (width > 400) ...[
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C3E50),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5011E1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              onPressed: isLoading ? null : () {
                if (!saleCreated) onSubmit();
              },
              child: const Text(
                "Finalize Payment",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else ...[
            Expanded(
              flex: 1,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3E50),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: () => Navigator.pop(context),
                child:
                    const Text("Close", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5011E1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: isLoading ? null : () {
                  if (!saleCreated) onSubmit();
                },
                child: const Text(
                  "Finalize Payment",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentRow(int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isCompact = constraints.maxWidth < 450;
        return Container(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
                _buildInputLabelField(
                  "Amount:*",
                  TextFormField(
                    controller: payments[index]['controller'],
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(Symbols.paid),
                    onTap: () {
                      if (payments[index]['controller'].text.isNotEmpty) {
                        payments[index]['controller'].selection = TextSelection(
                          baseOffset: 0,
                          extentOffset:
                              payments[index]['controller'].text.length,
                        );
                      }
                    },
                    onChanged: (val) {
                      payments[index]['amount'] = double.tryParse(val) ?? 0.0;
                      calculateMultiPayment();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildInputLabelField(
                  "Payment Method:*",
                  _buildPaymentMethodDropdown(index),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _buildInputLabelField(
                        "Amount:*",
                        TextFormField(
                          controller: payments[index]['controller'],
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(Symbols.paid),
                          onTap: () {
                            if (payments[index]['controller'].text.isNotEmpty) {
                              payments[index]['controller'].selection =
                                  TextSelection(
                                    baseOffset: 0,
                                    extentOffset:
                                        payments[index]['controller']
                                            .text
                                            .length,
                                  );
                            }
                          },
                          onChanged: (val) {
                            payments[index]['amount'] =
                                double.tryParse(val) ?? 0.0;
                            calculateMultiPayment();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInputLabelField(
                        "Payment Method:*",
                        _buildPaymentMethodDropdown(index),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              _buildInputLabelField(
                "Payment Account:",
                _buildPaymentAccountDropdown(index),
              ),
              if (index > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    label: const Text(
                      "Remove",
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                    onPressed: () => setState(() {
                      if (payments[index]['id'] != null) {
                        deletedPaymentId.add(payments[index]['id']);
                      }
                      payments[index]['controller']?.dispose();
                      payments.removeAt(index);
                      calculateMultiPayment();
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodDropdown(int index) {
    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField<String>(
        dropdownColor: Colors.white,
        value: payments[index]['method'],
        decoration: _inputDecoration(Symbols.wallet),
        style: const TextStyle(color: Colors.black, fontSize: 14),
        items: paymentMethods
            .map(
              (m) => DropdownMenuItem(
                value: m['name'].toString(),
                child: Text(
                  m['value'],
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            )
            .toList(),
        onChanged: (val) {
          setState(() {
            payments[index]['method'] = val;
            var method = paymentMethods.firstWhere(
              (m) => m['name'] == val,
              orElse: () => {},
            );
            if (method.isNotEmpty) {
              payments[index]['account_id'] = method['account_id'];
            }
          });
        },
      ),
    );
  }

  Widget _buildPaymentAccountDropdown(int index) {
    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField<int?>(
        dropdownColor: Colors.white,
        value: payments[index]['account_id'],
        decoration: _inputDecoration(Symbols.account_balance),
        isExpanded: true,
        style: const TextStyle(color: Colors.black, fontSize: 14),
        items: paymentAccounts
            .map(
              (a) => DropdownMenuItem<int?>(
                value: a['id'],
                child: Text(
                  a['name'],
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            )
            .toList(),
        onChanged: (val) => setState(() => payments[index]['account_id'] = val),
      ),
    );
  }

  Widget _buildRightSummary({bool isWide = true}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 24 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF39C12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow(
            "Total Items:",
            totalItems.toStringAsFixed(2),
            "",
            isWide: isWide,
          ),
          _divider(),
          _summaryRow(
            "Total Payable:",
            Helper().formatCurrency(invoiceAmount),
            symbol,
            isWide: isWide,
          ),
          _divider(),
          _summaryRow(
            "Total Paying:",
            Helper().formatCurrency(totalPaying),
            symbol,
            isWide: isWide,
          ),
          _divider(),
          _summaryRow(
            "Change Return:",
            Helper().formatCurrency(changeReturn),
            symbol,
            isWide: isWide,
          ),
          _divider(),
          _summaryRow(
            "Balance:",
            Helper().formatCurrency(pendingAmount),
            symbol,
            isWide: isWide,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value,
    String sym, {
    bool isWide = true,
  }) {
    if (isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "$value $sym",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Text(
            "$value $sym",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      );
    }
  }

  Widget _divider() => Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(color: Colors.white54, thickness: 1),
  );

  Widget _buildInputLabelField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  void _showError(String msg) {
    // Show toast for immediate feedback
    Helper().showNotification(context, msg, isError: true);

    // True Popup Dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text("Action Blocked"),
            ],
          ),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  InputDecoration _inputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
      fillColor: Colors.white,
      filled: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }

  Future<Map<String, dynamic>?> _scanAndVerifyNfcCard(double requiredAmount) async {
    bool isAvailable = await NfcService().isNfcAvailable();
    Completer<Map<String, dynamic>?> completer = Completer();
    TextEditingController manualCardController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String statusText = isAvailable
            ? "Please tap customer's NFC card on the back of the device..."
            : "NFC scanning unavailable on this device.";

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            void verifyAndComplete(String cardUid) async {
              NfcService().stopScanning();
              setDialogState(() {
                statusText = "Card ID ($cardUid). Verifying live balance...";
              });

              Map<String, dynamic>? nfcCustomer;

              // 1. Direct Live Server Search First (if connected)
              if (await Helper().checkConnectivity()) {
                nfcCustomer = await CustomerApi().getContactByCardUid(cardUid);
              }

              // 2. Offline Fallback to Local SQLite Search
              if (nfcCustomer == null) {
                nfcCustomer = await Contact().getCustomerByNfcCard(cardUid);
              }

              if (nfcCustomer == null) {
                if (mounted) {
                  Navigator.pop(dialogCtx);
                  _showError("No customer account found for NFC Card ($cardUid).");
                  if (!completer.isCompleted) completer.complete(null);
                }
                return;
              }

              double advanceBalance = double.tryParse((nfcCustomer['advance_balance'] ?? nfcCustomer['balance'] ?? 0.0).toString()) ?? 0.0;
              double creditLimit = double.tryParse((nfcCustomer['credit_limit'] ?? 0.0).toString()) ?? 0.0;
              double totalDue = double.tryParse((nfcCustomer['total_due'] ?? 0.0).toString()) ?? 0.0;

              double availableCredit = creditLimit > 0 ? (creditLimit - totalDue) : 0.0;
              if (availableCredit < 0) availableCredit = 0.0;
              double totalPurchasingPower = advanceBalance + availableCredit;

              if (requiredAmount > totalPurchasingPower) {
                if (mounted) {
                  Navigator.pop(dialogCtx);
                  _showError(
                    "Insufficient funds for ${nfcCustomer['name']}!\n"
                    "Advance Balance: $symbol${advanceBalance.toStringAsFixed(2)}\n"
                    "Available Credit: $symbol${availableCredit.toStringAsFixed(2)}\n"
                    "Total Power: $symbol${totalPurchasingPower.toStringAsFixed(2)}\n"
                    "Required Amount: $symbol${requiredAmount.toStringAsFixed(2)}",
                  );
                  if (!completer.isCompleted) completer.complete(null);
                }
                return;
              }

              if (mounted) {
                Navigator.pop(dialogCtx);
                if (!completer.isCompleted) completer.complete(nfcCustomer);
              }
            }

            if (isAvailable) {
              NfcService().startScanning(
                onCardScanned: (cardUid) {
                  verifyAndComplete(cardUid);
                },
                onError: (error) {
                  if (mounted) {
                    setDialogState(() {
                      statusText = error;
                    });
                  }
                },
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Symbols.nfc, color: themeData.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text("NFC Customer Card", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAvailable) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeData.colorScheme.primary.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Symbols.contactless, size: 40, color: themeData.colorScheme.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        statusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              "OR",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500]),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Enter Card ID / UID manually:",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: manualCardController,
                      decoration: InputDecoration(
                        hintText: "e.g. E2003410",
                        prefixIcon: const Icon(Symbols.credit_card, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (val) {
                        String manualUid = val.trim();
                        if (manualUid.isNotEmpty) {
                          verifyAndComplete(manualUid);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    NfcService().stopScanning();
                    Navigator.pop(dialogCtx);
                    if (!completer.isCompleted) completer.complete(null);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    String manualUid = manualCardController.text.trim();
                    if (manualUid.isEmpty) {
                      _showError("Please enter a valid Card ID or tap NFC card");
                      return;
                    }
                    verifyAndComplete(manualUid);
                  },
                  child: const Text("Verify & Pay"),
                ),
              ],
            );
          },
        );
      },
    );

    return completer.future;
  }

  Future<void> _deductAdvanceBalanceLocally() async {
    double nfcPaidAmount = 0.0;
    for (var p in payments) {
      String m = p['method'].toString().toLowerCase();
      if (m.contains('nfc') || m.contains('advance')) {
        nfcPaidAmount += (double.tryParse(p['amount'].toString()) ?? 0.0);
      }
    }

    if (nfcPaidAmount > 0 && argument!['customerId'] != null && argument!['customerId'] != 1) {
      int custId = argument!['customerId'];
      try {
        final db = await DbProvider().database;
        await db.rawUpdate(
          'UPDATE contact SET advance_balance = MAX(0, advance_balance - ?) WHERE id = ?',
          [nfcPaidAmount, custId],
        );
      } catch (e) {
        print("Error updating advance_balance locally: $e");
      }

      // Re-fetch updated customer details from server to keep local SQLite in sync
      if (await Helper().checkConnectivity()) {
        try {
          var details = await CustomerApi().getContactDetails(custId);
          if (details != null && details['data'] != null && details['data'].isNotEmpty) {
            Map<String, dynamic> c = Contact().contactModel(details['data'][0]);
            await Contact().insertContact(c);
          }
        } catch (_) {}
      }
    }
  }

  onSubmit() async {
    if (isLoading) return;

    // --- ARB / Al Rajhi Payment Check ---
    bool needsDigitalPayment = payments.any((p) => 
      p['method'].toString().toUpperCase().contains('ARB') || 
      p['method'].toString().toUpperCase().contains('RAJHI') ||
      p['method'].toString().toLowerCase() == 'online'
    );

    if (needsDigitalPayment) {
      if (!(await Helper().checkConnectivity())) {
        _showError("Internet connection required for ARB Payment.");
        return;
      }
      
      String trackId = "TRK-${DateTime.now().millisecondsSinceEpoch}";
      double digitalAmount = 0;
      for (var p in payments) {
        if (p['method'].toString().toUpperCase().contains('ARB') || 
            p['method'].toString().toUpperCase().contains('RAJHI') ||
            p['method'].toString().toLowerCase() == 'online') {
          digitalAmount += (double.tryParse(p['amount'].toString()) ?? 0.0);
        }
      }

      if (digitalAmount > 0) {
        setState(() => isLoading = true);
        
        final String successUrl = "https://payment-callback.success";
        final String errorUrl = "https://payment-callback.error";

        String? paymentId = await ARBPaymentService().initiatePayment(
          amount: digitalAmount.toStringAsFixed(2),
          trackId: trackId,
          successUrl: successUrl,
          errorUrl: errorUrl,
        );

        setState(() => isLoading = false);

        if (paymentId != null) {
          if (paymentId == "ERROR_MISSING_CREDS") {
            _showError("ARB Credentials are missing. Please configure them in your Profile.");
            return;
          }

          // Since we use external browser, we show a confirmation dialog
          bool? paid = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text("Payment in Progress"),
              content: Text("Please complete the payment in your browser and click 'I have Paid' below."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel")),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("I have Paid")),
              ],
            ),
          );

          if (paid != true) {
            _showError("Payment was not completed.");
            return;
          }
        } else {
          _showError("Could not initiate payment. Please check credentials.");
          return;
        }
      }
    }
    // --- End ARB Check ---

    // --- NFC Customer Card Payment Check ---
    bool usesNfc = payments.any((p) =>
      p['method'].toString().toUpperCase().contains('NFC')
    );

    if (usesNfc) {
      double nfcAmount = 0.0;
      for (var p in payments) {
        if (p['method'].toString().toUpperCase().contains('NFC')) {
          nfcAmount += (double.tryParse(p['amount'].toString()) ?? 0.0);
        }
      }

      if (nfcAmount > 0) {
        var nfcCustomer = await _scanAndVerifyNfcCard(nfcAmount);
        if (nfcCustomer == null) {
          return; // Cancelled or failed validation
        }
        // Bind customer ID to the sale arguments
        argument!['customerId'] = nfcCustomer['id'];

        // Bind card_number, card_type, and card_holder_name to payment lines
        String cardUid = (nfcCustomer['custom_field1'] ?? nfcCustomer['nfc_card_id'] ?? '').toString();
        for (var p in payments) {
          if (p['method'].toString().toUpperCase().contains('NFC')) {
            p['card_number'] = cardUid;
            p['card_type'] = 'nfc';
            p['card_holder_name'] = nfcCustomer['name'];
          }
        }
      }
    }
    // --- End NFC Check ---

    // Guard: Prevent due amount based on customer selection and phone number
    if (pendingAmount > 0.01) {
      final customerId = argument!['customerId'];

      // 1. Block Walk-in Customer
      if (customerId == 0 || customerId == 1) {
        _showError(
          "Due amount not allowed for Walk-in Customer. Please select a registered customer.",
        );
        return;
      }

      final customer = await Contact().getCustomerDetailById(customerId);

      // 2. Block if customer not found or has no phone number
      if (customer == null ||
          customer['mobile'] == null ||
          customer['mobile'].toString().trim().isEmpty) {
        _showError(
          "Customer phone number is required for credit sales (due amount).",
        );
        return;
      }

      // 3. Optional: Check for Credit Limit (Only if business uses it)
      double creditLimit =
          double.tryParse((customer['credit_limit'] ?? 0.0).toString()) ?? 0.0;
      double totalDue =
          double.tryParse((customer['total_due'] ?? 0.0).toString()) ?? 0.0;

      // If a credit limit is explicitly set (greater than 0), enforce it.
      if (creditLimit > 0 && (totalDue + pendingAmount) > creditLimit) {
        _showError(
          "Credit limit exceeded. Available credit: $symbol${(creditLimit - totalDue).toStringAsFixed(2)}",
        );
        return;
      }
    }

    setState(() {
      isLoading = true;
      saleCreated = true;
    });

    try {
      String type = (argument!['is_quotation'] == 1) ? 'draft' : 'sell';
      String invoiceNo = await Helper().generateRefNumber(type, locationId: argument!['locationId']);

      Map<String, dynamic> sell = await Sell().createSell(
        invoiceNo: invoiceNo,
        transactionDate: transactionDate,
        changeReturn: changeReturn,
        contactId: argument!['customerId'],
        discountAmount: argument!['discountAmount'],
        discountType: argument!['discountType'],
        invoiceAmount: invoiceAmount,
        locId: argument!['locationId'],
        pending: pendingAmount,
        saleNote: saleNote.text,
        saleStatus: 'final',
        sellId: sellId,
        shippingCharges: Helper().validateInput(shippingCharges.text),
        shippingDetails: shippingDetails.text,
        staffNote: staffNote.text,
        taxId: argument!['taxId'],
        isQuotation: 0,
      );

      if (sellId != null) {
        await SellDatabase().updateSells(sellId, sell);

        // Associate any newly added lines with this sell and mark completed
        // SAFER: Only mark lines that already belong to this sellId
        await SellDatabase().updateSellLine({
          'is_completed': 1,
        }, sellId: sellId);

        // Verify if any items exist before syncing to server
        String itemCount = await SellDatabase().countSellLines(sellId: sellId);
        if (int.parse(itemCount) == 0) {
          _showError("Error: No items found in this sale. Please add items.");
          setState(() => isLoading = false);
          return;
        }

        for (var e in payments) {
          Map<String, dynamic> line = {
            'amount': e['amount'],
            'method': e['method'],
            'note': e['note'],
            'account_id': e['account_id'],
          };
          if (e['id'] != null)
            PaymentDatabase().updateEditedPaymentLine(e['id'], line);
          else {
            line['sell_id'] = sellId;
            PaymentDatabase().store(line);
          }
        }
        if (deletedPaymentId.isNotEmpty)
          PaymentDatabase().deletePaymentLineByIds(deletedPaymentId);

        // Deduct advance balance in local SQLite database
        await _deductAdvanceBalanceLocally();

        // Direct communicate to server: wait for API if connected
        if (await Helper().checkConnectivity()) {
          Sell().createApiSell(sellId: sellId, force: true);
          
          // Send specific "Payment Received" WhatsApp notification for due payments
          double totalPaidThisSession = 0;
          List<String> newMethods = [];
          for (var p in payments) {
            if (p['id'] == null) { // Only count NEW payments added now
               double amt = (double.tryParse(p['amount'].toString()) ?? 0.0);
               if (amt > 0) {
                 totalPaidThisSession += amt;
                 String m = p['method'] ?? 'Cash';
                 if (!newMethods.contains(m)) newMethods.add(m);
               }
            }
          }
          if (totalPaidThisSession > 0) {
            WhatsAppService().sendPaymentNotification(
              sellId: sellId, 
              paidAmount: totalPaidThisSession,
              paymentMethod: newMethods.join(', '),
            );
          }
          
          // Always send the main Sale/Invoice notification (Unless it is a Draft)
          if (type != 'draft') {
            WhatsAppService().sendSaleNotification(sellId);
          }
        } else {
          Helper().showNotification(
            context,
            "Offline: Saved locally. Will sync later.",
          );
        }

        printOption(sellId);
      } else {
        var resp = await SellDatabase().storeSell(sell);
        await Sell().makePayment(payments, resp);

        // Associate incomplete lines with the new sell ID and mark as completed
        await SellDatabase().updateSellLine({
          'sell_id': resp,
          'is_completed': 1,
        }, sellId: null);

        // Verify items exist
        String itemCount = await SellDatabase().countSellLines(sellId: resp);
        if (int.parse(itemCount) == 0) {
          _showError("Error: No items added to cart.");
          setState(() => isLoading = false);
          return;
        }

        if (pendingAmount > 0 && argument!['customerId'] != 1) {
          try {
            final db = await DbProvider().database;
            await db.rawUpdate(
              'UPDATE contact SET total_due = total_due + ? WHERE id = ?',
              [pendingAmount, argument!['customerId']],
            );
          } catch (_) {}
        }

        // Deduct advance balance in local SQLite database
        await _deductAdvanceBalanceLocally();

        // Direct communicate to server: wait for API if connected
        if (await Helper().checkConnectivity()) {
          Sell().createApiSell(sellId: resp, force: true);
          // Send WhatsApp notification in background (Unless it is a Draft)
          if (argument!['is_quotation'] != 1) {
            WhatsAppService().sendSaleNotification(resp);
          }
        } else {
          Helper().showNotification(
            context,
            "Offline: Saved locally. Will sync later.",
          );
        }

        // Print and Notify
        printOption(resp);
      }
    } catch (e) {
      _showError("Checkout failed: $e");
      setState(() {
        isLoading = false;
        saleCreated = false;
      });
    }
  }

  printOption(sellId) async {
    final printerService = PrinterService();

    // 1. Start printing Customer Invoice
    // Using keepAlive if kitchen copy is needed to avoid reconnecting
    bool hasKitchen = printerService.printKitchenCopy;
    await Helper().printDocument(
      sellId,
      argument!['taxId'],
      context,
      keepAlive: hasKitchen,
    );

    // 2. Print Kitchen Order only if enabled
    if (hasKitchen) {
      await Helper().printKitchenDocument(sellId, context);
    }

    // Redirect to home/layout after starting prints
    Timer(const Duration(milliseconds: 500), () async {
      if (widget.replaceRootOnComplete == false) {
        if (mounted) Navigator.pop(context, true);
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/layout',
        ModalRoute.withName('/home'),
        arguments: {'initialIndex': 1},
      );
    });
  }

  Future<bool?> _showPaymentConfirmationDialog(String gatewayName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$gatewayName in Progress"),
        content: Text("Please complete the payment in your browser/app and click 'I have Paid' below."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("I have Paid")),
        ],
      ),
    );
  }
}
