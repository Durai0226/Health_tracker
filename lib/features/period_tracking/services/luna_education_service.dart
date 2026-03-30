import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/luna_education.dart';
import '../theme/luna_theme.dart';

/// Service for Luna Cycle education features
/// Health articles, tips, myths vs facts
class LunaEducationService extends ChangeNotifier {
  static const String _bookmarksKey = 'luna_bookmarked_articles';
  static const String _viewedArticlesKey = 'luna_viewed_articles';
  static const String _likedTipsKey = 'luna_liked_tips';
  static const String _lastTipDateKey = 'luna_last_tip_date';
  static const String _currentTipIdKey = 'luna_current_tip_id';

  List<LunaArticle> _articles = [];
  List<LunaHealthTip> _tips = [];
  List<LunaMythFact> _myths = [];
  Set<String> _bookmarkedArticleIds = {};
  Set<String> _viewedArticleIds = {};
  Set<String> _likedTipIds = {};
  LunaHealthTip? _dailyTip;
  bool _isLoading = false;

  List<LunaArticle> get articles => _articles;
  List<LunaHealthTip> get tips => _tips;
  List<LunaMythFact> get myths => _myths;
  LunaHealthTip? get dailyTip => _dailyTip;
  bool get isLoading => _isLoading;

  /// Initialize the service
  Future<void> initialize() async {
    await _loadLocalData();
    await _loadContent();
    await _loadDailyTip();
    notifyListeners();
  }

  /// Load local bookmarks and viewed articles
  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final bookmarks = prefs.getStringList(_bookmarksKey);
      if (bookmarks != null) {
        _bookmarkedArticleIds = bookmarks.toSet();
      }
      
      final viewed = prefs.getStringList(_viewedArticlesKey);
      if (viewed != null) {
        _viewedArticleIds = viewed.toSet();
      }
      
