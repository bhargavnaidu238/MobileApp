import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hotel_booking_app/services/api_service.dart';

class UploadImagesPage extends StatefulWidget {
  final String partnerId;
  final String hotelId; // TEMP-HOTEL-ID until final save

  const UploadImagesPage({Key? key, required this.partnerId, required this.hotelId}) : super(key: key);

  @override
  _UploadImagesPageState createState() => _UploadImagesPageState();
}

class _UploadImagesPageState extends State<UploadImagesPage> {
  final List<String> categories = [
    "Facade",
    "Lobby/Entrance",
    "Standard Rooms",
    "Executive Rooms",
    "Suite Rooms"
  ];

  final Map<String, int> limits = {
    "Facade": 5,
    "Lobby/Entrance": 5,
    "Standard Rooms": 10,
    "Executive Rooms": 10,
    "Suite Rooms": 10,
  };

  final Map<String, List<String>> uploadedUrls = {};
  final Map<String, List<_LocalImage>> localImages = {}; // Previews before upload

  final int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    for (var c in categories) {
      uploadedUrls[c] = [];
      localImages[c] = [];
    }
  }

  Future<void> _pickAndUpload(String category) async {
    int remaining = limits[category]! - uploadedUrls[category]!.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Limit reached for $category')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );

    if (result == null) return;

    final selected = result.files.take(remaining).toList();

    for (final pf in selected) {
      if (pf.size > maxFileSizeBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pf.name} is > 10MB and skipped')),
        );
        continue;
      }

      if (pf.bytes != null) {
        localImages[category]!.add(_LocalImage(name: pf.name, bytes: pf.bytes!, path: pf.path));
      } else if (pf.path != null) {
        final file = File(pf.path!);
        final bytes = await file.readAsBytes();
        localImages[category]!.add(_LocalImage(name: pf.name, bytes: bytes, path: pf.path));
      }
    }

    setState(() {});
    await _uploadBatch(category);
  }

  Future<void> _uploadBatch(String category) async {
    if (localImages[category]!.isEmpty) return;

    setState(() => _isUploading = true);

    try {
      final uri = Uri.parse("${ApiConfig.baseUrl}/${widget.partnerId}/${widget.hotelId}");
      final req = http.MultipartRequest('POST', uri);

      final batch = List<_LocalImage>.from(localImages[category]!);

      for (final img in batch) {
        http.MultipartFile mf;

        if (img.path != null) {
          final file = File(img.path!);
          mf = await http.MultipartFile.fromPath('files', img.path!, filename: img.name);
        } else {
          mf = http.MultipartFile.fromBytes('files', img.bytes!, filename: img.name);
        }

        req.files.add(mf);
      }

      req.fields['category'] = category;

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        if (decoded['urls'] != null) {
          uploadedUrls[category]!.addAll(List<String>.from(decoded['urls']));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded ${batch.length} images for $category')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed (${resp.statusCode})')),
        );
      }

      localImages[category]!.clear();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload error: $e')),
      );
    }

    setState(() => _isUploading = false);
  }

  Map<String, String> getAllCommaSeparated() {
    final out = <String, String>{};
    for (var c in categories) {
      out[c] = uploadedUrls[c]!.join(',');
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Hotel Images"),
        backgroundColor: Colors.green.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => Navigator.pop(context, getAllCommaSeparated()),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              "Upload images per category (<= 10MB each)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ListView.separated(
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildCategoryCard(categories[i]),
              ),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
              onPressed: () => Navigator.pop(context, getAllCommaSeparated()),
              child: const Text("Done"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String cat) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cat,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                Text(
                  "Uploaded: ${uploadedUrls[cat]!.length}",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isUploading ? null : () => _pickAndUpload(cat),
                  child: const Text("Pick & Upload"),
                )
              ],
            ),

            if (localImages[cat]!.isNotEmpty) _buildLocalPreview(cat),
            if (uploadedUrls[cat]!.isNotEmpty) _buildUploadedPreview(cat),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalPreview(String cat) {
    final list = localImages[cat]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('Selected (not uploaded yet):', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.black26,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(list[i].bytes!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 90,
                    child: Text(
                      list[i].name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  )
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildUploadedPreview(String cat) {
    final list = uploadedUrls[cat]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('Uploaded:', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(list[i], fit: BoxFit.cover, width: 90, height: 70),
              ),
            ),
          ),
        )
      ],
    );
  }
}

class _LocalImage {
  final String name;
  final Uint8List? bytes;
  final String? path;

  _LocalImage({required this.name, required this.bytes, required this.path});
}