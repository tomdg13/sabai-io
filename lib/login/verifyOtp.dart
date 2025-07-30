import 'dart:convert';
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/config/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
import 'ConfirmOtpPage.dart';

class VerifyOtpPage extends StatefulWidget {
  const VerifyOtpPage({Key? key}) : super(key: key);

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage>
    with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  String? errorMessage;
  String langCode = 'en';
  String currentTheme = ThemeConfig.defaultTheme;

  // Animation controllers
  late AnimationController _slideAnimationController;
  late AnimationController _shakeAnimationController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializePage();
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    _shakeAnimationController.dispose();
    _pulseController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _shakeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_shakeAnimationController);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializePage() async {
    await Future.wait([_loadTheme(), _loadLang()]);

    _slideAnimationController.forward();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme =
        prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    if (mounted) {
      setState(() {
        currentTheme = savedTheme;
      });
    }
  }

  Future<void> _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        langCode = prefs.getString('languageCode') ?? 'en';
      });
    }
  }

  void _triggerShakeAnimation() {
    _shakeAnimationController.forward().then((_) {
      _shakeAnimationController.reset();
    });
  }

  Future<void> _verifyPhone() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        errorMessage = SimpleTranslations.get(langCode, 'InvalidPhoneFormat');
      });
      _triggerShakeAnimation();
      HapticFeedback.lightImpact();
      return;
    }

    final phone = _phoneController.text.trim();

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    HapticFeedback.lightImpact();
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

          HapticFeedback.mediumImpact();

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

          _triggerShakeAnimation();
          HapticFeedback.heavyImpact();
        }
      } else {
        setState(() {
          errorMessage =
              '${SimpleTranslations.get(langCode, 'ServerError')}: ${response.statusCode}';
          isLoading = false;
        });

        _triggerShakeAnimation();
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      setState(() {
        errorMessage =
            '${SimpleTranslations.get(langCode, 'RequestFailed')}: $e';
        isLoading = false;
      });

      _triggerShakeAnimation();
      HapticFeedback.heavyImpact();
    }
  }

  Widget _buildHeader() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ThemeConfig.getPrimaryColor(
                        currentTheme,
                      ).withOpacity(0.2),
                      ThemeConfig.getPrimaryColor(
                        currentTheme,
                      ).withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ThemeConfig.getPrimaryColor(
                        currentTheme,
                      ).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.phone_android,
                  size: 48,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),
        Text(
          SimpleTranslations.get(langCode, 'EnterYourPhoneToGetOtp'),
          style: TextStyle(
            fontSize: 16,
            color: ThemeConfig.getTextColor(currentTheme).withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _shakeAnimation.value *
                10 *
                ((_shakeAnimationController.value * 4).floor() % 2 == 0
                    ? 1
                    : -1),
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SimpleTranslations.get(langCode, 'phone'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ThemeConfig.getTextColor(currentTheme),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeConfig.getPrimaryColor(
                        currentTheme,
                      ).withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: ThemeConfig.getTextColor(currentTheme),
                    ),
                    decoration: InputDecoration(
                      hintText: '20XXXXXXXX',
                      hintStyle: TextStyle(
                        color: ThemeConfig.getTextColor(
                          currentTheme,
                        ).withOpacity(0.5),
                      ),
                      prefixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.phone,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                              size: 20,
                            ),
                           
                            Container(
                              width: 1,
                              height: 20,
                              margin: const EdgeInsets.only(left: 8),
                              color: ThemeConfig.getTextColor(
                                currentTheme,
                              ).withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                      filled: true,
                      fillColor: ThemeConfig.getBackgroundColor(currentTheme),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ).withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ).withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
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
                    onChanged: (value) {
                      if (errorMessage != null) {
                        setState(() {
                          errorMessage = null;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGetOtpButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: isLoading
              ? [Colors.grey, Colors.grey]
              : [
                  ThemeConfig.getPrimaryColor(currentTheme),
                  ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.8),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _verifyPhone,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ThemeConfig.getButtonTextColor(currentTheme),
                  ),
                ),
              )
            : const Icon(Icons.send, size: 24),
        label: Text(
          isLoading
              ? 'Sending OTP...'
              : SimpleTranslations.get(langCode, 'GetOtp'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (errorMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(currentTheme),
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(langCode, 'VerifyPhone'),
          style: TextStyle(
            color: ThemeConfig.getButtonTextColor(currentTheme),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ThemeConfig.getPrimaryColor(currentTheme),
                ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.9),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.02),
              ThemeConfig.getBackgroundColor(currentTheme),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SlideTransition(
              position: _slideAnimation,
              child: Card(
                color: ThemeConfig.getBackgroundColor(currentTheme),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 12,
                shadowColor: ThemeConfig.getPrimaryColor(
                  currentTheme,
                ).withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      _buildHeader(),

                      const SizedBox(height: 32),

                      // Phone input
                      _buildPhoneInput(),

                      const SizedBox(height: 20),

                      const SizedBox(height: 24),

                      // Get OTP button
                      _buildGetOtpButton(),

                      const SizedBox(height: 16),

                      // Error message
                      _buildErrorMessage(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
