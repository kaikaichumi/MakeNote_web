import 'package:uuid/uuid.dart';

class Note {
  String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  String? categoryId;
  List<String> tagIds;
  bool isFavorite;
  bool isArchived;

  Note({
    String? id,
    required this.title,
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.categoryId,
    List<String>? tagIds,
    this.isFavorite = false,
    this.isArchived = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        tagIds = tagIds ?? [];

  // 從JSON對象創建Note
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      categoryId: json['categoryId'],
      tagIds: List<String>.from(json['tagIds'] ?? []),
      isFavorite: json['isFavorite'] ?? false,
      isArchived: json['isArchived'] ?? false,
    );
  }

  // 將Note轉換為JSON對象
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'categoryId': categoryId,
      'tagIds': tagIds,
      'isFavorite': isFavorite,
      'isArchived': isArchived,
    };
  }

  // 創建Note副本
  Note copyWith({
    String? title,
    String? content,
    String? categoryId,
    List<String>? tagIds,
    bool? isFavorite,
    bool? isArchived,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      categoryId: categoryId ?? this.categoryId,
      tagIds: tagIds ?? List.from(this.tagIds),
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}