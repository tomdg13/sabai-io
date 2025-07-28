import 'dart:convert';
import 'package:sabaicub/config/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
import 'ConfirmOtpPage.dart';

class VerifyOtpPage extends StatefulWidget {
  const VerifyOtpPage({Key? key}) : super(key: key);

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  String? errorMessage;
  String langCode = 'en';

  @override
  void initState() {
    super.initState();
    _loadLang();
  }

  Future<void> _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  Future<void> _verifyPhone() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        errorMessage = SimpleTranslations.get(langCode, 'InvalidPhoneFormat');
      });
      return;
    }

    final phone = _phoneController.text.trim();

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final Uri url = AppConfig.api('/api/customer/addotp');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['otp'] != null) {
          final otp = data['otp'].toString();

          setState(() {
            isLoading = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ConfirmOtpPage(phone: phone, serverOtp: otp),
            ),
          );
        } else {
          // Map backend error messages to translation keys
          String backendMsg = data['message'] ?? '';
          String translatedMsg;

          switch (backendMsg) {
            case 'You have reached the daily OTP limit (5). Please try again tomorrow.':
              translatedMsg = SimpleTranslations.get(
                langCode,
                'OtpDailyLimitReached',
              );
              break;
            default:
              translatedMsg = SimpleTranslations.get(
                langCode,
                'FailedToGetOtp',
              );
          }

          setState(() {
            errorMessage = translatedMsg;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage =
              '${SimpleTranslations.get(langCode, 'ServerError')}: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage =
            '${SimpleTranslations.get(langCode, 'RequestFailed')}: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCode, 'VerifyPhone')),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android, size: 60, color: Colors.blue),
                  const SizedBox(height: 16),
                  Text(
                    SimpleTranslations.get(langCode, 'EnterYourPhoneToGetOtp'),
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: SimpleTranslations.get(langCode, 'phone'),
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        final pattern = RegExp(r'^20\d{8}$');
                        if (value == null || value.isEmpty) {
                          return SimpleTranslations.get(
                            langCode,
                            'EnterPhoneRequired',
                          );
                        }
                        if (!pattern.hasMatch(value)) {
                          return SimpleTranslations.get(
                            langCode,
                            'InvalidPhoneFormat',
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(SimpleTranslations.get(langCode, 'GetOtp')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isLoading ? null : _verifyPhone,
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
