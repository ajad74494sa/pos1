import 'package:flutter/material.dart';
import 'package:krpos/helpers/AppTheme.dart';
import 'package:krpos/helpers/SizeConfig.dart';

class Block extends StatelessWidget {
  Block({
    this.icon,
    this.iconColor,
    this.subject,
    this.amount,
    required this.themeData,
    this.backgroundColor,
  });

  final IconData? icon;
  final Color? iconColor;
  final String? subject, amount;
  final ThemeData themeData;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    Color cardColor = backgroundColor ?? Colors.white;
    bool isDark = cardColor.computeLuminance() < 0.5;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: cardColor,
      child: Stack(
        children: [
          // Decorative Circle (Style #3)
          Positioned(
            right: -25,
            bottom: -25,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  subject!,
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.labelSmall,
                    fontWeight: 600,
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 1),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "$amount",
                      style: AppTheme.getTextStyle(
                        themeData.textTheme.bodyMedium,
                        fontWeight: 900,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
