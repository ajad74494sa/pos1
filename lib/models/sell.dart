import 'dart:convert';
import 'package:synchronized/synchronized.dart';
import 'package:flutter/cupertino.dart';

import '../apis/sell.dart';
import '../apis/contact.dart';
import '../models/contact_model.dart';
import '../models/paymentDatabase.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import '../models/database.dart';
import '../models/variations.dart';

class Sell {
  static final Set<int> _syncingIds = {};
  static final Lock _cartLock = Lock();

  //sync sell
  Future<Map<String, dynamic>> createApiSell({sellId, bool? syncAll, bool? force}) async {
    List salesRaw = (syncAll != null)
        ? await SellDatabase().getNotSyncedSells()
        : await SellDatabase().getSellBySellId(sellId);

    // Atomic filtering of already syncing items
    List sales = [];
    for (var s in salesRaw) {
      int id = s['id'];
      if (!_syncingIds.contains(id) || force == true) {
        _syncingIds.add(id);
        sales.add(s);
      }
    }

    if (sales.isEmpty) return {'success': true};

    Map<String, dynamic> lastResult = {'success': true};
    for (var saleItem in sales) {
      int localId = saleItem['id'];
      Map<String, dynamic> element = Map<String, dynamic>.from(saleItem);

      try {
        // Double check is_synced - if it's already 1 and not forced, skip
        if (element['is_synced'] == 1 && force != true) {
          continue;
        }

        // Mark as "syncing" locally to prevent duplicate parallel calls
        await SellDatabase().updateSells(localId, {'is_synced': 2});

        List products = await SellDatabase().getSellLines(element['id']);
        debugPrint('Sell.createApiSell: Fetching lines for localId: $localId. Found ${products.length} products.');
        
        if (products.isEmpty) {
          debugPrint('Sell.createApiSell: No products found for sellId $localId. Aborting sync for this record.');
          await SellDatabase().updateSells(localId, {'is_synced': 0});
          lastResult = {
            'success': false,
            'error': 'No products found for this sale in local database.'
          };
          continue;
        }

        // Map local product/variation ids to server ids using `variations` table
        try {
          final db = await DbProvider().database;
          List mapped = [];
          for (var p in products) {
            var variationId = p['variation_id'];
            var productId = p['product_id'];
            List rows = [];
            if (variationId != null) {
              rows = await db.query('variations',
                  where: 'variation_id = ?', whereArgs: [variationId]);
            }
            if (rows.isEmpty && productId != null) {
              rows = await db.query('variations',
                  where: 'product_id = ?', whereArgs: [productId]);
            }
            // If still not found, try refreshing variations from server and retry once
            if (rows.isEmpty) {
              try {
                print(
                    'Sell.createApiSell: variation not found locally, refreshing variations from server');
                await Variations().refresh();
                if (variationId != null) {
                  rows = await db.query('variations',
                      where: 'variation_id = ?', whereArgs: [variationId]);
                }
                if (rows.isEmpty && productId != null) {
                  rows = await db.query('variations',
                      where: 'product_id = ?', whereArgs: [productId]);
                }
              } catch (e) {
                print('Sell.createApiSell: failed to refresh variations: $e');
              }
            }
            if (rows.isNotEmpty) {
              var r = rows[0];
              mapped.add({
                'product_id': r['product_id'],
                'variation_id': r['variation_id'],
                'quantity': double.tryParse(p['quantity'].toString()) ?? 1.0,
                'unit_price': double.tryParse(p['unit_price'].toString()) ?? 0.0,
                'tax_rate_id': (p['tax_rate_id'] == 0 || p['tax_rate_id'] == null) ? null : p['tax_rate_id'],
                'discount_amount': double.tryParse((p['discount_amount'] ?? 0.0).toString()) ?? 0.0,
                'discount_type': p['discount_type'] ?? 'fixed',
                'sub_unit_id': null,
                'note': p['note'] ?? ''
              });
            } else {
              // fallback: keep original ids and warn
              mapped.add({
                'product_id': productId,
                'variation_id': variationId,
                'quantity': double.tryParse(p['quantity'].toString()) ?? 1.0,
                'unit_price': double.tryParse(p['unit_price'].toString()) ?? 0.0,
                'tax_rate_id': (p['tax_rate_id'] == 0 || p['tax_rate_id'] == null) ? null : p['tax_rate_id'],
                'discount_amount': double.tryParse((p['discount_amount'] ?? 0.0).toString()) ?? 0.0,
                'discount_type': p['discount_type'] ?? 'fixed',
                'sub_unit_id': null,
                'note': p['note'] ?? ''
              });
              print(
                  'Sell.createApiSell: warning - variation not found locally for ${productId}/${variationId}');
            }
          }
          products = mapped;
          // If any product mapping resulted in null ids, abort this sell create
          bool missing = false;
          for (var p in products) {
            if (p['product_id'] == null || p['variation_id'] == null) {
              missing = true;
              break;
            }
          }
          if (missing) {
            print(
                'Sell.createApiSell: aborting create for sell id ${element['id']} - one or more products missing server ids');
            await SellDatabase().updateSells(localId, {'is_synced': 0});
            lastResult = {
              'success': false,
              'error': 'One or more products missing server IDs. Please sync products and try again.'
            };
            continue; // skip to next sale
          }
        } catch (e) {
          print('Sell.createApiSell: failed to map products: $e');
        }

        //model map for creating new sell
        List payments = await PaymentDatabase().get(element['id']);
        List cleanedPayments = [];
        payments.forEach((p) {
          Map<String, dynamic> cp = {};
          cp['amount'] = double.tryParse(p['amount'].toString()) ?? 0.0;
          String rawMethod = p['method']?.toString().toLowerCase() ?? 'cash';
          if (rawMethod.contains('nfc') || rawMethod.contains('advance')) {
            cp['method'] = 'advance';
            cp['is_advance'] = 1;
            cp['card_type'] = p['card_type'] ?? 'nfc';
            if (p['card_number'] != null && p['card_number'].toString().isNotEmpty) {
              cp['card_number'] = p['card_number'];
            }
            if (p['card_holder_name'] != null && p['card_holder_name'].toString().isNotEmpty) {
              cp['card_holder_name'] = p['card_holder_name'];
            }
          } else if (rawMethod.contains('arb') || rawMethod.contains('rajhi') || rawMethod.contains('online')) {
            cp['method'] = 'card';
            cp['card_type'] = p['card_type'] ?? 'visa';
          } else if (rawMethod.contains('card')) {
            cp['method'] = 'card';
            cp['card_type'] = p['card_type'] ?? 'visa';
            if (p['card_number'] != null && p['card_number'].toString().isNotEmpty) {
              cp['card_number'] = p['card_number'];
            }
          } else {
            cp['method'] = rawMethod;
          }
          cp['note'] = p['note']?.toString() ?? '';
          
          if (p['account_id'] != null && p['account_id'] != 0) {
            cp['account_id'] = int.tryParse(p['account_id'].toString());
          }
          cleanedPayments.add(cp);
        });

        Map<String, dynamic> sale = {
          'location_id': element['location_id'],
          'contact_id':
              (element['contact_id'] == 0) ? null : element['contact_id'],
          'transaction_date': element['transaction_date'],
          'invoice_no': element['invoice_no'],
          'status': element['status'],
          'sub_status': (element['is_quotation'].toString() == '1')
              ? 'draft'
              : null,
          'tax_rate_id':
              (element['tax_rate_id'] == 0) ? null : element['tax_rate_id'],
          'discount_amount': element['discount_amount'],
          'discount_type': element['discount_type'],
          'change_return': element['change_return'],
          'products': products,
          'sale_note': element['sale_note'],
          'staff_note': element['staff_note'],
          'shipping_charges': element['shipping_charges'],
          'shipping_details': element['shipping_details'],
          'is_quotation': element['is_quotation'],
          'final_total': double.tryParse(element['invoice_amount'].toString()) ?? 0.0,
          'payments': cleanedPayments,
        };
        
        // Remove null values from sale object
        sale.removeWhere((key, value) => value == null);

        //fetch paymentLine where is_return = 1
        List paymentDetail = await PaymentDatabase()
            .getPaymentLineByReturnValue(element['id'], 1);
        //set change returnId for updating a sell in API
        var returnId =
            (paymentDetail.length > 0) ? paymentDetail[0]['payment_id'] : null;

        //model map for updating an existing sell
        List updatePayments = await PaymentDatabase()
            .getPaymentLineByReturnValue(element['id'], 0);
        List cleanedUpdatePayments = [];
        updatePayments.forEach((p) {
          Map<String, dynamic> cp = {};
          cp['amount'] = double.tryParse(p['amount'].toString()) ?? 0.0;
          String rawMethod = p['method']?.toString().toLowerCase() ?? 'cash';
          if (rawMethod.contains('nfc') || rawMethod.contains('advance')) {
            cp['method'] = 'advance';
            cp['is_advance'] = 1;
            cp['card_type'] = p['card_type'] ?? 'nfc';
            if (p['card_number'] != null && p['card_number'].toString().isNotEmpty) {
              cp['card_number'] = p['card_number'];
            }
            if (p['card_holder_name'] != null && p['card_holder_name'].toString().isNotEmpty) {
              cp['card_holder_name'] = p['card_holder_name'];
            }
          } else if (rawMethod.contains('arb') || rawMethod.contains('rajhi') || rawMethod.contains('online')) {
            cp['method'] = 'card';
            cp['card_type'] = p['card_type'] ?? 'visa';
          } else if (rawMethod.contains('card')) {
            cp['method'] = 'card';
            cp['card_type'] = p['card_type'] ?? 'visa';
            if (p['card_number'] != null && p['card_number'].toString().isNotEmpty) {
              cp['card_number'] = p['card_number'];
            }
          } else {
            cp['method'] = rawMethod;
          }
          cp['note'] = p['note']?.toString() ?? '';
          
          if (p['account_id'] != null && p['account_id'] != 0) {
            cp['account_id'] = int.tryParse(p['account_id'].toString());
          }
          
          if (p['payment_id'] != null) {
            cp['payment_id'] = p['payment_id'];
          }
          
          cleanedUpdatePayments.add(cp);
        });

        Map<String, dynamic> editedSale = {
          'location_id': element['location_id'],
          'contact_id':
              (element['contact_id'] == 0) ? null : element['contact_id'],
          'transaction_date': element['transaction_date'],
          'status': element['status'],
          'sub_status': (element['is_quotation'].toString() == '1')
              ? 'draft'
              : null,
          'tax_rate_id':
              (element['tax_rate_id'] == 0) ? null : element['tax_rate_id'],
          'discount_amount': double.tryParse((element['discount_amount'] ?? 0.0).toString()) ?? 0.0,
          'discount_type': element['discount_type'] ?? 'percentage',
          'sale_note': element['sale_note'],
          'staff_note': element['staff_note'],
          'shipping_charges': element['shipping_charges'],
          'shipping_details': element['shipping_details'],
          'is_quotation': element['is_quotation'],
          'change_return': double.tryParse(element['change_return'].toString()) ?? 0.0,
          'change_return_id': returnId,
          'products': products,
          'final_total': double.tryParse(element['invoice_amount'].toString()) ?? 0.0,
          'payments': cleanedUpdatePayments,
        };
        
        editedSale.removeWhere((key, value) => value == null);

        if (element['is_synced'] != 1 || force == true) {
          if (element['transaction_id'] != null) {
            print('Sell.createApiSell updating transaction ${element['transaction_id']}');
            print('Sell.createApiSell update payload: ${jsonEncode(editedSale)}');
            try {
              Map<String, dynamic> updatedResult = await SellApi()
                  .update(element['transaction_id'], editedSale);
              
              print('Sell.createApiSell update result: $updatedResult');
              
              if (updatedResult.containsKey('error')) {
                print('Sell.createApiSell update failed: ${updatedResult['error']}');
                await SellDatabase().updateSells(localId, {'is_synced': 0});
                lastResult = {
                  'success': false,
                  'error': updatedResult['error'],
                  'body': updatedResult['body']
                };
                continue;
              }

              if (updatedResult.containsKey('transaction_id') || updatedResult.containsKey('payment_lines')) {
                Map<String, dynamic> updateData = {
                  'is_synced': 1,
                };
                if (updatedResult['invoice_url'] != null && updatedResult['invoice_url'].toString().isNotEmpty) {
                  updateData['invoice_url'] = updatedResult['invoice_url'];
                }
                await SellDatabase().updateSells(element['id'], updateData);
                
                var result = updatedResult['payment_lines'];
                if (result != null) {
                  // Update local payment lines if returned by server
                  await PaymentDatabase().delete(element['id']);
                  for (var paymentLine in result) {
                    await PaymentDatabase().store({
                      'sell_id': element['id'],
                      'method': paymentLine['method'],
                      'amount': paymentLine['amount'],
                      'note': paymentLine['note'],
                      'payment_id': paymentLine['id'],
                      'is_return': paymentLine['is_return'],
                      'account_id': paymentLine['account_id']
                    });
                  }
                }
                lastResult = {'success': true};
              } else {
                print('Sell.createApiSell: update returned no valid response for sell id ${element['id']}');
                await SellDatabase().updateSells(localId, {'is_synced': 0});
                lastResult = {
                  'success': false,
                  'error': 'Server returned an invalid response during update.'
                };
              }
            } catch (e) {
              print(
                  'Sell.createApiSell update failed for transaction ${element['transaction_id']}: $e');
              await SellDatabase().updateSells(localId, {'is_synced': 0});
              lastResult = {
                'success': false,
                'error': e.toString()
              };
            }
          } else {
            Map<String, dynamic> createPayload = {'sells': [sale]};
            print('Sell.createApiSell create payload: $createPayload');
            try {
              var result = await SellApi().create(createPayload);
              if (result != null && result['transaction_id'] != null) {
                int serverTransactionId = result['transaction_id'];
                Map<String, dynamic> updateData = {
                  'is_synced': 1,
                  'transaction_id': serverTransactionId,
                };
                if (result['invoice_url'] != null && result['invoice_url'].toString().isNotEmpty) {
                  updateData['invoice_url'] = result['invoice_url'];
                }
                await SellDatabase().updateSells(element['id'], updateData);

                // Explicitly post advance payment lines to server via sell-payments API
                for (var p in payments) {
                  String m = p['method']?.toString().toLowerCase() ?? '';
                  double amt = double.tryParse(p['amount'].toString()) ?? 0.0;
                  if ((m.contains('nfc') || m.contains('advance')) && amt > 0) {
                    Map<String, dynamic> advancePaymentPayload = {
                      'transaction_id': serverTransactionId,
                      'amount': amt,
                      'method': 'advance',
                      'is_advance': 1,
                      'card_type': p['card_type'] ?? 'nfc',
                      'note': p['note']?.toString() ?? 'NFC Customer Card Payment',
                    };
                    if (p['card_number'] != null && p['card_number'].toString().isNotEmpty) {
                      advancePaymentPayload['card_number'] = p['card_number'];
                    }
                    if (p['card_holder_name'] != null && p['card_holder_name'].toString().isNotEmpty) {
                      advancePaymentPayload['card_holder_name'] = p['card_holder_name'];
                    }
                    if (p['account_id'] != null && p['account_id'] != 0) {
                      advancePaymentPayload['account_id'] = int.tryParse(p['account_id'].toString());
                    }
                    print('Posting advance payment to server via sell-payments API: $advancePaymentPayload');
                    await SellApi().postSellPayment(advancePaymentPayload);
                  }
                }

                // Re-fetch updated customer details from server to keep local SQLite in sync
                if (element['contact_id'] != null && element['contact_id'] != 0) {
                  try {
                    var details = await CustomerApi().getContactDetails(element['contact_id']);
                    if (details != null && details['data'] != null && details['data'].isNotEmpty) {
                      Map<String, dynamic> c = Contact().contactModel(details['data'][0]);
                      await Contact().insertContact(c);
                    }
                  } catch (_) {}
                }

                if (result['payment_lines'] != null) {
                  //delete existing paymentLines with reference to sellId
                  await PaymentDatabase().delete(element['id']);
                  for (var paymentLine in result['payment_lines']) {
                    await PaymentDatabase().store({
                      'sell_id': element['id'],
                      'method': paymentLine['method'],
                      'amount': paymentLine['amount'],
                      'note': paymentLine['note'],
                      'payment_id': paymentLine['id'],
                      'is_return': paymentLine['is_return'],
                      'account_id': paymentLine['account_id']
                    });
                  }
                }
                lastResult = {'success': true};
              } else {
                print(
                    'Sell.createApiSell: create returned null for sell id ${element['id']}');
                await SellDatabase().updateSells(localId, {'is_synced': 0});
                lastResult = {
                  'success': false,
                  'error': 'Server returned an invalid response during create.'
                };
              }
            } catch (e) {
              print(
                  'Sell.createApiSell create failed for sell id ${element['id']}: $e');
              await SellDatabase().updateSells(localId, {'is_synced': 0});
              lastResult = {
                'success': false,
                'error': e.toString()
              };
            }
          }
        }
      } catch (e) {
        print('Sell.createApiSell: unexpected error for sell element: $e');
        await SellDatabase().updateSells(localId, {'is_synced': 0});
        lastResult = {
          'success': false,
          'error': e.toString()
        };
      } finally {
        _syncingIds.remove(localId);
      }
    }
    return lastResult;
  }

