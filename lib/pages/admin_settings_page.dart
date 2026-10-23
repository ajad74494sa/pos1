import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../services/whatsapp_service.dart';
import '../services/connectivity_service.dart';
import '../helpers/otherHelpers.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({Key? key}) : super(key: key);

  @override
  _AdminSettingsPageState createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  // Dark Theme Colors
  final Color bgColor = const Color(0xFF0F111A);
  final Color cardColor = const Color(0xFF1A1D2B);
  final Color inputFillColor = const Color(0xFF25293C);
  final Color primaryColor = const Color(0xFF732A13);
  final Color textColor = Colors.white;

  // Controllers
  final whatsappBaseUrlController = TextEditingController();
  final whatsappApiKeyController = TextEditingController();
  final whatsappSessionIdController = TextEditingController();
  final arbIdController = TextEditingController();
  final arbPasswordController = TextEditingController();
  final arbResourceKeyController = TextEditingController();
  bool arbIsLive = false;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllConfigs();
  }

  Future<void> _loadAllConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final waConfig = await WhatsAppService().getConfig();

    setState(() {
      // WhatsApp
      whatsappBaseUrlController.text = waConfig['baseUrl'] ?? '';
      whatsappApiKeyController.text = waConfig['apiKey'] ?? '';
      whatsappSessionIdController.text = waConfig['sessionId'] ?? '';

      // ARB
      arbIdController.text = prefs.getString('arb_id') ?? '';
      arbPasswordController.text = prefs.getString('arb_password') ?? '';
      arbResourceKeyController.text = prefs.getString('arb_resource_key') ?? '';
      arbIsLive = prefs.getBool('arb_is_live') ?? false;

      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("System Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildConnectivitySection(),
                const SizedBox(height: 24),
                _buildWhatsAppSection(),
                const SizedBox(height: 24),
                _buildARBSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildConnectivitySection() {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, child) {
        String qualityText = connectivity.quality.name.toUpperCase();
        Color qualityColor = Colors.green;
        if (connectivity.quality == ConnectionQuality.slow) qualityColor = Colors.orange;
        if (connectivity.quality == ConnectionQuality.offline) qualityColor = Colors.red;

        return _buildSectionCard(
          title: "Network & Connectivity",
          icon: Icons.wifi,
          iconColor: Colors.cyan,
          onSave: () {}, // No explicit save needed as switch handles it
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Connection Quality:", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
                    Text(qualityText, style: TextStyle(color: qualityColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Latency:", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
                    Text("${connectivity.latency} ms", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSwitchRow(
              "Auto-Switch Mode (Smart)", 
              connectivity.autoSwitchEnabled, 
              (v) => connectivity.setAutoSwitchEnabled(v)
            ),
            const SizedBox(height: 4),
            const Text(
              "Automatically go offline when internet is slow (>1.5s) and back online when strong (<0.5s).",
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
            const SizedBox(height: 16),
            _buildSwitchRow(
              "Manual Low Internet Mode", 
              connectivity.lowInternetMode, 
              (v) => connectivity.setLowInternetMode(v)
            ),
            const SizedBox(height: 16),
            _buildSwitchRow(
              "Automatic Background Sync", 
              connectivity.autoSyncEnabled, 
              (v) => connectivity.setAutoSyncEnabled(v)
            ),
            const SizedBox(height: 4),
            const Text(
              "If disabled, you must click the Sync button manually on the Home screen to send sales to the server.",
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWhatsAppSection() {
    return _buildSectionCard(
      title: "OpenWA Settings",
      icon: Symbols.chat,
      iconColor: Colors.green,
      onSave: () async {
        await WhatsAppService().saveConfig(
          baseUrl: whatsappBaseUrlController.text.trim(),
          apiKey: whatsappApiKeyController.text.trim(),
          sessionId: whatsappSessionIdController.text.trim(),
        );
        Helper().showNotification(context, "WhatsApp Config Saved");
      },
      children: [
        _buildTextField(whatsappBaseUrlController, "Base URL", Icons.link),
        _buildTextField(whatsappSessionIdController, "Session ID", Icons.vpn_key),
        _buildTextField(whatsappApiKeyController, "API Key", Icons.lock, obscure: true),
      ],
    );
  }

  Widget _buildARBSection() {
    return _buildSectionCard(
      title: "ARB Payment Gateway",
      icon: Icons.account_balance,
      iconColor: Colors.blue,
      onSave: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('arb_id', arbIdController.text.trim());
        await prefs.setString('arb_password', arbPasswordController.text.trim());
        await prefs.setString('arb_resource_key', arbResourceKeyController.text.trim());
        await prefs.setBool('arb_is_live', arbIsLive);
        Helper().showNotification(context, "ARB Config Saved");
      },
      children: [
        _buildTextField(arbIdController, "Tranportal ID", Icons.badge),
        _buildTextField(arbPasswordController, "Tranportal Password", Icons.password, obscure: true),
        _buildTextField(arbResourceKeyController, "Resource Key", Icons.enhanced_encryption, obscure: true),
        _buildSwitchRow("Environment (Live Mode)", arbIsLive, (v) => setState(() => arbIsLive = v)),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Color iconColor, required List<Widget> children, required VoidCallback onSave}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(icon, color: iconColor), const SizedBox(width: 10), Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold))]),
              IconButton(onPressed: onSave, icon: const Icon(Icons.check_circle, color: Colors.green)),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          filled: true,
          fillColor: inputFillColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Switch(value: value, onChanged: onChanged, activeColor: Colors.green),
      ],
    );
  }
}
