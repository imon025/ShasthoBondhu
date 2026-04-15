import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;

class NearbyHospitalsScreen extends StatefulWidget {
  const NearbyHospitalsScreen({super.key});

  @override
  State<NearbyHospitalsScreen> createState() => _NearbyHospitalsScreenState();
}

class _NearbyHospitalsScreenState extends State<NearbyHospitalsScreen> {
  LatLng? _currentLocation;
  final MapController _mapController = MapController();
  List<Marker> _hospitalMarkers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _fetchNearbyHospitals() async {
    if (_currentLocation == null) return;
    final lat = _currentLocation!.latitude;
    final lon = _currentLocation!.longitude;

    // Overpass query to find amenities around the location (within 5000 meters)
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
          final tags = element['tags'] ?? {};
          final name = tags['name'] ?? 'Hospital';

          if (elementLat != null && elementLon != null) {
            markers.add(
              Marker(
                width: 60,
                height: 60,
                point: LatLng(elementLat, elementLon),
                alignment: Alignment.topCenter, // The tip of the pin is at the bottom of the 60x60 area
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(name)),
                    );
                  },
                  child: const _MedicalPinMarker(),
                ),
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

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    void setFallbackLocation() {
      if (!mounted) return;
      setState(() {
        _currentLocation = const LatLng(23.8103, 90.4125); // Dhaka Fallback
        _isLoading = false;
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
          _isLoading = false;
          _fetchNearbyHospitals();
        });
      }
    } catch (e) {
      setFallbackLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Nearby Hospitals',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: theme.primaryColor,
        centerTitle: true,
      ),
      body: _isLoading || _currentLocation == null
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
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
