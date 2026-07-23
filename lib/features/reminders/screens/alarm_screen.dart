import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/design/app_colors_ext.dart';
import '../../../core/services/notification_service.dart';
import '../../medication/services/medicine_storage_service.dart';

/// The full-screen reminder alert — "Aurora Veil" glassmorphism.
///
/// A living teal→indigo aurora drifts behind heavily-frosted glass whose top rim
/// catches a slow travelling specular sweep; the medicine glyph *breathes* at a
/// resting-breath cadence so the alert reads as an exhale, not a jolt. Calm by
/// design for a health context — no red, no amber, no flashing.
///
/// Accessible: a dedicated contrast scrim keeps text AA-legible over the moving
/// light; reduced-motion freezes all ambient animation; high-contrast /
/// reduce-transparency swaps the frost for solid fills; targets are ≥56px.
class AlarmScreen extends StatefulWidget {
  final Map<String, dynamic> payload;

  const AlarmScreen({super.key, required this.payload});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ambient; // aurora orbit + rim sweep (24s loop)
  late final AnimationController _breath; // glyph breathing (~4.6s)
  late final AnimationController _entrance; // staggered reveal
  Timer? _timer;
  DateTime _now = DateTime.now();

  // Cross-isolate "stop ringing" channel: the notification-action handlers run
  // in the alarm/background isolate and can't touch this screen's audio player
  // directly, so they send to this named port to silence + close the screen.
  static const String _kAlarmStopPort = 'db_alarm_stop';
  ReceivePort? _stopPort;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _registerStopPort();

