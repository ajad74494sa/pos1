import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:krpos/helpers/SizeConfig.dart';

class SalesChart extends StatelessWidget {
  final ThemeData themeData;
  final List<FlSpot> spots;
  final List<String>? xLabels;

  SalesChart({required this.themeData, required this.spots, this.xLabels});

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) return SizedBox.shrink();

    double maxY = 100;
    for (var spot in spots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    maxY = maxY * 1.15; // Minimal headspace
    if (maxY == 0) maxY = 100;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: MySize.size16!, vertical: MySize.size2!),
      padding: EdgeInsets.symmetric(horizontal: MySize.size16!, vertical: MySize.size10!),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales Analytics',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.blueGrey[900],
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(0xff732a13).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '12 Months',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff732a13),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 4.0, // Significant height reduction
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => Color(0xff732a13).withOpacity(0.9),
                    tooltipPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final flSpot = barSpot;
                        if (xLabels == null ||
                            flSpot.x.toInt() < 0 ||
                            flSpot.x.toInt() >= xLabels!.length) {
                          return null;
                        }
                        return LineTooltipItem(
                          '${xLabels![flSpot.x.toInt()]}: ',
                          const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: flSpot.y.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[50],
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: bottomTitleWidgets,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: leftTitleWidgets,
                      reservedSize: 35,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (xLabels != null && xLabels!.isNotEmpty)
                    ? (xLabels!.length - 1).toDouble()
                    : 11,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.4,
                    color: Color(0xff732a13),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 2.5,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: Color(0xff732a13),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xff732a13).withOpacity(0.15),
                          Color(0xff732a13).withOpacity(0.01),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    if (xLabels == null ||
        value.toInt() < 0 ||
        value.toInt() >= xLabels!.length) {
      return Container();
    }

    // Show fewer labels for a cleaner look
    bool shouldShow = false;
    if (xLabels!.length <= 6) {
      shouldShow = true;
    } else {
      // Show first, last and some in between
      int len = xLabels!.length;
      if (value.toInt() == 0 || value.toInt() == len - 1 || value.toInt() % 3 == 0) {
        shouldShow = true;
      }
    }

    if (!shouldShow) return Container();

    return SideTitleWidget(
      meta: meta,
      space: 8,
      child: Text(
        xLabels![value.toInt()],
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    if (value == meta.max || value == meta.min) return Container();

    String text = '';
    if (value >= 1000) {
      text = '${(value / 1000).toStringAsFixed(0)}k';
    } else {
      text = value.toInt().toString();
    }

    return SideTitleWidget(
      meta: meta,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
