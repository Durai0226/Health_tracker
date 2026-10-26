import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/health/adaptive_timing.dart';
import '../../../core/services/clean_storage_service.dart';
import '../services/reminder_insights.dart';
import '../models/reminder_category_model.dart';
import '../models/reminder_model.dart';
import 'category_management_screen.dart';
import '../services/reminder_alarm.dart';
import 'package:clock/clock.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/utils/calendar_day.dart';
import '../services/reminder_pause_until.dart';
import '../widgets/reminder_end_pause_controls.dart';

class AddReminderScreen extends StatefulWidget {
  final Reminder? reminder;
  final String? noteId;

  // Optional pre-fill values for a NEW reminder (e.g. from AI "Smart Add").
  // Applied only when [reminder] is null so the edit flow is unaffected.
  final String? initialTitle;
  final DateTime? initialTime;
  final RepeatType? initialRepeat;
  final String? initialCategoryId;
  final ReminderPriority? initialPriority;
  final List<int>? initialCustomDays;

  /// An RFC 5545 rule from Smart Add ("every other Tuesday", "every 3 days"),
  /// for repeats the [RepeatType] dropdown cannot express. Carried through save
  /// untouched — there is no picker for it yet, so editing the repeat dropdown
  /// is what clears it.
  final String? initialRecurrenceRule;
  final DateTime? initialEndsAt;
  final int? initialOccurrenceLimit;

  const AddReminderScreen({
    super.key,
    this.reminder,
    this.noteId,
    this.initialTitle,
    this.initialTime,
    this.initialRepeat,
    this.initialCategoryId,
    this.initialPriority,
    this.initialCustomDays,
    this.initialRecurrenceRule,
    this.initialEndsAt,
    this.initialOccurrenceLimit,
  });

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  DateTime _selectedDate = clock.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  RepeatType _repeatType = RepeatType.none;
  List<int> _customDays = [];

  /// An RFC 5545 rule, when the repeat is richer than the dropdown can show.
  ///
  /// There is no picker for it yet, so it only ever arrives from Smart Add or
  /// from an existing row. Touching the repeat dropdown clears it — silently
  /// keeping a hidden "every other Tuesday" while the dropdown reads "Every
  /// Week" would be a reminder that does not do what the screen says.
  String? _recurrenceRule;
  DateTime? _endsAt;
  int? _occurrenceLimit;

  /// Paused keeps the reminder but arms nothing; [_pauseUntil] is the day it
  /// comes back on by itself (kept in `ReminderPauseUntil`, not on the row).
  bool _paused = false;
  DateTime? _pauseUntil;
  ReminderEscalation _escalation = ReminderEscalation.standard;

  /// "You usually do this at 08:40 — move it?"
  ///
  /// Only ever a suggestion with an explicit Apply. The engine behind it
  /// (`AdaptiveTiming`, via `ReminderInsights`) already refuses to be confident
  /// without ≥4 samples, a ≥15 minute shift and a tight IQR — but the reason it
  /// is not applied automatically is not statistical. Extraction can be
  /// automated; scheduling authority stays with the user.
  AdaptiveSuggestion? _timeSuggestion;
  int _snoozeDuration = 5;
  String _sound = 'default';
  // Default to a normal alert level — not every new reminder should fire at the
  // most aggressive priority. Users can raise it when it truly matters.
  ReminderPriority _priority = ReminderPriority.medium;
  String? _selectedCategoryId;
  String? _selectedImagePath;
  bool _isLoading = false;
  bool _isPlayingPreview = false;
  List<ReminderCategory> _categories = [];

  // Built-in sounds — each maps to a bundled audio asset that plays instantly
  // on selection (offline, no network).
  static const Map<String, Map<String, String>> _soundOptions = {
    'default': {'label': 'Default', 'category': 'Classic', 'icon': 'notifications', 'asset': 'assets/sounds/chime.wav'},
    'gentle_chime': {'label': 'Gentle Chime', 'category': 'Gentle', 'icon': 'music_note', 'asset': 'assets/sounds/gentle_chime.wav'},
    'soft_bells': {'label': 'Soft Bells', 'category': 'Gentle', 'icon': 'notifications_active', 'asset': 'assets/sounds/soft_bells.wav'},
    'marimba': {'label': 'Marimba', 'category': 'Melodic', 'icon': 'music_note', 'asset': 'assets/sounds/marimba.wav'},
    'sunrise': {'label': 'Sunrise', 'category': 'Melodic', 'icon': 'wb_sunny', 'asset': 'assets/sounds/sunrise.wav'},
    'pulse': {'label': 'Pulse', 'category': 'Classic', 'icon': 'graphic_eq', 'asset': 'assets/sounds/pulse.wav'},
    'calm': {'label': 'Calm', 'category': 'Gentle', 'icon': 'self_improvement', 'asset': 'assets/sounds/calm.wav'},
    'digital_alarm': {'label': 'Digital Alarm', 'category': 'Alert', 'icon': 'alarm', 'asset': 'assets/sounds/digital_alarm.wav'},
    'urgent_alert': {'label': 'Urgent Alert', 'category': 'Alert', 'icon': 'warning', 'asset': 'assets/sounds/urgent_alert.wav'},
  };

