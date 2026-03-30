import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/habit_service.dart';
import '../theme/habit_theme.dart';

/// Character Selection/Customization Screen
/// Allows users to customize their avatar appearance
class CharacterSelectionScreen extends StatefulWidget {
  final bool isOnboarding;

  const CharacterSelectionScreen({
    super.key,
    this.isOnboarding = false,
  });

  @override
  State<CharacterSelectionScreen> createState() => _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen>
    with TickerProviderStateMixin {
  final HabitService _habitService = HabitService();

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  
  CharacterPart _selectedPart = CharacterPart.head;
  int _headIndex = 0;
  int _topIndex = 0;
  int _bottomIndex = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadCurrentCharacter();
  }

  void _initAnimations() {
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _bounceAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  void _loadCurrentCharacter() {
    final character = _habitService.character;
    if (character != null) {
      setState(() {
        _headIndex = character.headIndex;
        _topIndex = character.topIndex;
        _bottomIndex = character.bottomIndex;
      });
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8E7), // Warm cream
              Color(0xFFE8F4F8), // Light blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              // Character preview
              Expanded(child: _buildCharacterPreview()),
              // Part selector
              _buildPartSelector(),
              // Options carousel
              _buildOptionsCarousel(),
              const SizedBox(height: 20),
              // Done button
              _buildDoneButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!widget.isOnboarding)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 48),
          Text(
            'Choose your character',
            style: HabitTheme.h2.copyWith(color: HabitTheme.primary),
          ),
          TextButton(
            onPressed: _saveAndFinish,
            child: Text(
              'Done',
              style: HabitTheme.b1.copyWith(
                color: HabitTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterPreview() {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_bounceAnimation.value),
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background scenery
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildScenery(),
          ),
          // Character
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Navigation arrows
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: HabitTheme.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left, color: HabitTheme.gray),
                    ),
                    onPressed: () => _changeCharacterIndex(-1),
                  ),
                  const SizedBox(width: 100),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: HabitTheme.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_right, color: HabitTheme.gray),
                    ),
                    onPressed: () => _changeCharacterIndex(1),
                  ),
                ],
              ),
              // Character display
              Container(
                width: 200,
                height: 280,
                decoration: BoxDecoration(
                  color: HabitTheme.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Placeholder character illustration
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Head
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _getHeadColor(_headIndex),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _getHeadEmoji(_headIndex),
                              style: const TextStyle(fontSize: 40),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Top/Body
                        Container(
                          width: 100,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _getTopColor(_topIndex),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(40),
                              bottom: Radius.circular(20),
                            ),
                          ),
                        ),
                        // Bottom/Legs
                        Container(
                          width: 80,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _getBottomColor(_bottomIndex),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScenery() {
    return SizedBox(
      height: 120,
      child: Stack(
        children: [
          // Ground
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green.shade200,
                    Colors.green.shade300,
                  ],
                ),
              ),
            ),
          ),
          // Bushes
          Positioned(
            bottom: 30,
            left: 20,
            child: _buildBush(),
          ),
          Positioned(
            bottom: 30,
            right: 30,
            child: _buildBush(),
          ),
          // Street lamp
          Positioned(
            bottom: 40,
            left: 60,
            child: _buildStreetLamp(),
          ),
        ],
      ),
    );
  }

  Widget _buildBush() {
    return Container(
      width: 60,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.green.shade400,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildStreetLamp() {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.amber.shade200,
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 4,
          height: 50,
          color: Colors.grey.shade600,
        ),
      ],
    );
  }

  Widget _buildPartSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HabitTheme.grayLight,
        borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
      ),
      child: Row(
        children: CharacterPart.values.map((part) {
          final isSelected = _selectedPart == part;
          final label = switch (part) {
            CharacterPart.head => 'Head',
            CharacterPart.top => 'Top',
            CharacterPart.bottom => 'Bottom',
          };
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedPart = part);
              },
              child: AnimatedContainer(
                duration: HabitTheme.animationFast,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? HabitTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: HabitTheme.b2.copyWith(
                      color: isSelected ? HabitTheme.white : HabitTheme.gray,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOptionsCarousel() {
    final count = switch (_selectedPart) {
      CharacterPart.head => HabitCharacter.headStylesCount,
      CharacterPart.top => HabitCharacter.topStylesCount,
      CharacterPart.bottom => HabitCharacter.bottomStylesCount,
    };
    
    final currentIndex = switch (_selectedPart) {
      CharacterPart.head => _headIndex,
      CharacterPart.top => _topIndex,
      CharacterPart.bottom => _bottomIndex,
    };

    return Container(
      height: 80,
      margin: const EdgeInsets.only(top: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: count,
        itemBuilder: (context, index) {
          final isSelected = index == currentIndex;
          
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                switch (_selectedPart) {
                  case CharacterPart.head:
                    _headIndex = index;
                    break;
                  case CharacterPart.top:
                    _topIndex = index;
                    break;
                  case CharacterPart.bottom:
                    _bottomIndex = index;
                    break;
                }
              });
            },
            child: AnimatedContainer(
              duration: HabitTheme.animationFast,
              width: 60,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: _getOptionColor(index),
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(color: HabitTheme.primary, width: 3)
                    : null,
                boxShadow: isSelected ? HabitTheme.cardShadow : null,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: HabitTheme.b1.copyWith(
                    color: HabitTheme.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDoneButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saveAndFinish,
          style: ElevatedButton.styleFrom(
            backgroundColor: HabitTheme.primary,
            foregroundColor: HabitTheme.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
            ),
            elevation: 0,
          ),
          child: Text(
            widget.isOnboarding ? 'Continue' : 'Save Changes',
            style: HabitTheme.button,
          ),
        ),
      ),
    );
  }

  void _changeCharacterIndex(int delta) {
    HapticFeedback.lightImpact();
    setState(() {
      switch (_selectedPart) {
        case CharacterPart.head:
          _headIndex = (_headIndex + delta) % HabitCharacter.headStylesCount;
          if (_headIndex < 0) _headIndex = HabitCharacter.headStylesCount - 1;
          break;
        case CharacterPart.top:
          _topIndex = (_topIndex + delta) % HabitCharacter.topStylesCount;
          if (_topIndex < 0) _topIndex = HabitCharacter.topStylesCount - 1;
          break;
        case CharacterPart.bottom:
          _bottomIndex = (_bottomIndex + delta) % HabitCharacter.bottomStylesCount;
          if (_bottomIndex < 0) _bottomIndex = HabitCharacter.bottomStylesCount - 1;
          break;
      }
    });
  }

  Color _getHeadColor(int index) {
    final colors = [
      const Color(0xFFFFE4C4), // Bisque
      const Color(0xFFDEB887), // Burlywood
      const Color(0xFFD2B48C), // Tan
      const Color(0xFFF5DEB3), // Wheat
      const Color(0xFFFFDAB9), // Peach
      const Color(0xFFFAEBD7), // Antique white
      const Color(0xFFCD853F), // Peru
      const Color(0xFF8B4513), // Saddle brown
    ];
    return colors[index % colors.length];
  }

  Color _getTopColor(int index) {
    final colors = [
      const Color(0xFF7C91F4), // Primary blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF795548), // Brown
      const Color(0xFF607D8B), // Blue grey
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFF3F51B5), // Indigo
    ];
    return colors[index % colors.length];
  }

  Color _getBottomColor(int index) {
    final colors = [
      const Color(0xFF1A237E), // Dark blue
      const Color(0xFF212121), // Black
      const Color(0xFF5D4037), // Brown
      const Color(0xFF37474F), // Dark grey
      const Color(0xFF880E4F), // Maroon
      const Color(0xFF1B5E20), // Dark green
      const Color(0xFF311B92), // Deep purple
      const Color(0xFF01579B), // Light blue dark
    ];
    return colors[index % colors.length];
  }

  Color _getOptionColor(int index) {
    return switch (_selectedPart) {
      CharacterPart.head => _getHeadColor(index),
      CharacterPart.top => _getTopColor(index),
      CharacterPart.bottom => _getBottomColor(index),
    };
  }

  String _getHeadEmoji(int index) {
    final emojis = ['😊', '😄', '🙂', '😎', '🤗', '😇', '🥰', '😏'];
    return emojis[index % emojis.length];
  }

  Future<void> _saveAndFinish() async {
    HapticFeedback.mediumImpact();
    
    await _habitService.updateCharacter(
      headIndex: _headIndex,
      topIndex: _topIndex,
      bottomIndex: _bottomIndex,
    );

    if (mounted) {
      if (widget.isOnboarding) {
        // Navigate to main dashboard
        Navigator.pushReplacementNamed(context, '/habit');
      } else {
        Navigator.pop(context);
      }
    }
  }
}
