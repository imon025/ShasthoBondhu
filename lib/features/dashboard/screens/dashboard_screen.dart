import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Section (Deep Blue)
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF033A6B), // Deep blue from image 2
                borderRadius: BorderRadius.only(
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
                          const Icon(Icons.menu, color: Colors.white, size: 32),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: const [
                                  Text(
                                    'John Doe',
                                    style: TextStyle(
                                      color: Color(0xFF4DD0E1), // Teal
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Edit profile',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              const CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                // Use a placeholder icon for now
                                child: Icon(Icons.person, color: Color(0xFF033A6B), size: 30),
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
                          _buildCategoryIcon(Icons.air, 'Lungs'),
                          _buildCategoryIcon(Icons.pregnant_woman, 'Gynecology'),
                          _buildCategoryIcon(Icons.coronavirus_outlined, 'Dentistry'), // Using placeholder icons
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const TextField(
                          decoration: InputDecoration(
                            hintText: 'Search here',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            suffixIcon: Icon(Icons.search, color: Color(0xFF033A6B), size: 28),
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
                  const Center(
                    child: Text(
                      'Available Doctors',
                      style: TextStyle(
                        color: Color(0xFF033A6B), // Deep Blue
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Doctor Cards
                  _buildDoctorCard(
                    name: 'Dr. Mira',
                    specialty: 'Specialist',
                    icon: Icons.person_3,
                  ),
                  const SizedBox(height: 16),
                  _buildDoctorCard(
                    name: 'Dr. Sam',
                    specialty: 'Specialist',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),

                  // Show All Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Show All >',
                      style: TextStyle(
                        color: const Color(0xFF4DD0E1), // Teal
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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

  Widget _buildCategoryIcon(IconData icon, String label) {
    return Column(
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
    );
  }

  Widget _buildDoctorCard({required String name, required String specialty, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF75E6DA), // Light teal background
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 50, color: const Color(0xFF033A6B)),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF033A6B),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  specialty,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Next Button
          const Align(
            alignment: Alignment.bottomRight,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.white,
              child: Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF75E6DA)),
            ),
          ),
        ],
      ),
    );
  }
}
