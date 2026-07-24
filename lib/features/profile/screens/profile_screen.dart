import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../pneumonia/services/history_service.dart';
import 'my_reports_tab.dart';
import 'personal_report_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  int _detectCount = 0;
  int _reportsCount = 0;
  int _healthCount = 3; // still mocked for now
  int _daysActive = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      setState(() => _isLoading = true);
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // Fetch stats
      final detectRes = await Supabase.instance.client
          .from('detection_history')
          .select('id')
          .eq('user_id', user.id);
      
      final reportsRes = await Supabase.instance.client
          .from('user_reports')
          .select('id')
          .eq('user_id', user.id);

      if (mounted) {
        setState(() {
          _profileData = data ?? {};
          _profileData!['contact_number'] = _profileData!['contact_number'] ?? '';
          
          _detectCount = (detectRes as List?)?.length ?? 0;
          _reportsCount = (reportsRes as List?)?.length ?? 0;
          
          if (_profileData!['created_at'] != null) {
             final createdAt = DateTime.parse(_profileData!['created_at']);
             _daysActive = DateTime.now().difference(createdAt).inDays;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Profile error occurred');
      if (mounted) {
        setState(() => _isLoading = false);
        // Silently fail or show minimal snackbar
      }
    }
  }

  Future<void> _uploadProfilePicture() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(fileName, bytes);
      } else {
        await Supabase.instance.client.storage
            .from('avatars')
            .upload(fileName, File(image.path));
      }

      final imageUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': imageUrl})
          .eq('id', user.id);

      await _fetchProfileData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
      }
    } catch (e) {
      String errMsg = 'Unknown error';
      try {
        if (e is StorageException) {
          errMsg = e.message;
        } else {
          errMsg = e.toString();
        }
      } catch(_) {}
      
      debugPrint('Avatar upload error: $errMsg');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $errMsg')));
      }
      setState(() => _isLoading = false);
    }
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileSettingsScreen(initialData: _profileData)),
    );
    // Refresh data when returning from settings
    _fetchProfileData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

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
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _isLoading 
                    ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TOP GRADIENT CARD
              Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFB0C6D9), Color(0xFF3B434C)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _openSettings,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _uploadProfilePicture,
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 40,
                                      backgroundColor: const Color(0xFF80E0B4),
                                      backgroundImage: _profileData?['avatar_url'] != null ? NetworkImage(_profileData!['avatar_url']) : null,
                                      child: _profileData?['avatar_url'] == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: const Icon(Icons.edit, size: 12, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _profileData?['full_name'] ?? 'Not set',
                                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _profileData?['email'] ?? 'Not set',
                                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildTopStatIcon(Icons.calendar_month, Colors.blue, '$_daysActive'),
                              _buildTopStatIcon(Icons.local_fire_department, Colors.redAccent, '$_detectCount'),
                              _buildTopStatIcon(Icons.bolt, Colors.orangeAccent, '$_reportsCount'),
                              _buildTopStatIcon(Icons.access_time_filled, Colors.green, '$_healthCount'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // PERSONAL REPORT & INFO BUTTON
              Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE600), // Full yellow box
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalReportScreen()));
                    },
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.table_chart_rounded, color: Colors.black87),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Personal Report & Info',
                              style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chevron_right, color: Colors.black87, size: 20),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // USER HISTORY GRID
              _buildSectionHeader('User History', textColor),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: [
                  _buildHistoryCard('Health', 'History', cardColor, textColor, subTextColor, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthHistoryScreen()));
                  }),
                  _buildHistoryCard('Detect', 'History', cardColor, textColor, subTextColor, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DetectHistoryScreen()));
                  }),
                  _buildHistoryCard('My Reports', 'Uploaded files', cardColor, textColor, subTextColor, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('My Reports')),
                      body: const MyReportsTab()
                    )));
                  }),
                ],
              ),
              const SizedBox(height: 100), // Padding for bottom nav
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
                  fontWeight: FontWeight.bold,
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
                    child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
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
              InkWell(
                onTap: _openSettings,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings_rounded, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatIcon(IconData icon, Color iconColor, String value) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.greenAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.5),
                blurRadius: 6,
                spreadRadius: 2,
              )
            ]
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(String title, String subtitle, Color bgColor, Color textColor, Color subTextColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: subTextColor, size: 20),
          ],
        ),
      ),
    );
  }
}

// --- PROFILE SETTINGS SCREEN ---

class ProfileSettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const ProfileSettingsScreen({super.key, this.initialData});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _isLoading = false;
  late Map<String, dynamic> _profileData;

  @override
  void initState() {
    super.initState();
    _profileData = widget.initialData != null ? Map.from(widget.initialData!) : {};
    if (_profileData.isEmpty) {
      _fetchProfileData();
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      setState(() => _isLoading = true);
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _profileData = data ?? {};
          _profileData['contact_number'] = _profileData['contact_number'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load profile')));
      }
    }
  }

  Future<void> _updateField(String fieldKeys, String title, String currentValue, {TextInputType inputType = TextInputType.text}) async {
    String? result;
    
    if (inputType == TextInputType.datetime) {
      final initialDate = DateTime.tryParse(currentValue) ?? DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        result = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      }
    } else {
      final controller = TextEditingController(text: currentValue);
      result = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Edit $title'),
            content: TextField(
              controller: controller,
              keyboardType: inputType,
              decoration: InputDecoration(hintText: 'Enter your $title'),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text), 
                child: const Text('Save')
              ),
            ],
          );
        }
      );
    }

    if (result != null && result.trim() != currentValue) {
      dynamic parseResult = result.trim();
      if (fieldKeys == 'age') {
        parseResult = int.tryParse(result.trim());
        if (parseResult == null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Age must be a number')));
          return;
        }
      }

      setState(() => _isLoading = true);
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await Supabase.instance.client
              .from('profiles')
              .update({fieldKeys: parseResult})
              .eq('id', userId);
              
          await _fetchProfileData();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title updated!')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _showChangePasswordDialog() {
    final newController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: newController, decoration: const InputDecoration(labelText: 'New Password'), obscureText: true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pwd = newController.text.trim();
                Navigator.pop(dialogContext);
                if (pwd.length < 6) {
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password too short. Minimum 6 characters.')));
                   return;
                }
                setState(() => _isLoading = true);
                try {
                  await Supabase.instance.client.auth.updateUser(UserAttributes(password: pwd));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully!')));
                } catch(e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update password')));
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingTile(String title, String? value, String dbKey, {TextInputType inputType = TextInputType.text}) {
    final displayValue = (value == null || value.isEmpty || value == 'Not set') ? 'N/A' : value;
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(displayValue),
      trailing: const Icon(Icons.edit, size: 20),
      onTap: () => _updateField(dbKey, title, displayValue == 'N/A' ? '' : displayValue, inputType: inputType),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSettingTile('Name', _profileData['full_name'], 'full_name'),
              const Divider(),
              ListTile(
                title: const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_profileData['email'] ?? 'N/A'),
                trailing: const Icon(Icons.lock, size: 16, color: Colors.grey),
              ),
              const Divider(),
              _buildSettingTile('Contact', _profileData['contact_number'], 'contact_number', inputType: TextInputType.phone),
              const Divider(),
              _buildSettingTile('Age', _profileData['age']?.toString(), 'age', inputType: TextInputType.number),
              const Divider(),
              const Divider(),
              _buildSettingTile('Gender', _profileData['gender'], 'gender'),
              const Divider(),
              _buildSettingTile('Date of Birth', _profileData['date_of_birth'], 'date_of_birth', inputType: TextInputType.datetime),
              const Divider(),
              _buildSettingTile('Blood Group', _profileData['blood_group'], 'blood_group'),
              const Divider(),
              _buildSettingTile('Address', _profileData['address'], 'address', inputType: TextInputType.streetAddress),
              const Divider(),
              _buildSettingTile('Ailments', _profileData['ailments'], 'ailments'),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _showChangePasswordDialog,
                icon: const Icon(Icons.lock_reset),
                label: const Text('Change Password'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
    );
  }
}

// --- HISTORY SCREENS ---

class HealthHistoryScreen extends StatelessWidget {
  const HealthHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health History')),
      body: ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) => ListTile(
          leading: const Icon(Icons.favorite, color: Colors.redAccent),
          title: Text('Health Record #${index + 1}'),
          subtitle: const Text('12 Oct 2026'),
        ),
      ),
    );
  }
}

class DetectHistoryScreen extends StatelessWidget {
  const DetectHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detect History')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: HistoryService().fetchCloudHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('No history found'));
          }
          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              final label = item['label'] ?? 'Unknown';
              final confidence = (item['confidence'] ?? 0.0) * 100;
              final date = DateTime.parse(item['created_at']).toString().split(' ')[0];
              final patient = item['patient_name'] ?? 'Self';
              return ListTile(
                leading: Icon(
                  label == 'PNEUMONIA' ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: label == 'PNEUMONIA' ? Colors.red : Colors.green,
                ),
                title: Text('$label ($patient)'),
                subtitle: Text('${confidence.toStringAsFixed(1)}% Confidence • $date'),
              );
            },
          );
        },
      ),
    );
  }
}
