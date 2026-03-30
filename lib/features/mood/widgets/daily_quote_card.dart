import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mood_theme.dart';
import '../services/mood_quotes_service.dart';

/// Daily quote/affirmation card for mood dashboard
class DailyQuoteCard extends StatelessWidget {
  final MoodQuote? quote;
  final VoidCallback? onRefresh;
  final VoidCallback? onShare;

  const DailyQuoteCard({
    super.key,
    this.quote,
    this.onRefresh,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final displayQuote = quote ?? MoodQuotesService().getDailyQuote();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: MoodTheme.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MoodTheme.primary.withOpacity(0.15),
            MoodTheme.primaryLight.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: MoodTheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Text(displayQuote.emoji, style: const TextStyle(fontSize: 100)),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      MoodTheme.surface.withOpacity(0.95),
                      MoodTheme.surface.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: MoodTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 14, color: MoodTheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Daily Affirmation',
                              style: MoodTheme.bodySm.copyWith(
                                color: MoodTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (onShare != null)
                        _buildIconButton(Icons.share_rounded, onShare!),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '"${displayQuote.text}"',
                    style: MoodTheme.headingSm.copyWith(
                      color: MoodTheme.textPrimary,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '— ${displayQuote.author}',
                    style: MoodTheme.bodyMd.copyWith(
                      color: MoodTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: MoodTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: MoodTheme.primary),
      ),
    );
  }
}

/// Streak celebration quote card
class StreakQuoteCard extends StatelessWidget {
  final int streakDays;
  
  const StreakQuoteCard({super.key, required this.streakDays});

  @override
  Widget build(BuildContext context) {
    final quote = MoodQuotesService().getStreakQuote(streakDays);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: MoodTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MoodTheme.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 8),
              Text('$streakDays Day Streak!', style: MoodTheme.headingMd.copyWith(color: Colors.white)),
              const SizedBox(width: 8),
              const Text('🔥', style: TextStyle(fontSize: 28)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            quote.text,
            style: MoodTheme.bodyMd.copyWith(color: Colors.white.withOpacity(0.9), fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
