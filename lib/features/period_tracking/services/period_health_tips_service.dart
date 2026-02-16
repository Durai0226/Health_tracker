import '../models/cycle_log.dart';

class PeriodHealthTipsService {
  static HealthTip getDailyTip(CyclePhase phase, int dayOfCycle) {
    switch (phase) {
      case CyclePhase.menstrual:
        return _getMenstrualTip(dayOfCycle);
      case CyclePhase.follicular:
        return _getFollicularTip(dayOfCycle);
      case CyclePhase.ovulation:
        return _getOvulationTip(dayOfCycle);
      case CyclePhase.luteal:
        return _getLutealTip(dayOfCycle);
      case CyclePhase.pms:
        return _getPMSTip(dayOfCycle);
    }
  }

  static HealthTip _getMenstrualTip(int day) {
    final tips = [
      HealthTip(
        title: 'Rest & Restore',
        description: 'Your body is working hard. Prioritize rest and gentle activities.',
        nutritionTip: 'Iron-rich foods like spinach, lentils, and red meat help replenish what you lose.',
        exerciseTip: 'Light yoga, stretching, or gentle walks are ideal today.',
        icon: '🌙',
      ),
      HealthTip(
        title: 'Stay Hydrated',
        description: 'Drinking warm water or herbal teas can help ease cramps.',
        nutritionTip: 'Avoid caffeine and salty foods which can increase bloating.',
        exerciseTip: 'Swimming can help relieve cramps - the water pressure is soothing.',
        icon: '💧',
      ),
      HealthTip(
        title: 'Warmth Helps',
        description: 'A heating pad on your lower abdomen can ease menstrual cramps.',
        nutritionTip: 'Ginger tea and turmeric have natural anti-inflammatory properties.',
        exerciseTip: 'Restorative yoga poses like child\'s pose can help with discomfort.',
        icon: '🔥',
      ),
      HealthTip(
        title: 'Magnesium Magic',
        description: 'Magnesium can help reduce cramps and improve mood.',
        nutritionTip: 'Dark chocolate, bananas, and almonds are great magnesium sources.',
        exerciseTip: 'Gentle stretching focusing on hips and lower back.',
        icon: '✨',
      ),
      HealthTip(
        title: 'Self-Care Day',
        description: 'Listen to your body and give yourself permission to slow down.',
        nutritionTip: 'Omega-3 fatty acids from fish or flaxseeds help reduce inflammation.',
        exerciseTip: 'A slow, mindful walk in nature can boost your mood.',
        icon: '🌸',
      ),
    ];
    return tips[day % tips.length];
  }

  static HealthTip _getFollicularTip(int day) {
    final tips = [
      HealthTip(
        title: 'Energy Rising',
        description: 'Estrogen is climbing! You might feel more energetic and optimistic.',
        nutritionTip: 'Focus on fresh, light foods - salads, lean proteins, and fermented foods.',
        exerciseTip: 'Great time for cardio, HIIT, or trying a new workout class!',
        icon: '🌱',
      ),
      HealthTip(
        title: 'Brain Boost',
        description: 'Your cognitive abilities are peaking - great for learning new skills.',
        nutritionTip: 'Brain foods like blueberries, walnuts, and avocados support focus.',
        exerciseTip: 'Challenge yourself with complex movements or dance workouts.',
        icon: '🧠',
      ),
      HealthTip(
        title: 'Social Energy',
        description: 'You may feel more social and communicative. Great time for networking!',
        nutritionTip: 'Protein-rich breakfasts keep energy stable throughout the day.',
        exerciseTip: 'Group fitness classes or team sports can be extra enjoyable now.',
        icon: '👋',
      ),
      HealthTip(
        title: 'Creative Peak',
        description: 'Rising estrogen boosts creativity. Start new projects!',
        nutritionTip: 'Colorful vegetables provide antioxidants for skin health.',
        exerciseTip: 'Perfect time for strength training - your muscles recover faster.',
        icon: '🎨',
      ),
    ];
    return tips[day % tips.length];
  }

  static HealthTip _getOvulationTip(int day) {
    final tips = [
      HealthTip(
        title: 'Peak Performance',
        description: 'You\'re at your most fertile and energetic. Confidence is naturally high!',
        nutritionTip: 'Zinc-rich foods like pumpkin seeds support reproductive health.',
        exerciseTip: 'You can push harder - set new personal records!',
        icon: '⭐',
      ),
      HealthTip(
        title: 'Fertile Window',
        description: 'If trying to conceive, this is your peak fertility window.',
        nutritionTip: 'Folate from leafy greens is essential for fertility.',
        exerciseTip: 'High-intensity workouts feel easier now - take advantage!',
        icon: '🌟',
      ),
      HealthTip(
        title: 'Communication Peak',
        description: 'Verbal skills are at their best. Great for presentations or difficult conversations.',
        nutritionTip: 'Stay hydrated - you might notice increased cervical mucus.',
        exerciseTip: 'Endurance activities like running or cycling feel more achievable.',
        icon: '💬',
      ),
    ];
    return tips[day % tips.length];
  }

