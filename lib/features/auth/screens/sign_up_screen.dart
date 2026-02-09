
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import 'sign_in_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _signUp() {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please agree to the Terms & Conditions"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    // Simulate loading
    Future.delayed(Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.favorite_rounded, color: AppColors.primary, size: 32),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Remedly",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Your complete health companion",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                // Feature Highlights
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildFeatureItem(Icons.medication_rounded, "Medicine reminders"),
                      _buildFeatureItem(Icons.access_alarm_rounded, "Timely alerts"),
                      _buildFeatureItem(Icons.monitor_heart_rounded, "Sugar & pressure checks"),
                      _buildFeatureItem(Icons.water_drop_rounded, "Period tracking"),
                      _buildFeatureItem(Icons.calendar_month_rounded, "Daily health routine"),
                    ],
                  ),
                ),
                SizedBox(height: 32),

                Text(
                  "Create Account",
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                SizedBox(height: 8),
                Text(
                  "Start your health journey today",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 40),
                // Name Field
                _buildInputField(
                  controller: _nameController,
                  label: "Full Name",
                  hint: "John Doe",
                  icon: Icons.person_outline_rounded,
                ),
                SizedBox(height: 20),
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
                  hint: "Create a strong password",
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                SizedBox(height: 8),
                // Password Strength Indicator
                _buildPasswordStrength(),
                SizedBox(height: 24),
                // Terms Checkbox
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _agreeToTerms ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _agreeToTerms ? AppColors.primary : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: _agreeToTerms
                            ? Icon(Icons.check_rounded, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: "I agree to the ",
                          style: TextStyle(color: AppColors.textSecondary),
                          children: [
                            TextSpan(
                              text: "Terms & Conditions",
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32),
                // Sign Up Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text("Create Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(height: 24),
                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.divider)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("or", style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    Expanded(child: Divider(color: AppColors.divider)),
                  ],
                ),
                SizedBox(height: 24),
                // Social Buttons
                _buildSocialButton(
                  icon: Icons.g_mobiledata_rounded,
                  label: "Sign up with Google",
                  onTap: () {},
                ),
                SizedBox(height: 12),
                _buildSocialButton(
                  icon: Icons.apple_rounded,
                  label: "Sign up with Apple",
                  onTap: () {},
                ),
                SizedBox(height: 32),
                // Sign In Link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account? ", style: TextStyle(color: AppColors.textSecondary)),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text(
                          "Sign In",
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],
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
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: AppColors.primary),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrength() {
    final password = _passwordController.text;
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    final colors = [AppColors.error, AppColors.warning, AppColors.info, AppColors.success];
    final labels = ["Weak", "Fair", "Good", "Strong"];

    return Row(
      children: [
        ...List.generate(4, (index) {
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
              decoration: BoxDecoration(
                color: index < strength ? colors[strength - 1] : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
        SizedBox(width: 12),
        Text(
          password.isEmpty ? "" : labels[strength > 0 ? strength - 1 : 0],
          style: TextStyle(
            fontSize: 12,
            color: strength > 0 ? colors[strength - 1] : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: AppColors.textPrimary),
            SizedBox(width: 12),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
