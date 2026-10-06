import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive user experience preferences backed by SharedPreferences.
///
/// Use this for UX state only (e.g., last school name for display hints).
/// NEVER store tokens, passwords, or any credential here.
class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  // ── Last Known School Name ────────────────────────────────────────────────

  static const String _lastSchoolNameKey = 'last_school_name';

  /// Caches the display name of the last school for UX hint display.
  Future<void> saveLastSchoolName(String name) =>
      _prefs.setString(_lastSchoolNameKey, name);

  /// Returns the last cached school display name, or `null`.
  String? getLastSchoolName() => _prefs.getString(_lastSchoolNameKey);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> clearAll() => _prefs.clear();
}

