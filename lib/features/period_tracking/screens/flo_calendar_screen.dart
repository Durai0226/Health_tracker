import 'package:flutter/material.dart';
import '../theme/flo_theme.dart';
import '../widgets/widgets.dart';
import '../services/period_storage_service.dart';
import '../services/period_prediction_service.dart';
import '../models/models.dart';

/// Full calendar view for period tracking
class FloCalendarScreen extends StatefulWidget {
  const FloCalendarScreen({super.key});

  @override
  State<FloCalendarScreen> createState() => _FloCalendarScreenState();
}

class _FloCalendarScreenState extends State<FloCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  PeriodData? _periodData;
  Map<String, DateTime>? _fertileWindow;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final settings = PeriodCleanStorageService.getSettings();
    final lastPeriod = DateTime.now().subtract(const Duration(days: 10));
    
    _periodData = PeriodData(
      lastPeriodDate: lastPeriod,
      cycleLength: settings.defaultCycleLength,
      periodDuration: settings.defaultPeriodDuration,
    );

    if (_periodData != null) {
      _fertileWindow = PeriodPredictionService.predictFertileWindow(
        _periodData!.lastPeriodDate,
        _periodData!.cycleLength,
      );
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FloTheme.getBackground(context),
      appBar: FloAppBar(
        title: 'Calendar',
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _selectedDate = DateTime.now());
            },
            icon: Icon(
              Icons.today_rounded,
              color: FloTheme.periodPink,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: FloTheme.spacingLg),

            // Month calendar
            FloMonthCalendar(
              selectedDate: _selectedDate,
              periodStartDate: _periodData?.lastPeriodDate,
              cycleLength: _periodData?.cycleLength ?? 28,
              periodDuration: _periodData?.periodDuration ?? 5,
              fertileWindow: _fertileWindow,
              onDateSelected: (date) {
                setState(() => _selectedDate = date);
              },
            ),

            const SizedBox(height: FloTheme.spacing2xl),

            // Selected date info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
              child: _buildDateInfo(),
            ),

            const SizedBox(height: FloTheme.spacingLg),

            // Cycle history
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
              child: _buildCycleHistory(),
            ),

            const SizedBox(height: FloTheme.spacing4xl),
          ],
        ),
      ),
    );
  }

  Widget _buildDateInfo() {
    if (_periodData == null) return const SizedBox.shrink();

    final cycleDay = _selectedDate.difference(_periodData!.lastPeriodDate).inDays + 1;
    final isOnPeriod = _periodData!.isOnPeriod(_selectedDate);
    final isFertile = _fertileWindow != null &&
        _selectedDate.isAfter(_fertileWindow!['start']!.subtract(const Duration(days: 1))) &&
        _selectedDate.isBefore(_fertileWindow!['end']!.add(const Duration(days: 1)));

    String status = 'Day $cycleDay of your cycle';
    Color statusColor = FloTheme.getTextSecondary(context);

    if (isOnPeriod) {
      status = 'Period Day ${cycleDay}';
      statusColor = FloTheme.periodPink;
    } else if (isFertile) {
      status = 'Fertile Window - Day $cycleDay';
      statusColor = FloTheme.ovulationBlue;
    }

    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(FloTheme.spacingSm),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(FloTheme.radiusSm),
                ),
                child: Icon(
                  isOnPeriod
                      ? Icons.water_drop_rounded
                      : isFertile
                          ? Icons.favorite_rounded
                          : Icons.calendar_today_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: FloTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: FloTheme.titleMedium.copyWith(
                        color: statusColor,
                      ),
                    ),
                    Text(
                      'Tap to log symptoms for this day',
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
        ],
      ),
    );
  }

  Widget _buildCycleHistory() {
    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cycle Information',
            style: FloTheme.headlineSmall.copyWith(
              color: FloTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: FloTheme.spacingLg),
          _InfoRow(
            icon: Icons.loop_rounded,
            label: 'Cycle Length',
            value: '${_periodData?.cycleLength ?? 28} days',
          ),
          const SizedBox(height: FloTheme.spacingMd),
          _InfoRow(
            icon: Icons.water_drop_rounded,
            label: 'Period Duration',
            value: '${_periodData?.periodDuration ?? 5} days',
          ),
          const SizedBox(height: FloTheme.spacingMd),
          _InfoRow(
            icon: Icons.star_rounded,
            label: 'Ovulation Day',
            value: 'Day ${(_periodData?.cycleLength ?? 28) - 14}',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: FloTheme.periodPink),
        const SizedBox(width: FloTheme.spacingMd),
        Expanded(
          child: Text(
            label,
            style: FloTheme.bodyMedium.copyWith(
              color: FloTheme.getTextSecondary(context),
            ),
          ),
        ),
        Text(
          value,
          style: FloTheme.titleMedium.copyWith(
            color: FloTheme.getTextPrimary(context),
          ),
        ),
      ],
    );
  }
}
