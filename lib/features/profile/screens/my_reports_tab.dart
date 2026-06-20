import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportItem {
  final String id;
  final String title;
  final String imageUrl;
  final DateTime date;

  ReportItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.date,
  });

  factory ReportItem.fromJson(Map<String, dynamic> json) => ReportItem(
        id: json['id'].toString(),
        title: json['title'],
        imageUrl: json['image_url'],
        date: DateTime.parse(json['created_at']),
      );
}

class MyReportsTab extends StatefulWidget {
  const MyReportsTab({super.key});

  @override
  State<MyReportsTab> createState() => _MyReportsTabState();
}

class _MyReportsTabState extends State<MyReportsTab> {
  List<ReportItem> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('user_reports')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _reports = (response as List).map((e) => ReportItem.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading reports: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadReport() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to upload reports')),
      );
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    // Ask for title
    String? title = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Report Title'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'e.g. Blood Test Result'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (title == null || title.trim().isEmpty) title = 'Untitled Report';

    setState(() => _isLoading = true);

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      
      // Upload to Supabase Storage
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await Supabase.instance.client.storage
            .from('reports')
            .uploadBinary(fileName, bytes);
      } else {
        await Supabase.instance.client.storage
            .from('reports')
            .upload(fileName, File(image.path));
      }

      // Get Public URL
      final imageUrl = Supabase.instance.client.storage
          .from('reports')
          .getPublicUrl(fileName);

      // Insert into database
      await Supabase.instance.client.from('user_reports').insert({
        'user_id': user.id,
        'title': title,
        'image_url': imageUrl,
      });

      // Reload reports
      await _loadReports();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report saved successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error uploading report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save report: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReport(ReportItem report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // Delete from storage
        final fileName = report.imageUrl.split('/').last;
        await Supabase.instance.client.storage.from('reports').remove([fileName]);

        // Delete from database
        await Supabase.instance.client.from('user_reports').delete().eq('id', report.id);

        setState(() {
          _reports.remove(report);
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report deleted')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting report: $e');
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete report: $e')),
          );
        }
      }
    }
  }

  Widget _buildImage(ReportItem report, {double? width, double? height, BoxFit? fit}) {
    return Image.network(
      report.imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.broken_image, size: width ?? 60),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: width ?? 60,
          height: height ?? 60,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  void _viewFullImage(ReportItem report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(report.title),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: _buildImage(report),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _uploadReport,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload New Report'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(),
        Expanded(
          child: _reports.isEmpty && !_isLoading
              ? const Center(
                  child: Text(
                    'No reports uploaded yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(8),
                        leading: GestureDetector(
                          onTap: () => _viewFullImage(report),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImage(report, width: 60, height: 60, fit: BoxFit.cover),
                          ),
                        ),
                        title: Text(report.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${report.date.day}/${report.date.month}/${report.date.year}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteReport(report),
                        ),
                        onTap: () => _viewFullImage(report),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
