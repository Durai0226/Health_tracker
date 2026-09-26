/// User-visible strings that must read the same everywhere.
///
/// ## The product name
///
/// The app installs as **Dlyminder** — `CFBundleDisplayName`, `CFBundleName`
/// and `android:label` all say so, and that is the name on the user's home
/// screen. Inside `lib` the copy said something else 47 times: 31 "DailyMinder"
/// (a name the stores never saw) and 16 "DlyMinder". Three spellings of one
/// product, two of them wrong, in sentences the user reads.
///
/// [productName] is the manifest spelling, because the manifests are what the
/// launcher shows. Compose copy from it rather than typing the name, so the
/// next rename is one edit instead of forty-seven:
///
/// ```dart
/// Text('Require a PIN to open ${AppStrings.productName}.')
/// ```
abstract final class AppStrings {
  /// The shipped display name. Matches `CFBundleDisplayName` (iOS) and
  /// `android:label` (Android) exactly.
  static const String productName = 'Dlyminder';
}
