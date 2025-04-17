import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:note/widgets/custom_markdown_parser.dart';

class MarkdownPreview extends StatelessWidget {
  final String markdownText;
  final double? padding;
  final ScrollController? scrollController;
  final Function(String)? onTextChanged;

  const MarkdownPreview({
    Key? key,
    required this.markdownText,
    this.padding,
    this.scrollController,
    this.onTextChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    
    // 重構元素以支持僅掃准基本語法和我們的自定義模式
    final MarkdownStyleSheet styleSheet = MarkdownStyleSheet(
      // 標題樣式
      h1: theme.textTheme.headlineLarge,
      h2: theme.textTheme.headlineMedium,
      h3: theme.textTheme.headlineSmall,
      h4: theme.textTheme.titleLarge,
      h5: theme.textTheme.titleMedium,
      h6: theme.textTheme.titleSmall,
      
      // 一般文本樣式
      p: theme.textTheme.bodyLarge,
      
      // 列表樣式
      listBullet: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.primary,
      ),
      
      // 代碼區塊樣式
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'Roboto Mono',
        backgroundColor: isDarkMode 
          ? Colors.grey[800] 
          : Colors.grey[200],
        color: isDarkMode 
          ? Colors.grey[300] 
          : Colors.grey[900],
      ),
      codeblockDecoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      
      // 引用區塊樣式
      blockquote: theme.textTheme.bodyLarge?.copyWith(
        fontStyle: FontStyle.italic,
        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 4.0,
          ),
        ),
      ),
      
      // 水平線樣式
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1.0,
          ),
        ),
      ),
      
      // 表格樣式
      tableHead: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      tableBorder: TableBorder.all(
        color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
        width: 1.0,
      ),
    );

    // 使用自定義的Markdown體驗以支持複選框
    return CustomMarkdownSyntax(
      data: markdownText,
      selectable: true,
      padding: EdgeInsets.all(padding ?? 16.0),
      styleSheet: styleSheet,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href));
        }
      },
      onDataChanged: onTextChanged,
    );
  }
}