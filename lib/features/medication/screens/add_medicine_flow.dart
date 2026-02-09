
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../home/screens/home_screen.dart';
import '../../../core/services/storage_service.dart';
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
  TimeOfDay _time = TimeOfDay(hour: 8, minute: 0);
  String _frequency = "Once a day";
  int _durationDays = 7;
  bool _enableReminder = true;
  bool _enableBuyReminder = false;
  int _stockRemaining = 10;

  void _nextPage() {
    _pageController.nextPage(
      duration: Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _saveMedicine() async {
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

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (_currentPage > 0) {
              _prevPage();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text("Add Medicine"),
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
                                ? Icon(Icons.check_rounded, size: 16, color: Colors.white)
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
                physics: NeverScrollableScrollPhysics(),
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
          SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: 32),
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
            onChanged: (val) => setState(() => _name = val),
            style: TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: "e.g., Paracetamol",
              prefixIcon: Icon(Icons.medication_outlined, color: AppColors.primary),
            ),
          ),
          Spacer(),
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
            padding: EdgeInsets.all(20),
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
                SizedBox(width: 32),
                Text("$_dosageAmount", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                SizedBox(width: 32),
                _buildCircleButton(Icons.add_rounded, () => setState(() => _dosageAmount++)),
              ],
            ),
          ),
          SizedBox(height: 24),
          // Type Selector
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ["Tablet", "Capsule", "Syrup", "Injection"].map((type) {
              final isSelected = _dosageType == type;
              return GestureDetector(
                onTap: () => setState(() => _dosageType = type),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
          Spacer(),
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
              padding: EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                _time.format(context),
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          SizedBox(height: 32),
          DropdownButtonFormField<String>(
            value: _frequency,
            items: ["Once a day", "Twice a day", "Every 8 hours"]
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _frequency = val!),
            decoration: InputDecoration(
              labelText: "Frequency",
              prefixIcon: Icon(Icons.repeat_rounded, color: AppColors.primary),
            ),
          ),
          Spacer(),
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
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(20),
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
                    SizedBox(width: 16),
                    Text(
                      days == -1 ? "Until I stop" : "$days days",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    Spacer(),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }),
          Spacer(),
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
          SizedBox(height: 12),
          _buildToggleCard(
            icon: Icons.shopping_bag_outlined,
            title: "Refill Reminder",
            subtitle: "Alert when stock is low",
            value: _enableBuyReminder,
            onChanged: (val) => setState(() => _enableBuyReminder = val),
          ),
          if (_enableBuyReminder) ...[
            SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Current Stock (Tablets)",
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              onChanged: (val) => setState(() => _stockRemaining = int.tryParse(val) ?? 10),
            ),
          ],
          Spacer(),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
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
        child: Text("Continue"),
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
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saveMedicine,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: Row(
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
