import 'package:flutter/material.dart';

import 'chat_theme.dart';

class ChatFilterChips<T> extends StatelessWidget {
  final bool isDark;
  final List<T> filters;
  final T selected;
  final String Function(T) labelFor;
  final ValueChanged<T> onSelected;

  const ChatFilterChips({
    super.key,
    required this.isDark,
    required this.filters,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette(isDark);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: filters.map((f) {
          final active = f == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: active ? p.accentSoft : p.surface,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => onSelected(f),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? p.accent : p.borderSubtle,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    labelFor(f),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? p.accent : p.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
