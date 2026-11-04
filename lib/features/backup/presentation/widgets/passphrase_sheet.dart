import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/services/backup_encryption.dart';
import '../../../../core/widgets/app/app_widgets.dart';

/// The two questions about a backup's passphrase: choosing one when it is made,
/// and giving it when the backup is opened.
class PassphraseSheet {
  const PassphraseSheet._();

  /// Choose a passphrase for a new backup. Null when the person backs out.
  static Future<String?> askNew(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AppBottomSheet.show<String>(
      context,
      title: 'Protect this backup',
      icon: Symbols.lock_rounded,
      accent: ext.brand,
      builder: (ctx) => NewPassphraseBody(
        onChosen: (p) => Navigator.pop(ctx, p),
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  /// Give the passphrase of an encrypted backup. [wrong] says the last attempt did
  /// not open it. Null when the person gives up.
  static Future<String?> askExisting(BuildContext context, {bool wrong = false}) {
    final ext = AppColorsExt.of(context);
    return AppBottomSheet.show<String>(
      context,
      title: 'This backup is protected',
      icon: Symbols.lock_open_rounded,
      accent: ext.brand,
      builder: (ctx) => ExistingPassphraseBody(
        wrong: wrong,
        onGiven: (p) => Navigator.pop(ctx, p),
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }
}

/// Choosing a passphrase: typed twice, at least [BackupEncryption.minPassphraseLength]
/// characters, with the one thing worth reading said plainly above the fields —
/// that there is no way back from losing it.
class NewPassphraseBody extends StatefulWidget {
  const NewPassphraseBody({super.key, required this.onChosen, required this.onCancel});

  final ValueChanged<String> onChosen;
  final VoidCallback onCancel;

  @override
  State<NewPassphraseBody> createState() => _NewPassphraseBodyState();
}

class _NewPassphraseBodyState extends State<NewPassphraseBody> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  bool _shown = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _submit() {
    final problem = BackupEncryption.validatePassphrase(_first.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (_first.text != _second.text) {
      setState(() => _error = 'The two passphrases are not the same.');
      return;
    }
    widget.onChosen(_first.text);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final eye = IconButton(
      tooltip: _shown ? 'Hide passphrase' : 'Show passphrase',
      icon: Icon(_shown ? Symbols.visibility_off_rounded : Symbols.visibility_rounded,
          size: 20, color: ext.textTertiary),
      onPressed: () => setState(() => _shown = !_shown),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: ext.warning.container,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Symbols.warning_amber_rounded, size: 18, color: ext.warning.onContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'There is no way to recover this passphrase. If you lose it, '
                  'this backup cannot be opened — not by you, and not by us. '
                  'Keep it somewhere safe.',
                  style: tt.bodySmall
                      ?.copyWith(color: ext.warning.onContainer, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // A passphrase is not a word. Hidden, the keyboard leaves it alone; shown, it
        // is ordinary text, and a keyboard would correct it in one box and not the
        // other — or learn it. A backup passphrase cannot be recovered, so what was
        // typed must be exactly what is kept.
        AppTextField(
          controller: _first,
          label: 'Passphrase',
          hint: 'At least ${BackupEncryption.minPassphraseLength} characters',
          obscureText: !_shown,
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          enableSuggestions: false,
          suffix: eye,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          controller: _second,
          label: 'Type it again',
          obscureText: !_shown,
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: tt.bodySmall?.copyWith(color: ext.mark(ext.error))),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Create encrypted backup',
          leadingIcon: Symbols.lock_rounded,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          onPressed: widget.onCancel,
        ),
      ],
    );
  }
}

/// Giving the passphrase of an encrypted backup, again if it was wrong.
class ExistingPassphraseBody extends StatefulWidget {
  const ExistingPassphraseBody(
      {super.key, required this.wrong, required this.onGiven, required this.onCancel});

  final bool wrong;
  final ValueChanged<String> onGiven;
  final VoidCallback onCancel;

  @override
  State<ExistingPassphraseBody> createState() => _ExistingPassphraseBodyState();
}

class _ExistingPassphraseBodyState extends State<ExistingPassphraseBody> {
  final _field = TextEditingController();
  bool _shown = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    // Exactly what was typed — a passphrase may begin or end with a space — but
    // not nothing.
    if (_field.text.isEmpty) return;
    widget.onGiven(_field.text);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter the passphrase it was made with.',
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _field,
          label: 'Passphrase',
          obscureText: !_shown,
          // Not a word: see the fields that made the backup.
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          enableSuggestions: false,
          autofocus: true,
          errorText: widget.wrong
              ? 'That passphrase did not open the backup. Try again.'
              : null,
          suffix: IconButton(
            tooltip: _shown ? 'Hide passphrase' : 'Show passphrase',
            icon: Icon(
                _shown ? Symbols.visibility_off_rounded : Symbols.visibility_rounded,
                size: 20,
                color: ext.textTertiary),
            onPressed: () => setState(() => _shown = !_shown),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Open backup',
          leadingIcon: Symbols.lock_open_rounded,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          onPressed: widget.onCancel,
        ),
      ],
    );
  }
}
