import 'package:flutter/material.dart';
import 'package:krpos/helpers/AppTheme.dart';
import 'package:krpos/helpers/SizeConfig.dart';
import 'package:krpos/locale/MyLocalizations.dart';

class GreetingWidget extends StatelessWidget implements PreferredSizeWidget {
  const GreetingWidget({
    super.key,
    required this.themeData,
    required this.userName,
    this.onFilterSelected,
    this.selectedRangeText = 'Filter by date',
  });

  final ThemeData themeData;
  final String userName;
  final Function(String)? onFilterSelected;
  final String selectedRangeText;

  @override
  Widget build(BuildContext context) {
    final List<String> filterOptions = [
      'Today',
      'Yesterday',
      'Last 7 Days',
      'Last 30 Days',
      'This Month',
      'Last Month',
      'This month last year',
      'This Year',
      'Last Year',
      'Current financial year',
      'Last financial year',
      'Custom Range',
    ];

    return Container(
      color: Color(0xff732a13),
      padding: EdgeInsets.symmetric(
          horizontal: MySize.size20!, vertical: MySize.size24!),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context).translate('welcome') + ' ',
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.titleMedium,
                    color: Colors.white,
                    fontWeight: 700,
                  ),
                ),
                Flexible(
                  child: Text(
                    '$userName, 👋',
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.titleMedium,
                      color: Colors.white,
                      fontWeight: 700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: onFilterSelected,
            itemBuilder: (BuildContext context) {
              return filterOptions.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  height: 35,
                  child: Text(
                    choice,
                    style: TextStyle(fontSize: 13),
                  ),
                );
              }).toList();
            },
            offset: Offset(0, 40),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.black),
                  SizedBox(width: 4),
                  Text(
                    selectedRangeText,
                    style: TextStyle(color: Colors.black, fontSize: 10),
                  ),
                  Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.black),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(80);
}
