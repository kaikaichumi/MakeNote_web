import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Category {
  String id;
  String name;
  Color color;
  String? parentId; // 新增父類別ID
  List<String> childrenIds; // 新增子類別ID列表

  Category({
    String? id,
    required this.name,
    required this.color,
    this.parentId,
    List<String>? childrenIds,
  }) : id = id ?? const Uuid().v4(),
       childrenIds = childrenIds ?? [];

  // 從JSON對象創建Category
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      color: Color(json['color']),
      parentId: json['parentId'],
      childrenIds: List<String>.from(json['childrenIds'] ?? []),
    );
  }

  // 將Category轉換為JSON對象
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'parentId': parentId,
      'childrenIds': childrenIds,
    };
  }

  // 創建Category副本
  Category copyWith({
    String? name,
    Color? color,
    String? parentId,
    List<String>? childrenIds,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      parentId: parentId ?? this.parentId,
      childrenIds: childrenIds ?? List.from(this.childrenIds),
    );
  }
}