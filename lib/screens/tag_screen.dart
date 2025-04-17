import 'package:flutter/material.dart';
import 'package:note/models/tag.dart';
import 'package:note/services/storage_service.dart';
import 'package:note/utils/constants.dart';

class TagScreen extends StatefulWidget {
  const TagScreen({Key? key}) : super(key: key);

  @override
  State<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> {
  final StorageService _storageService = StorageService();
  List<Tag> _tags = [];
  bool _isLoading = true;
  final TextEditingController _nameController = TextEditingController();
  Color _selectedColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 載入所有標籤
  Future<void> _loadTags() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 獲取所有標籤
      final tags = await _storageService.getAllTags();
      setState(() {
        _tags = tags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入標籤時出錯: $e')),
        );
      }
    }
  }

  // 顯示添加/編輯標籤對話框
  void _showTagDialog([Tag? tag]) {
    if (tag != null) {
      _nameController.text = tag.name;
      _selectedColor = tag.color;
    } else {
      _nameController.clear();
      _selectedColor = Colors.blue;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(tag == null ? '添加標籤' : '編輯標籤'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '標籤名稱',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('選擇顏色:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.categoryColors.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == color
                              ? Colors.black
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (_nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('標籤名稱不能為空')),
                  );
                  return;
                }

                if (tag == null) {
                  // 添加新標籤
                  final newTag = Tag(
                    name: _nameController.text.trim(),
                    color: _selectedColor,
                  );
                  _saveTag(newTag);
                } else {
                  // 更新現有標籤
                  final updatedTag = tag.copyWith(
                    name: _nameController.text.trim(),
                    color: _selectedColor,
                  );
                  _updateTag(updatedTag);
                }

                Navigator.of(context).pop();
              },
              child: Text(tag == null ? '添加' : '更新'),
            ),
          ],
        ),
      ),
    );
  }

  // 保存新標籤
  Future<void> _saveTag(Tag tag) async {
    try {
      await _storageService.saveTag(tag);
      _loadTags();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('標籤已添加')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加標籤時出錯: $e')),
        );
      }
    }
  }

  // 更新標籤
  Future<void> _updateTag(Tag tag) async {
    try {
      await _storageService.updateTag(tag);
      _loadTags();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('標籤已更新')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新標籤時出錯: $e')),
        );
      }
    }
  }

  // 刪除標籤
  Future<void> _deleteTag(Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('您確定要刪除標籤 "${tag.name}" 嗎？這將移除所有筆記的此標籤標記。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _storageService.deleteTag(tag.id);
        _loadTags();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('標籤已刪除')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('刪除標籤時出錯: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理標籤'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tags.isEmpty
              ? const Center(
                  child: Text('沒有標籤，點擊右下角的按鈕添加'),
                )
              : ListView.builder(
                  itemCount: _tags.length,
                  itemBuilder: (context, index) {
                    final tag = _tags[index];
                    return ListTile(
                      leading: Icon(
                        Icons.label,
                        color: tag.color,
                      ),
                      title: Text(tag.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showTagDialog(tag),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteTag(tag),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTagDialog(),
        tooltip: '添加標籤',
        child: const Icon(Icons.add),
      ),
    );
  }
}