  /// A custom sound is stored as an absolute file path (from the device audio
  /// picker); built-in presets are stored as their key ('default', etc.).
  bool get _isCustomSound => _sound.startsWith('/');
  String get _customSoundName =>
      _isCustomSound ? _sound.split('/').last : _sound;

  @override
  void initState() {
    super.initState();

    if (widget.reminder != null) {
      _titleController.text = widget.reminder!.title;
      // Single free-text field: fold any legacy separate "note" into the
      // Description (body) when body is empty, so old records aren't lost.
      _bodyController.text = widget.reminder!.body.isNotEmpty
          ? widget.reminder!.body
          : (widget.reminder!.note ?? '');
      _selectedDate = widget.reminder!.scheduledTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.reminder!.scheduledTime);
      _repeatType = widget.reminder!.repeatType;
      _customDays = widget.reminder!.customDays != null
          ? List<int>.from(widget.reminder!.customDays!)
          : [];
      _recurrenceRule = widget.reminder!.recurrenceRule;
      _endsAt = widget.reminder!.endsAt;
      _occurrenceLimit = widget.reminder!.occurrenceLimit;
      _paused = widget.reminder!.isPaused;
      _pauseUntil = ReminderPauseUntil.get(widget.reminder!.id);
      _escalation = widget.reminder!.escalation;
      _loadTimeSuggestion();
      _snoozeDuration = widget.reminder?.snoozeDuration ?? 5;
      _sound = widget.reminder?.sound ?? 'default';
      // New reminders default to Medium (matches the model default) — High for
      // every reminder was needlessly aggressive.
      _priority = widget.reminder?.priority ?? ReminderPriority.medium;
      _selectedCategoryId = widget.reminder?.categoryId;
      _selectedImagePath = widget.reminder?.imagePath; // Load image path
    }

