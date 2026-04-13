import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

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

      if (mounted) {
        setState(() {
          _profileData = data ?? {};
          // Ensure contact_number exists conceptually
          _profileData!['contact_number'] = _profileData!['contact_number'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Profile error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load profile')));
      }
    }
  }

  Future<void> _updateField(String fieldKeys, String title, String currentValue, {TextInputType inputType = TextInputType.text}) async {
    final controller = TextEditingController(text: currentValue);
    
    final result = await showDialog<String>(
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

    if (result != null && result.trim() != currentValue) {
      // Validate age
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
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
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
        : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Avatar & Upload Placeholder
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: isDark ? const Color(0xFF2C2C54) : const Color(0xFF75E6DA),
                      child: Icon(Icons.person, size: 50, color: isDark ? Colors.white : theme.primaryColor),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Upload Photo coming soon!')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: theme.primaryColor, shape: BoxShape.circle),
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
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildProfileField(Icons.person_outline, 'Name', _profileData?['full_name'] ?? 'Not set', 'full_name'),
                      const Divider(),
                      _buildProfileField(Icons.email_outlined, 'Email', _profileData?['email'] ?? 'Not set', 'email', inputType: TextInputType.emailAddress, editable: false), // Usually emails aren't editable via simple row unless you verify
                      const Divider(),
                      _buildProfileField(Icons.phone_outlined, 'Contact', _profileData?['contact_number'] ?? 'Not set', 'contact_number', inputType: TextInputType.phone),
                      const Divider(),
                      _buildProfileField(Icons.calendar_today_outlined, 'Age', _profileData?['age']?.toString() ?? 'Not set', 'age', inputType: TextInputType.number),
                      const Divider(),
                      _buildProfileField(Icons.wc_outlined, 'Gender', _profileData?['gender'] ?? 'Not set', 'gender'),
                      const Divider(),
                      _buildProfileField(Icons.medical_services_outlined, 'Ailments', _profileData?['ailments'] ?? 'Not set', 'ailments'),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Change Password'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'User History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : theme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: isDark ? Colors.white : theme.primaryColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: isDark ? Colors.white : theme.primaryColor,
                      tabs: const [
                        Tab(text: 'Health History'),
                        Tab(text: 'Detect History'),
                      ],
                    ),
                    SizedBox(
                      height: 200,
                      child: TabBarView(
                        children: [
                          // Health History Mock
                          ListView.builder(
                            itemCount: 3,
                            itemBuilder: (context, index) => ListTile(
                              leading: const Icon(Icons.favorite, color: Colors.redAccent),
                              title: Text('Health Record #${index + 1}', style: theme.textTheme.bodyLarge),
                              subtitle: Text('12 Oct 2026', style: theme.textTheme.bodyMedium),
                            ),
                          ),
                          // Detect History Mock
                          ListView.builder(
                            itemCount: 2,
                            itemBuilder: (context, index) => ListTile(
                              leading: Icon(Icons.search, color: theme.primaryColor),
                              title: Text('Pneumonia Scan #${index + 1}', style: theme.textTheme.bodyLarge),
                              subtitle: Text('Negative - 05 Oct 2026', style: theme.textTheme.bodyMedium),
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

  Widget _buildProfileField(IconData icon, String label, String value, String dbKey, {TextInputType inputType = TextInputType.text, bool editable = true}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: isDark ? const Color(0xFF4DD0E1) : const Color(0xFF033A6B)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
          ),
          if (editable)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
              onPressed: () => _updateField(dbKey, label, value == 'Not set' ? '' : value, inputType: inputType),
            ),
        ],
      ),
    );
  }
}
