class MarkdownFormatter {
  // 格式化標題
  static String formatHeading(String text, int level) {
    final hashmarks = '#' * level;
    return '$hashmarks $text';
  }

  // 格式化粗體
  static String formatBold(String text) {
    return '**$text**';
  }

  // 格式化斜體
  static String formatItalic(String text) {
    return '*$text*';
  }

  // 格式化無序列表
  static String formatUnorderedList(List<String> items) {
    return items.map((item) => '- $item').join('\n');
  }

  // 格式化有序列表
  static String formatOrderedList(List<String> items) {
    final buffer = StringBuffer();
    for (var i = 0; i < items.length; i++) {
      buffer.writeln('${i + 1}. ${items[i]}');
    }
    return buffer.toString().trim();
  }

  // 格式化引用
  static String formatBlockquote(String text) {
    return text.split('\n').map((line) => '> $line').join('\n');
  }

  // 格式化代碼
  static String formatInlineCode(String code) {
    return '`$code`';
  }

  // 格式化代碼塊
  static String formatCodeBlock(String code, [String? language]) {
    return '```${language ?? ''}\n$code\n```';
  }

  // 格式化鏈接
  static String formatLink(String text, String url) {
    return '[$text]($url)';
  }

  // 格式化圖片
  static String formatImage(String altText, String url) {
    return '![$altText]($url)';
  }

  // 格式化表格
  static String formatTable(List<String> headers, List<List<String>> rows) {
    final buffer = StringBuffer();
    
    // 表頭
    buffer.write('| ');
    buffer.write(headers.join(' | '));
    buffer.writeln(' |');
    
    // 分隔線
    buffer.write('| ');
    buffer.write(headers.map((_) => '---').join(' | '));
    buffer.writeln(' |');
    
    // 表格內容
    for (final row in rows) {
      buffer.write('| ');
      buffer.write(row.join(' | '));
      buffer.writeln(' |');
    }
    
    return buffer.toString();
  }

  // 格式化水平線
  static String formatHorizontalRule() {
    return '---';
  }

  // 格式化任務列表
  static String formatTaskList(List<MapEntry<String, bool>> tasks) {
    return tasks.map((task) {
      final checkbox = task.value ? '[x]' : '[ ]';
      return '- $checkbox ${task.key}';
    }).join('\n');
  }

  // 提取純文本（去除Markdown格式）
  static String extractPlainText(String markdown) {
    String text = markdown;
    
    // 移除標題標記
    text = text.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');
    
    // 移除粗體和斜體標記
    text = text.replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'\1');
    text = text.replaceAll(RegExp(r'\*(.*?)\*'), r'\1');
    
    // 移除代碼標記
    text = text.replaceAll(RegExp(r'`(.*?)`'), r'\1');
    
    // 移除代碼塊
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    
    // 移除鏈接，保留文本
    text = text.replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'\1');
    
    // 移除圖片，用[圖片]替代
    text = text.replaceAll(RegExp(r'!\[(.*?)\]\(.*?\)'), '[圖片]');
    
    // 移除列表標記
    text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
    
    // 移除引用標記
    text = text.replaceAll(RegExp(r'^\s*>\s+', multiLine: true), '');
    
    // 移除水平線
    text = text.replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '');
    
    // 移除任務列表標記
    text = text.replaceAll(RegExp(r'^\s*-\s+\[([ x])\]\s+', multiLine: true), '');
    
    return text.trim();
  }
}