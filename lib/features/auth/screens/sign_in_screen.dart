
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import 'sign_up_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();

    // Check if already logged in
    if (_authService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _signIn() async {
    if (_emailController.text.isEmpty) {
      _showError("Please enter your email");
      return;
    }

    setState(() => _isLoading = true);

    // Mock sign in with email
    final success = await _authService.mockSignIn(
      _emailController.text.split('@').first,
      _emailController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    final success = await _authService.signInWithGoogle();

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        _showError("Google Sign In failed. Please try again.");
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 48),
                    // Premium Header Icon
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(Icons.medication_rounded, size: 44, color: Colors.white),
                      ),
                    ),
                    SizedBox(height: 24),
                    Center(
                      child: Text(
                        "Remedly",
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(height: 48),
                    // Welcome Text
                    Text(
                      "Welcome Back",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Sign in to continue managing your health",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 40),
                    // Email Field
                    _buildInputField(
                      controller: _emailController,
                      label: "Email",
                      hint: "you@example.com",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 20),
                    // Password Field
                    _buildInputField(
                      controller: _passwordController,
                      label: "Password",
                      hint: "Enter your password",
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    SizedBox(height: 8),
                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        child: Text(
                          "Forgot Password?",
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    // Sign In Button - Premium Design
                    _buildPrimaryButton(
                      onPressed: _isLoading ? null : _signIn,
                      label: "Sign In",
                    ),
                    SizedBox(height: 32),
                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            "or continue with",
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
                      ],
                    ),
                    SizedBox(height: 24),
                    // Social Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildSocialButton(
                            icon: Icons.g_mobiledata_rounded,
                            label: "Google",
                            onTap: _isLoading ? null : _signInWithGoogle,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildSocialButton(
                            icon: Icons.apple_rounded,
                            label: "Apple",
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 48),
                    // Sign Up Link
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SignUpScreen()),
                              );
                            },
                            child: Text(
                              "Sign Up",
                              style: GoogleFonts.inter(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Signing in...",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: AppColors.textLight,
                fontSize: 15,
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 16, right: 12),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 50),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: AppColors.textPrimary),
              SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
