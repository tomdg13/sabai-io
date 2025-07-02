<<<<<<< HEAD
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

=======
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
import 'package:image_picker/image_picker.dart';

// Reusable widget for image preview + pick
class ImagePickerWidget extends StatelessWidget {
  final String label;
  final File? imageFile;
  final String? imageUrl;
  final VoidCallback onTap;
  final double size;
  final bool isCircular;

  const ImagePickerWidget({
    Key? key,
    required this.label,
    this.imageFile,
    this.imageUrl,
    required this.onTap,
    this.size = 100,
    this.isCircular = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;

    if (imageFile != null) {
      imageProvider = FileImage(imageFile!);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(imageUrl!);
    }

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
              border: Border.all(color: Colors.grey),
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
            ),
            child: imageProvider == null
                ? const Icon(Icons.image, size: 40)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}

>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
class carInfoPage extends StatefulWidget {
  final Map<String, dynamic> carData;

  const carInfoPage({Key? key, required this.carData}) : super(key: key);

  @override
  _carInfoPageState createState() => _carInfoPageState();
}

class _carInfoPageState extends State<carInfoPage> {
  String? langCode;
  File? _picture_id;
  File? _picture1;
  File? _picture2;
  File? _picture3;

  @override
  void initState() {
    super.initState();
    _loadLangCode();

    final car = widget.carData;
    print('==== Car Info ====');
    print('brand: ${car['brand']}');
    print('model: ${car['model']}');
    print('license_plate: ${car['license_plate']}');
    print('pr_name: ${car['pr_name']}');
    print('car_type_id: ${car['car_type_id']}');
    print('picture_id: ${car['picture_id']}');
    print('picture1: ${car['picture1']}');
    print('picture2: ${car['picture2']}');
    print('picture3: ${car['picture3']}');
    print('===================');
  }

  Future<void> _loadLangCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  Future<void> _pickImage(String type) async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        final file = File(pickedFile.path);
        switch (type) {
          case 'picture_id':
            _picture_id = file;
            break;
          case 'picture1':
            _picture1 = file;
            break;
          case 'picture2':
            _picture2 = file;
            break;
          case 'picture3':
            _picture3 = file;
            break;
        }
      });
    }
  }

<<<<<<< HEAD
  Widget _imagePreview(
    String label, {
    File? imageFile,
    String? imageUrl,
    required VoidCallback onTap,
    double size = 100,
    bool isCircular = true,
  }) {
    ImageProvider? imageProvider;

    if (imageFile != null) {
      imageProvider = FileImage(imageFile);
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      imageProvider = NetworkImage(imageUrl);
    }

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
              border: Border.all(color: Colors.grey),
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
            ),
            child: imageProvider == null
                ? const Icon(Icons.image, size: 40)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }

=======
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
  Widget _buildReadOnlyField({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        readOnly: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLangCode = langCode ?? 'en';
    final carData = widget.carData;

    return Scaffold(
      appBar: AppBar(
        title: Text(SimpleTranslations.get(effectiveLangCode, 'carInfoPage')),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
<<<<<<< HEAD
                  _imagePreview(
                    SimpleTranslations.get(effectiveLangCode, "picture_Id"),
=======
                  ImagePickerWidget(
                    label: SimpleTranslations.get(effectiveLangCode, "picture_Id"),
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
                    imageFile: _picture_id,
                    imageUrl: carData['picture_id'] as String?,
                    onTap: () => _pickImage('picture_id'),
                    size: 200,
                    isCircular: false,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
<<<<<<< HEAD
                  _imagePreview(
                    SimpleTranslations.get(effectiveLangCode, "picture1"),
=======
                  ImagePickerWidget(
                    label: SimpleTranslations.get(effectiveLangCode, "picture1"),
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
                    imageFile: _picture1,
                    imageUrl: carData['picture1'] as String?,
                    onTap: () => _pickImage('picture1'),
                    size: 100,
                    isCircular: false,
                  ),
<<<<<<< HEAD
                  _imagePreview(
                    SimpleTranslations.get(effectiveLangCode, "picture2"),
=======
                  ImagePickerWidget(
                    label: SimpleTranslations.get(effectiveLangCode, "picture2"),
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
                    imageFile: _picture2,
                    imageUrl: carData['picture2'] as String?,
                    onTap: () => _pickImage('picture2'),
                    size: 100,
                    isCircular: false,
                  ),
<<<<<<< HEAD
                  _imagePreview(
                    SimpleTranslations.get(effectiveLangCode, "picture3"),
=======
                  ImagePickerWidget(
                    label: SimpleTranslations.get(effectiveLangCode, "picture3"),
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
                    imageFile: _picture3,
                    imageUrl: carData['picture3'] as String?,
                    onTap: () => _pickImage('picture3'),
                    size: 100,
                    isCircular: false,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildReadOnlyField(
                label: SimpleTranslations.get(effectiveLangCode, 'brand'),
                value: carData['brand'] ?? '',
              ),
              _buildReadOnlyField(
                label: SimpleTranslations.get(effectiveLangCode, 'model'),
                value: carData['model'] ?? '',
              ),
              _buildReadOnlyField(
                label: SimpleTranslations.get(effectiveLangCode, 'car_type_id'),
<<<<<<< HEAD
                value: carData['car_type_id'] ?? '',
=======
                value: carData['car_type_id'].toString(),
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
              ),

              // Combined container for pr_name and license_plate
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellow,
                    border: Border.all(color: Colors.black, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        carData['pr_name'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        carData['license_plate'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
<<<<<<< HEAD
              // Buttons removed
=======
              // Buttons or other widgets if needed
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
            ],
          ),
        ),
      ),
    );
  }
}
