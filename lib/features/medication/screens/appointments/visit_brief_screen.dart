import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/utils/date_formats.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/doctor_pharmacy.dart';
import '../../services/adherence_report_service.dart';
import '../../services/visit_brief_export.dart';
import '../../services/visit_brief_pdf.dart';
import '../../services/visit_brief_service.dart';

/// "Since your last visit": how the doses went, what was measured, what changed
/// on the list and what you wanted to raise — to read before the visit and to
/// hand over at it.
class VisitBriefScreen extends StatefulWidget {
  const VisitBriefScreen({super.key, required this.appointment});

  final Appointment appointment;

  /// "Covers since your last visit on Mar 4 (47 days)" / "Covers the last 30 days".
  static String coversLine(VisitBrief b) {
    final w = b.window;
    return w.sinceVisit != null
        ? 'Covers since your last visit on '
            '${DateFormats.dayLabel(w.sinceVisit!, reference: b.generatedAt)} (${w.days} days)'
        : 'Covers the last ${w.days} days';
  }

  @override
  State<VisitBriefScreen> createState() => _VisitBriefScreenState();
}

class _VisitBriefScreenState extends State<VisitBriefScreen> {
  VisitBrief? _brief;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final brief = await VisitBriefService.build(widget.appointment);
    if (!mounted) return;
    setState(() => _brief = brief);
  }

  Future<void> _share() async {
    final b = _brief;
    if (b == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await VisitBriefPdf.build(b);
      await VisitBriefExport.sharePdf(bytes,
          VisitBriefExport.filenameFor(b.appointment.doctorName, b.appointment.dateTime));
    } catch (e) {
      debugPrint('⚠️ Sharing the visit brief failed: $e');
      if (mounted) context.toastError('Could not make the PDF. Please try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final b = _brief;
    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Visit brief',
              leading: AppHeader.backButton(context),
              actions: [
                AppIconButton(
                  icon: Symbols.ios_share_rounded,
                  filled: false,
                  tooltip: 'Share as PDF',
                  onPressed: b == null ? null : _share,
                ),
              ],
            ),
            Expanded(
              child: b == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.sm,
                          AppSpacing.gutter, AppSpacing.xxl),
                      children: [
                        _visitCard(context, b),
                        const SizedBox(height: AppSpacing.md),
                        _dosesCard(context, b),
                        if (b.hasVitals) ...[
                          const SizedBox(height: AppSpacing.md),
                          _readingsCard(context, b),
                        ],
                        if (b.started.isNotEmpty || b.stopped.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          _changesCard(context, b),
                        ],
                        if (b.discuss.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          _discussCard(context, b),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          label: 'Share as PDF',
                          leadingIcon: Symbols.picture_as_pdf_rounded,
                          fullWidth: true,
                          size: AppButtonSize.lg,
                          loading: _sharing,
                          accent: ext.medicine,
                          onPressed: _share,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'What was logged in the app, for a conversation with your doctor. '
                          'It is not medical advice.',
                          style: tt.bodySmall?.copyWith(color: ext.textTertiary, height: 1.35),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String title, IconData icon, List<Widget> children) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: ext.mark(ext.medicine)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title,
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String text, {bool strong = false, bool quiet = false}) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: (strong ? tt.titleMedium : tt.bodyMedium)?.copyWith(
            color: quiet ? ext.textSecondary : ext.textPrimary,
            fontWeight: strong ? FontWeight.w700 : null),
      ),
    );
  }

  Widget _visitCard(BuildContext context, VisitBrief b) {
    final a = b.appointment;
    final when = '${DateFormats.weekdayDayMonthShort.format(a.dateTime)} · '
        '${DateFormats.time.format(a.dateTime)}';
    final loc = (a.location ?? '').trim();
    return _card(context, a.doctorName, Symbols.event_rounded, [
      if (b.patientName != null && b.patientName!.trim().isNotEmpty)
        _line(context, 'For ${b.patientName}', quiet: true),
      _line(context, loc.isEmpty ? when : '$when · $loc'),
      _line(context, VisitBriefScreen.coversLine(b), quiet: true),
    ]);
  }

  Widget _dosesCard(BuildContext context, VisitBrief b) {
    final pct = b.overallPercent;
    final lowest = [
      for (final m in b.medicines)
        if (m.percent != null && m.percent! < 100) m,
    ].take(3).toList();
    return _card(context, 'Doses', Symbols.medication_rounded, [
      if (b.medicines.isEmpty)
        _line(context, 'No medicines were being taken in this period.', quiet: true)
      else if (pct == null)
        _line(context, 'No scheduled doses came due in this period.', quiet: true)
      else ...[
        _line(context, '$pct% of doses taken', strong: true),
        _line(context, '${b.taken} of ${b.due} scheduled · ${b.missed} missed · ${b.skipped} skipped',
            quiet: true),
        if (lowest.isEmpty)
          _line(context, 'Every medicine was taken as scheduled.')
        else
          for (final m in lowest) _line(context, _medicineLine(m)),
      ],
    ]);
  }

  static String _medicineLine(MedicineAdherence m) {
    final s = m.medicine.strength;
    final name = (s != null && s.trim().isNotEmpty) ? '${m.medicine.name} $s' : m.medicine.name;
    return '$name: ${m.percent}%${m.missed > 0 ? ' · ${m.missed} missed' : ''}';
  }

  Widget _readingsCard(BuildContext context, VisitBrief b) {
    final bp = b.bp, g = b.glucose, w = b.weight;
    return _card(context, 'Readings', Symbols.monitor_heart_rounded, [
      if (bp != null)
        _line(context,
            'Blood pressure: average ${bp.avgSystolic}/${bp.avgDiastolic} over '
            '${bp.sessions} measurement${bp.sessions == 1 ? '' : 's'} '
            '(${bp.minSystolic} to ${bp.maxSystolic} / ${bp.minDiastolic} to ${bp.maxDiastolic})'),
      if (g != null)
        _line(context,
            'Blood sugar: average ${g.avgMgdl} mg/dL over ${g.readings} '
            'reading${g.readings == 1 ? '' : 's'}'
            '${g.inRangePercent == null ? '' : ', ${g.inRangePercent}% in target'}'),
      if (w != null)
        _line(
            context,
            w.readings == 1
                ? 'Weight: ${w.lastKg.toStringAsFixed(1)} kg'
                : 'Weight: ${w.firstKg.toStringAsFixed(1)} to ${w.lastKg.toStringAsFixed(1)} kg '
                    '(${w.changeKg >= 0 ? '+' : '-'}${w.changeKg.abs().toStringAsFixed(1)})'),
    ]);
  }

  Widget _changesCard(BuildContext context, VisitBrief b) {
    return _card(context, 'Changes', Symbols.swap_horiz_rounded, [
      if (b.started.isNotEmpty)
        _line(context, 'Started: ${b.started.map((m) => m.name).join(', ')}'),
      if (b.stopped.isNotEmpty)
        _line(context, 'Stopped or put away: ${b.stopped.map((m) => m.name).join(', ')}'),
    ]);
  }

  Widget _discussCard(BuildContext context, VisitBrief b) {
    return _card(context, 'To discuss', Symbols.chat_rounded, [
      for (final d in b.discuss) _line(context, d),
    ]);
  }
}