    _ambient =
        AnimationController(vsync: this, duration: const Duration(seconds: 24));
    _breath = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4600));
    _entrance = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startAlarmSound();
  }

  final AudioPlayer _alarmSound = AudioPlayer();

  /// Plays the reminder's chosen sound on LOOP through the ALARM stream (so it
  /// rings at alarm volume, even in silent/DND) until the user dismisses or
  /// snoozes. This is what actually makes the alarm "ring" — the notification
  /// itself only plays a one-shot ping; the bundled sounds live in Flutter
  /// assets (not res/raw) so only an in-app player can use them.
  Future<void> _startAlarmSound() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.alarm,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));

      final sound = widget.payload['sound']?.toString();
      if (sound != null && sound.startsWith('/')) {
        await _alarmSound.setFilePath(sound); // user-picked device file
      } else {
        final key = (sound == null || sound.isEmpty || sound == 'default')
            ? 'chime'
            : sound;
        await _alarmSound.setAsset('assets/sounds/$key.wav');
      }
      await _alarmSound.setLoopMode(LoopMode.one);
      await _alarmSound.setVolume(1.0);
      await _alarmSound.play();
    } catch (e) {
      debugPrint('⚠️ Alarm sound failed: $e'); // notification ping still played
    }
  }

  Future<void> _stopAlarmSound() async {
    try {
      await _alarmSound.stop();
    } catch (_) {}
  }

  /// Listen for a stop signal from the notification-side action handlers. If the
  /// user dismisses/takes/snoozes from the NOTIFICATION (e.g. the shade) while
  /// this screen is ringing, this silences the loop and closes the screen too.
  void _registerStopPort() {
    final port = ReceivePort();
    _stopPort = port;
    IsolateNameServer.removePortNameMapping(_kAlarmStopPort);
    IsolateNameServer.registerPortWithName(port.sendPort, _kAlarmStopPort);
    port.listen((_) {
      if (mounted) _exit();
    });
  }

  bool _motionConfigured = false;

  void _configureMotion() {
    if (_motionConfigured) return;
    _motionConfigured = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _ambient.value = 0.18; // a pleasing frozen frame
      _breath.value = 0.5;
      _entrance.value = 1.0;
    } else {
      _ambient.repeat();
      _breath.repeat(reverse: true);
      _entrance.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configureMotion();
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping(_kAlarmStopPort);
    _stopPort?.close();
    _timer?.cancel();
    _ambient.dispose();
    _breath.dispose();
    _entrance.dispose();
    _alarmSound.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  int? _payloadId() {
    final id = widget.payload['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  Future<void> _handleDismiss() async {
    HapticFeedback.lightImpact();
    final id = _payloadId();
    if (id != null) await NotificationService().cancelNotification(id);
    _exit();
  }

  /// Medicine alarms only: log the dose taken right here (foreground → Drift is
  /// available), cancel the notification, and leave. Payload carries the dose id.
  Future<void> _handleTake() async {
    HapticFeedback.mediumImpact();
    final medId = widget.payload['medicineId']?.toString();
    if (medId != null && medId.isNotEmpty) {
      final hour = (widget.payload['hour'] as num?)?.toInt();
      final minute = (widget.payload['minute'] as num?)?.toInt();
      final now = DateTime.now();
      final scheduled = (hour != null && minute != null)
          ? DateTime(now.year, now.month, now.day, hour, minute)
          : now;
      try {
        await MedicineCleanStorageService.markMedicineTaken(
            medicineId: medId, scheduledTime: scheduled);
      } catch (_) {}
    }
    final id = _payloadId();
    if (id != null) await NotificationService().cancelNotification(id);
    _exit();
  }

  Future<void> _handleSnooze() async {
    HapticFeedback.lightImpact();
    final id = _payloadId();
    if (id != null) {
      final d = widget.payload['snoozeDuration'];
      final mins = d is int ? d : (d is String ? int.tryParse(d) ?? 5 : 5);
      // Pass the title/body we already have so the snoozed alarm keeps the real
      // reminder name (medicine/health/water aren't in the generic list).
      await NotificationService().snoozeReminder(
        id,
        mins,
        title: widget.payload['title']?.toString(),
        body: widget.payload['body']?.toString(),
      );
    }
    _exit();
  }

  /// Leaves the alarm. When it was the app's cold-launch route there is nothing
  /// to pop into (popping → black screen / app close), so fall through to home.
  void _exit() {
    _stopAlarmSound(); // silence the ring on dismiss/snooze
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final dark = ext.isDark;
    final reduceTransparency =
        MediaQuery.maybeHighContrastOf(context) ?? false;

    final title = (widget.payload['title'] ?? 'Reminder').toString();
    final body = (widget.payload['body'] ?? 'Time for your task').toString();

    // Aurora palette (bespoke immersive art layer — design-intent colors).
    final tealBlob = dark ? const Color(0xFF00897B) : const Color(0xFF4DB6AC);
    final indigoBlob = dark ? const Color(0xFF6366F1) : const Color(0xFF818CF8);
    const bridgeBlob = Color(0xFF26A69A);
    final wash = dark
        ? const [Color(0xFF0B0F16), Color(0xFF0F1319), Color(0xFF11161F)]
        : const [Color(0xFFEFF3F4), Color(0xFFF5F6F8), Color(0xFFF0F4F3)];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Living aurora background ──
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ambient,
              builder: (_, __) => CustomPaint(
                painter: _AuroraPainter(
                  t: _ambient.value,
                  wash: wash,
                  blobA: tealBlob.withOpacity(dark ? 0.55 : 0.30),
                  blobB: indigoBlob.withOpacity(dark ? 0.45 : 0.24),
                  blobC: bridgeBlob.withOpacity(dark ? 0.30 : 0.16),
                  vignette: dark ? 0.12 : 0.06,
                  vignetteWarm: !dark,
                ),
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        _reveal(0.30, 0.55, child: _clockPill(ext, dark, reduceTransparency)),
                        const SizedBox(height: 22),
                        _heroSlab(ext, dark, reduceTransparency, title, body,
                            tealBlob, indigoBlob),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Staggered entrance wrapper (opacity + 8px rise) ──
  Widget _reveal(double begin, double end, {required Widget child}) {
    final curve = CurvedAnimation(
        parent: _entrance, curve: Interval(begin, end, curve: const Cubic(0.2, 0, 0, 1)));
    return AnimatedBuilder(
      animation: curve,
      builder: (_, c) => Opacity(
        opacity: curve.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - curve.value) * 10), child: c),
      ),
      child: child,
    );
  }

  // ── Floating clock pill (nearest depth: lightest blur) ──
  Widget _clockPill(AppColorsExt ext, bool dark, bool solid) {
    final tt = Theme.of(context).textTheme;
    return _glass(
      ext: ext,
      dark: dark,
      solid: solid,
      blur: 18,
      radius: 26,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      fill: dark
          ? [Colors.white.withOpacity(0.09), Colors.white.withOpacity(0.04)]
          : [Colors.white.withOpacity(0.60), Colors.white.withOpacity(0.46)],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('h:mm').format(_now),
                style: TextStyle(
                  fontSize: 64,
                  height: 1,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 1,
                  color: ext.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(DateFormat('a').format(_now),
                    style: tt.labelMedium?.copyWith(
                        color: ext.mark(ext.brand),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(DateFormat('EEEE, MMMM d').format(_now),
              style: tt.bodySmall?.copyWith(
                  color: ext.textSecondary, letterSpacing: 1)),
        ],
      ),
    );
  }

  // ── Hero slab: glyph + title + body + actions ──
  Widget _heroSlab(AppColorsExt ext, bool dark, bool solid, String title,
      String body, Color teal, Color indigo) {
    final tt = Theme.of(context).textTheme;
    final scrim = dark
        ? const Color(0xFF0B0F16).withOpacity(0.28)
        : Colors.white.withOpacity(0.45);
    return _glass(
      ext: ext,
      dark: dark,
      solid: solid,
      blur: 30,
      radius: 36,
      rim: true,
      teal: teal,
      indigo: indigo,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      fill: dark
          ? [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)]
          : [Colors.white.withOpacity(0.55), Colors.white.withOpacity(0.40)],
      child: Semantics(
        header: true,
        label: 'Medication reminder. $title. $body.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reveal(0.40, 0.65, child: _breathingGlyph(ext, teal, indigo)),
            const SizedBox(height: 24),
            // Contrast scrim behind the text so type never floats on aurora peaks.
            _reveal(
              0.50,
              0.78,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [scrim, scrim.withOpacity(scrim.opacity * 0.55)],
                  ),
                ),
                child: Column(
                  children: [
                    Text(title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.headlineSmall?.copyWith(
                            color: ext.textPrimary,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            letterSpacing: 0.2)),
                    const SizedBox(height: 8),
                    Text(body,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                            color: ext.textSecondary, height: 1.4)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            _reveal(0.60, 0.90, child: _actions(ext, dark)),
          ],
        ),
      ),
    );
  }

  Widget _breathingGlyph(AppColorsExt ext, Color teal, Color indigo) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (_, __) {
        final b = Curves.easeInOut.transform(_breath.value); // 0..1
        final scale = 1.0 + 0.03 * b;
        final halo = 0.8 + 0.2 * b;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [indigo, teal, indigo],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                    color: teal.withOpacity(0.35 * halo),
                    blurRadius: 28,
                    spreadRadius: 2),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ext.isDark
                    ? const Color(0xFF0E131B)
                    : Colors.white.withOpacity(0.9),
              ),
              child: Icon(Symbols.medication_rounded,
                  size: 34, color: ext.mark(ext.medicine)),
            ),
          ),
        );
      },
    );
  }

  Widget _actions(AppColorsExt ext, bool dark) {
    final isMedicine =
        (widget.payload['medicineId']?.toString().isNotEmpty ?? false);
    return Column(
      children: [
        if (isMedicine) ...[
          _TakeChip(ext: ext, onTap: _handleTake),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: _SnoozeChip(
                ext: ext,
                onTap: _handleSnooze,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DismissChip(
                ext: ext,
                onTap: _handleDismiss,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Reusable glass container (frost + tint + optional edge-lit rim + colored shadow) ──
  Widget _glass({
    required AppColorsExt ext,
    required bool dark,
    required bool solid,
    required double blur,
    required double radius,
    required EdgeInsets padding,
    required List<Color> fill,
    required Widget child,
    bool rim = false,
    Color? teal,
    Color? indigo,
  }) {
    final shadow = dark
        ? const Color(0xFF00251F).withOpacity(0.5)
        : const Color(0xFF1A1D21).withOpacity(0.10);
    final rrect = BorderRadius.circular(radius);

    Widget inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: rrect,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: solid
              ? [ext.surfaceElevated, ext.surface]
              : fill,
        ),
      ),
      child: child,
    );

    // Diagonal accent sheen + edge-lit rim overlay.
    Widget panel = Stack(
      children: [
        inner,
        if (!solid && teal != null && indigo != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: rrect,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      teal.withOpacity(0.06),
                      Colors.transparent,
                      indigo.withOpacity(0.05),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
        if (rim)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ambient,
                builder: (_, __) => CustomPaint(
                  painter: _RimPainter(
                    radius: radius,
                    teal: (teal ?? ext.brand.base),
                    indigo: (indigo ?? ext.medicine.base),
                    sweep: (_ambient.value * 2) % 1.0, // 2 sweeps per loop
                    innerHighlight:
                        Colors.white.withOpacity(dark ? 0.14 : 0.35),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: rrect,
        boxShadow: [
          BoxShadow(
              color: shadow,
              blurRadius: dark ? 60 : 40,
              offset: Offset(0, dark ? 24 : 18)),
        ],
      ),
      child: ClipRRect(
        borderRadius: rrect,
        child: solid
            ? panel
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: panel,
              ),
      ),
    );
  }
}

// ─────────────────────────── Action chips ───────────────────────────

class _DismissChip extends StatefulWidget {
  final AppColorsExt ext;
  final VoidCallback onTap;
  const _DismissChip({required this.ext, required this.onTap});
  @override
  State<_DismissChip> createState() => _DismissChipState();
}

class _DismissChipState extends State<_DismissChip> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    return Semantics(
      button: true,
      label: 'Dismiss reminder',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: ext.fillBg(ext.brand),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: ext.brand.base.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.check_rounded,
                      size: 20, color: ext.fillFg(ext.brand)),
                  const SizedBox(width: 8),
                  Text('Dismiss',
                      style: TextStyle(
                          color: ext.fillFg(ext.brand),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          fontSize: 15)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SnoozeChip extends StatefulWidget {
  final AppColorsExt ext;
  final VoidCallback onTap;
  const _SnoozeChip({required this.ext, required this.onTap});
  @override
  State<_SnoozeChip> createState() => _SnoozeChipState();
}

class _SnoozeChipState extends State<_SnoozeChip> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final accent = ext.mark(ext.brand);
    return Semantics(
      button: true,
      label: 'Snooze 10 minutes',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withOpacity(0.45), width: 1.2),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.snooze_rounded, size: 20, color: accent),
                  const SizedBox(width: 8),
                  Text('Snooze',
                      style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          fontSize: 15)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Prominent primary "Take now" button for medicine alarms (foreground path).
class _TakeChip extends StatefulWidget {
  final AppColorsExt ext;
  final VoidCallback onTap;
  const _TakeChip({required this.ext, required this.onTap});
  @override
  State<_TakeChip> createState() => _TakeChipState();
}

class _TakeChipState extends State<_TakeChip> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final accent = widget.ext.mark(widget.ext.medicine);
    return Semantics(
      button: true,
      label: 'Mark medicine taken',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.check_rounded, size: 22, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Take now',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Painters ───────────────────────────

/// The living aurora: base wash + three diffuse light blobs on incommensurate
/// (but seamlessly-looping) orbits + a soft vignette. Heavy blur via MaskFilter.
class _AuroraPainter extends CustomPainter {
  final double t; // 0..1 master phase
  final List<Color> wash;
  final Color blobA, blobB, blobC;
  final double vignette;
  final bool vignetteWarm;

  _AuroraPainter({
    required this.t,
    required this.wash,
    required this.blobA,
    required this.blobB,
    required this.blobC,
    required this.vignette,
    required this.vignetteWarm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base wash
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: wash,
        ).createShader(rect),
    );

    final shorter = math.min(size.width, size.height);
    final r = shorter * 0.42;
    final sigma = (shorter * 0.14).clamp(90.0, 130.0);
    final ax = size.width * 0.15;
    final ay = size.height * 0.11;
    final tau = 2 * math.pi;

    void blob(Color c, double cx, double cy, double fx, double fy, double phase) {
      final x = cx + ax * math.sin(tau * (t * fx) + phase);
      final y = cy + ay * math.sin(tau * (t * fy) + phase * 0.5);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = c
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
    }

    // Integer frequencies → seamless loop; different phases → non-repeating feel.
    blob(blobA, size.width * 0.34, size.height * 0.32, 1, 2, 0);
    blob(blobB, size.width * 0.68, size.height * 0.40, 2, 1, math.pi * 0.6);
    blob(blobC, size.width * 0.50, size.height * 0.66, 2, 2, math.pi);

    // Vignette
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [
            Colors.transparent,
            (vignetteWarm ? const Color(0xFF3A2E24) : Colors.black)
                .withOpacity(vignette),
          ],
          stops: const [0.65, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.t != t || old.blobA != blobA;
}

/// Edge-lit rim: a teal→indigo stroke brightest along the top-left, a soft inner
/// top highlight, and a small specular glint that travels the top lip.
class _RimPainter extends CustomPainter {
  final double radius;
  final Color teal, indigo;
  final double sweep; // 0..1 position of the travelling glint
  final Color innerHighlight;

  _RimPainter({
    required this.radius,
    required this.teal,
    required this.indigo,
    required this.sweep,
    required this.innerHighlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect.deflate(0.75), Radius.circular(radius));

    // Edge-lit rim
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            teal.withOpacity(0.6),
            indigo.withOpacity(0.55),
            indigo.withOpacity(0.1),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );

    // Inner top highlight (specular sheen)
    canvas.drawLine(
      Offset(radius, 1.5),
      Offset(size.width - radius, 1.5),
      Paint()
        ..color = innerHighlight
        ..strokeWidth = 1
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );

    // Travelling glint along the top lip
    final gx = radius + (size.width - 2 * radius) * sweep;
    canvas.drawCircle(
      Offset(gx, 2),
      10,
      Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(covariant _RimPainter old) => old.sweep != sweep;
}
