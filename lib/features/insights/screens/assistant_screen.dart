import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/ai/insight.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/voice_input_service.dart';
import '../services/assistant_service.dart';
import '../services/chat_store.dart';
import 'memories_screen.dart';

/// Deterministic-first "Ask AI about my data" chat. Answers instantly from the
/// user's own logs + a curated knowledge base on-device; safety red-flags
/// short-circuit. Modern chat UX: persistent thread, capability empty state +
/// starter chips, typing indicator, suggested follow-ups, honest per-answer
/// engine badge + tappable source citations, copy + helpful/not-helpful
/// feedback, and a persistent disclaimer bar. Accessible: labelled controls and
/// ≥44px touch targets.
class AssistantScreen extends StatefulWidget {
  /// Optional question to ask automatically on open (e.g. deep-linking a
  /// suggested prompt). Null → the normal empty state.
  final String? initialQuestion;
  const AssistantScreen({super.key, this.initialQuestion});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  List<String> _followups = AssistantService.starters;
  bool _thinking = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    // Restore the previous thread so the conversation survives reopening.
    final saved = ChatStore.load();
    if (saved.isNotEmpty) {
      _messages.addAll(saved);
      _followups = const [];
      WidgetsBinding.instance.addPostFrameCallback((_) => _jump());
    }
    final initial = widget.initialQuestion?.trim();
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(initial));
    }
  }

  @override
  void dispose() {
    VoiceInputService.instance.cancel();
    _controller.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Puts an example into the composer (without sending) so the user can tweak
  /// a number then send — used by the "just log it" examples.
  void _prefill(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _inputFocus.requestFocus();
  }

  /// Toggles voice dictation into the composer. Falls back silently (a toast)
  /// when the device has no recognizer or the mic permission is denied.
  Future<void> _toggleMic() async {
    if (_listening) {
      await VoiceInputService.instance.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    final started = await VoiceInputService.instance.start(
      onText: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _controller.text = text;
          _controller.selection =
              TextSelection.collapsed(offset: text.length);
        });
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (started) {
      setState(() => _listening = true);
    } else {
      context.toastInfo(
          'Voice input isn\'t available on this device. You can type instead.');
    }
  }

  Future<void> _send(String raw) async {
    final q = raw.trim();
    if (q.isEmpty || _thinking) return;
    _controller.clear();
    FocusScope.of(context).unfocus();
    // Topic of the most recent answer — lets a follow-up ("why?") resolve to it.
    final contextTopic = _messages
        .lastWhere((m) => !m.isUser, orElse: () => ChatMessage(text: ''))
        .topic;
    setState(() {
      _messages.add(ChatMessage(text: q, isUser: true));
      _thinking = true;
      _followups = const [];
    });
    _jump();
    final reply =
        await AssistantService.answer(q, contextTopic: contextTopic);
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: reply.text,
        isEmergency: reply.isEmergency,
        sources: reply.sources,
        engine: reply.engine,
        topic: reply.topic,
      ));
      _followups = reply.followups;
      _thinking = false;
    });
    _persist();
    _jump();
  }

  void _persist() => ChatStore.save(_messages);

  Future<void> _clearThread() async {
    final ext = AppColorsExt.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColorsExt.of(ctx).surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        title: const Text('Start a new chat?'),
        content: const Text('This clears the current conversation. Your saved memories are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('New chat', style: TextStyle(color: ext.mark(ext.brand))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ChatStore.clear();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _followups = AssistantService.starters;
    });
  }

  void _setFeedback(ChatMessage m, int value) {
    setState(() => m.feedback = m.feedback == value ? 0 : value);
    HapticFeedback.selectionClick();
    _persist();
    if (m.feedback != 0) {
      context.toastInfo('Thanks — this helps me improve.');
    }
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'Ask AI',
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              tooltip: 'Back',
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            ),
            actions: [
              if (_messages.isNotEmpty)
                AppIconButton(
                  icon: Symbols.add_comment_rounded,
                  filled: false,
                  accent: accent,
                  tooltip: 'New chat',
                  onPressed: _clearThread,
                ),
              AppIconButton(
                icon: Symbols.psychology_rounded,
                filled: false,
                accent: accent,
                tooltip: 'Memory',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MemoriesScreen())),
              ),
              const SizedBox(width: AppSpacing.xs),
              const AiSeal(size: 24),
            ],
            bottom: Container(height: 1, color: ext.outline),
          ),
          Expanded(
            child: _messages.isEmpty ? _emptyState(ext, accent) : _list(ext, accent),
          ),
          if (_followups.isNotEmpty && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.sm),
              child: PromptChipRow(prompts: _followups, accent: accent, onTap: _send),
            ),
          _inputBar(ext, accent),
        ],
      ),
    );
  }

  Widget _emptyState(AppColorsExt ext, AccentSwatch accent) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                const AiSeal(size: 56),
                const SizedBox(height: AppSpacing.md),
                Text('Ask about your health',
                    style: tt.headlineMedium?.copyWith(color: ext.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Text(
                      'I answer from your own logs and a built-in wellness guide — all on this device. I show my sources and I don\'t give diagnoses.',
                      style: tt.bodyMedium
                          ?.copyWith(color: ext.textSecondary, height: 1.4)),
                ),
                const SizedBox(height: AppSpacing.xl),
                _starterMenu(ext),
                const SizedBox(height: AppSpacing.xl),
                _logMenu(ext, accent),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: SafetyDisclaimerBar(),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  /// One editorial index of starter prompts — hairline-separated rows with a
  /// shared topic-glyph rail. Each row is a labelled, ≥44px button.
  Widget _starterMenu(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    const starters = AssistantService.starters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TRY ASKING',
            style: tt.labelSmall
                ?.copyWith(color: ext.textTertiary, letterSpacing: 0.6)),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < starters.length; i++) ...[
                if (i != 0)
                  Container(
                    height: 1,
                    color: ext.outline,
                    margin:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  ),
                Semantics(
                  button: true,
                  label: 'Ask: ${starters[i]}',
                  child: InkWell(
                    onTap: () => _send(starters[i]),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(_starterIcon(starters[i]),
                                size: 16,
                                color: ext.mark(_starterAccent(context, starters[i]))),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(starters[i],
                                  style: tt.bodyMedium
                                      ?.copyWith(color: ext.textPrimary)),
                            ),
                            Icon(Symbols.arrow_outward_rounded,
                                size: 14, color: ext.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "Just log it" examples — tapping pre-fills the composer so the user learns
  /// they can record entries in plain words ("drank 500 ml" → ✓), not only ask.
  Widget _logMenu(AppColorsExt ext, AccentSwatch accent) {
    final tt = Theme.of(context).textTheme;
    const items = AssistantService.logExamples;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('OR JUST LOG IT',
            style: tt.labelSmall
                ?.copyWith(color: ext.textTertiary, letterSpacing: 0.6)),
        const SizedBox(height: AppSpacing.xs),
        Text('Tell me in plain words and I\'ll record it — tap one to try.',
            style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in items)
              AppChip(label: e, accent: accent, onTap: () => _prefill(e)),
          ],
        ),
      ],
    );
  }

  IconData _starterIcon(String p) {
    final s = p.toLowerCase();
    if (s.contains('pressure')) return Symbols.favorite_rounded;
    if (s.contains('water')) return Symbols.water_drop_rounded;
    if (s.contains('period')) return Symbols.calendar_month_rounded;
    if (s.contains('step')) return Symbols.directions_walk_rounded;
    if (s.contains('sleep')) return Symbols.bedtime_rounded;
    if (s.contains('streak')) return Symbols.local_fire_department_rounded;
    return Symbols.medication_rounded;
  }

  AccentSwatch _starterAccent(BuildContext context, String p) {
    final s = p.toLowerCase();
    if (s.contains('pressure')) {
      return InsightVisuals.accent(context, InsightFeature.bloodPressure);
    }
    if (s.contains('water')) {
      return InsightVisuals.accent(context, InsightFeature.water);
    }
    if (s.contains('period')) {
      return InsightVisuals.accent(context, InsightFeature.period);
    }
    if (s.contains('step')) {
      return InsightVisuals.accent(context, InsightFeature.steps);
    }
    if (s.contains('sleep')) {
      return InsightVisuals.accent(context, InsightFeature.sleep);
    }
    if (s.contains('streak')) {
      return InsightVisuals.accent(context, InsightFeature.crossCutting);
    }
    return InsightVisuals.accent(context, InsightFeature.medicine);
  }

  Widget _list(AppColorsExt ext, AccentSwatch accent) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.md),
      itemCount: _messages.length + (_thinking ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _messages.length) return _typing(ext);
        return _bubble(ext, accent, _messages[i]);
      },
    );
  }

  Widget _bubble(AppColorsExt ext, AccentSwatch accent, ChatMessage m) {
    final tt = Theme.of(context).textTheme;
    if (m.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ext.fillBg(accent),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          child: Text(m.text, style: tt.bodyMedium?.copyWith(color: ext.fillFg(accent))),
        ),
      );
    }
    final bg = m.isEmergency ? ext.error.container : ext.surfaceVariant;
    final fg = m.isEmergency ? ext.error.onContainer : ext.textPrimary;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm, right: 40),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.isEmergency) ...[
              Row(children: [
                Icon(Symbols.health_and_safety_rounded, size: 18, color: fg),
                const SizedBox(width: AppSpacing.sm),
                Text('Please reach out',
                    style: tt.labelMedium
                        ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: AppSpacing.sm),
            ],
            _answerBody(tt, fg, m.text),
            if (!m.isEmergency) ...[
              const SizedBox(height: AppSpacing.sm),
              // Provenance row: honest engine badge + every source (not just one).
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  EngineBadge(engine: m.engine),
                  for (final c in m.sources)
                    SourceChip(label: c.label, quote: c.body),
                ],
              ),
              const SizedBox(height: 2),
              // Actions: helpful / not-helpful feedback + copy (all ≥44px, labelled).
              Row(children: [
                _action(ext,
                    icon: m.feedback == 1
                        ? Symbols.thumb_up_rounded
                        : Symbols.thumb_up_rounded,
                    label: 'Helpful',
                    active: m.feedback == 1,
                    accent: accent,
                    onTap: () => _setFeedback(m, 1)),
                _action(ext,
                    icon: m.feedback == -1
                        ? Symbols.thumb_down_rounded
                        : Symbols.thumb_down_rounded,
                    label: 'Not helpful',
                    active: m.feedback == -1,
                    accent: accent,
                    onTap: () => _setFeedback(m, -1)),
                const Spacer(),
                _action(ext,
                    icon: Symbols.content_copy_rounded,
                    label: 'Copy answer',
                    accent: accent,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: m.text));
                      HapticFeedback.selectionClick();
                      context.toastSuccess('Copied');
                    }),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  /// A labelled, ≥44px icon action for the answer footer.
  Widget _action(AppColorsExt ext,
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      required AccentSwatch accent,
      bool active = false}) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: AppRadius.brFull,
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon,
                size: 17,
                color: active ? ext.mark(accent) : ext.textTertiary),
          ),
        ),
      ),
    );
  }

  /// Renders an answer, splitting off a trailing markdown-italic disclaimer
  /// (`\n\n_…_`, as added by SafetyGuard) so it shows as real italics — a quiet
  /// footnote — instead of literal underscores.
  Widget _answerBody(TextTheme tt, Color fg, String text) {
    final m = RegExp(r'^([\s\S]*?)\n\n_(.+)_\s*$').firstMatch(text);
    if (m == null) {
      return _md(tt, fg, text);
    }
    final ext = AppColorsExt.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _md(tt, fg, m.group(1)!.trimRight()),
        const SizedBox(height: AppSpacing.sm),
        Text(m.group(2)!,
            style: tt.bodySmall?.copyWith(
                color: ext.textTertiary,
                height: 1.35,
                fontStyle: FontStyle.italic)),
      ],
    );
  }

  /// Renders assistant text as markdown so **bold**, bullets and headings show
  /// properly instead of leaking literal asterisks. Bubble-colour aware.
  Widget _md(TextTheme tt, Color fg, String data) {
    final body = tt.bodyMedium?.copyWith(color: fg, height: 1.4);
    return MarkdownBody(
      data: data,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        p: body,
        listBullet: body,
        strong: body?.copyWith(fontWeight: FontWeight.w700),
        em: body?.copyWith(fontStyle: FontStyle.italic),
        h1: tt.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
        h2: tt.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
        h3: tt.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
        blockSpacing: AppSpacing.sm,
      ),
    );
  }

  Widget _typing(AppColorsExt ext) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: 'Assistant is typing',
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: ext.surfaceVariant, borderRadius: AppRadius.brLg),
          child: SizedBox(
            width: 34,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                  3,
                  (_) => Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: ext.textTertiary, shape: BoxShape.circle))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputBar(AppColorsExt ext, AccentSwatch accent) {
    final canSend = _controller.text.trim().isNotEmpty && !_thinking;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: ext.outline),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _inputFocus,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _listening
                          ? 'Listening…'
                          : 'Ask, or just log — e.g. "drank 500 ml"',
                      filled: true,
                      fillColor: ext.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: const OutlineInputBorder(
                          borderRadius: AppRadius.brFull,
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Semantics(
                  button: true,
                  label: _listening ? 'Stop voice input' : 'Voice input',
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Material(
                      color: _listening
                          ? ext.fillBg(accent)
                          : ext.surfaceVariant,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _thinking ? null : _toggleMic,
                        child: Icon(
                            _listening
                                ? Symbols.stop_rounded
                                : Symbols.mic_rounded,
                            color: _listening
                                ? ext.fillFg(accent)
                                : ext.textSecondary,
                            size: 22),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Semantics(
                  button: true,
                  enabled: canSend,
                  label: 'Send',
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Material(
                      color: canSend ? ext.fillBg(accent) : ext.surfaceVariant,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: canSend ? () => _send(_controller.text) : null,
                        child: Icon(Symbols.arrow_upward_rounded,
                            color: canSend
                                ? ext.fillFg(accent)
                                : ext.textDisabled,
                            size: 22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
