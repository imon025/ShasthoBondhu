import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/skin_service.dart';
import '../services/history_service.dart';

import '../../../core/widgets/camera_capture_screen.dart';

class SkinDetectionScreen extends StatefulWidget {
  const SkinDetectionScreen({super.key});

  @override
  State<SkinDetectionScreen> createState() => _SkinDetectionScreenState();
}

class _SkinDetectionScreenState extends State<SkinDetectionScreen>
    with SingleTickerProviderStateMixin {
  final SkinService _skinService = createSkinService();
  final SkinHistoryService _historyService = SkinHistoryService();
  final ImagePicker _picker = ImagePicker();
  
  Uint8List? _imageBytes;
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _skinService.loadModel();
    
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final Uint8List? capturedImage = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (context) => const CameraCaptureScreen()),
      );

      if (capturedImage != null) {
        setState(() {
          _imageBytes = capturedImage;
          _result = null;
        });
      }
      return;
    }

    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _result = null;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;
    
    setState(() {
      _isLoading = true;
      _result = null;
    });

    _scanController.repeat(reverse: true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      
      final minDuration = Future.delayed(const Duration(seconds: 2));
      final prediction = _skinService.predict(_imageBytes!);
      
      final results = await Future.wait([minDuration, prediction]);
      final result = results[1] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
          _scanController.stop();
        });

        // Save to History
        if (result['error'] == null) {
          await _historyService.saveResult(SkinHistoryItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: result['label'] ?? 'Unknown',
            confidence: result['confidence'] ?? 0.0,
            dateTime: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _scanController.stop();
          _result = {'error': 'Analysis failed: $e'};
        });
      }
    }
  }

  void _showHistory() async {
    final history = await _historyService.getHistory();
    if (!mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Scan History', style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87
                )),
                TextButton(
                  onPressed: () {
                    _historyService.clearHistory();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (history.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40), 
                  child: Text('No local history yet', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey))
                )
              ),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: history.map((item) => ListTile(
                  leading: const Icon(
                    Icons.face_retouching_natural,
                    color: Colors.orangeAccent,
                  ),
                  title: Text(item.label, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(
                    '${(item.confidence * 100).toStringAsFixed(1)}% Confidence • ${item.dateTime.toString().split(' ')[0]}',
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _showSaveDialog() async {
    final theme = Theme.of(context);
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save to Clinical Record'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Patient Name', 
                hintText: 'Enter name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Age', 
                hintText: 'Enter age',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || ageController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                 return;
              }
              
              final age = int.tryParse(ageController.text);
              if (age == null) return;

              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                debugPrint('Attempting to save to Supabase...');
                if (_result == null) throw Exception('No analysis result found to save');
                
                await _historyService.saveToCloud(
                  patientName: nameController.text.trim(),
                  patientAge: age,
                  label: _result!['label'] ?? 'Unknown',
                  confidence: _result!['confidence'] ?? 0.0,
                );
                
                debugPrint('Supabase save successful!');
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully saved to profile!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                debugPrint('Supabase save error: $e');
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Save Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Skin Disease Detection', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 2,
        foregroundColor: Theme.of(context).colorScheme.primary,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        actions: [
          IconButton(
            onPressed: _showHistory,
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.face_retouching_natural, color: Colors.white, size: 40),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Skin Analysis',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Powered by Transfer Learning (MobileNetV2)',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Image Selection
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(23),
                    child: _imageBytes == null
                        ? const Center(child: Text('Tap to upload Skin Image', style: TextStyle(color: Colors.grey)))
                        : Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _imageBytes == null ? null : () {
                          setState(() {
                            _imageBytes = null;
                            _result = null;
                          });
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                          foregroundColor: isDark ? Colors.white70 : Colors.black54,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Select Source'),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt, color: Colors.orange),
                                    title: const Text('Camera'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickImage(ImageSource.camera);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library, color: Colors.orange),
                                    title: const Text('Gallery'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickImage(ImageSource.gallery);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Upload'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Detection Button
                ElevatedButton(
                  onPressed: (_imageBytes == null || _isLoading) ? null : _analyzeImage,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('START CLINICAL DETECTION', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),

                // Result Section
                AnimatedSize(
                  duration: const Duration(milliseconds: 500),
                  child: _result == null
                      ? const SizedBox.shrink()
                      : Column(
                          children: [
                            const SizedBox(height: 40),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                children: [
                                  if (_result!['error'] != null)
                                    Text(
                                      _result!['error'],
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                                      textAlign: TextAlign.center,
                                    )
                                  else ...[
                                    Text(
                                      'Analysis Result: ${_result!["label"]?.toString().replaceAll('_', ' ')}',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.orange),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_result!['confidence'] != null)
                                      Text(
                                        'Confidence: ${(_result!['confidence'] * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          color: isDark ? Colors.orange.withValues(alpha: 0.9) : Colors.orange
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Seek Medical Attention if necessary',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_result!['error'] == null)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _showSaveDialog,
                                  icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
                                  label: const Text('SAVE TO CLINICAL HISTORY'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.9),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 24),
                    Text('AI DERMATOLOGICAL ANALYSIS...', style: TextStyle(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
