import 'package:flutter/material.dart';
import 'dart:io';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart' as pos;
import '../helpers/AppTheme.dart';
import '../services/printer_service.dart';

class PrinterConfigPage extends StatefulWidget {
  @override
  _PrinterConfigPageState createState() => _PrinterConfigPageState();
}

class _PrinterConfigPageState extends State<PrinterConfigPage> {
  final PrinterService _printerService = PrinterService();
  List<PrinterDevice> _devices = [];
  bool _isScanning = false;
  PrinterConnectionType _selectedType = PrinterConnectionType.network;
  
  final _ipController = TextEditingController();
  final _nameController = TextEditingController(text: 'Network Printer');

  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  @override
  void initState() {
    super.initState();
    _printerService.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _scan() async {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    try {
      if (_selectedType == PrinterConnectionType.usb && Platform.isAndroid) {
        // Special scan for Raw USB printers on Android
        List<PrinterDevice> results = [];
        
        await for (final device in pos.PrinterManager.instance.discovery(type: pos.PrinterType.usb)) {
          results.add(UsbPrinterDevice(
            name: device.name ?? 'USB Printer',
            identifier: '${device.vendorId}:${device.productId}',
            usbPlatform: UsbPlatform.android,
          ));
          if (mounted) setState(() => _devices = List.from(results));
        }
      } else {
        final devices = await _printerService.manager.scanPrinters(
          types: {_selectedType},
          timeout: const Duration(seconds: 7),
        );
        if (mounted) {
          setState(() {
            _devices = devices;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _onDeviceTapped(PrinterDevice device) {
    if (!_printerService.useSeparateKitchenPrinter) {
      _selectDevice(device, isKitchen: false);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Assign Printer'),
          content: Text('How do you want to use "${device.name}"?'),
          actions: [
            TextButton(
              onPressed: () {
                _selectDevice(device, isKitchen: false);
                Navigator.pop(context);
              },
              child: const Text('Customer Invoice'),
            ),
            TextButton(
              onPressed: () {
                _selectDevice(device, isKitchen: true);
                Navigator.pop(context);
              },
              child: const Text('Kitchen Order'),
            ),
          ],
        ),
      );
    }
  }

  void _addManualNetworkPrinter() {
    final ip = _ipController.text.trim();
    final name = _nameController.text.trim();
    
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter IP address')),
      );
      return;
    }

    // Basic IP format check
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid IP address')),
      );
      return;
    }

    final device = NetworkPrinterDevice(
      name: name.isEmpty ? 'Network Printer' : name, 
      host: ip
    );
    _onDeviceTapped(device);
  }

  void _selectDevice(PrinterDevice? device, {required bool isKitchen}) async {
    if (isKitchen) {
      await _printerService.setKitchenDevice(device);
    } else {
      await _printerService.setCustomerDevice(device);
    }
    if (mounted) setState(() {});
  }

  Future<void> _testPrint(bool isKitchen) async {
    final device = isKitchen ? _printerService.kitchenDevice : _printerService.customerDevice;
    
    if (device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a ${isKitchen ? "kitchen" : "customer"} printer first')),
      );
      return;
    }

    try {
      final profile = await CapabilityProfile.load();
      final ticket = Ticket(PaperSize.mm80, profile);
      ticket.text('TEST PRINT (${isKitchen ? "KITCHEN" : "CUSTOMER"})', 
        style: const PrintTextStyle(bold: true, height: TextSize.size2, width: TextSize.size2),
        align: PrintAlign.center);
      ticket.separator();
      ticket.text('Printer Name: ${device.name}');
      ticket.text('Address: ${_getDeviceAddress(device)}');
      ticket.text('Role: ${isKitchen ? "Kitchen Order" : "Customer Invoice"}');
      ticket.separator();
      ticket.feed(3);
      ticket.cut();

      await _printerService.printReceipt(ticket, isKitchen: isKitchen);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test print failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff732a13),
      appBar: AppBar(
        backgroundColor: const Color(0xff732a13),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Printer Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: themeData.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildGeneralSettings(),
              _buildSelectedPrinters(),
              _buildScanner(),
              if (_selectedType == PrinterConnectionType.network) _buildManualIPEntry(),
              _buildDeviceList(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('General Settings', 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Printing', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text('Turn on/off all receipt printing', style: TextStyle(fontSize: 12)),
              value: _printerService.isPrintingEnabled,
              activeColor: const Color(0xff732a13),
              onChanged: (val) async {
                await _printerService.setPrintingEnabled(val);
                setState(() {});
              },
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto Print Customer Receipt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text('Automatically print receipt after payment', style: TextStyle(fontSize: 12)),
              value: _printerService.printCustomerCopy,
              activeColor: const Color(0xff732a13),
              onChanged: (val) async {
                await _printerService.setPrintCustomerCopy(val);
                setState(() {});
              },
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Kitchen Printing', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text('Print a second copy for kitchen staff', style: TextStyle(fontSize: 12)),
              value: _printerService.printKitchenCopy,
              activeColor: const Color(0xff732a13),
              onChanged: (val) async {
                await _printerService.setPrintKitchenCopy(val);
                setState(() {});
              },
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use Separate Kitchen Printer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text('Use a different physical printer for kitchen', style: TextStyle(fontSize: 12)),
              value: _printerService.useSeparateKitchenPrinter,
              activeColor: const Color(0xff732a13),
              onChanged: (val) async {
                await _printerService.setUseSeparateKitchenPrinter(val);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPrinters() {
    return Column(
      children: [
        _buildPrinterSlot(
          title: 'Customer Invoice Printer',
          device: _printerService.customerDevice,
          onRemove: () => _selectDevice(null, isKitchen: false),
          onTest: () => _testPrint(false),
        ),
        if (_printerService.useSeparateKitchenPrinter)
          _buildPrinterSlot(
            title: 'Kitchen Order Printer',
            device: _printerService.kitchenDevice,
            onRemove: () => _selectDevice(null, isKitchen: true),
            onTest: () => _testPrint(true),
          ),
      ],
    );
  }

  Widget _buildPrinterSlot({
    required String title,
    required PrinterDevice? device,
    required VoidCallback onRemove,
    required VoidCallback onTest,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 12)),
                if (device != null)
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline, color: Colors.blue, size: 20),
                    onPressed: onTest,
                    tooltip: 'Test Print',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (device != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.print, color: Colors.green),
                title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${_getDeviceAddress(device)} (${device.connectionType.name})'),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  onPressed: onRemove,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Not configured', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<PrinterConnectionType>(
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  value: _selectedType,
                  items: PrinterConnectionType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedType = val);
                      _scan();
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _scan,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff732a13),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isScanning 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
              : const Icon(Icons.search),
            label: const Text('Scan'),
          ),
        ],
      ),
    );
  }

  Widget _buildManualIPEntry() {
    return Card(
      elevation: 0,
      color: Colors.blue[50],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Manually (If Scan fails)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      hintText: 'e.g. 192.168.1.100',
                      isDense: true,
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _addManualNetworkPrinter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty && !_isScanning) {
      return Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: Column(
          children: [
            Icon(Icons.print_disabled_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text('No devices found', style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _devices.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final device = _devices[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: Colors.grey[100],
            child: Icon(
              device.connectionType == PrinterConnectionType.usb ? Icons.usb : 
              device.connectionType == PrinterConnectionType.network ? Icons.network_check : Icons.bluetooth,
              color: Colors.grey[600],
            ),
          ),
          title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_getDeviceSubtitle(device)),
          trailing: const Icon(Icons.add_circle_outline, color: Colors.blue),
          onTap: () => _onDeviceTapped(device),
        );
      },
    );
  }

  String _getDeviceSubtitle(PrinterDevice device) {
    String address = _getDeviceAddress(device);
    return '$address (${device.connectionType.name})';
  }

  String _getDeviceAddress(PrinterDevice device) {
    if (device is NetworkPrinterDevice) return device.host;
    if (device is BluetoothPrinterDevice) return device.address;
    if (device is BlePrinterDevice) return device.deviceId;
    if (device is UsbPrinterDevice) return device.identifier;
    return '';
  }
}
