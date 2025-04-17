import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class CustomMarkdownSyntax extends StatefulWidget {
  final String data;
  final bool selectable;
  final MarkdownStyleSheet? styleSheet;
  final MarkdownTapLinkCallback? onTapLink;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final bool softLineBreak;
  final Function(String)? onDataChanged;

  const CustomMarkdownSyntax({
    Key? key,
    required this.data,
    this.selectable = false,
    this.styleSheet,
    this.onTapLink,
    this.padding = const EdgeInsets.all(16.0),
    this.controller,
    this.softLineBreak = false,
    this.onDataChanged,
  }) : super(key: key);

  @override
  State<CustomMarkdownSyntax> createState() => _CustomMarkdownSyntaxState();
}

class _CustomMarkdownSyntaxState extends State<CustomMarkdownSyntax> {
  static final _checkboxRegex = RegExp(r'^\s*[-*]\s+\[([ xX])\]\s+(.*)$', multiLine: true);
  String _currentData = '';
  
  @override
  void initState() {
    super.initState();
    _currentData = widget.data;
  }
  
  @override
  void didUpdateWidget(CustomMarkdownSyntax oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _currentData = widget.data;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final styleSheet = widget.styleSheet ?? MarkdownStyleSheet.fromTheme(theme);
    
    return SingleChildScrollView(
      controller: widget.controller,
      child: Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _buildMarkdownBlocks(
            _currentData.split('\n'),
            styleSheet,
          ),
        ),
      ),
    );
  }

  // 處理 Checkbox 勾選事件
  void _handleCheckboxToggle(String textContent, bool newValue) {
    // 不在 build 方法中直接修改狀態，而是先修改數據然後在 microtask 中通知
    final lines = _currentData.split('\n');
    bool updated = false;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = _checkboxRegex.firstMatch(line);
      if (match != null) {
        final matchedText = match.group(2) ?? '';
        if (matchedText == textContent) {
          // 找到對應的行，更新 checkbox 狀態
          final String newMark = newValue ? '[x]' : '[ ]';
          final newLine = line.replaceFirst(
            RegExp(r'\[([ xX])\]'),
            newMark
          );
          lines[i] = newLine;
          updated = true;
          break;
        }
      }
    }
    
    if (updated) {
      final newData = lines.join('\n');
      // 安全地排程更新
      Future.microtask(() {
        if (mounted && widget.onDataChanged != null) {
          widget.onDataChanged!(newData);
        }
      });
    }
  }

  List<Widget> _buildMarkdownBlocks(List<String> lines, MarkdownStyleSheet styleSheet) {
    final List<Widget> widgets = [];
    List<String> currentBlock = [];
    
    // 標記行是否處理過
    List<bool> processedLines = List.filled(lines.length, false);

    // 第一遍：尋找並處理複選框
    for (int i = 0; i < lines.length; i++) {
      if (processedLines[i]) continue;
      
      final String line = lines[i];
      final match = _checkboxRegex.firstMatch(line);
      
      if (match != null) {
        // 找到複選框
        processedLines[i] = true;
        
        // 如果當前有未處理的文本塊，先處理它
        if (currentBlock.isNotEmpty) {
          widgets.add(
            MarkdownBody(
              data: currentBlock.join('\n'),
              styleSheet: styleSheet,
              onTapLink: widget.onTapLink,
              selectable: widget.selectable,
              softLineBreak: widget.softLineBreak,
            ),
          );
          currentBlock = [];
        }

        // 處理複選框
        final bool isChecked = match.group(1) == 'x' || match.group(1) == 'X';
        final String text = match.group(2) ?? '';
        
        // 直接使用內部構建的 StatelessWidget 來避免狀態管理問題
        widgets.add(
          _CheckboxListItem(
            text: text,
            isChecked: isChecked,
            onToggle: (newValue) {
              _handleCheckboxToggle(text, newValue);
            },
            styleSheet: styleSheet,
            themeData: Theme.of(context),
          ),
        );
      } else {
        // 保存普通文本行
        currentBlock.add(line);
      }
    }

    // 處理剩餘的文本塊
    if (currentBlock.isNotEmpty) {
      widgets.add(
        MarkdownBody(
          data: currentBlock.join('\n'),
          styleSheet: styleSheet,
          onTapLink: widget.onTapLink,
          selectable: widget.selectable,
          softLineBreak: widget.softLineBreak,
        ),
      );
    }

    return widgets;
  }
}

// 使用一個獨立的 StatelessWidget 處理 checkbox
class _CheckboxListItem extends StatelessWidget {
  final String text;
  final bool isChecked;
  final Function(bool) onToggle;
  final MarkdownStyleSheet styleSheet;
  final ThemeData themeData;

  const _CheckboxListItem({
    Key? key,
    required this.text,
    required this.isChecked,
    required this.onToggle,
    required this.styleSheet,
    required this.themeData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isChecked,
              activeColor: themeData.colorScheme.primary,
              checkColor: themeData.colorScheme.onPrimary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (bool? newValue) {
                if (newValue != null) {
                  onToggle(newValue);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                onToggle(!isChecked);
              },
              child: Text(
                text,
                style: styleSheet.p?.copyWith(
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  color: isChecked ? Colors.grey : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
