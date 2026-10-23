import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pinput/pinput.dart';
import '../apis/user.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/otherHelpers.dart';
import '../models/system.dart';
import 'admin_settings_page.dart';

class UserProfile extends StatefulWidget {
  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? businessData;
  bool isLoading = true;
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  
  final Color bgColor = const Color(0xFF0F111A);
  final Color cardColor = const Color(0xFF1A1D2B);
  final Color inputFillColor = const Color(0xFF25293C);
  final Color primaryColor = const Color(0xFF732A13);
  final Color textColor = Colors.white;
  final Color mutedTextColor = Colors.white70;

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final pinController = TextEditingController();

  final _passwordFormKey = GlobalKey<FormState>();
  bool isUpdatingPassword = false;
  final storage = FlutterSecureStorage();
  String? currentPin;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPin();
  }

  _loadPin() async {
    String username = userData?['username'] ?? '';
    if (username.isEmpty) {
      var localUser = await System().get('loggedInUser');
      username = localUser?['username'] ?? '';
    }
    if (username.isNotEmpty) {
      String? pin = await storage.read(key: 'user_pin_$username');
      if (mounted) setState(() => currentPin = pin);
    }
  }

  _loadUserData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      businessData = await Helper().getFormattedBusinessDetails();
      var localUser = await System().get('loggedInUser');
      if (mounted && localUser != null) {
        setState(() {
          userData = Map<String, dynamic>.from(localUser);
          isLoading = false; 
        });
      }
      if (await Helper().checkConnectivity()) {
        String token = await System().getToken();
        var apiUser = await User().get(token);
        if (apiUser != null && apiUser is Map && mounted) {
          setState(() => userData = Map<String, dynamic>.from(apiUser));
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xff732a13),
        title: const Text("Account Management", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: isLoading && userData == null
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 30),
                  _buildSectionTitle("Profile Information"),
                  _buildProfileInfoFields(),
                  const SizedBox(height: 30),
                  _buildSectionTitle("Fast Login Settings"),
                  _buildFastLoginSettings(),
                  const SizedBox(height: 30),
                  _buildSectionTitle("Account Security"),
                  _buildPasswordSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: inputFillColor, borderRadius: BorderRadius.circular(50)),
            child: const Icon(Icons.person, size: 50, color: Colors.white24),
          ),
          const SizedBox(height: 16),
          Text(userData?['first_name'] ?? 'User', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(userData?['email'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildProfileInfoFields() {
    return Column(
      children: [
        _buildInputField("Username", userData?['username'] ?? '-'),
        const SizedBox(height: 12),
        _buildInputField("Role", userData?['user_type']?.toString().toUpperCase() ?? 'USER'),
      ],
    );
  }

  Widget _buildFastLoginSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Pinput(
            length: 4, obscureText: true, controller: pinController,
            defaultPinTheme: PinTheme(
              width: 50, height: 50,
              textStyle: const TextStyle(fontSize: 20, color: Colors.white),
              decoration: BoxDecoration(border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(8), color: inputFillColor),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handlePinUpdate,
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, minimumSize: const Size(double.infinity, 50)),
            child: Text(currentPin == null ? "Set Quick PIN" : "Update Quick PIN", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handlePinUpdate() async {
    if (pinController.text.length == 4) {
      await storage.write(key: 'user_pin_${userData?['username']}', value: pinController.text);
      setState(() => currentPin = pinController.text);
      pinController.clear();
      Helper().showNotification(context, "PIN Saved");
    }
  }

  Widget _buildPasswordSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          children: [
            _buildPasswordField("Old Password", currentPasswordController),
            const SizedBox(height: 12),
            _buildPasswordField("New Password", newPasswordController),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isUpdatingPassword ? null : _handlePasswordUpdate,
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, minimumSize: const Size(double.infinity, 50)),
              child: isUpdatingPassword ? const CircularProgressIndicator(color: Colors.white) : const Text("Change Password", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: inputFillColor, borderRadius: BorderRadius.circular(8)),
          child: Text(value, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller, obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: inputFillColor),
    );
  }

  void _handlePasswordUpdate() async {
    if (_passwordFormKey.currentState!.validate()) {
      setState(() => isUpdatingPassword = true);
      String token = await System().getToken();
      var response = await User().updatePassword(token, {
        'current_password': currentPasswordController.text,
        'new_password': newPasswordController.text,
        'new_password_confirmation': newPasswordController.text,
      });
      setState(() => isUpdatingPassword = false);
      if (response != null && response['success'] == true) {
        Helper().showNotification(context, "Password Updated");
      }
    }
  }
}
