import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

// 使用條件編譯而不是動態導入
// 只在非 Web 平台上導入 window_size 插件
import 'window_size_stub.dart'
    if (dart.library.io) 'window_size_real.dart';

// 為了避免編譯錯誤，使用條件檢查
void initializeWindowSettings() {
  if (kIsWeb) return; // Web 平台直接返回
  
  try {
    // 只在實際的桌面平台上使用
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 調用實際的設置函數
      initializeWindow();
    }
  } catch (e) {
    print('Window settings initialization error: $e');
  }
}