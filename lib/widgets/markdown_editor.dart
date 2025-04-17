import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart' as markdown;
import 'package:note/utils/markdown_formatter.dart';
import 'dart:math';

class MarkdownEditor extends StatefulWidget {
  final String initialValue;
  final Function(String) onChanged;
  final FocusNode? focusNode;

  const MarkdownEditor({
    Key? key,
    required this.initialValue,
    required this.onChanged,
    this.focusNode,
  }) : super(key: key);

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String _previousContent = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = widget.focusNode ?? FocusNode();
    _previousContent = widget.initialValue;
    
    // 設置焦點節點的鍵盤處理
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
        // 處理 Tab 鍵
        _handleTabKey();
        return KeyEventResult.handled; // 指示我們已經處理了這個按鍵
      }
      return KeyEventResult.ignored; // 其他按鍵交給默認處理
    };
    
    // 監聽文本變化
    _controller.addListener(() {
      widget.onChanged(_controller.text);
    });
  }
  
  // 監控父元件屬性變化
  @override
  void didUpdateWidget(MarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 檢查文本內容是否已從外部改變
    if (widget.initialValue != _previousContent && widget.initialValue != _controller.text) {
      // 將編輯器的文本更新為新的內容
      final currentCursorPosition = _controller.selection.baseOffset;
      
      if (currentCursorPosition >= 0) {
        // 如果有有效的位置，嘗試保持游標位置
        _controller.value = TextEditingValue(
          text: widget.initialValue,
          selection: TextSelection.collapsed(offset: min(currentCursorPosition, widget.initialValue.length)),
        );
      } else {
        // 否則直接更新文本
        _controller.text = widget.initialValue;
      }
      
      // 更新記錄
      _previousContent = widget.initialValue;
    }
  }
  
  // 處理 Tab 鍵的功能 - 將整行往後縮進 4 個空格
  void _handleTabKey() {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.baseOffset;
    
    if (cursorPos >= 0) {
      // 找到當前行的起始和結束位置
      final beforeCursor = text.substring(0, cursorPos);
      final afterCursor = text.substring(cursorPos);
      final lastNewLine = beforeCursor.lastIndexOf('\n');
      final nextNewLine = afterCursor.indexOf('\n');
      
      final lineStart = lastNewLine == -1 ? 0 : lastNewLine + 1;
      final lineEnd = nextNewLine == -1 ? text.length : cursorPos + nextNewLine;
      
      // 取得當前行的內容
      final currentLine = text.substring(lineStart, lineEnd);
      // 在行首插入 4 個空格
      const indentation = '    ';
      final newLine = indentation + currentLine;
      
      // 在原始位置替換整行
      final newText = text.substring(0, lineStart) + newLine + text.substring(lineEnd);
      
      // 更新文本並移動游標
      // 將游標位置向右移 4 個空格
      final newCursorPosition = cursorPos + indentation.length;
      
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  // 插入標題
  void _insertHeading(int level) {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.baseOffset;
    
    if (cursorPos < 0) return;
    
    final beforeCursor = text.substring(0, cursorPos);
    final afterCursor = text.substring(cursorPos);
    
    // 確定光標是否在行首
    final lastNewLine = beforeCursor.lastIndexOf('\n');
    final isStartOfLine = lastNewLine == beforeCursor.length - 1 || beforeCursor.isEmpty;
    
    // 定位到行首
    final lineStart = isStartOfLine ? cursorPos : lastNewLine + 1;
    final prefix = '#' * level + ' ';
    
    // 生成新文本
    String newText;
    if (isStartOfLine) {
      newText = beforeCursor + prefix + afterCursor;
    } else {
      final beforeLine = text.substring(0, lineStart);
      final currentLine = text.substring(lineStart, cursorPos);
      newText = beforeLine + prefix + currentLine + afterCursor;
    }
    
    // 更新文本
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (isStartOfLine ? cursorPos : lineStart) + prefix.length,
      ),
    );
    
    // 確保編輯器保持焦點
    _focusNode.requestFocus();
  }

  // 插入粗體
  void _insertBold() {
    final text = _controller.text;
    final selection = _controller.selection;
    
    if (selection.baseOffset < 0 || selection.extentOffset < 0) {
      // 無效的選擇範圍
      return;
    }
    
    if (selection.baseOffset == selection.extentOffset) {
      // 無選擇文本，插入空的粗體標記
      final newText = text.replaceRange(selection.baseOffset, selection.baseOffset, '****');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.baseOffset + 2),
      );
    } else {
      // 選擇了文本，將其加粗
      int startOffset = min(selection.baseOffset, selection.extentOffset);
      int endOffset = max(selection.baseOffset, selection.extentOffset);
      
      // 安全檢查，確保範圍有效
      if (startOffset < 0) startOffset = 0;
      if (endOffset > text.length) endOffset = text.length;
      
      // 取得選擇的文本
      final selectedText = text.substring(startOffset, endOffset);
      final newText = text.replaceRange(startOffset, endOffset, '**$selectedText**');
      
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: endOffset + 4),
      );
    }
    
    // 確保編輯器保持焦點
    _focusNode.requestFocus();
  }

  // 插入斜體
  void _insertItalic() {
    final text = _controller.text;
    final selection = _controller.selection;
    
    if (selection.baseOffset < 0 || selection.extentOffset < 0) {
      // 無效的選擇範圍
      return;
    }
    
    if (selection.baseOffset == selection.extentOffset) {
      // 無選擇文本，插入空的斜體標記
      final newText = text.replaceRange(selection.baseOffset, selection.baseOffset, '**');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.baseOffset + 1),
      );
    } else {
      // 選擇了文本，將其變為斜體
      int startOffset = min(selection.baseOffset, selection.extentOffset);
      int endOffset = max(selection.baseOffset, selection.extentOffset);
      
      // 安全檢查，確保範圍有效
      if (startOffset < 0) startOffset = 0;
      if (endOffset > text.length) endOffset = text.length;
      
      final selectedText = text.substring(startOffset, endOffset);
      final newText = text.replaceRange(startOffset, endOffset, '*$selectedText*');
      
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: endOffset + 2),
      );
    }
    
    // 確保編輯器保持焦點
    _focusNode.requestFocus();
  }

  // 插入代碼塊
  void _insertCodeBlock() {
    final text = _controller.text;
    final selection = _controller.selection;
    
    if (selection.baseOffset < 0 || selection.extentOffset < 0) {
      // 無效的選擇範圍
      return;
    }
    
    if (selection.baseOffset == selection.extentOffset) {
      // 無選擇文本，插入空代碼塊
      const codeBlock = '```\n\n```';
      final newText = text.replaceRange(selection.baseOffset, selection.baseOffset, codeBlock);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.baseOffset + 4),
      );
    } else {
      // 將選擇的文本包裹在代碼塊中
      int startOffset = min(selection.baseOffset, selection.extentOffset);
      int endOffset = max(selection.baseOffset, selection.extentOffset);
      
      // 安全檢查，確保範圍有效
      if (startOffset < 0) startOffset = 0;
      if (endOffset > text.length) endOffset = text.length;
      
      final selectedText = text.substring(startOffset, endOffset);
      final newText = text.replaceRange(startOffset, endOffset, '```\n$selectedText\n```');
      
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: endOffset + 6),
      );
    }
    
    // 確保編輯器保持焦點
    _focusNode.requestFocus();
  }

  // 處理巢狀列表（支持縮進）
  void _processNestingForList(String line, bool ordered) {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.baseOffset;
    
    // 檢測縮進級別（通過計算前導空格或Tab）
    int indentationLevel = 0;
    int i = 0;
    while (i < line.length && (line[i] == ' ' || line[i] == '\t')) {
      if (line[i] == '\t') {
        indentationLevel++;
        i++;
      } else if (i + 3 < line.length && line.substring(i, i + 4) == '    ') {
        indentationLevel++;
        i += 4;
      } else {
        i++;
      }
    }
    
    // 從字符串中移除前導空格
    final trimmedLine = line.trimLeft();
    
    // 檢查是否已經是列表
    final isAlreadyList = trimmedLine.startsWith('- ') || 
                          trimmedLine.startsWith('* ') || 
                          RegExp(r'^\d+\.\s').hasMatch(trimmedLine);
    
    // 構建新行
    String newLine;
    if (isAlreadyList) {
      // 如果已經是列表項，則縮進一級
      final indent = '    ' * (indentationLevel + 1);
      final listPrefix = ordered ? '1. ' : '- ';
      newLine = indent + listPrefix;
    } else {
      // 否則，保持當前縮進級別並添加列表標記
      final indent = '    ' * indentationLevel;
      final listPrefix = ordered ? '1. ' : '- ';
      newLine = indent + listPrefix + trimmedLine;
    }
    
    // 更新文本
    _controller.value = TextEditingValue(
      text: text.replaceRange(selection.baseOffset, selection.baseOffset, newLine),
      selection: TextSelection.collapsed(offset: selection.baseOffset + newLine.length),
    );
    
    // 確保編輯器保持焦點
    _focusNode.requestFocus();
  }

  // 插入列表（支持巢狀）
  void _insertList(bool ordered) {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.baseOffset;
    
    if (cursorPos < 0) return;
    
    final beforeCursor = text.substring(0, cursorPos);
    final afterCursor = text.substring(cursorPos);
    
    // 確定光標是否在行首
    final lastNewLine = beforeCursor.lastIndexOf('\n');
    final isStartOfLine = lastNewLine == beforeCursor.length - 1 || beforeCursor.isEmpty;
    
    // 檢查是否需要處理嵌套
    if (!isStartOfLine) {
      // 獲取當前行
      final lineStart = lastNewLine + 1;
      final currentLine = beforeCursor.substring(lineStart);
      
      // 檢查是否已經是列表項
      final isCurrentLineList = RegExp(r'^\s*[-*]\s').hasMatch(currentLine) || 
                                RegExp(r'^\s*\d+\.\s').hasMatch(currentLine);
      
      if (isCurrentLineList) {
        // 如果當前行已經是列表項，處理嵌套
        _processNestingForList(currentLine, ordered);
        return;
      }
    }
    
    // 檢查是否是連續使用列表功能，實現自動編號
    // 如果當前行是空行，且上一行是有序列表，則繼續編號
    bool continueNumbering = false;
    int nextNumber = 1;
    
    if (ordered && isStartOfLine && lastNewLine > 0) {
      // 取得上一行的內容
      final lastLineStart = beforeCursor.lastIndexOf('\n', lastNewLine - 1) + 1;
      if (lastLineStart > 0) {
        final previousLine = beforeCursor.substring(lastLineStart, lastNewLine);
        final numberMatch = RegExp(r'^(\s*)(\d+)\.\s').firstMatch(previousLine);
        
        if (numberMatch != null) {
          final indent = numberMatch.group(1) ?? '';
          nextNumber = int.parse(numberMatch.group(2) ?? '1') + 1;
          continueNumbering = true;
          
          // 更新文本，保持相同縮進並設置下一個編號
          final prefix = '$indent$nextNumber. ';
          final newText = beforeCursor + prefix + afterCursor;
          
          _controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: cursorPos + prefix.length),
          );
          
          _focusNode.requestFocus();
          return;
        }
      }
    }
    
    // 標準列表處理（非嵌套情況）
    final prefix = ordered ? '1. ' : '- ';
    
    // 生成新文本
    String newText;
    if (isStartOfLine) {
      newText = beforeCursor + prefix + afterCursor;
    } else {
      newText = beforeCursor + '\n' + prefix + afterCursor;
    }
    
    // 更新文本
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (isStartOfLine ? cursorPos : beforeCursor.length + 1) + prefix.length,
      ),
    );
    
    // 確保編輯器保持焦點
    _focusNode.requestFocus();
  }

  // 插入鏈接
  void _insertLink() {
  final text = _controller.text;
  final selection = _controller.selection;
  
  if (selection.baseOffset < 0 || selection.extentOffset < 0) {
  // 無效的選擇範圍
  return;
  }
  
  if (selection.baseOffset == selection.extentOffset) {
  // 無選擇文本，插入空鏈接標記
    final newText = text.replaceRange(selection.baseOffset, selection.baseOffset, '[]()'); 
  _controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: selection.baseOffset + 1),
  );
  } else {
  // 將選擇的文本設置為鏈接文字
  int startOffset = min(selection.baseOffset, selection.extentOffset);
  int endOffset = max(selection.baseOffset, selection.extentOffset);
  
  // 安全檢查，確保範圍有效
  if (startOffset < 0) startOffset = 0;
  if (endOffset > text.length) endOffset = text.length;
  
  final selectedText = text.substring(startOffset, endOffset);
  
  // 檢查選擇的文本是否已經是URL
  final isUrl = Uri.tryParse(selectedText)?.isAbsolute ?? false;
  
  if (isUrl) {
  // 如果選擇的文本是URL，則設置為目標URL而非文本
    final newText = text.replaceRange(startOffset, endOffset, '[](${selectedText})');
      _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: startOffset + 1),
        );
      } else {
        // 一般情況，選擇的文本作為鏈接文字
        final newText = text.replaceRange(startOffset, endOffset, '[${selectedText}]()');
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: endOffset + 3),
        );
      }
    }
    
    // 確保編輯器保持焦點
    _focusNode.requestFocus();
  }
  
  // 插入簡易超連結 <URL> 或 <mail>
  void _insertSimpleLink() {
    final text = _controller.text;
    final selection = _controller.selection;
    
    if (selection.baseOffset < 0 || selection.extentOffset < 0) {
      // 無效的選擇範圍
      return;
    }
    
    if (selection.baseOffset == selection.extentOffset) {
      // 無選擇文本，插入空的簡易鏈接標記
      final newText = text.replaceRange(selection.baseOffset, selection.baseOffset, '<>');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.baseOffset + 1),
      );
    } else {
      // 將選擇的文本包裹在尖括號中
      int startOffset = min(selection.baseOffset, selection.extentOffset);
      int endOffset = max(selection.baseOffset, selection.extentOffset);
      
      // 安全檢查，確保範圍有效
      if (startOffset < 0) startOffset = 0;
      if (endOffset > text.length) endOffset = text.length;
      
      final selectedText = text.substring(startOffset, endOffset);
      final newText = text.replaceRange(startOffset, endOffset, '<$selectedText>');
      
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: endOffset + 2),
      );
    }
    
    // 確保編輯器保持焦點
    _focusNode.requestFocus();
  }

  // 插入圖片
  void _insertImage() {
  final text = _controller.text;
  final selection = _controller.selection;
  
  if (selection.baseOffset < 0 || selection.extentOffset < 0) {
  // 無效的選擇範圍
  return;
  }
  
  if (selection.baseOffset == selection.extentOffset) {
  // 無選擇文本，插入空的圖片標記
    final newText = text.replaceRange(selection.baseOffset, selection.baseOffset, '![]()'); 
  _controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: selection.baseOffset + 2),
  );
  } else {
  // 將選擇的文本設置為圖片說明或URL
  int startOffset = min(selection.baseOffset, selection.extentOffset);
  int endOffset = max(selection.baseOffset, selection.extentOffset);
  
  // 安全檢查，確保範圍有效
  if (startOffset < 0) startOffset = 0;
  if (endOffset > text.length) endOffset = text.length;
  
  final selectedText = text.substring(startOffset, endOffset);
  
  // 檢查選擇的文本是否已經是URL
  final isUrl = Uri.tryParse(selectedText)?.isAbsolute ?? false;
  
  if (isUrl) {
  // 如果選擇的文本是URL，則設置為圖片URL
    final newText = text.replaceRange(startOffset, endOffset, '![](${selectedText})');
      _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: startOffset + 2),
        );
      } else {
        // 一般情況，選擇的文本作為圖片說明
        final newText = text.replaceRange(startOffset, endOffset, '![${selectedText}]()');
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: endOffset + 4),
        );
      }
    }
    
    // 確保編輯器保持焦點
    _focusNode.requestFocus();
  }
  
  // 插入複選框
  void _insertCheckbox() {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.baseOffset;
    
    if (cursorPos < 0) return;
    
    final beforeCursor = text.substring(0, cursorPos);
    final afterCursor = text.substring(cursorPos);
    
    // 確定光標是否在行首
    final lastNewLine = beforeCursor.lastIndexOf('\n');
    final isStartOfLine = lastNewLine == beforeCursor.length - 1 || beforeCursor.isEmpty;
    
    // 生成新文本
    final checkboxMark = "- [ ] ";
    String newText;
    
    if (isStartOfLine) {
      newText = beforeCursor + checkboxMark + afterCursor;
    } else {
      newText = beforeCursor + '\n' + checkboxMark + afterCursor;
    }
    
    // 更新文本
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (isStartOfLine ? cursorPos : beforeCursor.length + 1) + checkboxMark.length,
      ),
    );
    
    // 確保編輯器保持焦點
    _focusNode.requestFocus();
  }

  // 插入表格
  void _insertTable() {
    final text = _controller.text;
    final selection = _controller.selection;
    
    if (selection.baseOffset < 0 || selection.extentOffset < 0) {
      // 無效的選擇範圍
      return;
    }
    
    const tableMarkdown = '| 標題1 | 標題2 | 標題3 |\n| --- | --- | --- |\n| 單元格1 | 單元格2 | 單元格3 |\n| 單元格4 | 單元格5 | 單元格6 |';
    
    // 求出選擇的安全範圍
    int startOffset = min(selection.baseOffset, selection.extentOffset);
    int endOffset = max(selection.baseOffset, selection.extentOffset);
    
    // 安全檢查，確保範圍有效
    if (startOffset < 0) startOffset = 0;
    if (endOffset > text.length) endOffset = text.length;
    
    final newText = text.replaceRange(startOffset, endOffset, tableMarkdown);
    
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: startOffset + tableMarkdown.length),
    );
    
    // 確保編輯器保持焦點
    _focusNode.requestFocus();
  }
  
  // 插入分隔線
  void _insertHorizontalRule() {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.baseOffset;
    
    if (cursorPos < 0) return;
    
    final beforeCursor = text.substring(0, cursorPos);
    final afterCursor = text.substring(cursorPos);
    
    // 確定光標是否在行首
    final lastNewLine = beforeCursor.lastIndexOf('\n');
    final isStartOfLine = lastNewLine == beforeCursor.length - 1 || beforeCursor.isEmpty;
    
    // 根據 Markdown 規範, 分隔線前後應該有空行
    String newText;
    const horizontalRule = "---";
    
    if (isStartOfLine && beforeCursor.length > 0) {
      newText = beforeCursor + horizontalRule + "\n" + afterCursor;
    } else if (isStartOfLine) {
      newText = horizontalRule + "\n" + afterCursor;
    } else {
      newText = beforeCursor + "\n\n" + horizontalRule + "\n\n" + afterCursor;
    }
    
    // 更新文本
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (isStartOfLine ? cursorPos : beforeCursor.length + 2) + horizontalRule.length + 1,
      ),
    );
    
    // 確保編輯器保持焦點
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工具欄
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: MouseRegion(
              // 保持焦點
              opaque: false,  // 讓事件能穿透到下層
              child: Row(
                children: [
                  IconButton(
                    icon: const Text('H1', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _insertHeading(1),
                    tooltip: '標題1',
                    focusNode: FocusNode(skipTraversal: true),  // 避免獲取焦點
                  ),
                  IconButton(
                    icon: const Text('H2', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _insertHeading(2),
                    tooltip: '標題2',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                  IconButton(
                    icon: const Text('H3', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _insertHeading(3),
                    tooltip: '標題3',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                  const VerticalDivider(),
                  IconButton(
                    icon: const Icon(Icons.format_bold),
                    onPressed: _insertBold,
                    tooltip: '粗體',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_italic),
                    onPressed: _insertItalic,
                    tooltip: '斜體',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.code),
                    onPressed: _insertCodeBlock,
                    tooltip: '代碼塊',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                  const VerticalDivider(),
                  IconButton(
                    icon: const Icon(Icons.format_list_bulleted),
                    onPressed: () => _insertList(false),
                    tooltip: '無序列表',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_list_numbered),
                    onPressed: () => _insertList(true),
                    tooltip: '有序列表',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_box_outline_blank),
                    onPressed: _insertCheckbox,
                    tooltip: '複選框',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                  const VerticalDivider(),
                  IconButton(
                    icon: const Icon(Icons.link),
                    onPressed: _insertLink,
                    tooltip: '鏈接',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.link_outlined),
                    onPressed: _insertSimpleLink,
                    tooltip: '簡易鏈接',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _insertImage,
                    tooltip: '圖片',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.table_chart),
                    onPressed: _insertTable,
                    tooltip: '表格',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.horizontal_rule),
                    onPressed: _insertHorizontalRule,
                    tooltip: '分隔線',
                    focusNode: FocusNode(skipTraversal: true),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 編輯器
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: '使用 Markdown 語法輸入筆記內容...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(16.0),
            ),
            style: const TextStyle(fontFamily: 'Roboto Mono', fontSize: 16.0),
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            // 防止點擊外部失去焦點
            onTapOutside: (_) {
              // 保持編輯器焦點
              _focusNode.requestFocus();
            },
            // 確保點擊時獲得焦點
            onTap: () {
              _focusNode.requestFocus();
            },
            // 防止提交表單時失去焦點
            onSubmitted: (text) {
              _focusNode.requestFocus();
            },
          ),
        ),
      ],
    );
  }
}
