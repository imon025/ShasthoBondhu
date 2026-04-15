import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/pneumonia_service.dart';
import '../../../core/theme/app_colors.dart';

class PneumoniaDetectionScreen extends StatefulWidget {
  const PneumoniaDetectionScreen({super.key});

  @override
  State<PneumoniaDetectionScreen> createState() => _PneumoniaDetectionScreenState();
}

class _PneumoniaDetectionScreenState extends State<PneumoniaDetectionScreen>
    with SingleTickerProviderStateMixin {
  final PneumoniaService _pneumoniaService = createPneumoniaService();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _pneumoniaService.loadModel();
    
    // Animation setup for scanning and pulse effects
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

    // Start scanning/pulse animation immediately
    _scanController.repeat(reverse: true);

    try {
      // 1. BREATHING GAP: Allow the UI to transition smoothly before heavy work starts
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Minimum duration for the "cool" animation feel
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

  @override
  Widget build(BuildContext context) {
    final bool isPneumonia = _result?['label'] == 'PNEUMONIA';
    final bool isNotXray = _result?['label'] == 'NOT AN X-RAY';
    final Color resultColor = isNotXray ? Colors.orange : (isPneumonia ? Colors.red : Colors.green);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pneumonia Detection', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
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
                              'AI X-Ray Analysis',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Upload an X-ray report for instant detection.',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Image Selection
                GestureDetector(
                  onTap: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _imageBytes == null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primaryBlue),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Tap to upload Chest X-ray',
                                style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Supports JPG, PNG',
                                style: TextStyle(color: Colors.black26, fontSize: 12),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(23),
                            child: Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryBlue,
                          elevation: 0,
                          side: const BorderSide(color: AppColors.primaryBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryBlue,
                          elevation: 0,
                          side: const BorderSide(color: AppColors.primaryBlue),
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
                  child: const Text(
                    'START DETECTION',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),

                // Result Section
                AnimatedSize(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.fastOutSlowIn,
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
                                border: Border.all(
                                  color: resultColor.withValues(alpha: 0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: resultColor.withValues(alpha: 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  if (isNotXray) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            'INVALID INPUT',
                                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ] else ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'AI VERIFIED',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Text(
                                    'Analysis Result',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: resultColor.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _result!['label'] ?? 'Unknown',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isNotXray ? 24 : 40,
                                      fontWeight: FontWeight.w900,
                                      color: resultColor,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const Text(
                                    '(Real-time AI Clinical Analysis)',
                                    style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
                                  ),
                                  if (!isNotXray && _result!['confidence'] != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: resultColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Text(
                                        'Confidence: ${(_result!['confidence'] * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: resultColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  const Divider(),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, color: resultColor, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          isNotXray
                                              ? (_result!['warning'] ?? 'Please upload a valid grayscale X-ray for analysis.')
                                              : (_result!['label'] == 'PNEUMONIA'
                                                  ? 'Recommendations: Please consult a doctor immediately and stay hydrated.'
                                                  : 'Recommendations: Your lungs appear clear. Maintain healthy habits!'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textPrimary.withValues(alpha: 0.8),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
          
          // IMMERSIVE ANALYSIS INTERPAGE (Lab Mode)
          if (_isLoading)
            RepaintBoundary(
              child: FadeTransition(
                opacity: _scanController, // Subtle shimmer effect using existing controller
                child: Container(
                  color: Colors.black.withValues(alpha: 0.95),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: Tween(begin: 1.0, end: 1.2).animate(_scanController),
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primaryBlue, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.4),
                                  blurRadius: 40,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 80),
                          ),
                        ),
                        const SizedBox(height: 60),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(seconds: 3),
                          builder: (context, value, _) {
                            return Column(
                              children: [
                                Text(
                                  'AI CLINICAL SCANNER',
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 8,
                                    fontSize: 12,
                                    shadows: [Shadow(color: AppColors.primaryBlue, blurRadius: 10 * value)],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: 200,
                                  child: LinearProgressIndicator(
                                    value: value,
                                    backgroundColor: Colors.white12,
                                    color: AppColors.primaryBlue,
                                    minHeight: 2,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Decrypting pulmonary structures...',
                          style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
