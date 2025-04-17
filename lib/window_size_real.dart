import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';

// 這是真實的實現，用於桌面平台
void initializeWindow() {
  // 設置窗口標題和大小
  setWindowTitle('MakeNote');
  setWindowMinSize(const Size(800, 600));
  setWindowMaxSize(Size.infinite);
}