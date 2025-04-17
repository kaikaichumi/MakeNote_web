import 'package:flutter/material.dart';

// 應用程序常數
class AppConstants {
  // 應用程序名稱
  static const String appName = 'MarkNote';
  
  // 版本信息
  static const String appVersion = '0.1.3';
  
  // 數據庫名稱
  static const String databaseName = 'marknote.db';
  
  // 偏好設置鍵
  static const String themePreferenceKey = 'theme_preference';
  static const String fontSizePreferenceKey = 'font_size_preference';
  
  // 默認設置
  static const double defaultFontSize = 16.0;
  
  // Markdown語法參考
  static const Map<String, String> markdownSyntaxReference = {
    '標題': '# 標題1\n## 標題2\n### 標題3',
    '粗體': '**粗體文字**',
    '斜體': '*斜體文字*',
    '列表': '- 項目1\n- 項目2\n- 項目3',
    '有序列表': '1. 第一項\n2. 第二項\n3. 第三項',
    '引用': '> 引用的文字',
    '代碼': '`行內代碼`',
    '代碼塊': '```\n代碼塊\n```',
    '鏈接': '[鏈接文字](https://example.com)',
    '圖片': '![圖片說明](image_url.jpg)',
    '表格': '| 標題1 | 標題2 |\n| --- | --- |\n| 單元格1 | 單元格2 |',
    '水平線': '---',
    '任務列表': '- [x] 已完成任務\n- [ ] 未完成任務',
  };
  
  // 預設類別顏色
  static const List<Color> categoryColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];
}