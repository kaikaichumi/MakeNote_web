import 'package:flutter/material.dart';
import 'package:note/models/category.dart';
import 'package:note/services/storage_service.dart';
import 'package:note/utils/constants.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({Key? key}) : super(key: key);

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final StorageService _storageService = StorageService();
  List<Category> _categories = [];
  bool _isLoading = true;
  final TextEditingController _nameController = TextEditingController();
  Color _selectedColor = Colors.blue;
  Category? _selectedParentCategory;

  // 展開狀態管理
  Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 載入所有類別
  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 獲取所有類別
      final categories = await _storageService.getAllCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入類別時出錯: $e')),
        );
      }
    }
  }

  // 顯示添加/編輯類別對話框
  void _showCategoryDialog([Category? category, Category? parentCategory]) {
    if (category != null) {
      _nameController.text = category.name;
      _selectedColor = category.color;
      if (category.parentId != null) {
        // 修正：使用 firstWhereOrNull 擴展方法來避免空安全問題
        _selectedParentCategory = _categories
            .where((cat) => cat.id == category.parentId)
            .firstOrNull;
      } else {
        _selectedParentCategory = null;
      }
    } else {
      _nameController.clear();
      _selectedColor = Colors.blue;
      _selectedParentCategory = parentCategory;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(category == null ? '添加類別' : '編輯類別'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '類別名稱',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('選擇上層類別:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<Category?>(
                  value: _selectedParentCategory,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<Category?>(
                      value: null,
                      child: Text('無（頂層類別）'),
                    ),
                    ..._categories
                        .where((cat) => cat.id != category?.id) // 避免選擇自己作為父類別
                        .map((cat) => DropdownMenuItem<Category?>(
                              value: cat,
                              child: Text(cat.name),
                            ))
                        .toList(),
                  ],
                  onChanged: (newValue) {
                    setState(() {
                      _selectedParentCategory = newValue;
                    });
                  },
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
                    const SnackBar(content: Text('類別名稱不能為空')),
                  );
                  return;
                }

                if (category == null) {
                  // 添加新類別
                  final newCategory = Category(
                    name: _nameController.text.trim(),
                    color: _selectedColor,
                    parentId: _selectedParentCategory?.id,
                  );
                  _saveCategory(newCategory);
                  
                  // 如果有父類別，更新父類別的子類別列表
                  if (_selectedParentCategory != null) {
                    final updatedParent = _selectedParentCategory!.copyWith(
                      childrenIds: [..._selectedParentCategory!.childrenIds, newCategory.id],
                    );
                    _updateCategory(updatedParent);
                  }
                } else {
                  // 檢查是否更改了父類別
                  final oldParentId = category.parentId;
                  final newParentId = _selectedParentCategory?.id;
                  
                  // 更新現有類別
                  final updatedCategory = category.copyWith(
                    name: _nameController.text.trim(),
                    color: _selectedColor,
                    parentId: newParentId,
                  );
                  _updateCategory(updatedCategory);
                  
                  // 更新舊父類別和新父類別的子類別列表
                  if (oldParentId != newParentId) {
                    // 從舊父類別中移除
                    if (oldParentId != null) {
                      final oldParent = _categories
                          .where((cat) => cat.id == oldParentId)
                          .firstOrNull;
                      if (oldParent != null) {
                        final updatedOldParent = oldParent.copyWith(
                          childrenIds: oldParent.childrenIds.where((id) => id != category.id).toList(),
                        );
                        _updateCategory(updatedOldParent);
                      }
                    }
                    
                    // 添加到新父類別
                    if (newParentId != null) {
                      final newParent = _categories.firstWhere(
                        (cat) => cat.id == newParentId,
                      );
                      final updatedNewParent = newParent.copyWith(
                        childrenIds: [...newParent.childrenIds, category.id],
                      );
                      _updateCategory(updatedNewParent);
                    }
                  }
                }

                Navigator.of(context).pop();
              },
              child: Text(category == null ? '添加' : '更新'),
            ),
          ],
        ),
      ),
    );
  }

  // 保存新類別
  Future<void> _saveCategory(Category category) async {
    try {
      await _storageService.saveCategory(category);
      _loadCategories();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('類別已添加')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加類別時出錯: $e')),
        );
      }
    }
  }

  // 更新類別
  Future<void> _updateCategory(Category category) async {
    try {
      await _storageService.updateCategory(category);
      _loadCategories();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('類別已更新')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新類別時出錯: $e')),
        );
      }
    }
  }

  // 刪除類別
  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('您確定要刪除類別 "${category.name}" 嗎？這將移除所有筆記的此類別標記，以及所有子類別。'),
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
        // 首先需要處理該類別的子類別
        for (final childId in category.childrenIds) {
          final child = _categories
              .where((cat) => cat.id == childId)
              .firstOrNull;
          if (child != null) {
            await _deleteCategory(child); // 遞迴刪除子類別
          }
        }
        
        // 如果該類別有父類別，更新父類別的子類別列表
        if (category.parentId != null) {
          final parent = _categories
              .where((cat) => cat.id == category.parentId)
              .firstOrNull;
          if (parent != null) {
            final updatedParent = parent.copyWith(
              childrenIds: parent.childrenIds.where((id) => id != category.id).toList(),
            );
            await _storageService.updateCategory(updatedParent);
          }
        }
        
        // 最後刪除該類別
        await _storageService.deleteCategory(category.id);
        
        _loadCategories();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('類別已刪除')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('刪除類別時出錯: $e')),
          );
        }
      }
    }
  }

  // 創建子類別
  void _addSubcategory(Category parentCategory) {
    _showCategoryDialog(null, parentCategory);
  }

  // 構建類別樹
  Widget _buildCategoryTree() {
    // 獲取頂層類別（無父類別的類別）
    final topLevelCategories = _categories.where((cat) => cat.parentId == null).toList();
    
    // 為了避免重複顯示，保存已經顯示的類別ID
    Set<String> processedIds = {};
    
    return ListView.builder(
      itemCount: topLevelCategories.length,
      itemBuilder: (context, index) {
        return _buildCategoryItem(topLevelCategories[index], 0, processedIds);
      },
    );
  }

  // 構建類別項目
  Widget _buildCategoryItem(Category category, int depth, Set<String> processedIds) {
    // 如果該類別已經處理過，則跳過，避免重複顯示
    if (processedIds.contains(category.id)) {
      return const SizedBox.shrink();
    }
    
    // 標記此ID已被處理
    processedIds.add(category.id);
    
    // 查找子類別，確保子類別不包含自身和已處理過的類別
    final children = _categories.where((cat) => 
      cat.parentId == category.id && 
      cat.id != category.id && 
      !processedIds.contains(cat.id)
    ).toList();
    
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedCategories.contains(category.id);

    return Column(
      children: [
        InkWell(
          onTap: () {
            // 點擊整個項目時展開/收起
            setState(() {
              if (isExpanded) {
                _expandedCategories.remove(category.id);
              } else {
                _expandedCategories.add(category.id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                SizedBox(width: 16.0 + depth * 20.0),
                Icon(
                  isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Icon(Icons.folder, color: category.color),
                const SizedBox(width: 8),
                Expanded(child: Text(category.name)),
                // 進行操作的按鈕
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _addSubcategory(category),
                  tooltip: '新增資料夾',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('編輯類別'),
                            onTap: () {
                              Navigator.pop(context);
                              _showCategoryDialog(category);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete),
                            title: const Text('刪除類別'),
                            onTap: () {
                              Navigator.pop(context);
                              _deleteCategory(category);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        if (isExpanded && hasChildren)
          ...children.map((child) => _buildCategoryItem(child, depth + 1, processedIds)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理類別'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(
                  child: Text('沒有類別，點擊右下角的按鈕添加'),
                )
              : _buildCategoryTree(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        tooltip: '添加類別',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Dart 2.12 後的 firstOrNull 擴展方法
extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}