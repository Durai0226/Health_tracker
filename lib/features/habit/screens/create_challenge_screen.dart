import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/habit_service.dart';
import '../services/habit_social_service.dart';
import '../theme/habit_theme.dart';

/// Create Challenge Screen
/// Allows users to create habit challenges with friends
class CreateChallengeScreen extends StatefulWidget {
  final List<String>? initialFriendIds;

  const CreateChallengeScreen({super.key, this.initialFriendIds});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final HabitService _habitService = HabitService();
  final HabitSocialService _socialService = HabitSocialService();
  final _titleController = TextEditingController();

  List<String> _selectedHabitIds = [];
  List<String> _selectedFriendIds = [];
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    if (widget.initialFriendIds != null) {
      _selectedFriendIds = List.from(widget.initialFriendIds!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HabitTheme.background,
      appBar: AppBar(
        backgroundColor: HabitTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: HabitTheme.dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Create Challenge', style: HabitTheme.h2),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title input
            _buildTitleSection(),
            const SizedBox(height: 24),
            // Habits selection
            _buildHabitsSection(),
            const SizedBox(height: 24),
            // Friends selection
            _buildFriendsSection(),
            const SizedBox(height: 24),
            // Date selection
            _buildDateSection(),
            const SizedBox(height: 32),
            // Create button
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
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
          Text('Challenge Title', style: HabitTheme.label),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            style: HabitTheme.b1,
            decoration: InputDecoration(
              hintText: 'e.g., 30-Day Fitness Challenge',
              hintStyle: HabitTheme.b1.copyWith(color: HabitTheme.gray),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HabitTheme.radiusM),
                borderSide: BorderSide(color: HabitTheme.grayLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HabitTheme.radiusM),
                borderSide: BorderSide(color: HabitTheme.grayLight),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsSection() {
    final habits = _habitService.activeHabits;

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
              Text('Choose habits you want to challenge', style: HabitTheme.label),
              Text(
                '${_selectedHabitIds.length} selected',
                style: HabitTheme.caption.copyWith(color: HabitTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Selected habits chips
          if (_selectedHabitIds.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedHabitIds.map((id) {
                final habit = habits.firstWhere((h) => h.id == id);
                return Chip(
                  label: Text(habit.name),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() => _selectedHabitIds.remove(id));
                  },
                  backgroundColor: habit.color.withOpacity(0.15),
                  labelStyle: HabitTheme.b3.copyWith(color: habit.color),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          // Add habit button
          GestureDetector(
            onTap: () => _showHabitSelector(habits),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: HabitTheme.primary,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(HabitTheme.radiusM),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: HabitTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'List of active habits',
                    style: HabitTheme.b2.copyWith(color: HabitTheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsSection() {
    final friends = _socialService.acceptedFriends;

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
              Text('Invite friends', style: HabitTheme.label),
              Text(
                '${_selectedFriendIds.length} selected',
                style: HabitTheme.caption.copyWith(color: HabitTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Friends list
          if (friends.isEmpty)
            Center(
              child: Text(
                'No friends to invite. Add friends first!',
                style: HabitTheme.b3.copyWith(color: HabitTheme.gray),
              ),
            )
          else
            ...friends.map((friend) {
              final isSelected = _selectedFriendIds.contains(friend.oderId);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isSelected) {
                      _selectedFriendIds.remove(friend.oderId);
                    } else {
                      _selectedFriendIds.add(friend.oderId);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: HabitTheme.grayLight,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: HabitTheme.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            friend.displayName.substring(0, 1).toUpperCase(),
                            style: HabitTheme.b1.copyWith(
                              color: HabitTheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          friend.displayName,
                          style: HabitTheme.b2,
                        ),
                      ),
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedFriendIds.add(friend.oderId);
                            } else {
                              _selectedFriendIds.remove(friend.oderId);
                            }
                          });
                        },
                        activeColor: HabitTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
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
          Text('Challenge Duration', style: HabitTheme.label),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(
                  'Start Date',
                  _startDate,
                  (date) => setState(() => _startDate = date),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDatePicker(
                  'End Date',
                  _endDate,
                  (date) => setState(() => _endDate = date),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${_endDate.difference(_startDate).inDays + 1} days',
              style: HabitTheme.b2.copyWith(
                color: HabitTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime date,
    ValueChanged<DateTime> onChanged,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: HabitTheme.grayLight),
          borderRadius: BorderRadius.circular(HabitTheme.radiusM),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: HabitTheme.caption),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatDate(date),
                  style: HabitTheme.b2,
                ),
                const Spacer(),
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: HabitTheme.gray,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final isValid = _titleController.text.isNotEmpty &&
        _selectedHabitIds.isNotEmpty &&
        _selectedFriendIds.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isValid ? _createChallenge : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: HabitTheme.primary,
          foregroundColor: HabitTheme.white,
          disabledBackgroundColor: HabitTheme.grayLight,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
          ),
          elevation: 0,
        ),
        child: Text('CREATE CHALLENGE', style: HabitTheme.button),
      ),
    );
  }

  void _showHabitSelector(List<Habit> habits) {
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
            Text('Select Habits', style: HabitTheme.h2),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: habits.length,
                itemBuilder: (context, index) {
                  final habit = habits[index];
                  final isSelected = _selectedHabitIds.contains(habit.id);
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: habit.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(habit.icon, color: habit.color, size: 20),
                    ),
                    title: Text(habit.name),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedHabitIds.add(habit.id);
                          } else {
                            _selectedHabitIds.remove(habit.id);
                          }
                        });
                        Navigator.pop(context);
                      },
                      activeColor: HabitTheme.primary,
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedHabitIds.remove(habit.id);
                        } else {
                          _selectedHabitIds.add(habit.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _createChallenge() async {
    HapticFeedback.mediumImpact();

    final habitNames = _selectedHabitIds.map((id) {
      final habit = _habitService.getHabit(id);
      return habit?.name ?? '';
    }).where((name) => name.isNotEmpty).toList();

    final challenge = await _socialService.createChallenge(
      title: _titleController.text.trim(),
      habitIds: _selectedHabitIds,
      habitNames: habitNames,
      invitedFriendIds: _selectedFriendIds,
      startDate: _startDate,
      endDate: _endDate,
    );

    if (challenge != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challenge created! Invites sent to friends.'),
          backgroundColor: HabitTheme.success,
        ),
      );
      Navigator.pop(context);
    }
  }
}
