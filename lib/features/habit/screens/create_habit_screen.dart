import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/habit_service.dart';
import '../theme/habit_theme.dart';
import '../widgets/week_selector.dart';

/// Create/Edit Habit Screen
/// Matches the Habit Land create habit flow design
class CreateHabitScreen extends StatefulWidget {
  final Habit? existingHabit;

  const CreateHabitScreen({super.key, this.existingHabit});

  @override
  State<CreateHabitScreen> createState() => _CreateHabitScreenState();
}

class _CreateHabitScreenState extends State<CreateHabitScreen> {
  final HabitService _habitService = HabitService();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _targetUnitController = TextEditingController();

  bool get isEditing => widget.existingHabit != null;

  // Form state
  HabitType _habitType = HabitType.regular;
  int _selectedIconIndex = 0;
  int _selectedColorIndex = 11; // Primary color
  RepeatType _repeatType = RepeatType.daily;
  List<int> _selectedDays = [0, 1, 2, 3, 4, 5, 6];
  int _repeatXDays = 2;
  int _daysPerWeek = 4;
  HabitTimeOfDay _timeOfDay = HabitTimeOfDay.anytime;
  bool _hasTarget = false;
  String? _selectedGroupId;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadExistingHabit();
    }
  }

  void _loadExistingHabit() {
    final habit = widget.existingHabit!;
    _nameController.text = habit.name;
    _habitType = habit.habitType;
    _selectedIconIndex = HabitTheme.habitIcons.indexWhere(
      (icon) => icon.codePoint == habit.iconCodePoint,
    );
    if (_selectedIconIndex < 0) _selectedIconIndex = 0;
    _selectedColorIndex = HabitTheme.habitColors.indexWhere(
      (color) => color.value == habit.colorValue,
    );
    if (_selectedColorIndex < 0) _selectedColorIndex = 11;
    _repeatType = habit.repeatType;
    _selectedDays = List.from(habit.repeatDays);
    _repeatXDays = habit.repeatXDays;
    _daysPerWeek = habit.daysPerWeek;
    _timeOfDay = habit.timeOfDay;
    _hasTarget = habit.hasTarget;
    if (habit.targetValue != null) {
      _targetController.text = habit.targetValue.toString();
    }
    if (habit.targetUnit != null) {
      _targetUnitController.text = habit.targetUnit!;
    }
    _selectedGroupId = habit.groupId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _targetUnitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HabitTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: HabitTheme.dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Habit' : 'Regular habit',
          style: HabitTheme.h2,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Habit type selector (for new habits)
            if (!isEditing) _buildHabitTypeSelector(),
            const SizedBox(height: 24),
            
            // Icon and name input
            _buildIconAndName(),
            const SizedBox(height: 24),
            
            // Target toggle
            _buildTargetSection(),
            const SizedBox(height: 24),
            
            // Repeat habit section
            _buildRepeatSection(),
            const SizedBox(height: 24),
            
            // Time of day
            _buildTimeOfDaySection(),
            const SizedBox(height: 24),
            
            // Advanced settings
            _buildAdvancedSettings(),
            const SizedBox(height: 32),
            
            // Create button
            _buildCreateButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTypeOption(
            'Create a regular habit',
            HabitType.regular,
            Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTypeOption(
            'Break a bad habit',
            HabitType.breakBad,
            Icons.block,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeOption(String label, HabitType type, IconData icon) {
    final isSelected = _habitType == type;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _habitType = type);
      },
      child: AnimatedContainer(
        duration: HabitTheme.animationFast,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? HabitTheme.primary : HabitTheme.white,
          borderRadius: BorderRadius.circular(HabitTheme.radiusL),
          border: Border.all(
            color: isSelected ? HabitTheme.primary : HabitTheme.grayLight,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? HabitTheme.white : HabitTheme.gray,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: HabitTheme.b3.copyWith(
                color: isSelected ? HabitTheme.white : HabitTheme.dark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconAndName() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Selected icon preview
              GestureDetector(
                onTap: _showIconPicker,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: HabitTheme.habitColors[_selectedColorIndex]
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(HabitTheme.radiusM),
                  ),
                  child: Icon(
                    HabitTheme.habitIcons[_selectedIconIndex],
                    color: HabitTheme.habitColors[_selectedColorIndex],
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name input
              Expanded(
                child: TextField(
                  controller: _nameController,
                  style: HabitTheme.b1,
                  decoration: InputDecoration(
                    hintText: 'Habit name',
                    hintStyle: HabitTheme.b1.copyWith(color: HabitTheme.gray),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              // Edit icon button
              IconButton(
                onPressed: _showIconPicker,
                icon: Icon(
                  Icons.edit_outlined,
                  color: HabitTheme.gray,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Set your target', style: HabitTheme.b1),
              Switch(
                value: _hasTarget,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _hasTarget = value);
                },
                activeColor: HabitTheme.primary,
              ),
            ],
          ),
          if (_hasTarget) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    style: HabitTheme.b1,
                    decoration: InputDecoration(
                      hintText: '30',
                      hintStyle: HabitTheme.b1.copyWith(color: HabitTheme.gray),
                      filled: true,
                      fillColor: HabitTheme.grayLight.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HabitTheme.radiusS),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _targetUnitController,
                    style: HabitTheme.b1,
                    decoration: InputDecoration(
                      hintText: 'mins, km, glasses...',
                      hintStyle: HabitTheme.b1.copyWith(color: HabitTheme.gray),
                      filled: true,
                      fillColor: HabitTheme.grayLight.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HabitTheme.radiusS),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepeatSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Repeat habit', style: HabitTheme.b1),
          const SizedBox(height: 16),
          // Repeat type options
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRepeatOption('Daily', RepeatType.daily),
              _buildRepeatOption('Weekly', RepeatType.weekly),
              _buildRepeatOption('Monthly', RepeatType.monthly),
              _buildRepeatOption('Every x days', RepeatType.everyXDays),
            ],
          ),
          const SizedBox(height: 20),
          // Day selector or custom options
          if (_repeatType == RepeatType.daily) ...[
            Text(
              'On these day',
              style: HabitTheme.b3.copyWith(color: HabitTheme.gray),
            ),
            const SizedBox(height: 12),
            DayPillSelector(
              selectedDays: _selectedDays,
              onChanged: (days) => setState(() => _selectedDays = days),
            ),
          ] else if (_repeatType == RepeatType.weekly) ...[
            Text(
              '${_daysPerWeek} days per week',
              style: HabitTheme.b3.copyWith(color: HabitTheme.gray),
            ),
            Slider(
              value: _daysPerWeek.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              activeColor: HabitTheme.primary,
              onChanged: (value) {
                setState(() => _daysPerWeek = value.toInt());
              },
            ),
          ] else if (_repeatType == RepeatType.everyXDays) ...[
            Row(
              children: [
                Text('Every ', style: HabitTheme.b2),
                SizedBox(
                  width: 60,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: HabitTheme.b1.copyWith(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HabitTheme.radiusS),
                      ),
                    ),
                    controller: TextEditingController(text: '$_repeatXDays'),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        setState(() => _repeatXDays = parsed);
                      }
                    },
                  ),
                ),
                Text(' days', style: HabitTheme.b2),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepeatOption(String label, RepeatType type) {
    final isSelected = _repeatType == type;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _repeatType = type);
      },
      child: AnimatedContainer(
        duration: HabitTheme.animationFast,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? HabitTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
          border: Border.all(
            color: isSelected ? HabitTheme.primary : HabitTheme.grayLight,
          ),
        ),
        child: Text(
          label,
          style: HabitTheme.b3.copyWith(
            color: isSelected ? HabitTheme.white : HabitTheme.dark,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeOfDaySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('I will do it at', style: HabitTheme.b1),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HabitTimeOfDay.values.map((time) {
              final isSelected = _timeOfDay == time;
              final label = switch (time) {
                HabitTimeOfDay.anytime => 'Anytime',
                HabitTimeOfDay.morning => 'Morning',
                HabitTimeOfDay.afternoon => 'Afternoon',
                HabitTimeOfDay.evening => 'Evening',
              };
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _timeOfDay = time);
                },
                child: AnimatedContainer(
                  duration: HabitTheme.animationFast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? HabitTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
                    border: Border.all(
                      color: isSelected
                          ? HabitTheme.primary
                          : HabitTheme.grayLight,
                    ),
                  ),
                  child: Text(
                    label,
                    style: HabitTheme.b3.copyWith(
                      color: isSelected ? HabitTheme.white : HabitTheme.dark,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HabitTheme.white,
              borderRadius: BorderRadius.circular(HabitTheme.radiusL),
              boxShadow: HabitTheme.subtleShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ADVANCE SETTINGS', style: HabitTheme.label),
                Icon(
                  _showAdvanced
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_right,
                  color: HabitTheme.gray,
                ),
              ],
            ),
          ),
        ),
        if (_showAdvanced) ...[
          const SizedBox(height: 16),
          // Color picker
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HabitTheme.white,
              borderRadius: BorderRadius.circular(HabitTheme.radiusL),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Color', style: HabitTheme.b2),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(
                    HabitTheme.habitColors.length,
                    (index) => GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedColorIndex = index);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: HabitTheme.habitColors[index],
                          shape: BoxShape.circle,
                          border: _selectedColorIndex == index
                              ? Border.all(color: HabitTheme.dark, width: 2)
                              : null,
                        ),
                        child: _selectedColorIndex == index
                            ? const Icon(
                                Icons.check,
                                color: HabitTheme.white,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _createHabit,
        style: ElevatedButton.styleFrom(
          backgroundColor: HabitTheme.primary,
          foregroundColor: HabitTheme.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HabitTheme.radiusL),
          ),
          elevation: 0,
        ),
        child: Text(
          isEditing ? 'SAVE CHANGES' : 'CREATE',
          style: HabitTheme.button,
        ),
      ),
    );
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HabitTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HabitTheme.grayLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Choose Icon', style: HabitTheme.h2),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                HabitTheme.habitIcons.length,
                (index) => GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedIconIndex = index);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _selectedIconIndex == index
                          ? HabitTheme.primary.withOpacity(0.15)
                          : HabitTheme.grayLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: _selectedIconIndex == index
                          ? Border.all(color: HabitTheme.primary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      HabitTheme.habitIcons[index],
                      color: _selectedIconIndex == index
                          ? HabitTheme.primary
                          : HabitTheme.gray,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _createHabit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a habit name')),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    final targetValue = _hasTarget
        ? double.tryParse(_targetController.text)
        : null;
    final targetUnit = _hasTarget && _targetUnitController.text.isNotEmpty
        ? _targetUnitController.text.trim()
        : null;

    if (isEditing) {
      await _habitService.updateHabit(
        widget.existingHabit!.copyWith(
          name: name,
          iconCodePoint: HabitTheme.habitIcons[_selectedIconIndex].codePoint,
          colorValue: HabitTheme.habitColors[_selectedColorIndex].value,
          habitType: _habitType,
          repeatType: _repeatType,
          repeatDays: _selectedDays,
          repeatXDays: _repeatXDays,
          daysPerWeek: _daysPerWeek,
          timeOfDay: _timeOfDay,
          hasTarget: _hasTarget,
          targetValue: targetValue,
          targetUnit: targetUnit,
          groupId: _selectedGroupId,
        ),
      );
    } else {
      await _habitService.createHabit(
        name: name,
        iconCodePoint: HabitTheme.habitIcons[_selectedIconIndex].codePoint,
        colorValue: HabitTheme.habitColors[_selectedColorIndex].value,
        habitType: _habitType,
        repeatType: _repeatType,
        repeatDays: _selectedDays,
        repeatXDays: _repeatXDays,
        daysPerWeek: _daysPerWeek,
        timeOfDay: _timeOfDay,
        hasTarget: _hasTarget,
        targetValue: targetValue,
        targetUnit: targetUnit,
        groupId: _selectedGroupId,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