      final likedTips = prefs.getStringList(_likedTipsKey);
      if (likedTips != null) {
        _likedTipIds = likedTips.toSet();
      }
    } catch (e) {
      debugPrint('Error loading local education data: $e');
    }
  }

  /// Save local data
  Future<void> _saveLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_bookmarksKey, _bookmarkedArticleIds.toList());
      await prefs.setStringList(_viewedArticlesKey, _viewedArticleIds.toList());
      await prefs.setStringList(_likedTipsKey, _likedTipIds.toList());
    } catch (e) {
      debugPrint('Error saving local education data: $e');
    }
  }

  /// Load content (articles, tips, myths)
  Future<void> _loadContent() async {
    _isLoading = true;
    notifyListeners();

    // Load predefined content
    _myths = LunaPredefinedMyths.all;
    _tips = [
      ...LunaPredefinedTips.menstrualTips,
      ...LunaPredefinedTips.follicularTips,
      ...LunaPredefinedTips.ovulationTips,
      ...LunaPredefinedTips.lutealTips,
      ...LunaPredefinedTips.pmsTips,
    ];

    // Load predefined articles
    _articles = _getPredefinedArticles();

    // Try to load from Firestore for additional content
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('luna_education_articles')
          .orderBy('publishedAt', descending: true)
          .limit(50)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final cloudArticles = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return LunaArticle.fromJson(data);
        }).toList();
        
        // Merge with predefined, avoiding duplicates
        for (final article in cloudArticles) {
          if (!_articles.any((a) => a.id == article.id)) {
            _articles.add(article);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cloud articles: $e');
    }

    // Mark bookmarked articles
    _articles = _articles.map((a) => a.copyWith(
      isBookmarked: _bookmarkedArticleIds.contains(a.id),
    )).toList();

    _isLoading = false;
    notifyListeners();
  }

  /// Load or generate daily tip based on cycle phase
  Future<void> _loadDailyTip({LunaCyclePhase? currentPhase}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTipDate = prefs.getString(_lastTipDateKey);
      final today = DateTime.now().toIso8601String().substring(0, 10);

      if (lastTipDate == today) {
        // Already have today's tip
        final currentTipId = prefs.getString(_currentTipIdKey);
        if (currentTipId != null) {
          _dailyTip = _tips.firstWhere(
            (t) => t.id == currentTipId,
            orElse: () => _getRandomTip(currentPhase),
          );
          return;
        }
      }

      // Get new tip for today
      _dailyTip = _getRandomTip(currentPhase);
      
      await prefs.setString(_lastTipDateKey, today);
      await prefs.setString(_currentTipIdKey, _dailyTip!.id);
    } catch (e) {
      debugPrint('Error loading daily tip: $e');
      _dailyTip = _getRandomTip(currentPhase);
    }
  }

  /// Get random tip, preferring phase-relevant ones
  LunaHealthTip _getRandomTip(LunaCyclePhase? phase) {
    if (phase != null) {
      final phaseTips = _tips.where((t) {
        if (t.phaseRelevance == null) return false;
        return t.phaseRelevance == LunaCyclePhaseRelevance.values[phase.index] ||
               t.phaseRelevance == LunaCyclePhaseRelevance.all;
      }).toList();
      
      if (phaseTips.isNotEmpty) {
        final index = DateTime.now().day % phaseTips.length;
        return phaseTips[index];
      }
    }
    
    // Fallback to any tip
    final index = DateTime.now().day % _tips.length;
    return _tips[index];
  }

  /// Update daily tip based on current phase
  Future<void> updateDailyTipForPhase(LunaCyclePhase phase) async {
    await _loadDailyTip(currentPhase: phase);
    notifyListeners();
  }

  /// Toggle article bookmark
  Future<void> toggleBookmark(String articleId) async {
    final isBookmarked = _bookmarkedArticleIds.contains(articleId);
    
    if (isBookmarked) {
      _bookmarkedArticleIds.remove(articleId);
    } else {
      _bookmarkedArticleIds.add(articleId);
    }

    // Update article state
    final index = _articles.indexWhere((a) => a.id == articleId);
    if (index != -1) {
      _articles[index] = _articles[index].copyWith(isBookmarked: !isBookmarked);
    }

    await _saveLocalData();
    notifyListeners();
  }

  /// Mark article as viewed
  Future<void> markArticleViewed(String articleId) async {
    if (!_viewedArticleIds.contains(articleId)) {
      _viewedArticleIds.add(articleId);
      
      // Update view count in Firestore
      try {
        await FirebaseFirestore.instance
            .collection('luna_education_articles')
            .doc(articleId)
            .update({'viewCount': FieldValue.increment(1)});
      } catch (e) {
        // Ignore if article doesn't exist in Firestore
      }

      await _saveLocalData();
    }
  }

  /// Toggle tip like
  Future<void> toggleTipLike(String tipId) async {
    final isLiked = _likedTipIds.contains(tipId);
    
    if (isLiked) {
      _likedTipIds.remove(tipId);
    } else {
      _likedTipIds.add(tipId);
    }

    await _saveLocalData();
    notifyListeners();
  }

  /// Check if tip is liked
  bool isTipLiked(String tipId) => _likedTipIds.contains(tipId);

  /// Get bookmarked articles
  List<LunaArticle> get bookmarkedArticles {
    return _articles.where((a) => _bookmarkedArticleIds.contains(a.id)).toList();
  }

  /// Get articles by category
  List<LunaArticle> getArticlesByCategory(LunaArticleCategory category) {
    return _articles.where((a) => a.category == category).toList();
  }

  /// Get tips by phase
  List<LunaHealthTip> getTipsForPhase(LunaCyclePhase phase) {
    return _tips.where((t) {
      if (t.phaseRelevance == null) return false;
      return t.phaseRelevance == LunaCyclePhaseRelevance.values[phase.index] ||
             t.phaseRelevance == LunaCyclePhaseRelevance.all;
    }).toList();
  }

  /// Get myths by category
  List<LunaMythFact> getMythsByCategory(LunaMythCategory category) {
    return _myths.where((m) => m.category == category).toList();
  }

  /// Search articles
  List<LunaArticle> searchArticles(String query) {
    final lowerQuery = query.toLowerCase();
    return _articles.where((a) {
      return a.title.toLowerCase().contains(lowerQuery) ||
          a.summary.toLowerCase().contains(lowerQuery) ||
          a.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Get featured articles
  List<LunaArticle> get featuredArticles {
    return _articles.where((a) => a.isVerified).take(5).toList();
  }

  /// Get recently viewed articles
  List<LunaArticle> get recentlyViewedArticles {
    return _articles.where((a) => _viewedArticleIds.contains(a.id)).toList();
  }

  /// Get predefined articles
  List<LunaArticle> _getPredefinedArticles() {
    return [
      LunaArticle(
        id: 'article-1',
        title: 'Understanding Your Menstrual Cycle',
        summary: 'Learn about the four phases of your cycle and how they affect your body and mind.',
        content: '''
# Understanding Your Menstrual Cycle

Your menstrual cycle is a monthly process that prepares your body for pregnancy. Understanding it can help you better manage your health and well-being.

## The Four Phases

### 1. Menstrual Phase (Days 1-5)
This is when you have your period. The uterine lining sheds, and hormone levels are at their lowest.

**What to expect:**
- Bleeding for 3-7 days
- Possible cramping
- Lower energy levels

### 2. Follicular Phase (Days 6-14)
Your body prepares to release an egg. Estrogen levels rise.

**What to expect:**
- Increasing energy
- Improved mood
- Better concentration

### 3. Ovulation (Day 14)
An egg is released from the ovary. This is your most fertile time.

**What to expect:**
- Peak energy
- Increased libido
- Slight temperature rise

### 4. Luteal Phase (Days 15-28)
If the egg isn't fertilized, hormone levels drop, preparing for the next cycle.

**What to expect:**
- PMS symptoms may appear
- Possible mood changes
- Cravings

## Tips for Each Phase

Listen to your body and adjust your activities accordingly. Rest more during menstruation, take on challenges during the follicular phase, and practice self-care during the luteal phase.
        ''',
        category: LunaArticleCategory.cycleBasics,
        tags: ['cycle', 'phases', 'hormones', 'basics'],
        authorName: 'Luna Health Team',
        authorCredentials: 'Health Educators',
        isVerified: true,
        readTimeMinutes: 8,
        viewCount: 15420,
        publishedAt: DateTime(2024, 1, 15),
      ),
      LunaArticle(
        id: 'article-2',
        title: 'Managing PMS Naturally',
        summary: 'Discover natural remedies and lifestyle changes to ease premenstrual symptoms.',
        content: '''
# Managing PMS Naturally

PMS affects up to 75% of women. While symptoms vary, there are many natural approaches to find relief.

## Common PMS Symptoms
- Mood swings
- Bloating
- Breast tenderness
- Fatigue
- Food cravings

## Natural Remedies

### Dietary Changes
- Reduce salt to minimize bloating
- Limit caffeine and alcohol
- Eat complex carbohydrates
- Include calcium-rich foods

### Exercise
Light to moderate exercise can help by:
- Releasing endorphins
- Reducing stress
- Improving sleep

### Supplements (consult your doctor)
- Vitamin B6
- Magnesium
- Evening primrose oil
- Calcium

### Lifestyle
- Get enough sleep (7-9 hours)
- Practice stress management
- Try yoga or meditation
- Use heat therapy for cramps

## When to See a Doctor
If PMS significantly impacts your daily life, talk to a healthcare provider about PMDD (Premenstrual Dysphoric Disorder) or other treatments.
        ''',
        category: LunaArticleCategory.symptoms,
        tags: ['pms', 'natural', 'remedies', 'symptoms'],
        authorName: 'Dr. Sarah Mitchell',
        authorCredentials: 'MD, OB-GYN',
        isVerified: true,
        readTimeMinutes: 6,
        viewCount: 12350,
        publishedAt: DateTime(2024, 2, 1),
      ),
      LunaArticle(
        id: 'article-3',
        title: 'Nutrition for Hormonal Balance',
        summary: 'Foods that support hormonal health throughout your cycle.',
        content: '''
# Nutrition for Hormonal Balance

What you eat can significantly impact your hormonal health. Here's how to eat for each phase of your cycle.

## Menstrual Phase
Focus on iron-rich foods to replace what's lost:
- Leafy greens (spinach, kale)
- Lean red meat
- Legumes
- Dark chocolate

## Follicular Phase
Support rising estrogen with:
- Fermented foods
- Flaxseeds
- Citrus fruits
- Lean proteins

## Ovulation
Fuel peak energy with:
- Fresh vegetables
- Fiber-rich foods
- Light, easily digestible meals
- Plenty of water

## Luteal Phase
Combat cravings and support mood:
- Complex carbs (sweet potatoes, quinoa)
- Magnesium-rich foods (nuts, seeds)
- B vitamins (whole grains)
- Healthy fats (avocado, olive oil)

## Foods to Limit
- Processed foods
- Excess sugar
- Too much caffeine
- Alcohol

## Hydration
Aim for 8 glasses of water daily. Herbal teas like chamomile and ginger can also help with symptoms.
        ''',
        category: LunaArticleCategory.nutrition,
        tags: ['nutrition', 'hormones', 'food', 'diet'],
        authorName: 'Emma Rodriguez',
        authorCredentials: 'Registered Dietitian',
        isVerified: true,
        readTimeMinutes: 7,
        viewCount: 9870,
        publishedAt: DateTime(2024, 2, 15),
      ),
      LunaArticle(
        id: 'article-4',
        title: 'Exercise and Your Cycle',
        summary: 'How to adapt your workout routine to your menstrual cycle for optimal results.',
        content: '''
# Exercise and Your Cycle

Your body's capabilities change throughout your cycle. Learn how to work with these changes for better fitness results.

## Menstrual Phase
**Best exercises:**
- Gentle yoga
- Walking
- Light stretching
- Swimming

*Listen to your body - rest if needed*

## Follicular Phase
**Best exercises:**
- High-intensity interval training (HIIT)
- Weight training
- Running
- New workout classes

*Your body recovers faster - push yourself!*

## Ovulation
**Best exercises:**
- Group fitness classes
- Competitive sports
- Personal records attempts
- Social workouts

*Energy and strength are at their peak*

## Luteal Phase
**Best exercises:**
- Pilates
- Moderate cardio
- Strength training (moderate intensity)
- Yoga

*Focus on consistency over intensity*

## Tips
- Track how you feel during workouts
- Don't skip rest days
- Stay hydrated
- Adjust intensity based on energy levels
        ''',
        category: LunaArticleCategory.fitness,
        tags: ['fitness', 'exercise', 'workout', 'cycle'],
        authorName: 'Coach Maya Chen',
        authorCredentials: 'Certified Personal Trainer',
        isVerified: true,
        readTimeMinutes: 5,
        viewCount: 8540,
        publishedAt: DateTime(2024, 3, 1),
      ),
      LunaArticle(
        id: 'article-5',
        title: 'Mental Health and Your Cycle',
        summary: 'Understanding the connection between hormones and mood, with coping strategies.',
        content: '''
# Mental Health and Your Cycle

Hormonal fluctuations throughout your cycle can significantly impact your mental health. Understanding this connection is the first step to managing it.

## How Hormones Affect Mood

### Estrogen
- Boosts serotonin (the "happy hormone")
- Peaks during follicular phase and ovulation
- Drops before your period

### Progesterone
- Has calming effects
- Rises after ovulation
- Can cause anxiety as it drops

## Symptoms to Watch
- Mood swings
- Anxiety
- Depression
- Irritability
- Difficulty concentrating

## Coping Strategies

### During PMS/Menstrual Phase
- Practice self-compassion
- Reduce commitments if possible
- Get extra sleep
- Journal your feelings

### Throughout Your Cycle
- Regular exercise
- Mindfulness meditation
- Consistent sleep schedule
- Social support

## When to Seek Help
If mood symptoms significantly impact your life, consider:
- Talking to your doctor about PMDD
- Therapy or counseling
- Support groups
- Medical treatment options

Remember: Your feelings are valid, and help is available.
        ''',
        category: LunaArticleCategory.mentalHealth,
        tags: ['mental health', 'mood', 'hormones', 'anxiety'],
        authorName: 'Dr. Lisa Park',
        authorCredentials: 'PhD, Clinical Psychologist',
        isVerified: true,
        readTimeMinutes: 6,
        viewCount: 11200,
        publishedAt: DateTime(2024, 3, 15),
      ),
    ];
  }

  /// Clear all data
  Future<void> clearAllData() async {
    _articles = [];
    _tips = [];
    _myths = [];
    _bookmarkedArticleIds = {};
    _viewedArticleIds = {};
    _likedTipIds = {};
    _dailyTip = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bookmarksKey);
    await prefs.remove(_viewedArticlesKey);
    await prefs.remove(_likedTipsKey);
    await prefs.remove(_lastTipDateKey);
    await prefs.remove(_currentTipIdKey);
    
    notifyListeners();
  }
}
