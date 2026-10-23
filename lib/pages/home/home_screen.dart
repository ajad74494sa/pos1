import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:krpos/config.dart';
import 'package:krpos/helpers/AppTheme.dart';
import 'package:krpos/helpers/icons.dart';
import 'package:krpos/locale/MyLocalizations.dart';
import 'package:krpos/models/sellDatabase.dart';
import 'package:krpos/pages/home/widgets/greeting_widget.dart';
import 'package:krpos/pages/notifications/view_model_manger/notifications_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/otherHelpers.dart';
import 'widgets/statistics_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static ThemeData themeData = AppTheme.getThemeFromThemeMode(1);
  static GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      appBar: AppBar(
        backgroundColor: const Color(0xff732a13),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context).translate('home'),
          style: AppTheme.getTextStyle(
            themeData.textTheme.titleLarge,
            fontWeight: 600,
            color: Colors.white,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              /*     (await Helper().checkConnectivity())
                    ? await sync()
                    : Helper().showNotification(context, AppLocalizations.of(context)
                        .translate('check_connectivity'), isError: true);*/
            },
            icon: const Icon(Symbols.sync, color: Colors.white),
          ),
          IconButton(
            onPressed: () async {
              List unsyncedSells = await SellDatabase().getNotSyncedSells();
              if (unsyncedSells.isNotEmpty) {
                Helper().showNotification(
                  context,
                  AppLocalizations.of(context).translate('sync_all_sales_before_logout'),
                  isError: true,
                );
                return;
              }
              SharedPreferences prefs = await SharedPreferences.getInstance();
              prefs.setInt('prevUserId', Config.userId!);
              prefs.remove('userId');
              Config.userId = null; // Clear session data
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout, color: Colors.redAccent),
          ),
        ],
        leading: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                child: const Icon(Icons.list, color: Colors.white),
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
            const SizedBox(width: 10),
            BlocBuilder<NotificationsCubit, NotificationsState>(
              builder: (context, state) {
                return Badge.count(
                  smallSize: 10,
                  largeSize: 15,
                  alignment: AlignmentDirectional.topEnd,
                  count: NotificationsCubit.get(context).notificationsCount,
                  child: GestureDetector(
                    onTap: () {
                      //    Navigator.pushNamed(context, '/notify');
                    },
                    child: const Icon(
                      IconBroken.Notification,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        leadingWidth: 75,
        bottom: GreetingWidget(themeData: themeData, userName: 'Shehab'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Statistics(
              themeData: themeData,
              totalSales: 0,
              totalReceivedAmount: 0,
              totalDueAmount: 0,
              totalSalesAmount: 0,
            ),
          ],
        ),
      ),
    );
  }
}
