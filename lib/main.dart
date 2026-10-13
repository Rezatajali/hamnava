import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'copy.dart';
import 'domain.dart';

void main() => runApp(const HamnavaApp());

class HamnavaApp extends StatelessWidget {
  const HamnavaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: fa['name']!,
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff6f2e9),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff244f43)),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
      ),
    ),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int page = 0;
  final journal = TextEditingController();
  final amount = TextEditingController();
  final entries = <JournalEntry>[];
  final transactions = <MoneyTransaction>[];
  TransactionKind kind = TransactionKind.expense;
  String category = fa['food']!;
  String? error;

  @override
  void dispose() { journal.dispose(); amount.dispose(); super.dispose(); }

  String money(int cents) => '${(cents / 100).toStringAsFixed(2)} €';

  Widget box(Widget child) => Card(
    elevation: 0, color: Colors.white,
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(fa['name']!), backgroundColor: Colors.transparent),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page, onDestinationSelected: (value) => setState(() => page = value),
      destinations: [
        NavigationDestination(icon: const Icon(Icons.auto_stories_outlined), label: fa['journal']!),
        NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), label: fa['finance']!),
      ],
    ),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Text(fa['demo']!, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
        if (page == 0) ...journalScreen() else ...financeScreen(),
      ]),
    ))),
  );

  List<Widget> journalScreen() => [
    Text(fa['today']!, style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 8), Text(fa['subtitle']!), const SizedBox(height: 24),
    box(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Tooltip(message: fa['voicePending']!, child: OutlinedButton.icon(
        onPressed: null, icon: const Icon(Icons.mic_none), label: Text(fa['voice']!),
      )),
      Text(fa['voicePending']!, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      TextField(controller: journal, minLines: 5, maxLines: 12,
        decoration: InputDecoration(hintText: fa['draft'])),
      const SizedBox(height: 16),
      FilledButton(onPressed: () {
        final text = journal.text.trim();
        if (text.isEmpty) return;
        setState(() { entries.insert(0, JournalEntry(text: text, createdAt: DateTime.now())); journal.clear(); });
      }, child: Text(fa['save']!)),
    ])),
    if (entries.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(fa['empty']!)),
    for (final entry in entries) box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('${entry.createdAt.year}/${entry.createdAt.month}/${entry.createdAt.day}')),
        IconButton(tooltip: fa['delete'], onPressed: () => setState(() => entries.remove(entry)),
          icon: const Icon(Icons.delete_outline)),
      ]),
      SelectableText(entry.text),
    ])),
  ];

  List<Widget> financeScreen() {
    final now = DateTime.now();
    final income = monthTotal(transactions, now, TransactionKind.income);
    final expense = monthTotal(transactions, now, TransactionKind.expense);
    final monthly = transactions.where((t) => t.createdAt.year == now.year && t.createdAt.month == now.month).toList();
    final groups = <String, int>{};
    for (final t in monthly.where((t) => t.kind == TransactionKind.expense)) {
      groups.update(t.category, (value) => value + t.cents, ifAbsent: () => t.cents);
    }
    return [
      Text(fa['finance']!, style: Theme.of(context).textTheme.headlineMedium),
      Text(fa['month']!), const SizedBox(height: 20),
      box(Column(children: [
        Text(fa['balance']!), Text(money(income - expense), textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Wrap(spacing: 24, runSpacing: 8, children: [Text('${fa['income']}: ${money(income)}'), Text('${fa['expense']}: ${money(expense)}')]),
      ])),
      box(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<TransactionKind>(segments: [
          ButtonSegment(value: TransactionKind.expense, label: Text(fa['expense']!)),
          ButtonSegment(value: TransactionKind.income, label: Text(fa['income']!)),
        ], selected: {kind}, onSelectionChanged: (values) => setState(() => kind = values.first)),
        const SizedBox(height: 16),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: fa['amount'], errorText: error)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: category,
          decoration: InputDecoration(labelText: fa['category']),
          items: ['food', 'transport', 'shopping', 'home', 'salary', 'other'].map((key) =>
            DropdownMenuItem(value: fa[key], child: Text(fa[key]!))).toList(),
          onChanged: (value) { if (value != null) setState(() => category = value); }),
        const SizedBox(height: 16),
        FilledButton(onPressed: () {
          final cents = parseCents(amount.text);
          if (cents == null) { setState(() => error = fa['invalid']); return; }
          setState(() {
            transactions.insert(0, MoneyTransaction(cents: cents, kind: kind, category: category, createdAt: DateTime.now()));
            amount.clear(); error = null;
          });
        }, child: Text(fa['add']!)),
      ])),
      if (groups.isNotEmpty) box(Column(children: [
        for (final group in groups.entries) Padding(padding: const EdgeInsets.only(bottom: 14), child:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${group.key} · ${money(group.value)}'), const SizedBox(height: 6),
            Semantics(label: '${group.key}: ${money(group.value)}', child: LinearProgressIndicator(
              value: group.value / expense, minHeight: 10)),
          ])),
      ])),
      if (monthly.isEmpty) Text(fa['none']!),
      for (final t in monthly) box(ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(t.kind == TransactionKind.income ? Icons.arrow_downward : Icons.arrow_upward),
        title: Text(t.category), subtitle: Text(money(t.cents), textDirection: TextDirection.ltr),
        trailing: IconButton(tooltip: fa['delete'], onPressed: () => setState(() => transactions.remove(t)),
          icon: const Icon(Icons.delete_outline)),
      )),
    ];
  }
}
