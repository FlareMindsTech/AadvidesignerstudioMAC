import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../models/user.dart';
import 'register_screen.dart';
import 'main_navigation_screen.dart';
import 'edit_profile_screen.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isSignUpMode = false;
  bool _isOtpLogin = true; // Default to OTP for students
  bool _showOtpField = false;
  bool _showAdminTab = false; // Secretly toggle this to show Admin login
  bool _obscurePassword = true;
  int _timerSeconds = 30;
  Timer? _resendTimer;
  bool _rememberMe = false;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Password strength indicators
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigit = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();

    // Add password listener for strength checking
    _passwordController.addListener(_checkPasswordStrength);

    // Load saved credentials if remember me was checked
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final credentials = await StorageService.getSavedCredentials();
    if (credentials != null && mounted) {
      setState(() {
        _emailController.text = credentials['email'] ?? '';
        _passwordController.text = credentials['password'] ?? '';
        _rememberMe = true;
      });
    }
  }

  void _checkPasswordStrength() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasDigit = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timerSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--;
        } else {
          _resendTimer?.cancel();
        }
      });
    });
  }

  Future<void> _handleSendOtp() async {
    if (_phoneController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.sendOtp(
        _phoneController.text.trim(),
        mode: _isSignUpMode ? 'signup' : 'signin',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showOtpField = true;
        });
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        if (e.message.toLowerCase().contains('account already exists')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red),
          );
        } else if (e.message.toLowerCase().contains('no account found')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      LoginResponse loginResponse;

      if (_isOtpLogin) {
        if (!_showOtpField) {
          await _handleSendOtp();
          return;
        }
        loginResponse = await AuthService.verifyOtp(
          _phoneController.text.trim(),
          _otpController.text.trim(),
        );
      } else {
        loginResponse = await AuthService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (_rememberMe) {
          await StorageService.saveCredentials(
            _emailController.text.trim(),
            _passwordController.text,
          );
        }
      }

      if (!mounted) return;

      final role = loginResponse.user.role.toLowerCase().trim();
      
      // Security check: If someone tried to login with a student account while admin tab was hidden (theoretically)
      if (_showAdminTab && (role == 'student' || role == 'user')) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unauthorized access. Please use the Student login.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = false);

      // Show "Login Successful" popup
      await _showLoginSuccessDialog(loginResponse.user);

      if (!mounted) return;

      // Check if profile is complete (especially for new OTP users)
      if (!loginResponse.user.isProfileComplete) {
        Navigator.of(context).pushReplacement(
          PageTransition(
            type: PageTransitionType.fade,
            child: EditProfileScreen(
              user: loginResponse.user,
              isInitialSetup: true,
            ),
          ),
        );
      } else {
        context.read<AppProvider>().setSelectedIndex(0);
        Navigator.of(context).pushReplacement(
          PageTransition(
            type: PageTransitionType.fade,
            child: const MainNavigationScreen(),
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred.')),
        );
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _showLoginSuccessDialog(User user) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            const Text(
              'Login successfully',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        duration: const Duration(seconds: 2),
      ),
    );

    // Small delay before navigation
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      body: SafeArea(
        top: true,
        bottom: true,
        left: true,
        right: true,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 20.0,
              bottom: 20.0 + MediaQuery.of(context).padding.bottom,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Section - More Compact
                      _buildCompactLogo(primaryColor),
                      const SizedBox(height: 32),

                      // Login Card - Smaller & Cleaner
                      _buildCompactLoginCard(theme, isDark, primaryColor),
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

  Widget _buildCompactLogo(Color primaryColor) {
    return Column(
      children: [
        GestureDetector(
            onLongPress: () {
              // BLOCK regular switching if we are in the middle of OTP verification
              if (_showOtpField) return;

              FocusScope.of(context).unfocus();
              setState(() {
                _isOtpLogin = !_isOtpLogin;
                _showAdminTab = !_isOtpLogin; // Secretly track if we are in admin mode
                
                // Reset states and clear controllers
                _otpController.clear();
                _phoneController.clear();
                _emailController.clear();
                _passwordController.clear();
                _resendTimer?.cancel();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isOtpLogin 
                    ? 'Continue to mobile number' 
                    : 'Continue to email'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: _isOtpLogin ? Colors.green : Colors.deepPurple,
                ),
              );
            },
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/app_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Aadvi Fashion Institute',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Meeting Platform',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLoginCard(
      ThemeData theme, bool isDark, Color primaryColor) {
    return Card(
      elevation: isDark ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Welcome Text - Smaller
              const Text(
                'Welcome',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _isSignUpMode ? 'Create a new account' : 'Sign in to your account',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              const SizedBox(height: 12),


              if (_showOtpField) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'OTP sent to +91 ${_phoneController.text}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _showOtpField = false;
                          _otpController.clear();
                          _resendTimer?.cancel();
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Change Number',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildOtpField(theme, isDark),
                const SizedBox(height: 12),
                _buildResendSection(theme),
                const SizedBox(height: 20),
              ] else if (_isOtpLogin) ...[
                _buildPhoneField(theme, isDark),
                const SizedBox(height: 20),
              ] else ...[
                // Email Field
                _buildEmailField(theme, isDark),
                const SizedBox(height: 16),

                // Password Field
                _buildPasswordField(theme, isDark),
                const SizedBox(height: 12),

                // Remember Me and Forgot Password Row
                _buildRememberMeRow(theme, isDark),
              ],

              const SizedBox(height: 24),

              // Login Button
              _buildLoginButton(theme, isDark, primaryColor),
              const SizedBox(height: 20),
              //
              // // Or Divider
              // _buildOrDivider(theme, isDark),
              // const SizedBox(height: 20),
              //
              // // Social Login Buttons - More Compact
              // _buildSocialLoginButtons(theme, isDark),
              // const SizedBox(height: 20),

              // Sign Up Toggle
              if (_isOtpLogin && !_showOtpField)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      PageTransition(
                        type: PageTransitionType.rightToLeft,
                        duration: const Duration(milliseconds: 300),
                        child: const RegisterScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Don\'t have an account? Sign Up',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password Requirements:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildRequirementChip('8+ chars', _hasMinLength),
            _buildRequirementChip('A-Z', _hasUppercase),
            _buildRequirementChip('a-z', _hasLowercase),
            _buildRequirementChip('0-9', _hasDigit),
            _buildRequirementChip('!@#\$', _hasSpecialChar),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirementChip(String label, bool isMet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMet
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isMet ? Colors.green : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 12,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isMet ? Colors.green.shade700 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField(ThemeData theme, bool isDark) {
    return TextFormField(
      key: const ValueKey('email_field'),
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      validator: _validateEmail,
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'your@email.com',
        prefixIcon: const Icon(Icons.email_outlined, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildPasswordField(ThemeData theme, bool isDark) {
    return TextFormField(
      key: const ValueKey('password_field'),
      controller: _passwordController,
      obscureText: _obscurePassword,
      // validator: _validatePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildRememberMeRow(ThemeData theme, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (value) {
              setState(() {
                _rememberMe = value ?? false;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Remember me',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(ThemeData theme, bool isDark, Color primaryColor) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                _isOtpLogin && !_showOtpField 
                    ? 'Get OTP' 
                    : (_isSignUpMode ? 'Verify & Sign Up' : 'Sign In'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  Widget _buildOrDivider(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.grey[300],
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.grey[300],
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButtons(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            icon: Icons.g_mobiledata,
            label: 'Google',
            isDark: isDark,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Google sign-in coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSocialButton(
            icon: Icons.apple,
            label: 'Apple',
            isDark: isDark,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Apple sign-in coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 20,
      ),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(
          color: Colors.grey[300]!,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildPhoneField(ThemeData theme, bool isDark) {
    return TextFormField(
      key: const ValueKey('phone_field'),
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: 'Enter 10 digit number',
        counterText: '',
        prefixIcon: const Icon(Icons.phone_android, size: 20),
        prefixText: '+91 ',
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Phone number is required';
        if (value.length != 10) return 'Enter 10 digits';
        return null;
      },
    );
  }

  Widget _buildOtpField(ThemeData theme, bool isDark) {
    return TextFormField(
      key: const ValueKey('otp_field'),
      controller: _otpController,
      keyboardType: TextInputType.number,
      maxLength: 4,
      decoration: InputDecoration(
        labelText: 'OTP',
        hintText: 'Enter 4 digit OTP',
        counterText: '',
        prefixIcon: const Icon(Icons.lock_clock, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'OTP is required';
        if (value.length != 4) return 'Enter 4 digits';
        return null;
      },
    );
  }

  Widget _buildResendSection(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_timerSeconds > 0)
          Text(
            'Resend OTP in ${_timerSeconds.toString().padLeft(2, '0')}s',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          )
        else
          TextButton(
            onPressed: _isLoading ? null : _handleSendOtp,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Resend OTP',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
