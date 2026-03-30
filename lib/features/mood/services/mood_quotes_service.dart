import 'dart:math';
import '../models/mood_type.dart';

/// Service for providing mood-based quotes and affirmations
/// Curated quotes based on mood type from Behance design
class MoodQuotesService {
  static final MoodQuotesService _instance = MoodQuotesService._internal();
  factory MoodQuotesService() => _instance;
  MoodQuotesService._internal();

  final _random = Random();

  /// Get a random quote for a specific mood
  MoodQuote getQuoteForMood(MoodType mood) {
    final quotes = _moodQuotes[mood] ?? _generalQuotes;
    return quotes[_random.nextInt(quotes.length)];
  }

  /// Get the daily quote (same quote for the entire day)
  MoodQuote getDailyQuote() {
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final dailyRandom = Random(seed);
    return _generalQuotes[dailyRandom.nextInt(_generalQuotes.length)];
  }

  /// Get a motivational quote for streaks
  MoodQuote getStreakQuote(int streakDays) {
    if (streakDays >= 30) {
      return _streakQuotes['month']![_random.nextInt(_streakQuotes['month']!.length)];
    } else if (streakDays >= 7) {
      return _streakQuotes['week']![_random.nextInt(_streakQuotes['week']!.length)];
    } else {
      return _streakQuotes['start']![_random.nextInt(_streakQuotes['start']!.length)];
    }
  }

  // Mood-specific quotes
  static final Map<MoodType, List<MoodQuote>> _moodQuotes = {
    MoodType.happy: [
      const MoodQuote(
        text: "Happiness is not something ready-made. It comes from your own actions.",
        author: "Dalai Lama",
        emoji: "✨",
      ),
      const MoodQuote(
        text: "The most important thing is to enjoy your life—to be happy.",
        author: "Audrey Hepburn",
        emoji: "🌟",
      ),
      const MoodQuote(
        text: "Happiness is a warm puppy.",
        author: "Charles M. Schulz",
        emoji: "💛",
      ),
      const MoodQuote(
        text: "Keep your face always toward the sunshine, and shadows will fall behind you.",
        author: "Walt Whitman",
        emoji: "☀️",
      ),
    ],
    MoodType.sad: [
      const MoodQuote(
        text: "Every storm runs out of rain. This too shall pass.",
        author: "Maya Angelou",
        emoji: "🌈",
      ),
      const MoodQuote(
        text: "It's okay to not be okay. Feelings are temporary visitors.",
        author: "Unknown",
        emoji: "💙",
      ),
      const MoodQuote(
        text: "The wound is the place where the Light enters you.",
        author: "Rumi",
        emoji: "🕊️",
      ),
      const MoodQuote(
        text: "Crying is one of the highest devotional songs.",
        author: "Rumi",
        emoji: "💜",
      ),
    ],
    MoodType.anxious: [
      const MoodQuote(
        text: "You don't have to control your thoughts. You just have to stop letting them control you.",
        author: "Dan Millman",
        emoji: "🧘",
      ),
      const MoodQuote(
        text: "Nothing diminishes anxiety faster than action.",
        author: "Walter Anderson",
        emoji: "💪",
      ),
      const MoodQuote(
        text: "Breathe. It's just a bad day, not a bad life.",
        author: "Unknown",
        emoji: "🌬️",
      ),
      const MoodQuote(
        text: "You are braver than you believe, stronger than you seem.",
        author: "A.A. Milne",
        emoji: "🦋",
      ),
    ],
    MoodType.angry: [
      const MoodQuote(
        text: "Holding on to anger is like drinking poison and expecting the other person to die.",
        author: "Buddha",
        emoji: "🍃",
      ),
      const MoodQuote(
        text: "For every minute you remain angry, you give up sixty seconds of peace of mind.",
        author: "Ralph Waldo Emerson",
        emoji: "☮️",
      ),
      const MoodQuote(
        text: "Speak when you are angry and you will make the best speech you will ever regret.",
        author: "Ambrose Bierce",
        emoji: "🤐",
      ),
    ],
    MoodType.love: [
      const MoodQuote(
        text: "Love is the bridge between you and everything.",
        author: "Rumi",
        emoji: "💕",
      ),
      const MoodQuote(
        text: "The best thing to hold onto in life is each other.",
        author: "Audrey Hepburn",
        emoji: "💗",
      ),
      const MoodQuote(
        text: "Where there is love there is life.",
        author: "Mahatma Gandhi",
        emoji: "❤️",
      ),
    ],
    MoodType.excited: [
      const MoodQuote(
        text: "Live life as if everything is rigged in your favor.",
        author: "Rumi",
        emoji: "🎉",
      ),
      const MoodQuote(
        text: "The energy you bring, positive or negative, dictates your perceptions.",
        author: "Unknown",
        emoji: "⚡",
      ),
      const MoodQuote(
        text: "Enthusiasm is the electricity of life.",
        author: "Gordon Parks",
        emoji: "🔥",
      ),
    ],
    MoodType.tired: [
      const MoodQuote(
        text: "Rest when you're weary. Refresh and renew yourself.",
        author: "Ralph Marston",
        emoji: "🌙",
      ),
      const MoodQuote(
        text: "Almost everything will work again if you unplug it for a few minutes.",
        author: "Anne Lamott",
        emoji: "😴",
      ),
      const MoodQuote(
        text: "Your body is telling you something. Listen to it.",
        author: "Unknown",
        emoji: "💤",
      ),
    ],
    MoodType.neutral: [
      const MoodQuote(
        text: "Peace is the result of retraining your mind to process life as it is.",
        author: "Wayne Dyer",
        emoji: "☯️",
      ),
      const MoodQuote(
        text: "Calmness is the cradle of power.",
        author: "Josiah Gilbert Holland",
        emoji: "🧠",
      ),
      const MoodQuote(
        text: "In the middle of difficulty lies opportunity.",
        author: "Albert Einstein",
        emoji: "💫",
      ),
    ],
  };

