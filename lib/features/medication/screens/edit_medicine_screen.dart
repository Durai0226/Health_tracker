
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../home/screens/home_screen.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/medicine.dart';

class EditMedicineScreen extends StatefulWidget {
  final Medicine medicine;

  const EditMedicineScreen({super.key, required this.medicine});

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  late String _name;
  late int _dosageAmount;
  late String _dosageType;
  late TimeOfDay _time;
  late String _frequency;
  late int _durationDays;
  late bool _enableReminder;
  late bool _enableBuyReminder;
  late int _stockRemaining;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    _name = m.name;
    _nameController.text = _name;
    _dosageAmount = m.dosageAmount;
    _dosageType = m.dosageType;
    _time = TimeOfDay(hour: m.time.hour, minute: m.time.minute);
    _frequency = m.frequency;
    _durationDays = m.durationDays ?? -1;
    _enableReminder = m.enableReminder;
    _enableBuyReminder = m.enableBuyReminder;
    _stockRemaining = m.stockRemaining ?? 10;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final notificationService = NotificationService();
      final notificationId = widget.medicine.id.hashCode;
      final wasReminderEnabled = widget.medicine.enableReminder;
      
      final updatedMedicine = Medicine(
        id: widget.medicine.id,
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

      // Save to storage first (critical operation)
      await StorageService.updateMedicine(updatedMedicine);

      // Handle notification scheduling based on what changed
      bool scheduled = false;
      String message = '';
      
      if (_enableReminder) {
        // Case 1: Reminder is now enabled
        // Always cancel first, then reschedule (handles time/frequency changes too)
        unawaited(notificationService.cancelNotification(notificationId).catchError((e) {
          debugPrint('Cancel notification error (non-blocking): $e');
        }));
        
        // Small delay to ensure cancellation completes
        await Future.delayed(const Duration(milliseconds: 100));
        
        scheduled = await notificationService.scheduleMedicineReminder(
          id: notificationId,
          medicineName: _name,
          hour: _time.hour,
          minute: _time.minute,
          frequency: _frequency,
        );
        
        if (scheduled) {
          message = 'Reminder set for ${_time.format(context)}';
          // Show confirmation notification (non-blocking)
          unawaited(notificationService.showImmediateNotification(
            title: wasReminderEnabled ? 'Reminder Updated 💊' : 'Reminder Enabled 💊',
            body: '$_name - ${_time.format(context)}',
            channelId: 'medicine_channel',
          ).catchError((e) {
            debugPrint('Confirmation notification error: $e');
            return false;
          }));
        } else {
          message = 'Saved but reminder failed. Check permissions.';
        }
      } else {
        // Case 2: Reminder is now disabled
        if (wasReminderEnabled) {
          // Was enabled, now disabled - cancel the notification
          unawaited(notificationService.cancelNotification(notificationId).catchError((e) {
            debugPrint('Cancel notification error: $e');
          }));
          message = 'Medicine saved (reminder disabled)';
        } else {
          // Was disabled, still disabled
          message = 'Medicine saved';
        }
        scheduled = true; // No scheduling needed, so consider it success
      }

      // Show result to user
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
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error saving medicine: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to save. Please try again.')),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text('Are you sure you want to delete "$_name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteMedicine(widget.medicine.id);
      await NotificationService().cancelNotification(widget.medicine.id.hashCode);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Edit Medicine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medicine Name
              Text('Medicine Name', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                onChanged: (val) => setState(() => _name = val),
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'e.g., Paracetamol',
                  prefixIcon: Icon(Icons.medication_outlined, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 32),

              // Dosage
              Text('Dosage', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
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
                    Text('$_dosageAmount', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 32),
                    _buildCircleButton(Icons.add_rounded, () => setState(() => _dosageAmount++)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ['Tablet', 'Capsule', 'Syrup', 'Injection'].map((type) {
                  final isSelected = _dosageType == type;
                  return GestureDetector(
                    onTap: () => setState(() => _dosageType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
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
              const SizedBox(height: 32),

              // Reminder Time
              Text('Reminder Time', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _time);
                  if (t != null) setState(() => _time = t);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        _time.format(context),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                items: ['Once a day', 'Twice a day', 'Every 8 hours']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _frequency = val!),
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  prefixIcon: Icon(Icons.repeat_rounded, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 32),

              // Duration
              Text('Duration', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...[7, 14, 30, -1].map((days) {
                final isSelected = _durationDays == days;
                return GestureDetector(
                  onTap: () => setState(() => _durationDays = days),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(width: 12),
                        Text(
                          days == -1 ? 'Until I stop' : '$days days',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 32),

              // Reminder Toggles
              _buildToggleCard(
                icon: Icons.notifications_active_outlined,
                title: 'Push Notifications',
                subtitle: 'Get reminded with custom ringtone',
                value: _enableReminder,
                onChanged: (val) => setState(() => _enableReminder = val),
              ),
              const SizedBox(height: 12),
              _buildToggleCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Refill Reminder',
                subtitle: 'Alert when stock is low',
                value: _enableBuyReminder,
                onChanged: (val) => setState(() => _enableBuyReminder = val),
              ),
              if (_enableBuyReminder) ...[
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Current Stock (Tablets)',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  controller: TextEditingController(text: '$_stockRemaining'),
                  onChanged: (val) => setState(() => _stockRemaining = int.tryParse(val) ?? 10),
                ),
              ],
              const SizedBox(height: 48),

              // Save Button
              Container(
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
                  onPressed: (_name.isNotEmpty && !_isSaving) ? _save : null,
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
                            Text('Save Changes'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
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
}
