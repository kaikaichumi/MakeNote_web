import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Tag {
  String id;
  String name;
  Color color;

  Tag({
    String? id,
    required this.name,
    required this.color,
  }) : id = id ?? const Uuid().v4();

  // 從JSON對象創建Tag
  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'],
      name: json['name'],
      color: Color(json['color']),
    );
  }

  // 將Tag轉換為JSON對象
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
    };
  }

  // 創建Tag副本
  Tag copyWith({
    String? name,
    Color? color,
  }) {
    return Tag(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}