import 'package:flutter/material.dart';
import 'package:note/models/note.dart';
import 'package:intl/intl.dart';

class NoteList extends StatelessWidget {
  final List<Note> notes;
  final Function(Note) onNoteTap;
  final Function(Note) onNoteDelete;
  final Function(Note, bool)? onNoteFavorite;

  const NoteList({
    Key? key,
    required this.notes,
    required this.onNoteTap,
    required this.onNoteDelete,
    this.onNoteFavorite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '沒有筆記',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '點擊右下角的加號按鈕創建新筆記',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        
        // 格式化日期
        final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
        final updatedAt = dateFormat.format(note.updatedAt);
        
        // 提取 Markdown 預覽
        String preview = note.content;
        // 移除 Markdown 語法標記
        preview = preview.replaceAll(RegExp(r'#+ '), '');
        preview = preview.replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'\1');
        preview = preview.replaceAll(RegExp(r'\*(.*?)\*'), r'\1');
        preview = preview.replaceAll(RegExp(r'`(.*?)`'), r'\1');
        preview = preview.replaceAll(RegExp(r'!\[(.*?)\]\(.*?\)'), '[圖片]');
        preview = preview.replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'\1');
        
        // 限制長度
        if (preview.length > 100) {
          preview = preview.substring(0, 100) + '...';
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(
              note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  updatedAt,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            leading: note.isFavorite
                ? const Icon(Icons.star, color: Colors.amber)
                : const Icon(Icons.description),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'delete':
                    onNoteDelete(note);
                    break;
                  case 'favorite':
                    onNoteFavorite?.call(note, !note.isFavorite);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'favorite',
                  child: Row(
                    children: [
                      Icon(
                        note.isFavorite ? Icons.star_border : Icons.star,
                        color: note.isFavorite ? null : Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Text(note.isFavorite ? '取消收藏' : '收藏'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('刪除'),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => onNoteTap(note),
          ),
        );
      },
    );
  }
}