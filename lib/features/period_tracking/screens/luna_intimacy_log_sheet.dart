import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/luna_theme.dart';
import '../services/period_storage_service.dart';
import '../models/symptom_log.dart';

/// Bottom sheet for logging intimacy
class LunaIntimacyLogSheet extends StatefulWidget {
  final DateTime date;
  final VoidCallback? onSaved;

  const LunaIntimacyLogSheet({
    super.key,
    required this.date,
    this.onSaved,
  });

  @override
  State<LunaIntimacyLogSheet> createState() => _LunaIntimacyLogSheetState();
}

class _LunaIntimacyLogSheetState extends State<LunaIntimacyLogSheet> {
  bool _protected = true;
  bool _highLibido = false;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveIntimacy() async {
    HapticFeedback.mediumImpact();

    // Create symptom log for intimacy tracking
    final log = SymptomLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: widget.date,
      hadIntimacy: true,
      protectedIntimacy: _protected,
      highLibido: _highLibido,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      createdAt: DateTime.now(),
    );

    await PeriodCleanStorageService.addSymptomLog(log);

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Intimacy logged'),
          backgroundColor: LunaTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LunaTheme.radius2xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: LunaTheme.spacingMd),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: LunaTheme.getDivider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(LunaTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite, color: LunaTheme.safetyRed.withOpacity(0.8)),
                    const SizedBox(width: LunaTheme.spacingSm),
                    Text(
                      'Log Intimacy',
                      style: LunaTheme.headlineMedium.copyWith(
                        color: LunaTheme.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: LunaTheme.spacingLg),

                // Protection toggle
                Container(
                  padding: const EdgeInsets.all(LunaTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: LunaTheme.primaryPinkSoft,
                    borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield, color: LunaTheme.primaryPink),
                      const SizedBox(width: LunaTheme.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Protected',
                              style: LunaTheme.titleMedium.copyWith(
                                color: LunaTheme.getTextPrimary(context),
                              ),
                            ),
                            Text(
                              'Used contraception',
                              style: LunaTheme.bodySmall.copyWith(
                                color: LunaTheme.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _protected,
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                          setState(() => _protected = value);
                        },
                        activeColor: LunaTheme.primaryPink,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: LunaTheme.spacingMd),

                // Libido toggle
                Container(
                  padding: const EdgeInsets.all(LunaTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: LunaTheme.accentPurpleLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: LunaTheme.accentPurple),
                      const SizedBox(width: LunaTheme.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'High Libido',
                              style: LunaTheme.titleMedium.copyWith(
                                color: LunaTheme.getTextPrimary(context),
                              ),
                            ),
                            Text(
                              'Track your desire levels',
                              style: LunaTheme.bodySmall.copyWith(
                                color: LunaTheme.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _highLibido,
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                          setState(() => _highLibido = value);
                        },
                        activeColor: LunaTheme.accentPurple,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: LunaTheme.spacingLg),

                // Notes
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add private notes (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
                    ),
                  ),
                ),

                const SizedBox(height: LunaTheme.spacingXl),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveIntimacy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LunaTheme.primaryPink,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
                      ),
                    ),
                    child: const Text('Save', style: TextStyle(color: Colors.white)),
                  ),
                ),

                SafeArea(
                  top: false,
                  child: Container(height: LunaTheme.spacingMd),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
