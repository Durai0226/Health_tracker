import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/care_circle.dart';
import '../../../core/services/contact_launcher.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// "Let Priya know…" on a missed dose: opens the messages app with a note typed
/// in, and the person presses send. Nothing at all while the offer is off or
/// there is nobody to tell. See [CareCircle].
class TellContactButton extends StatelessWidget {
  const TellContactButton({super.key});

  @override
  Widget build(BuildContext context) {
    final contact = CareCircle.contactToOffer();
    if (contact == null) return const SizedBox.shrink();
    final name = contact.name.trim();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppButton(
        label: name.isEmpty ? 'Let your contact know…' : 'Let $name know…',
        leadingIcon: Symbols.sms_rounded,
        variant: AppButtonVariant.ghost,
        fullWidth: true,
        accent: AppColorsExt.of(context).medicine,
        onPressed: () async {
          final opened = await ContactLauncher.text(contact.phone,
              body: CareCircle.missedDoseMessage(name));
          if (opened || !context.mounted) return;
          context.toastError('Could not open messages. The number is ${contact.phone}.');
        },
      ),
    );
  }
}
