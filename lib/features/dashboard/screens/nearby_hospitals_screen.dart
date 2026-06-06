import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class NearbyHospitalsScreen extends StatefulWidget {
  final String initialFilter;
  final VoidCallback? onBack;
  const NearbyHospitalsScreen({super.key, this.initialFilter = 'All', this.onBack});

  @override
  State<NearbyHospitalsScreen> createState() => _NearbyHospitalsScreenState();
}

class _NearbyHospitalsScreenState extends State<NearbyHospitalsScreen> with TickerProviderStateMixin {
  LatLng? _currentLocation;
  final MapController _mapController = MapController();
  List<Marker> _hospitalMarkers = [];
  List<dynamic> _allElements = [];
  bool _isLoading = true;
  List<LatLng> _routePoints = [];

  late String _selectedFilter;

  // Colors based on premium palette
  static const Color sageGreen = Color(0xFF3D8361);
  static const Color softMedicalRed = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _determinePosition();
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    final controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    final Animation<double> animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  Future<void> _fetchNearbyHospitals() async {
    if (_currentLocation == null) return;
    final lat = _currentLocation!.latitude;
    final lon = _currentLocation!.longitude;

    if (_allElements.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = true);
      }
      final query = '''
        [out:json];
        (
          node["amenity"="hospital"](around:5000,$lat,$lon);
          node["amenity"="clinic"](around:5000,$lat,$lon);
          node["amenity"="pharmacy"](around:5000,$lat,$lon);
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
          _allElements = data['elements'] as List;
        }
      } catch (e) {
        debugPrint('Failed to fetch hospitals: $e');
      }
    }

    _updateMarkers();
  }

  Future<void> _fetchRoute(LatLng destination) async {
    if (_currentLocation == null) return;

    final startLon = _currentLocation!.longitude;
    final startLat = _currentLocation!.latitude;
    final endLon = destination.longitude;
    final endLat = destination.latitude;

    final url = 'https://router.project-osrm.org/route/v1/driving/$startLon,$startLat;$endLon,$endLat?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          
          setState(() {
            _routePoints = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
          });
          
          final bounds = LatLngBounds.fromPoints([_currentLocation!, destination, ..._routePoints]);
          _mapController.fitCamera(
             CameraFit.bounds(
               bounds: bounds,
               padding: const EdgeInsets.all(60.0),
             ),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch route: $e');
    }
  }

  void _updateMarkers() {
    List<Marker> markers = [];
    final Distance distanceCalc = const Distance();

    for (var element in _allElements) {
      final tags = element['tags'] ?? {};
      final amenity = tags['amenity'];

      bool matchesFilter = false;
      if (_selectedFilter == 'All') {
        matchesFilter = true;
      } else if (_selectedFilter == 'Hospital' && amenity == 'hospital') {
        matchesFilter = true;
      } else if (_selectedFilter == 'Clinic' && amenity == 'clinic') {
        matchesFilter = true;
      } else if (_selectedFilter == 'Medicine' && amenity == 'pharmacy') {
        matchesFilter = true;
      }

      if (!matchesFilter) continue;

      final elementLat = element['lat'];
      final elementLon = element['lon'];

      if (elementLat != null && elementLon != null) {
        final name = tags['name'] ?? 'Unknown Facility';
        final phone = tags['phone'] ?? tags['contact:phone'] ?? 'Not available';
        final address = tags['addr:full'] ?? tags['addr:street'] ?? 'Address not available';
        final emergency = tags['emergency'] ?? 'Not specified';
        final openingHours = tags['opening_hours'] ?? 'Not specified';
        
        final latLng = LatLng(elementLat, elementLon);
        double dist = _currentLocation != null ? distanceCalc.as(LengthUnit.Meter, _currentLocation!, latLng) : 0;

        markers.add(
          Marker(
            width: 80,
            height: 80,
            point: latLng,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                _animatedMapMove(latLng, 16.0);
                _showDetailsBottomSheet(
                  context,
                  name: name,
                  phone: phone,
                  address: address,
                  emergency: emergency,
                  openingHours: openingHours,
                  distance: dist,
                  destination: latLng,
                );
              },
              child: const _AnimatedMedicalPinMarker(),
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _hospitalMarkers = markers;
        _isLoading = false;
      });
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Nearby', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_currentLocation == null)
            const Center(child: CircularProgressIndicator(color: sageGreen))
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation!,
                initialZoom: 14.0,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.sashthobondhu',
                ),
                if (_hospitalMarkers.isNotEmpty)
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 45,
                      size: const Size(44, 44),
                      markers: _hospitalMarkers,
                      builder: (context, markers) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sageGreen,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                               BoxShadow(color: sageGreen.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2)
                            ]
                          ),
                          child: Center(
                            child: Text(
                              markers.length.toString(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blueAccent.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    // User Location
                    Marker(
                      point: _currentLocation!,
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      child: const _AnimatedMedicalPinMarker(isUser: true),
                    ),
                  ],
                ),
              ],
            ),

          if (_isLoading && _currentLocation != null)
            Positioned(
              top: kToolbarHeight + 80,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: sageGreen),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (_currentLocation != null)
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildGlassChip('All', Icons.apps),
                    const SizedBox(width: 8),
                    _buildGlassChip('Hospital', Icons.local_hospital_rounded),
                    const SizedBox(width: 8),
                    _buildGlassChip('Clinic', Icons.medical_services_rounded),
                    const SizedBox(width: 8),
                    _buildGlassChip('Medicine', Icons.medication_rounded),
                  ],
                ),
              ),
            ),
            
          if (_currentLocation != null)
            Positioned(
              bottom: 32,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                      boxShadow: const [
                         BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                      ]
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.my_location_rounded, color: sageGreen),
                      onPressed: () {
                        if (_currentLocation != null) {
                          _animatedMapMove(_currentLocation!, 15.0);
                        }
                      },
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildGlassChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    final color = isSelected ? Colors.white : sageGreen;
    final bgColor = isSelected ? sageGreen.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.7);

    return GestureDetector(
      onTap: () {
        if (_selectedFilter != label) {
          setState(() {
            _selectedFilter = label;
            _routePoints = [];
          });
          _updateMarkers();
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.6)),
              boxShadow: isSelected ? [BoxShadow(color: sageGreen.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailsBottomSheet(
    BuildContext context, {
    required String name,
    required String phone,
    required String address,
    required String emergency,
    required String openingHours,
    required double distance,
    required LatLng destination,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) {
        final distanceStr = distance > 1000 ? '${(distance / 1000).toStringAsFixed(1)} km' : '${distance.toInt()} m';
        final timeMins = (distance / 80).ceil(); // Assuming ~80m/min walking speed
        final isOpen = openingHours.toLowerCase() == '24/7' || openingHours != 'Not specified';
        final hasEmergency = emergency == 'yes';

        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (_, controller) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1.5)),
                  ),
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.black54),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black87, height: 1.2),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: _buildInfoCard(Icons.directions_walk_rounded, distanceStr, '$timeMins min', sageGreen)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInfoCard(Icons.access_time_rounded, isOpen ? 'Open' : 'Status', isOpen ? 'Available' : 'Unknown', Colors.blue)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInfoCard(Icons.warning_amber_rounded, 'Emergency', hasEmergency ? 'Yes' : 'No', softMedicalRed)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildDetailRow(Icons.location_on_rounded, 'Address', address),
                      const SizedBox(height: 16),
                      _buildDetailRow(Icons.phone_rounded, 'Contact', phone),
                      const SizedBox(height: 16),
                      _buildDetailRow(Icons.schedule_rounded, 'Opening Hours', openingHours),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _fetchRoute(destination);
                          },
                          icon: const Icon(Icons.directions_rounded, color: Colors.white),
                          label: const Text('Get Directions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sageGreen,
                            elevation: 8,
                            shadowColor: sageGreen.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoCard(IconData icon, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.black54, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimatedMedicalPinMarker extends StatefulWidget {
  final bool isUser;
  const _AnimatedMedicalPinMarker({this.isUser = false});

  @override
  State<_AnimatedMedicalPinMarker> createState() => _AnimatedMedicalPinMarkerState();
}

class _AnimatedMedicalPinMarkerState extends State<_AnimatedMedicalPinMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isUser ? Colors.blue : const Color(0xFFFF6B6B);
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 40 + (_controller.value * 30),
              height: 40 + (_controller.value * 30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.2 - (_controller.value * 0.15)),
              ),
            );
          },
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: primaryColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Center(
            child: Icon(widget.isUser ? Icons.person_rounded : Icons.local_hospital_rounded, color: primaryColor, size: 20),
          ),
        ),
      ],
    );
  }
}