    // If creating new reminder, default time to next hour
    if (widget.reminder == null) {
      final now = clock.now();
      // Roll into the next day when created after 23:00 (hour 24 is invalid and
      // asserts in TimeOfDay).
      final next = now.add(const Duration(hours: 1));
      _selectedDate = DateTime(next.year, next.month, next.day, next.hour);
      _selectedTime = TimeOfDay(hour: next.hour, minute: 0);

      // Apply AI "Smart Add" pre-fill values (new reminders only).
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
      }
      if (widget.initialTime != null) {
        _selectedDate = widget.initialTime!;
        _selectedTime = TimeOfDay.fromDateTime(widget.initialTime!);
      }
      if (widget.initialRepeat != null) {
        _repeatType = widget.initialRepeat!;
      }
      if (widget.initialCategoryId != null) {
        _selectedCategoryId = widget.initialCategoryId;
      }
      if (widget.initialPriority != null) {
        _priority = widget.initialPriority!;
      }
      if (widget.initialCustomDays != null &&
          widget.initialCustomDays!.isNotEmpty) {
        _customDays = List<int>.from(widget.initialCustomDays!);
      }
      _recurrenceRule = widget.initialRecurrenceRule;
      _endsAt = widget.initialEndsAt;
      _occurrenceLimit = widget.initialOccurrenceLimit;
    }

    // Seed from the sync cache, then refresh from Drift.
    _categories = CleanStorageService.getAllCategories();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await CleanStorageService.getAllCategoriesAsync();
    if (mounted) {
      setState(() => _categories = categories);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Let the user pick a sound from their device's audio files.
  Future<void> _pickCustomSound() async {
    try {
      final picked = await FilePicker.pickFile(type: FileType.audio);
      final path = picked?.path;
      if (path != null && mounted) {
        setState(() => _sound = path);
        _previewSound(); // instant confirmation it plays
      }
    } catch (e) {
      debugPrint('Pick sound error: $e');
      if (mounted) {
        context.toastError('Could not open audio files: $e');
      }
    }
  }

  /// Plays the currently-selected sound so the user hears it: a bundled asset
  /// for presets, or the picked file for a custom device sound. All local — no
  /// network.
  Future<void> _previewSound() async {
    try {
      setState(() => _isPlayingPreview = true);
      await _audioPlayer.stop();
      if (_isCustomSound) {
        await _audioPlayer.setFilePath(_sound);
      } else {
        final asset =
            _soundOptions[_sound]?['asset'] ?? 'assets/sounds/chime.wav';
        await _audioPlayer.setAsset(asset);
      }
      await _audioPlayer.setVolume(0.85);
      await _audioPlayer.play();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          _audioPlayer.stop();
          setState(() => _isPlayingPreview = false);
        }
      });
    } catch (e) {
      debugPrint('Sound preview error: $e');
      if (mounted) {
        setState(() => _isPlayingPreview = false);
        context.toastError('Could not play this audio file.');
      }
    }
  }

  void _stopPreview() {
    _audioPlayer.stop();
    setState(() => _isPlayingPreview = false);
  }

  IconData _getSoundIcon(String iconName) {
    switch (iconName) {
      case 'notifications': return Symbols.notifications_rounded;
      case 'music_note': return Symbols.music_note_rounded;
      case 'notifications_active': return Symbols.notifications_active_rounded;
      case 'flutter_dash': return Symbols.flutter_dash_rounded;
      case 'water': return Symbols.water_rounded;
      case 'wb_sunny': return Symbols.wb_sunny_rounded;
      case 'star': return Symbols.star_rounded;
      case 'warning': return Symbols.warning_rounded;
      case 'alarm': return Symbols.alarm_rounded;
      case 'self_improvement': return Symbols.self_improvement_rounded;
      case 'graphic_eq': return Symbols.graphic_eq_rounded;
      default: return Symbols.music_note_rounded;
    }
  }

  Future<void> _selectDate() async {
    // shiftCalendarDays, not add(Duration(days:)): a civil day is 23 or 25
    // hours, so a year of absolute Durations lands a day out across a DST
    // boundary — and these are the picker's bounds, which an overdue reminder
    // is already compared against below.
    final lastDate = shiftCalendarDays(clock.now(), 365);
    final defaultFirst = shiftCalendarDays(clock.now(), -1);
    // An overdue reminder's date can be before defaultFirst; showDatePicker
    // asserts if initialDate < firstDate, so widen firstDate to include it and
    // clamp initialDate into [firstDate, lastDate] as a safety net.
    final firstDate =
        _selectedDate.isBefore(defaultFirst) ? _selectedDate : defaultFirst;
    final initialDate =
        _selectedDate.isAfter(lastDate) ? lastDate : _selectedDate;
    final picked = await AppDatePicker.show(
      context,
      initial: initialDate,
      first: firstDate,
      last: lastDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await AppTimePicker.show(context, initial: _selectedTime);
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      var scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // A ONE-OFF set in the past fires the instant it is saved.
      //
      // There was no validation at all: pick 14:00 when it is already 16:00 and
      // `zonedSchedule`/`oneShotAt` deliver immediately, so the reminder rings
      // while the user is still looking at the screen they created it on and is
      // then gone. Rolling it to the same time tomorrow is what the user
      // almost certainly meant; the alternative — refusing to save — loses the
      // rest of their input.
      var rolledForward = false;
      final oneOff = _repeatType == RepeatType.none && _recurrenceRule == null;
      if (oneOff && scheduledDateTime.isBefore(clock.now())) {
        // Keep the CHOSEN clock time and move it to the next date on which it
        // is still ahead — today if the time has not passed yet, otherwise
        // tomorrow. `shiftCalendarDays` preserves the wall clock across a DST
        // transition, where `add(Duration(days: 1))` would shift it by an hour.
        final now = clock.now();
        var candidate = DateTime(now.year, now.month, now.day,
            _selectedTime.hour, _selectedTime.minute);
        if (!candidate.isAfter(now)) {
          candidate = shiftCalendarDays(candidate, 1);
        }
        scheduledDateTime = candidate;
        rolledForward = true;
      }

      // An end before the first reminder means it would never fire at all.
      final end = _endsAt;
      if (end != null && !end.isAfter(scheduledDateTime)) {
        if (mounted) {
          setState(() => _isLoading = false);
          context.toastWarning(
              'The end date has to come after the first reminder.');
        }
        return;
      }

      final reminderId = widget.reminder?.id ?? const Uuid().v4();

      final reminder = Reminder(
        id: reminderId,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        scheduledTime: scheduledDateTime,
        isCompleted: false, // Reset completed status on edit
        createdAt: widget.reminder?.createdAt,
        repeatType: _repeatType,
        customDays: _repeatType == RepeatType.custom ? _customDays : null,
        snoozeDuration: _snoozeDuration,
        sound: _sound,
        priority: _priority,
        categoryId: _selectedCategoryId,
        note: null, // merged into `body`; field kept (deprecated) for old records
        imagePath: _selectedImagePath,
        noteId: widget.noteId ?? widget.reminder?.noteId,
        // Preserved on edit so an existing reminder keeps the id it is already
        // armed under; null for a new one, and allocated by the save below.
        notificationId: widget.reminder?.notificationId,
        recurrenceRule: _recurrenceRule,
        endsAt: _endsAt,
        occurrenceLimit: _occurrenceLimit,
        isPaused: _paused,
        escalation: _escalation,
      );

      // Save FIRST and arm under the id that was actually stored. The id used to
      // be `reminderId.hashCode`, which is unreserved and can collide with the
      // fixed blocks other features own.
      final saved =
          await CleanStorageService.saveReminderAllocatingId(reminder);

      // The resume date goes with the pause: kept only while it is paused.
      if (_paused && _pauseUntil != null) {
        await ReminderPauseUntil.set(saved.id, _pauseUntil!);
      } else {
        await ReminderPauseUntil.clear(saved.id);
      }

      // Through the ReminderAlarm seam, not straight at NotificationService.
      //
      // `arm`/`disarm` are the only place the +2000 follow-up alarm is armed
      // and cancelled, and they were called ONLY from the app-start re-arm
      // pass. So an Insistent reminder created here got no follow-up until the
      // next launch, and editing one left the previously-armed follow-up
      // pointing at the old schedule. Going through the seam also applies the
      // recurrence rule (see ReminderArmRequest.forNextOccurrence) instead of
      // the raw RepeatType.
      final request = ReminderArmRequest.forNextOccurrence(saved);
      if (request == null) {
        // Paused, or already past its end date — make sure nothing is armed.
        await const NotificationReminderAlarm().disarm(
          id: saved.notificationSlot,
          repeatType: saved.repeatType,
          customDays: saved.customDays,
        );
        if (mounted) Navigator.pop(context);
        return;
      }

      final armed = await const NotificationReminderAlarm().arm(request);

      if (!mounted) return;
      Navigator.pop(context);

      // The reminder IS saved either way — it is in the list and the re-arm
      // pass will retry at the next launch. What must not happen is popping in
      // silence when the OS refused to schedule it, which is what
      // `scheduleGenericReminder` returning an unconditional `true` used to
      // cause with SCHEDULE_EXACT_ALARM revoked.
      if (!armed) {
        context.toastWarning(
          'Saved, but it could not be scheduled — check notification and '
          'alarm permissions.',
          action: AppToastAction(
            label: 'Open settings',
            onPressed: () => openAppSettings(),
          ),
        );
      } else if (rolledForward) {
        final t = TimeOfDay.fromDateTime(scheduledDateTime);
        final when = DateUtils.isSameDay(scheduledDateTime, clock.now())
            ? 'today'
            : 'tomorrow';
        context.toastInfo(
            'That time had passed — set for $when at ${t.format(context)}.');
      }
    } catch (e) {
      if (mounted) {
        context.toastError('Error saving reminder: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final rem = ext.reminders;
    final tt = Theme.of(context).textTheme;
    final dateFormat = DateFormat('EEE, MMM d, y');
    final isEditing = widget.reminder != null;

    return AccentScope(
      feature: FeatureAccent.reminders,
      child: AppScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppHeader(
              title: isEditing ? 'Edit Reminder' : 'New Reminder',
              leading: IconButton(
                icon: Icon(Symbols.close_rounded, color: ext.textPrimary),
                // An ✕ announces as a bare "button" without this — and the
                // control that discards a half-filled form is the last one
                // that should be unnamed.
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
              // Single Save affordance — the primary "Create Reminder" / "Save
              // Changes" button at the end of the form (the duplicate header
              // Save was removed).
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---- Details ----
                      AppTextField(
                        controller: _titleController,
                        label: 'Title',
                        hint: 'What needs to be done?',
                        accent: rem,
                        textCapitalization: TextCapitalization.sentences,
                        // `trim()`, not `isEmpty`: the title is stored as
                        // `_titleController.text.trim()`, so a whitespace-only
                        // entry passed validation and then saved a reminder with
                        // an EMPTY title — a blank row in the list and a blank
                        // heading on the notification.
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Please enter a title'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _bodyController,
                        label: 'Description (Optional)',
                        hint: 'Add details...',
                        accent: rem,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Schedule ----
                      SectionHeader(
                        title: 'Schedule',
                        icon: Symbols.event_rounded,
                        accent: rem,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        child: Column(
                          children: [
                            _buildTimeRow(
                              icon: Symbols.calendar_today_rounded,
                              label: 'Date',
                              value: dateFormat.format(_selectedDate),
                              onTap: _selectDate,
                            ),
                            Divider(height: AppSpacing.xl, color: ext.outline),
                            _buildTimeRow(
                              icon: Symbols.access_time_rounded,
                              label: 'Time',
                              value: _selectedTime.format(context),
                              onTap: _selectTime,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      if (_timeSuggestion != null) ...[
                        _buildTimeSuggestion(ext, rem),
                        const SizedBox(height: AppSpacing.xl),
                      ],

                      // ---- Repeat ----
                      SectionHeader(
                        title: 'Repeat',
                        icon: Symbols.repeat_rounded,
                        accent: rem,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDropdownShell(
                        ext: ext,
                        rem: rem,
                        child: DropdownButton<RepeatType>(
                          value: _repeatType,
                          isExpanded: true,
                          borderRadius: AppRadius.brMd,
                          dropdownColor: ext.surface,
                          style: tt.bodyLarge?.copyWith(color: ext.textPrimary),
                          icon: Icon(Symbols.keyboard_arrow_down_rounded,
                              color: ext.mark(rem)),
                          // Every repeat type, unconditionally.
                          //
                          // `custom` (pick your own days) used to be gated
                          // behind FeatureFlagService.keyAdvancedRepeat, which
                          // is off by default and toggleable only from the
                          // early-access screen — so on a stock install the one
                          // repeat option people actually reach for was invisible,
                          // while the on-device parser could produce it from
                          // "every Mon and Thu" and the DB happily stored it.
                          items: RepeatType.values.map((type) {
                            String label;
                            switch (type) {
                              case RepeatType.none: label = 'Does not repeat'; break;
                              case RepeatType.daily: label = 'Every Day'; break;
                              case RepeatType.weekly: label = 'Every Week'; break;
                              case RepeatType.weekdays: label = 'Every Weekday (Mon-Fri)'; break;
                              case RepeatType.weekends: label = 'Every Weekend (Sat-Sun)'; break;
                              case RepeatType.custom: label = 'Custom'; break;
                            }
                            return DropdownMenuItem(
                              value: type,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _repeatType = value;
                                // Picking from the dropdown discards any RRULE.
                                // Keeping a hidden "every other Tuesday" while
                                // the dropdown reads "Every Week" would be a
                                // reminder that does not do what the screen says.
                                _recurrenceRule = null;
                                if (value == RepeatType.custom && _customDays.isEmpty) {
                                  // Default to today if empty
                                  _customDays.add(_selectedDate.weekday);
                                }
                              });
                            }
                          },
                        ),
                      ),
                      if (_repeatType == RepeatType.custom) ...[
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          // xs, not sm: each toggle now carries 2pt of hit box
                          // on every side of its 40pt circle (see
                          // _buildDayToggle), so 4pt here leaves the SAME 8pt
                          // gap between circles while the seven 44pt targets
                          // still fit a 390pt phone inside the gutters.
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.sm,
                          children: [
                            _buildDayToggle('M', 1),
                            _buildDayToggle('T', 2),
                            _buildDayToggle('W', 3),
                            _buildDayToggle('T', 4),
                            _buildDayToggle('F', 5),
                            _buildDayToggle('S', 6),
                            _buildDayToggle('S', 7),
                          ],
                        ),
                      ],
                      // ---- Ends ---- (only a repeating reminder has an end)
                      if (_repeatType != RepeatType.none ||
                          _recurrenceRule != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        SectionHeader(
                          title: 'Ends',
                          icon: Symbols.event_busy_rounded,
                          accent: rem,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ReminderEndsControl(
                          endsAt: _endsAt,
                          limit: _occurrenceLimit,
                          firstDate: DateTime(_selectedDate.year,
                              _selectedDate.month, _selectedDate.day),
                          accent: rem,
                          onChanged: (e, l) => setState(() {
                            _endsAt = e;
                            _occurrenceLimit = l;
                          }),
                        ),
                      ],
                      // ---- Pause ---- (an existing reminder only)
                      if (widget.reminder != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        SectionHeader(
                          title: 'Pause',
                          icon: Symbols.pause_circle_rounded,
                          accent: rem,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ReminderPauseControl(
                          paused: _paused,
                          until: _pauseUntil,
                          accent: rem,
                          onChanged: (p, u) => setState(() {
                            _paused = p;
                            _pauseUntil = p ? u : null;
                          }),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Snooze ----
                      SectionHeader(
                        title: 'Snooze Duration',
                        icon: Symbols.snooze_rounded,
                        accent: rem,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDropdownShell(
                        ext: ext,
                        rem: rem,
                        child: DropdownButton<int>(
                          value: _snoozeDuration,
                          isExpanded: true,
                          borderRadius: AppRadius.brMd,
                          dropdownColor: ext.surface,
                          style: tt.bodyLarge?.copyWith(color: ext.textPrimary),
                          icon: Icon(Symbols.keyboard_arrow_down_rounded,
                              color: ext.mark(rem)),
                          items: [5, 10, 15, 30, 60].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                value >= 60 ? '${value ~/ 60} hour' : '$value minutes',
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              setState(() => _snoozeDuration = newValue);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Alarm Sound ----
                      SectionHeader(
                        title: 'Alarm Sound',
                        icon: Symbols.music_note_rounded,
                        accent: rem,
                        actionLabel: _isPlayingPreview ? 'Stop' : null,
                        onAction: _isPlayingPreview ? _stopPreview : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            // Current selection with preview button
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: rem.container,
                                      borderRadius: AppRadius.brSm,
                                    ),
                                    child: Icon(
                                      _isCustomSound
                                          ? Symbols.audiotrack_rounded
                                          : _getSoundIcon(_soundOptions[_sound]
                                                  ?['icon'] ??
                                              'notifications'),
                                      color: rem.onContainer,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isCustomSound
                                              ? _customSoundName
                                              : (_soundOptions[_sound]?['label'] ??
                                                  'Default'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: tt.titleLarge
                                              ?.copyWith(color: ext.textPrimary),
                                        ),
                                        Text(
                                          _isCustomSound
                                              ? 'Custom sound from device'
                                              : (_soundOptions[_sound]
                                                      ?['category'] ??
                                                  'Classic'),
                                          style: tt.bodyMedium
                                              ?.copyWith(color: ext.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Every sound is playable (bundled asset or
                                  // picked file) — tap to hear it.
                                  IconButton(
                                    onPressed: _isPlayingPreview
                                        ? _stopPreview
                                        : _previewSound,
                                    icon: Icon(
                                      _isPlayingPreview
                                          ? Symbols.stop_circle_rounded
                                          : Symbols.play_circle_rounded,
                                      color: _isPlayingPreview
                                          ? ext.mark(ext.error)
                                          : ext.mark(rem),
                                      size: 32,
                                    ),
                                    tooltip: _isPlayingPreview
                                        ? 'Stop preview'
                                        : 'Preview sound',
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: ext.outline),
                            // Sound selection grid
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  // Pick any audio file from the device.
                                  AppChip(
                                    label: 'Choose from device',
                                    icon: Symbols.folder_open_rounded,
                                    selected: _isCustomSound,
                                    accent: rem,
                                    onTap: _pickCustomSound,
                                  ),
                                  ..._soundOptions.entries.map((entry) {
                                    return AppChip(
                                      label: entry.value['label'] ?? entry.key,
                                      icon: _getSoundIcon(
                                          entry.value['icon'] ?? 'notifications'),
                                      selected: _sound == entry.key,
                                      accent: rem,
                                      // Tap to select (no surprise auto-play);
                                      // tap the already-selected one to preview.
                                      onTap: () {
                                        if (_sound == entry.key) {
                                          _previewSound();
                                        } else {
                                          setState(() => _sound = entry.key);
                                        }
                                      },
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Priority ----
                      SectionHeader(
                        title: 'Priority',
                        icon: Symbols.flag_rounded,
                        accent: rem,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPriorityOption(
                                ReminderPriority.low, 'Low', ext.success, ext),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildPriorityOption(
                                ReminderPriority.medium, 'Medium', ext.warning, ext),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildPriorityOption(
                                ReminderPriority.high, 'High', ext.error, ext),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- How insistent ----
                      //
                      // Distinct from Priority above, which orders the LIST.
                      // This decides what happens when the reminder is ignored:
                      // whether it rings, whether it asks again, whether it
                      // takes over the screen. Before this existed the answer
                      // was decided by whichever code path scheduled it.
                      SectionHeader(
                        title: 'If you don\'t respond',
                        icon: Symbols.notifications_active_rounded,
                        accent: rem,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Column(
                        children: [
                          for (final level in ReminderEscalation.values) ...[
                            _buildEscalationOption(level, ext, rem),
                            if (level != ReminderEscalation.values.last)
                              const SizedBox(height: AppSpacing.xs),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Category ----
                      SectionHeader(
                        title: 'Category',
                        icon: Symbols.label_rounded,
                        accent: rem,
                        actionLabel: 'Manage',
                        onAction: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CategoryManagementScreen()),
                          );
                          _loadCategories();
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDropdownShell(
                        ext: ext,
                        rem: rem,
                        child: DropdownButton<String?>(
                          value: _categories.any((c) => c.id == _selectedCategoryId)
                              ? _selectedCategoryId
                              : null,
                          isExpanded: true,
                          borderRadius: AppRadius.brMd,
                          dropdownColor: ext.surface,
                          style: tt.bodyLarge?.copyWith(color: ext.textPrimary),
                          hint: Text('Select Category',
                              style: tt.bodyLarge?.copyWith(color: ext.textTertiary)),
                          icon: Icon(Symbols.keyboard_arrow_down_rounded,
                              color: ext.mark(rem)),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('None',
                                  style: tt.bodyLarge?.copyWith(color: ext.textPrimary)),
                            ),
                            ..._categories.map((category) {
                              return DropdownMenuItem<String?>(
                                value: category.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: category.colorObj,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(category.iconObj, size: 18, color: category.colorObj),
                                    const SizedBox(width: 8),
                                    Text(category.name),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedCategoryId = value);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Attachments ----
                      SectionHeader(
                        title: 'Attachments',
                        icon: Symbols.attach_file_rounded,
                        accent: rem,
                        actionLabel: _selectedImagePath == null ? 'Add Image' : null,
                        onAction: _selectedImagePath == null ? _pickImage : null,
                      ),
                      if (_selectedImagePath != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: AppRadius.brCard,
                              child: Image.file(
                                File(_selectedImagePath!),
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: AppSpacing.sm,
                              right: AppSpacing.sm,
                              child: Material(
                                color: ext.surface,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                // Named, because the ✕ is the only thing in
                                // here and an unnamed icon announces as a bare
                                // "button". NOT `excludeSemantics: true`: that
                                // drops the InkWell's own node — tap action and
                                // all — and leaves a node a screen reader can
                                // read out but cannot activate. Without it the
                                // annotation merges INTO the InkWell's node, so
                                // the name and the tap live together. Same
                                // reason [_buildDayToggle] excludes at the
                                // [Text] instead.
                                child: Semantics(
                                  button: true,
                                  label: 'Remove photo',
                                  child: InkWell(
                                    onTap: _removeImage,
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(Symbols.close_rounded,
                                          color: ext.mark(ext.error), size: 20),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Save ----
                      AppButton(
                        label: isEditing ? 'Save Changes' : 'Create Reminder',
                        accent: rem,
                        fullWidth: true,
                        size: AppButtonSize.lg,
                        loading: _isLoading,
                        leadingIcon: Symbols.check_rounded,
                        onPressed: _saveReminder,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // Save the image to app directory for persistence
      final directory = await getApplicationDocumentsDirectory();
      final String path = directory.path;
      final String fileName = '${const Uuid().v4()}.jpg';
      final File newImage = await File(pickedFile.path).copy('$path/$fileName');

      setState(() {
        _selectedImagePath = newImage.path;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImagePath = null;
    });
  }

  /// Token-styled shell for the native DropdownButton.
  Widget _buildDropdownShell({
    required AppColorsExt ext,
    required AccentSwatch rem,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: ext.surfaceVariant,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: ext.outline),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  Future<void> _loadTimeSuggestion() async {
    final reminder = widget.reminder;
    if (reminder == null) return;
    try {
      final occurrences =
          await CleanStorageService.getReminderOccurrences(reminder.id);
      final suggestion = ReminderInsights.suggestTimeShift(
        reminder: reminder,
        occurrences: occurrences,
      );
      if (!mounted || !suggestion.confident) return;
      setState(() => _timeSuggestion = suggestion);
    } catch (e) {
      debugPrint('⚠️ Loading the time suggestion failed: $e');
    }
  }

  Widget _buildTimeSuggestion(AppColorsExt ext, AccentSwatch rem) {
    final s = _timeSuggestion!;
    final hour = s.suggestedMinutes ~/ 60;
    final minute = s.suggestedMinutes % 60;
    final label = TimeOfDay(hour: hour, minute: minute).format(context);
    final later = s.deltaMinutes > 0;
    return AppCard(
      child: Row(
        children: [
          Icon(Symbols.schedule_rounded, color: ext.mark(rem), size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You usually do this around $label',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: ext.textPrimary),
                ),
                Text(
                  'Based on ${s.sampleCount} times you marked it done, '
                  '${s.deltaMinutes.abs()} min ${later ? 'later' : 'earlier'} '
                  'than scheduled.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: 'Move it',
            size: AppButtonSize.sm,
            variant: AppButtonVariant.tonal,
            onPressed: () => setState(() {
              _selectedTime = TimeOfDay(hour: hour, minute: minute);
              _selectedDate = DateTime(_selectedDate.year, _selectedDate.month,
                  _selectedDate.day, hour, minute);
              // Dismiss once applied — leaving it up would invite the user to
              // "apply" a shift that is already in the form.
              _timeSuggestion = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEscalationOption(
      ReminderEscalation level, AppColorsExt ext, AccentSwatch rem) {
    final isSelected = _escalation == level;
    return GestureDetector(
      onTap: () => setState(() => _escalation = level),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? rem.container : ext.surfaceVariant,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: isSelected ? ext.mark(rem) : ext.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Symbols.radio_button_checked_rounded
                  : Symbols.radio_button_unchecked_rounded,
              size: 20,
              color: isSelected ? ext.mark(rem) : ext.textTertiary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: ext.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                  ),
                  Text(
                    level.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ext.textSecondary,
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

  Widget _buildPriorityOption(
      ReminderPriority priority, String label, AccentSwatch swatch, AppColorsExt ext) {
    final isSelected = _priority == priority;
    return GestureDetector(
      onTap: () => setState(() => _priority = priority),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? swatch.container : ext.surfaceVariant,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: isSelected ? ext.mark(swatch) : ext.outline,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _getPriorityIcon(priority),
              color: isSelected ? ext.mark(swatch) : ext.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isSelected ? ext.mark(swatch) : ext.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPriorityIcon(ReminderPriority priority) {
    switch (priority) {
      case ReminderPriority.high: return Symbols.notifications_active_rounded;
      case ReminderPriority.medium: return Symbols.notifications_rounded;
      case ReminderPriority.low: return Symbols.notifications_none_rounded;
    }
  }

  Widget _buildTimeRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final ext = AppColorsExt.of(context);
    final rem = ext.reminders;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: rem.container,
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(icon, color: rem.onContainer, size: 20),
            ),
            const SizedBox(width: AppSpacing.lg),
            // Expanded on the VALUE, not a Spacer.
            //
            // `label` is a fixed short word ("Date"/"Time"); `value` is a
            // formatted date — 'EEE, MMM d, y' is "Wed, Sep 30, 2026" — and the
            // chip took whatever width it wanted. Both rows overflowed on a
            // 320pt phone, by 122px at 1.0x and 407px at 2.0x.
            //
            // This was invisible until the screen moved to `clock.now()`:
            // against the wall clock it rendered a date the pinned test seed
            // never matched, so the responsive sweep measured a different
            // layout from the one users see.
            Text(
              label,
              style: tt.titleLarge?.copyWith(color: ext.textPrimary),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ext.surfaceVariant,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelLarge?.copyWith(color: ext.mark(rem)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The Apple HIG minimum. The circle stays 40 so the row looks unchanged.
  static const double _dayToggleTarget = 44.0;

  /// Indexed by `DateTime.weekday - 1`, matching the `day` the toggles pass and
  /// the `customDays` values they store.
  static const List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// One day-of-week toggle: a 40pt circle inside a 44pt target.
  ///
  /// This is the control that decides which days a reminder fires on, and it
  /// was a bare 40x40 `GestureDetector` — under the 44pt floor, with no name
  /// and no state. A screen reader reached seven unlabelled buttons and could
  /// not tell which days were already on.
  Widget _buildDayToggle(String label, int day) {
    final ext = AppColorsExt.of(context);
    final rem = ext.reminders;
    final isSelected = _customDays.contains(day);
    return Semantics(
      button: true,
      selected: isSelected,
      // The full name, because the visible letter cannot be the accessible one:
      // 'T' is both Tuesday and Thursday, 'S' both Saturday and Sunday. The
      // letter itself is excluded down at the [Text] rather than with
      // `excludeSemantics` here — that would also drop the tap action this
      // annotation has to merge with, leaving a named node nothing can
      // activate.
      label: _dayNames[day - 1],
      child: GestureDetector(
        // Opaque: the 2pt ring of padding around the circle has no painted
        // child of its own, so without this the target is 40pt again.
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            if (isSelected) {
              _customDays.remove(day);
            } else {
              _customDays.add(day);
            }
          });
        },
        child: SizedBox(
          width: _dayToggleTarget,
          height: _dayToggleTarget,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? rem.container : ext.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? ext.mark(rem) : ext.outline,
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected ? rem.onContainer : ext.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
