import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/flo_theme.dart';
import '../models/cycle_log.dart';
import 'flo_glass_card.dart';

/// Bottom sheet for quick period logging
class FloQuickLogSheet extends StatefulWidget {
  final DateTime? initialDate;
  final Function(DateTime startDate, FlowIntensity? flow)? onLogPeriod;
  final VoidCallback? onLogSymptoms;

  const FloQuickLogSheet({
    super.key,
    this.initialDate,
    this.onLogPeriod,
    this.onLogSymptoms,
  });

  static Future<void> show(
    BuildContext context, {
    DateTime? initialDate,
    Function(DateTime startDate, FlowIntensity? flow)? onLogPeriod,
    VoidCallback? onLogSymptoms,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FloQuickLogSheet(
        initialDate: initialDate,
        onLogPeriod: onLogPeriod,
        onLogSymptoms: onLogSymptoms,
      ),
    );
  }

  @override
  State<FloQuickLogSheet> createState() => _FloQuickLogSheetState();
}

class _FloQuickLogSheetState extends State<FloQuickLogSheet> {
  late DateTime _selectedDate;
  FlowIntensity? _selectedFlow;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: BoxDecoration(
        color: FloTheme.getSurface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(FloTheme.radius2xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(FloTheme.spacing2xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FloTheme.getDivider(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: FloTheme.spacing2xl),

              // Title
              Text(
                'Quick Log',
                style: FloTheme.headlineLarge.copyWith(
                  color: FloTheme.getTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: FloTheme.spacing2xl),

              // Log Period option
              _LogOption(
                icon: Icons.water_drop_rounded,
                iconColor: FloTheme.periodPink,
                title: 'Log Period Start',
                subtitle: 'Start a new cycle',
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showPeriodLogDialog();
                },
              ),

              const SizedBox(height: FloTheme.spacingMd),

              // Log Symptoms option
              _LogOption(
                icon: Icons.favorite_rounded,
                iconColor: Colors.purple,
                title: 'Log Symptoms & Mood',
                subtitle: 'Track how you feel',
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  widget.onLogSymptoms?.call();
                },
              ),

              const SizedBox(height: FloTheme.spacingMd),

              // Log Intimacy option
              _LogOption(
                icon: Icons.nights_stay_rounded,
                iconColor: FloTheme.ovulationBlue,
                title: 'Log Intimacy',
                subtitle: 'Record intimate moments',
                onTap: () {
                  HapticFeedback.selectionClick();
                  // TODO: Navigate to intimacy log
                  Navigator.pop(context);
                },
              ),

              const SizedBox(height: FloTheme.spacing2xl),
            ],
          ),
        ),
      ),
    );
  }

  void _showPeriodLogDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: FloTheme.getSurface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FloTheme.radiusXl),
          ),
          title: Text(
            'Log Period Start',
            style: FloTheme.headlineMedium.copyWith(
              color: FloTheme.getTextPrimary(context),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date picker
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 60)),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setDialogState(() => _selectedDate = date);
                    setState(() {});
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(FloTheme.spacingLg),
                  decoration: BoxDecoration(
                    color: FloTheme.periodPinkLight,
                    borderRadius: BorderRadius.circular(FloTheme.radiusMd),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(_selectedDate),
                        style: FloTheme.bodyLarge.copyWith(
                          color: FloTheme.periodPink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_rounded,
                        color: FloTheme.periodPink,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: FloTheme.spacingLg),

              // Flow intensity
              Text(
                'Flow Intensity (optional)',
                style: FloTheme.bodyMedium.copyWith(
                  color: FloTheme.getTextSecondary(context),
                ),
              ),

              const SizedBox(height: FloTheme.spacingSm),

              Wrap(
                spacing: FloTheme.spacingSm,
                children: FlowIntensity.values.map((flow) {
                  final isSelected = _selectedFlow == flow;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => _selectedFlow = flow);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FloTheme.spacingMd,
                        vertical: FloTheme.spacingSm,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? FloTheme.periodPink
                            : FloTheme.periodPinkLight,
                        borderRadius: BorderRadius.circular(FloTheme.radiusFull),
                      ),
                      child: Text(
                        _getFlowName(flow),
                        style: FloTheme.labelSmall.copyWith(
                          color: isSelected ? Colors.white : FloTheme.periodPink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: FloTheme.getTextSecondary(context)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close bottom sheet
                widget.onLogPeriod?.call(_selectedDate, _selectedFlow);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FloTheme.periodPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FloTheme.radiusMd),
                ),
              ),
              child: const Text('Log'),
            ),
          ],
        ),
      ),
    );
  }

  String _getFlowName(FlowIntensity flow) {
    switch (flow) {
      case FlowIntensity.spotting:
        return 'Spotting';
      case FlowIntensity.light:
        return 'Light';
      case FlowIntensity.medium:
        return 'Medium';
      case FlowIntensity.heavy:
        return 'Heavy';
      case FlowIntensity.veryHeavy:
        return 'Very Heavy';
    }
  }
}

class _LogOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LogOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FloGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(FloTheme.spacingMd),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: FloTheme.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FloTheme.titleLarge.copyWith(
                    color: FloTheme.getTextPrimary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: FloTheme.bodySmall.copyWith(
                    color: FloTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: FloTheme.getTextSecondary(context),
          ),
        ],
      ),
    );
  }
}

/// Period end confirmation sheet
class FloEndPeriodSheet extends StatelessWidget {
  final DateTime startDate;
  final Function(DateTime endDate)? onConfirm;

  const FloEndPeriodSheet({
    super.key,
    required this.startDate,
    this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime startDate,
    Function(DateTime endDate)? onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => FloEndPeriodSheet(
        startDate: startDate,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final duration = today.difference(startDate).inDays + 1;

    return Container(
      decoration: BoxDecoration(
        color: FloTheme.getSurface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(FloTheme.radius2xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(FloTheme.spacing2xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FloTheme.getDivider(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: FloTheme.spacing2xl),

              Icon(
                Icons.check_circle_rounded,
                color: FloTheme.periodPink,
                size: 64,
              ),

              const SizedBox(height: FloTheme.spacingLg),

              Text(
                'End Period?',
                style: FloTheme.headlineLarge.copyWith(
                  color: FloTheme.getTextPrimary(context),
                ),
              ),

              const SizedBox(height: FloTheme.spacingSm),

              Text(
                'Your period lasted $duration days\n(${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(today)})',
                style: FloTheme.bodyMedium.copyWith(
                  color: FloTheme.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: FloTheme.spacing2xl),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: FloTheme.getDivider(context)),
                        padding: const EdgeInsets.symmetric(vertical: FloTheme.spacingLg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FloTheme.radiusMd),
                        ),
                      ),
                      child: Text(
                        'Not Yet',
                        style: TextStyle(color: FloTheme.getTextPrimary(context)),
                      ),
                    ),
                  ),
                  const SizedBox(width: FloTheme.spacingMd),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm?.call(today);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FloTheme.periodPink,
                        padding: const EdgeInsets.symmetric(vertical: FloTheme.spacingLg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FloTheme.radiusMd),
                        ),
                      ),
                      child: const Text('End Period'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
