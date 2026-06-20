import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import '../utils/download_helper.dart';

class PersonalReportScreen extends StatefulWidget {
  const PersonalReportScreen({super.key});

  @override
  State<PersonalReportScreen> createState() => _PersonalReportScreenState();
}

class _PersonalReportScreenState extends State<PersonalReportScreen> {
  List<List<String>> _tableData = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSaved = false;
  Timer? _saveTimer;
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  int _initialCols = 5;
  int _initialRows = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _initializeDefaultData() {
    _tableData = []; // Initially empty, showing the setup form
  }

  Future<void> _loadData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('personal_report_data')
            .eq('id', user.id)
            .maybeSingle();
            
        if (data != null && data['personal_report_data'] != null) {
          final dbData = data['personal_report_data'];
          final List<dynamic> decoded = (dbData is String) ? jsonDecode(dbData) : dbData;
          _tableData = decoded.map((row) => List<String>.from(row)).toList();
          if (_tableData.isEmpty) {
             _initializeDefaultData();
          }
          setState(() => _isLoading = false);
          return;
        }
      }
    } catch (e) {
      debugPrint('Supabase load error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('personal_excel_data');
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        _tableData = decoded.map((row) => List<String>.from(row)).toList();
        if (_tableData.isEmpty) {
          _initializeDefaultData();
        }
      } catch (e) {
        _initializeDefaultData();
      }
    } else {
      _initializeDefaultData();
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _debouncedSave() {
    setState(() {
       _isSaving = true;
       _isSaved = false;
    });
    if (_saveTimer?.isActive ?? false) _saveTimer!.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1000), () async {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(_tableData);
      await prefs.setString('personal_excel_data', jsonData);
      
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client.from('profiles').update({
            'personal_report_data': jsonData
          }).eq('id', user.id);
        }
      } catch (e) {
        debugPrint('Supabase save error: $e');
      }
      
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isSaved = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isSaved = false);
        });
      }
    });
  }

  void _addRow() {
    setState(() {
      _tableData.add(List.filled(_tableData[0].length, ''));
    });
    _debouncedSave();
  }

  void _addColumn() {
    setState(() {
      for (var row in _tableData) {
        row.add('');
      }
    });
    _debouncedSave();
  }

  void _deleteRow(int rowIndex) {
    setState(() {
      _tableData.removeAt(rowIndex);
    });
    _debouncedSave();
  }

  Future<void> _shareAllData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to share.')));
        return;
      }
      
      String content = "My Full Health Report:\n\n";
      for (int i = 1; i < _tableData.length; i++) {
        final row = _tableData[i];
        if (row.any((cell) => cell.trim().isNotEmpty)) {
           content += "Row $i:\n";
           for (int j = 0; j < row.length; j++) {
             if (row[j].isNotEmpty) {
               content += "  - ${_tableData[0][j]}: ${row[j]}\n";
             }
           }
           content += "\n";
        }
      }
      
      await Supabase.instance.client.from('community_feed').insert({
        'user_id': user.id,
        'content': content,
      });
      
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared entire report to feed!')));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share. Ensure community_feed table exists: $e')));
    }
  }

  Future<void> _pickDate(int rowIndex) async {
    final initialDate = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final dateStr = "${picked.day}-${months[picked.month - 1]}";
      
      bool isDuplicate = false;
      for (int i = 1; i < _tableData.length; i++) {
        if (i != rowIndex && _tableData[i][0] == dateStr) {
          isDuplicate = true;
          break;
        }
      }
      
      if (isDuplicate) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date already exists! Cannot reuse.')));
        return;
      }

      setState(() {
        _tableData[rowIndex][0] = dateStr;
      });
      _debouncedSave();
    }
  }

  void _updateCell(int rowIndex, int colIndex, String value) {
    _tableData[rowIndex][colIndex] = value;
    // We don't save immediately here to avoid character-by-character saving.
    // Saving is handled by the Focus widget's onFocusChange event.
  }

  Future<void> _downloadData() async {
    List<List<String>> filteredData = [_tableData[0]];
    for (int i = 1; i < _tableData.length; i++) {
      bool hasData = _tableData[i].any((cell) => cell.trim().isNotEmpty);
      if (hasData) {
        filteredData.add(_tableData[i]);
      }
    }

    if (filteredData.length == 1) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to download')));
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
                // Background Watermark
                pw.Center(
                  child: pw.Transform.rotate(
                    angle: -0.5,
                    child: pw.Text(
                      'ShasthoBondhu',
                      softWrap: false, // Ensure it never wraps
                      style: pw.TextStyle(
                        fontSize: 40,
                        color: PdfColor.fromHex('#E0E0E0'),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Foreground content
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header section
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Top Left
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
                            // Profile Info Block
                            pw.Container(
                              padding: const pw.EdgeInsets.all(12),
                              decoration: const pw.BoxDecoration(color: PdfColors.white),
                              width: 320,
                              height: 125, // Fixed height
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
                        // Top Right (Profile Icon Vector or Avatar)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 40), // Align with the details block below the title
                          child: pw.Container(
                            width: 125, // Same height as profile info block
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

                    // Table
                    pw.TableHelper.fromTextArray(
                      context: context,
                      data: filteredData,
                      border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      cellStyle: const pw.TextStyle(color: PdfColors.black, fontSize: 10),
                      cellAlignment: pw.Alignment.center,
                    ),

                    pw.Spacer(),

                    // Bottom right reference
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
      await downloadBytes('personal_report.pdf', bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloaded successfully! (Saved as PDF)')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download: $e')));
      }
    }
  }

  bool _isDeletionMode = false;
  final Set<int> _selectedRows = {};
  final Set<int> _selectedCols = {};

  void _deleteSelected() {
    if (_selectedRows.isEmpty && _selectedCols.isEmpty) {
      setState(() => _isDeletionMode = false);
      return;
    }

    setState(() {
      // Sort descending to avoid index shifting during removal
      final colsToDelete = _selectedCols.toList()..sort((a, b) => b.compareTo(a));
      final rowsToDelete = _selectedRows.toList()..sort((a, b) => b.compareTo(a));

      // Remove columns first
      for (int cIndex in colsToDelete) {
        for (var row in _tableData) {
          if (row.length > cIndex) {
            row.removeAt(cIndex);
          }
        }
      }

      // Remove rows
      for (int rIndex in rowsToDelete) {
        if (_tableData.length > rIndex) {
          _tableData.removeAt(rIndex);
        }
      }

      _selectedCols.clear();
      _selectedRows.clear();
      _isDeletionMode = false;
    });
    _debouncedSave();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  Widget _buildSetupForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.table_chart, size: 64, color: Color(0xFF436B46)),
              const SizedBox(height: 16),
              const Text('Create Your Table', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Set up your personal report tracker. You can always add more columns and rows later.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Number of Columns',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.view_column),
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => _initialCols = int.tryParse(val) ?? 5,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Number of Rows',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.table_rows),
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => _initialRows = int.tryParse(val) ?? 10,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF436B46)),
                  onPressed: () {
                    if (_initialCols < 1 || _initialRows < 1) return;
                    setState(() {
                      _tableData = [List.generate(_initialCols, (i) => i == 0 ? 'Date' : 'Column ${i+1}')];
                      for (int i = 0; i < _initialRows; i++) {
                        _tableData.add(List.filled(_initialCols, ''));
                      }
                    });
                    _debouncedSave();
                  },
                  child: const Text('Generate Table', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF436B46);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Text(
          _isDeletionMode ? 'Select to Delete' : 'Personal Report & Info', 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
        ),
        backgroundColor: _isDeletionMode ? Colors.redAccent : primaryColor,
        foregroundColor: Colors.white,
        actions: _isDeletionMode 
          ? [
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete Selected',
                onPressed: _deleteSelected,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: () {
                  setState(() {
                    _selectedCols.clear();
                    _selectedRows.clear();
                    _isDeletionMode = false;
                  });
                },
              )
            ]
          : _tableData.isEmpty ? [] : [
          // Auto Save Indicator
          if (_isSaving) 
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))))
          else if (_isSaved) 
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.cloud_done, color: Colors.white))
          else 
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.cloud_queue, color: Colors.white54)),
            
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download Report',
            onPressed: _downloadData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'share') _shareAllData();
              else if (value == 'add_col') _addColumn();
              else if (value == 'add_row') _addRow();
              else if (value == 'delete') setState(() => _isDeletionMode = true);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'add_col', child: Text('Add Column')),
              const PopupMenuItem<String>(value: 'add_row', child: Text('Add Row')),
              const PopupMenuItem<String>(value: 'delete', child: Text('Delete Row or Column')),
              const PopupMenuItem<String>(value: 'share', child: Text('Share All Data to Feed')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tableData.isEmpty
              ? _buildSetupForm()
              : Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: (_tableData[0].length * 120.0), // Fixed width based on columns
                  child: Column(
                    children: [
                      Container(
                        child: Row(
                          children: [
                            ...List.generate(
                              _tableData[0].length,
                              (colIndex) => _buildCell(
                                0,
                                colIndex,
                                isHeader: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _verticalController,
                          itemCount: _tableData.length - 1,
                          itemBuilder: (context, index) {
                            final rowIndex = index + 1;
                            return Row(
                              children: [
                                ...List.generate(
                                  _tableData[rowIndex].length,
                                  (colIndex) => _buildCell(
                                    rowIndex,
                                    colIndex,
                                    isHeader: false,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCell(int rowIndex, int colIndex, {required bool isHeader}) {
    final isDateCol = colIndex == 0 && !isHeader;
    final borderColor = Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black;

    bool isSelectable = _isDeletionMode && ((isHeader && colIndex > 0) || (!isHeader && colIndex == 0));
    bool isSelected = false;
    if (_isDeletionMode) {
       if (isHeader && colIndex > 0) isSelected = _selectedCols.contains(colIndex);
       if (!isHeader && colIndex == 0) isSelected = _selectedRows.contains(rowIndex);
    }

    return Container(
      width: 120.0,
      height: 40.0,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: borderColor, width: 1.0),
          bottom: BorderSide(color: borderColor, width: 1.0),
          left: colIndex == 0 ? BorderSide(color: borderColor, width: 1.0) : BorderSide.none,
          top: rowIndex == 0 ? BorderSide(color: borderColor, width: 1.0) : BorderSide.none,
        ),
        color: isSelected 
            ? Colors.red.withValues(alpha: 0.2) 
            : (_isDeletionMode && !isSelectable 
                ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[200]) // Dim non-selectable cells
                : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _isDeletionMode
        ? InkWell(
            onTap: isSelectable ? () {
               setState(() {
                 if (isHeader) {
                   if (_selectedCols.contains(colIndex)) _selectedCols.remove(colIndex);
                   else _selectedCols.add(colIndex);
                 } else {
                   if (_selectedRows.contains(rowIndex)) _selectedRows.remove(rowIndex);
                   else _selectedRows.add(rowIndex);
                 }
               });
            } : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelectable)
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 16,
                    color: isSelected ? Colors.red : Colors.grey,
                  ),
                if (isSelectable)
                  const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _tableData[rowIndex][colIndex],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        : (isDateCol 
            ? InkWell(
                onTap: () => _pickDate(rowIndex),
                child: IgnorePointer(
                  child: TextFormField(
                    key: Key('date_${rowIndex}_${_tableData[rowIndex][colIndex]}'),
                    initialValue: _tableData[rowIndex][colIndex],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      hintText: 'Date',
                      hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              )
            : Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                     _debouncedSave(); // Only save when focus is lost
                  }
                },
                child: TextFormField(
                  key: Key('cell_${rowIndex}_${colIndex}_${_tableData[rowIndex][colIndex]}'),
                  initialValue: _tableData[rowIndex][colIndex],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    hintText: isHeader ? 'Col' : '',
                    hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) => _updateCell(rowIndex, colIndex, val),
                ),
              )
          ),
    );
  }
}
