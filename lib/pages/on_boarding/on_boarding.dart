import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:krpos/helpers/SizeConfig.dart';
import 'package:krpos/helpers/AppTheme.dart';
import 'package:krpos/locale/MyLocalizations.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Welcome to KR POS',
      'description': 'The next generation of point-of-sale systems, designed for speed and reliability.',
      'lottie': 'assets/lottie/welcome.json',
    },
    {
      'title': 'Intelligent Cart',
      'description': 'Manage your orders effortlessly with our streamlined cart management system.',
      'lottie': 'assets/lottie/cart_empty.json',
    },
    {
      'title': 'Smart Notifications',
      'description': 'Stay updated with real-time alerts about your business operations.',
      'lottie': 'assets/lottie/bell.json',
    },
  ];

  void _onFinish() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    MySize().init(context);
    final Color techColor = Colors.cyanAccent.shade400;

    return Scaffold(
      backgroundColor: const Color(0xFF001111),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _onboardingData.length,
            itemBuilder: (context, index) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    _onboardingData[index]['lottie']!,
                    height: MySize.screenHeight! * 0.4,
                  ),
                  SizedBox(height: MySize.size40),
                  Text(
                    _onboardingData[index]['title']!,
                    style: TextStyle(
                      color: techColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(MySize.size32!),
                    child: Text(
                      _onboardingData[index]['description']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: MySize.size60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _onboardingData.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? techColor : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MySize.size40),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: MySize.size32!),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _onFinish,
                        child: Text(
                          'SKIP',
                          style: TextStyle(color: Colors.white54, letterSpacing: 2),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (_currentPage == _onboardingData.length - 1) {
                            _onFinish();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.ease,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: techColor, width: 1.5),
                            boxShadow: [
                              BoxShadow(color: techColor.withOpacity(0.1), blurRadius: 10),
                            ],
                          ),
                          child: Text(
                            _currentPage == _onboardingData.length - 1 ? 'GET STARTED' : 'NEXT',
                            style: TextStyle(
                              color: techColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
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
