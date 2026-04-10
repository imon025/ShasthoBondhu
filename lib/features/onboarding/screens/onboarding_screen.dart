import 'package:flutter/material.dart';
import '../../auth/screens/login_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'icon': Icons.medical_services_rounded,
      'title': 'AI Health\nDetection',
      'description': 'Advanced AI technology to monitor and detect early symptoms of various diseases.',
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

    return Scaffold(
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
          
          // Skip Button
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: _completeOnboarding,
              child: Text(
                'SKIP',
                style: TextStyle(
                  color: Colors.white, // Over the colored circle
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),

          // Bottom Controls (Dots & Button)
          Positioned(
            bottom: 40,
            left: 30,
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Indicators
                Row(
                  children: List.generate(
                    _onboardingData.length,
                    (index) => buildDot(index: index, activeColor: currentColor),
                  ),
                ),
                // Next / Log In Button (Pill shaped, matches Photo 1)
                ElevatedButton(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 10,
                    shadowColor: currentColor.withOpacity(0.5),
                  ),
                  child: Text(
                    _currentPage == _onboardingData.length - 1 ? 'LOG IN' : 'NEXT',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900, 
                      letterSpacing: 1.5,
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

  Widget buildDot({required int index, required Color activeColor}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? activeColor : activeColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
