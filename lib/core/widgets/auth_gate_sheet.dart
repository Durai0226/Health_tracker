import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';

/// Authentication gate bottom sheet shown when guest users access features
/// Offers options to continue as guest or sign in with Google
class AuthGateSheet extends StatefulWidget {
  final String featureName;
  final Color featureColor;
  final IconData featureIcon;
  final VoidCallback onContinueAsGuest;
  final VoidCallback onSignedIn;

  const AuthGateSheet({
    super.key,
    required this.featureName,
    required this.featureColor,
    required this.featureIcon,
    required this.onContinueAsGuest,
    required this.onSignedIn,
  });

  /// Show the auth gate sheet and return true if user authenticated/continued
  static Future<bool> show({
    required BuildContext context,
    required String featureName,
    required Color featureColor,
    required IconData featureIcon,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => AuthGateSheet(
        featureName: featureName,
        featureColor: featureColor,
        featureIcon: featureIcon,
        onContinueAsGuest: () => Navigator.pop(context, true),
        onSignedIn: () => Navigator.pop(context, true),
      ),
    );
    return result ?? false;
  }

  @override
  State<AuthGateSheet> createState() => _AuthGateSheetState();
}

class _AuthGateSheetState extends State<AuthGateSheet>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final HapticService _hapticService = HapticService();
  
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    _hapticService.selection();
    
    try {
      final result = await _authService.signInWithGoogle();
      
      if (result == null) {
        // Success
        _hapticService.success();
        if (mounted) {
          widget.onSignedIn();
        }
      } else if (result != 'cancelled') {
        // Error
        setState(() {
          _error = result;
          _isLoading = false;
        });
      } else {
        // Cancelled
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _error = 'Sign in failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _handleContinueAsGuest() {
    _hapticService.selection();
    widget.onContinueAsGuest();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.8)
                    : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: widget.featureColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.featureColor.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  _buildHeader(isDark),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        // Feature info
                        _buildFeatureInfo(isDark),
                        
                        const SizedBox(height: 24),
                        
                        // Sign in with Google button
                        _buildGoogleSignInButton(isDark),
                        
                        const SizedBox(height: 12),
                        
                        // Divider with "or"
                        _buildDivider(isDark),
                        
                        const SizedBox(height: 12),
                        
                        // Continue as guest button
                        _buildGuestButton(isDark),
                        
                        // Error message
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          _buildErrorMessage(),
                        ],
                        
                        const SizedBox(height: 16),
                        
                        // Guest limitations note
                        _buildGuestNote(isDark),
                      ],
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

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.featureColor.withOpacity(0.15),
            widget.featureColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.featureColor, widget.featureColor.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: widget.featureColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              widget.featureIcon,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                Text(
                  widget.featureName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: Icon(
              Icons.close_rounded,
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: widget.featureColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sign in to sync your data across devices and unlock all features.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton(bool isDark) {
    return GestureDetector(
      onTap: _isLoading ? null : _handleGoogleSignIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: widget.featureColor,
                ),
              )
            else ...[
              Image.network(
                'https://www.google.com/favicon.ico',
                width: 24,
                height: 24,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.g_mobiledata_rounded,
                  color: Colors.red[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Sign in with Google',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.getBorder(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.getBorder(context),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestButton(bool isDark) {
    return GestureDetector(
      onTap: _handleContinueAsGuest,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.getBorder(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline_rounded,
              color: AppColors.getTextSecondary(context),
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Continue as Guest',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestNote(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 16,
          color: AppColors.getTextSecondary(context).withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Text(
          'Guest data is stored locally only',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.getTextSecondary(context).withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
