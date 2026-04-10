import 'package:flutter/material.dart';

class OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color activeColor;

  const OnboardingPage({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    required this.activeColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Minimal Icon Section
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: activeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 100,
                    color: activeColor,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 50),
          
          // Bottom Section with Text
          Text(
            'WELCOME TO',
            style: TextStyle(
              color: activeColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF033A6B), // Deep Blue Dashboard Color
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.blueGrey.shade600,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          // Extra space to prevent overlapping with bottom buttons
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