  //toMap for creating payment
  Future<void> makePayment(List payments, int sellId) async {
    for (var element in payments) {
      Map<String, dynamic> payment = {
        'sell_id': sellId,
        'method': element['method'],
        'amount': element['amount'],
        'note': element['note'],
        'account_id':
            (element.containsKey('account_id')) ? element['account_id'] : null
      };
      await PaymentDatabase().store(payment);
    }
  }

//toMap create sell
  Future<Map<String, dynamic>> createSell(
      {String? invoiceNo,
      String? transactionDate,
      int? contactId,
      int? locId,
      int? taxId,
      String? discountType,
      double? discountAmount,
      double? invoiceAmount,
      double? changeReturn,
      double? pending,
      String? saleNote,
      String? staffNote,
      double? shippingCharges,
      String? shippingDetails,
      String? saleStatus,
      int? isQuotation,
      int? sellId}) async {
    Map<String, dynamic> sale;
    if (sellId == null) {
      //TODO:dynamic customer name and location name
      sale = {
        'transaction_date': transactionDate,
        'invoice_no': invoiceNo,
        'contact_id': contactId,
        'location_id': locId,
        'status': saleStatus,
        'tax_rate_id': taxId,
        'discount_amount': (discountAmount != null) ? discountAmount : 0.00,
        'discount_type': discountType,
        'invoice_amount': invoiceAmount,
        'change_return': changeReturn,
        'sale_note': saleNote,
        'staff_note': staffNote,
        'shipping_charges': shippingCharges,
        'shipping_details': shippingDetails,
        'pending_amount': pending,
        'is_quotation': isQuotation ?? 0,
        'is_synced': 0,
      };
      return sale;
    } else {
      sale = {
        'contact_id': contactId,
        'transaction_date': transactionDate,
        'location_id': locId,
        'status': saleStatus,
        'tax_rate_id': taxId,
        'discount_amount': (discountAmount != null) ? discountAmount : 0.0,
        'discount_type': discountType,
        'invoice_amount': invoiceAmount,
        'change_return': changeReturn,
        'sale_note': saleNote,
        'staff_note': staffNote,
        'shipping_charges': shippingCharges,
        'shipping_details': shippingDetails,
        'pending_amount': pending,
        'is_quotation': isQuotation ?? 0,
        'is_synced': 0,
      };
      return sale;
    }
  }

