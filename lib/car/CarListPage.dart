import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/car/CarAddPage.dart';
import 'package:sabaicub/car/carInfoPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../config/config.dart'; // Ensure this has AppConfig.api
import '../utils/simple_translations.dart';
// import 'carInfoPage.dart';
// import 'CarAddPage.dart';

class CarListPage extends StatefulWidget {
  const CarListPage({Key? key}) : super(key: key);

  @override
  State<CarListPage> createState() => _CarListPageState();
}

class _CarListPageState extends State<CarListPage> {
  List<Car> cars = [];
  List<Car> filteredCars = [];
  bool loading = true;
  String? error;
  String langCode = 'en';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLangCode();
    fetchCars();
    _searchController.addListener(() {
      filterCars(_searchController.text);
    });
  }

  Future<void> _loadLangCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  Future<void> fetchCars() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final role = prefs.getString('role') ?? 'Driver';

    final url = AppConfig.api('/api/car/carRole');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'role': role}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List raw = data['data'];
          setState(() {
            cars = raw.map((e) => Car.fromJson(e)).toList();
            filteredCars = cars;
            loading = false;
          });
        } else {
          setState(() {
            error = data['message'];
            loading = false;
          });
        }
      } else {
        setState(() {
          error = 'Error ${response.statusCode}';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void filterCars(String query) {
    final q = query.toLowerCase();
    setState(() {
      filteredCars = cars.where((car) {
        return car.license_plate.toLowerCase().contains(q) ||
            car.car_type_la.toLowerCase().contains(q) ||
            car.model.toLowerCase().contains(q);
      }).toList();
    });
  }

  void _onAddCar() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CarAddPage()),
    );
    if (result == true) {
      fetchCars();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'search'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredCars.isEmpty
                ? Center(
                    child: Text(
                      SimpleTranslations.get(langCode, 'no_cars_found'),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredCars.length,
                    itemBuilder: (ctx, i) {
                      final car = filteredCars[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: car.picture1.isNotEmpty
                              ? NetworkImage(car.picture1)
                              : const AssetImage(
                                      'assets/images/default_car.png',
                                    )
                                    as ImageProvider,
                        ),
                        title: Text(car.car_type_la),
                        subtitle: Text(car.model),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.yellowAccent,
                            border: Border.all(color: Colors.black, width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            car.license_plate_no,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => carInfoPage(
                                carData: {
                                  'brand': car.brand,
                                  'model': car.model,
                                  'license_plate': car.license_plate,
                                  'pr_name': car.pr_name,
                                  'car_type_id': car.car_type_la,
                                  'picture1': car.picture1,
                                  'picture2': car.picture2,
                                  'picture3': car.picture3,
                                  'picture_id': car.picture_id,
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddCar,
        backgroundColor: Colors.blue,
        tooltip: SimpleTranslations.get(langCode, 'add_car'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class Car {
  final int carId;
  final String license_plate;
  final String model;
  final String brand;
  final String car_type;
  final String license_plate_no;
  final String pr_name;
  final String car_type_la;
  final String picture1;
  final String picture2;
  final String picture3;
  final String picture_id;

  Car({
    required this.carId,
    required this.license_plate,
    required this.model,
    required this.brand,
    required this.car_type,
    required this.license_plate_no,
    required this.pr_name,
    required this.car_type_la,
    required this.picture1,
    required this.picture2,
    required this.picture3,
    required this.picture_id,
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      carId: json['car_id'] ?? 0,
      license_plate: json['license_plate'] ?? '',
      model: json['model'] ?? '',
      brand: json['brand'] ?? '',
      car_type: json['car_type'] ?? '',
      license_plate_no: json['license_plate_no'] ?? '',
      pr_name: json['pr_name'] ?? '',
      car_type_la: json['car_type_la'] ?? '',
      picture1: json['picture1'] ?? '',
      picture2: json['picture2'] ?? '',
      picture3: json['picture3'] ?? '',
      picture_id: json['picture_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'car_id': carId,
    'license_plate': license_plate,
    'model': model,
    'picture1': picture1,
    'picture2': picture2,
    'picture3': picture3,
    'picture_id': picture_id,
  };
}
