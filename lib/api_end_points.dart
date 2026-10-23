abstract final class ApiEndPoints {
  static String baseUrl = 'https://pos.kheyalcafe.com';
  // static String baseUrl = 'https://pos.krrider.cloud';
  static String apiUrl = '/connector/api';

  //#region used by http

  ///auth
  static String loginUrl = '$baseUrl/oauth/token';
  static String getUser = '$baseUrl$apiUrl/user/loggedin';
  static String updatePassword = '$baseUrl$apiUrl/update-password';

  ///attendance
  static String checkIn = '$baseUrl$apiUrl/clock-in';
  static String checkOut = '$baseUrl$apiUrl/clock-out';
  static String getAttendance = '$baseUrl$apiUrl/get-attendance/';

  ///contact
  static String contact = '$baseUrl$apiUrl/contactapi';
  static String getContact = '$contact?type=customer&per_page=500';
  static String addContact = '$contact?type=customer';
  //contact payment
  static String customerDue = '$baseUrl$apiUrl/contact-payments/';
  static String addContactPayment = '$baseUrl$apiUrl/contact-payments';
  static String addSellPayment = '$baseUrl$apiUrl/sell-payments';

  //#endregion

  //#region used by Dio

  ///Notifications
  static String allNotifications = '$apiUrl/notifications';

  ///brands
  static String allBrands = '$apiUrl/brand';

  ///Purchases
  static String purchases = '$apiUrl/purchases';
  //#endregion

  /// WhatsApp OpenWA (Default/Fallback)
  static String whatsappBaseUrl = 'http://147.93.72.104:2785';
  static String whatsappApiKey = 'owa_k1_8b99b371a37a83d1939620150f863a1bc2b977cdc40d76a261223f9f99071bed';
  static String whatsappSessionId = '0ee4ae68-b404-48d0-bbd6-5f12a8b67c2b';
  
  // Note: constructed dynamically in WhatsAppService to support server settings
  static String sendText = '$whatsappBaseUrl/api/sessions/$whatsappSessionId/messages/send-text';
}
