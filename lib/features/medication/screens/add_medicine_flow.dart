
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/medicine.dart';
import 'package:uuid/uuid.dart';

class AddMedicineFlow extends StatefulWidget {
  const AddMedicineFlow({super.key});

  @override
  State<AddMedicineFlow> createState() => _AddMedicineFlowState();
}

class _AddMedicineFlowState extends State<AddMedicineFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 5;

  // Form State
  String _name = "";
  int _dosageAmount = 1;
  String _dosageType = "Tablet";
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  String _frequency = "Once a day";
  int _durationDays = 7;
  bool _enableReminder = true;
  bool _enableBuyReminder = false;
  int _stockRemaining = 10;
  bool _isSaving = false;

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _saveMedicine() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final newMedicine = Medicine(
        id: const Uuid().v4(),
        name: _name,
        dosageAmount: _dosageAmount,
        dosageType: _dosageType,
        time: DateTime(2024, 1, 1, _time.hour, _time.minute),
        frequency: _frequency,
        durationDays: _durationDays == -1 ? null : _durationDays,
        enableReminder: _enableReminder,
        enableBuyReminder: _enableBuyReminder,
        stockRemaining: _enableBuyReminder ? _stockRemaining : null,
        lowStockThreshold: _enableBuyReminder ? 5 : null,
      );

      await StorageService.addMedicine(newMedicine);

      bool scheduled = false;
      String message = '';
      
      if (_enableReminder) {
        final notificationService = NotificationService();
        
        scheduled = await notificationService.scheduleMedicineReminder(
          id: newMedicine.id.hashCode,
          medicineName: _name,
          hour: _time.hour,
          minute: _time.minute,
          frequency: _frequency,
        );

        if (scheduled) {
          message = 'Reminder set for ${_time.format(context)}';
          // Show confirmation (non-blocking)
          unawaited(notificationService.showImmediateNotification(
            title: 'Reminder Added 💊',
            body: '$_name - ${_time.format(context)}',
            channelId: 'medicine_channel',
          ).catchError((e) { debugPrint('Notification error: $e'); return false; }));
        } else {
          message = 'Saved but reminder failed. Check permissions.';
        }
      } else {
        message = 'Medicine saved';
        scheduled = true;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  scheduled ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: scheduled ? AppColors.success : AppColors.warning,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error saving medicine: $e');
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to save medicine. Please try again.'),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (_currentPage > 0) {
              _prevPage();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text("Add Reminder"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Steps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: Row(
                children: List.generate(_totalPages, (index) {
                  final isComplete = index < _currentPage;
                  final isCurrent = index == _currentPage;
                  return Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isComplete
                                ? AppColors.success
                                : (isCurrent ? AppColors.primary : AppColors.divider),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isComplete
                                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                : Text(
                                    "${index + 1}",
                                    style: TextStyle(
                                      color: isCurrent ? Colors.white : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ),
                        if (index < _totalPages - 1)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: isComplete ? AppColors.success : AppColors.divider,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildNameStep(),
                  _buildDosageStep(),
                  _buildTimeStep(),
                  _buildDurationStep(),
                  _buildRemindersStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContainer({required String title, required String subtitle, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildNameStep() {
    return _buildStepContainer(
      title: "Medicine Name",
      subtitle: "What medication do you take?",
      child: Column(
        children: [
          TextField(
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: 50,
            onChanged: (val) => setState(() => _name = val.trim()),
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              hintText: "e.g., Paracetamol",
              prefixIcon: Icon(Icons.medication_outlined, color: AppColors.primary),
            ),
          ),
          const Spacer(),
          _buildNextButton(enabled: _name.isNotEmpty),
        ],
      ),
    );
  }

  Widget _buildDosageStep() {
    return _buildStepContainer(
      title: "Dosage",
      subtitle: "How much do you take each time?",
      child: Column(
        children: [
          // Amount Selector
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCircleButton(Icons.remove_rounded, () {
                  if (_dosageAmount > 1) setState(() => _dosageAmount--);
                }),
                const SizedBox(width: 32),
                Text("$_dosageAmount", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                const SizedBox(width: 32),
                _buildCircleButton(Icons.add_rounded, () => setState(() => _dosageAmount++)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Type Selector
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ["Tablet", "Capsule", "Syrup", "Injection"].map((type) {
              final isSelected = _dosageType == type;
              return GestureDetector(
                onTap: () => setState(() => _dosageType = type),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildTimeStep() {
    return _buildStepContainer(
      title: "Reminder Time",
      subtitle: "When should we remind you?",
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                _time.format(context),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 32),
          DropdownButtonFormField<String>(
            initialValue: _frequency,
            items: ["Once a day", "Twice a day", "Every 8 hours"]
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _frequency = val!),
            decoration: const InputDecoration(
              labelText: "Frequency",
              prefixIcon: Icon(Icons.repeat_rounded, color: AppColors.primary),
            ),
          ),
          const Spacer(),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildDurationStep() {
    return _buildStepContainer(
      title: "Duration",
      subtitle: "How long will you take this medicine?",
      child: Column(
        children: [
          ...[7, 14, 30, -1].map((days) {
            final isSelected = _durationDays == days;
            return GestureDetector(
              onTap: () => setState(() => _durationDays = days),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      days == -1 ? Icons.all_inclusive_rounded : Icons.calendar_today_rounded,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      days == -1 ? "Until I stop" : "$days days",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildRemindersStep() {
    return _buildStepContainer(
      title: "Reminders",
      subtitle: "Customize your notification preferences",
      child: Column(
        children: [
          _buildToggleCard(
            icon: Icons.notifications_active_outlined,
            title: "Push Notifications",
            subtitle: "Get reminded on time",
            value: _enableReminder,
            onChanged: (val) => setState(() => _enableReminder = val),
          ),
          const SizedBox(height: 12),
          _buildToggleCard(
            icon: Icons.shopping_bag_outlined,
            title: "Refill Reminder",
            subtitle: "Alert when stock is low",
            value: _enableBuyReminder,
            onChanged: (val) => setState(() => _enableBuyReminder = val),
          ),
          if (_enableBuyReminder) ...[
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Current Stock (Tablets)",
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              onChanged: (val) => setState(() => _stockRemaining = int.tryParse(val) ?? 10),
            ),
          ],
          const Spacer(),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton({bool enabled = true}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? _nextPage : null,
        child: const Text("Continue"),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveMedicine,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded),
                  SizedBox(width: 8),
                  Text("Save Medicine"),
                ],
              ),
      ),
    );
  }
}
