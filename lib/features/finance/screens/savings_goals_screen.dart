import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';
import '../widgets/savings_goal_card.dart';
import '../widgets/add_savings_goal_dialog.dart';

/// Screen for managing savings goals
class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FinanceSavingsGoal> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await FinanceService.init();
    setState(() {
      _goals = FinanceService.getSavingsGoals(includeArchived: true);
      _isLoading = false;
    });
  }

  List<FinanceSavingsGoal> get _activeGoals =>
      _goals.where((g) => !g.isCompleted && !g.isArchived).toList();

  List<FinanceSavingsGoal> get _completedGoals =>
      _goals.where((g) => g.isCompleted && !g.isArchived).toList();

  List<FinanceSavingsGoal> get _archivedGoals =>
      _goals.where((g) => g.isArchived).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceTheme.background,
      appBar: AppBar(
        backgroundColor: FinanceTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: FinanceTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Savings Goals', style: FinanceTheme.headingL),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: FinanceTheme.primary,
            labelColor: FinanceTheme.primary,
            unselectedLabelColor: FinanceTheme.textSecondary,
            labelStyle: FinanceTheme.bodyM.copyWith(fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Active (${_activeGoals.length})'),
              Tab(text: 'Completed (${_completedGoals.length})'),
              Tab(text: 'Archived (${_archivedGoals.length})'),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary card
                _buildSummaryCard(),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGoalsList(_activeGoals, 'No active goals'),
                      _buildGoalsList(_completedGoals, 'No completed goals'),
                      _buildGoalsList(_archivedGoals, 'No archived goals'),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalDialog(),
        backgroundColor: FinanceTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Goal', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalSaved = FinanceService.getTotalSavingsAmount();
    final totalTarget = _activeGoals.fold(0.0, (sum, g) => sum + g.targetAmount);
    final progress = totalTarget > 0 ? (totalSaved / totalTarget * 100) : 0;

    return Container(
      margin: const EdgeInsets.all(FinanceTheme.spacingM),
      padding: const EdgeInsets.all(FinanceTheme.spacingL),
      decoration: BoxDecoration(
        gradient: FinanceTheme.cardGradient,
        borderRadius: FinanceTheme.borderRadiusXL,
        boxShadow: FinanceTheme.shadowMedium,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Saved',
                    style: FinanceTheme.labelM.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FinanceService.formatCurrency(totalSaved),
                    style: FinanceTheme.currency.copyWith(fontSize: 28),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FinanceTheme.spacingM,
                  vertical: FinanceTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: FinanceTheme.borderRadiusM,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${progress.toStringAsFixed(1)}%',
                      style: FinanceTheme.bodyM.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FinanceTheme.spacingM),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: FinanceTheme.spacingS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'of ${FinanceService.formatCurrency(totalTarget)} target',
                style: FinanceTheme.bodyS.copyWith(color: Colors.white70),
              ),
              Text(
                '${_activeGoals.length} active goals',
                style: FinanceTheme.bodyS.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsList(List<FinanceSavingsGoal> goals, String emptyMessage) {
    if (goals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.savings_outlined, size: 64, color: FinanceTheme.textLight),
            const SizedBox(height: FinanceTheme.spacingM),
            Text(
              emptyMessage,
              style: FinanceTheme.bodyL.copyWith(color: FinanceTheme.textSecondary),
            ),
            const SizedBox(height: FinanceTheme.spacingS),
            if (emptyMessage == 'No active goals')
              ElevatedButton(
                onPressed: () => _showAddGoalDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinanceTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create Your First Goal'),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(FinanceTheme.spacingM),
        itemCount: goals.length,
        itemBuilder: (context, index) {
          final goal = goals[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: FinanceTheme.spacingM),
            child: SavingsGoalCard(
              goal: goal,
              onTap: () => _showGoalDetail(goal),
              onAddContribution: goal.isCompleted ? null : () => _showAddContribution(goal),
            ),
          );
        },
      ),
    );
  }

  void _showAddGoalDialog() {
    AddSavingsGoalDialog.show(
      context,
      onSaved: _loadData,
    );
  }

  void _showGoalDetail(FinanceSavingsGoal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GoalDetailSheet(
        goal: goal,
        onEdit: () {
          Navigator.pop(context);
          AddSavingsGoalDialog.show(
            context,
            existingGoal: goal,
            onSaved: _loadData,
          );
        },
        onArchive: () async {
          Navigator.pop(context);
          await FinanceService.updateSavingsGoal(
            goal.copyWith(isArchived: !goal.isArchived),
          );
          _loadData();
        },
        onDelete: () async {
          Navigator.pop(context);
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Goal?'),
              content: Text('Are you sure you want to delete "${goal.name}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FinanceTheme.expense,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await FinanceService.deleteSavingsGoal(goal.id);
            _loadData();
          }
        },
      ),
    );
  }

  void _showAddContribution(FinanceSavingsGoal goal) {
    AddContributionDialog.show(
      context,
      goal: goal,
      onSaved: _loadData,
    );
  }
}

class _GoalDetailSheet extends StatelessWidget {
  final FinanceSavingsGoal goal;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _GoalDetailSheet({
    required this.goal,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FinanceTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(FinanceTheme.spacingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FinanceTheme.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: FinanceTheme.spacingL),

          // Goal header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: goal.color.withValues(alpha: 0.15),
                  borderRadius: FinanceTheme.borderRadiusM,
                ),
                child: Icon(goal.icon, color: goal.color, size: 28),
              ),
              const SizedBox(width: FinanceTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name, style: FinanceTheme.headingM),
                    Text(
                      '${goal.progress.toStringAsFixed(1)}% complete',
                      style: FinanceTheme.bodyM.copyWith(
                        color: FinanceTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FinanceTheme.spacingL),

          // Progress
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progress / 100,
              backgroundColor: goal.color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(goal.color),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: FinanceTheme.spacingM),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Saved',
                  value: FinanceService.formatCurrency(goal.currentAmount),
                  color: goal.color,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Remaining',
                  value: FinanceService.formatCurrency(goal.remaining),
                  color: FinanceTheme.textSecondary,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Target',
                  value: FinanceService.formatCurrency(goal.targetAmount),
                  color: FinanceTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: FinanceTheme.spacingL),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FinanceTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: FinanceTheme.spacingS),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onArchive,
                  icon: Icon(goal.isArchived ? Icons.unarchive : Icons.archive, size: 18),
                  label: Text(goal.isArchived ? 'Restore' : 'Archive'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FinanceTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: FinanceTheme.spacingS),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FinanceTheme.expense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FinanceTheme.spacingM),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: FinanceTheme.labelS.copyWith(color: FinanceTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: FinanceTheme.bodyM.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