  //get unit_price
  getUnitPrice(unitPrice, taxId) async {
    double price = 0.00;
    await System().get('tax').then((value) {
      value.forEach((element) {
        if (element['id'] == taxId) {
          price = (unitPrice * 100) /
              (double.parse(element['amount'].toString()) + 100);
        }
      });
    });
    return price;
  }

/*
*  x + (x*15/100) = 575;
* 100x + 15x = 57500;
* x = 57500/115;
* */

//toMap create sellLine
  addToCart(product, sellId) async {
    return _cartLock.synchronized(() async {
      //convert product to create sellLine
      double price = (product['unit_price'] != null)
          ? double.parse(product['unit_price'].toString())
          : 0.0;

      var sellLine = {
        'sell_id': sellId,
        'product_id': product['product_id'],
        'variation_id': product['variation_id'] ?? product['id'],
        'quantity': product['quantity'] ?? 1.0,
        'unit_price': price,
        'tax_rate_id':
            (product['tax_rate_id'] == 0) ? null : product['tax_rate_id'],
        'discount_amount': product['discount_amount'] ?? 0.00,
        'discount_type': product['discount_type'] ?? 'fixed',
        'note': product['note'] ?? '',
        'is_completed': 0
      };

      //check if item is added to cart/not
      var variationId = sellLine['variation_id'];
      // If variation id is missing, try to find a fallback variation for this product
      if (variationId == null) {
        try {
          final db = await DbProvider().database;
          List rows = await db.query('variations',
              where: 'product_id = ?', whereArgs: [sellLine['product_id']]);
          if (rows.isNotEmpty) {
            variationId = rows[0]['variation_id'];
            sellLine['variation_id'] = variationId;
          } else {
            print(
                'Sell.addToCart: no variation found for product ${sellLine['product_id']}, inserting with null variation_id');
          }
        } catch (e) {
          print('Sell.addToCart: failed to lookup variation fallback: $e');
        }
      }

      // If still no variationId, insert without uniqueness check
      if (variationId == null) {
        await SellDatabase().store(sellLine);
        return;
      }

      List checkSellLine =
          await SellDatabase().checkSellLine(variationId, sellId: sellId);
      //if added increase quantity else addToCart
      if (checkSellLine.length > 0) {
        // Correctly update existing item quantity
        int existingId = checkSellLine[0]['id'];
        double currentQty = double.tryParse(checkSellLine[0]['quantity'].toString()) ?? 0.0;
        double addedQty = double.tryParse(sellLine['quantity'].toString()) ?? 1.0;
        await SellDatabase().update(existingId, {'quantity': currentQty + addedQty});
      } else {
        //insert in database
        await SellDatabase().store(sellLine);
      }
    });
  }

  //Reset cart
  resetCart() async {
    await SellDatabase().deleteInComplete();
  }

  Future<String> cartItemCount({isCompleted, sellId}) async {
    return await SellDatabase()
        .countSellLines(isCompleted: isCompleted, sellId: sellId);
  }

  //refresh sale
  Map<String, dynamic> createSellMap(Map sell, change, pending) {
    Map<String, dynamic> sale = {
      'transaction_date': sell['transaction_date'],
      'invoice_no': sell['invoice_no'],
      'contact_id': sell['contact_id'],
      'location_id': sell['location_id'],
      'status': sell['status'],
      'tax_rate_id': (sell['tax_id'] != 0) ? sell['tax_id'] : null,
      'discount_amount':
          (sell['discount_amount'] != null) ? sell['discount_amount'] : 0.00,
      'discount_type': sell['discount_type'],
      'invoice_amount': sell['final_total'],
      'change_return': change,
      'sale_note': sell['additional_notes'],
      'staff_note': sell['staff_note'],
      'shipping_charges': double.parse(sell['shipping_charges']),
      'shipping_details': sell['shipping_details'],
      'pending_amount': pending,
      'is_synced': 1,
    };
    return sale;
  }
}
