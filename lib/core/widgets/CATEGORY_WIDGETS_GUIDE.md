# Premium Category Selection Widgets Guide

## Overview
Modern, compact, and premium category selection widgets that provide an excellent user experience aligned with the app's theme.

## Available Widgets

### 1. PremiumCategorySelector
**Use Case:** Full-screen category selection with grid layout
**Best For:** Onboarding, settings, main category selection

```dart
PremiumCategorySelector(
  initialCategory: AppCategory.health,
  showHeader: true,
  onCategorySelected: (category) {
    print('Selected: ${category.name}');
  },
)
```

**Features:**
- ✨ Animated grid layout (2 columns)
- 🎨 Gradient backgrounds with category colors
- 💫 Smooth scale animations on load
- ✓ Selection indicators with checkmarks
- 📊 Feature count badges
- 🎯 Premium glassmorphism effects

---

### 2. CompactCategorySelector
**Use Case:** Horizontal scrolling category selector
**Best For:** Modals, bottom sheets, inline selections

```dart
CompactCategorySelector(
  initialCategory: AppCategory.productivity,
  onCategorySelected: (category) {
    // Handle selection
  },
)
```

**Features:**
- 📱 Horizontal scroll (120px height)
- 🎨 Gradient cards when selected
- ⚡ Compact 140px width per card
- ✓ Check circle indicators
- 🔄 Smooth transitions

---

### 3. CategoryDetailCard
**Use Case:** Detailed category information with action button
**Best For:** Category details page, confirmation screens

```dart
CategoryDetailCard(
  config: CategoryManager.allCategories[0],
  isSelected: true,
  onSelect: () {
    // Handle selection
  },
)
```

**Features:**
- 📋 Full category description
- 🏷️ Feature tags with checkmarks
- 🎯 Action button (gradient or success)
- 💎 Premium elevated card design
- 📝 Formatted feature names

---

## Category Configuration

Each category includes:
- **Name:** Display name (e.g., "Health & Wellness")
- **Icon:** Material icon
- **Color:** Primary color for theming
- **Tagline:** Short motivational phrase
- **Description:** Detailed explanation
- **Features:** List of included feature IDs

### Current Categories

1. **Health & Wellness** 🩺
   - Color: Teal (#00897B)
   - Features: medicine, water, reminders
   - Tagline: "Your complete health companion"

2. **Focus & Productivity** 🧠
   - Color: Purple (#8B5CF6)
   - Features: focus, notes, exam_prep
   - Tagline: "Maximize your potential"

3. **Fitness & Activity** 💪
   - Color: Red (#EF4444)
   - Features: fitness
   - Tagline: "Transform your body"

4. **Finance Tracker** 💰
   - Color: Green (#22C55E)
   - Features: finance
   - Tagline: "Master your money"

5. **Period Tracking** 📅
   - Color: Pink (#EC4899)
   - Features: period
   - Tagline: "Understand your cycle"

---

## Integration Examples

### Example 1: Modal Bottom Sheet
```dart
showModalBottomSheet(
  context: context,
  builder: (context) => Container(
    padding: EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Select Category', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),
        CompactCategorySelector(
          onCategorySelected: (category) {
            Navigator.pop(context, category);
          },
        ),
      ],
    ),
  ),
);
```

### Example 2: Settings Screen
```dart
PremiumCategorySelector(
  initialCategory: CategoryManager().selectedCategory,
  showHeader: true,
  onCategorySelected: (category) async {
    await CategoryManager().selectCategory(category);
    // Navigate or update UI
  },
)
```

### Example 3: Category Details
```dart
ListView.builder(
  itemCount: CategoryManager.allCategories.length,
  itemBuilder: (context, index) {
    final config = CategoryManager.allCategories[index];
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: CategoryDetailCard(
        config: config,
        isSelected: selectedCategory == config.category,
        onSelect: () => selectCategory(config.category),
      ),
    );
  },
)
```

---

## Design Principles

### 🎨 Visual Hierarchy
- Category color as primary accent
- White/dark card backgrounds
- Gradient overlays for selection
- Shadow depth indicates selection state

### 💫 Animations
- Scale animations on load (staggered)
- Smooth color transitions (300ms)
- Bounce physics for scrolling
- Fade transitions for state changes

### 📱 Responsive Design
- Grid adapts to screen size
- Touch targets minimum 44px
- Proper spacing for readability
- Compact mode for small spaces

### ♿ Accessibility
- High contrast ratios
- Clear selection indicators
- Descriptive labels
- Proper semantic structure

---

## Theme Integration

All widgets automatically adapt to:
- ✅ Light/Dark mode
- ✅ App color scheme (AppColors)
- ✅ Custom category colors
- ✅ Glassmorphism effects

---

## Best Practices

1. **Use PremiumCategorySelector** for main selection screens
2. **Use CompactCategorySelector** for quick picks in modals
3. **Use CategoryDetailCard** for detailed information
4. **Always provide onCategorySelected callback**
5. **Show current selection with initialCategory**
6. **Combine with CommonButton for actions**
7. **Use with TabBarModal for multi-step flows**

---

## Notes

- Fun & Relax category is always available (not in selection)
- Users can only select ONE category at a time
- Category change requires sign out (enforced by CategoryManager)
- Exam prep is included in "Focus & Productivity" category
- All widgets use shared AppColors for consistency

---

## File Locations

- **Widgets:** `lib/core/widgets/premium_category_selector.dart`
- **Manager:** `lib/core/services/category_manager.dart`
- **Onboarding:** `lib/features/onboarding/screens/category_selection_screen.dart`
