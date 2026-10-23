import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:krpos/apis/api.dart';
import 'package:krpos/locale/MyLocalizations.dart';
import 'package:krpos/apis/system.dart';
import 'package:krpos/apis/user.dart';
import 'package:krpos/config.dart';
import 'package:krpos/helpers/AppTheme.dart';
import 'package:krpos/helpers/otherHelpers.dart';
import 'package:krpos/models/contact_model.dart';
import 'package:krpos/models/database.dart';
import 'package:krpos/models/sellDatabase.dart';
import 'package:krpos/models/system.dart';
import 'package:krpos/models/variations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../services/printer_service.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(LoginInitial());

  static LoginCubit get(BuildContext context) => BlocProvider.of(context);

  final LocalAuthentication auth = LocalAuthentication();
  final storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: true),
  );

  @override
  Future<void> close() async {
    _usernameController.dispose();
    _passwordController.dispose();
    return super.close();
  }

  ///private variables
  static int _themeType = 1;
  ThemeData _themeData = AppTheme.getThemeFromThemeMode(_themeType);
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  IconData _passwordIcon = Symbols.visibility_off;

  ///Getters
  ThemeData get themeData => _themeData;

  GlobalKey<FormState> get formKey => _formKey;

  TextEditingController get usernameController => _usernameController;

  TextEditingController get passwordController => _passwordController;

  bool get isLoading => _isLoading;

  bool get passwordVisible => _passwordVisible;

  IconData get passwordIcon => _passwordIcon;

  ///Setters
  set isLoading(bool isLoading) => _isLoading = isLoading;

  set passwordVisible(bool passwordVisible) {
    _passwordVisible = passwordVisible;
    if (passwordVisible)
      _passwordIcon = Symbols.visibility;
    else
      _passwordIcon = Symbols.visibility_off;
    emit(LoginChangePasswordVisibility());
  }

  ///Methods
  Future<void> authenticateWithBiometrics(BuildContext context) async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();
      final List<BiometricType> availableBiometrics =
          await auth.getAvailableBiometrics();

      if (!isDeviceSupported) {
        Helper().showNotification(context, "Device does not support biometrics", isError: true);
        return;
      }

      if (availableBiometrics.isEmpty && !canAuthenticateWithBiometrics) {
        Helper().showNotification(context, "No biometrics enrolled on this device", isError: true);
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to login',
          biometricOnly: false,
          persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        // Retrieve credentials for the CURRENTLY entered username
        String username = _usernameController.text.trim();
        if (username.isEmpty) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          username = prefs.getString('last_username') ?? '';
          _usernameController.text = username;
        }

        if (username.isEmpty) {
          Helper().showNotification(context, "Please enter your username first", isError: true);
          return;
        }

        String? savedPassword =
            await storage.read(key: 'fast_password_$username');

        if (savedPassword != null) {
          _passwordController.text = savedPassword;
          await checkOnLogin(context);
        } else {
          Helper().showNotification(
              context, "No fast login data for $username. Login normally first.", isError: true);
        }
      } else {
        Helper().showNotification(context, "Authentication failed", isError: true);
      }
    } catch (e) {
      debugPrint("Biometric Error: $e");
      Helper().showNotification(context, "Error: ${e.toString()}", isError: true);
    }
  }

  Future<void> loginWithPin(BuildContext context, String pin) async {
    String username = _usernameController.text.trim();
    if (username.isEmpty) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      username = prefs.getString('last_username') ?? '';
      _usernameController.text = username;
    }

    if (username.isEmpty) {
      Helper().showNotification(context, "Please enter your username first", isError: true);
      return;
    }

    String? savedPin = await storage.read(key: 'user_pin_$username');
    if (savedPin == pin) {
      String? savedPassword =
          await storage.read(key: 'fast_password_$username');

      if (savedPassword != null) {
        _passwordController.text = savedPassword;
        await checkOnLogin(context);
      } else {
        Helper().showNotification(
            context, "Credentials missing. Please login with password.", isError: true);
      }
    } else {
      Helper().showNotification(context, "Invalid PIN", isError: true);
    }
  }

  Future<void> saveCredentialsForFastLogin(
      String username, String password) async {
    await storage.write(key: 'fast_password_$username', value: password);

    // Track this user in a list of users who have fast login enabled
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> userList = prefs.getStringList('fast_login_users') ?? [];
    if (!userList.contains(username)) {
      userList.add(username);
      await prefs.setStringList('fast_login_users', userList);
    }
    await prefs.setString('last_username', username);
  }

  Future<void> savePin(BuildContext context, String pin) async {
    // We need the username. Since PIN is saved from Profile, we can get it from loggedInUser
    var user = await System().get('loggedInUser');
    if (user is Map && user.containsKey('username')) {
      String username = user['username'];
      await storage.write(key: 'user_pin_$username', value: pin);
      Helper().showNotification(context, "PIN saved successfully for $username");

    }
  }

  Future<bool> hasFastLoginData() async {
    String username = _usernameController.text.trim();
    if (username.isEmpty) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      username = prefs.getString('last_username') ?? '';
    }

    if (username.isNotEmpty) {
      String? password = await storage.read(key: 'fast_password_$username');
      return password != null;
    }
    return false;
  }

  Future<List<String>> getFastLoginUsers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('fast_login_users') ?? [];
  }

  void selectUserForFastLogin(String username) {
    _usernameController.text = username;
    emit(LoginInitial()); // Refresh UI
  }

  Future<void> _showLoadingDialogue(BuildContext context) async {
    emit(LoginShowLoadingDialogue());
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.1),
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Helper().loadingIndicator(
              context, 
              subTitle: 'AUTHENTICATING...', 
              showBackground: true
            ),
          ),
        );
      },
    );
  }

  Future<bool> _checkInternetConnectivity() async {
    return await Helper().checkConnectivity();
  }

  bool _validateOnData() {
    return _formKey.currentState!.validate() && !_isLoading;
  }

  Future<Map<dynamic, dynamic>?> _makeALogin() async {
    return await Api().login(
      _usernameController.text.trim(), 
      _passwordController.text.trim()
    );
  }

  void navigateToHome(BuildContext context) async {
    // If there's a loading dialog, pop it
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);

    Navigator.of(context).pushReplacementNamed('/layout');
  }

  Future<void> _loadAllData(loginResponse, context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var userData = await User().get(loginResponse['access_token']);

    if (userData == null) {
      throw Exception("Could not fetch user details from server");
    }
    
    Map loggedInUser = userData;
    Config.userId = loggedInUser['id'];

    //saving userId in disk
    prefs.setInt('userId', Config.userId!);
    await DbProvider().initializeDatabase(loggedInUser['id']);

    String? lastSync = await System().getProductLastSync();
    final date2 = DateTime.now();

    //delete system table before saving data
    await System().empty();
    //delete contact table
    await Contact().emptyContact();
    //save user details
    await System().insertUserDetails(loggedInUser);
    //Insert token
    await System().insertToken(loginResponse['access_token']);
    //save system data
    await SystemApi().store();
    await System().insertProductLastSyncDateTimeNow();

    // Ensure printer settings are loaded correctly for this session
    await PrinterService().init();

    //check previous userId
    try {
      if (prefs.getInt('prevUserId') == null ||
          prefs.getInt('prevUserId') != prefs.getInt('userId')) {
        SellDatabase().deleteSellTables();
        Variations().refresh();
      } else {
        if (lastSync == null ||
            (date2.difference(DateTime.parse(lastSync)).inHours > 10)) {
          if (await Helper().checkConnectivity()) {
            Variations().refresh();
            await System().insertProductLastSyncDateTimeNow();
            SellDatabase().deleteSellTables();
          }
        }
      }
    } catch (e) {
      debugPrint("Warning: Failed to initiate background refresh: $e");
    }
  }

  Future<void> checkOnLogin(BuildContext context) async {
    debugPrint("checkOnLogin started");
    if (!await _checkInternetConnectivity()) {
      Helper().showNotification(
        context,
        AppLocalizations.of(context).translate('check_connectivity'),
        isError: true,
      );
      return;
    }

    if (!_validateOnData()) {
      return;
    }

    isLoading = true;
    _showLoadingDialogue(context);

    try {
      var loginResponse = await _makeALogin();
      if (loginResponse?['success'] == true) {
        await saveCredentialsForFastLogin(
            _usernameController.text.trim(), _passwordController.text.trim());

        Helper().jobScheduler();
        await _loadAllData(loginResponse, context);
        emit(LoginSuccessfully());
      } else {
        if (Navigator.canPop(context)) Navigator.of(context).pop();
        emit(LoginFailed(error: loginResponse?['error']));
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      emit(LoginFailed(error: e.toString()));
    } finally {
      isLoading = false;
    }
  }

  Future<void> register() async {
    await launchUrl(Uri.parse('${Config.baseUrl}/business/register'));
  }
}
