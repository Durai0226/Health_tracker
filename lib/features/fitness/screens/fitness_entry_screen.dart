import 'package:flutter/material.dart';
import '../services/fitness_storage_service.dart';
import 'fitness_main_screen.dart';
import 'onboarding/fitness_onboarding_screen.dart';

/// Entry point for Fitness feature
/// Handles onboarding check for ALL users (guests and logged-in)
/// Shows onboarding on first launch, stores preferences locally
class FitnessEntryScreen extends StatefulWidget {
  const FitnessEntryScreen({super.key});

  @override
  State<FitnessEntryScreen> createState() => _FitnessEntryScreenState();
}

class _FitnessEntryScreenState extends State<FitnessEntryScreen> {
  final FitnessStorageService _storageService = FitnessStorageService();
  bool _isLoading = true;
  bool _shouldShowOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    // Check if ANY user (guest or logged-in) has completed onboarding
    // Profile is stored locally via SharedPreferences
    final profile = await _storageService.getProfile();
    
    if (mounted) {
      if (profile.hasCompletedOnboarding) {
        // Already completed - go to main screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FitnessMainScreen()),
        );
      } else {
        // Not completed - show onboarding for ALL users
        setState(() {
          _shouldShowOnboarding = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFCDFF00),
          ),
        ),
      );
    }

    if (_shouldShowOnboarding) {
      return const FitnessOnboardingScreen();
    }

    return const FitnessMainScreen();
  }
}