  // General daily quotes
  static const List<MoodQuote> _generalQuotes = [
    MoodQuote(
      text: "Today is a gift. That's why it's called the present.",
      author: "Unknown",
      emoji: "🎁",
    ),
    MoodQuote(
      text: "Be yourself; everyone else is already taken.",
      author: "Oscar Wilde",
      emoji: "✨",
    ),
    MoodQuote(
      text: "The only way to do great work is to love what you do.",
      author: "Steve Jobs",
      emoji: "💪",
    ),
    MoodQuote(
      text: "Every day may not be good, but there's something good in every day.",
      author: "Alice Morse Earle",
      emoji: "🌻",
    ),
    MoodQuote(
      text: "Your feelings are valid. Honor them.",
      author: "Unknown",
      emoji: "💜",
    ),
    MoodQuote(
      text: "Small steps every day lead to big changes.",
      author: "Unknown",
      emoji: "👣",
    ),
    MoodQuote(
      text: "You are enough just as you are.",
      author: "Meghan Markle",
      emoji: "💗",
    ),
    MoodQuote(
      text: "Self-care is not selfish. You cannot pour from an empty cup.",
      author: "Unknown",
      emoji: "☕",
    ),
  ];

  // Streak motivation quotes
  static const Map<String, List<MoodQuote>> _streakQuotes = {
    'start': [
      MoodQuote(
        text: "Every journey begins with a single step. You've started!",
        author: "Unknown",
        emoji: "🚀",
      ),
      MoodQuote(
        text: "Consistency is key. Keep showing up for yourself.",
        author: "Unknown",
        emoji: "🔑",
      ),
    ],
    'week': [
      MoodQuote(
        text: "A week of tracking! You're building a powerful habit.",
        author: "Unknown",
        emoji: "🏆",
      ),
      MoodQuote(
        text: "Seven days strong! Self-awareness is growing.",
        author: "Unknown",
        emoji: "💪",
      ),
    ],
    'month': [
      MoodQuote(
        text: "A month of mindfulness! You're truly committed to your wellbeing.",
        author: "Unknown",
        emoji: "🎯",
      ),
      MoodQuote(
        text: "30 days of consistency! You're mastering emotional intelligence.",
        author: "Unknown",
        emoji: "👑",
      ),
    ],
  };
}

/// Model for a mood quote
class MoodQuote {
  final String text;
  final String author;
  final String emoji;

  const MoodQuote({
    required this.text,
    required this.author,
    required this.emoji,
  });
}
