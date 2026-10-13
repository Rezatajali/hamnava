import 'package:flutter/material.dart';
import 'widgets.dart';

/// Groups loaded records by their local calendar day, preserving query order.
Map<DateTime?, List<T>> groupJournalDays<T>(
  Iterable<T> entries,
  DateTime? Function(T) dateOf,
) {
  final days = <DateTime?, List<T>>{};
  for (final entry in entries) {
    final date = dateOf(entry)?.toLocal();
    final day = date == null ? null : DateTime(date.year, date.month, date.day);
    days.putIfAbsent(day, () => []).add(entry);
  }
  return days;
}

class JournalDayFolder extends StatelessWidget {
  const JournalDayFolder({
    super.key,
    required this.day,
    required this.count,
    required this.audioCount,
    required this.children,
    this.searching = false,
  });
  final DateTime? day;
  final int count, audioCount;
  final List<Widget> children;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = day == null
        ? 'در انتظار ثبت'
        : day == today
        ? 'امروز · ${dateLabel(day!)}'
        : day == DateTime(now.year, now.month, now.day - 1)
        ? 'دیروز · ${dateLabel(day!)}'
        : dateLabel(day!);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('journal-day-$day-$searching'),
        initiallyExpanded: searching,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: const Icon(Icons.folder_outlined, color: forest),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '$count یادداشت${audioCount == 0 ? '' : ' · $audioCount فایل صوتی'}',
          style: const TextStyle(fontSize: 15, color: mutedInk),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 12),
        children: children,
      ),
    );
  }
}
