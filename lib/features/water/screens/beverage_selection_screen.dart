import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/common_tab_widgets.dart';
import '../models/beverage_type.dart';
import '../models/enhanced_water_log.dart';
import '../models/water_container.dart';
import '../services/water_service.dart';

/// Beverage selection screen - allows users to log different drink types
class BeverageSelectionScreen extends StatefulWidget {
  final int? preSelectedAmount;
  
  const BeverageSelectionScreen({super.key, this.preSelectedAmount});

  @override
  State<BeverageSelectionScreen> createState() => _BeverageSelectionScreenState();
}

class _BeverageSelectionScreenState extends State<BeverageSelectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  BeverageType? _selectedBeverage;
  WaterContainer? _selectedContainer;
  int _customAmount = 250;
  bool _isLogging = false;

  final List<String> _categories = [
    'All',
    'Water',
    'Hot Drinks',
    'Cold Drinks',
    'Alcohol',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    if (widget.preSelectedAmount != null) {
      _customAmount = widget.preSelectedAmount!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BeverageType> _getFilteredBeverages(String category) {
    final all = WaterService.getAllBeverages();
    switch (category) {
      case 'Water':
        return all.where((b) => b.id.contains('water') || b.id == 'sparkling_water').toList();
      case 'Hot Drinks':
        return all.where((b) => 
          b.id.contains('coffee') || 
          b.id.contains('tea') || 
          b.id == 'espresso'
        ).toList();
      case 'Cold Drinks':
        return all.where((b) => 
          !b.isAlcoholic && 
          !b.id.contains('coffee') && 
          !b.id.contains('tea') &&
          !b.id.contains('water') &&
          b.id != 'espresso'
        ).toList();
      case 'Alcohol':
        return all.where((b) => b.isAlcoholic).toList();
      default:
        return all;
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.info;
    }
  }

  Future<void> _logDrink() async {
    if (_selectedBeverage == null || _isLogging) return;

    setState(() => _isLogging = true);
    HapticFeedback.mediumImpact();

    try {
      final data = await WaterService.addWaterLog(
        amountMl: _customAmount,
        beverage: _selectedBeverage!,
        container: _selectedContainer,
      );

      if (mounted) {
        final effectiveHydration = _selectedBeverage!.getEffectiveHydration(_customAmount);
        final isNegative = effectiveHydration < 0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(_selectedBeverage!.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${_customAmount}ml ${_selectedBeverage!.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        isNegative
                            ? 'Dehydration: ${effectiveHydration}ml'
                            : 'Hydration: +${effectiveHydration}ml',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.goalReached)
                  const Text('🎉', style: TextStyle(fontSize: 24)),
              ],
            ),
            backgroundColor: isNegative ? AppColors.warning : AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error logging drink: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging drink: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Drink'),
        bottom: CommonTabBar(
          tabs: _categories,
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.info,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: CommonTabView(
              controller: _tabController,
              children: _categories.map((category) {
                return _buildBeverageGrid(category);
              }).toList(),
            ),
          ),
          _buildAmountSelector(),
          _buildContainerSelector(),
          _buildLogButton(),
        ],
      ),
    );
  }

  Widget _buildBeverageGrid(String category) {
    final beverages = _getFilteredBeverages(category);
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: beverages.length,
      itemBuilder: (context, index) {
        final beverage = beverages[index];
        final isSelected = _selectedBeverage?.id == beverage.id;
        final color = _parseColor(beverage.colorHex);

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedBeverage = beverage;
              _customAmount = beverage.defaultAmountMl;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  beverage.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(height: 8),
                Text(
                  beverage.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? color : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: beverage.hydrationPercent >= 80
                        ? AppColors.success.withOpacity(0.1)
                        : beverage.hydrationPercent >= 50
                            ? AppColors.warning.withOpacity(0.1)
                            : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${beverage.hydrationPercent}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: beverage.hydrationPercent >= 80
                          ? AppColors.success
                          : beverage.hydrationPercent >= 50
                              ? AppColors.warning
                              : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmountSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Amount',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (_selectedBeverage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Hydration: ${_selectedBeverage!.getEffectiveHydration(_customAmount)}ml',
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedBeverage!.hydrationPercent >= 0
                          ? AppColors.info
                          : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _customAmount = (_customAmount - 50).clamp(50, 2000);
                  });
                  HapticFeedback.selectionClick();
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, color: AppColors.info),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_customAmount}ml',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _customAmount = (_customAmount + 50).clamp(50, 2000);
                  });
                  HapticFeedback.selectionClick();
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: AppColors.info),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.info,
              inactiveTrackColor: AppColors.info.withOpacity(0.2),
              thumbColor: AppColors.info,
              overlayColor: AppColors.info.withOpacity(0.1),
            ),
            child: Slider(
              value: _customAmount.toDouble(),
              min: 50,
              max: 2000,
              divisions: 39,
              onChanged: (value) {
                setState(() => _customAmount = value.round());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContainerSelector() {
    final containers = WaterService.getFrequentContainers(limit: 5);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Quick Select Container',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: containers.length,
              itemBuilder: (context, index) {
                final container = containers[index];
                final isSelected = _selectedContainer?.id == container.id;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedContainer = isSelected ? null : container;
                      if (!isSelected) _customAmount = container.capacityMl;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.info.withOpacity(0.15) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.info : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(container.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(
                          '${container.capacityMl}ml',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.info : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogButton() {
    final canLog = _selectedBeverage != null;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: CommonButton(
        text: 'Log ${_customAmount}ml${_selectedBeverage != null ? ' ${_selectedBeverage!.name}' : ''}',
        icon: Icons.local_drink,
        variant: ButtonVariant.primary,
        backgroundColor: canLog ? AppColors.info : Colors.grey.shade300,
        isLoading: _isLogging,
        onPressed: canLog && !_isLogging ? _logDrink : null,
      ),
    );
  }
}
