import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Current Password'),
                obscureText: true,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Implement password change logic here
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password logic goes here')),
                );
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF033A6B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar & Upload Placeholder
            Center(
              child: Stack(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFF75E6DA),
                    child: Icon(Icons.person, size: 50, color: Color(0xFF033A6B)),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () {
                        // Implement image picker here
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Upload Photo coming soon!')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            color: Color(0xFF033A6B), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // User Details UI
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProfileField(Icons.person_outline, 'Name', 'Mr Farazi'),
                    const Divider(),
                    _buildProfileField(Icons.email_outlined, 'Email', 'user@example.com'),
                    const Divider(),
                    _buildProfileField(Icons.phone_outlined, 'Phone', '+880 1234 567890'),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Change Password'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF033A6B),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _showChangePasswordDialog,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // History Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'User History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF033A6B),
                ),
              ),
            ),
            const SizedBox(height: 10),

            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Color(0xFF033A6B),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Color(0xFF033A6B),
                    tabs: [
                      Tab(text: 'Health History'),
                      Tab(text: 'Detect History'),
                    ],
                  ),
                  SizedBox(
                    height: 200, // Fixed height for simple list or Expanded in a specific view
                    child: TabBarView(
                      children: [
                        // Health History Mock
                        ListView.builder(
                          itemCount: 3,
                          itemBuilder: (context, index) => ListTile(
                            leading: const Icon(Icons.favorite, color: Colors.redAccent),
                            title: Text('Health Record #${index + 1}'),
                            subtitle: const Text('12 Oct 2026'),
                          ),
                        ),
                        // Detect History Mock
                        ListView.builder(
                          itemCount: 2,
                          itemBuilder: (context, index) => ListTile(
                            leading: const Icon(Icons.search, color: Color(0xFF033A6B)),
                            title: Text('Pneumonia Scan #${index + 1}'),
                            subtitle: const Text('Negative - 05 Oct 2026'),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4DD0E1)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Edit $label coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }
}
