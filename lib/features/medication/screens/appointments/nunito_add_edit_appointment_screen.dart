import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/doctor_pharmacy.dart';
import '../../services/medicine_storage_service.dart';

/// Presets for [Appointment.reminderMinutesBefore] — common lead times a
/// reminder-before-an-appointment picker offers, matching the granularity
/// medication/vitals reminders already use elsewhere in this app.
const List<int> _reminderPresetMinutes = [15, 30, 60, 120, 1440];

// Kept compact (no space) since SegmentedToggle gives 5 items an equal,
// narrow share of the row on a typical phone width.
String _reminderPresetLabel(int minutes) {
  if (minutes < 60) return '${minutes}min';
  if (minutes < 1440) return '${minutes ~/ 60}hr';
  return '${minutes ~/ 1440}day';
}

class NunitoAddEditAppointmentScreen extends StatefulWidget {
  final Appointment? editAppointment;

  const NunitoAddEditAppointmentScreen({super.key, this.editAppointment});

  @override
  State<NunitoAddEditAppointmentScreen> createState() =>
      _NunitoAddEditAppointmentScreenState();
}

class _NunitoAddEditAppointmentScreenState
    extends State<NunitoAddEditAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _doctorNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  bool _reminderEnabled = true;
  int _reminderMinutesBefore = 60;
  bool _isCompleted = false;

  final HapticService _hapticService = HapticService();

  bool get _isEditing => widget.editAppointment != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editAppointment;
    if (e != null) {
      _doctorNameController.text = e.doctorName;
      _locationController.text = e.location ?? '';
      _notesController.text = e.notes ?? '';
      _date = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      _time = TimeOfDay(hour: e.dateTime.hour, minute: e.dateTime.minute);
      _reminderEnabled = e.reminderEnabled;
      _reminderMinutesBefore = e.reminderMinutesBefore;
      _isCompleted = e.isCompleted;
    } else {
      final now = DateTime.now().add(const Duration(hours: 1));
      _date = DateTime(now.year, now.month, now.day);
      _time = TimeOfDay(hour: now.hour, minute: 0);
    }
  }

  @override
  void dispose() {
    _doctorNameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime get _combinedDateTime =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate(AccentSwatch accent) async {
    final picked = await AppDatePicker.show(
      context,
      initial: _date,
      first: DateTime.now().subtract(const Duration(days: 365)),
      accent: accent,
      title: 'Appointment date',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(AccentSwatch accent) async {
    final picked = await AppTimePicker.show(
      context,
      initial: _time,
      accent: accent,
      minuteInterval: 5,
      title: 'Appointment time',
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final appointment = Appointment(
        id: _isEditing ? widget.editAppointment!.id : const Uuid().v4(),
        doctorId: widget.editAppointment?.doctorId,
        doctorName: _doctorNameController.text.trim(),
        dateTime: _combinedDateTime,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        reminderEnabled: _reminderEnabled,
        reminderMinutesBefore: _reminderMinutesBefore,
        isCompleted: _isCompleted,
        dependentId: widget.editAppointment?.dependentId,
        medicineIds: widget.editAppointment?.medicineIds,
      );

      if (_isEditing) {
        await MedicineCleanStorageService.updateAppointment(appointment);
      } else {
        await MedicineCleanStorageService.addAppointment(appointment);
      }
      _hapticService.success();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error saving appointment: $e');
      _hapticService.error();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: _isEditing ? 'Edit appointment' : 'Add appointment',
              accent: accent,
              leading: AppIconButton(
                icon: Symbols.close_rounded,
                filled: false,
                accent: accent,
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                AppButton(
                  label: 'Save',
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.tonal,
                  accent: accent,
                  loading: _isSaving,
                  onPressed: _isSaving ? null : _save,
                ),
              ],
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 40),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'Details',
                            icon: Symbols.event_rounded,
                            accent: accent,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            controller: _doctorNameController,
                            label: 'Doctor / reason',
                            hint: 'e.g. Dr. Patel — cardiology follow-up',
                            prefixIcon: Symbols.person_rounded,
                            accent: accent,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'This field is required'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _locationController,
                            label: 'Location',
                            hint: 'Clinic or address (optional)',
                            prefixIcon: Symbols.location_on_rounded,
                            accent: accent,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'When',
                            icon: Symbols.schedule_rounded,
                            accent: accent,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: _FieldRow(
                                  icon: Symbols.calendar_month_rounded,
                                  label: 'Date',
                                  value: _formatDate(_date),
                                  accent: accent,
                                  onTap: () => _pickDate(accent),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _FieldRow(
                                  icon: Symbols.schedule_rounded,
                                  label: 'Time',
                                  value: _time.format(context),
                                  accent: accent,
                                  onTap: () => _pickTime(accent),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accent.container,
                                  borderRadius: AppRadius.brSm,
                                ),
                                child: Icon(Symbols.notifications_rounded,
                                    color: accent.onContainer, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text('Reminder',
                                    style: tt.titleLarge
                                        ?.copyWith(color: ext.textPrimary)),
                              ),
                              AppSwitch(
                                value: _reminderEnabled,
                                onChanged: (v) {
                                  _hapticService.toggle();
                                  setState(() => _reminderEnabled = v);
                                },
                                accent: accent,
                              ),
                            ],
                          ),
                          if (_reminderEnabled) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text('Remind me before',
                                style: tt.bodyMedium
                                    ?.copyWith(color: ext.textSecondary)),
                            const SizedBox(height: AppSpacing.sm),
                            SegmentedToggle(
                              items: _reminderPresetMinutes
                                  .map((m) => SegmentItem(label: _reminderPresetLabel(m)))
                                  .toList(),
                              index: _reminderPresetMinutes
                                  .indexOf(_reminderMinutesBefore)
                                  .clamp(0, _reminderPresetMinutes.length - 1),
                              accent: accent,
                              onChanged: (i) {
                                _hapticService.light();
                                setState(() =>
                                    _reminderMinutesBefore = _reminderPresetMinutes[i]);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'Notes',
                            icon: Symbols.notes_rounded,
                            accent: accent,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            controller: _notesController,
                            label: 'Notes',
                            hint: 'Questions to ask, things to bring…',
                            prefixIcon: Symbols.sticky_note_2_rounded,
                            accent: accent,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                      ),
                    ),

                    if (_isEditing) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        onTap: () {
                          _hapticService.toggle();
                          setState(() => _isCompleted = !_isCompleted);
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ext.success.container,
                                borderRadius: AppRadius.brSm,
                              ),
                              child: Icon(Symbols.check_circle_rounded,
                                  color: ext.success.onContainer, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text('Mark as done',
                                  style: tt.titleLarge
                                      ?.copyWith(color: ext.textPrimary)),
                            ),
                            AppSwitch(
                              value: _isCompleted,
                              onChanged: (v) {
                                _hapticService.toggle();
                                setState(() => _isCompleted = v);
                              },
                              accent: accent,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: _isEditing ? 'Save changes' : 'Add appointment',
                      accent: accent,
                      fullWidth: true,
                      size: AppButtonSize.lg,
                      leadingIcon: Symbols.check_rounded,
                      loading: _isSaving,
                      onPressed: _isSaving ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AccentSwatch accent;
  final VoidCallback onTap;

  const _FieldRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: ext.outline),
          borderRadius: AppRadius.brMd,
        ),
        child: Row(
          children: [
            Icon(icon, color: ext.mark(accent), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
                  Text(value,
                      style: tt.bodyMedium?.copyWith(
                          color: ext.textPrimary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
