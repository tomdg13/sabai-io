import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
// import 'package:sabaicub/config/config.dart';

class ImagePreviewPage extends StatefulWidget {
  final String imageUrl; // original image URL
  final String name; // user name to show on appbar
  final int customerId;
  final String token;
  final String role; // <-- added role
  final VoidCallback onUpdateProfile;

  const ImagePreviewPage({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.customerId,
    required this.token,
    required this.role, // <-- added role
    required this.onUpdateProfile,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late String displayedImageUrl;
  String? newImageBase64;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    displayedImageUrl = widget.imageUrl;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return; // User cancelled

    final bytes = await pickedFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    setState(() {
      newImageBase64 = 'data:image/png;base64,$base64Image';
      displayedImageUrl = pickedFile.path; // local file path to preview
    });
  }

  Future<void> _uploadImage() async {
    if (newImageBase64 == null) return;

    setState(() {
      uploading = true;
    });

    try {
      final url = AppConfig.api('/api/user/uploadProfile');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'customer_id': widget.customerId,
          'role': widget.role, // <-- added role here
          'profile_image': newImageBase64,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(
          //     content: Text('Profile image updated successfully!'),
          //   ),
          // );
          widget.onUpdateProfile();
          Navigator.of(context).pop(); // go back after upload success
        } else {
          throw Exception(data['message'] ?? 'Failed to update image');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        uploading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isNewImagePicked = newImageBase64 != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.name, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    InteractiveViewer(
                      child: CircleAvatar(
                        radius: 130,
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage: isNewImagePicked
                            ? FileImage(File(displayedImageUrl))
                                  as ImageProvider
                            : (displayedImageUrl.isNotEmpty
                                      ? NetworkImage(displayedImageUrl)
                                      : const AssetImage(
                                          'assets/images/default_profile.png',
                                        ))
                                  as ImageProvider,
                        onBackgroundImageError: (_, __) {
                          setState(() {
                            displayedImageUrl = '';
                            newImageBase64 = null;
                          });
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        backgroundColor: Colors.green,
                        mini: true,
                        onPressed: uploading ? null : _pickImage,
                        child: uploading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Icon(Icons.edit),
                      ),
                    ),
                  ],
                ),
                if (isNewImagePicked) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: uploading ? null : _uploadImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 3,
                            ),
                            child: uploading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Confirm',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: uploading
                                ? null
                                : () {
                                    setState(() {
                                      newImageBase64 = null;
                                      displayedImageUrl = widget.imageUrl;
                                    });
                                  },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
