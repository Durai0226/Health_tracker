import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/ai/ai_types.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../services/assistant_service.dart';

class _Msg {
  final String text;
  final bool isUser;
  final bool isEmergency;
  const _Msg(this.text, {this.isUser = false, this.isEmergency = false});
}

/// Deterministic-first "Ask AI about my data" chat. Answers instantly from the
/// user's own logs on-device; safety red-flags short-circuit. Follows the
/// research UX: capability empty state + starter chips, typing indicator,
/// suggested follow-ups, per-answer engine badge, copy action, disclaimer bar.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];
  List<String> _followups = AssistantService.starters;
  bool _thinking = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final q = raw.trim();
    if (q.isEmpty || _thinking) return;
    _controller.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _messages.add(_Msg(q, isUser: true));
      _thinking = true;
      _followups = const [];
    });
    _jump();
    final reply = await AssistantService.answer(q);
    if (!mounted) return;
    setState(() {
      _messages.add(_Msg(reply.text, isEmergency: reply.isEmergency));
      _followups = reply.followups;
      _thinking = false;
    });
    _jump();
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
            icon: kAiSparkle,
            accent: accent,
            leading: AppIconButton(
              icon: Icons.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        const SizedBox(height: 24),
        Icon(kAiSparkle, size: 48, color: ext.mark(accent)),
        const SizedBox(height: AppSpacing.md),
        Text('Ask about your health data',
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text(
            'I answer from your own logs on this device — adherence, water, blood pressure, blood sugar, focus and streaks. I don\'t give diagnoses.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        ...AssistantService.starters.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                onTap: () => _send(s),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: ext.mark(accent)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(s, style: tt.bodyMedium?.copyWith(color: ext.textPrimary))),
                  Icon(Icons.north_east_rounded, size: 14, color: ext.textTertiary),
                ]),
              ),
            )),
        const SizedBox(height: AppSpacing.md),
        const SafetyDisclaimerBar(),
      ],
    );
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

  Widget _bubble(AppColorsExt ext, AccentSwatch accent, _Msg m) {
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
    final bg = m.isEmergency ? const Color(0xFF7F1D1D) : ext.surfaceVariant;
    final fg = m.isEmergency ? Colors.white : ext.textPrimary;
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
            Text(m.text, style: tt.bodyMedium?.copyWith(color: fg, height: 1.4)),
            if (!m.isEmergency) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                const EngineBadge(engine: AiEngineKind.ruleBased),
                const Spacer(),
                InkWell(
                  borderRadius: AppRadius.brFull,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: m.text));
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied')));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.copy_rounded, size: 15, color: ext.textTertiary),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typing(AppColorsExt ext) {
    return Align(
      alignment: Alignment.centerLeft,
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
    );
  }

  Widget _inputBar(AppColorsExt ext, AccentSwatch accent) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Ask about your data…',
                  filled: true,
                  fillColor: ext.surfaceVariant,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: AppRadius.brFull, borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Material(
              color: ext.fillBg(accent),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _send(_controller.text),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.arrow_upward_rounded, color: ext.fillFg(accent), size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
