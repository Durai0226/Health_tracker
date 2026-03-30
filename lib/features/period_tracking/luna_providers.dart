import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/luna_safety_service.dart';
import 'services/luna_community_service.dart';
import 'services/period_storage_service.dart';

/// Provider wrapper for Luna Cycle services
/// Initializes and provides all services needed for the Luna Cycle feature
class LunaProviders extends StatefulWidget {
  final Widget child;

  const LunaProviders({super.key, required this.child});

  @override
  State<LunaProviders> createState() => _LunaProvidersState();
}

class _LunaProvidersState extends State<LunaProviders> {
  late final LunaSafetyService _safetyService;
  late final LunaCommunityService _communityService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _safetyService = LunaSafetyService();
    _communityService = LunaCommunityService();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize period storage first
    await PeriodCleanStorageService.init();
    
    // Initialize other services
    await _safetyService.initialize();
    await _communityService.initialize();
    
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _safetyService),
        ChangeNotifierProvider.value(value: _communityService),
      ],
      child: widget.child,
    );
  }
}
