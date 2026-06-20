import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/pneumonia_service.dart';
import '../services/history_service.dart';
import '../../../core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import '../../profile/utils/download_helper.dart';

import '../../../core/widgets/camera_capture_screen.dart';

class PneumoniaDetectionScreen extends StatefulWidget {
  const PneumoniaDetectionScreen({super.key});

  @override
  State<PneumoniaDetectionScreen> createState() => _PneumoniaDetectionScreenState();
}

class _PneumoniaDetectionScreenState extends State<PneumoniaDetectionScreen>
    with SingleTickerProviderStateMixin {
  final PneumoniaService _pneumoniaService = createPneumoniaService();
  final HistoryService _historyService = HistoryService();
  final ImagePicker _picker = ImagePicker();
  
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _showHeatmap = false;
  Map<String, dynamic>? _result;
  
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _pneumoniaService.loadModel();
    
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
          _showHeatmap = false;
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
        _showHeatmap = false;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;
    
    setState(() {
      _isLoading = true;
      _result = null;
      _showHeatmap = false;
    });

    _scanController.repeat(reverse: true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      
      final minDuration = Future.delayed(const Duration(seconds: 3));
      final prediction = _pneumoniaService.predict(_imageBytes!);
      
      final results = await Future.wait([minDuration, prediction]);
      final result = results[1] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
          _scanController.stop();
        });

        // Save to History
        if (result['label'] != 'NOT AN X-RAY' && result['error'] == null) {
          await _historyService.saveResult(PneumoniaHistoryItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: result['label'],
            confidence: result['confidence'],
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
                  leading: Icon(
                    item.label == 'PNEUMONIA' ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    color: item.label == 'PNEUMONIA' ? Colors.red : Colors.green,
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

    // Try to auto-fill from profile (REMOVED per user request)
    // We start with blank fields for clinical accuracy
    
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
                  label: _result!['label'],
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

  Future<void> _downloadReport() async {
    if (_imageBytes == null || _result == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No result to download')));
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...')));
    }

    // Fetch user profile data
    Map<String, dynamic>? profile;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name, age, contact_number, avatar_url, gender, date_of_birth, blood_group, address')
            .eq('id', user.id)
            .maybeSingle();
      } catch (e) {
        debugPrint('Failed to load profile for pdf: $e');
      }
    }

    final String name = profile?['full_name'] ?? 'Unknown User';
    final String age = profile?['age']?.toString() ?? 'N/A';
    final String contact = profile?['contact_number'] ?? 'N/A';
    final String gender = profile?['gender'] ?? 'N/A';
    final String dob = profile?['date_of_birth'] ?? 'N/A';
    final String bloodGroup = profile?['blood_group'] ?? 'N/A';
    final String address = profile?['address'] ?? 'N/A';
    final String reportDate = "${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}";
    final String avatarUrl = profile?['avatar_url'] ?? '';

    pw.MemoryImage? profileImage;
    if (avatarUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(avatarUrl));
        if (response.statusCode == 200) {
          profileImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('Failed to load avatar image: $e');
      }
    }

    final pdf = pw.Document();
    final scanImage = pw.MemoryImage(_imageBytes!);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          pw.Widget buildInfoRow(String title, String value) {
            return pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 75,
                  child: pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Text(': ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Expanded(
                  child: pw.Text(value, style: pw.TextStyle(fontSize: 10)),
                ),
              ]
            );
          }

          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2),
            ),
            padding: const pw.EdgeInsets.all(24),
            child: pw.Stack(
              children: [
                pw.Center(
                  child: pw.Transform.rotate(
                    angle: -0.5,
                    child: pw.Text(
                      'ShasthoBondhu',
                      softWrap: false,
                      style: pw.TextStyle(
                        fontSize: 40,
                        color: PdfColor.fromHex('#E0E0E0'),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              children: [
                                pw.Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const pw.BoxDecoration(color: PdfColors.red, shape: pw.BoxShape.circle),
                                  child: pw.Center(child: pw.Text('+', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 16))),
                                ),
                                pw.SizedBox(width: 8),
                                pw.Text('MEDICAL RECORD', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                              ],
                            ),
                            pw.SizedBox(height: 16),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(12),
                              decoration: const pw.BoxDecoration(color: PdfColors.white),
                              width: 320,
                              height: 125,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                                children: [
                                  buildInfoRow('Name', name),
                                  buildInfoRow('Age', age),
                                  buildInfoRow('Gender', gender),
                                  buildInfoRow('Date of Birth', dob),
                                  buildInfoRow('Blood Group', bloodGroup),
                                  buildInfoRow('Contact', contact),
                                  buildInfoRow('Address', address),
                                  buildInfoRow('Report Date', reportDate),
                                ]
                              )
                            ),
                          ]
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 40),
                          child: pw.Container(
                            width: 125,
                            height: 125,
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              color: PdfColor.fromHex('#D7CCC8'),
                              image: profileImage != null 
                                 ? pw.DecorationImage(image: profileImage, fit: pw.BoxFit.cover)
                                 : null,
                            ),
                            child: profileImage == null ? pw.Center(
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                   pw.Container(width: 35, height: 35, decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.grey500)),
                                   pw.SizedBox(height: 4),
                                   pw.Container(width: 60, height: 30, decoration: const pw.BoxDecoration(color: PdfColors.grey500, borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(30)))),
                                ]
                              )
                            ) : null
                          )
                        )
                      ]
                    ),
                    pw.SizedBox(height: 32),
                    pw.Text('Pneumonia Detection Result', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 16),
                    pw.Center(
                      child: pw.Container(
                        height: 250,
                        child: pw.Image(scanImage, fit: pw.BoxFit.contain),
                      ),
                    ),
                    pw.SizedBox(height: 24),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Analysis: ${_result!["label"]}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          if (_result!['confidence'] != null)
                            pw.Text('Confidence: ${(_result!['confidence'] * 100).toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 14)),
                          pw.SizedBox(height: 8),
                          pw.Text('Note: This is an AI-generated analysis. Please consult a qualified medical professional for an accurate diagnosis.', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                        ]
                      )
                    ),
                    pw.Spacer(),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text('Generated by shasthobondhu (Farazi)', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                    )
                  ]
                )
              ]
            )
          );
        }
      )
    );

    try {
      final bytes = await pdf.save();
      await downloadBytes('pneumonia_report.pdf', bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloaded successfully! (Saved as PDF)')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPneumonia = _result?['label'] == 'PNEUMONIA';
    final bool isNormal = _result?['label'] == 'NORMAL';
    final bool isNotXray = _result?['label'] == 'NOT AN X-RAY';
    final Color resultColor = isNotXray 
        ? Colors.orange 
        : (isPneumonia ? Colors.red : (isNormal ? Colors.green : Colors.grey));
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pneumonia Detection', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    gradient: const LinearGradient(colors: AppColors.primaryGradient),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.health_and_safety, color: Colors.white, size: 40),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Premium AI X-Ray Analysis',
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

                // Image Selection & Heatmap Toggle
                Stack(
                  alignment: Alignment.topRight,
                  children: [
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
                            ? const Center(child: Text('Tap to upload Chest X-ray', style: TextStyle(color: Colors.grey)))
                            : Stack(
                                children: [
                                  Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                  if (_showHeatmap && _result?['heatmap'] != null)
                                    Image.memory(_result!['heatmap'], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                ],
                              ),
                      ),
                    ),
                    if (_result?['heatmap'] != null)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: FloatingActionButton.small(
                          onPressed: () => setState(() => _showHeatmap = !_showHeatmap),
                          backgroundColor: _showHeatmap ? Colors.red : Colors.white,
                          child: Icon(Icons.remove_red_eye, color: _showHeatmap ? Colors.white : Colors.red),
                        ),
                      ),
                  ],
                ),
                if (_result?['heatmap'] != null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Text('Toggle AI Heatmap to see regions of interest', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
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
                            _showHeatmap = false;
                          });
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white10 
                              : Colors.grey[200],
                          foregroundColor: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white70 
                              : Colors.black54,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15), 
                          ),
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
                                    leading: const Icon(Icons.camera_alt, color: AppColors.primaryBlue),
                                    title: const Text('Camera'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickImage(ImageSource.camera);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library, color: AppColors.primaryBlue),
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
                          backgroundColor: AppColors.primaryBlue,
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
                    backgroundColor: AppColors.primaryBlue,
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
                                color: resultColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: resultColor.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Analysis Result: ${_result!["label"]}',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: resultColor),
                                  ),
                                  if (!isNotXray && _result!['confidence'] != null)
                                    Text(
                                      'Confidence: ${(_result!['confidence'] * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        color: isDark ? resultColor.withValues(alpha: 0.9) : resultColor
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  Text(
                                    isNotXray 
                                        ? (_result!['warning'] ?? 'Invalid Image') 
                                        : (isPneumonia 
                                            ? 'Seek Medical Attention' 
                                            : (_result!['label'] == 'NORMAL' ? 'Healthy Lungs Detected' : 'Unknown Result')),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _showSaveDialog,
                                    icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 20),
                                    label: const Text('SAVE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _downloadReport,
                                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                                    label: const Text('DOWNLOAD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    ),
                                  ),
                                ),
                              ],
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primaryBlue),
                    const SizedBox(height: 24),
                    const Text('AI PULMONARY ANALYSIS...', style: TextStyle(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
