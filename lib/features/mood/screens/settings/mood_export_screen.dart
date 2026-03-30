import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/mood_theme.dart';

/// Mood Export Journal Screen
class MoodExportScreen extends StatefulWidget {
  const MoodExportScreen({super.key});

  @override
  State<MoodExportScreen> createState() => _MoodExportScreenState();
}

class _MoodExportScreenState extends State<MoodExportScreen> {
  String _exportFormat = 'pdf';
  String _dateRange = 'month';
  bool _includeNotes = true;
  bool _includeStats = true;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoodTheme.background,
      appBar: AppBar(
        backgroundColor: MoodTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: MoodTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Export Journal', style: MoodTheme.headingSm.copyWith(color: MoodTheme.textPrimary)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(MoodTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Export Format'),
            const SizedBox(height: MoodTheme.spacingSm),
            _buildFormatSelector(),
            const SizedBox(height: MoodTheme.spacingLg),
            _buildSectionTitle('Date Range'),
            const SizedBox(height: MoodTheme.spacingSm),
            _buildDateRangeSelector(),
            const SizedBox(height: MoodTheme.spacingLg),
            _buildSectionTitle('Include'),
            const SizedBox(height: MoodTheme.spacingSm),
            _buildIncludeOptions(),
            const SizedBox(height: MoodTheme.spacingLg),
            _buildExportButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: MoodTheme.titleLg.copyWith(color: MoodTheme.textPrimary));
  }

  Widget _buildFormatSelector() {
    return Container(
      padding: const EdgeInsets.all(MoodTheme.spacingSm),
      decoration: BoxDecoration(
        color: MoodTheme.surface,
        borderRadius: MoodTheme.borderRadiusLg,
        boxShadow: MoodTheme.softShadow,
      ),
      child: Row(
        children: [
          _buildFormatOption('pdf', 'PDF', Icons.picture_as_pdf_outlined),
          const SizedBox(width: MoodTheme.spacingSm),
          _buildFormatOption('csv', 'CSV', Icons.table_chart_outlined),
          const SizedBox(width: MoodTheme.spacingSm),
          _buildFormatOption('json', 'JSON', Icons.data_object),
        ],
      ),
    );
  }

  Widget _buildFormatOption(String id, String label, IconData icon) {
    final isSelected = _exportFormat == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _exportFormat = id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: MoodTheme.spacingMd),
          decoration: BoxDecoration(
            color: isSelected ? MoodTheme.primary : Colors.transparent,
            borderRadius: MoodTheme.borderRadiusMd,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : MoodTheme.textMuted, size: 24),
              const SizedBox(height: 4),
              Text(label, style: MoodTheme.titleSm.copyWith(
                color: isSelected ? Colors.white : MoodTheme.textSecondary,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(MoodTheme.spacingSm),
      decoration: BoxDecoration(
        color: MoodTheme.surface,
        borderRadius: MoodTheme.borderRadiusLg,
        boxShadow: MoodTheme.softShadow,
      ),
      child: Column(
        children: [
          _buildDateRangeOption('week', 'Last 7 Days', Icons.calendar_today),
          Divider(color: MoodTheme.beige100),
          _buildDateRangeOption('month', 'Last 30 Days', Icons.date_range),
          Divider(color: MoodTheme.beige100),
          _buildDateRangeOption('year', 'Last Year', Icons.calendar_month),
          Divider(color: MoodTheme.beige100),
          _buildDateRangeOption('all', 'All Time', Icons.all_inclusive),
        ],
      ),
    );
  }

  Widget _buildDateRangeOption(String id, String label, IconData icon) {
    final isSelected = _dateRange == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _dateRange = id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MoodTheme.spacingSm),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? MoodTheme.primary : MoodTheme.textMuted, size: 20),
            const SizedBox(width: MoodTheme.spacingMd),
            Expanded(
              child: Text(label, style: MoodTheme.bodyMd.copyWith(
                color: isSelected ? MoodTheme.primary : MoodTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              )),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: MoodTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildIncludeOptions() {
    return Container(
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      decoration: BoxDecoration(
        color: MoodTheme.surface,
        borderRadius: MoodTheme.borderRadiusLg,
        boxShadow: MoodTheme.softShadow,
      ),
      child: Column(
        children: [
          _buildToggleRow(
            icon: Icons.notes_outlined,
            title: 'Journal Notes',
            subtitle: 'Include your written reflections',
            value: _includeNotes,
            onChanged: (v) => setState(() => _includeNotes = v),
          ),
          Divider(color: MoodTheme.beige100, height: MoodTheme.spacingLg),
          _buildToggleRow(
            icon: Icons.analytics_outlined,
            title: 'Statistics',
            subtitle: 'Include mood trends and insights',
            value: _includeStats,
            onChanged: (v) => setState(() => _includeStats = v),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: value ? MoodTheme.purple50 : MoodTheme.beige50,
            borderRadius: MoodTheme.borderRadiusSm,
          ),
          child: Icon(icon, color: value ? MoodTheme.primary : MoodTheme.textMuted, size: 20),
        ),
        const SizedBox(width: MoodTheme.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: MoodTheme.titleSm.copyWith(color: MoodTheme.textPrimary)),
              Text(subtitle, style: MoodTheme.bodySm.copyWith(color: MoodTheme.textMuted)),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: (v) {
            HapticFeedback.lightImpact();
            onChanged(v);
          },
          activeColor: MoodTheme.primary,
        ),
      ],
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isExporting ? null : _exportJournal,
        style: ElevatedButton.styleFrom(
          backgroundColor: MoodTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: MoodTheme.borderRadiusLg),
        ),
        child: _isExporting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.download_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text('Export as ${_exportFormat.toUpperCase()}', 
                    style: MoodTheme.titleMd.copyWith(color: Colors.white)),
                ],
              ),
      ),
    );
  }

  Future<void> _exportJournal() async {
    HapticFeedback.mediumImpact();
    setState(() => _isExporting = true);
    
    // Simulate export
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Journal exported as ${_exportFormat.toUpperCase()}!'),
          backgroundColor: MoodTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
