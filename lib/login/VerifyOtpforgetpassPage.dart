import 'dart:convert';
import 'package:sabaicub/config/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
import 'package:sabaicub/config/theme.dart';
import 'ConfirmOtpResetPWPage.dart';

class VerifyOtpforgetpassPage extends StatefulWidget {
  const VerifyOtpforgetpassPage({Key? key}) : super(key: key);

  @override
  State<VerifyOtpforgetpassPage> createState() =>
      _VerifyOtpforgetpassPageState();
}

class _VerifyOtpforgetpassPageState extends State<VerifyOtpforgetpassPage> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  String? errorMessage;
  String langCode = 'en';
  String currentTheme = ThemeConfig.defaultTheme; // Add theme state

  @override
  void initState() {
    super.initState();
    _loadLang();
    _loadTheme(); // Load current theme
  }

  Future<void> _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  // Add method to load current theme
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme =
          prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
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
                  ConfirmOtpResetPWPage(phone: phone, serverOtp: otp),
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
      backgroundColor: ThemeConfig.getBackgroundColor(
        currentTheme,
      ), // Use theme background
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(langCode, 'ForgetPassword'),
          style: TextStyle(color: ThemeConfig.getButtonTextColor(currentTheme)),
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(
          currentTheme,
        ), // Use theme primary color
        iconTheme: IconThemeData(
          color: ThemeConfig.getButtonTextColor(currentTheme),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            color: ThemeConfig.getBackgroundColor(
              currentTheme,
            ), // Use theme background for card
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_reset,
                    size: 60,
                    color: ThemeConfig.getPrimaryColor(
                      currentTheme,
                    ), // Use theme primary color
                  ),
                  const SizedBox(height: 16),
                  Text(
                    SimpleTranslations.get(
                      langCode,
                      'EnterPhoneToResetPassword',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ThemeConfig.getTextColor(
                        currentTheme,
                      ), // Use theme text color
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(
                        color: ThemeConfig.getTextColor(
                          currentTheme,
                        ), // Use theme text color
                      ),
                      decoration: InputDecoration(
                        labelText: SimpleTranslations.get(langCode, 'phone'),
                        labelStyle: TextStyle(
                          color: ThemeConfig.getTextColor(currentTheme),
                        ),
                        prefixIcon: Icon(
                          Icons.phone,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(
                              currentTheme,
                            ).withOpacity(0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                            width: 2,
                          ),
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
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: ThemeConfig.getButtonTextColor(
                                  currentTheme,
                                ), // Use theme button text color
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.send,
                              color: ThemeConfig.getButtonTextColor(
                                currentTheme,
                              ),
                            ),
                      label: Text(
                        SimpleTranslations.get(langCode, 'GetOtpForReset'),
                        style: TextStyle(
                          color: ThemeConfig.getButtonTextColor(currentTheme),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConfig.getPrimaryColor(
                          currentTheme,
                        ), // Use theme primary color
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isLoading ? null : _verifyPhone,
                    ),
                  ),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                        ), // Keep error red for visibility
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
