import 'package:flutter/foundation.dart';

@immutable
class GridFilterOption {
  final String value;
  final String label;
  final bool selected;

  const GridFilterOption({
    required this.value,
    required this.label,
    this.selected = false,
  });

  GridFilterOption copyWith({String? value, String? label, bool? selected}) {
    return GridFilterOption(
      value: value ?? this.value,
      label: label ?? this.label,
      selected: selected ?? this.selected,
    );
  }
}

@immutable
class GridFilterState {
  final String search;
  final List<GridFilterOption> options;

  const GridFilterState({
    this.search = '',
    this.options = const <GridFilterOption>[],
  });

  GridFilterState copyWith({String? search, List<GridFilterOption>? options}) {
    return GridFilterState(
      search: search ?? this.search,
      options: options ?? this.options,
    );
  }

  List<GridFilterOption> get visibleOptions {
    final normalized = search.trim().toLowerCase();
    if (normalized.isEmpty) return options;
    return options
        .where((option) => option.label.toLowerCase().contains(normalized))
        .toList();
  }

  Set<String> get selectedValues {
    return options
        .where((option) => option.selected)
        .map((option) => option.value)
        .toSet();
  }
}
