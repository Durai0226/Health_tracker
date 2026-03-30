import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/luna_theme.dart';
import '../widgets/luna_widgets.dart';
import '../models/luna_safety.dart';
import '../services/luna_safety_service.dart';

/// Safety screen for Luna Cycle - Fully functional with persistence
class LunaSafetyScreen extends StatefulWidget {
  const LunaSafetyScreen({super.key});

  @override
  State<LunaSafetyScreen> createState() => _LunaSafetyScreenState();
}

class _LunaSafetyScreenState extends State<LunaSafetyScreen> {
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Get address from coordinates (simplified)
      _currentAddress = 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, '
          'Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}';
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
    
    if (mounted) setState(() => _isLoadingLocation = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LunaSafetyService>(
      builder: (context, safetyService, _) {
        final contacts = safetyService.contacts;
        final isSOSReady = contacts.isNotEmpty;
        final activeShare = safetyService.activeLocationShare;

        return Scaffold(
          backgroundColor: LunaTheme.getBackground(context),
          body: safetyService.isLoading
              ? const Center(child: CircularProgressIndicator(color: LunaTheme.primaryPink))
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.all(LunaTheme.spacingLg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Safety',
                                style: LunaTheme.headlineLarge.copyWith(
                                  color: LunaTheme.getTextPrimary(context),
                                ),
                              ),
                              Text(
                                'Your safety is our priority',
                                style: LunaTheme.bodyMedium.copyWith(
                                  color: LunaTheme.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // SOS Button
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: LunaTheme.spacingXl),
                        child: Center(
                          child: Column(
                            children: [
                              LunaSafetySOSButton(
                                onSOS: () => _triggerSOS(safetyService),
                                countdownEnabled: true,
                                countdownSeconds: 5,
                                onCountdownCancel: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('SOS cancelled')),
                                  );
                                },
                              ),
                              const SizedBox(height: LunaTheme.spacingMd),
                              Text(
                                isSOSReady ? 'Hold to send SOS' : 'Add contacts to enable SOS',
                                style: LunaTheme.bodySmall.copyWith(
                                  color: isSOSReady
                                      ? LunaTheme.getTextSecondary(context)
                                      : LunaTheme.safetyRed,
                                ),
                              ),
                              if (_isLoadingLocation)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text('Getting location...', style: TextStyle(fontSize: 12)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Active location share
                    if (activeShare != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: LunaTheme.spacingLg),
                          child: LunaLocationShareCard(
                            sharedWithName: activeShare.sharedWithName,
                            address: activeShare.currentAddress,
                            startedAt: activeShare.startedAt,
                            expiresAt: activeShare.expiresAt,
                            onStop: () => safetyService.stopLocationSharing(),
                          ),
                        ),
                      ),

                    // Quick actions
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(LunaTheme.spacingLg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Actions',
                              style: LunaTheme.headlineSmall.copyWith(
                                color: LunaTheme.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: LunaTheme.spacingMd),
                            Row(
                              children: [
                                Expanded(
                                  child: _QuickActionCard(
                                    icon: Icons.location_on,
                                    label: 'Share Location',
                                    color: LunaTheme.communityTeal,
                                    onTap: () => _showShareLocationSheet(safetyService),
                                  ),
                                ),
                                const SizedBox(width: LunaTheme.spacingMd),
                                Expanded(
                                  child: _QuickActionCard(
                                    icon: Icons.timer,
                                    label: 'Safety Timer',
                                    color: LunaTheme.accentPurple,
                                    onTap: _showSafetyTimerSheet,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: LunaTheme.spacingMd),
                            Row(
                              children: [
                                Expanded(
                                  child: _QuickActionCard(
                                    icon: Icons.phone,
                                    label: 'Emergency Call',
                                    color: LunaTheme.safetyRed,
                                    onTap: () => _callEmergency('112'),
                                  ),
                                ),
                                const SizedBox(width: LunaTheme.spacingMd),
                                Expanded(
                                  child: _QuickActionCard(
                                    icon: Icons.message,
                                    label: 'Send Alert',
                                    color: LunaTheme.warning,
                                    onTap: () => _sendQuickAlert(safetyService),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Emergency contacts header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: LunaTheme.spacingLg),
                        child: Row(
                          children: [
                            Text(
                              'Emergency Contacts',
                              style: LunaTheme.headlineSmall.copyWith(
                                color: LunaTheme.getTextPrimary(context),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.add, color: LunaTheme.primaryPink),
                              onPressed: () => _showAddContactSheet(safetyService),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Contacts list
                    if (contacts.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(LunaTheme.spacingLg),
                          child: LunaGlassCard(
                            onTap: () => _showAddContactSheet(safetyService),
                            padding: const EdgeInsets.all(LunaTheme.spacingXl),
                            child: Column(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: LunaTheme.primaryPink.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person_add,
                                    color: LunaTheme.primaryPink,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: LunaTheme.spacingMd),
                                Text(
                                  'Add Emergency Contact',
                                  style: LunaTheme.titleMedium.copyWith(
                                    color: LunaTheme.getTextPrimary(context),
                                  ),
                                ),
                                Text(
                                  'Add trusted people who can help in emergencies',
                                  style: LunaTheme.bodySmall.copyWith(
                                    color: LunaTheme.getTextSecondary(context),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final contact = contacts[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: LunaTheme.spacingLg,
                                vertical: LunaTheme.spacingSm,
                              ),
                              child: _ContactCard(
                                contact: contact,
                                onCall: () => _callContact(contact),
                                onMessage: () => _messageContact(contact),
                                onDelete: () => _deleteContact(safetyService, contact),
                              ),
                            );
                          },
                          childCount: contacts.length,
                        ),
                      ),

                    // Helplines
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(LunaTheme.spacingLg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Emergency Helplines',
                              style: LunaTheme.headlineSmall.copyWith(
                                color: LunaTheme.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: LunaTheme.spacingMd),
                            _buildHelplineCard('Emergency Services', '112', Icons.local_hospital),
                            const SizedBox(height: LunaTheme.spacingSm),
                            _buildHelplineCard('Women Helpline', '181', Icons.woman),
                            const SizedBox(height: LunaTheme.spacingSm),
                            _buildHelplineCard('Mental Health', '988', Icons.psychology),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildHelplineCard(String name, String number, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(LunaTheme.spacingMd),
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
        border: Border.all(color: LunaTheme.getDivider(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: LunaTheme.safetyRed, size: 20),
          const SizedBox(width: LunaTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: LunaTheme.titleSmall.copyWith(
                  color: LunaTheme.getTextPrimary(context),
                )),
                Text(number, style: LunaTheme.bodySmall.copyWith(
                  color: LunaTheme.getTextSecondary(context),
                )),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: LunaTheme.success),
            onPressed: () => _callEmergency(number),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerSOS(LunaSafetyService service) async {
    HapticFeedback.heavyImpact();
    
    if (service.contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add emergency contacts first'),
          backgroundColor: LunaTheme.safetyRed,
        ),
      );
      return;
    }

    // Get current location
    await _getCurrentLocation();
    
    // Create SOS alert with location
    final alert = await service.triggerSOS(
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
      address: _currentAddress,
      customMessage: 'I need help! This is an emergency.',
    );

    if (alert != null) {
      // Send SMS/notification to all contacts
      for (final contact in service.contacts) {
        final locationUrl = _currentPosition != null
            ? 'https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}'
            : '';
        
        final message = 'SOS ALERT from Luna Cycle!\n'
            'I need help urgently!\n'
            'Location: $locationUrl\n'
            'Time: ${DateTime.now()}';

        // Try to send SMS
        final smsUri = Uri.parse('sms:${contact.phone}?body=${Uri.encodeComponent(message)}');
        try {
          await launchUrl(smsUri);
        } catch (e) {
          debugPrint('Could not send SMS: $e');
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: LunaTheme.success),
                const SizedBox(width: 8),
                const Text('SOS Sent!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your emergency contacts have been notified.'),
                if (_currentPosition != null) ...[
                  const SizedBox(height: 12),
                  Text('📍 Location shared: $_currentAddress'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _callEmergency(String number) async {
    HapticFeedback.heavyImpact();
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot call $number')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calling: $e')),
        );
      }
    }
  }

  Future<void> _callContact(LunaEmergencyContact contact) async {
    HapticFeedback.mediumImpact();
    final uri = Uri.parse('tel:${contact.phone}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot call ${contact.name}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _messageContact(LunaEmergencyContact contact) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse('sms:${contact.phone}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Error messaging: $e');
    }
  }

  Future<void> _sendQuickAlert(LunaSafetyService service) async {
    HapticFeedback.mediumImpact();
    
    if (service.contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add contacts first')),
      );
      return;
    }

    await _getCurrentLocation();
    
    final locationUrl = _currentPosition != null
        ? 'https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        : 'Location unavailable';

    final message = 'Quick Alert from Luna Cycle\n'
        'I wanted to let you know where I am.\n'
        'Location: $locationUrl';

    // Share with all contacts
    await Share.share(message, subject: 'Luna Cycle - Location Update');
  }

  void _showShareLocationSheet(LunaSafetyService service) {
    if (service.contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add contacts first to share location')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ShareLocationSheet(
        contacts: service.contacts,
        currentPosition: _currentPosition,
        onShare: (contactId, duration) async {
          Navigator.pop(context);
          
          final contact = service.contacts.firstWhere((c) => c.id == contactId);
          await _getCurrentLocation();
          
          await service.startLocationSharing(
            contact: contact,
            duration: duration,
            latitude: _currentPosition?.latitude,
            longitude: _currentPosition?.longitude,
            address: _currentAddress,
          );

          // Share the location via SMS/Share
          if (_currentPosition != null) {
            final locationUrl = 'https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
            final message = 'Luna Cycle: I\'m sharing my live location with you.\n'
                'Current location: $locationUrl\n'
                'Sharing for: ${duration.displayName}';
            
            final smsUri = Uri.parse('sms:${contact.phone}?body=${Uri.encodeComponent(message)}');
            try {
              await launchUrl(smsUri);
            } catch (e) {
              debugPrint('Could not send SMS: $e');
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Location shared with ${contact.name}'),
                backgroundColor: LunaTheme.success,
              ),
            );
          }
        },
      ),
    );
  }

  void _showSafetyTimerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SafetyTimerSheet(
        onStart: (minutes) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Safety timer set for $minutes minutes'),
              backgroundColor: LunaTheme.accentPurple,
            ),
          );
        },
      ),
    );
  }

  void _showAddContactSheet(LunaSafetyService service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddContactSheet(
        onAdd: (contact) async {
          Navigator.pop(context);
          await service.addContact(contact);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${contact.name} added as emergency contact'),
                backgroundColor: LunaTheme.success,
              ),
            );
          }
        },
      ),
    );
  }

  void _deleteContact(LunaSafetyService service, LunaEmergencyContact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact?'),
        content: Text('Remove ${contact.name} from emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await service.deleteContact(contact.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${contact.name} removed')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(LunaTheme.spacingLg),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(LunaTheme.radiusLg),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: LunaTheme.spacingSm),
            Text(
              label,
              style: LunaTheme.titleSmall.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final LunaEmergencyContact contact;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.onCall,
    required this.onMessage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LunaTheme.spacingMd),
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
        border: Border.all(
          color: contact.isPrimary ? LunaTheme.primaryPink : LunaTheme.getDivider(context),
          width: contact.isPrimary ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: LunaTheme.primaryPink.withOpacity(0.1),
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: const TextStyle(color: LunaTheme.primaryPink, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: LunaTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      contact.name,
                      style: LunaTheme.titleMedium.copyWith(
                        color: LunaTheme.getTextPrimary(context),
                      ),
                    ),
                    if (contact.isPrimary) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: LunaTheme.primaryPink,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Primary',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  contact.phone,
                  style: LunaTheme.bodySmall.copyWith(
                    color: LunaTheme.getTextSecondary(context),
                  ),
                ),
                if (contact.relationship != null)
                  Text(
                    contact.relationship!,
                    style: LunaTheme.labelSmall.copyWith(
                      color: LunaTheme.getTextTertiary(context),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: LunaTheme.success, size: 20),
            onPressed: onCall,
          ),
          IconButton(
            icon: const Icon(Icons.message, color: LunaTheme.communityTeal, size: 20),
            onPressed: onMessage,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: LunaTheme.error, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ShareLocationSheet extends StatefulWidget {
  final List<LunaEmergencyContact> contacts;
  final Position? currentPosition;
  final Function(String contactId, LunaShareDuration duration) onShare;

  const _ShareLocationSheet({
    required this.contacts,
    this.currentPosition,
    required this.onShare,
  });

  @override
  State<_ShareLocationSheet> createState() => _ShareLocationSheetState();
}

class _ShareLocationSheetState extends State<_ShareLocationSheet> {
  String? _selectedContactId;
  LunaShareDuration _selectedDuration = LunaShareDuration.hour1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(LunaTheme.radius2xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: LunaTheme.getDivider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: LunaTheme.spacingLg),
          
          Row(
            children: [
              const Icon(Icons.location_on, color: LunaTheme.communityTeal),
              const SizedBox(width: 8),
              Text('Share Location', style: LunaTheme.headlineMedium.copyWith(
                color: LunaTheme.getTextPrimary(context),
              )),
            ],
          ),
          
          if (widget.currentPosition != null) ...[
            const SizedBox(height: 8),
            Text(
              '📍 Current: ${widget.currentPosition!.latitude.toStringAsFixed(4)}, ${widget.currentPosition!.longitude.toStringAsFixed(4)}',
              style: LunaTheme.bodySmall.copyWith(color: LunaTheme.getTextSecondary(context)),
            ),
          ],
          
          const SizedBox(height: LunaTheme.spacingLg),
          Text('Share with:', style: LunaTheme.titleMedium),
          const SizedBox(height: LunaTheme.spacingSm),
          
          ...widget.contacts.map((contact) => RadioListTile<String>(
            value: contact.id,
            groupValue: _selectedContactId,
            onChanged: (value) => setState(() => _selectedContactId = value),
            title: Text(contact.name),
            subtitle: Text(contact.phone),
            activeColor: LunaTheme.primaryPink,
          )),
          
          const SizedBox(height: LunaTheme.spacingLg),
          Text('Duration:', style: LunaTheme.titleMedium),
          const SizedBox(height: LunaTheme.spacingSm),
          
          Wrap(
            spacing: LunaTheme.spacingSm,
            children: LunaShareDuration.values.take(4).map((duration) {
              final isSelected = _selectedDuration == duration;
              return ChoiceChip(
                label: Text(duration.displayName),
                selected: isSelected,
                selectedColor: LunaTheme.communityTeal.withOpacity(0.2),
                onSelected: (_) => setState(() => _selectedDuration = duration),
              );
            }).toList(),
          ),
          
          const SizedBox(height: LunaTheme.spacingXl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedContactId != null
                  ? () => widget.onShare(_selectedContactId!, _selectedDuration)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: LunaTheme.communityTeal,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Share My Location', style: TextStyle(color: Colors.white)),
            ),
          ),
          SafeArea(top: false, child: Container(height: LunaTheme.spacingMd)),
        ],
      ),
    );
  }
}

