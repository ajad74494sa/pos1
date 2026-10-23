import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'helpers/AppTheme.dart';
import 'helpers/AppThemeNotifier.dart';
import 'helpers/routes.dart';
import 'locale/MyLocalizations.dart';
import 'pages/notifications/view_model_manger/notifications_cubit.dart';
import 'services/printer_service.dart';
import 'services/connectivity_service.dart';
import 'pages/customer_display.dart';
import 'helpers/customer_display_service.dart';

void main(List<String> args) async {
  debugPrint("--- MAIN START ---");
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("Flutter Binding Initialized");
  
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    debugPrint("Initializing Window Manager...");
    await windowManager.ensureInitialized();
    debugPrint("Window Manager Initialized");
  }

  if (args.firstOrNull == 'multi_window') {
    final windowId = args[1];
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CustomerDisplay(windowId: windowId),
    ));
    return;
  }

  AppLanguage appLanguage = AppLanguage();
  await appLanguage.fetchLocale();
  AppThemeNotifier appThemeNotifier = AppThemeNotifier();
  
  // Restore user session immediately on startup
  final prefs = await SharedPreferences.getInstance();
  Config.userId = prefs.getInt('userId');

  await PrinterService().init();
  runApp(MyApp(
    appLanguage: appLanguage,
    appThemeNotifier: appThemeNotifier,
  ));
}

class MyApp extends StatelessWidget {
  final AppLanguage? appLanguage;
  final AppThemeNotifier? appThemeNotifier;

  const MyApp({super.key, this.appLanguage, this.appThemeNotifier});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationsCubit()..getNotification(),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<AppLanguage>(create: (_) => appLanguage!),
          ChangeNotifierProvider<AppThemeNotifier>(create: (_) => appThemeNotifier!),
          ChangeNotifierProvider<CustomerDisplayService>(create: (_) => CustomerDisplayService()..init()),
          ChangeNotifierProvider<ConnectivityService>(create: (_) => ConnectivityService()),
        ],
        child: Consumer2<AppLanguage, AppThemeNotifier>(builder: (context, model, themeModel, child) {
          return MaterialApp(
            routes: Routes.generateRoute(),
            initialRoute: '/splash',
            debugShowCheckedModeBanner: false,
            //Turns on a little "DEBUG" banner in checked mode to indicate that the app is in checked mode.
            theme: AppTheme.getThemeFromThemeMode(1),
            locale: model.appLocal,
            supportedLocales: Config().supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
          );
        }),
      ),
    );
  }
}
