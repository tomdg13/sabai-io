import 'package:flutter/material.dart';
import 'package:sabaicub/login/regiteruser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';

class ConfirmOtpPage extends StatefulWidget {
  final String phone;
  final String serverOtp;

  const ConfirmOtpPage({Key? key, required this.phone, required this.serverOtp})
    : super(key: key);

  @override
  State<ConfirmOtpPage> createState() => _ConfirmOtpPageState();
}

class _ConfirmOtpPageState extends State<ConfirmOtpPage> {
  final TextEditingController _otpController = TextEditingController();
  String? errorMessage;
  bool isVerified = false;
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
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RegisterUserPage(phone: widget.phone),
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
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCode, 'ConfirmOtp')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${SimpleTranslations.get(langCode, 'PhoneLabel')}: ${widget.phone}',
                    style: const TextStyle(fontSize: 16),
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
                    decoration: InputDecoration(
                      labelText: SimpleTranslations.get(langCode, 'EnterOtp'),
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.verified),
                      label: Text(
                        SimpleTranslations.get(langCode, 'VerifyOtp'),
                      ),
                      onPressed: _verifyOtp,
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                  if (isVerified) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        SimpleTranslations.get(langCode, 'OtpVerifiedSuccess'),
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
