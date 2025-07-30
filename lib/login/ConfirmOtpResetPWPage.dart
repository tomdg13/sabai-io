import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sabaicub/config/theme.dart'; // Add theme import
import '../utils/simple_translations.dart';
import 'ForgetPasswordPage.dart';

class ConfirmOtpResetPWPage extends StatefulWidget {
  final String phone;
  final String serverOtp;

  const ConfirmOtpResetPWPage({
    Key? key,
    required this.phone,
    required this.serverOtp,
  }) : super(key: key);

  @override
  State<ConfirmOtpResetPWPage> createState() => _ConfirmOtpResetPWPageState();
}

class _ConfirmOtpResetPWPageState extends State<ConfirmOtpResetPWPage> {
  final TextEditingController _otpController = TextEditingController();
  String? errorMessage;
  bool isVerified = false;
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

  void _verifyOtp() {
    final enteredOtp = _otpController.text.trim();
    print('User entered OTP: $enteredOtp');
    print('Expected server OTP: ${widget.serverOtp}');

    if (enteredOtp.isEmpty) {
      setState(() {
        errorMessage = SimpleTranslations.get(langCode, 'EnterOtpRequired');
        isVerified = false;
      });
      print('OTP verification failed: No OTP entered');
      return;
    }

    if (enteredOtp == widget.serverOtp) {
      setState(() {
        errorMessage = null;
        isVerified = true;
      });
      print('OTP verification succeeded');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SimpleTranslations.get(langCode, 'OtpVerifiedSuccess')),
          backgroundColor: ThemeConfig.getPrimaryColor(
            currentTheme,
          ), // Use theme color
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ForgetPasswordPage(phone: widget.phone),
        ),
      );
    } else {
      setState(() {
        errorMessage = SimpleTranslations.get(langCode, 'InvalidOtp');
        isVerified = false;
      });
      print('OTP verification failed: OTP does not match');
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(
        currentTheme,
      ), // Use theme background
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(langCode, 'ConfirmOtp'),
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
          padding: const EdgeInsets.all(16),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            color: ThemeConfig.getBackgroundColor(
              currentTheme,
            ), // Use theme background for card
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.phone,
                        color: ThemeConfig.getPrimaryColor(currentTheme),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${SimpleTranslations.get(langCode, 'PhoneLabel')}: ${widget.phone}',
                          style: TextStyle(
                            fontSize: 16,
                            color: ThemeConfig.getTextColor(currentTheme),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // const SizedBox(height: 8),
                  // Text(
                  //     '${SimpleTranslations.get(langCode, 'OtpSentLabel')}: ${widget.serverOtp}',
                  //     style: const TextStyle(
                  //         fontSize: 16,
                  //         color: Colors.green,
                  //         fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: ThemeConfig.getTextColor(currentTheme),
                    ),
                    decoration: InputDecoration(
                      labelText: SimpleTranslations.get(langCode, 'EnterOtp'),
                      labelStyle: TextStyle(
                        color: ThemeConfig.getTextColor(currentTheme),
                      ),
                      prefixIcon: Icon(
                        Icons.lock,
                        color: ThemeConfig.getPrimaryColor(currentTheme),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ).withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(
                        Icons.verified,
                        color: ThemeConfig.getButtonTextColor(currentTheme),
                      ),
                      label: Text(
                        SimpleTranslations.get(langCode, 'VerifyOtp'),
                        style: TextStyle(
                          color: ThemeConfig.getButtonTextColor(currentTheme),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConfig.getPrimaryColor(
                          currentTheme,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _verifyOtp,
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isVerified) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              SimpleTranslations.get(
                                langCode,
                                'OtpVerifiedSuccess',
                              ),
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
