import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/medication/models/dependent_profile.dart';
import '../../features/medication/services/medicine_storage_service.dart';

/// Tracks which household member's medicines/logs/vitals are currently in
/// view: the app's own owner ("self", represented as `null`) or a specific
/// [DependentProfile]'s id. Before this service existed, nothing tracked
/// "which profile is active" at all — every screen showed every profile's
/// data mixed together, because `dependentId` columns existed on the
/// medicine/log/vitals tables but nothing ever filtered by them.
///
/// `null` means self BY DESIGN, not merely as an unset default: every
/// medicine/log/BP/glucose row created before profiles existed already has
/// `dependentId == null` (nothing ever wrote a non-null value), so treating
/// null as "self" needs no data migration — introducing this feature orphans
/// nothing. [selfProfileId] gets a real [DependentProfile] row so the
/// profile switcher UI has a name/avatar to show for "Me", but that id is
/// never written into or compared against a `dependentId` column — the
/// comparison is always against null. See [MedicineCleanStorageService]'s
/// `_inActiveProfile` for the read-side half of this contract.
///
/// Mirrors [FeatureManager]'s singleton + `ChangeNotifier` + SharedPreferences
/// pattern: a bare factory constructor returning one shared instance, an
/// idempotent `init()` awaited alongside the other critical services at
/// startup, and mutators that persist then `notifyListeners()`.
class ActiveProfileService extends ChangeNotifier {
  static final ActiveProfileService _instance = ActiveProfileService._internal();
  factory ActiveProfileService() => _instance;
  ActiveProfileService._internal();

  /// Well-known id for the auto-created "self" [DependentProfile] row.
  static const String selfProfileId = 'self';

  static const String _prefsKey = 'active_dependent_id';

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  String? _activeDependentId; // null = self

  /// The currently active dependent's id, or null when "self" is active.
  String? get activeDependentId => _activeDependentId;
  bool get isSelfActive => _activeDependentId == null;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _activeDependentId = _prefs!.getString(_prefsKey);
      await _ensureSelfProfileExists();
      _isInitialized = true;
      debugPrint(
          '✓ ActiveProfileService initialized (active=${_activeDependentId ?? "self"})');
    } catch (e) {
      debugPrint('⚠️ ActiveProfileService init failed: $e');
    }
  }

  /// One-time (per install): makes sure a "self" [DependentProfile] row
  /// exists so the profile switcher has something to show for "Me". This
  /// NEVER touches medicine/log/vitals rows — those already read as self via
  /// a null `dependentId`, with nothing to back-fill.
  Future<void> _ensureSelfProfileExists() async {
    try {
      final existing = await MedicineCleanStorageService.getAllDependents();
      if (existing.any((d) => d.id == selfProfileId || d.isSelf)) return;
      await MedicineCleanStorageService.addDependent(
          DependentProfile.self(name: 'Me'));
    } catch (e) {
      debugPrint('⚠️ Self-profile backfill failed: $e');
    }
  }

  /// Switches the active profile. Pass null to switch back to "self".
  Future<void> setActiveDependent(String? dependentId) async {
    if (dependentId == selfProfileId) dependentId = null;
    _activeDependentId = dependentId;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    if (dependentId == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, dependentId);
    }
    notifyListeners();
  }

  /// Resets in-memory state so a test's `init()` call re-runs the self-backfill
  /// against that test's own fresh DB/prefs, instead of silently no-op'ing
  /// because a PRIOR test in the same run already flipped [_isInitialized].
  /// The singleton itself (this instance) is shared across tests in one file;
  /// only its state is cleared.
  @visibleForTesting
  void resetForTesting() {
    _prefs = null;
    _isInitialized = false;
    _activeDependentId = null;
  }
}
