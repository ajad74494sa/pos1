import 'package:intl/intl.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/paymentDatabase.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import 'contact_model.dart';

class InvoicePrinter {
  double subTotal = 0;
  String taxName = 'taxRates';
  double inlineDiscountAmount = 0.0;
  double inlineTaxAmount = 0.0;
  double taxRate = 0;

  Future<void> setTax(taxId) async {
    List taxes = await System().get('tax');
    for (var element in taxes) {
      if (element['id'] == taxId) {
        taxName = element['name'];
        taxRate = double.tryParse(element['amount'].toString()) ?? 0;
        break;
      }
    }
  }

  Map<String, dynamic> calculateTotals({
    required String discountType,
    required double discountValue,
    required double shippingCharges,
  }) {
    double discountAmount = 0;
    if (discountType == "fixed") {
      discountAmount = discountValue;
    } else if (discountType == "percentage") {
      discountAmount = subTotal * (discountValue / 100);
    }

    double amountAfterDiscount = subTotal - discountAmount;
    double taxAmount = amountAfterDiscount * (taxRate / 100);
    double totalAmount = amountAfterDiscount + taxAmount + shippingCharges;

    return {
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
    };
  }

  Future<Ticket> generateTicket(sellId, taxId, context) async {
    await setTax(taxId);

    List sells = await SellDatabase().getSellBySellId(sellId);
    if (sells.isEmpty) throw Exception("Invoice not found");
    var sell = sells[0];
    var customer = await Contact().getCustomerDetailById(sell['contact_id']);
    var businessInfo = await Helper().getFormattedBusinessDetails();
    String symbol = businessInfo['symbol'] ?? '';
    String businessName = businessInfo['name'] ?? 'KHEYAL CAFÉ';
    String businessNameAr = '';
    String taxLabel = businessInfo['taxLabel'] ?? '';
    String taxNumber = businessInfo['taxNumber'] ?? '';

    // Location details
    List locations = await System().get('location');
    var location = locations.firstWhere(
      (element) => element['id'].toString() == sell['location_id']?.toString(),
      orElse: () => null,
    );
    String locationName = location?['name']?.toString() ?? '';
    String locationMobile =
        (location?['mobile'] ?? location?['alternate_number'] ?? '')
            .toString()
            .trim();
    String locationAddress = '';
    if (location != null) {
      locationAddress = [
        location['landmark'],
        location['city'],
        location['state'],
        location['zip_code'],
        location['country'],
      ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    }

    String invoiceNo = sell['invoice_no'];
    String dateTimeStr = sell['transaction_date'];
    String formattedDate = DateFormat("dd-MM-yyyy HH:mm")
        .format(DateTime.parse(dateTimeStr));

    // Products fetch and calculation
    List products = await SellDatabase().get(sellId: sellId);
    subTotal = 0.00;
    inlineDiscountAmount = 0.0;
    inlineTaxAmount = 0.0;

    final profile = await CapabilityProfile.load();
    final Ticket ticket = Ticket(PaperSize.mm80, profile);

    // 1. Logo
    // try {
    //   final ByteData data = await rootBundle.load(
    //     'assets/logo/Blue Modern Up Arrow Illustration Financial Business Logo (1).png',
    //   );
    //   final Uint8List bytes = data.buffer.asUint8List();
    //   final img.Image? image = img.decodeImage(bytes);
    //   if (image != null) {
    //     img.Image resized = img.copyResize(image, width: 220);
    //     // ticket.imageRaster(resized, align: PrintAlign.center);
    //   }
    // } catch (e) {
    //   debugPrint('Error loading logo: $e');
    // }

    // 2. Header
    // await ticket.textRaster(
    //   '$businessName',
    //   style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    //   align: PrintAlign.right,
    // );

    if (locationName.isNotEmpty) {
      await ticket.textRaster(
        locationName,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        align: PrintAlign.center,
      );
    }

    if (locationAddress.isNotEmpty) {
      await ticket.textRaster(
        locationAddress,
        style: const TextStyle(fontSize: 14),
        align: PrintAlign.center,
      );
    }

    if (locationMobile.isNotEmpty) {
      await ticket.textRaster(
        'Mobile: $locationMobile',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        align: PrintAlign.center,
      );
    }

    await ticket.textRaster(
      'فاتوره',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      align: PrintAlign.center,
    );

    // 3. Metadata Info
    await ticket.rowRaster([
      PrintRasterColumn(
        text: AppLocalizations.of(context).translate('invoice_no'),
        flex: 2,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      PrintRasterColumn(text: invoiceNo, flex: 3, align: PrintAlign.right),
    ]);
    await ticket.rowRaster([
      PrintRasterColumn(
        text: AppLocalizations.of(context).translate('date'),
        flex: 1,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      PrintRasterColumn(text: formattedDate, flex: 2, align: PrintAlign.right),
    ]);
    //
    // final user = await System().get('loggedInUser');
    // String salesMan = '${user['first_name']} ${user['last_name'] ?? ''}'.trim();
    // await ticket.rowRaster([
    //   PrintRasterColumn(text: 'مبيعات|Sales Mane', flex: 2, style: const TextStyle(fontWeight: FontWeight.bold)),
    //   PrintRasterColumn(text: salesMan, flex: 3, align: PrintAlign.right),
    // ]);

    await ticket.rowRaster([
      PrintRasterColumn(
        text: AppLocalizations.of(context).translate('customer'),
        flex: 1,
      ),
      PrintRasterColumn( 
        text: customer?['name'],
        flex: 2,
        align: PrintAlign.right,
      ),
    ]);

    if (customer != null && customer['mobile'] != null) {
      await ticket.rowRaster([
        PrintRasterColumn(text: 'Mobile:', flex: 1),
        PrintRasterColumn(
          text: customer['mobile'],
          flex: 2,
          align: PrintAlign.right,
        ),
      ]);
    }
    ticket.separator();

    // 4. Products Table Header
    await ticket.rowRaster([
      PrintRasterColumn(
        text: '#',
        flex: 1,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      PrintRasterColumn(
        text: 'منتج',
        flex: 4,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      PrintRasterColumn(
        text: 'كمية',
        flex: 3,
        align: PrintAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      PrintRasterColumn(
        text: 'سعر الوحدة',
        flex: 2,
        align: PrintAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      PrintRasterColumn(
        text: 'المجموع الكلي',
        flex: 2,
        align: PrintAlign.right,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ]);
    ticket.separator();

    int totalItemsCount = 0;
    for (int i = 0; i < products.length; i++) {
      String productName = products[i]['name'] ?? '';
      double quantity =
          double.tryParse(products[i]['quantity']?.toString() ?? '0') ?? 0;
      totalItemsCount += quantity.toInt();

      var discountAmount =
          double.tryParse(products[i]['discount_amount']?.toString() ?? '0') ??
          0.0;
      var discountType = products[i]['discount_type'] ?? 'fixed';
      var unitPrice =
          double.tryParse(products[i]['unit_price']?.toString() ?? '0') ?? 0.0;
      var taxRateId = products[i]['tax_rate_id'];

      Map<String, dynamic> inlineAmounts = await Helper()
          .calculateTaxAndDiscount(
            discountAmount: discountAmount,
            discountType: discountType,
            unitPrice: unitPrice,
            taxId: taxRateId,
          );

      inlineDiscountAmount += (inlineAmounts['discountAmount'] ?? 0) * quantity;
      inlineTaxAmount += (inlineAmounts['taxAmount'] ?? 0) * quantity;

      String productPriceStr = await Helper().calculateTotal(
        taxId: taxRateId,
        discountAmount: discountAmount,
        discountType: discountType,
        unitPrice: unitPrice,
      );

      double productPrice = double.tryParse(productPriceStr) ?? 0;
      double totalProductPrice = quantity * productPrice;
      subTotal += totalProductPrice;

      // Product Row
      await ticket.rowRaster([
        PrintRasterColumn(text: '${i + 1}', flex: 1),
        PrintRasterColumn(text: productName, flex: 4),
        PrintRasterColumn(
          text: '${quantity.toStringAsFixed(3)}\nPc(s)',
          flex: 3,
          align: PrintAlign.center,
        ),
        PrintRasterColumn(
          text: productPrice.toStringAsFixed(2),
          flex: 2,
          align: PrintAlign.center,
        ),
        PrintRasterColumn(
          text: totalProductPrice.toStringAsFixed(2),
          flex: 2,
          align: PrintAlign.right,
        ),
      ]);
    }
    ticket.separator();

    // 5. Totals Section
    var totals = calculateTotals(
      discountType: sell['discount_type'] ?? 'fixed',
      discountValue: double.tryParse(sell['discount_amount'].toString()) ?? 0,
      shippingCharges:
          double.tryParse(sell['shipping_charges'].toString()) ?? 0,
    );

    double totalAmount = totals['totalAmount'];
    double totalTax = inlineTaxAmount + totals['taxAmount'];
    double totalDiscount = inlineDiscountAmount + totals['discountAmount'];

    await ticket.rowRaster([
      PrintRasterColumn(text: 'Total items', flex: 2, align: PrintAlign.right),
      PrintRasterColumn(
        text: '$totalItemsCount',
        flex: 1,
        align: PrintAlign.right,
      ),
    ]);

    await ticket.rowRaster([
      PrintRasterColumn(
        text: AppLocalizations.of(context).translate('sub_total'),
        flex: 2,
        align: PrintAlign.left,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      PrintRasterColumn(
        text: '${subTotal.toStringAsFixed(2)}' + symbol,
        flex: 1,
        align: PrintAlign.right,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ]);

    if (totalDiscount > 0) {
      await ticket.rowRaster([
        PrintRasterColumn(
          text: AppLocalizations.of(context).translate('discount'),
          flex: 2,
          align: PrintAlign.left,
        ),
        PrintRasterColumn(
          text: '(-) ${totalDiscount.toStringAsFixed(2)} ' + symbol,
          flex: 1,
          align: PrintAlign.right,
        ),
      ]);
    }

    if (totalTax > 0) {
      await ticket.rowRaster([
        PrintRasterColumn(
          text: AppLocalizations.of(context).translate('tax'),
          flex: 2,
          align: PrintAlign.left,
        ),
        PrintRasterColumn(
          text: '(+) ${totalTax.toStringAsFixed(2)} ' + symbol,
          flex: 1,
          align: PrintAlign.right,
        ),
      ]);
    }

    await ticket.rowRaster([
      PrintRasterColumn(
        text: AppLocalizations.of(context).translate('total'),
        flex: 2,
        align: PrintAlign.left,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      PrintRasterColumn(
        text: '${totalAmount.toStringAsFixed(2)} ' + symbol,
        flex: 1,
        align: PrintAlign.right,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ]);

    // 6. Payments
    List paymentList = await PaymentDatabase().get(
      sell['id'],
      allColumns: true,
    );
    double totalPaidAmount = 0.0;
    for (var element in paymentList) {
      double amt = double.tryParse(element['amount'].toString()) ?? 0;
      if (element['is_return'] == 0) {
        totalPaidAmount += amt;
      } else {
        totalPaidAmount -= amt;
      }

      if (amt > 0) {
        String method = element['method'] ?? 'Cash';
        String payDate = DateFormat("dd-MM-yyyy")
            .format(DateTime.parse(dateTimeStr));
        await ticket.rowRaster([
          PrintRasterColumn(
            text: '$method ($payDate)',
            flex: 2,
            align: PrintAlign.right,
          ),
          PrintRasterColumn(
            text: '${amt.toStringAsFixed(2)} ' + symbol,
            flex: 1,
            align: PrintAlign.right,
          ),
        ]);
      }
    }

    await ticket.rowRaster([
      PrintRasterColumn(
        text: AppLocalizations.of(context).translate('paid'),
        flex: 2,
        align: PrintAlign.right,
      ),
      PrintRasterColumn(
        text: '${totalPaidAmount.toStringAsFixed(2)} ' + symbol,
        flex: 1,
        align: PrintAlign.right,
      ),
    ]);

    double dueAmount = totalAmount - totalPaidAmount;
    if (dueAmount < 0) dueAmount = 0;
    if (dueAmount > 0) {
      await ticket.rowRaster([
        PrintRasterColumn(
          text: AppLocalizations.of(context).translate('due'),
          flex: 2,
          align: PrintAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        PrintRasterColumn(
          text: '${dueAmount.toStringAsFixed(2)} ' + symbol,
          flex: 1,
          align: PrintAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ]);
    }

    // ZATCA QR Code
    String qrContent = Helper().generateZatcaQr(
      businessNameAr,
      taxNumber.isNotEmpty ? taxNumber : '123456789012345',
      dateTimeStr,
      totalAmount,
      totalTax,
    );
    ticket.qrcode(qrContent, size: QRSize.size8);

    // 7. Footer
    await ticket.textRaster(
      'جمعتكم احلى جمعه 🖤',
      style: const TextStyle(fontSize: 12),
      align: PrintAlign.center,
    );

    ticket.feed(3);
    ticket.cut();

    return ticket;
  }

  Future<Ticket> generateKitchenTicket(sellId, context) async {
    List sells = await SellDatabase().getSellBySellId(sellId);
    if (sells.isEmpty) throw Exception("Invoice not found");
    var sell = sells[0];

    final user = await System().get('loggedInUser');
    final List joinedLines = await SellDatabase().get(sellId: sellId);

    final profile = await CapabilityProfile.load();
    final Ticket ticket = Ticket(PaperSize.mm80, profile);

    await ticket.textRaster(
      'طلب المطبخ | Kitchen Order',
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      align: PrintAlign.center,
    );

    if (sell != null) {
      await ticket.textRaster(
        'رقم الفاتوره: ${sell['invoice_no']}',
        style: const TextStyle(fontSize: 20),
        align: PrintAlign.left,
      );

      await ticket.textRaster(
        'يوم: ${sell['transaction_date']}',
        style: const TextStyle(fontSize: 18),
        align: PrintAlign.left,
      );

      String salesMan = '${user['first_name']} ${user['last_name'] ?? ''}'
          .trim();
      await ticket.textRaster(
        'Sales Mane: $salesMan',
        style: const TextStyle(fontSize: 18),
        align: PrintAlign.left,
      );
    }

    // Customer Info
    if (sell != null && sell['contact_id'] != null) {
      var customer = await Contact().getCustomerDetailById(sell['contact_id']);
      if (customer != null) {
        await ticket.textRaster(
          'العميل: ${customer['name']}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          align: PrintAlign.left,
        );
      }
    }

    ticket.separator();

    // Items Table Header
    await ticket.rowRaster([
      PrintRasterColumn(
        text: 'منتج | Product',
        flex: 4,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      PrintRasterColumn(
        text: 'كمية | Qty',
        flex: 1,
        align: PrintAlign.right,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
    ]);
    ticket.separator();

    for (var line in joinedLines) {
      double qty = double.tryParse(line['quantity']?.toString() ?? '0') ?? 0.0;

      await ticket.rowRaster([
        PrintRasterColumn(
          text: Helper().trimText(line['name'] ?? 'Product', 20),
          flex: 4,
          style: const TextStyle(fontSize: 22),
        ),
        PrintRasterColumn(
          text: '${qty.toInt()}',
          flex: 1,
          align: PrintAlign.right,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ]);
    }

    ticket.separator();
    ticket.feed(3);
    ticket.cut();

    return ticket;
  }
}
