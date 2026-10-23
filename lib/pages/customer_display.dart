import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import '../helpers/futuristic_loader.dart';

class CustomerDisplay extends StatefulWidget {
  final String windowId;
  CustomerDisplay({this.windowId = ""});

  @override 
  _CustomerDisplayState createState() => _CustomerDisplayState();
}

class _CustomerDisplayState extends State<CustomerDisplay> {
  List<dynamic> cartItems = [];
  String total = "0.00";
  String symbol = "";

  @override
  void initState() {
    super.initState();
    WindowController.fromWindowId(widget.windowId).setWindowMethodHandler((call) async {
      if (call.method == "updateData") {
        final decoded = jsonDecode(call.arguments);
        setState(() {
          cartItems = decoded['items'] ?? [];
          total = decoded['total']?.toString() ?? "0.00";
          symbol = decoded['symbol'] ?? "";
        });
      } else if (call.method == "setFrame") {
        final args = call.arguments as Map;
        await windowManager.setBounds(Rect.fromLTWH(
          (args['x'] as num).toDouble(),
          (args['y'] as num).toDouble(),
          (args['width'] as num).toDouble(),
          (args['height'] as num).toDouble(),
        ));
      } else if (call.method == "setTitle") {
        await windowManager.setTitle(call.arguments as String);
      } else if (call.method == "close") {
        await windowManager.close();
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000505), // Dark Theme
      body: Stack(
        children: [
          // Background Grid
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(),
            ),
          ),
          SafeArea(
            child: cartItems.isEmpty ? _buildSplashScreen() : _buildResponsiveLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildSplashScreen() {
    return Center(
      child: FuturisticLoader(
        size: 400,
        title: "KR POS",
        subTitle: "WELCOME TO OUR STORE",
        showGrid: false, // Grid is already in background
      ),
    );
  }

  Widget _buildResponsiveLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > constraints.maxHeight * 1.2;
        
        if (isWide) {
          return Row(
            children: [
              Expanded(flex: 3, child: _buildCartSection()),
              // const VerticalDivider(color: Colors.cyanAccent, width: 1, thickness: 0.5),
              // Expanded(flex: 2, child: _buildPromotionSection()),
            ],
          );
        } else {
          return _buildCartSection();
        }
      },
    );
  }

  Widget _buildCartSection() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          Expanded(child: _buildItemList()),
          const SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "SHOPPING CART",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.cyanAccent,
                letterSpacing: 2,
              ),
            ),
            Container(
              height: 4,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.cyanAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        Text(
          "${cartItems.length} ITEMS",
          style: const TextStyle(fontSize: 24, color: Colors.white70, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildItemList() {
    return ListView.separated(
      itemCount: cartItems.length,
      separatorBuilder: (context, index) => Divider(color: Colors.white.withOpacity(0.1), height: 1),
      itemBuilder: (context, index) {
        final item = cartItems[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? "",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "QUANTITY: ${item['quantity']}",
                      style: const TextStyle(fontSize: 18, color: Colors.cyanAccent, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Text(
                "$symbol ${item['price']}",
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "TOTAL AMOUNT",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          Text(
            "$symbol $total",
            style: const TextStyle(
              fontSize: 60,
              fontWeight: FontWeight.w900,
              color: Colors.greenAccent,
              shadows: [
                Shadow(color: Colors.greenAccent, blurRadius: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_2, size: 200, color: Colors.cyanAccent),
          const SizedBox(height: 40),
          const Text(
            "KR POS",
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),
          const Text(
            "SCAN TO PAY",
            style: TextStyle(fontSize: 24, color: Colors.cyanAccent, letterSpacing: 4),
          ),
          const Spacer(),
          const Text(
            "THANK YOU FOR SHOPPING!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white38, fontWeight: FontWeight.w300),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    double step = 40.0;
    for (double i = 0; i <= size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