  static HealthTip _getLutealTip(int day) {
    final tips = [
      HealthTip(
        title: 'Winding Down',
        description: 'Progesterone rises, bringing a calmer energy. Good for detailed work.',
        nutritionTip: 'Complex carbs like sweet potatoes help with serotonin production.',
        exerciseTip: 'Moderate exercise like pilates or moderate-paced running.',
        icon: '🍂',
      ),
      HealthTip(
        title: 'Nesting Mode',
        description: 'You might prefer staying in and organizing. Listen to this instinct.',
        nutritionTip: 'Fiber-rich foods help prevent constipation common in this phase.',
        exerciseTip: 'Strength training is still great, but allow longer rest periods.',
        icon: '🏠',
      ),
      HealthTip(
        title: 'Steady Focus',
        description: 'Great time for completing projects and administrative tasks.',
        nutritionTip: 'Reduce salt to minimize water retention.',
        exerciseTip: 'Yoga and stretching help as your body prepares for menstruation.',
        icon: '📋',
      ),
      HealthTip(
        title: 'Sleep Priority',
        description: 'You might need more sleep. Try to get to bed earlier.',
        nutritionTip: 'Calcium-rich foods may help reduce PMS symptoms.',
        exerciseTip: 'Evening walks can help with sleep quality.',
        icon: '😴',
      ),
    ];
    return tips[day % tips.length];
  }

  static HealthTip _getPMSTip(int day) {
    final tips = [
      HealthTip(
        title: 'Be Gentle',
        description: 'PMS symptoms may appear. Self-compassion is key.',
        nutritionTip: 'Magnesium and B6 vitamins can help with mood swings.',
        exerciseTip: 'Low-impact exercise like swimming or walking reduces symptoms.',
        icon: '💜',
      ),
      HealthTip(
        title: 'Craving Control',
        description: 'Cravings are normal - opt for healthier versions of comfort foods.',
        nutritionTip: 'Dark chocolate satisfies cravings and provides magnesium.',
        exerciseTip: 'Gentle yoga can help with bloating and mood.',
        icon: '🍫',
      ),
      HealthTip(
        title: 'Mood Support',
        description: 'Hormonal shifts affect mood. It\'s temporary and valid.',
        nutritionTip: 'Limit caffeine and alcohol which can worsen PMS symptoms.',
        exerciseTip: 'Any movement helps - even a 10-minute walk makes a difference.',
        icon: '🌈',
      ),
      HealthTip(
        title: 'Prepare Ahead',
        description: 'Stock up on period supplies and schedule lighter activities.',
        nutritionTip: 'Anti-inflammatory foods like turmeric and ginger help.',
        exerciseTip: 'Stretching and deep breathing exercises ease tension.',
        icon: '📦',
      ),
      HealthTip(
        title: 'Almost There',
        description: 'Your period is approaching. Rest and reset.',
        nutritionTip: 'Warm, nourishing soups and stews feel comforting.',
        exerciseTip: 'Yin yoga or restorative stretching prepares your body.',
        icon: '🌙',
      ),
    ];
    return tips[day % tips.length];
  }

  static List<String> getMotivationalMessages(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return [
          "Your body is doing amazing work. Rest is productive too! 💜",
          "Be as kind to yourself as you would be to a good friend.",
          "This too shall pass. You've got this! 🌸",
          "It's okay to slow down. Tomorrow is a new day.",
          "Your worth isn't measured by your productivity today.",
        ];
      case CyclePhase.follicular:
        return [
          "Rising energy, rising possibilities! ✨",
          "Today is full of potential. What will you create?",
          "Your natural optimism is shining through! 🌱",
          "Great time to start something new!",
          "Your body is building strength. So is your spirit!",
        ];
      case CyclePhase.ovulation:
        return [
          "You're glowing! Confidence looks great on you! ⭐",
          "Peak power mode activated! 💪",
          "Your voice matters. Speak up today!",
          "You're magnetic right now. Shine bright! 🌟",
          "This is your time to connect and create!",
        ];
      case CyclePhase.luteal:
        return [
          "Steady progress is still progress! 🍂",
          "Your attention to detail is a superpower right now.",
          "Completion feels just as good as starting.",
          "Quiet strength is still strength. 🏠",
          "You're preparing for renewal. Trust the process.",
        ];
      case CyclePhase.pms:
        return [
          "Your feelings are valid. Be gentle with yourself. 💜",
          "This is temporary. Better days are coming! 🌈",
          "It's okay not to be okay sometimes.",
          "Self-care isn't selfish. It's necessary. 🌙",
          "You're stronger than you know. 💪",
        ];
    }
  }
}

class HealthTip {
  final String title;
  final String description;
  final String nutritionTip;
  final String exerciseTip;
  final String icon;

  HealthTip({
    required this.title,
    required this.description,
    required this.nutritionTip,
    required this.exerciseTip,
    required this.icon,
  });
}
