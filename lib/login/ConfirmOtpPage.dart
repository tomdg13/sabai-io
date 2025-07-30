import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sabaicub/config/theme.dart';
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

class _ConfirmOtpPageState extends State<ConfirmOtpPage>
    with TickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  String? errorMessage;
  bool isVerified = false;
  bool isVerifying = false;
  String langCode = 'en';
  String currentTheme = ThemeConfig.defaultTheme;

  // Animation controllers
  late AnimationController _slideAnimationController;
  late AnimationController _shakeAnimationController;
  late AnimationController _successAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _successAnimation;

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
    _successAnimationController.dispose();
    _otpController.dispose();
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

    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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

    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: Curves.elasticOut,
      ),
    );
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

  Future<void> _verifyOtp() async {
    if (isVerifying) return;

    final enteredOtp = _otpController.text.trim();
    debugPrint('User entered OTP: $enteredOtp');
    debugPrint('Expected server OTP: ${widget.serverOtp}');

    if (enteredOtp.isEmpty) {
      setState(() {
        errorMessage = SimpleTranslations.get(langCode, 'EnterOtpRequired');
        isVerified = false;
      });
      _triggerShakeAnimation();
      debugPrint('OTP verification failed: No OTP entered');
      return;
    }

    setState(() {
      isVerifying = true;
      errorMessage = null;
    });

    HapticFeedback.lightImpact();

    // Add a small delay for better UX
    await Future.delayed(const Duration(milliseconds: 800));

    if (enteredOtp == widget.serverOtp) {
      setState(() {
        errorMessage = null;
        isVerified = true;
        isVerifying = false;
      });

      debugPrint('OTP verification succeeded');
      HapticFeedback.mediumImpact();
      _successAnimationController.forward();

      _showSuccessSnackBar();

      // Navigate after animation
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RegisterUserPage(phone: widget.phone),
          ),
        );
      }
    } else {
      setState(() {
        errorMessage = SimpleTranslations.get(langCode, 'InvalidOtp');
        isVerified = false;
        isVerifying = false;
      });

      HapticFeedback.heavyImpact();
      _triggerShakeAnimation();
      debugPrint('OTP verification failed: OTP does not match');
    }
  }

  void _triggerShakeAnimation() {
    _shakeAnimationController.forward().then((_) {
      _shakeAnimationController.reset();
    });
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              SimpleTranslations.get(langCode, 'OtpVerifiedSuccess'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPhoneDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
            ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.phone,
              color: ThemeConfig.getPrimaryColor(currentTheme),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SimpleTranslations.get(langCode, 'PhoneLabel'),
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeConfig.getTextColor(
                      currentTheme,
                    ).withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.phone,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ThemeConfig.getTextColor(currentTheme),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInput() {
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
                SimpleTranslations.get(langCode, 'EnterOtp'),
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
                child: TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: ThemeConfig.getTextColor(currentTheme),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '• • • • • •',
                    hintStyle: TextStyle(
                      color: ThemeConfig.getTextColor(
                        currentTheme,
                      ).withOpacity(0.3),
                      letterSpacing: 8,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.lock_outline,
                        color: ThemeConfig.getPrimaryColor(currentTheme),
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
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (value) {
                    if (errorMessage != null) {
                      setState(() {
                        errorMessage = null;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerifyButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: isVerifying
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
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: isVerifying ? null : _verifyOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: isVerifying
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
            : const Icon(Icons.verified, size: 24),
        label: Text(
          isVerifying
              ? 'Verifying...'
              : SimpleTranslations.get(langCode, 'VerifyOtp'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (errorMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage!,
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    if (!isVerified) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.1),
                  Colors.green.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  SimpleTranslations.get(langCode, 'OtpVerifiedSuccess'),
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(currentTheme),
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(langCode, 'ConfirmOtp'),
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
                elevation: 8,
                shadowColor: ThemeConfig.getPrimaryColor(
                  currentTheme,
                ).withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    ThemeConfig.getPrimaryColor(
                                      currentTheme,
                                    ).withOpacity(0.1),
                                    ThemeConfig.getPrimaryColor(
                                      currentTheme,
                                    ).withOpacity(0.05),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.security,
                                color: ThemeConfig.getPrimaryColor(
                                  currentTheme,
                                ),
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Verify Your Phone',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: ThemeConfig.getTextColor(currentTheme),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter the 6-digit code sent to your phone',
                              style: TextStyle(
                                fontSize: 14,
                                color: ThemeConfig.getTextColor(
                                  currentTheme,
                                ).withOpacity(0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Phone display
                      _buildPhoneDisplay(),

                      const SizedBox(height: 24),

                      // OTP input
                      _buildOtpInput(),

                      const SizedBox(height: 24),

                      // Verify button
                      _buildVerifyButton(),

                      const SizedBox(height: 16),

                      // Error message
                      _buildErrorMessage(),

                      // Success message
                      _buildSuccessMessage(),
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
