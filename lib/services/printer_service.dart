import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart'
    as pos;
import 'package:flutter/foundation.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final PrinterManager manager = PrinterManager();

  PrinterDevice? _customerDevice;
  PrinterDevice? _kitchenDevice;

  bool _printKitchenCopy = true;
  bool _useSeparateKitchenPrinter = false;
  bool _isPrintingEnabled = true;
  bool _promptBeforePrinting = true;
  bool _printCustomerCopy = true;
  Future<void> _printQueue = Future<void>.value();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    debugPrint("PrinterService: Initializing from SharedPreferences...");

    _printKitchenCopy = prefs.getBool('print_kitchen_copy') ?? true;
    _useSeparateKitchenPrinter =
        prefs.getBool('use_separate_kitchen_printer') ?? false;
    _isPrintingEnabled = prefs.getBool('is_printing_enabled') ?? true;
    _promptBeforePrinting = prefs.getBool('prompt_before_printing') ?? true;
    _printCustomerCopy = prefs.getBool('print_customer_copy') ?? true;

    _customerDevice = await _loadDevice(prefs, 'customer_printer');
    _kitchenDevice = await _loadDevice(prefs, 'kitchen_printer');

    debugPrint(
      "PrinterService: Load Complete. Customer Printer: ${_customerDevice?.name ?? 'None'}",
    );
  }

  Future<PrinterDevice?> _loadDevice(
    SharedPreferences prefs,
    String key,
  ) async {
    try {
      final String? deviceJson = prefs.getString(key);
      if (deviceJson == null) return null;

      final Map<String, dynamic> map = jsonDecode(deviceJson);
      final typeStr = map['type'];

      debugPrint("PrinterService: Loading device $key - Type: $typeStr");

      // Handle both string and enum-like string formats
      if (typeStr.contains('network')) {
        return NetworkPrinterDevice(
          name: map['name'],
          host: map['address'],
          port: map['port'] ?? 9100,
        );
      } else if (typeStr.contains('bluetooth')) {
        return BluetoothPrinterDevice(
          name: map['name'],
          address: map['address'],
        );
      } else if (typeStr.contains('ble')) {
        return BlePrinterDevice(name: map['name'], deviceId: map['address']);
      } else if (typeStr.contains('usb')) {
        return UsbPrinterDevice(
          name: map['name'],
          identifier: map['address'],
          usbPlatform: Platform.isAndroid
              ? UsbPlatform.android
              : UsbPlatform.desktop,
        );
      }
    } catch (e) {
      debugPrint("PrinterService: Error loading device $key: $e");
    }
    return null;
  }

  PrinterDevice? get customerDevice => _customerDevice;
  PrinterDevice? get kitchenDevice => _kitchenDevice;
  bool get printKitchenCopy => _printKitchenCopy;
  bool get useSeparateKitchenPrinter => _useSeparateKitchenPrinter;

  bool get isPrintingEnabled => _isPrintingEnabled;
  bool get promptBeforePrinting => _promptBeforePrinting;
  bool get printCustomerCopy => _printCustomerCopy;

  // For backward compatibility with existing code that uses .selectedDevice
  PrinterDevice? get selectedDevice => _customerDevice;

  Future<void> setPrintingEnabled(bool value) async {
    _isPrintingEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_printing_enabled', value);
  }

  Future<void> setPrintKitchenCopy(bool value) async {
    _printKitchenCopy = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('print_kitchen_copy', value);
  }

  Future<void> setUseSeparateKitchenPrinter(bool value) async {
    _useSeparateKitchenPrinter = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_separate_kitchen_printer', value);
  }

  Future<void> setPromptBeforePrinting(bool value) async {
    _promptBeforePrinting = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prompt_before_printing', value);
  }

  Future<void> setPrintCustomerCopy(bool value) async {
    _printCustomerCopy = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('print_customer_copy', value);
  }

  Future<void> setCustomerDevice(PrinterDevice? device) async {
    _customerDevice = device;
    await _saveDevice('customer_printer', device);
  }

  Future<void> setKitchenDevice(PrinterDevice? device) async {
    _kitchenDevice = device;
    await _saveDevice('kitchen_printer', device);
  }

  // Helper for old code
  Future<void> setSelectedDevice(PrinterDevice? device) async {
    await setCustomerDevice(device);
  }

  Future<void> _saveDevice(String key, PrinterDevice? device) async {
    final prefs = await SharedPreferences.getInstance();
    if (device != null) {
      Map<String, dynamic> map = {
        'name': device.name,
        'type': device.connectionType.toString(),
      };

      if (device is NetworkPrinterDevice) {
        map['address'] = device.host;
        map['port'] = device.port;
      } else if (device is BluetoothPrinterDevice) {
        map['address'] = device.address;
      } else if (device is BlePrinterDevice) {
        map['address'] = device.deviceId;
      } else if (device is UsbPrinterDevice) {
        map['address'] = device.identifier;
      }
      await prefs.setString(key, jsonEncode(map));
    } else {
      await prefs.remove(key);
    }
  }

  Future<void> printReceipt(
    Ticket ticket, {
    bool isKitchen = false,
    bool keepAlive = false,
  }) {
    final completer = Completer<void>();
    _printQueue = _printQueue.then((_) async {
      try {
        await _printReceiptNow(
          ticket,
          isKitchen: isKitchen,
          keepAlive: keepAlive,
        );
        completer.complete();
      } catch (e, stackTrace) {
        completer.completeError(e, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _printReceiptNow(
    Ticket ticket, {
    required bool isKitchen,
    required bool keepAlive,
  }) async {
    PrinterDevice? targetDevice = _customerDevice;

    if (isKitchen) {
      targetDevice = _useSeparateKitchenPrinter
          ? _kitchenDevice
          : _customerDevice;
    }

    if (targetDevice == null || !_isPrintingEnabled) return;

    try {
      if (targetDevice is UsbPrinterDevice && Platform.isAndroid) {
        await _printUsbAndroid(targetDevice, ticket.bytes);
        return;
      }

      // Disconnect active if different
      if (manager.isConnected &&
          manager.connectedDevice?.name != targetDevice.name) {
        await manager.disconnect();
      }

      if (!manager.isConnected) {
        await manager.connect(
          targetDevice,
          timeout: const Duration(seconds: 5),
        );
      }

      await manager.printTicket(ticket);

      if (!keepAlive) {
        await manager.disconnect();
      }
    } catch (e) {
      debugPrint("Printing error: $e");
      // Ensure we can retry next time
      try {
        await manager.disconnect();
      } catch (_) {}
    }
  }

  Future<void> disconnect() async {
    if (manager.isConnected) {
      await manager.disconnect();
    }
  }

  Future<void> _printUsbAndroid(
    UsbPrinterDevice device,
    List<int> bytes,
  ) async {
    final parts = device.identifier.split(':');
    if (parts.length != 2)
      throw Exception("Invalid USB identifier: ${device.identifier}");

    final vendorId = int.tryParse(parts[0]);
    final productId = int.tryParse(parts[1]);

    if (vendorId == null || productId == null) {
      throw Exception("Invalid USB VID/PID: ${device.identifier}");
    }

    final usbManager = pos.PrinterManager.instance;

    // Attempt to connect using pos_printer_platform
    bool connected = await usbManager.connect(
      type: pos.PrinterType.usb,
      model: pos.UsbPrinterInput(
        name: device.name,
        vendorId: vendorId.toString(),
        productId: productId.toString(),
      ),
    );

    if (!connected) {
      throw Exception("Could not connect to USB printer via Raw USB");
    }

    await usbManager.send(type: pos.PrinterType.usb, bytes: bytes);
    // Give it a moment to finish sending before disconnecting
    await Future.delayed(const Duration(milliseconds: 500));
    await usbManager.disconnect(type: pos.PrinterType.usb);
  }
}
