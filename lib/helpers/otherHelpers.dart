
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

// import 'package:call_log/call_log.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cron/cron.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';
// printing removed — print/save functions are no-ops
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../locale/MyLocalizations.dart';
import '../models/database.dart';
import '../models/contact_model.dart';
import '../models/paymentDatabase.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import '../apis/sell.dart';
import '../services/printer_service.dart';
import '../api_end_points.dart';
import 'AppTheme.dart';
import 'SizeConfig.dart';
import 'futuristic_loader.dart';

import '../services/whatsapp_service.dart';

class Helper {
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  static final Map<String, img.Image> _logoCache = {};

  String trimText(String text, int length) {
    if (text.length <= length) return text;
    return text.substring(0, length - 2) + '..';
  }

  // ZATCA TLV Generator
  String generateZatcaQr(String sellerName, String vatNumber, String timestamp, double totalAmount, double vatAmount) {
    BytesBuilder builder = BytesBuilder();
    
    // Tag 1: Seller Name
    builder.addByte(1);
    builder.addByte(utf8.encode(sellerName).length);
    builder.add(utf8.encode(sellerName));

    // Tag 2: VAT Number
    builder.addByte(2);
    builder.addByte(utf8.encode(vatNumber).length);
    builder.add(utf8.encode(vatNumber));

    // Tag 3: Timestamp
    builder.addByte(3);
    builder.addByte(utf8.encode(timestamp).length);
    builder.add(utf8.encode(timestamp));

    // Tag 4: Total Amount
    String totalStr = totalAmount.toStringAsFixed(2);
    builder.addByte(4);
    builder.addByte(utf8.encode(totalStr).length);
    builder.add(utf8.encode(totalStr));

    // Tag 5: VAT Amount
    String vatStr = vatAmount.toStringAsFixed(2);
    builder.addByte(5);
    builder.addByte(utf8.encode(vatStr).length);
    builder.add(utf8.encode(vatStr));

    return base64.encode(builder.toBytes());
  }