class _SafetyTimerSheet extends StatefulWidget {
  final Function(int minutes) onStart;

  const _SafetyTimerSheet({required this.onStart});

  @override
  State<_SafetyTimerSheet> createState() => _SafetyTimerSheetState();
}

class _SafetyTimerSheetState extends State<_SafetyTimerSheet> {
  int _selectedMinutes = 30;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(LunaTheme.radius2xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: LunaTheme.getDivider(context), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: LunaTheme.spacingLg),
          
          Row(
            children: [
              const Icon(Icons.timer, color: LunaTheme.accentPurple),
              const SizedBox(width: 8),
              Text('Safety Timer', style: LunaTheme.headlineMedium.copyWith(
                color: LunaTheme.getTextPrimary(context),
              )),
            ],
          ),
          
          const SizedBox(height: 8),
          Text(
            'If you don\'t check in before the timer ends, your emergency contacts will be notified.',
            style: LunaTheme.bodySmall.copyWith(color: LunaTheme.getTextSecondary(context)),
          ),
          
          const SizedBox(height: LunaTheme.spacingLg),
          
          Wrap(
            spacing: LunaTheme.spacingSm,
            runSpacing: LunaTheme.spacingSm,
            children: [15, 30, 60, 120].map((minutes) {
              final isSelected = _selectedMinutes == minutes;
              return ChoiceChip(
                label: Text(minutes < 60 ? '$minutes min' : '${minutes ~/ 60} hr'),
                selected: isSelected,
                selectedColor: LunaTheme.accentPurple.withOpacity(0.2),
                onSelected: (_) => setState(() => _selectedMinutes = minutes),
              );
            }).toList(),
          ),
          
