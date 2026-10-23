import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:screen_retriever/screen_retriever.dart';

extension WindowControllerExtension on WindowController {
  Future<void> setFrame(Rect frame) async {
    await invokeMethod('setFrame', {
      'x': frame.left,
      'y': frame.top,
      'width': frame.width,
      'height': frame.height,
    });
  }

  Future<void> setTitle(String title) async {
    await invokeMethod('setTitle', title);
  }

  Future<void> close() async {
    await invokeMethod('close');
  }
}

class CustomerDisplayService extends ChangeNotifier {
  String? _customerWindowId;
  String? get customerWindowId => _customerWindowId;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized || !Platform.isWindows) return;

    try {
      // Get all connected screens
      List<Display> displaysList = await screenRetriever.getAllDisplays();
      
      // If only one screen is detected, do not open customer display
      if (displaysList.length <= 1) {
        debugPrint("Single screen detected. Customer display will not be opened.");
        return;
      }

      final window = await WindowController.create(WindowConfiguration(arguments: jsonEncode({})));
      
      debugPrint("--- Global Display Detection ---");
      for (int i = 0; i < displaysList.length; i++) {
        final d = displaysList[i];
        debugPrint("Display [$i]: ${d.name} | Size: ${d.size} | Pos: ${d.visiblePosition}");
      }

      // MANUAL CONFIGURATION: change index 1 to your wireless display index if needed
      int targetDisplayIndex = 1; 
      
      if (displaysList.length > targetDisplayIndex) {
        Display targetDisplay = displaysList[targetDisplayIndex];
        final Offset position = targetDisplay.visiblePosition ?? Offset.zero;
        await window.setFrame(Rect.fromLTWH(
          position.dx,
          position.dy,
          targetDisplay.size.width,
          targetDisplay.size.height,
        ));
        await window.setTitle('Customer Display');
        await window.show();
      }

      _customerWindowId = window.windowId;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error initializing global customer window: $e");
    }
  }

  void updateDisplay({
    required List<Map<String, dynamic>> items,
    required String total,
    required String symbol,
  }) {
    if (_customerWindowId != null) {
      final data = {
        'items': items,
        'total': total,
        'symbol': symbol,
      };
      WindowController.fromWindowId(_customerWindowId!)
          .invokeMethod("updateData", jsonEncode(data));
    }
  }

  void clearDisplay(String symbol) {
    updateDisplay(items: [], total: "0.00", symbol: symbol);
  }

  @override
  void dispose() {
    if (_customerWindowId != null) {
      WindowController.fromWindowId(_customerWindowId!).close();
    }
    super.dispose();
  }
}
