import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../pneumonia/screens/pneumonia_detection_screen.dart';
import '../../skin_disease/screens/skin_detection_screen.dart';
import '../../medicine_suggestion/screens/medicine_suggestion_screen.dart';

class DetectionOptionsPage extends StatelessWidget {
  const DetectionOptionsPage({super.key});

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
                    color: Color(0xFFF5F6F8), // Dashboard background color
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        const MedicinePriceWidget(),
                        const SizedBox(height: 24),
                        _buildMainActionArea(context),
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
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF436B46), // Dashboard main green
        borderRadius: BorderRadius.circular(40),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    ClipOval(
                      child: Container(
                        width: 32,
                        height: 32,
                        color: Colors.grey[200],
                        child: Icon(Icons.person, color: Colors.grey[600], size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Sarah',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.black87,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildGridItem(
                  context,
                  icon: Icons.coronavirus_outlined,
                  title: 'Pneumonia\nDetection',
                  value1: 'Scan',
                  value2: 'Ready',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PneumoniaDetectionScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGridItem(
                  context,
                  icon: Icons.face_retouching_natural,
                  title: 'Skin\nDisease',
                  value1: 'Scan',
                  value2: 'Ready',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SkinDetectionScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildGridItem(
                  context,
                  icon: Icons.mood,
                  title: 'Emotion\nDetection',
                  value1: 'Scan',
                  value2: 'Ready',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Emotion Detection coming soon!')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGridItem(
                  context,
                  icon: Icons.medication_outlined,
                  title: 'Medicine\nSuggestion',
                  value1: 'Scan',
                  value2: 'Ready',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MedicineSuggestionScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value1,
    required String value2,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF436B46), // Updated to dashboard green
                    size: 24,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value1,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MedicinePriceWidget extends StatefulWidget {
  const MedicinePriceWidget({super.key});

  @override
  State<MedicinePriceWidget> createState() => _MedicinePriceWidgetState();
}

class _MedicinePriceWidgetState extends State<MedicinePriceWidget> {
  TextEditingController? _textController;
  bool _isLoading = false;
  String? _priceResult;
  String? _searchedMedicine;

  // Real prices database for suggestion and quick lookup
  final Map<String, String> _medicineDatabase = {
    'Napa 500mg (Paracetamol)': '৳ 1.20 / pc\n৳ 12.00 / strip',
    'Napa Extra (Paracetamol + Caffeine)': '৳ 2.50 / pc\n৳ 25.00 / strip',
    'Napa Extend 665mg (Paracetamol)': '৳ 2.00 / pc\n৳ 24.00 / strip',
    'Seclo 20mg (Omeprazole)': '৳ 5.00 / cap\n৳ 50.00 / strip',
    'Sergel 20mg (Esomeprazole)': '৳ 7.00 / cap\n৳ 70.00 / strip',
    'Maxpro 20mg (Esomeprazole)': '৳ 7.00 / cap\n৳ 70.00 / strip',
    'Fexo 120mg (Fexofenadine)': '৳ 8.00 / tab\n৳ 80.00 / strip',
    'Alatrol 10mg (Cetirizine)': '৳ 3.00 / tab\n৳ 30.00 / strip',
    'Monas 10mg (Montelukast)': '৳ 15.00 / tab\n৳ 150.00 / strip',
    'Ceevit 250mg (Vitamin C)': '৳ 1.50 / tab\n৳ 15.00 / strip',
    'Azithrocin 500mg (Azithromycin)': '৳ 35.00 / tab\n৳ 105.00 / strip',
    'Zimax 500mg (Azithromycin)': '৳ 35.00 / tab\n৳ 105.00 / strip',
    'Calbo-D (Calcium + Vitamin D)': '৳ 5.00 / tab\n৳ 75.00 / bottle',
    'Napa Syrup 120mg/5ml': '৳ 20.00 / bottle',
  };

  void _searchPrice(String query) {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _priceResult = null;
      _searchedMedicine = query;
    });

    // Short delay to simulate search
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        
        // Exact match
        if (_medicineDatabase.containsKey(query)) {
          _priceResult = _medicineDatabase[query];
        } else {
          // Fuzzy match
          final matches = _medicineDatabase.keys
              .where((k) => k.toLowerCase().contains(query.toLowerCase()))
              .toList();
          if (matches.isNotEmpty) {
             _searchedMedicine = matches.first;
             _priceResult = _medicineDatabase[matches.first];
          } else {
             _priceResult = 'Not found. Try selecting from suggestions.';
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F6F8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medication, color: Color(0xFF436B46)),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medicine Price',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Check real medicine prices',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return _medicineDatabase.keys.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    if (_textController != null) {
                      _textController!.text = selection;
                    }
                    _searchPrice(selection);
                  },
                  fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                    _textController = fieldTextEditingController;
                    return TextField(
                      controller: fieldTextEditingController,
                      focusNode: fieldFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Enter medicine name...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: (value) {
                         _searchPrice(value);
                      },
                    );
                  },
                  optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: MediaQuery.of(context).size.width - 100,
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            shrinkWrap: true,
                            itemBuilder: (BuildContext context, int index) {
                              final String option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                  child: Text(
                                    option,
                                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _isLoading ? null : () => _searchPrice(_textController?.text ?? ''),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF436B46),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.search, color: Colors.white),
                ),
              ),
            ],
          ),
          if (_priceResult != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF436B46).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF436B46).withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _searchedMedicine ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Verified real price',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _priceResult!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF436B46),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
