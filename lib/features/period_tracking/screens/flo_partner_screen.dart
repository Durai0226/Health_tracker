import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/flo_theme.dart';
import '../widgets/widgets.dart';
import '../models/partner_profile.dart';

/// Partner sharing and management screen
class FloPartnerScreen extends StatefulWidget {
  const FloPartnerScreen({super.key});

  @override
  State<FloPartnerScreen> createState() => _FloPartnerScreenState();
}

class _FloPartnerScreenState extends State<FloPartnerScreen> {
  PartnerProfile? _partner;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPartner();
  }

  void _loadPartner() {
    // TODO: Load partner from storage
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FloTheme.getBackground(context),
      appBar: FloAppBar(
        title: 'Partner',
        actions: [
          if (_partner != null)
            IconButton(
              onPressed: _showPartnerSettings,
              icon: Icon(
                Icons.settings_rounded,
                color: FloTheme.getTextPrimary(context),
              ),
            ),
        ],
      ),
      body: _partner == null ? _buildNoPartner() : _buildPartnerView(),
    );
  }

  Widget _buildNoPartner() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Column(
        children: [
          const SizedBox(height: FloTheme.spacing4xl),

          // Illustration
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: FloTheme.periodPinkLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.people_rounded,
                size: 80,
                color: FloTheme.periodPink,
              ),
            ),
          ),

          const SizedBox(height: FloTheme.spacing2xl),

          Text(
            'Share with your Partner',
            style: FloTheme.headlineLarge.copyWith(
              color: FloTheme.getTextPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: FloTheme.spacingMd),

          Text(
            'Let your partner stay informed about your cycle. They\'ll be able to see your current phase and important dates.',
            style: FloTheme.bodyMedium.copyWith(
              color: FloTheme.getTextSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: FloTheme.spacing3xl),

          // Benefits
          _buildBenefitCard(
            icon: Icons.visibility_rounded,
            title: 'Cycle Awareness',
            description: 'Your partner can understand your current phase',
          ),
          const SizedBox(height: FloTheme.spacingMd),
          _buildBenefitCard(
            icon: Icons.notifications_rounded,
            title: 'Smart Reminders',
            description: 'Get notified about important dates together',
          ),
          const SizedBox(height: FloTheme.spacingMd),
          _buildBenefitCard(
            icon: Icons.lock_rounded,
            title: 'Privacy Controls',
            description: 'You control exactly what they can see',
          ),

          const SizedBox(height: FloTheme.spacing3xl),

          // Invite button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _invitePartner,
              style: ElevatedButton.styleFrom(
                backgroundColor: FloTheme.periodPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: FloTheme.spacingLg,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FloTheme.radiusMd),
                ),
              ),
              child: const Text(
                'Invite Partner',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: FloTheme.spacingMd),

          // Link existing
          TextButton(
            onPressed: _enterInviteCode,
            child: Text(
              'I have an invite code',
              style: FloTheme.bodyMedium.copyWith(
                color: FloTheme.periodPink,
              ),
            ),
          ),

          const SizedBox(height: FloTheme.spacing4xl),
        ],
      ),
    );
  }

  Widget _buildBenefitCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(FloTheme.spacingMd),
            decoration: BoxDecoration(
              color: FloTheme.periodPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(FloTheme.radiusMd),
            ),
            child: Icon(icon, color: FloTheme.periodPink),
          ),
          const SizedBox(width: FloTheme.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FloTheme.titleMedium.copyWith(
                    color: FloTheme.getTextPrimary(context),
                  ),
                ),
                Text(
                  description,
                  style: FloTheme.bodySmall.copyWith(
                    color: FloTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Column(
        children: [
          // Partner info card
          FloGlassCard(
            padding: const EdgeInsets.all(FloTheme.spacingLg),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: FloTheme.periodPinkLight,
                    shape: BoxShape.circle,
                  ),
                  child: _partner?.photoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            _partner!.photoUrl!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          color: FloTheme.periodPink,
                          size: 32,
                        ),
                ),
                const SizedBox(width: FloTheme.spacingLg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _partner?.name ?? 'Partner',
                        style: FloTheme.headlineSmall.copyWith(
                          color: FloTheme.getTextPrimary(context),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _partner?.isLinked == true
                                  ? Colors.green
                                  : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _partner?.isLinked == true ? 'Connected' : 'Pending',
                            style: FloTheme.bodySmall.copyWith(
                              color: FloTheme.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: FloTheme.spacing2xl),

          // Privacy settings
          Text(
            'What can your partner see?',
            style: FloTheme.headlineSmall.copyWith(
              color: FloTheme.getTextPrimary(context),
            ),
          ),

          const SizedBox(height: FloTheme.spacingLg),

          _buildPermissionToggle(
            'Cycle Phase',
            'Current phase of your cycle',
            _partner?.permissions.viewCyclePhase ?? true,
            (value) => _updatePermission('viewCyclePhase', value),
          ),
          _buildPermissionToggle(
            'Period Dates',
            'When your period starts and ends',
            _partner?.permissions.viewPeriodDates ?? true,
            (value) => _updatePermission('viewPeriodDates', value),
          ),
          _buildPermissionToggle(
            'Fertile Window',
            'Your fertile days and ovulation',
            _partner?.permissions.viewFertileWindow ?? true,
            (value) => _updatePermission('viewFertileWindow', value),
          ),
          _buildPermissionToggle(
            'Symptoms',
            'Your logged symptoms',
            _partner?.permissions.viewSymptoms ?? false,
            (value) => _updatePermission('viewSymptoms', value),
          ),
          _buildPermissionToggle(
            'Mood',
            'Your mood entries',
            _partner?.permissions.viewMood ?? false,
            (value) => _updatePermission('viewMood', value),
          ),

          const SizedBox(height: FloTheme.spacing2xl),

          // Remove partner
          TextButton(
            onPressed: _removePartner,
            child: Text(
              'Remove Partner',
              style: FloTheme.bodyMedium.copyWith(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionToggle(
    String title,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return FloGlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: FloTheme.spacingLg,
        vertical: FloTheme.spacingMd,
      ),
      margin: const EdgeInsets.only(bottom: FloTheme.spacingSm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FloTheme.titleMedium.copyWith(
                    color: FloTheme.getTextPrimary(context),
                  ),
                ),
                Text(
                  description,
                  style: FloTheme.bodySmall.copyWith(
                    color: FloTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: FloTheme.periodPink,
          ),
        ],
      ),
    );
  }

  void _invitePartner() {
    final inviteCode = PartnerProfile.generateInviteCode();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: FloTheme.getSurface(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(FloTheme.radius2xl),
          ),
        ),
        padding: const EdgeInsets.all(FloTheme.spacing2xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share this code with your partner',
              style: FloTheme.headlineSmall.copyWith(
                color: FloTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: FloTheme.spacing2xl),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: inviteCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied!')),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(FloTheme.spacingXl),
                decoration: BoxDecoration(
                  color: FloTheme.periodPinkLight,
                  borderRadius: BorderRadius.circular(FloTheme.radiusMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      inviteCode,
                      style: FloTheme.headlineLarge.copyWith(
                        color: FloTheme.periodPink,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: FloTheme.spacingMd),
                    Icon(Icons.copy_rounded, color: FloTheme.periodPink),
                  ],
                ),
              ),
            ),
            const SizedBox(height: FloTheme.spacingLg),
            Text(
              'This code expires in 24 hours',
              style: FloTheme.bodySmall.copyWith(
                color: FloTheme.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: FloTheme.spacing2xl),
          ],
        ),
      ),
    );
  }

  void _enterInviteCode() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FloTheme.getSurface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FloTheme.radiusXl),
        ),
        title: Text(
          'Enter Invite Code',
          style: FloTheme.headlineMedium.copyWith(
            color: FloTheme.getTextPrimary(context),
          ),
        ),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'FLO-XXXXXX',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FloTheme.radiusMd),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Validate and link partner
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FloTheme.periodPink,
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showPartnerSettings() {
    // TODO: Show partner settings
  }

  void _updatePermission(String key, bool value) {
    // TODO: Update permission
    setState(() {});
  }

  void _removePartner() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Partner?'),
        content: const Text(
          'Your partner will no longer be able to see your cycle information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _partner = null);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
