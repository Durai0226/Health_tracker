import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../design/app_design.dart';
import '../../services/llm_service.dart';
import 'app_card.dart';
import 'app_button.dart';
import 'primitives.dart';
import 'app_bottom_sheet.dart';

/// Shared AI UI kit (Calm Clarity). Both pieces degrade gracefully when no AI
/// key is configured — they nudge the user to Settings and never block.

/// A self-loading insight card: runs [loader] once, renders the markdown result,
/// and offers a refresh. Shows a gentle "enable AI" state when unconfigured.
class AiInsightCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final AccentSwatch accent;
  final Future<String?> Function() loader;

  const AiInsightCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.loader,
  });

  @override
  State<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<AiInsightCard> {
  String? _text;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (LlmService().isConfigured) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final t = await widget.loader();
    if (!mounted) return;
    setState(() {
      _text = t;
      _failed = t == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final s = widget.accent;

    // Not configured → subtle prompt (never intrusive).
    if (!LlmService().isConfigured) {
      return AppCard(
        color: s.container,
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: s.onContainer, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Turn on the AI Assistant in Settings for personalized ${widget.title.toLowerCase()}.',
                style: tt.bodyMedium?.copyWith(color: s.onContainer),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration:
                    BoxDecoration(color: s.container, borderRadius: AppRadius.brSm),
                child: Icon(widget.icon, color: s.onContainer, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(widget.title,
                    style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
              ),
              const Icon(Icons.auto_awesome_rounded, size: 14),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: Icon(Icons.refresh_rounded, color: ext.mark(s), size: 20),
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_loading)
            Row(
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: ext.mark(s))),
                const SizedBox(width: AppSpacing.md),
                Text('Thinking…',
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
              ],
            )
          else if (_failed || _text == null)
            InkWell(
              onTap: _load,
              child: Text('Couldn\'t generate a tip right now. Tap to retry.',
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
            )
          else
            MarkdownBody(
              data: _text!,
              styleSheet: _mdStyle(context, ext),
            ),
        ],
      ),
    );
  }
}

/// A bottom-sheet "Ask AI" experience: a text field + answer area (markdown).
class AiAskSheet {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required AccentSwatch accent,
    String hint = 'Ask a question…',
    String? disclaimer,
    String? initialQuestion,
    required Future<String?> Function(String question) onAsk,
  }) {
    return AppBottomSheet.show<void>(
      context,
      title: title,
      icon: Icons.auto_awesome_rounded,
      accent: accent,
      builder: (ctx) => _AiAskBody(
        accent: accent,
        hint: hint,
        disclaimer: disclaimer,
        initialQuestion: initialQuestion,
        onAsk: onAsk,
      ),
    );
  }
}

class _AiAskBody extends StatefulWidget {
  final AccentSwatch accent;
  final String hint;
  final String? disclaimer;
  final String? initialQuestion;
  final Future<String?> Function(String question) onAsk;

  const _AiAskBody({
    required this.accent,
    required this.hint,
    required this.onAsk,
    this.disclaimer,
    this.initialQuestion,
  });

  @override
  State<_AiAskBody> createState() => _AiAskBodyState();
}

class _AiAskBodyState extends State<_AiAskBody> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _answer;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuestion != null) {
      _controller.text = widget.initialQuestion!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _failed = false;
      _answer = null;
    });
    final a = await widget.onAsk(q);
    if (!mounted) return;
    setState(() {
      _answer = a;
      _failed = a == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    if (!LlmService().isConfigured) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add your AI key in Settings → AI Assistant to use this.',
                style: tt.bodyLarge?.copyWith(color: ext.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Close',
              variant: AppButtonVariant.secondary,
              accent: widget.accent,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _controller,
          hint: widget.hint,
          accent: widget.accent,
          maxLines: 2,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _ask(),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Ask',
          leadingIcon: Icons.auto_awesome_rounded,
          accent: widget.accent,
          loading: _loading,
          fullWidth: true,
          onPressed: _loading ? null : _ask,
        ),
        if (_answer != null || _failed) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: ext.surfaceVariant,
              borderRadius: AppRadius.brMd,
            ),
            child: _failed
                ? Text('Couldn\'t get an answer right now. Please try again.',
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary))
                : MarkdownBody(data: _answer!, styleSheet: _mdStyle(context, ext)),
          ),
        ],
        if (widget.disclaimer != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(widget.disclaimer!,
              style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

MarkdownStyleSheet _mdStyle(BuildContext context, AppColorsExt ext) {
  final tt = Theme.of(context).textTheme;
  return MarkdownStyleSheet(
    p: tt.bodyMedium?.copyWith(color: ext.textPrimary, height: 1.45),
    listBullet: tt.bodyMedium?.copyWith(color: ext.textPrimary),
    strong: tt.bodyMedium?.copyWith(
        color: ext.textPrimary, fontWeight: FontWeight.w700),
    h1: tt.titleLarge?.copyWith(color: ext.textPrimary),
    h2: tt.titleMedium?.copyWith(color: ext.textPrimary),
    h3: tt.titleSmall?.copyWith(color: ext.textPrimary),
  );
}
