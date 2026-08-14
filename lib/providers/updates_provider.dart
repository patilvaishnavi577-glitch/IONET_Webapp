import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/update_model.dart';
import '../services/api_service.dart';

class UpdatesProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SharedPreferences? _prefs;
  final List<SystemUpdate> _updates = [];
  bool _isLoading = false;

  List<SystemUpdate> get updates => _updates;
  bool get isLoading => _isLoading;

  SystemUpdate? _selectedUpdate;
  final Set<String> _seenUpdateIds = {};

  UpdatesProvider({SharedPreferences? prefs}) : _prefs = prefs {
    _loadSeenUpdates();
  }

  void _loadSeenUpdates() {
    if (_prefs != null) {
      final list = _prefs.getStringList('seen_update_ids') ?? [];
      _seenUpdateIds.addAll(list);
    }
  }

  void _saveSeenUpdates() {
    _prefs?.setStringList('seen_update_ids', _seenUpdateIds.toList());
  }

  SystemUpdate? get selectedUpdate => _selectedUpdate;

  void selectUpdate(SystemUpdate? update) {
    _selectedUpdate = update;
    if (update != null) {
      _seenUpdateIds.add(update.id);
      _saveSeenUpdates();
    }
    notifyListeners();
  }

  bool isUpdateSeen(String id) => _seenUpdateIds.contains(id);

  void markUpdateSeen(String id) {
    _seenUpdateIds.add(id);
    _saveSeenUpdates();
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  /// Retrieve general announcement updates from backend API
  Future<bool> fetchUpdates() async {
    _setLoading(true);
    final rawUpdates = await _apiService.getUpdates();
    _setLoading(false);

    if (rawUpdates != null) {
      _updates.clear();
      for (final raw in rawUpdates) {
        _updates.add(SystemUpdate.fromJson(raw));
      }
      // Sort updates newest first
      _updates.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
      return true;
    }
    return false;
  }
}
