import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../models/beverage_type.dart';
import '../models/water_container.dart';
import '../services/water_service.dart';

/// Screen for creating and customizing cups/containers
class CustomCupCreatorScreen extends StatefulWidget {
  final WaterContainer? existingContainer;
  
  const CustomCupCreatorScreen({super.key, this.existingContainer});

  @override
  State<CustomCupCreatorScreen> createState() => _CustomCupCreatorScreenState();
}

class _CustomCupCreatorScreenState extends State<CustomCupCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();
  
  String _selectedEmoji = '🥛';
  Color _selectedColor = AppColors.info;
  bool _isSaving = false;
  
  // Multi-ingredient support
  final List<CupIngredient> _ingredients = [];
  bool _isMultiIngredient = false;

  final List<String> _emojiOptions = [
    '🥛', '☕', '🍵', '🧃', '🧴', '🍼', '🥤', '🫗', '🫖', '🏃',
    '💧', '🧊', '🥥', '🍺', '🍷', '🥃', '🧋', '🫧', '🍹', '🥝',
  ];

  final List<Color> _colorOptions = [
    AppColors.info,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lime,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.pink,
    Colors.purple,
    Colors.indigo,
    Colors.brown,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingContainer != null) {
      final c = widget.existingContainer!;
      _nameController.text = c.name;
      _capacityController.text = c.capacityMl.toString();
      _selectedEmoji = c.emoji;
      if (c.colorHex != null) {
        _selectedColor = Color(int.parse(c.colorHex!.replaceFirst('#', '0xFF')));
      }
    } else {
      _capacityController.text = '250';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  int get _totalCapacity {
    if (_isMultiIngredient && _ingredients.isNotEmpty) {
      return _ingredients.fold(0, (sum, i) => sum + i.amountMl);
    }
    return int.tryParse(_capacityController.text) ?? 0;
  }

  int get _effectiveHydration {
    if (_isMultiIngredient && _ingredients.isNotEmpty) {
      int totalEffective = 0;
      for (final ing in _ingredients) {
        final beverage = WaterService.getBeverage(ing.beverageId);
        if (beverage != null) {
          totalEffective += beverage.getEffectiveHydration(ing.amountMl);
        }
      }
      return totalEffective;
    }
    return int.tryParse(_capacityController.text) ?? 0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final container = WaterContainer(
        id: widget.existingContainer?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        emoji: _selectedEmoji,
        capacityMl: _totalCapacity,
        colorHex: '#${_selectedColor.value.toRadixString(16).substring(2)}',
        usageCount: widget.existingContainer?.usageCount ?? 0,
        lastUsed: widget.existingContainer?.lastUsed,
      );

      if (widget.existingContainer != null) {
        await WaterService.updateContainer(container);
      } else {
        await WaterService.addCustomContainer(container);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addIngredient() {
    final beverages = WaterService.getAllBeverages();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _IngredientSelector(
        beverages: beverages,
        onSelected: (beverageId, amount) {
          setState(() {
            _ingredients.add(CupIngredient(
              beverageId: beverageId,
              amountMl: amount,
            ));
          });
        },
      ),
    );
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.existingContainer != null ? 'Edit Cup' : 'Create Custom Cup'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPreview(),
              const SizedBox(height: 24),
              _buildNameField(),
              const SizedBox(height: 20),
              _buildEmojiSelector(),
              const SizedBox(height: 20),
              _buildColorSelector(),
              const SizedBox(height: 20),
              _buildCapacitySection(),
              const SizedBox(height: 20),
              _buildMultiIngredientToggle(),
              if (_isMultiIngredient) ...[
                const SizedBox(height: 16),
                _buildIngredientsList(),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _selectedColor.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _selectedColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _selectedColor, width: 2),
              ),
              child: Center(
                child: Text(_selectedEmoji, style: const TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _nameController.text.isEmpty ? 'Cup Name' : _nameController.text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_totalCapacity}ml',
              style: TextStyle(
                fontSize: 14,
                color: _selectedColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_isMultiIngredient && _effectiveHydration != _totalCapacity)
              Text(
                'Effective: ${_effectiveHydration}ml',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cup Name',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'e.g., My Favorite Mug',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Icon',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _emojiOptions.map((emoji) {
              final isSelected = emoji == _selectedEmoji;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedEmoji = emoji);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? _selectedColor.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected ? Border.all(color: _selectedColor, width: 2) : null,
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Color',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colorOptions.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedColor = color);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacitySection() {
    if (_isMultiIngredient) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Capacity',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_totalCapacity}ml',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.info,
                    ),
                  ),
                  Text(
                    'from ${_ingredients.length} ingredients',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Capacity (ml)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _capacityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter capacity',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixText: 'ml',
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final n = int.tryParse(v);
              if (n == null || n <= 0) return 'Enter valid amount';
              return null;
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [100, 150, 250, 350, 500, 750, 1000].map((ml) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _capacityController.text = ml.toString();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${ml}ml'),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiIngredientToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multi-Ingredient Cup',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Mix different beverages for accurate hydration',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isMultiIngredient,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() {
                _isMultiIngredient = v;
                if (!v) _ingredients.clear();
              });
            },
            activeThumbColor: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ingredients',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              TextButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_ingredients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Tap "Add" to add ingredients',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ..._ingredients.asMap().entries.map((entry) {
              final index = entry.key;
              final ingredient = entry.value;
              final beverage = WaterService.getBeverage(ingredient.beverageId);
              
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      beverage?.emoji ?? '💧',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            beverage?.name ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${ingredient.amountMl}ml (${beverage?.hydrationPercent ?? 100}% hydration)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                      onPressed: () => _removeIngredient(index),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Model for cup ingredients
class CupIngredient {
  final String beverageId;
  final int amountMl;

  CupIngredient({required this.beverageId, required this.amountMl});
}

/// Bottom sheet for selecting ingredients
class _IngredientSelector extends StatefulWidget {
  final List<BeverageType> beverages;
  final Function(String beverageId, int amount) onSelected;

  const _IngredientSelector({
    required this.beverages,
    required this.onSelected,
  });

  @override
  State<_IngredientSelector> createState() => _IngredientSelectorState();
}

class _IngredientSelectorState extends State<_IngredientSelector> {
  BeverageType? _selectedBeverage;
  final _amountController = TextEditingController(text: '100');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Ingredient',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text('Select Beverage', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.beverages.length,
                itemBuilder: (context, index) {
                  final bev = widget.beverages[index];
                  final isSelected = _selectedBeverage?.id == bev.id;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedBeverage = bev);
                    },
                    child: Container(
                      width: 70,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.info.withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: AppColors.info, width: 2) : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(bev.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(
                            bev.name,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppColors.info : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const Text('Amount (ml)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixText: 'ml',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [50, 100, 150, 200, 250].map((ml) {
                return GestureDetector(
                  onTap: () {
                    _amountController.text = ml.toString();
                  },
                  child: Chip(label: Text('${ml}ml')),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedBeverage == null
                    ? null
                    : () {
                        final amount = int.tryParse(_amountController.text) ?? 0;
                        if (amount > 0) {
                          widget.onSelected(_selectedBeverage!.id, amount);
                          Navigator.pop(context);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Add Ingredient',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
