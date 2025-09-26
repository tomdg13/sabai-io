import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

class CSVUploadPage extends StatefulWidget {
  final String apiType;

  /// apiType can be "acquirer-settlement" or "settlement-summary"
  const CSVUploadPage({super.key, this.apiType = "acquirer-settlement"});

  @override
  State<CSVUploadPage> createState() => _CSVUploadPageState();
}

class _CSVUploadPageState extends State<CSVUploadPage> {
  List<List<dynamic>> _csvData = [];
  bool _loading = false;
  String? _statusMessage;

  Future<void> _pickAndParseCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      final input = file.openRead();
      final fields = await input
          .transform(utf8.decoder)
          .transform(const CsvToListConverter())
          .toList();

      setState(() {
        _csvData = fields;
      });
    }
  }

  Future<void> _uploadCSV() async {
    if (_csvData.isEmpty) {
      setState(() {
        _statusMessage = "⚠️ Please pick a CSV file first.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    try {
      // First row is header
      final headers = _csvData.first.map((h) => h.toString()).toList();
      final dataRows = _csvData.skip(1);

      final jsonData = dataRows.map((row) {
        final map = <String, dynamic>{};
        for (int i = 0; i < headers.length; i++) {
          map[headers[i]] = row[i];
        }
        return map;
      }).toList();

      final url = Uri.parse(
          "http://localhost:3000/api/payment-system/${widget.apiType}/import-csv");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"csvData": jsonData}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          _statusMessage = "✅ Upload successful!";
        });
      } else {
        setState(() {
          _statusMessage =
              "❌ Upload failed: ${response.statusCode}\n${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Error: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("CSV Upload (${widget.apiType})"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.file_upload),
              label: const Text("Pick CSV File"),
              onPressed: _pickAndParseCSV,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _csvData.isEmpty
                  ? const Center(child: Text("No CSV file loaded."))
                  : ListView.builder(
                      itemCount: _csvData.length,
                      itemBuilder: (context, index) {
                        return Text(_csvData[index].join(", "));
                      },
                    ),
            ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator(),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusMessage!.contains("✅")
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _uploadCSV,
              child: const Text("Upload CSV"),
            ),
          ],
        ),
      ),
    );
  }
}
