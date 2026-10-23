import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ARBPaymentService {
  static final ARBPaymentService _instance = ARBPaymentService._internal();
  factory ARBPaymentService() => _instance;
  ARBPaymentService._internal();

  Future<Map<String, String>> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getString('arb_id') ?? "PG360500",
      'password': prefs.getString('arb_password') ?? "4#DX\$\$U6u3rYek0",
      'resourceKey': prefs.getString('arb_resource_key') ?? "60955124350560955124350560955124",
      'isLive': (prefs.getBool('arb_is_live') ?? true).toString(),
    };
  }

  bool validateCredentialFormat(Map<String, String> creds) {
    print("--- ARB PRE-FLIGHT CHECK ---");
    if (creds['resourceKey']!.length != 32) {
       print("❌ ERROR: Resource Key must be 32 characters.");
       return false;
    }
    return true;
  }

  String encryptTrandata(String plainText, String resourceKey) {
    final key = encrypt_pkg.Key.fromUtf8(resourceKey);
    final iv = encrypt_pkg.IV.fromUtf8('PGKEYENCDECIVSPC'); 
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc, padding: 'PKCS7'));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  Future<String?> initiatePayment({
    required String amount,
    required String trackId,
    required String successUrl,
    required String errorUrl,
  }) async {
    final creds = await getCredentials();
    if (!validateCredentialFormat(creds)) return null;

    final String id = creds['id']!;
    final String password = creds['password']!;
    final String resourceKey = creds['resourceKey']!;
    final bool isLive = id.startsWith("PG") ? true : (creds['isLive'] == 'true');

    final String url = isLive 
        ? "https://digitalpayments.neoleap.com.sa/pg/payment/tranportal.htm"
        : "https://securepayments.neoleap.com.sa/pg/payment/tranportal.htm";

    final Map<String, dynamic> innerPayload = {
      "amt": amount.replaceAll(".00", ""),
      "action": "1",
      "password": password,
      "id": id,
      "currencyCode": "682",
      "trackId": DateTime.now().millisecondsSinceEpoch.toString().substring(0, 10),
      "responseURL": "https://krpos.com/success", // Use real-looking URLs
      "errorURL": "https://krpos.com/error",
      "langid": "EN",
      "udf1": "KRPOS",
      "udf2": "PROD",
      "udf3": "",
      "udf4": "",
      "udf5": "",
    };

    final String jsonPayload = jsonEncode([innerPayload]);

    try {
      print("--- HANDSHAKING WITH BANK (LIVE: $isLive) ---");
      final String encryptedData = encryptTrandata(jsonPayload, resourceKey);
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        body: jsonEncode([{
          "id": id,
          "trandata": encryptedData,
        }]),
      ).timeout(const Duration(seconds: 15));

      print("Bank Response: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        if (jsonList.isNotEmpty) {
          final resp = jsonList[0];
          if (resp['paymentId'] != null) {
            return _launchHostedUrl(resp['paymentId'], resp['url'], isLive);
          } else {
             print("Bank Rejected Data: ${resp['errorText']}");
          }
        }
      }
      return null;
    } catch (e) {
      print("System Error: $e");
      return null;
    }
  }

  Future<String?> _launchHostedUrl(String payId, String? redirectUrl, bool isLive) async {
    String finalRedirect = redirectUrl ?? "";
    if (!finalRedirect.contains("http")) {
       finalRedirect = isLive 
        ? "https://digitalpayments.neoleap.com.sa/pg/payment/hosted.htm"
        : "https://securepayments.neoleap.com.sa/pg/payment/hosted.htm";
    }
    String finalUrl = finalRedirect.contains('?') ? "$finalRedirect&paymentid=$payId" : "$finalRedirect?paymentid=$payId";
    if (await canLaunchUrl(Uri.parse(finalUrl))) {
      await launchUrl(Uri.parse(finalUrl), mode: LaunchMode.externalApplication);
      return payId;
    }
    return null;
  }
}
