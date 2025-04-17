import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themePreferenceKey = 'theme_preference';
  static const String _blackThemePreferenceKey = 'black_theme_preference';
  
  ThemeMode _themeMode = ThemeMode.system;
  bool _useBlackTheme = false;
  
  ThemeMode get themeMode => _themeMode;
  bool get useBlackTheme => _useBlackTheme;
  
  // 亮色主題
  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.grey[50],
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    ),
    cardTheme: CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 2,
      highlightElevation: 4,
    ),
    dividerTheme: const DividerThemeData(
      thickness: 1,
      space: 1,
    ),
  );
  
  // 暗色主題
  ThemeData get darkTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: _useBlackTheme ? Colors.black : const Color(0xFF121212),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: _useBlackTheme ? Colors.black : Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: _useBlackTheme ? const Color(0xFF121212) : Colors.grey[850],
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
      ),
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: _useBlackTheme ? Colors.grey[900] : Colors.grey[800],
      ),
    );
    
    // 如果使用黑色主題，替換更多元素的顏色
    if (_useBlackTheme) {
      return baseTheme.copyWith(
        dialogBackgroundColor: const Color(0xFF121212),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.black,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF121212),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.black,
        ),
      );
    }
    
    return baseTheme;
  }

  ThemeService() {
    _loadThemePreferences();
  }

  // 載入保存的主題偏好
  Future<void> _loadThemePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themePref = prefs.getString(_themePreferenceKey);
    final blackThemePref = prefs.getBool(_blackThemePreferenceKey);
    
    if (themePref == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themePref == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    
    _useBlackTheme = blackThemePref ?? false;
    
    notifyListeners();
  }

  // 保存主題偏好
  Future<void> _saveThemePreference(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String themePref;
    
    if (mode == ThemeMode.light) {
      themePref = 'light';
    } else if (mode == ThemeMode.dark) {
      themePref = 'dark';
    } else {
      themePref = 'system';
    }
    
    await prefs.setString(_themePreferenceKey, themePref);
  }
  
  // 保存黑色背景偏好
  Future<void> _saveBlackThemePreference(bool useBlack) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_blackThemePreferenceKey, useBlack);
  }

  // 切換至亮色主題
  Future<void> setLightMode() async {
    _themeMode = ThemeMode.light;
    await _saveThemePreference(_themeMode);
    notifyListeners();
  }

  // 切換至暗色主題
  Future<void> setDarkMode() async {
    _themeMode = ThemeMode.dark;
    await _saveThemePreference(_themeMode);
    notifyListeners();
  }

  // 切換至系統主題
  Future<void> setSystemMode() async {
    _themeMode = ThemeMode.system;
    await _saveThemePreference(_themeMode);
    notifyListeners();
  }
  
  // 設置是否使用黑色背景
  Future<void> setUseBlackBackground(bool useBlack) async {
    _useBlackTheme = useBlack;
    await _saveBlackThemePreference(useBlack);
    notifyListeners();
  }

  // 根據當前主題切換到另一種主題
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setDarkMode();
    } else {
      await setLightMode();
    }
  }
}