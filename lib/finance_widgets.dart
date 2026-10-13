import 'package:flutter/material.dart';
import 'widgets.dart';

IconData categoryIcon(String category) => switch (category) {
  'غذا' => Icons.restaurant_outlined,
  'رفت‌وآمد' => Icons.directions_bus_outlined,
  'خرید' => Icons.shopping_bag_outlined,
  'خانه' => Icons.home_outlined,
  'حقوق' => Icons.work_outline,
  _ => Icons.more_horiz,
};

class FinanceItem {
  const FinanceItem({
    required this.id,
    required this.category,
    required this.cents,
    required this.income,
    required this.date,
    required this.note,
    this.receiptCount = 0,
  });
  final String id, category, note;
  final int cents;
  final int receiptCount;
  final bool income;
  final DateTime date;
}

/// One category chart; individual records are available on demand below it.
class FinanceOverview extends StatelessWidget {
  const FinanceOverview({
    super.key,
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });
  final List<FinanceItem> items;
  final ValueChanged<String> onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    var income = 0, expense = 0;
    final groups = <String, int>{};
    for (final item in items) {
      if (item.income) {
        income += item.cents;
      } else {
        expense += item.cents;
        groups.update(
          item.category,
          (total) => total + item.cents,
          ifAbsent: () => item.cents,
        );
      }
    }
    final categories = groups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        paper(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('ماندهٔ این ماه', style: TextStyle(color: forest)),
              const SizedBox(height: 6),
              Text(
                money(income - expense),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: forest,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 32,
                runSpacing: 16,
                children: [
                  _Total(
                    label: 'درآمد',
                    cents: income,
                    icon: Icons.south_west,
                    color: forest,
                  ),
                  _Total(
                    label: 'هزینه',
                    cents: expense,
                    icon: Icons.north_east,
                    color: expenseInk,
                  ),
                ],
              ),
            ],
          ),
          color: const Color(0xffe7eee5),
        ),
        if (categories.isNotEmpty)
          paper(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'هزینه‌ها به تفکیک دسته',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'سهم هر دسته از کل هزینهٔ ماه',
                  style: TextStyle(color: mutedInk, fontSize: 15),
                ),
                const SizedBox(height: 24),
                for (final group in categories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            categoryIcon(group.key),
                            color: forest,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                group.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 12,
                                children: [
                                  Text(
                                    money(group.value),
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(color: expenseInk),
                                  ),
                                  Text(
                                    '${(group.value / expense * 100).round()}٪',
                                    style: const TextStyle(color: mutedInk),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  value: group.value / expense,
                                  semanticsLabel: 'سهم ${group.key}',
                                  color: copper,
                                  backgroundColor: const Color(0xffeee8dc),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (items.isEmpty)
          paper(
            const Column(
              children: [
                Icon(Icons.receipt_long_outlined, color: forest, size: 36),
                SizedBox(height: 12),
                Text(
                  'این ماه هنوز تراکنشی نداری.',
                  textAlign: TextAlign.center,
                ),
                Text(
                  'از دکمهٔ ثبت تراکنش شروع کن.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mutedInk),
                ),
              ],
            ),
          )
        else
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              key: const PageStorageKey('finance-details'),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              title: const Text(
                'ریز تراکنش‌ها',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${items.length} تراکنش · مشاهده و ویرایش',
                style: const TextStyle(fontSize: 15, color: mutedInk),
              ),
              children: [
                for (final item in items)
                  _TransactionRow(
                    item: item,
                    onEdit: () => onEdit(item.id),
                    onDelete: () => onDelete(item.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.cents,
    required this.icon,
    required this.color,
  });
  final String label;
  final int cents;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      Text(
        money(cents),
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ],
  );
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  final FinanceItem item;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 8, 16),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xffeee8dc))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${item.income ? 'درآمد' : 'هزینه'} · ${dateLabel(item.date)}',
                    style: const TextStyle(fontSize: 14, color: mutedInk),
                  ),
                  Text(
                    money(item.cents),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: item.income ? forest : expenseInk,
                    ),
                  ),
                  if (item.receiptCount > 0)
                    Text(
                      '${item.receiptCount} رسید',
                      style: const TextStyle(fontSize: 14, color: forest),
                    ),
                  if (item.note.isNotEmpty)
                    Text(
                      item.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                ],
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'گزینه‌های تراکنش',
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else {
              onDelete();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('ویرایش')),
            PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
      ],
    ),
  );
}
