import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NfcService {
  static final NfcService _instance = NfcService._internal();
  factory NfcService() => _instance;
  NfcService._internal();

  /// Check if NFC is available on this device
  Future<bool> isNfcAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      debugPrint("NFC availability check failed: $e");
      return false;
    }
  }

  /// Start scanning for an NFC tag to extract its hardware Card UID
  void startScanning({
    required Function(String cardUid) onCardScanned,
    required Function(String error) onError,
  }) async {
    bool isAvailable = await isNfcAvailable();
    if (!isAvailable) {
      onError("NFC is not supported or not enabled on this device.");
      return;
    }

    try {
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            List<int>? identifier;
            final Map<String, dynamic> data = tag.data;

            if (data.containsKey('nfca')) {
              identifier = List<int>.from(data['nfca']['identifier'] ?? []);
            } else if (data.containsKey('mifare')) {
              identifier = List<int>.from(data['mifare']['identifier'] ?? []);
            } else if (data.containsKey('isodep')) {
              identifier = List<int>.from(data['isodep']['identifier'] ?? []);
            } else if (data.containsKey('nfcb')) {
              identifier = List<int>.from(data['nfcb']['identifier'] ?? []);
            } else if (data.containsKey('nfcf')) {
              identifier = List<int>.from(data['nfcf']['identifier'] ?? []);
            } else if (data.containsKey('nfcv')) {
              identifier = List<int>.from(data['nfcv']['identifier'] ?? []);
            }

            if (identifier != null && identifier.isNotEmpty) {
              String cardUid = identifier
                  .map((e) => e.toRadixString(16).padLeft(2, '0'))
                  .join()
                  .toUpperCase();
              onCardScanned(cardUid);
            } else {
              onError("Could not read UID from scanned NFC card.");
            }
          } catch (e) {
            onError("Failed to parse NFC card data: ${e.toString()}");
          } finally {
            NfcManager.instance.stopSession();
          }
        },
      );
    } catch (e) {
      onError("Failed to start NFC session: ${e.toString()}");
    }
  }

  /// Stop active NFC scanning session
  void stopScanning() {
    try {
      NfcManager.instance.stopSession();
    } catch (e) {
      debugPrint("Error stopping NFC session: $e");
    }
  }
}
