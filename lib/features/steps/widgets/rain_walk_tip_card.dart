import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/dry_window.dart';
import '../../../core/health/walk_weather_tip.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../water/services/hydration_weather_service.dart';

/// "Rain from 6 pm — 4–6 pm looks dry for a walk.": shown on the Steps screen
/// only to someone clearly behind on today's goal, when the forecast has rain in
/// the hours left and a dry stretch to point at. Renders nothing otherwise — on a
/// dry day, or on pace, or with no weather set up.
///
/// It uses the place the person already gave for the weather-aware water goal,
/// and says so; it adds no permission and no place of its own.
class RainWalkTipCard extends StatefulWidget {
  const RainWalkTipCard({
    super.key,
    required this.steps,
    required this.goal,
    this.restDay = false,
    this.load = HydrationWeatherService.rainForecastToday,
  });

  /// Today's steps so far, and the goal.
  final int steps;
  final int goal;

  /// Today's goal is paused: nothing to nudge about.
  final bool restDay;

  /// Where the forecast comes from; a test hands in its own.
  @visibleForTesting
  final Future<RainForecast?> Function() load;

  @override
  State<RainWalkTipCard> createState() => _RainWalkTipCardState();
}

class _RainWalkTipCardState extends State<RainWalkTipCard> {
  RainForecast? _forecast;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final f = await widget.load();
    if (!mounted) return;
    setState(() => _forecast = f);
  }

  /// The tip for this moment, or null when there is none to give.
  DryWindow? _window() {
    final f = _forecast;
    if (f == null || widget.restDay) return null;
    final now = clock.now();
    final minute = now.hour * 60 + now.minute;
    if (!WalkWeatherTips.behindPace(
        steps: widget.steps, goal: widget.goal, nowMinute: minute)) {
      return null;
    }
    return DryWindows.find(f.hourly, nowHour: now.hour, nowMinute: now.minute);
  }

  @override
  Widget build(BuildContext context) {
    final window = _window();
    if (window == null) return const SizedBox.shrink();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      // Carries its own top spacing so it leaves no gap when it has nothing to say.
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ext.steps.container,
                borderRadius: AppRadius.brMd,
              ),
              child: Icon(Symbols.umbrella_rounded,
                  size: 22, color: ext.steps.onContainer),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(WalkWeatherTips.say(window), style: tt.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Forecast for ${_forecast!.placeName} — a guess, not a promise.',
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
