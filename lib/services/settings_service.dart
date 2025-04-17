import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 編輯器模式枚舉
enum EditorMode {
  splitView,  // 雙欄模式
  editOnly,   // 純編輯模式
  previewOnly // 純預覽模式
}

// 設定服務類，用於保存和讀取用戶偏好設定
class SettingsService extends ChangeNotifier {
  // 單例模式
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;
  
  // 預設值
  bool _autosaveEnabled = true;
  int _autosaveInterval = 5; // 秒
  EditorMode _defaultEditorMode = EditorMode.splitView;
  
  // 獲取和設定方法
  bool get autosaveEnabled => _autosaveEnabled;
  int get autosaveInterval => _autosaveInterval;
  EditorMode get defaultEditorMode => _defaultEditorMode;

  // 初始化
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  // 從 SharedPreferences 載入設定
  void _loadSettings() {
    _autosaveEnabled = _prefs.getBool('autosave_enabled') ?? true;
    _autosaveInterval = _prefs.getInt('autosave_interval') ?? 5;
    _defaultEditorMode = EditorMode.values[
      _prefs.getInt('default_editor_mode') ?? EditorMode.splitView.index
    ];
    notifyListeners();
  }

  // 設定自動儲存開關
  Future<void> setAutosaveEnabled(bool value) async {
    _autosaveEnabled = value;
    await _prefs.setBool('autosave_enabled', value);
    notifyListeners();
  }

  // 設定自動儲存間隔
  Future<void> setAutosaveInterval(int seconds) async {
    if (seconds < 1) seconds = 1; // 最小1秒
    _autosaveInterval = seconds;
    await _prefs.setInt('autosave_interval', seconds);
    notifyListeners();
  }

  // 設定預設編輯器模式
  Future<void> setDefaultEditorMode(EditorMode mode) async {
    _defaultEditorMode = mode;
    await _prefs.setInt('default_editor_mode', mode.index);
    notifyListeners();
  }
}
