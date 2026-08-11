import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/doctor_pharmacy.dart';
import '../../services/medicine_storage_service.dart';
import 'nunito_add_edit_appointment_screen.dart';

class NunitoAppointmentListScreen extends StatefulWidget {
  const NunitoAppointmentListScreen({super.key});

  @override
  State<NunitoAppointmentListScreen> createState() =>
      _NunitoAppointmentListScreenState();
}

class _NunitoAppointmentListScreenState
    extends State<NunitoAppointmentListScreen> {
  List<Appointment> _appointments = [];
  bool _isLoading = true;

  final HapticService _hapticService = HapticService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final appointments = await MedicineCleanStorageService.getAllAppointments();
      appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      if (mounted) {
        setState(() {
          _appointments = appointments;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading appointments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToAddEdit({Appointment? appointment}) async {
    _hapticService.light();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NunitoAddEditAppointmentScreen(editAppointment: appointment),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _toggleCompleted(Appointment appointment) async {
    _hapticService.toggle();
    await MedicineCleanStorageService.updateAppointment(
        appointment.copyWith(isCompleted: !appointment.isCompleted));
    _load();
  }

  Future<void> _deleteAppointment(Appointment appointment) async {
    final ext = AppColorsExt.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ext.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        title: Text('Delete appointment',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: ext.textPrimary)),
        content: Text(
            'Are you sure you want to delete this appointment with ${appointment.doctorName}?',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: ext.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: ext.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: ext.error.strong),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _hapticService.error();
      await MedicineCleanStorageService.deleteAppointment(appointment.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;
    final upcoming = _appointments.where((a) => !a.isCompleted && a.isUpcoming).toList();
    final past = _appointments
        .where((a) => a.isCompleted || !a.isUpcoming)
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        floatingActionButton: AppFab(
          icon: Symbols.add_rounded,
          label: 'Add appointment',
          accent: accent,
          onPressed: () => _navigateToAddEdit(),
        ),
        body: Column(
          children: [
            AppHeader(
              title: 'Appointments',
              accent: accent,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                accent: accent,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _appointments.isEmpty
                      // Hosted in a scroller: the Expanded hands the empty
                      // state exactly the height the header leaves over, and
                      // at large Dynamic Type the circle + title + message +
                      // button need more than that (bottom overflow at 200%).
                      ? _ScrollableFill(
                          child: EmptyState(
                            icon: Symbols.event_rounded,
                            title: 'No appointments yet',
                            message:
                                'Add an upcoming doctor visit and get a reminder before it starts.',
                            accent: accent,
                            action: AppButton(
                              label: 'Add appointment',
                              accent: accent,
                              leadingIcon: Symbols.add_rounded,
                              onPressed: () => _navigateToAddEdit(),
                            ),
                          ),
                        )
                      : _buildList(ext, accent, upcoming, past),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(AppColorsExt ext, AccentSwatch accent,
      List<Appointment> upcoming, List<Appointment> past) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 96),
      children: [
        if (upcoming.isNotEmpty) ...[
          SectionHeader(
              title: 'Upcoming', icon: Symbols.upcoming_rounded, accent: accent),
          const SizedBox(height: AppSpacing.sm),
          for (final a in upcoming) _buildCard(a, ext, accent),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (past.isNotEmpty) ...[
          SectionHeader(title: 'Past', icon: Symbols.history_rounded, accent: accent),
          const SizedBox(height: AppSpacing.sm),
          for (final a in past) _buildCard(a, ext, accent),
        ],
      ],
    );
  }

  Widget _buildCard(Appointment a, AppColorsExt ext, AccentSwatch accent) {
    final tt = Theme.of(context).textTheme;
    return Dismissible(
      key: Key(a.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(color: ext.error.base, borderRadius: AppRadius.brCard),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Symbols.delete_rounded, color: ext.error.on),
      ),
      confirmDismiss: (direction) async {
        _deleteAppointment(a);
        return false;
      },
      child: AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        onTap: () => _navigateToAddEdit(appointment: a),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleCompleted(a),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: a.isCompleted ? ext.success.container : accent.container,
                  borderRadius: AppRadius.brLg,
                ),
                child: Icon(
                  a.isCompleted ? Symbols.check_rounded : Symbols.event_rounded,
                  color: a.isCompleted ? ext.success.onContainer : accent.onContainer,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.doctorName,
                    style: tt.titleLarge?.copyWith(
                      color: ext.textPrimary,
                      decoration: a.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTime(a.dateTime),
                    style: tt.bodySmall?.copyWith(color: ext.mark(accent)),
                  ),
                  if (a.location != null && a.location!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      a.location!,
                      style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (a.reminderEnabled && !a.isCompleted)
              Icon(Symbols.notifications_active_rounded,
                  color: ext.mark(accent), size: 20),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$minute $period';
  }
}

/// Gives its child the incoming viewport height as a MINIMUM instead of a
/// fixed size, and lets it scroll past that.
///
/// Anything dropped into an [Expanded] gets a tight height, which is fine
/// until Dynamic Type grows the content past it — then a centred column of
/// text simply gets clipped ("BOTTOM OVERFLOWED"). Because the constraint is
/// only a minimum, layout at default text sizes is byte-for-byte unchanged.
class _ScrollableFill extends StatelessWidget {
  final Widget child;
  const _ScrollableFill({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}
