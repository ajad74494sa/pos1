import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sell.dart';
import '../models/variations.dart';

enum ConnectionQuality { excellent, good, slow, offline }

class ConnectivityService with ChangeNotifier {
  bool _isOnline = true;
  bool _isSyncing = false;
  bool _lowInternetMode = false;
  bool _autoSwitchEnabled = true; // Auto switch based on latency
  bool _autoSyncEnabled = false;   // User wants manual sync
  
  int _latency = 0;
  ConnectionQuality _quality = ConnectionQuality.excellent;

  bool get isOnline => _isOnline && !_lowInternetMode; 
  bool get isSyncing => _isSyncing;
  bool get lowInternetMode => _lowInternetMode;
  bool get autoSwitchEnabled => _autoSwitchEnabled;
  bool get autoSyncEnabled => _autoSyncEnabled;
  int get latency => _latency;
  ConnectionQuality get quality => _quality;

  late StreamSubscription<List<ConnectivityResult>> _subscription;
  Timer? _latencyTimer;

  ConnectivityService() {
    _init();
    _startLatencyChecker();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _lowInternetMode = prefs.getBool('low_internet_mode') ?? false;
    _autoSwitchEnabled = prefs.getBool('auto_switch_enabled') ?? true;
    _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? false;

    final results = await Connectivity().checkConnectivity();
    _updateOnlineStatus(results);

    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateStatus(results);
    });
  }

  void _updateOnlineStatus(List<ConnectivityResult> results) {
    _isOnline = results.contains(ConnectivityResult.mobile) ||
                results.contains(ConnectivityResult.wifi) ||
                results.contains(ConnectivityResult.ethernet);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    bool online = results.contains(ConnectivityResult.mobile) ||
                 results.contains(ConnectivityResult.wifi) ||
                 results.contains(ConnectivityResult.ethernet);
    
    if (_isOnline != online) {
      _isOnline = online;
      if (_isOnline) {
        if (_autoSyncEnabled) triggerAutoSync();
        _checkLatency(); 
      } else {
        _quality = ConnectionQuality.offline;
      }
      notifyListeners();
    }
  }

  void _startLatencyChecker() {
    _latencyTimer?.cancel();
    _latencyTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_isOnline) {
        _checkLatency();
      }
    });
  }

  Future<void> _checkLatency() async {
    if (!_isOnline) return;

    try {
      final stopwatch = Stopwatch()..start();
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      stopwatch.stop();

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _latency = stopwatch.elapsedMilliseconds;
        
        // Update Quality
        if (_latency < 300) {
          _quality = ConnectionQuality.excellent;
        } else if (_latency < 800) {
          _quality = ConnectionQuality.good;
        } else {
          _quality = ConnectionQuality.slow;
        }

        // AUTO SWITCH LOGIC
        if (_autoSwitchEnabled) {
          // If internet is extremely poor (> 1500ms), force offline
          if (_latency > 1500 && !_lowInternetMode) {
            print("ConnectivityService: Poor Connection ($_latency ms). Auto-switching to OFFLINE.");
            _lowInternetMode = true;
            _saveLowModePreference(true);
          } 
          // If internet becomes strong (< 500ms), go back online
          else if (_latency < 500 && _lowInternetMode) {
            print("ConnectivityService: Strong Connection ($_latency ms). Auto-switching to ONLINE.");
            _lowInternetMode = false;
            _saveLowModePreference(false);
            if (_autoSyncEnabled) triggerAutoSync();
          }
        }
      }
    } catch (_) {
      _quality = ConnectionQuality.offline;
      if (_autoSwitchEnabled && !_lowInternetMode) {
        _lowInternetMode = true;
        _saveLowModePreference(true);
      }
    }
    notifyListeners();
  }

  Future<void> _saveLowModePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('low_internet_mode', value);
  }

  Future<void> setLowInternetMode(bool value) async {
    _lowInternetMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('low_internet_mode', value);
    notifyListeners();
    if (!_lowInternetMode && _isOnline && _autoSyncEnabled) {
      triggerAutoSync();
    }
  }

  Future<void> setAutoSwitchEnabled(bool value) async {
    _autoSwitchEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_switch_enabled', value);
    notifyListeners();
  }

  Future<void> setAutoSyncEnabled(bool value) async {
    _autoSyncEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_enabled', value);
    notifyListeners();
  }

  Future<void> triggerAutoSync() async {
    if (_isSyncing || !isOnline) return;
    
    _isSyncing = true;
    notifyListeners();
    print('ConnectivityService: Sync started');

    try {
      await Sell().createApiSell(syncAll: true);
      await Variations().refresh();
      print('ConnectivityService: Sync completed');
    } catch (e) {
      print('ConnectivityService: Sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _latencyTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
