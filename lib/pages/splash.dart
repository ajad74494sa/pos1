import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/connectivity_service.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/database.dart';
import '../models/system.dart';

class LoginIntent extends Intent {
  const LoginIntent();
}

class Splash extends StatefulWidget {
  static int themeType = 1;

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _dataController;
  final FocusNode _focusNode = FocusNode();

  // Real-time data simulation
  double _cpuValue = 12.0;
  int _latencyValue = 0;
  double _ramValue = 42.0;
  double _diskValue = 78.0;
  double _tempValue = 45.0;
  double _sendSpeed = 0.0;
  double _receiveSpeed = 0.0;
  late Timer _dataTimer;
  late Timer _latencyTimer;
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    changeLanguage();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _dataController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Start real-time data fluctuation
    _dataTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          _cpuValue = 5 + math.Random().nextDouble() * 15; // 5% - 20%
          _ramValue = 35 + math.Random().nextDouble() * 10; // 35% - 45%
          _diskValue = 72 + math.Random().nextDouble() * 2; // 72% - 74%
          _tempValue = 36 + math.Random().nextDouble() * 8; // 36°C - 44°C
        });
      }
    });

    // Real Latency Check
    _latencyTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (mounted) {
        final stopwatch = Stopwatch()..start();
        try {
          // Attempting a real lightweight connection to check delay
          await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 1));
          if (mounted) {
            setState(() {
              _latencyValue = stopwatch.elapsedMilliseconds;

              // Simulate speed based on latency (Lower latency = Higher speed)
              // This makes the data feel "real" to the user
              if (_latencyValue > 0) {
                double baseSpeed = 1000 / _latencyValue; // higher ms = lower speed
                _sendSpeed = (baseSpeed * 0.1) + math.Random().nextDouble() * 2;
                _receiveSpeed = (baseSpeed * 0.5) + math.Random().nextDouble() * 10;
              } else {
                _sendSpeed = 0;
                _receiveSpeed = 0;
              }
            });
          }
        } catch (_) {
          if (mounted) setState(() {
            _latencyValue = 0;
            _sendSpeed = 0;
            _receiveSpeed = 0;
          });
        }
      }
    });

    // Request focus for keyboard shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _dataController.dispose();
    _dataTimer.cancel();
    _latencyValue = 0; // stop timer
    _latencyTimer.cancel();
    _clockTimer.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  var selectedLanguage;
  void changeLanguage() async {
    var prefs = await SharedPreferences.getInstance();
    selectedLanguage =
        prefs.getString('language_code') ?? Config().defaultLanguage;
    setState(() {});
  }

  Future<void> _performLogin() async {
    await Helper().requestAppPermission();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

    if (isFirstLaunch) {
      Navigator.of(context).pushReplacementNamed('/onBoarding');
    } else if (prefs.getInt('userId') != null) {
      Config.userId = prefs.getInt('userId');
      
      // Explicitly initialize database and ensure basic data exists
      try {
        await DbProvider().database;
        var user = await System().get('loggedInUser');
        if (user == null || (user is List && user.isEmpty)) {
          // If session data is missing in DB, force re-login
          Config.userId = null;
          Navigator.of(context).pushReplacementNamed('/login');
          return;
        }
      } catch (e) {
        print("Splash DB init error: $e");
      }

      Helper().jobScheduler();
      Navigator.of(context).pushReplacementNamed('/layout');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    MySize().init(context);
    final Color techColor = Colors.cyanAccent.shade400;
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const LoginIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const LoginIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          LoginIntent: CallbackAction<LoginIntent>(
            onInvoke: (LoginIntent intent) => _performLogin(),
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Scaffold(
            backgroundColor: const Color(0xFF001111), // Deep high-tech black
            body: Stack(
              children: [
                // 1. Futuristic Background Grid
                CustomPaint(
                  size: Size.infinite,
                  painter: TechGridPainter(techColor.withOpacity(0.05)),
                ),

                // 2. Main Animated Tech Core
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Inner glowing circle
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: techColor.withOpacity(0.2 * _pulseController.value),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                  border: Border.all(color: techColor.withOpacity(0.3), width: 1),
                                ),
                              );
                            },
                          ),

                          // Rotating Data Rings
                          RotationTransition(
                            turns: _rotationController,
                            child: CustomPaint(
                              size: const Size(260, 260),
                              painter: TechRingPainter(techColor),
                            ),
                          ),

                          // Counter-rotating outer ring
                          RotationTransition(
                            turns: ReverseAnimation(_rotationController),
                            child: CustomPaint(
                              size: const Size(320, 320),
                              painter: OuterTechRingPainter(techColor),
                            ),
                          ),

                          // Central Text
                          Column(
                            children: [
                              Text(
                                'KR POS',
                                style: TextStyle(
                                  color: techColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 8,
                                  shadows: [Shadow(color: techColor, blurRadius: 15)],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'INITIALIZING...',
                                style: TextStyle(
                                  color: techColor.withOpacity(0.7),
                                  fontSize: 10,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 80),

                      // Interactive Login Button
                      Container(
                        width: 300,
                        child: Column(
                          children: [
                            _buildTechButton(
                              text: AppLocalizations.of(context).translate('login'),
                              color: techColor,
                              onPressed: _performLogin,
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF001A1A),
                                    title: Text(
                                      AppLocalizations.of(context).translate('language'),
                                      style: TextStyle(color: techColor),
                                    ),
                                    content: changeAppLanguage(),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('CLOSE', style: TextStyle(color: techColor)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Text(
                                AppLocalizations.of(context).translate('language').toUpperCase(),
                                style: TextStyle(color: techColor.withOpacity(0.6), letterSpacing: 2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Floating Data Points (Decoration)
                if (!isSmallScreen) ...[
                  Positioned(
                    top: 80,
                    right: 30,
                    child: _buildSpeedModule(techColor),
                  ),
                  Positioned(
                    top: 200,
                    right: 40,
                    child: _buildDataModule('LATENCY', '$_latencyValue MS',
                        _latencyValue > 0 ? techColor : Colors.redAccent),
                  ),
                  Positioned(
                    bottom: 240,
                    left: 40,
                    child: _buildDataModule(
                        'TEMP', '${_tempValue.toStringAsFixed(1)}°C', techColor),
                  ),
                  Positioned(
                    bottom: 180,
                    left: 30,
                    child: _buildDataModule(
                        'DISK', '${_diskValue.toStringAsFixed(1)}%', techColor),
                  ),
                  Positioned(
                    top: 150,
                    left: 30,
                    child: Consumer<ConnectivityService>(
                        builder: (context, connectivity, child) {
                      return _buildDataModule(
                          'SYNC',
                          connectivity.isOnline ? 'ONLINE' : 'OFFLINE',
                          connectivity.isOnline
                              ? Colors.greenAccent
                              : Colors.redAccent);
                    }),
                  ),
                ],

                // Always shown on all screens: CPU and Clock
                Positioned(
                  bottom: isSmallScreen ? 40 : 120,
                  left: isSmallScreen ? 30 : 40,
                  child: _buildDataModule(
                      'CPU', '${_cpuValue.toStringAsFixed(1)}%', techColor),
                ),

                Positioned(
                  top: isSmallScreen ? 60 : 250,
                  right: isSmallScreen ? 30 : 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        intl.DateFormat('HH:mm:ss').format(_currentTime),
                        style: TextStyle(
                          color: techColor,
                          fontSize: isSmallScreen ? 20 : 28,
                          fontWeight: FontWeight.w100,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                                color: techColor.withOpacity(0.5),
                                blurRadius: 10)
                          ],
                        ),
                      ),
                      Text(
                        intl.DateFormat('EEEE, MMMM d, yyyy')
                            .format(_currentTime)
                            .toUpperCase(),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: techColor.withOpacity(0.5),
                          fontSize: isSmallScreen ? 8 : 9,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedModule(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _speedRow('Send', _sendSpeed, true, color),
        const SizedBox(height: 12),
        _speedRow('Receive', _receiveSpeed, false, color),
      ],
    );
  }

  Widget _speedRow(String label, double value, bool isDashed, Color color) {
    // Standard conversion logic: if < 1 Mbps, show as Kbps
    String unit = value >= 1.0 ? 'Mbps' : 'Kbps';
    double displayNum = value >= 1.0 ? value : (value * 1024);
    String displayValue = displayNum.toStringAsFixed(1);
    if (_latencyValue == 0) displayValue = "0.0";

    return Row(
      children: [
        // Vertical indicator line (Dashed for Send, Solid for Receive)
        if (isDashed)
          Column(
            children: List.generate(4, (index) => Container(
              width: 2,
              height: 6,
              margin: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                boxShadow: [BoxShadow(color: color, blurRadius: 4)],
              ),
            )),
          )
        else
          Container(
            width: 2,
            height: 35,
            decoration: BoxDecoration(
              color: color.withOpacity(0.8),
              boxShadow: [BoxShadow(color: color, blurRadius: 4)],
            ),
          ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color.withOpacity(0.5), fontSize: 10, letterSpacing: 1)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(displayValue, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Text(unit, style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataModule(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.5), fontSize: 10, letterSpacing: 1)),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Container(height: 1, width: 60, color: color.withOpacity(0.3)),
      ],
    );
  }

  Widget _buildTechButton({required String text, required Color color, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 10),
          ],
        ),
        child: Stack(
          children: [
            // Corner details
            Positioned(top: 0, left: 0, child: Container(width: 10, height: 10, color: color)),
            Positioned(bottom: 0, right: 0, child: Container(width: 10, height: 10, color: color)),
            Center(
              child: Text(
                text.toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget changeAppLanguage() {
    var appLanguage = Provider.of<AppLanguage>(context);
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        dropdownColor: const Color(0xFF001A1A),
        onChanged: (String? newValue) {
          appLanguage.changeLanguage(Locale(newValue!), newValue);
          setState(() {
            selectedLanguage = newValue;
          });
          Navigator.pop(context);
        },
        value: Config().lang.any((l) => l['languageCode'] == selectedLanguage)
            ? selectedLanguage
            : (Config().lang.isNotEmpty ? Config().lang[0]['languageCode'] : null),
        items: Config().lang.map<DropdownMenuItem<String>>((Map locale) {
          return DropdownMenuItem<String>(
            value: locale['languageCode'],
            child: Text(
              locale['name'],
              style: TextStyle(color: Colors.cyanAccent.shade400, fontWeight: FontWeight.w600),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class TechGridPainter extends CustomPainter {
  final Color color;
  TechGridPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    const double step = 40;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TechRingPainter extends CustomPainter {
  final Color color;
  TechRingPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw dashed ring
    for (int i = 0; i < 8; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        (i * math.pi / 4),
        math.pi / 8,
        false,
        paint,
      );
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class OuterTechRingPainter extends CustomPainter {
  final Color color;
  OuterTechRingPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius, paint);

    final dashPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi / 4,
      false,
      dashPaint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
