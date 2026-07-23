import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/ai/ai_assistant.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// Manage the optional on-device AI model — a free, offline, private generative
/// tier that phrases answers from the same retrieved knowledge (never sends
/// anything off-device). Experimental + opt-in: a model must be downloaded once.
class OnDeviceAiScreen extends StatefulWidget {
  const OnDeviceAiScreen({super.key});

  @override
  State<OnDeviceAiScreen> createState() => _OnDeviceAiScreenState();
}

class _OnDeviceAiScreenState extends State<OnDeviceAiScreen> {
  final _ai = AiAssistant();
  final _urlController = TextEditingController();

  bool _installed = false;
  bool _enabled = false;
  bool _downloading = false;
  bool _busy = true;
  int _progress = 0;
  StreamSubscription<int>? _sub;

  @override
  void initState() {
    super.initState();
    _urlController.text = _ai.onDeviceModelUrl;
    _refresh();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final installed = await _ai.onDeviceModelInstalled();
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _enabled = _ai.onDeviceEnabled;
      _busy = false;
    });
  }

  void _download() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _toast('Paste a model download URL first.');
      return;
    }
    _ai.setOnDeviceModelUrl(url);
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    _sub = _ai.downloadOnDeviceModel(url).listen(
      (p) => setState(() => _progress = p),
      onDone: () async {
        await _refresh();
        if (mounted) setState(() => _downloading = false);
        _toast('Model downloaded.');
      },
      onError: (e) {
        if (mounted) setState(() => _downloading = false);
        _toast('Download failed. Check the URL and your connection.');
      },
    );
  }

  Future<void> _enable(bool v) async {
    setState(() => _busy = true);
    await _ai.setOnDeviceEnabled(v);
    if (v) {
      final ok = await _ai.activateOnDevice();
      if (!ok) _toast('Couldn\'t start the model on this device.');
    }
    await _refresh();
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    await _ai.removeOnDeviceModel();
    await _ai.setOnDeviceEnabled(false);
    await _refresh();
    _toast('Model removed.');
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'On-device AI',
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
            bottom: Container(height: 1, color: ext.outline),
          ),
          Expanded(
            child: _busy
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.lg, AppSpacing.gutter, AppSpacing.huge),
                    children: [
                      _intro(ext, tt),
                      const SizedBox(height: AppSpacing.lg),
                      if (!_ai.onDeviceSupported)
                        _note(ext, tt,
                            'On-device AI runs on phones only. This device or platform isn\'t supported.')
                      else ...[
                        _statusCard(ext, tt, accent),
                        const SizedBox(height: AppSpacing.md),
                        if (!_installed) _downloadCard(ext, tt, accent),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _intro(AppColorsExt ext, TextTheme tt) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Symbols.memory_rounded, size: 20, color: ext.mark(ext.brand)),
              const SizedBox(width: AppSpacing.sm),
              Text('Smarter answers, still private',
                  style: tt.titleMedium?.copyWith(
                      color: ext.textPrimary, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text(
                'Adds a small AI model that phrases answers from the same on-device knowledge — fully offline, no account, no data leaves your phone. Experimental; the one-time download is large (hundreds of MB) and best done on Wi-Fi.',
                style: tt.bodyMedium
                    ?.copyWith(color: ext.textSecondary, height: 1.4)),
          ],
        ),
      );

  Widget _statusCard(
      AppColorsExt ext, TextTheme tt, AccentSwatch accent) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(_installed ? Symbols.check_circle_rounded : Symbols.info_rounded,
                size: 18,
                color: _installed ? ext.mark(ext.success) : ext.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Text(_installed ? 'Model installed' : 'No model yet',
                style: tt.titleSmall?.copyWith(
                    color: ext.textPrimary, fontWeight: FontWeight.w600)),
          ]),
          if (_installed) ...[
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Use on-device AI',
                        style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
                    Text('Prefer it for grounded answers',
                        style:
                            tt.bodySmall?.copyWith(color: ext.textSecondary)),
                  ],
                ),
              ),
              AppSwitch(value: _enabled, onChanged: _enable),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Remove model',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                leadingIcon: Symbols.delete_rounded,
                accent: ext.error,
                onPressed: _remove,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _downloadCard(AppColorsExt ext, TextTheme tt, AccentSwatch accent) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Download a model',
              style: tt.titleSmall?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Text(
              'Paste a direct link to a compatible int4 model (.task). Use a small model such as a Gemma int4 build for phones.',
              style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _urlController,
            enabled: !_downloading,
            decoration: InputDecoration(
              hintText: 'https://…/model.task',
              filled: true,
              fillColor: ext.surfaceVariant,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: const OutlineInputBorder(
                  borderRadius: AppRadius.brMd, borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_downloading) ...[
            ClipRRect(
              borderRadius: AppRadius.brFull,
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress / 100 : null,
                minHeight: 8,
                backgroundColor: ext.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(ext.mark(accent)),
              ),
            ),
            const SizedBox(height: 6),
            Text('Downloading… $_progress%',
                style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
          ] else
            AppButton(
              label: 'Download',
              leadingIcon: Symbols.download_rounded,
              accent: accent,
              onPressed: _download,
            ),
        ],
      ),
    );
  }

  Widget _note(AppColorsExt ext, TextTheme tt, String text) => AppCard(
        child: Text(text,
            style:
                tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4)),
      );
}
