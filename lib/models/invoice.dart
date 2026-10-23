import 'package:intl/intl.dart';

import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/paymentDatabase.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import 'contact_model.dart';

class InvoiceFormatter {
  double subTotal = 0;
  String taxName = 'taxRates';
  double inlineDiscountAmount = 0.0;
  double inlineTaxAmount = 0.0;
  double taxRate = 0;

  Future<String> generateProductDetails(sellId, context) async {
    List products = await SellDatabase().get(sellId: sellId);
    String productHtml = '';
    subTotal = 0.00;
    inlineDiscountAmount = 0.0;
    inlineTaxAmount = 0.0;

    for (int i = 0; i < products.length; i++) {
      String productName = products[i]['name'] ?? '';
      String productSku = products[i]['sub_sku'] ?? '';
      double quantity =
          double.tryParse(products[i]['quantity'].toString()) ?? 0;

      Map<String, dynamic> inlineAmounts = await Helper()
          .calculateTaxAndDiscount(
            discountAmount: products[i]['discount_amount'],
            discountType: products[i]['discount_type'],
            unitPrice: products[i]['unit_price'],
            taxId: products[i]['tax_rate_id'],
          );

      inlineDiscountAmount += (inlineAmounts['discountAmount'] ?? 0) * quantity;
      inlineTaxAmount += (inlineAmounts['taxAmount'] ?? 0) * quantity;

      String productPriceStr = await Helper().calculateTotal(
        taxId: products[i]['tax_rate_id'],
        discountAmount: products[i]['discount_amount'],
        discountType: products[i]['discount_type'],
        unitPrice: products[i]['unit_price'],
      );

      double productPrice = double.tryParse(productPriceStr) ?? 0;
      double totalProductPrice = quantity * productPrice;
      subTotal += totalProductPrice;

      productHtml +=
          '''
          <tr class="bb-dashed">
               <td colspan="4" class="text-left" style="padding: 3px 0;">               
                     <p class="m-0"><strong>$productName</strong> <small>($productSku)</small></p>
                     <p class="m-0" style="display: flex; justify-content: space-between;">
                        <span>${Helper().formatQuantity(quantity)} x ${Helper().formatCurrency(productPrice)}</span>
                        <span><strong>${Helper().formatCurrency(totalProductPrice)}</strong></span>
                     </p>
               </td>
            </tr>
    ''';
    }
    return productHtml;
  }

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

