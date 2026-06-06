import 'package:flutter/material.dart';
import '../../auth/screens/login_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'icon': Icons.health_and_safety_rounded,
      'title': 'ShasthoBondhu 🩺',
      'description': 'Your intelligent companion for all health-related needs. Let\'s start your journey to a healthier life.',
      'color': AppColors.onb1,
    },
    {
      'icon': Icons.monitor_heart_rounded,
      'title': 'Real-time\nMonitoring',
      'description': 'Ensures accurate health tracking with sophisticated face and eye movement analysis.',
      'color': AppColors.onb2,
    },
    {
      'icon': Icons.document_scanner_rounded,
      'title': 'X-Ray Pneumonia\nAnalysis',
      'description': 'Instantly detect pneumonia symptoms by scanning X-ray reports with our high-precision AI.',
      'color': AppColors.onb3,
    },
    {
      'icon': Icons.face_retouching_natural_rounded,
      'title': 'Mood & Emotion\nTracker',
      'description': 'Keep track of your mental well-being through real-time facial expression and mood analysis.',
      'color': AppColors.onb4,
    },
    {
      'icon': Icons.map_rounded,
      'title': 'Smart Hospital\nFinder',
      'description': 'Find and navigate to the best nearby hospitals and clinics integrated with real-time maps.',
      'color': AppColors.onb5,
    },
    {
      'icon': Icons.medication_rounded,
      'title': 'Personalized\nMedicine',
      'description': 'Get intelligent medicine suggestions tailored to your age, history, and specific health case.',
      'color': AppColors.onb6,
    },
    {
      'icon': Icons.insights_rounded,
      'title': 'Actionable\nInsights',
      'description': 'Receive simple, easy-to-understand health reports and personalized suggestions every day.',
      'color': AppColors.onb7,
    },
  ];

  void _completeOnboarding() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color currentColor = _onboardingData[_currentPage]['color'];

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
        children: [
          // The PageView
          PageView.builder(
            controller: _pageController,
            itemCount: _onboardingData.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              return OnboardingPage(
                icon: _onboardingData[index]['icon'],
                title: _onboardingData[index]['title'],
                description: _onboardingData[index]['description'],
                activeColor: _onboardingData[index]['color'],
              );
            },
          ),
          // Bottom Controls Bar
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Skip Button
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Indicators
                    Row(
                      children: List.generate(
                        _onboardingData.length,
                        (index) => buildDot(index: index),
                      ),
                    ),
                    // Next / Log In Button
                    IconButton(
                      onPressed: () {
                        if (_currentPage < _onboardingData.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOutCubic,
                          );
                        } else {
                          _completeOnboarding();
                        }
                      },
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget buildDot({required int index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.white : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
