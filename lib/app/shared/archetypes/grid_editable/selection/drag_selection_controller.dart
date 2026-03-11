import 'package:flutter/material.dart';

@immutable
class DragSelectionRect {
  final Offset start;
  final Offset end;

  const DragSelectionRect({required this.start, required this.end});

  Rect get rect => Rect.fromPoints(start, end);
}

class DragSelectionController extends ChangeNotifier {
  DragSelectionRect? _current;

  DragSelectionRect? get current => _current;
  bool get dragging => _current != null;

  void start(Offset point) {
    _current = DragSelectionRect(start: point, end: point);
    notifyListeners();
  }

  void update(Offset point) {
    final current = _current;
    if (current == null) return;
    _current = DragSelectionRect(start: current.start, end: point);
    notifyListeners();
  }

  void clear() {
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }
}
