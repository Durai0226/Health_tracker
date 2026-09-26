import 'package:flutter/material.dart';
import '../../../core/design/app_design.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:tablet_remainder/core/widgets/app/app_toast.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/vitavibe_service.dart';
import '../../../core/services/audio_service.dart';
import '../models/relaxation_music.dart';
import '../services/relaxation_service.dart';

class RelaxationScreen extends StatefulWidget {
  const RelaxationScreen({super.key});

  @override
  State<RelaxationScreen> createState() => _RelaxationScreenState();
}

class _RelaxationScreenState extends State<RelaxationScreen>
    with SingleTickerProviderStateMixin {
  final RelaxationService _relaxationService = RelaxationService();
  final HapticService _hapticService = HapticService();
  final VitaVibeService _vitaVibeService = VitaVibeService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _relaxationService.init();
    _relaxationService.justCompleted.addListener(_onSessionCompleted);
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // It repeats forever, so it is started from didChangeDependencies, where
    // the reduce-motion preference can be read.

    // A second `_waveController` used to live here, repeating at 4s for the
    // life of the locked session. It drove an `AnimatedBuilder` around the
    // whole 260px timer display whose builder never read its value — so it
    // rebuilt that subtree (gradient circle, shadowed disc, FittedBox,
    // progress column) every vsync to draw exactly the same pixels.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Purely decorative: a breathing pulse behind the cards. It carries no
    // information, so under reduce-motion it simply holds still at its resting
    // value.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulseController.stop();
      _pulseController.value = 0.0;
    } else {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _relaxationService.justCompleted.removeListener(_onSessionCompleted);
    _pulseController.dispose();
    super.dispose();
  }

  /// Say so in the app, because the user is already here.
  ///
  /// `RelaxationService._completeSession` fired an OS notification
  /// unconditionally, and it can only ever run while the app is on screen — so
  /// the end of a session the user was watching arrived as a system banner
  /// dropped over the screen that was showing it. The service now publishes to
  /// `justCompleted` when a screen is listening and keeps the notification for
  /// when none is; this is that screen.
  void _onSessionCompleted() {
    final session = _relaxationService.justCompleted.value;
    if (session == null || !mounted) return;

    // Called straight through, with no post-frame hop. `showAppToast` goes via
    // `ScaffoldMessenger`, not an `OverlayEntry`, and this listener is fired
    // from `_completeSession` — a timer or lifecycle callback, never a build —
    // so there is no pass in flight to insert into and no async gap that could
    // leave this context deactivated. (`FocusScreen` defers its own completion
    // toast because `FocusToast` inserts an overlay entry, which is not safe
    // mid-build.)
    //
    // No haptic here either: `RelaxationService._completeSession` already fires
    // `focusComplete()` itself, and adding one would double-buzz — the same
    // mistake the pause button below used to make.
    context.toastSuccess(
      '${session.actualMinutes} minutes of ${session.category.name} done',
      title: 'Relaxation complete',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _relaxationService,
      builder: (context, _) {
        if (_relaxationService.isRunning) {
          return _buildLockedSessionScreen();
        }
        return _buildSelectionScreen();
      },
    );
  }

  /// The DS swatch that stands in for a category's hardcoded hue.
  ///
  /// `RelaxationCategory.color` is a raw model constant, and measured it fails
  /// as a filled control: white on stressRelief's #10B981 is **2.54:1**, below
  /// AA even for large text, and the "Start N min Session" CTA is exactly that
  /// pair. The three categories map onto swatches the palette has already
  /// verified, so the fills keep their hue family and gain a foreground that
  /// passes. The raw hue stays for DECORATION only — 5–20% tints and 1px
  /// borders, where contrast does not apply.
  AccentSwatch _swatchFor(RelaxationCategory category) {
    final ext = AppColorsExt.of(context);
    switch (category) {
      case RelaxationCategory.deepFocus:
        return ext.focus;
      case RelaxationCategory.stressRelief:
        return ext.success;
      case RelaxationCategory.nervousSystemReset:
        return ext.sleep;
    }
  }

  Widget _buildSelectionScreen() {
    return Scaffold(
      backgroundColor: AppColorsExt.of(context).background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    _buildCategorySelector(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildMusicList(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildDurationSelector(),
                    const SizedBox(height: AppSpacing.xl),
                    if (_relaxationService.selectedMusic != null)
                      _buildStartButton(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildQuickStats(),
                    // Was a magic SizedBox(height: 100). This is a PUSHED
                    // screen, so `pushed` — and it adds the gesture-bar inset
                    // the constant never did.
                    SizedBox(height: AppInsets.pushed(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, AppSpacing.sm),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                // 11 + 22 + 11 = 44. At 10 this measured 42x42 and was the only
                // Focus target under the Apple HIG comfort minimum.
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColorsExt.of(context).surface,
                  borderRadius: AppRadius.brMd,
                  boxShadow: AppShadows.resting(context),
                ),
                child: const Icon(Symbols.arrow_back_rounded, size: 22),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relaxation',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Select music & set your session',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColorsExt.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Goal',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        // Horizontally scrollable strip whose height is driven by the tallest
        // card (min 110 keeps the default look) so wrapped names/descriptions
        // at large text sizes grow the strip instead of overflowing it.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 110),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: RelaxationCategory.values
                    .map(_buildCategoryCard)
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(RelaxationCategory category) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final swatch = _swatchFor(category);
    final isSelected = _relaxationService.selectedCategory == category;
    final fg = isSelected ? ext.fillFg(swatch) : ext.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.brCard,
        child: InkWell(
          onTap: () {
            _hapticService.tap();
            _vitaVibeService.tap();
            _relaxationService.setCategory(category);
          },
          borderRadius: AppRadius.brCard,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            width: 130,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? ext.fillBg(swatch) : ext.surface,
              borderRadius: AppRadius.brCard,
              border: Border.all(
                color: isSelected ? ext.fillBg(swatch) : ext.outline,
                width: isSelected ? 0 : 1,
              ),
              boxShadow: AppShadows.resting(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The goal glyph is chrome — badge-sized, in a card that tints
                // itself when selected — so it takes the accent foreground.
                Icon(category.icon, size: 28, color: fg),
                const Spacer(),
                Text(
                  category.name,
                  style: tt.labelLarge?.copyWith(color: fg),
                ),
                const SizedBox(height: 2),
                Text(
                  category.description,
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: isSelected ? fg : ext.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The tracks in the selected category that actually have audio behind them.
  ///
  /// `AudioService.hasRelaxationAudio` was written for exactly this and then had
  /// no caller, so this list rendered all fourteen catalogue entries while three
  /// files existed: eleven of them started a real, fully-functional countdown and
  /// played nothing. The count beside "Select Music" is the filtered count for the
  /// same reason — "6 tracks" above two rows is its own small lie.
  /// A category whose CC0 audio has not been sourced yet.
  ///
  /// Not a shared `EmptyState`: the screen around it is not empty — the category
  /// cards and the duration selector are still usable, and this is one section
  /// reporting on itself. Saying so plainly beats a header above an empty list,
  /// which reads as a bug.
  Widget _buildNoTracksYet() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColorsExt.of(context).surface,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        children: [
          Icon(Symbols.library_music_rounded,
              color: AppColorsExt.of(context).textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Soundscapes for this category are on the way. '
              'The other categories have tracks you can start now.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColorsExt.of(context).textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicList() {
    final tracks = _relaxationService.selectedCategory.tracks
        .where((t) => AudioService.hasRelaxationAudio(t.assetKey))
        .toList();

    if (tracks.isEmpty) return _buildNoTracksYet();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final swatch = _swatchFor(_relaxationService.selectedCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Select Music',
                style: tt.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                '${tracks.length} tracks',
                style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isSelected = _relaxationService.selectedMusic == track;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                borderRadius: AppRadius.brLg,
                child: InkWell(
                  onTap: () {
                    _hapticService.selectionClick();
                    _relaxationService.setMusic(track);
                  },
                  borderRadius: AppRadius.brLg,
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? track.color.withOpacity(0.1)
                          : ext.surface,
                      borderRadius: AppRadius.brLg,
                      border: Border.all(
                        color: isSelected ? track.color : ext.outline,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? AppShadows.resting(context) : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: track.color.withOpacity(0.15),
                            borderRadius: AppRadius.brLg,
                          ),
                          child: Center(
                            // emoji-content-ok: the track's own artwork glyph,
                            // one per soundscape, chosen with the catalogue
                            child: Text(track.emoji, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.name,
                                // The selected name takes the CATEGORY's AA
                                // swatch, not `track.color` — the fourteen track
                                // hues include #F59E0B (2.15:1 as text on the
                                // card) and are only safe as the 10–15% tints
                                // around it.
                                style: tt.titleMedium?.copyWith(
                                  color: isSelected
                                      ? ext.mark(swatch)
                                      : ext.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                track.description,
                                style: tt.bodySmall
                                    ?.copyWith(color: ext.textSecondary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: ext.fillBg(swatch),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Symbols.check_rounded,
                              color: ext.fillFg(swatch),
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    final durations = [5, 10, 15, 20, 30, 45, 60];
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final swatch = _swatchFor(_relaxationService.selectedCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session Duration', style: tt.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: durations.map((mins) {
            final isSelected = _relaxationService.selectedMinutes == mins;
            return Material(
              color: Colors.transparent,
              borderRadius: AppRadius.brLg,
              child: InkWell(
                onTap: () {
                  _hapticService.selectionClick();
                  _relaxationService.setDuration(mins);
                },
                borderRadius: AppRadius.brLg,
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  // 14 + 16 (labelLarge line box) + 14 = 44. At AppSpacing.md
                  // these chips measured 42 tall, under the HIG comfort floor.
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? ext.fillBg(swatch) : ext.surface,
                    borderRadius: AppRadius.brLg,
                    border: Border.all(
                      color: isSelected ? ext.fillBg(swatch) : ext.outline,
                    ),
                    boxShadow: isSelected ? AppShadows.resting(context) : null,
                  ),
                  child: Text(
                    '$mins min',
                    style: tt.labelLarge?.copyWith(
                      color: isSelected
                          ? ext.fillFg(swatch)
                          : ext.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    final music = _relaxationService.selectedMusic!;
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final swatch = _swatchFor(_relaxationService.selectedCategory);
    final fg = ext.fillFg(swatch);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Material(
            color: Colors.transparent,
            borderRadius: AppRadius.brSheet,
            child: InkWell(
              onTap: () {
                _hapticService.success();
                _vitaVibeService.playPattern(VibePattern.meditationBell);
                _relaxationService.startSession();
              },
              borderRadius: AppRadius.brSheet,
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.gutter),
                decoration: BoxDecoration(
                  color: ext.fillBg(swatch),
                  borderRadius: AppRadius.brSheet,
                  boxShadow: AppShadows.elevated(context),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Symbols.play_arrow_rounded, color: fg, size: 32),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            'Start ${_relaxationService.selectedMinutes} min Session',
                            style: tt.headlineSmall?.copyWith(color: fg),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      music.name,
                      style: tt.labelLarge?.copyWith(color: fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStats() {
    final stats = _relaxationService.stats;
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final swatch = _swatchFor(_relaxationService.selectedCategory);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: AppRadius.brSheet,
        boxShadow: AppShadows.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Relaxation Journey', style: tt.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _buildStatItem(
                icon: Symbols.timer_rounded,
                value: '${stats.totalMinutes}',
                label: 'Minutes',
                swatch: swatch,
              ),
              const SizedBox(width: AppSpacing.md),
              _buildStatItem(
                icon: Symbols.spa_rounded,
                value: '${stats.completedSessions}',
                label: 'Sessions',
                swatch: ext.success,
              ),
              const SizedBox(width: AppSpacing.md),
              _buildStatItem(
                icon: Symbols.trending_up_rounded,
                value: '${(stats.completionRate * 100).toInt()}%',
                label: 'Completion',
                swatch: ext.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required AccentSwatch swatch,
  }) {
    final tt = Theme.of(context).textTheme;
    // `container`/`onContainer` rather than a hand-mixed `mark @ 10%`: the pair
    // is the palette's verified tinted-badge combination, and the previous mix
    // put `mark(warning)` (#B45309) on its own 10% wash for the completion tile.
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: swatch.container,
          borderRadius: AppRadius.brLg,
        ),
        child: Column(
          children: [
            Icon(icon, color: swatch.onContainer, size: 22),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: tt.headlineMedium?.copyWith(color: swatch.onContainer),
              ),
            ),
            Text(
              label,
              // `onContainer`, not `textSecondary`: the label sits ON the tinted
              // tile, and the container pair is the one the palette measured
              // there. textSecondary on the dark container read 3.43:1.
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w400,
                color: swatch.onContainer,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // LOCKED SESSION SCREEN
  Widget _buildLockedSessionScreen() {
    final music = _relaxationService.selectedMusic!;
    final category = _relaxationService.selectedCategory;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showAbandonDialog();
        }
      },
      child: Scaffold(
        backgroundColor: AppColorsExt.of(context).background,
        body: SafeArea(
          // Scroll-safe: on tall screens the Spacers center the content as
          // designed; on shorter screens the content scrolls instead of
          // overflowing (fixes the "BOTTOM OVERFLOWED" render error).
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        _buildLockedHeader(category),
                        const Spacer(),
                        _buildTimerDisplay(category),
                        const Spacer(),
                        _buildMusicInfo(music, category),
                        const SizedBox(height: 40),
                        _buildControlButtons(category),
                        const SizedBox(height: 20),
                        _buildAbandonButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedHeader(RelaxationCategory category) {
    final ext = AppColorsExt.of(context);
    final swatch = _swatchFor(category);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter, vertical: 14),
      decoration: BoxDecoration(
        color: swatch.container,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: ext.mark(swatch).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.lock_rounded, color: swatch.onContainer, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Session Locked',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: swatch.onContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(RelaxationCategory category) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final swatch = _swatchFor(category);
    final mark = ext.mark(swatch);
    return Column(
      children: [
        // Static: the only thing that moves inside it is the clock, on its own
        // ValueListenableBuilder below.
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                mark.withOpacity(0.2),
                mark.withOpacity(0.05),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ext.surface,
                boxShadow: AppShadows.card(context),
              ),
              // The disc is a fixed 200px, so its contents have nowhere to
              // grow: at 2.0x text the 48pt clock alone measures ~200pt wide
              // and spilled past the circle. scaleDown never enlarges, so
              // the default rendering is untouched. `focus_screen.dart`
              // wraps its own timer the same way.
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.gutter),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(category.icon, size: 40, color: mark),
                        const SizedBox(height: AppSpacing.sm),
                        // Only the clock reacts to the per-second tick. The
                        // outer ListenableBuilder now fires only on real state
                        // transitions, so a running session no longer rebuilds
                        // this whole screen 60 times a minute.
                        ValueListenableBuilder<int>(
                          valueListenable: _relaxationService.tick,
                          builder: (context, _, __) => Text(
                            _relaxationService.formattedTime,
                            maxLines: 1,
                            softWrap: false,
                            style: tt.displayLarge?.copyWith(
                              // No scale slot exists above 32 for a clock;
                              // this keeps the display FACE and weight and
                              // overrides only the size, the way
                              // `focus_screen.dart` does at its own timer.
                              fontSize: 48,
                              color: mark,
                              letterSpacing: 2,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: AppRadius.brSm,
                child: LinearProgressIndicator(
                  value: _relaxationService.progress,
                  backgroundColor: ext.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(mark),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${(_relaxationService.progress * 100).toInt()}% complete',
                style: tt.bodySmall?.copyWith(color: ext.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMusicInfo(RelaxationMusicType music, RelaxationCategory category) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final swatch = _swatchFor(category);
    final mark = ext.mark(swatch);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: AppRadius.brSheet,
        boxShadow: AppShadows.card(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: music.color.withOpacity(0.15),
                  borderRadius: AppRadius.brLg,
                ),
                child: Center(
                  // emoji-content-ok: the track's own artwork glyph
                  child: Text(music.emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      music.name,
                      style: tt.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      category.name,
                      style: tt.labelLarge?.copyWith(color: mark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Volume indicator
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 6),
                decoration: BoxDecoration(
                  color: swatch.container,
                  borderRadius: AppRadius.brMd,
                ),
                child: Row(
                  children: [
                    Icon(Symbols.volume_up_rounded,
                        color: swatch.onContainer, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${(_relaxationService.volume * 100).toInt()}%',
                      style: tt.labelMedium?.copyWith(color: swatch.onContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Volume slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: mark,
              inactiveTrackColor: mark.withOpacity(0.2),
              thumbColor: mark,
              overlayColor: mark.withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: _relaxationService.volume,
              // Live feedback while dragging: the audio volume follows the
              // thumb, and nothing is written.
              onChanged: (value) {
                _relaxationService.setVolume(value, persist: false);
              },
              // …but the PERSIST happens once, on release. `onChanged` alone
              // meant a drag ran six Drift writes per frame, two of them
              // re-encoding the stats blob and the last hundred sessions.
              onChangeEnd: (value) {
                _relaxationService.setVolume(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(RelaxationCategory category) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pause/Resume button.
        //
        // Icon-only, so without an explicit label a screen reader announces the
        // one control of a running relaxation session as just "button". The
        // label has to track the state — saying "Pause" on an already-paused
        // session is worse than saying nothing.
        Semantics(
          button: true,
          label: _relaxationService.isPaused ? 'Resume' : 'Pause',
          child: GestureDetector(
            onTap: () {
              // No haptic here. This called `focusComplete()` — the session-
              // COMPLETE celebration pattern — for a pause, and it double-buzzed:
              // `RelaxationService.pauseSession`/`resumeSession` already fire
              // `focusPause()`/`focusStart()` themselves.
              if (_relaxationService.isPaused) {
                _relaxationService.resumeSession();
              } else {
                _relaxationService.pauseSession();
              }
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColorsExt.of(context).surface,
                shape: BoxShape.circle,
                boxShadow: AppShadows.elevated(context),
              ),
              child: Icon(
                _relaxationService.isPaused
                    ? Symbols.play_arrow_rounded
                    : Symbols.pause_rounded,
                color: AppColorsExt.of(context).mark(_swatchFor(category)),
                size: 40,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAbandonButton() {
    return GestureDetector(
      onTap: () => _showAbandonDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColorsExt.of(context).error.container,
          borderRadius: AppRadius.brLg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.close_rounded,
              color: AppColorsExt.of(context).error.onContainer,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Abandon Session',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColorsExt.of(context).error.onContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbandonDialog() {
    final category = _relaxationService.selectedCategory;
    final ext = AppColorsExt.of(context);
    final swatch = _swatchFor(category);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSheet),
        title: Row(
          children: [
            Icon(category.icon, size: 28, color: ext.mark(swatch)),
            const SizedBox(width: AppSpacing.md),
            const Expanded(child: Text('End Session?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your relaxation session is still in progress. Are you sure you want to end it now?',
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: swatch.container,
                borderRadius: AppRadius.brMd,
              ),
              child: Row(
                children: [
                  Icon(Symbols.timer_rounded,
                      color: swatch.onContainer, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'Time remaining: ${_relaxationService.formattedTime}',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: swatch.onContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: ext.mark(swatch)),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _relaxationService.abandonSession();
              context.toastWarning('Session ended');
            },
            style: TextButton.styleFrom(
                foregroundColor: AppColorsExt.of(context)
                    .mark(AppColorsExt.of(context).error)),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }
}
