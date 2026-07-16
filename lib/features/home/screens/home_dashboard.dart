import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../medication/models/medicine_log.dart';
import '../../water/services/water_service.dart';
import '../../water/models/enhanced_water_log.dart';
import '../../water/models/beverage_type.dart';
import '../../focus/services/focus_service.dart';
import '../../reminders/models/reminder_model.dart';
import '../../reminders/screens/add_reminder_screen.dart';
import '../../settings/screens/settings_screen.dart';

/// The unified landing screen — one calm "today" snapshot across every feature.
/// The only greeting in the app.
class HomeDashboard extends StatefulWidget {
  /// Switches the shell destination; [healthTab] selects Medicine(0)/Water(1).
  final void Function(int index, {int? healthTab}) onNavigate;

  const HomeDashboard({super.key, required this.onNavigate});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final AuthService _authService = AuthService();
  final FocusService _focus = FocusService();
  Future<DailyMedicineSummary>? _medicineSummary;

  @override
  void initState() {
    super.initState();
    _refreshMedicine();
  }

  void _refreshMedicine() {
    setState(() {
      _medicineSummary =
          MedicineCleanStorageService.getDailySummaryAsync(DateTime.now());
    });
  }

  Future<void> _refreshAll() async {
    _refreshMedicine();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _dateLabel => DateFormat('EEEE, MMM d').format(DateTime.now());

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    ).then((_) => mounted ? setState(() {}) : null);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final name = _authService.currentUser?.name ?? '';
    return AppScaffold(
      body: RefreshIndicator(
        color: ext.brand.base,
        onRefresh: _refreshAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: AppHeader(
                greeting: '$_greeting · $_dateLabel',
                title: name.isNotEmpty ? name : 'Welcome back',
                accent: ext.brand,
                actions: [
                  AppIconButton(
                    icon: Icons.settings_rounded,
                    accent: ext.brand,
                    onPressed: _openSettings,
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.xs, AppSpacing.gutter, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildQuickActions(ext),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(title: 'Today', accent: ext.brand),
                  const SizedBox(height: AppSpacing.xs),
                  _buildMedicineCard(ext),
                  const SizedBox(height: AppSpacing.lg),
                  _buildWaterCard(ext),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 132,
                    child: Row(
                      children: [
                        Expanded(child: _buildFocusCard(ext)),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: _buildRemindersCard(ext)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- quick actions -------------------------------------------------------

  Widget _buildQuickActions(AppColorsExt ext) {
    return Row(
      children: [
        _quickAction(ext.water, Icons.water_drop_rounded, '+250ml', _quickAddWater),
        const SizedBox(width: AppSpacing.md),
        _quickAction(ext.medicine, Icons.medication_rounded, 'Meds',
            () => widget.onNavigate(1, healthTab: 0)),
        const SizedBox(width: AppSpacing.md),
        _quickAction(ext.focus, Icons.self_improvement_rounded, 'Focus',
            () => widget.onNavigate(2)),
        const SizedBox(width: AppSpacing.md),
        _quickAction(ext.reminders, Icons.add_alert_rounded, 'Remind', _addReminder),
      ],
    );
  }

  Widget _quickAction(AccentSwatch s, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: s.container,
        borderRadius: AppRadius.brLg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(icon, color: s.onContainer, size: 24),
                const SizedBox(height: 6),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: s.onContainer)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _quickAddWater() async {
    final water =
        WaterService.getBeverage('water') ?? BeverageType.defaultBeverages.first;
    await WaterService.addWaterLog(amountMl: 250, beverage: water);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('+250 ml logged'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _addReminder() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddReminderScreen()))
        .then((_) => mounted ? setState(() {}) : null);
  }

  // ---- shared feature card -------------------------------------------------

  Widget _featureCard({
    required AccentSwatch accent,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: accent.container, borderRadius: AppRadius.brMd),
            child: Icon(icon, color: accent.onContainer, size: 24),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          trailing ?? Icon(Icons.chevron_right_rounded, color: ext.textTertiary),
        ],
      ),
    );
  }

  // ---- medicine ------------------------------------------------------------

  Widget _buildMedicineCard(AppColorsExt ext) {
    return FutureBuilder<DailyMedicineSummary>(
      future: _medicineSummary,
      builder: (context, snapshot) {
        final s = snapshot.data;
        final total = s?.totalScheduled ?? 0;
        final taken = s?.taken ?? 0;
        final missed = s?.missed ?? 0;
        final adherence = s?.adherenceRate ?? 0;

        final String status;
        if (total == 0) {
          status = 'No doses scheduled today';
        } else if (taken >= total) {
          status = 'All doses taken — nice work';
        } else if (missed > 0) {
          status = '$missed missed · ${total - taken - missed} left today';
        } else {
          status = '${total - taken} of $total doses left today';
        }

        return _featureCard(
          accent: ext.medicine,
          icon: Icons.medication_rounded,
          title: 'Medicine',
          subtitle: status,
          onTap: () => widget.onNavigate(1, healthTab: 0),
          trailing: total > 0
              ? ProgressRing(
                  progress: taken / total,
                  size: 48,
                  stroke: 5,
                  accent: ext.medicine,
                  center: Text('${adherence.round()}%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ext.medicine.strong, fontWeight: FontWeight.w800)),
                )
              : null,
        );
      },
    );
  }

  // ---- water ---------------------------------------------------------------

  Widget _buildWaterCard(AppColorsExt ext) {
    final listenable = WaterService.listenToDailyData();
    if (listenable == null) return _waterCardBody(ext, WaterService.getTodayData());
    return ValueListenableBuilder<Map<String, DailyWaterData>>(
      valueListenable: listenable,
      builder: (context, _, __) => _waterCardBody(ext, WaterService.getTodayData()),
    );
  }

  Widget _waterCardBody(AppColorsExt ext, DailyWaterData data) {
    final goal = WaterService.getDailyGoal();
    final progress = goal == 0 ? 0.0 : data.effectiveHydrationMl / goal;
    final remaining = (goal - data.effectiveHydrationMl).clamp(0, goal);
    return _featureCard(
      accent: ext.water,
      icon: Icons.water_drop_rounded,
      title: 'Hydration',
      subtitle: (data.effectiveHydrationMl >= goal && goal > 0)
          ? 'Goal reached · ${data.effectiveHydrationMl} ml'
          : '${data.effectiveHydrationMl} / $goal ml · $remaining ml to go',
      onTap: () => widget.onNavigate(1, healthTab: 1),
      trailing: ProgressRing(
        progress: progress.clamp(0.0, 1.0),
        size: 48,
        stroke: 5,
        accent: ext.water,
        center: Text('${(progress * 100).round()}%',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: ext.water.strong, fontWeight: FontWeight.w800)),
      ),
    );
  }

  // ---- focus (tamed to sibling parity, keeps purple accent) ----------------

  // Compact card for the 2-up row (Focus / Reminders).
  Widget _compactCard({
    required AccentSwatch accent,
    required IconData icon,
    required String title,
    required String value,
    required String sub,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration:
                    BoxDecoration(color: accent.container, borderRadius: AppRadius.brMd),
                child: Icon(icon, color: accent.onContainer, size: 22),
              ),
              const Spacer(),
              if (badge != null) badge,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(title, style: tt.titleMedium),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFocusCard(AppColorsExt ext) {
    return ListenableBuilder(
      listenable: _focus,
      builder: (context, _) {
        final mins = _focus.todayMinutes;
        final streak = _focus.stats.currentStreak;
        return _compactCard(
          accent: ext.focus,
          icon: Icons.self_improvement_rounded,
          title: 'Focus',
          value: mins > 0 ? '$mins min' : 'Start',
          sub: streak > 0 ? '$streak-day streak' : 'Ready to focus?',
          onTap: () => widget.onNavigate(2),
          badge: streak > 0
              ? Icon(Icons.local_fire_department_rounded,
                  size: 18, color: ext.focus.strong)
              : null,
        );
      },
    );
  }

  // ---- reminders -----------------------------------------------------------

  Widget _buildRemindersCard(AppColorsExt ext) {
    final reminders = CleanStorageService.getReminders();
    final now = DateTime.now();
    final pending = reminders.where((r) => !r.isCompleted).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final today = pending
        .where((r) =>
            r.scheduledTime.year == now.year &&
            r.scheduledTime.month == now.month &&
            r.scheduledTime.day == now.day)
        .toList();
    final upcoming = pending.where((r) => r.scheduledTime.isAfter(now)).toList();
    final Reminder? next =
        today.isNotEmpty ? today.first : (upcoming.isNotEmpty ? upcoming.first : null);

    return _compactCard(
      accent: ext.reminders,
      icon: Icons.notifications_rounded,
      title: 'Reminders',
      value: today.isNotEmpty
          ? '${today.length} today'
          : (next != null ? _formatTime(next.scheduledTime) : 'All clear'),
      sub: next == null ? 'Nothing upcoming' : next.title,
      onTap: () => widget.onNavigate(3),
      badge: today.isNotEmpty
          ? CountBadge(count: today.length, accent: ext.reminders)
          : null,
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
  }
}
