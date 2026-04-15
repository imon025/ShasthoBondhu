import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import '../../../../main.dart'; // Import for themeNotifier
import '../../profile/screens/profile_screen.dart';
import '../../pneumonia/screens/pneumonia_detection_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToNearby;
  const DashboardScreen({super.key, this.onNavigateToNearby});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  LatLng? _currentLocation;
  final MapController _mapController = MapController();
  List<Marker> _hospitalMarkers = [];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    void setFallbackLocation() {
      if (!mounted) return;
      setState(() {
        _currentLocation = const LatLng(23.8103, 90.4125); // Dhaka Fallback
        _fetchNearbyHospitals();
      });
    }

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return setFallbackLocation();

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return setFallbackLocation();
    }
    
    if (permission == LocationPermission.deniedForever) return setFallbackLocation();

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _fetchNearbyHospitals();
        });
      }
    } catch (e) {
      setFallbackLocation();
    }
  }

  Future<void> _fetchNearbyHospitals() async {
    if (_currentLocation == null) return;
    final lat = _currentLocation!.latitude;
    final lon = _currentLocation!.longitude;

    final query = '''
      [out:json];
      (
        node["amenity"="clinic"](around:5000,$lat,$lon);
        node["amenity"="hospital"](around:5000,$lat,$lon);
      );
      out;
    ''';

    try {
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;
        List<Marker> markers = [];
        for (var element in elements) {
          final elementLat = element['lat'];
          final elementLon = element['lon'];
          if (elementLat != null && elementLon != null) {
            markers.add(
              Marker(
                width: 60,
                height: 60,
                point: LatLng(elementLat, elementLon),
                alignment: Alignment.topCenter,
                child: const _MedicalPinMarker(),
              ),
            );
          }
        }
        if (mounted) {
          setState(() {
            _hospitalMarkers = markers;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch hospitals: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: Drawer(
        backgroundColor: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: theme.primaryColor),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: theme.primaryColor, size: 40),
                      ),
                      const SizedBox(height: 10),
                      const Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: theme.iconTheme.color),
              title: Text('Home', style: theme.textTheme.bodyLarge),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.settings, color: theme.iconTheme.color),
              title: Text('Settings', style: theme.textTheme.bodyLarge),
              onTap: () => Navigator.pop(context),
            ),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, currentMode, child) {
                final isDarkMode = currentMode == ThemeMode.dark || 
                    (currentMode == ThemeMode.system && isDark);
                return SwitchListTile(
                  title: Text('Dark Mode', style: theme.textTheme.bodyLarge),
                  secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: theme.iconTheme.color),
                  value: isDarkMode,
                  onChanged: (bool value) {
                    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                  },
                );
              },
            ),
            const Spacer(),
            ListTile(
              leading: Icon(Icons.logout, color: theme.iconTheme.color),
              title: Text('Logout', style: theme.textTheme.bodyLarge),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Section (Deep Blue)
            Container(
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    children: [
                      // Header: Menu & Profile
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Builder(
                            builder: (context) => IconButton(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              icon: const Icon(Icons.menu, color: Colors.white, size: 32),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                          ),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Mr Farazi',
                                    style: TextStyle(
                                      color: theme.colorScheme.secondary, // Teal
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Edit profile',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.person, color: theme.primaryColor, size: 30),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Categories Title
                      const Text(
                        'Categories',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Categories Icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCategoryIcon(
                            Icons.health_and_safety, 
                            'Pneumonia',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const PneumoniaDetectionScreen()),
                              );
                            },
                          ),
                          _buildCategoryIcon(Icons.face_retouching_natural, 'Skin'),
                          _buildCategoryIcon(Icons.mood, 'Emotion'),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                          decoration: InputDecoration(
                            hintText: 'Search here',
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            suffixIcon: Icon(Icons.search, color: theme.iconTheme.color, size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Section (White)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Near Hospital',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Map Photo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 300,
                      width: double.infinity,
                      child: _currentLocation == null
                        ? Container(
                            color: theme.colorScheme.surface,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _currentLocation!,
                              initialZoom: 14.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.sashthobondhu',
                              ),
                              MarkerLayer(
                                markers: [
                                  // User Location
                                  Marker(
                                    point: _currentLocation!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
                                  ),
                                  // Hospitals
                                  ..._hospitalMarkers,
                                ],
                              ),
                            ],
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Show All Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () {
                        if (widget.onNavigateToNearby != null) {
                          widget.onNavigateToNearby!();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Show All >',
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
    );
  }

  Widget _buildCategoryIcon(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFFFB4A2), size: 36), // Pinkish icon color
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _MedicalPinMarker extends StatefulWidget {
  const _MedicalPinMarker();

  @override
  State<_MedicalPinMarker> createState() => _MedicalPinMarkerState();
}

class _MedicalPinMarkerState extends State<_MedicalPinMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Ripple effect
            Positioned(
              bottom: 20, // Centered on the pin head
              child: Container(
                width: 25 + (30 * _controller.value),
                height: 25 + (30 * _controller.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.4 * (1 - _controller.value)),
                ),
              ),
            ),
            // Pin Shape
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Head
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.red, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.add, color: Colors.red, size: 20),
                  ),
                ),
                // Tip
                CustomPaint(
                  size: const Size(12, 10),
                  painter: _PinTipPainter(color: Colors.red),
                ),
                const SizedBox(height: 10), // Offset to keep tip at center bottom of stack
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PinTipPainter extends CustomPainter {
  final Color color;
  _PinTipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final ui.Path path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