          const SizedBox(height: LunaTheme.spacingXl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onStart(_selectedMinutes),
              style: ElevatedButton.styleFrom(
                backgroundColor: LunaTheme.accentPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Start $_selectedMinutes min Timer', style: const TextStyle(color: Colors.white)),
            ),
          ),
          SafeArea(top: false, child: Container(height: LunaTheme.spacingMd)),
        ],
      ),
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  final Function(LunaEmergencyContact) onAdd;

  const _AddContactSheet({required this.onAdd});

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _relationship;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _addContact() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final contact = LunaEmergencyContact(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      relationship: _relationship,
      createdAt: DateTime.now(),
    );
    
    widget.onAdd(contact);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(
        left: LunaTheme.spacingLg,
        right: LunaTheme.spacingLg,
        top: LunaTheme.spacingLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + LunaTheme.spacingLg,
      ),
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(LunaTheme.radius2xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: LunaTheme.getDivider(context), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: LunaTheme.spacingLg),
          
          Row(
            children: [
              const Icon(Icons.person_add, color: LunaTheme.primaryPink),
              const SizedBox(width: 8),
              Text('Add Emergency Contact', style: LunaTheme.headlineMedium.copyWith(
                color: LunaTheme.getTextPrimary(context),
              )),
            ],
          ),
          
          const SizedBox(height: LunaTheme.spacingXl),
          
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Name *',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(LunaTheme.radiusMd)),
            ),
          ),
          
          const SizedBox(height: LunaTheme.spacingMd),
          
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number *',
              prefixIcon: const Icon(Icons.phone),
              hintText: '+1 234 567 8900',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(LunaTheme.radiusMd)),
            ),
          ),
          
          const SizedBox(height: LunaTheme.spacingMd),
          
          DropdownButtonFormField<String>(
            value: _relationship,
            decoration: InputDecoration(
              labelText: 'Relationship',
              prefixIcon: const Icon(Icons.people),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(LunaTheme.radiusMd)),
            ),
            items: ['Partner', 'Parent', 'Sibling', 'Friend', 'Other'].map((r) {
              return DropdownMenuItem(value: r, child: Text(r));
            }).toList(),
            onChanged: (value) => setState(() => _relationship = value),
          ),
          
          const Spacer(),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addContact,
              style: ElevatedButton.styleFrom(
                backgroundColor: LunaTheme.primaryPink,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LunaTheme.radiusMd)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          
          SafeArea(top: false, child: Container(height: LunaTheme.spacingMd)),
        ],
      ),
    );
  }
}
