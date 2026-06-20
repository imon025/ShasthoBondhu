import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nearby_hospitals_screen.dart';
import 'detection_options_page.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF436B46), Color(0xFF2E4E32)], // Soft green gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.4], // Gradient only at the top
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F6F8), // Very light greyish background
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNotificationsHeader(),
                        const SizedBox(height: 16),
                        _buildNotificationCard(),
                        const SizedBox(height: 30),
                        const Text(
                          'Quick Services',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildQuickServices(context),
                        const SizedBox(height: 30),
                        const Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDashboardCards(),
                        const SizedBox(height: 16),
                        _buildActivityCard(),
                        const SizedBox(height: 16),
                        const DashboardMapSection(),
                        const SizedBox(height: 16),
                        _buildWellnessCornerCard(),
                        const SizedBox(height: 100), // Padding for floating bottom nav
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickServices(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildServiceButton(
            context,
            title: 'Nearby',
            subtitle: 'Hospitals',
            icon: Icons.near_me_rounded,
            color: const Color(0xFF436B46),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NearbyHospitalsScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildServiceButton(
            context,
            title: 'Detect',
            subtitle: 'AI Analysis',
            icon: Icons.search_rounded,
            color: const Color(0xFF2E4E32),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DetectionOptionsPage()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildServiceButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.spa_rounded, color: Color(0xFF90B094), size: 30),
              const SizedBox(width: 10),
              const Text(
                'Shasthobondhu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF4B4B),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '12',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              FutureBuilder(
                future: Supabase.instance.client.auth.currentUser != null
                    ? Supabase.instance.client
                        .from('profiles')
                        .select('avatar_url')
                        .eq('id', Supabase.instance.client.auth.currentUser!.id)
                        .maybeSingle()
                    : Future.value(null),
                builder: (context, snapshot) {
                  final data = snapshot.data as Map<String, dynamic>?;
                  final avatarUrl = data?['avatar_url'] as String?;
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                  );
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNotificationsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Text(
                'See more',
                style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 10, color: Colors.black54),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF436B46), // Green color for detection
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.coronavirus_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pneumonia Scan Result',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Status: Normal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Today, 10:24 AM • Detection Module',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 20),
                  SizedBox(width: 8),
                  Text('View Full History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCards() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Latest Activity',
                      style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF386641),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_walk, color: Colors.white, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '5:32 AM',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Today\'s Status',
                      style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF4B4B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.priority_high, color: Colors.white, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Risk!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF4B4B)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Activity',
                style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6F8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Text(
                      'Weekly',
                      style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black54),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '21',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'h',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _buildChartBar('S', 0.4, true),
              _buildChartBar('M', 0.6, true),
              _buildChartBar('T', 0.5, true),
              _buildChartBar('W', 0.3, true),
              _buildChartBar('T', 0.5, true),
              _buildChartBar('F', 0.8, true),
              _buildChartBar('S', 0.0, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(String day, double heightRatio, bool isActive) {
    const double maxHeight = 80;
    final double height = maxHeight * heightRatio;
    
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Column(
        children: [
          Container(
            width: 24,
            height: maxHeight,
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 24,
              height: height > 0 ? height : 4, // Minimum height for 0
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFC8E6C9) : const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            day,
            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessCornerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0F0F0), width: 1, style: BorderStyle.solid),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Wellness corner',
            style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF386641),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class DashboardMapSection extends StatefulWidget {
  const DashboardMapSection({super.key});

  @override
  State<DashboardMapSection> createState() => _DashboardMapSectionState();
}

class _DashboardMapSectionState extends State<DashboardMapSection> {
  LatLng? _currentLocation;
  final MapController _mapController = MapController();
  List<Marker> _hospitalMarkers = [];
  bool _isLoading = true;
  String _selectedFilter = 'Hospital'; // Default filter

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _fetchNearbyHospitals() async {
    if (_currentLocation == null) return;
    final lat = _currentLocation!.latitude;
    final lon = _currentLocation!.longitude;

    String queryElements = '';
    if (_selectedFilter == 'Hospital') {
      queryElements += 'node["amenity"="hospital"](around:5000,$lat,$lon);\n';
    } else if (_selectedFilter == 'Clinic') {
      queryElements += 'node["amenity"="clinic"](around:5000,$lat,$lon);\n';
    } else if (_selectedFilter == 'Medicine') {
      queryElements += 'node["amenity"="pharmacy"](around:5000,$lat,$lon);\n';
    }

    final query = '''
      [out:json];
      (
        $queryElements
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

          if (elementLat != null && elementLon != null) {
            final name = tags['name'] ?? 'Unknown Facility';
            final phone = tags['phone'] ?? tags['contact:phone'] ?? 'Not available';
            final address = tags['addr:full'] ?? tags['addr:street'] ?? 'Address not available';
            final emergency = tags['emergency'] ?? 'Not specified';
            final openingHours = tags['opening_hours'] ?? 'Not specified';

            markers.add(
              Marker(
                width: 40,
                height: 40,
                point: LatLng(elementLat, elementLon),
                child: GestureDetector(
                  onTap: () {
                    _showDetailsBottomSheet(
                      context,
                      name: name,
                      phone: phone,
                      address: address,
                      emergency: emergency,
                      openingHours: openingHours,
                    );
                  },
                  child: Icon(
                    _selectedFilter == 'Hospital' ? Icons.local_hospital : 
                    (_selectedFilter == 'Clinic' ? Icons.medical_services : Icons.medication),
                    color: Colors.red,
                    size: 30,
                  ),
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
      debugPrint('Failed to fetch hospitals');
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    void setFallbackLocation() {
      if (!mounted) return;
      setState(() {
        _currentLocation = const LatLng(23.8103, 90.4125);
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nearby Healthcare',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NearbyHospitalsScreen(initialFilter: _selectedFilter)),
                  );
                },
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF436B46),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF436B46)),
                items: ['Hospital', 'Clinic', 'Medicine'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(
                      children: [
                        Icon(
                          value == 'Hospital' ? Icons.local_hospital_rounded :
                          value == 'Clinic' ? Icons.medical_services_rounded :
                          Icons.medication_rounded,
                          color: const Color(0xFF436B46),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          value,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null && newValue != _selectedFilter) {
                    setState(() {
                      _selectedFilter = newValue;
                      _hospitalMarkers = [];
                    });
                    _fetchNearbyHospitals();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: _isLoading || _currentLocation == null
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF436B46)))
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentLocation!,
                        initialZoom: 14.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.sashthobondhu',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentLocation!,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
                            ),
                            ..._hospitalMarkers,
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
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
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow(Icons.location_on_outlined, 'Address', address),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.phone_outlined, 'Contact', phone),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.access_time_outlined, 'Opening Hours', openingHours),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.warning_amber_rounded, 'Emergency Services', emergency, isAlert: emergency == 'yes'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF436B46),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value, {bool isAlert = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isAlert ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF436B46).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isAlert ? Colors.red : const Color(0xFF436B46), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: isAlert ? Colors.red : Colors.black87,
                  fontWeight: isAlert ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
