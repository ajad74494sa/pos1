import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_end_points.dart';
import '../models/paymentDatabase.dart';
import '../models/sellDatabase.dart';
import '../models/contact_model.dart';
import '../helpers/otherHelpers.dart';

class WhatsAppService {
  // Prevents sending multiple messages for the same sale ID in one session
  static final Set<String> _sentSaleIds = {};

  Future<Map<String, String>> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'baseUrl': prefs.getString('wa_base_url') ?? ApiEndPoints.whatsappBaseUrl,
      'apiKey': prefs.getString('wa_api_key') ?? ApiEndPoints.whatsappApiKey,
      'sessionId': prefs.getString('wa_session_id') ?? ApiEndPoints.whatsappSessionId,
      'templateSale': prefs.getString('wa_template_sale') ?? 
          "عزيزي {customer_name},\n\n"
          "رقم فاتورتك هو  {invoice_no}\n\n"
          "{invoice_url_section}"
          "المبلغ الإجمالي:  {final_total} {symbol}\n"
          "المبلغ المدفوع: {received_amount} {symbol} ({payment_method})\n"
          "المبلغ المستحق:  {pending_amount} {symbol}\n\n"
          "نشكرك على التسوق معنا.",
      'templatePayment': prefs.getString('wa_template_payment') ??
          "عزيزي {customer_name}،\n\n"
          "رقم فاتورتك هو  {invoice_no}\n"
          "لقد استلمنا مبلغًا قدره {paid_amount} {symbol} عبر {payment_method}\n\n"
          "{business_name}",
    };
  }

  Future<void> saveConfig({
    required String baseUrl,
    required String apiKey,
    required String sessionId,
    String? templateSale,
    String? templatePayment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wa_base_url', baseUrl);
    await prefs.setString('wa_api_key', apiKey);
    await prefs.setString('wa_session_id', sessionId);
    if (templateSale != null) await prefs.setString('wa_template_sale', templateSale);
    if (templatePayment != null) await prefs.setString('wa_template_payment', templatePayment);
  }

  /// Sends a simple text message via the local OpenWA server using provided session details
  Future<bool> sendTextMessage({
    required String phone,
    required String message,
  }) async {
    if (phone.isEmpty || phone == 'null') return false;
    
    try {
      final config = await getConfig();
      
      // Ensure phone is in correct format (number@c.us)
      String formattedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      
      // Automatically add Saudi Arabia country code (966) if missing
      if (formattedPhone.startsWith('05') && formattedPhone.length == 10) {
        // e.g., 0561624285 -> 966561624285
        formattedPhone = '966${formattedPhone.substring(1)}';
      } else if (formattedPhone.startsWith('5') && formattedPhone.length == 9) {
        // e.g., 561624285 -> 966561624285
        formattedPhone = '966$formattedPhone';
      }

      if (!formattedPhone.contains('@c.us')) {
        formattedPhone = '$formattedPhone@c.us';
      }

      // Construct URL dynamically
      String baseUrl = config['baseUrl'] ?? '';
      if (baseUrl.isEmpty) {
        print("WhatsApp Error: Base URL is empty in config.");
        return false;
      }
      if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      
      final String sessionId = config['sessionId'] ?? '';
      if (sessionId.isEmpty) {
        print("WhatsApp Error: Session ID is empty in config.");
        return false;
      }

      final String urlStr = '$baseUrl/api/sessions/$sessionId/messages/send-text';
      final url = Uri.parse(urlStr);
      
      print("WhatsApp: Attempting to send to $formattedPhone via OpenWA...");

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': config['apiKey'] ?? '',
        },
        body: jsonEncode({
          "chatId": formattedPhone,
          "text": message,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("WhatsApp Message Sent successfully to $phone");
        return true;
      } else {
        print("Failed to send WhatsApp message. Status: ${response.statusCode}");
        print("Response: ${response.body}");
        return false;
      }
    } catch (e) {
      print("WhatsApp Service Error: $e");
      return false;
    }
  }

  /// Fetches contact details (Name and Number) from OpenWA directly using the phone number
  Future<Map<String, dynamic>?> getContactDetails(String phone) async {
    try {
      final config = await getConfig();
      String baseUrl = config['baseUrl'] ?? '';
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      final String sessionId = config['sessionId'] ?? '';
      final String apiKey = config['apiKey'] ?? '';

      // Ensure phone is in correct format (number)
      String formattedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (formattedPhone.startsWith('05') && formattedPhone.length == 10) {
        formattedPhone = '966${formattedPhone.substring(1)}';
      } else if (formattedPhone.startsWith('5') && formattedPhone.length == 9) {
        formattedPhone = '966$formattedPhone';
      }

      // Append @c.us if not present
      if (!formattedPhone.contains('@')) {
        formattedPhone = '$formattedPhone@c.us';
      }

      final contactUrl =
          Uri.parse('$baseUrl/api/sessions/$sessionId/contacts/$formattedPhone');
      print("WhatsApp Direct Fetch (Details): $contactUrl");

      final contactResponse = await http.get(
        contactUrl,
        headers: {
          'Accept': 'application/json',
          'X-API-Key': apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (contactResponse.statusCode == 200) {
        var body = jsonDecode(contactResponse.body);
        var data = body['response'] ?? body['data'] ?? body;
        
         print("WhatsApp Direct Fetch Raw Data: $data");
        
        String name = data['name'] ?? data['pushname'] ?? data['formattedName'] ?? data['verifiedName'] ?? '';
        String number = data['id']?.toString().split('@')[0] ?? formattedPhone.split('@')[0];

        if (name.isNotEmpty) {
          return {
            'name': name,
            'number': number,
          };
        } else {
          print("WhatsApp Contact Found but name is empty");
          return null;
        }
      } else {
        print("WhatsApp Direct Fetch Failed. Status: ${contactResponse.statusCode} Body: ${contactResponse.body}");
        return null;
      }
    } catch (e) {
      print("WhatsApp Contact Search Error: $e");
      return null;
    }
  }

  /// Sends a sale notification with basic details
  Future<void> sendSaleNotification(dynamic id, {bool isServerId = false, bool force = false}) async {
    final String uniqueKey = "${isServerId ? 'S' : 'L'}_$id";
    if (!force && _sentSaleIds.contains(uniqueKey)) {
      print("WhatsApp Guard: Notification already sent or in progress for $uniqueKey. Skipping.");
      return;
    }
    if (!force) {
      _sentSaleIds.add(uniqueKey);
    }

    try {
      // 1. Polling for Invoice URL and Transaction ID (Wait up to 30 seconds)
      // Background sync might take time, especially for due sales
      List sells = [];
      Map? sell;
      int attempts = 0;
      
      print("WhatsApp: Starting polling for sale $uniqueKey...");

      while (attempts < 30) {
        if (isServerId) {
          sells = await SellDatabase().getSellByTransactionId(id);
        } else {
          sells = await SellDatabase().getSellBySellId(id);
        }
        
        if (sells.isNotEmpty) {
          sell = sells[0];
          // We wait until we have BOTH a transaction_id (synced) and an invoice_url.
          // However, for Drafts or if syncing takes too long, we proceed with just the ID.
          bool isSynced = sell!['transaction_id'] != null;
          bool hasUrl = sell['invoice_url'] != null && sell['invoice_url'].toString().isNotEmpty;
          bool isDraft = sell['status'] == 'draft' || sell['is_quotation'] == 1;

          if (isSynced && (hasUrl || isDraft || attempts > 10)) {
            print("WhatsApp Polling: Proceeding with synced sale (URL: $hasUrl, Draft: $isDraft) after $attempts seconds.");
            break; 
          }
        }
        
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      }

      if (sell == null) {
        print("WhatsApp Error: Sale record not found for id $id (ServerId: $isServerId)");
        _sentSaleIds.remove(uniqueKey);
        return;
      }
      
      String invoiceUrl = sell['invoice_url']?.toString() ?? '';
      
      if (invoiceUrl.isEmpty && (sell['status'] == 'final')) {
        print("WhatsApp Warning: Polling timed out for final sale $uniqueKey. Sync may be slow.");
      }
      
      var customer = await Contact().getCustomerDetailById(sell['contact_id']);
      if (customer == null) {
        print("WhatsApp Error: Customer not found (ID: ${sell['contact_id']}) for sale $uniqueKey");
        _sentSaleIds.remove(uniqueKey);
        return;
      }

      if (customer['mobile'] == null || customer['mobile'].toString().trim().isEmpty) {
        print("WhatsApp Error: Customer ${customer['name']} has no mobile number. Cannot send notification.");
        _sentSaleIds.remove(uniqueKey);
        return;
      }
      
      String mobile = customer['mobile'].toString();
      if (mobile.isEmpty || mobile == 'null') return;

      var businessInfo = await Helper().getFormattedBusinessDetails();
      String symbol = businessInfo['symbol'] ?? '';
      double finalTotal = (double.tryParse(sell['invoice_amount']?.toString() ?? '0') ?? 0.0);
      double pendingAmount = (double.tryParse(sell['pending_amount']?.toString() ?? '0') ?? 0.0);
      String invoiceNo = sell['invoice_no'] ?? '';
      String customerName = customer['name'] ?? '';

      double receivedAmount = finalTotal - pendingAmount;

      // Try to get payment method(s)
      String paymentMethod = '';
      try {
        List paymentList = await PaymentDatabase().get(sell['id']);
        if (paymentList.isNotEmpty) {
          paymentMethod = paymentList.map((e) => e['method'] ?? 'Cash').toSet().join(', ');
        }
      } catch (_) {}

      final config = await getConfig();
      String message = config['templateSale'] ?? '';
      
      String invoiceUrlSection = invoiceUrl.isNotEmpty 
          ? "يمكنك عرض فاتورتك هنا: $invoiceUrl\n\n" 
          : "";

      message = message
          .replaceAll('{customer_name}', customerName)
          .replaceAll('{invoice_no}', invoiceNo)
          .replaceAll('{invoice_url_section}', invoiceUrlSection)
          .replaceAll('{invoice_url}', invoiceUrl)
          .replaceAll('{final_total}', finalTotal.toStringAsFixed(2))
          .replaceAll('{received_amount}', receivedAmount.toStringAsFixed(2))
          .replaceAll('{pending_amount}', pendingAmount.toStringAsFixed(2))
          .replaceAll('{payment_method}', paymentMethod)
          .replaceAll('{symbol}', symbol);

      bool success = await sendTextMessage(phone: mobile, message: message);
      if (!success) {
        _sentSaleIds.remove(uniqueKey); // Allow retry if send failed
      }
    } catch (e) {
      print("Error sending sale notification: $e");
      _sentSaleIds.remove(uniqueKey);
    }
  }

  /// Sends a specific notification for payments received (paying off a due amount)
  Future<void> sendPaymentNotification({
    required dynamic sellId,
    required double paidAmount,
    String? paymentMethod,
  }) async {
    try {
      List sells = await SellDatabase().getSellBySellId(sellId);
      if (sells.isEmpty) return;
      var sell = sells[0];

      var customer = await Contact().getCustomerDetailById(sell['contact_id']);
      if (customer == null || customer['mobile'] == null) return;
      
      String mobile = customer['mobile'].toString();
      if (mobile.isEmpty || mobile == 'null') return;

      var businessInfo = await Helper().getFormattedBusinessDetails();
      String businessName = businessInfo['name'] ?? 'KHEYAL CAFÉ';
      String symbol = businessInfo['symbol'] ?? '';
      String invoiceNo = sell['invoice_no'] ?? '';
      String customerName = customer['name'] ?? '';

      // Fallback: If paymentMethod is not provided, fetch from DB
      if (paymentMethod == null || paymentMethod.isEmpty) {
        List paymentList = await PaymentDatabase().get(sell['id']);
        if (paymentList.isNotEmpty) {
          paymentMethod = paymentList.last['method'] ?? 'Cash';
        } else {
          paymentMethod = 'Cash';
        }
      }

      final config = await getConfig();
      String message = config['templatePayment'] ?? '';
      
      message = message
          .replaceAll('{customer_name}', customerName)
          .replaceAll('{invoice_no}', invoiceNo)
          .replaceAll('{paid_amount}', paidAmount.toStringAsFixed(2))
          .replaceAll('{payment_method}', paymentMethod!)
          .replaceAll('{symbol}', symbol)
          .replaceAll('{business_name}', businessName);

      await sendTextMessage(phone: mobile, message: message);
    } catch (e) {
      print("Error sending payment notification: $e");
    }
  }

  /// TEST METHOD: Use this to test your local server connectivity
  Future<void> testWhatsAppMessage() async {
    const String testNumber = '+966 56 162 4285';
    const String testMsg = 'Hello from KR POS! Your WhatsApp configuration is working correctly. 🚀';
    
    print("Starting WhatsApp dynamic config test...");
    bool success = await sendTextMessage(phone: testNumber, message: testMsg);
    
    if (success) {
      print("Test SUCCESS: Message was accepted by server.");
    } else {
      print("Test FAILED: Check your Configuration in the Profile page.");
    }
  }
}