  Widget loadingIndicator(BuildContext context, {String? subTitle, bool showBackground = true}) {
    return Center(
      child: Container(
        width: 280,
        height: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: showBackground ? const Color(0xFF050A0A) : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
          border: showBackground ? Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2), width: 1) : null,
          boxShadow: showBackground ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ] : null,
        ),
        alignment: Alignment.center,
        child: FuturisticLoader(
          size: 180,
          subTitle: subTitle ?? 'LOADING...',
          showGrid: showBackground,
        ),
      ),
    );
  }

  void showToast(BuildContext context, String msg) {
    showNotification(context, msg);
  }

  void showNotification(BuildContext context, String message,
      {bool isError = false}) {
    try {
      final overlay = Overlay.of(context);
      if (overlay == null) {
        debugPrint("Notification: $message");
        return;
      }
      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (context) => _NotificationWidget(
          message: message,
          isError: isError,
          onDismiss: () => entry.remove(),
        ),
      );

      overlay.insert(entry);
      Future.delayed(const Duration(seconds: 3), () {
        if (entry.mounted) {
          entry.remove();
        }
      });
    } catch (e) {
      debugPrint("Notification Error: $e");
    }
  }

  //format currency
  String formatCurrency(amount) {
    double convertAmount = double.parse(amount.toString());

    var amt = NumberFormat.currency(
            symbol: '', decimalDigits: Config.currencyPrecision)
        .format(convertAmount);
    return amt;
  }

  double validateInput(String val) {
    try {
      double value = double.parse(val.toString());
      return value;
    } catch (e) {
      return 0.00;
    }
  }

  //format quantity
  String formatQuantity(amount) {
    double quantity = double.parse(amount.toString());
    var amt = NumberFormat.currency(
            symbol: '', decimalDigits: Config.quantityPrecision)
        .format(quantity);
    return amt;
  }

  //argument model
  Map argument(
      {int? sellId,
      int? locId,
      int? taxId,
      String? discountType,
      double? discountAmount,
      double? invoiceAmount,
      int? customerId,
      int? isQuotation}) {
    Map args = {
      'sellId': sellId,
      'locationId': locId,
      'taxId': taxId,
      'discountType': discountType,
      'discountAmount': discountAmount,
      'invoiceAmount': invoiceAmount,
      'customerId': customerId,
      'is_quotation': isQuotation
    };
    return args;
  }

  //check internet connectivity
  Future<bool> checkConnectivity() async {
    final prefs = await SharedPreferences.getInstance();
    bool lowInternetMode = prefs.getBool('low_internet_mode') ?? false;
    if (lowInternetMode) return false; // Treat as offline if forced low mode

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.ethernet)) {
      return true;
    } else {
      return false;
    }
  }

  //get location name by location_id
  Future<String?> getLocationNameById( id) async {
    String? locationName;
    var response = await System().get('location');
    response.forEach((element) {
      if (element['id'] == int.parse(id.toString())) {
        locationName = element['name'];
      }
    });
    return locationName;
  }

  //calculate inline tax and discount amount
  calculateTaxAndDiscount(
      {discountAmount, discountType, taxId, unitPrice}) async {
    double disAmt = 0.0, tax = 0.00, taxAmt = 0.00;
    await System().get('tax').then((value) {
      value.forEach((element) {
        if (element['id'] == taxId) {
          tax = double.parse(element['amount'].toString()) * 1.0;
        }
      });
    });

    if (discountType == 'fixed') {
      disAmt = discountAmount;
      taxAmt = ((unitPrice - discountAmount) * tax / 100);
    } else {
      disAmt = (unitPrice * discountAmount / 100);
      taxAmt = ((unitPrice - (unitPrice * discountAmount / 100)) * tax / 100);
    }
    return {'discountAmount': disAmt, 'taxAmount': taxAmt};
  }

  //calculate price including tax
  calculateTotal({unitPrice, discountType, discountAmount, taxId}) async {
    double tax = 0.00;
    double subTotal = 0.00;
    double amount = 0.0;
    unitPrice = double.parse(unitPrice.toString());
    discountAmount = double.parse(discountAmount.toString());
    //set tax
    await System().get('tax').then((value) {
      value.forEach((element) {
        if (element['id'] == taxId) {
          tax = double.parse(element['amount'].toString()) * 1.0;
        }
      });
    });
    //calculate subTotal according to discount type
    if (discountType == 'fixed') {
      amount = unitPrice - discountAmount;
    } else {
      amount = unitPrice - (unitPrice * discountAmount / 100);
    }
    //calculate subtotal
    subTotal = (amount + (amount * tax / 100));
    return subTotal.toStringAsFixed(2);
  }

  Future<String> barcodeScan() async {
    var result = await BarcodeScanner.scan();
    return result.rawContent.trimRight();
  }

  //function for formatting invoice
  Future<void> printDocument(sellId, taxId, context, {invoice, bool keepAlive = false, bool isManual = false}) async {
    final printerService = PrinterService();
    
    // Auto print logic: skip if printCustomerCopy is off and this is NOT a manual request
    if (!isManual && !printerService.printCustomerCopy) {
      debugPrint("Auto-print customer invoice is disabled. Skipping.");
      return;
    }
    
    // Auto print if printer is configured, else show notification
    if (printerService.customerDevice == null) {
      showNotification(context, "Sale completed. Printer not configured.", isError: false);
      return;
    }
    
    if (!printerService.isPrintingEnabled) {
      showNotification(context, "Sale completed. Printing is disabled.", isError: false);
      return;
    }

    try {
      List sells = await SellDatabase().getSellBySellId(sellId);
      if (sells.isEmpty) return;
      var sell = sells[0];

      var customer = await Contact().getCustomerDetailById(sell['contact_id']);
      var businessInfo = await getFormattedBusinessDetails();
      String symbol = businessInfo['symbol'] ?? '';
      String businessName = businessInfo['name'] ?? 'KHEYAL CAFÉ';
      String businessNameAr = 'مقهى خيال الحقو';
      String taxLabel = businessInfo['taxLabel'] ?? '';
      String taxNumber = businessInfo['taxNumber'] ?? '';

      // Location details
      List locations = await System().get('location');
      var location = locations.firstWhere((element) => element['id'] == sell['location_id'], orElse: () => null);
      String locationAddress = 'FMGF+737, Al Haqu 87261, Al Haqu, Saudi Arabia';
      if (location != null) {
        locationAddress = [
          location['landmark'],
          location['city'],
          location['state'],
          location['zip_code'],
          location['country']
        ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
      }

      String invoiceNo = sell['invoice_no'];
      String invoiceDisplay = invoiceNo;
      if (invoiceNo.contains('-')) {
        var parts = invoiceNo.split('-');
        String year = DateFormat('yyyy').format(DateTime.now());
        invoiceDisplay = "$year-${parts.last}";
      }

      String dateTimeStr = sell['transaction_date'];
      String formattedDate = DateFormat("dd-MM-yyyy HH:mm").format(DateTime.parse(dateTimeStr));

      // Products fetch
      List products = await SellDatabase().get(sellId: sellId);
      double subTotal = 0.00;
      double totalTax = 0.00;
      double totalDiscount = 0.00;

      final profile = await CapabilityProfile.load();
      final Ticket ticket = Ticket(PaperSize.mm80, profile);

      // 1. Logo
      try {
        final ByteData data = await rootBundle.load('assets/logo/Blue Modern Up Arrow Illustration Financial Business Logo (1).png');
        final Uint8List bytes = data.buffer.asUint8List();
        final img.Image? image = img.decodeImage(bytes);
        if (image != null) {
          img.Image resized = img.copyResize(image, width: 200);
          ticket.imageRaster(resized, align: PrintAlign.center);
        }
      } catch (e) {
        debugPrint('Error loading logo: $e');
      }

      // 2. Header
      await ticket.textRaster('$businessNameAr | $businessName',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold), 
          align: PrintAlign.center);
      
      await ticket.textRaster(locationAddress, 
          style: const TextStyle(fontSize: 18), 
          align: PrintAlign.center);
      
      await ticket.textRaster('Mobile: ${businessInfo['mobile'] ?? '0552561609'}', 
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), 
          align: PrintAlign.center);
      
      await ticket.textRaster('فاتوره', 
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), 
          align: PrintAlign.center);

      // 3. Metadata Info
      await ticket.rowRaster([
        PrintRasterColumn(text: 'رقم الفاتوره', flex: 2, style: const TextStyle(fontWeight: FontWeight.bold)),
        PrintRasterColumn(text: invoiceDisplay, flex: 3, align: PrintAlign.right),
      ]);
      await ticket.rowRaster([
        PrintRasterColumn(text: 'يوم', flex: 1, style: const TextStyle(fontWeight: FontWeight.bold)),
        PrintRasterColumn(text: formattedDate, flex: 2, align: PrintAlign.right),
      ]);
      
      final user = await System().get('loggedInUser');
      String salesMan = '${user['surname'] ?? ''} ${user['first_name']} ${user['last_name'] ?? ''}'.trim();
      await ticket.rowRaster([
        PrintRasterColumn(text: 'مبيعات|Sales Mane', flex: 2, style: const TextStyle(fontWeight: FontWeight.bold)),
        PrintRasterColumn(text: salesMan, flex: 3, align: PrintAlign.right),
      ]);

      await ticket.rowRaster([
        PrintRasterColumn(text: 'Table', flex: 1, style: const TextStyle(fontWeight: FontWeight.bold)),
        PrintRasterColumn(text: '1', flex: 1, align: PrintAlign.right),
      ]);

      if (customer != null) {
        await ticket.rowRaster([
          PrintRasterColumn(text: 'اسم العميل', flex: 1),
          PrintRasterColumn(text: customer['name'] ?? '', flex: 2, align: PrintAlign.right),
        ]);
        if (customer['mobile'] != null) {
          await ticket.rowRaster([
            PrintRasterColumn(text: 'Mobile', flex: 1),
            PrintRasterColumn(text: customer['mobile'], flex: 2, align: PrintAlign.right),
          ]);
        }
      }

      await ticket.rowRaster([
        PrintRasterColumn(text: 'Reward', flex: 1),
        PrintRasterColumn(text: '168', flex: 1, align: PrintAlign.right),
      ]);

      ticket.separator();

      // 4. Products Table
      await ticket.rowRaster([
        PrintRasterColumn(text: '#', flex: 1, style: const TextStyle(fontWeight: FontWeight.bold)),
        PrintRasterColumn(text: 'منتج', flex: 4, style: const TextStyle(fontWeight: FontWeight.bold)),
        PrintRasterColumn(text: 'كمية', flex: 3, align: PrintAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        PrintRasterColumn(text: 'سعر الوحدة', flex: 2, align: PrintAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        PrintRasterColumn(text: 'المجموع الكلي', flex: 2, align: PrintAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]);
      ticket.separator();

      int totalItemsCount = 0;
      for (int i = 0; i < products.length; i++) {
        double quantity = double.tryParse(products[i]['quantity']?.toString() ?? '0') ?? 0;
        totalItemsCount += quantity.toInt();
        
        var dAmount = double.tryParse(products[i]['discount_amount']?.toString() ?? '0') ?? 0.0;
        var dType = products[i]['discount_type'] ?? 'fixed';
        var uPrice = double.tryParse(products[i]['unit_price']?.toString() ?? '0') ?? 0.0;
        var tRateId = products[i]['tax_rate_id'];

        Map<String, dynamic> inlineAmounts = await calculateTaxAndDiscount(
            discountAmount: dAmount,
            discountType: dType,
            unitPrice: uPrice,
            taxId: tRateId);
            
        totalDiscount += (inlineAmounts['discountAmount'] ?? 0) * quantity;
        totalTax += (inlineAmounts['taxAmount'] ?? 0) * quantity;
        
        String productPriceStr = await calculateTotal(
            taxId: tRateId,
            discountAmount: dAmount,
            discountType: dType,
            unitPrice: uPrice);
        
        double productPrice = double.tryParse(productPriceStr) ?? 0;
        double totalProductPrice = quantity * productPrice;
        subTotal += totalProductPrice;

        await ticket.rowRaster([
          PrintRasterColumn(text: '${i + 1}', flex: 1),
          PrintRasterColumn(text: products[i]['name'] ?? '', flex: 4),
          PrintRasterColumn(text: '${quantity.toStringAsFixed(3)}\nPc(s)', flex: 3, align: PrintAlign.center),
          PrintRasterColumn(text: productPrice.toStringAsFixed(2), flex: 2, align: PrintAlign.center),
          PrintRasterColumn(text: totalProductPrice.toStringAsFixed(2), flex: 2, align: PrintAlign.right),
        ]);
      }
      ticket.separator();

      // 5. Summary
      double finalTotal = (double.tryParse(sell['invoice_amount']?.toString() ?? '0') ?? 0.0);

      await ticket.rowRaster([
        PrintRasterColumn(text: 'Total items', flex: 2, align: PrintAlign.right),
        PrintRasterColumn(text: '$totalItemsCount', flex: 1, align: PrintAlign.right),
      ]);

      await ticket.rowRaster([
        PrintRasterColumn(text: 'Subtotal|المجموع الكلي:', flex: 2, align: PrintAlign.left, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        PrintRasterColumn(text: '${subTotal.toStringAsFixed(2)} ريال', flex: 1, align: PrintAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ]);

      await ticket.rowRaster([
        PrintRasterColumn(text: 'Total | المجموع:', flex: 2, align: PrintAlign.left, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        PrintRasterColumn(text: '${finalTotal.toStringAsFixed(2)} ريال', flex: 1, align: PrintAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      ]);
      
      // 6. Payments
      List paymentList = await PaymentDatabase().get(sell['id'], allColumns: true);
      double totalPaidAmount = 0.0;
      for (var element in paymentList) {
        double amt = double.tryParse(element['amount'].toString()) ?? 0;
        if (element['is_return'] == 0) totalPaidAmount += amt;
        else totalPaidAmount -= amt;
        
        if (amt > 0) {
          String method = element['method'] ?? 'Cash';
          String payDate = formattedDate.split(' ')[0];
          await ticket.rowRaster([
            PrintRasterColumn(text: '$method ($payDate)', flex: 2, align: PrintAlign.right),
            PrintRasterColumn(text: '${amt.toStringAsFixed(2)} ريال', flex: 1, align: PrintAlign.right),
          ]);
        }
      }

      await ticket.rowRaster([
        PrintRasterColumn(text: 'مجموع المبلغ المدفوع', flex: 2, align: PrintAlign.right),
        PrintRasterColumn(text: '${totalPaidAmount.toStringAsFixed(2)} ريال', flex: 1, align: PrintAlign.right),
      ]);

      double dueAmount = finalTotal - totalPaidAmount;
      if (dueAmount > 0.01) {
        await ticket.rowRaster([
          PrintRasterColumn(text: 'Total Due|المجموع المستحق', flex: 2, align: PrintAlign.right),
          PrintRasterColumn(text: '${dueAmount.toStringAsFixed(2)} ريال', flex: 1, align: PrintAlign.right),
        ]);
      }

      if (customer != null && customer['total_due'] != null) {
        double totalBalance = double.tryParse(customer['total_due'].toString()) ?? 0.0;
        if (totalBalance > 0.01) {
          await ticket.rowRaster([
            PrintRasterColumn(text: 'Total Due|المجموع المستحق', flex: 2, align: PrintAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            PrintRasterColumn(text: '${totalBalance.toStringAsFixed(2)} ريال', flex: 1, align: PrintAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ]);
        }
      }

      // 7. QR & Footer
      String qrContent = generateZatcaQr(businessNameAr, taxNumber.isNotEmpty ? taxNumber : '123456789012345', dateTimeStr, finalTotal, totalTax);
      ticket.qrcode(qrContent, size: QRSize.size8);
      await ticket.textRaster('جمعتكم أحلى جمعة ❤️', style: const TextStyle(fontSize: 18), align: PrintAlign.center);
      
      ticket.feed(3);
      ticket.cut();

      await printerService.printReceipt(ticket, isKitchen: false, keepAlive: keepAlive);
    } catch (e) {
      print("Printing error: $e");
    }
  }

  // function for formatting kitchen invoice
  Future<void> printKitchenDocument(sellId, context) async {
    final printerService = PrinterService();
    
    if (!printerService.isPrintingEnabled) return;
    
    // Determine target printer
    PrinterDevice? target = printerService.useSeparateKitchenPrinter 
        ? printerService.kitchenDevice 
        : printerService.customerDevice;

    if (target == null) return;

    try {
      List sells = await SellDatabase().getSellBySellId(sellId);
      if (sells.isEmpty) return;
      var sell = sells[0];

      final user = await System().get('loggedInUser');
      final List joinedLines = await SellDatabase().get(sellId: sellId);

      final profile = await CapabilityProfile.load();
      final Ticket ticket = Ticket(PaperSize.mm80, profile);

      await ticket.textRaster('طلب المطبخ | Kitchen Order', 
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        align: PrintAlign.center);

      if (sell != null) {
        await ticket.textRaster('رقم الفاتوره: ${sell['invoice_no']}', 
          style: const TextStyle(fontSize: 20), align: PrintAlign.left);
        
        await ticket.textRaster('يوم: ${sell['transaction_date']}', 
          style: const TextStyle(fontSize: 18), align: PrintAlign.left);

        String salesMan = '${user['first_name']} ${user['last_name'] ?? ''}'.trim();
        await ticket.textRaster('Sales Mane: $salesMan', 
          style: const TextStyle(fontSize: 18), align: PrintAlign.left);
      }
      
      if (sell != null && sell['contact_id'] != null) {
        var customer = await Contact().getCustomerDetailById(sell['contact_id']);
        if (customer != null) {
          await ticket.textRaster('العميل: ${customer['name']}', 
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), align: PrintAlign.left);
        }
      }
      
      ticket.separator();

      await ticket.rowRaster([
        PrintRasterColumn(text: 'منتج | Product', flex: 4, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        PrintRasterColumn(text: 'كمية | Qty', flex: 1, align: PrintAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ]);
      ticket.separator();

      for (var line in joinedLines) {
        double qty = double.tryParse(line['quantity']?.toString() ?? '0') ?? 0.0;

        await ticket.rowRaster([
          PrintRasterColumn(text: trimText(line['name'] ?? 'Product', 20), flex: 4, style: const TextStyle(fontSize: 22)),
          PrintRasterColumn(text: '${qty.toInt()}', flex: 1, align: PrintAlign.right, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ]);
      }
      
      ticket.separator();
      ticket.feed(3);
      ticket.cut();

      await printerService.printReceipt(ticket, isKitchen: true);
    } catch (e) {
      print("Kitchen Printing error: $e");
    }
  }

  // //request permissions
  requestAppPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.storage,
      Permission.camera,
      // Permission.phone
    ].request();
    return statuses;
  }

  //job scheduler
  jobScheduler() {
    if (Config().syncCallLog) {
      final cron = Cron();
      cron.schedule(Schedule.parse('*/${Config.callLogSyncDuration} * * * *'),
          () async {
        syncCallLogs();
      });
    }
  }

  //post call_logs in api
  syncCallLogs() async {
    if (await Permission.phone.status == PermissionStatus.granted) {
      if (Config().syncCallLog && await Helper().checkConnectivity()) {
        // ignore: unused_local_variable
        List recentLogs = [];
        //get last sync time
        var lastSync = await System().callLogLastSyncDateTime();
        //difference between time now and last sync
        int getLogBefore = (lastSync != null)
            ? DateTime.now().difference(DateTime.parse(lastSync)).inMinutes
            : 1440;
        //set 'from' duration for call_log query
        // ignore: unused_local_variable
        int from = DateTime.now()
            .subtract(
                Duration(minutes: (getLogBefore > 1440) ? 1440 : getLogBefore))
            .millisecondsSinceEpoch;
        try {
          // //fetch call_log
          // await CallLog.query(dateFrom: from).then((value) async {
          //   if (value.isNotEmpty) {
          //     value.forEach((element) {
          //       recentLogs.add(CallLogModel().createLog(element));
          //     });
          //     //     //save call_log in api
          //     await FollowUpApi()
          //         .syncCallLog({'call_logs': recentLogs}).then((value) async {
          //       if (value == true) {
          //         System().callLogLastSyncDateTime(true);
          //       }
          //     });
          //   }
          // });
        } catch (e) {}
      }
    }
  }

  //share invoice
  savePdf(sellId, taxId, context, invoiceNo, {invoice}) async {
    print('Helper.savePdf: PDF export/sharing disabled');
  }

  //fetch formatted business details
  Future<Map<String, dynamic>> getFormattedBusinessDetails() async {
    List business = await System().get('business');
    if (business.isEmpty) {
      return {
        'symbol': '',
        'name': 'Business Name',
        'logo': Config().defaultBusinessImage,
        'currencyPrecision': Config.currencyPrecision,
        'quantityPrecision': Config.quantityPrecision,
        'taxLabel': '',
        'taxNumber': ''
      };
    }
    var firstBusiness = business[0];
    String? symbol = firstBusiness['currency'] != null ? firstBusiness['currency']['symbol'] : '',
        name = firstBusiness['name'],
        logo = firstBusiness['logo'],
        taxLabel = firstBusiness['tax_label_1'],
        taxNumber = firstBusiness['tax_number_1'];
    int? currencyPrecision = firstBusiness['currency_precision'],
        quantityPrecision = firstBusiness['quantity_precision'];
    return {
      'symbol': symbol ?? '',
      'name': name ?? '',
      'logo': logo ?? Config().defaultBusinessImage,
      'currencyPrecision': currencyPrecision ?? Config.currencyPrecision,
      'quantityPrecision': quantityPrecision ?? Config.quantityPrecision,
      'taxLabel': (taxLabel != null) ? '$taxLabel : ' : '',
      'taxNumber': (taxNumber != null) ? '$taxNumber' : ''
    };
  }

  // Sync WhatsApp configuration from server Business Settings
  Future<void> syncWhatsAppFromBusinessSettings() async {
    try {
      List business = await System().get('business');
      if (business.isNotEmpty) {
        var businessData = business[0];
        // Check for sms_settings field (Common in Ultimate POS / ERP)
        if (businessData['sms_settings'] != null) {
          var sms = businessData['sms_settings'];
          
          // Map server fields to WhatsApp parameters
          String url = sms['url'] ?? '';
          String apiKey = sms['header_1'] ?? '';
          String sessionId = sms['header_2'] ?? '';

          if (url.isNotEmpty || apiKey.isNotEmpty || sessionId.isNotEmpty) {
            await WhatsAppService().saveConfig(
              baseUrl: url.isNotEmpty ? url : ApiEndPoints.whatsappBaseUrl,
              apiKey: apiKey.isNotEmpty ? apiKey : ApiEndPoints.whatsappApiKey,
              sessionId: sessionId.isNotEmpty ? sessionId : ApiEndPoints.whatsappSessionId,
            );
            print("WhatsApp Config synced from server Business Settings");
          }
        }
      }
    } catch (e) {
      print("Error syncing WhatsApp settings: $e");
    }
  }

  //fetch permission from database
  Future<bool> getPermission(String permissionFor) async {
    bool permission = false;
    var value = await System().getPermission();
    if (value.isNotEmpty) {
      if (value[0] == 'all' || value.contains(permissionFor)) {
        permission = true;
      }
    }
    return permission;
  }

  // Generate reference number based on business settings
  Future<String> generateRefNumber(String type,
      {String? defaultPrefix, int? locationId}) async {
    List business = await System().get('business');
    String prefix = '';

    if (business.isNotEmpty) {
      var businessData = business[0];
      if (businessData['ref_no_prefixes'] != null &&
          businessData['ref_no_prefixes'][type] != null) {
        prefix = businessData['ref_no_prefixes'][type].toString();
      }
    }

    if (defaultPrefix != null && defaultPrefix.isNotEmpty) {
      prefix = defaultPrefix;
    }

    int nextNumber = 1;
    String refYear = DateTime.now().year.toString();

    // Online-first check
    if (type == 'sell' && locationId != null) {
      try {
        if (await checkConnectivity()) {
          String? lastOnlineInv =
              await SellApi().getLatestOnlineInvoiceNumber(locationId);
          if (lastOnlineInv != null && lastOnlineInv.contains('-')) {
            var parts = lastOnlineInv.split('-');
            int? lastNum = int.tryParse(parts.last);
            if (lastNum != null) {
              nextNumber = lastNum + 1;
              String refDigits = nextNumber.toString().padLeft(6, '0');
              return '$refYear-$refDigits';
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching online invoice number: $e');
      }
    }

    final db = await DbProvider().database;
    // Fallback or other types: get the last invoice and increment its number part
    List<Map<String, dynamic>> lastRes =
        await db.query('sell', orderBy: 'id DESC', limit: 1);

    if (lastRes.isNotEmpty) {
      String? lastInv = lastRes.first['invoice_no'];
      if (lastInv != null && lastInv.contains('-')) {
        var parts = lastInv.split('-');
        int? lastNum = int.tryParse(parts.last);
        if (lastNum != null) nextNumber = lastNum + 1;
      } else {
        var result = await db.rawQuery('SELECT COUNT(*) AS count FROM sell');
        nextNumber = (result[0]['count'] as int) + 1;
      }
    } else {
      var result = await db.rawQuery('SELECT COUNT(*) AS count FROM sell');
      nextNumber = (result[0]['count'] as int) + 1;
    }

    String refDigits = nextNumber.toString().padLeft(6, '0');

    if (['contacts', 'business_location', 'username'].contains(type)) {
      return '$prefix$refDigits';
    } else {
      // Format as Year-SequentialNumber (e.g., 2026-000048)
      return '$refYear-$refDigits';
    }
  }

  //call widget
  //make phone call
  makePhoneCall(phone) async {
    if (phone != null && phone != 'null' && phone.toString().isNotEmpty) {
      var url = Uri.parse('tel:$phone');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  Widget callDropdown(context, followUpDetails, List numbers,
      {required String type}) {
    numbers.removeWhere((element) => element.toString() == 'null');
    return Container(
      height: MySize.size36,
      child: PopupMenuButton<String>(
        icon: Icon(
          (type == 'call') ? Symbols.phone : Symbols.whatshot,
          color:
              (type == 'call') ? themeData.colorScheme.primary : Colors.green,
        ),
        onSelected: (value) async {
          if (type == 'call') {
            await launchUrl(Uri.parse('tel:$value'));
          }

          if (type == 'whatsApp') {
            await launchUrl(Uri.parse("https://wa.me/$value"));
          }
        },
        itemBuilder: (BuildContext context) {
          return numbers.map((item) {
            return PopupMenuItem<String>(
              value: item,
              child: Text(
                '$item',
                style: TextStyle(color: Colors.black),
              ),
            );
          }).toList();
        },
      ),
    );
  }

  //noData widget
  noDataWidget(context) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: CachedNetworkImage(
            imageUrl: Config().noDataImage,
            errorWidget: (context, url, error) =>
                Lottie.asset('assets/lottie/empty.json'),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            AppLocalizations.of(context).translate('no_data'),
            style: AppTheme.getTextStyle(
              themeData.textTheme.headlineSmall,
              fontWeight: 600,
              color: themeData.colorScheme.onSurface,
            ),
          ),
        )
      ],
    );
  }

  Future<void> showPrintOptionsDialog(BuildContext context, dynamic sellId, dynamic taxId) async {
    final printerService = PrinterService();
    
    // Send notification logic in background (don't block UI)
    sendWhatsAppNotification(sellId);

    if (!printerService.promptBeforePrinting) {
      bool willPrintCustomer = printerService.printCustomerCopy;
      await printKitchenDocument(sellId, context);
      if (willPrintCustomer) {
        await printDocument(sellId, taxId, context);
      }
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Printing Options'),
        content: const Text('Which documents would you like to print?'),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await printKitchenDocument(sellId, context);
                    await printDocument(sellId, taxId, context);
                  },
                  icon: const Icon(Icons.print),
                  label: const Text('Print Both'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await printDocument(sellId, taxId, context, isManual: true);
                      },
                      child: const Text('Customer Only'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await printKitchenDocument(sellId, context);
                      },
                      child: const Text('Kitchen Only'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Skip Printing'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> sendWhatsAppNotification(dynamic sellId, {bool isServerId = false, bool force = false}) async {
    try {
      final whatsappService = WhatsAppService();
      await whatsappService.sendSaleNotification(sellId, isServerId: isServerId, force: force);
    } catch (e) {
      print("Sales notification error: $e");
    }
  }

  // Quick printer selection dialog
  Future<void> _showPrinterSelectionDialog(BuildContext context, dynamic sellId, dynamic taxId) async {
    final printerService = PrinterService();
    PrinterConnectionType selectedType = PrinterConnectionType.network;
    List<PrinterDevice> devices = [];
    bool isScanning = false;
    final manualIpController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context).translate('printer_configuration')),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<PrinterConnectionType>(
                            isExpanded: true,
                            value: selectedType,
                            items: PrinterConnectionType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type.name.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => selectedType = val);
                            },
                          ),
                        ),
                        IconButton(
                          icon: isScanning 
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                            : Icon(Icons.search),
                          onPressed: isScanning ? null : () async {
                            setState(() { isScanning = true; devices = []; });
                            try {
                              final results = await printerService.manager.scanPrinters(types: {selectedType});
                              setState(() { devices = results; isScanning = false; });
                            } catch (e) {
                              setState(() => isScanning = false);
                            }
                          },
                        ),
                      ],
                    ),
                    if (selectedType == PrinterConnectionType.network) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: manualIpController,
                              decoration: const InputDecoration(
                                hintText: 'Manual IP (e.g. 192.168.1.100)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final ip = manualIpController.text.trim();
                              if (ip.isNotEmpty) {
                                final device = NetworkPrinterDevice(name: 'Network Printer', host: ip);
                                await printerService.setSelectedDevice(device);
                                Navigator.pop(context);
                                printDocument(sellId, taxId, context, isManual: true);
                              }
                            },
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                    Divider(),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 200),
                      child: devices.isEmpty 
                        ? Center(child: Text(isScanning ? 'Scanning...' : 'No printers found'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                              final device = devices[index];
                              return ListTile(
                                leading: Icon(Icons.print),
                                title: Text(device.name),
                                subtitle: Text(device is NetworkPrinterDevice ? device.host : (device is BluetoothPrinterDevice ? device.address : '')),
                                onTap: () async {
                                  await printerService.setSelectedDevice(device);
                                  Navigator.pop(context);
                                  // Retry printing
                                  printDocument(sellId, taxId, context, isManual: true);
                                },
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context).translate('cancel')),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NotificationWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  _NotificationWidgetState createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      right: 20,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isError ? Colors.red.shade800 : Colors.blue.shade700,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isError ? Icons.error : Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.onDismiss,
                  child: const Icon(Icons.close, color: Colors.white70, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

