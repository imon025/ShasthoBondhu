import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dashboard_screen.dart';
import 'nearby_hospitals_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isDetectMenuOpen = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _slideAnimation;

  late final List<Widget> _screens = [
    DashboardScreen(
      onNavigateToNearby: () {
        setState(() {
          _currentIndex = 3;
        });
      },
    ),
    const Center(child: Text('Health Tracking (Coming Soon)')),
    const Center(child: Text('Detect Feature (Coming Soon)')),
    const NearbyHospitalsScreen(),
    const Center(child: Text('Notifications (Coming Soon)')),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _rotationAnimation = Tween<double>(begin: 0, end: 0.125).animate( // 45 degree turn
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<double>(begin: 0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleDetectMenu() {
    setState(() {
      _isDetectMenuOpen = !_isDetectMenuOpen;
      if (_isDetectMenuOpen) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  void _onNavTapped(int index) {
    if (index == 2) {
      if (_currentIndex != 2) {
        setState(() => _currentIndex = 2);
      }
      _toggleDetectMenu();
    } else {
      if (_isDetectMenuOpen) {
        _toggleDetectMenu();
      }
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final surfaceColor = theme.colorScheme.surface;
    final activeTextColor = isDark ? Colors.white : Colors.black87;
    final inactiveIconColor = isDark ? const Color(0xFF94A3B8) : Colors.black54;
    final activeBubbleColor = isDark ? const Color(0xFF3F3F5A) : Colors.white;

    final targetLoc = (_currentIndex + 0.5) / 5;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          
          if (_isDetectMenuOpen)
            GestureDetector(
              onTap: _toggleDetectMenu,
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),

          // Updated Capsule Popup Bar matching user image
          Positioned(
            left: (screenWidth - 280) / 2, // 280 width capsule
            bottom: 110 + (20 * _slideAnimation.value), // Slide up effect
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Opacity(
                opacity: _slideAnimation.value,
                child: Container(
                  width: 280,
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2B52), // Deep navy from image
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCapsuleItem(Icons.camera_alt_outlined, 'Pneumonia'),
                      _buildCapsuleItem(Icons.play_circle_outline, 'Skin'),
                      _buildCapsuleItem(Icons.monetization_on_outlined, 'Emotion'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: SizedBox(
          height: 90,
          child: Stack(
            children: [
              Positioned(
                 bottom: 0,
                 left: 0,
                 right: 0,
                 height: 70,
                 child: TweenAnimationBuilder<double>(
                   tween: Tween<double>(begin: targetLoc, end: targetLoc),
                   duration: const Duration(milliseconds: 300),
                   curve: Curves.easeOutCubic,
                   builder: (context, value, child) {
                     return CustomPaint(
                       painter: _BottomNavCurvePainter(
                         color: surfaceColor,
                         loc: value,
                       ),
                     );
                   },
                 ),
              ),
              
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                top: 0,
                left: (screenWidth / 5) * _currentIndex + 
                      (screenWidth / 5 - 55) / 2,
                child: GestureDetector(
                  onTap: () => _onNavTapped(_currentIndex),
                  child: Container(
                    width: 55,
                    height: 55,
                    decoration: _currentIndex == 2 && _isDetectMenuOpen 
                      ? null // Use custom paint for hexagon when open
                      : BoxDecoration(
                        color: activeBubbleColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ]
                      ),
                    child: CustomPaint(
                      painter: _currentIndex == 2 && _isDetectMenuOpen 
                        ? _HexagonPainter(color: const Color(0xFF4FC3F7)) // Cyan from image
                        : null,
                      child: Center(
                        child: RotationTransition(
                          turns: _currentIndex == 2 ? _rotationAnimation : const AlwaysStoppedAnimation(0),
                          child: Icon(
                            _currentIndex == 2 && _isDetectMenuOpen ? Icons.add : _getIcon(_currentIndex), 
                            color: _currentIndex == 2 && _isDetectMenuOpen ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 70,
                child: Row(
                  children: List.generate(5, (index) {
                    final isSelected = _currentIndex == index;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onNavTapped(index),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isSelected) ...[
                              Icon(_getIcon(index), color: inactiveIconColor, size: 28),
                              const SizedBox(height: 4),
                            ],
                            if (isSelected) const SizedBox(height: 24),
                            Text(
                              _getLabel(index),
                              style: TextStyle(
                                fontSize: isSelected ? 13 : 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? activeTextColor : inactiveIconColor,
                              )
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapsuleItem(IconData icon, String label) {
    return InkWell(
      onTap: () {
        _toggleDetectMenu();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Starting $label scan...')));
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
        ],
      ),
    );
  }

  IconData _getIcon(int index) {
    switch (index) {
      case 0: return Icons.home_outlined;
      case 1: return Icons.monitor_heart_outlined;
      case 2: return Icons.search;
      case 3: return Icons.near_me_outlined;
      case 4: return Icons.notifications_outlined;
      default: return Icons.home;
    }
  }

  String _getLabel(int index) {
    switch (index) {
      case 0: return 'Home';
      case 3: return 'Nearby';
      case 2: return 'Detect';
      case 1: return 'Health';
      case 4: return 'Alerts';
      default: return '';
    }
  }
}

class _HexagonPainter extends CustomPainter {
  final Color color;
  _HexagonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width / 2;

    for (int i = 0; i < 6; i++) {
        double angle = 2 * math.pi / 6 * i - math.pi / 6; // Rotate to have point at top
        double x = centerX + radius * math.cos(angle);
        double y = centerY + radius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
    }
    path.close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.2), 6, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomNavCurvePainter extends CustomPainter {
  final Color color;
  final double loc;
  _BottomNavCurvePainter({required this.color, required this.loc});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    
    final centerX = size.width * loc;
    const curveWidth = 65.0;
    const curveDepth = 45.0;

    path.lineTo(centerX - curveWidth, 0);
    path.cubicTo(
      centerX - curveWidth / 2, 0, 
      centerX - curveWidth / 2, curveDepth, 
      centerX, curveDepth
    );
    path.cubicTo(
      centerX + curveWidth / 2, curveDepth, 
      centerX + curveWidth / 2, 0, 
      centerX + curveWidth, 0
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.08), 5, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BottomNavCurvePainter oldDelegate) => 
      oldDelegate.loc != loc || oldDelegate.color != color;
}