  Future<String> generateInvoice(sellId, taxId, context) async {
    await setTax(taxId);

    List sells = await SellDatabase().getSellBySellId(sellId);
    if (sells.isEmpty) return "Invoice not found";
    var sell = sells[0];

    String productsHtml = await generateProductDetails(sellId, context);
    var customer = await Contact().getCustomerDetailById(sell['contact_id']);

    var businessInfo = await Helper().getFormattedBusinessDetails();
    String symbol = businessInfo['symbol'] ?? '';
    String businessName = businessInfo['name'] ?? '';
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
    String formattedDate = DateFormat("yyyy-MM-dd HH:mm:ss")
        .format(DateTime.parse(dateTimeStr));

    // Calculate amounts
    var totals = calculateTotals(
      discountType: sell['discount_type'] ?? 'fixed',
      discountValue: double.tryParse(sell['discount_amount'].toString()) ?? 0,
      shippingCharges:
          double.tryParse(sell['shipping_charges'].toString()) ?? 0,
    );

    double totalAmount = totals['totalAmount'];
    double totalTax = inlineTaxAmount + totals['taxAmount'];
    double totalDiscount = inlineDiscountAmount + totals['discountAmount'];

    // Payments
    List paymentList = await PaymentDatabase().get(
      sell['id'],
      allColumns: true,
    );
    double totalPaidAmount = 0.0;
    String paymentsHtml = '';
    for (var element in paymentList) {
      double amt = double.tryParse(element['amount'].toString()) ?? 0;
      if (element['is_return'] == 0) {
        totalPaidAmount += amt;
      } else {
        totalPaidAmount -= amt;
      }

      if (amt > 0) {
        paymentsHtml +=
            '''
        <div class="flex-box">
           <p class="width-60 text-left">${element['method']} (${element['is_return'] == 0 ? '+' : '-'})</p>
           <p class="width-40 text-right">$symbol ${Helper().formatCurrency(amt)}</p>
        </div>
        ''';
      }
    }

    double dueAmount = totalAmount - totalPaidAmount;
    if (dueAmount < 0) dueAmount = 0;

    return '''
<section class="invoice print_section" id="receipt_section">
   <meta charset="UTF-8">
   <meta name="viewport" content="width=device-width, initial-scale=1.0">
   <title>Receipt-$invoiceNo</title>
   <div class="ticket">
      <div class="text-center">
         <h2 class="m-0">$businessName</h2>
         ${locationName.isNotEmpty ? '<p class="m-0"><strong>$locationName</strong></p>' : ''}
         ${locationAddress.isNotEmpty ? '<p class="m-0">$locationAddress</p>' : ''}
         ${locationMobile.isNotEmpty ? '<p class="m-0">Mobile: $locationMobile</p>' : ''}
         <p class="m-0"><strong>$taxLabel:</strong> $taxNumber</p>
      </div>
      
      <div class="border-top mt-10">
         <p class="m-0"><strong>${AppLocalizations.of(context).translate('invoice_no')}:</strong> $invoiceNo</p>
         <p class="m-0"><strong>${AppLocalizations.of(context).translate('date')}:</strong> $formattedDate</p>
      </div>

      <div class="border-top mt-10">
         <p class="m-0"><strong>${AppLocalizations.of(context).translate('customer')}:</strong> ${customer['name']}</p>
         <p class="m-0 small">${[customer['address_line_1'], customer['city'], customer['state']].where((e) => e != null).join(', ')}</p>
         <p class="m-0 small">${customer['mobile'] ?? ''}</p>
      </div>

      <table class="width-100 mt-10" style="border-collapse: collapse;">
         <thead>
            <tr class="border-bottom">
               <th class="text-left" colspan="3" style="padding-bottom: 3px;">${AppLocalizations.of(context).translate('products')}</th>
               <th class="text-right" style="padding-bottom: 3px;">${AppLocalizations.of(context).translate('total')}</th>
            </tr>
         </thead> 
         <tbody>
            $productsHtml
         </tbody>
      </table>

      <div class="mt-10" style="border-top: 1px solid #000; padding-top: 5px;">
         <div class="flex-box">
            <p class="text-left">${AppLocalizations.of(context).translate('sub_total')}:</p>
            <p class="text-right">$symbol ${Helper().formatCurrency(subTotal)}</p>
         </div>
         
         ${totalDiscount > 0 ? '''
         <div class="flex-box">
            <p class="text-left">${AppLocalizations.of(context).translate('discount')}:</p>
            <p class="text-right">(-) $symbol ${Helper().formatCurrency(totalDiscount)}</p>
         </div>
         ''' : ''}
         
         ${totalTax > 0 ? '''
         <div class="flex-box">
            <p class="text-left">${AppLocalizations.of(context).translate('tax')}:</p>
            <p class="text-right">(+) $symbol ${Helper().formatCurrency(totalTax)}</p>
         </div>
         ''' : ''}
         
         ${sell['shipping_charges'] > 0 ? '''
         <div class="flex-box">
            <p class="text-left">${AppLocalizations.of(context).translate('shipping')}:</p>
            <p class="text-right">$symbol ${Helper().formatCurrency(sell['shipping_charges'])}</p>
         </div>
         ''' : ''}

         <div class="flex-box border-top-bold mt-5">
            <p class="text-left"><strong>${AppLocalizations.of(context).translate('total')}:</strong></p>
            <p class="text-right"><strong>$symbol ${Helper().formatCurrency(totalAmount)}</strong></p>
         </div>
      </div>

      <div class="border-top mt-10">
         <p class="m-0 small"><strong>${AppLocalizations.of(context).translate('payments')}:</strong></p>
         $paymentsHtml
         <div class="flex-box">
            <p class="text-left">${AppLocalizations.of(context).translate('paid')}:</p>
            <p class="text-right">$symbol ${Helper().formatCurrency(totalPaidAmount)}</p>
         </div>
         ${dueAmount > 0 ? '''
         <div class="flex-box bold" style="background: #f9f9f9; padding: 2px 0;">
            <p class="text-left">${AppLocalizations.of(context).translate('due')}:</p>
            <p class="text-right">$symbol ${Helper().formatCurrency(dueAmount)}</p>
         </div>
         ''' : ''}
      </div>

      <div class="border-top mt-20 text-center">
         <p class="m-0">Thank you for your business!</p>
         <p class="m-0 small">Visit us again</p>
      </div>
   </div>

   <style type="text/css">
      * {
         box-sizing: border-box;
         font-size: 11px;
         font-family: Arial, Helvetica, sans-serif;
         line-height: 1.2;
         color: #000;
      }
      .ticket { width: 100%; max-width: 280px; margin: auto; padding: 4px; }
      h2 { font-size: 16px; line-height: 1.15; }
      p { margin: 2px 0; }
      .text-center { text-align: center; }
      .text-left { text-align: left; }
      .text-right { text-align: right; }
      .width-100 { width: 100%; }
      .m-0 { margin: 0; }
      .mt-5 { margin-top: 5px; }
      .mt-10 { margin-top: 6px; }
      .mt-20 { margin-top: 10px; }
      .bold { font-weight: bold; }
      .border-top { border-top: 1px dashed #000; padding-top: 4px; }
      .border-top-bold { border-top: 1px solid #000; padding-top: 4px; }
      .border-bottom { border-bottom: 1px solid #000; }
      .bb-dashed { border-bottom: 1px dashed #666; }
      .flex-box { display: flex; width: 100%; justify-content: space-between; }
      .small { font-size: 10px; }
      .f-right { float: right; }
      @media print {
         .ticket { width: 72mm; max-width: 72mm; margin: 0; padding: 0; }
         * { font-size: 10px; }
         h2 { font-size: 15px; }
      }
   </style>
</section>
''';
  }
}
