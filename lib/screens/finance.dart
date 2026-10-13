import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../domain.dart';
import '../repository.dart';
import '../voice_composer.dart';
import '../widgets.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, required this.repo});
  final PersonalRepository repo;
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}
class _FinanceScreenState extends State<FinanceScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  late Stream<QuerySnapshot<Map<String, dynamic>>> stream = widget.repo.monthQuery(month).snapshots();
  void changeMonth(int step) => setState(() {
    month = DateTime(month.year, month.month + step);
    stream = widget.repo.monthQuery(month).snapshots();
  });
  Future<void> edit([DocumentSnapshot<Map<String, dynamic>>? doc]) => showDialog<void>(context: context,
    barrierDismissible: false, builder: (_) => TransactionEditor(repo: widget.repo, doc: doc, initialDate: month));
  Widget metric(String label, int cents, Color color) => SizedBox(width: 220, child: paper(Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), const SizedBox(height: 12),
      Text(money(cents), textDirection: TextDirection.ltr, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, color: color))])));
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
    Text('پولم کجا رفت؟', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: forest)),
    const SizedBox(height: 8), const Text('درآمد و هزینه‌ها، مستقل از دفتر روزانه.'), const SizedBox(height: 20),
    Row(children: [IconButton(tooltip: 'ماه قبل', onPressed: () => changeMonth(-1), icon: const Icon(Icons.chevron_right)),
      Expanded(child: Text('${month.year} / ${month.month} · ماه میلادی', textAlign: TextAlign.center)),
      IconButton(tooltip: 'ماه بعد', onPressed: () => changeMonth(1), icon: const Icon(Icons.chevron_left))]),
    const SizedBox(height: 16),
    FilledButton.icon(onPressed: () => edit(), icon: const Icon(Icons.add), label: const Padding(
      padding: EdgeInsets.all(12), child: Text('ثبت درآمد یا هزینه · با صدا یا متن'))),
    const SizedBox(height: 24),
    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: stream, builder: (context, snapshot) {
      if (snapshot.hasError) return paper(Text(errorText(snapshot.error!)));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final docs = [...snapshot.data!.docs]..sort((a,b) => ((b.data()['date'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)
        .compareTo((a.data()['date'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
      int income = 0, expense = 0;
      final groups = <String, int>{};
      for (final doc in docs) {
        final data = doc.data();
        if (data['currency'] != 'EUR') continue;
        final cents = data['cents'] as int? ?? 0;
        if (data['kind'] == 'income') income += cents;
        else { expense += cents; groups.update(data['category'] as String? ?? 'سایر', (v) => v + cents, ifAbsent: () => cents); }
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 12, runSpacing: 0, children: [metric('درآمد', income, forest), metric('هزینه', expense, copper), metric('مانده ماه', income - expense, forest)]),
        if (groups.isNotEmpty) paper(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('سهم هزینه‌ها', style: TextStyle(fontSize: 20)), const SizedBox(height: 20),
          for (final group in groups.entries) Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [Expanded(child: Text(group.key)), Text('${money(group.value)} · ${(group.value / expense * 100).round()}٪')]),
              const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(
                minHeight: 12, value: group.value / expense, color: copper, backgroundColor: const Color(0xffeee8dc))),
            ])),
        ])),
        if (docs.isEmpty) paper(const Text('این ماه هنوز تراکنشی نداری. اولین مورد را ثبت کن.')),
        for (final doc in docs) paper(ListTile(contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: const Color(0xfff6f2e9), child: Icon(doc.data()['kind'] == 'income' ? Icons.south_west : Icons.north_east,
            color: doc.data()['kind'] == 'income' ? forest : copper)),
          title: Text('${doc.data()['category']} · ${money(doc.data()['cents'] as int? ?? 0)}'),
          subtitle: Text('${dateLabel((doc.data()['date'] as Timestamp?)?.toDate() ?? month)}\n${doc.data()['note'] ?? ''}'),
          trailing: Wrap(children: [IconButton(tooltip: 'ویرایش', onPressed: () => edit(doc), icon: const Icon(Icons.edit_outlined)),
            IconButton(tooltip: 'حذف', onPressed: () async {
              if (!await confirmDelete(context)) return;
              try { await widget.repo.delete('transactions', doc.id); } catch (e) { if (mounted) notice(context, errorText(e)); }
            }, icon: const Icon(Icons.delete_outline))]),
        )),
      ]);
    }),
  ]);
}

class TransactionEditor extends StatefulWidget {
  const TransactionEditor({super.key, required this.repo, required this.initialDate, this.doc});
  final PersonalRepository repo;
  final DateTime initialDate;
  final DocumentSnapshot<Map<String, dynamic>>? doc;
  @override
  State<TransactionEditor> createState() => _TransactionEditorState();
}
class _TransactionEditorState extends State<TransactionEditor> {
  late final id = widget.doc?.id ?? widget.repo.collection('transactions').doc().id;
  final transcript = TextEditingController();
  late final amount = TextEditingController(text: widget.doc == null ? '' : ((widget.doc!.data()!['cents'] as int) / 100).toStringAsFixed(2));
  late final note = TextEditingController(text: widget.doc?.data()?['note'] as String? ?? '');
  late String category = widget.doc?.data()?['category'] as String? ?? 'سایر';
  late TransactionKind kind = widget.doc?.data()?['kind'] == 'income' ? TransactionKind.income : TransactionKind.expense;
  late DateTime date = (widget.doc?.data()?['date'] as Timestamp?)?.toDate() ??
    (widget.initialDate.year == DateTime.now().year && widget.initialDate.month == DateTime.now().month ? DateTime.now() : widget.initialDate);
  bool busy = false, recording = false;
  String? error;
  @override
  void dispose() { transcript.dispose(); amount.dispose(); note.dispose(); super.dispose(); }
  void suggest() {
    final suggestion = suggestTransaction(transcript.text);
    if (suggestion == null) { setState(() => error = 'مبلغ یورو تشخیص داده نشد؛ مبلغ و دسته را دستی وارد کن.'); return; }
    setState(() {
      amount.text = (suggestion.cents / 100).toStringAsFixed(2);
      category = suggestion.category; kind = suggestion.kind; note.text = transcript.text;
      error = 'این فقط یک پیشنهاد است؛ مبلغ، نوع و دسته را قبل از ذخیره بررسی کن.';
    });
  }
  Future<void> save() async {
    if (busy || recording) return;
    final cents = parseCents(amount.text);
    if (cents == null || note.text.length > 2000) { setState(() => error = 'مبلغ مثبت با حداکثر دو رقم اعشار و توضیح تا ۲۰۰۰ کاراکتر وارد کن.'); return; }
    setState(() { busy = true; error = null; });
    try {
      await widget.repo.saveTransaction(id, {
        'cents': cents, 'kind': kind.name, 'currency': 'EUR', 'category': category,
        'note': note.text.trim(), 'date': Timestamp.fromDate(date),
        'month': '${date.year}-${date.month.toString().padLeft(2, '0')}',
        'createdAt': widget.doc?.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) setState(() => error = errorText(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !busy && !recording, child: Dialog(
    insetPadding: const EdgeInsets.all(16), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620),
      child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: Text('ثبت مالی', style: Theme.of(context).textTheme.headlineSmall)),
          IconButton(tooltip: 'بستن', onPressed: busy || recording ? null : () => Navigator.pop(context), icon: const Icon(Icons.close))]),
        const Text('مثلاً: امروز دوازده یورو برای ناهار خرج کردم.'),
        VoiceComposer(controller: transcript, enabled: !busy, audioKey: '', transcriptionOnly: true, onAudio: (_) {},
          onBusy: (value) => setState(() => recording = value)),
        TextField(controller: transcript, enabled: !busy && !recording, maxLines: 3, decoration: const InputDecoration(labelText: 'جمله مالی')),
        TextButton(onPressed: busy || recording ? null : suggest, child: const Text('ساخت پیشنهاد از جمله')),
        const SizedBox(height: 16),
        SegmentedButton<TransactionKind>(segments: const [ButtonSegment(value: TransactionKind.expense, label: Text('هزینه')),
          ButtonSegment(value: TransactionKind.income, label: Text('درآمد'))], selected: {kind},
          onSelectionChanged: busy ? null : (values) => setState(() => kind = values.first)),
        const SizedBox(height: 16), TextField(controller: amount, enabled: !busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'مبلغ به یورو')),
        const SizedBox(height: 16), DropdownButtonFormField<String>(initialValue: category, key: ValueKey(category),
          decoration: const InputDecoration(labelText: 'دسته'), items: ['غذا', 'رفت‌وآمد', 'خرید', 'خانه', 'حقوق', 'سایر']
            .map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
          onChanged: busy ? null : (value) => setState(() => category = value!)),
        const SizedBox(height: 12), OutlinedButton.icon(onPressed: busy ? null : () async {
          final selected = await showDatePicker(context: context, initialDate: date,
            firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (selected != null && mounted) setState(() => date = selected);
        }, icon: const Icon(Icons.calendar_today_outlined), label: Text(dateLabel(date))),
        const SizedBox(height: 12), TextField(controller: note, enabled: !busy, maxLength: 2000,
          decoration: const InputDecoration(labelText: 'توضیح (اختیاری)')),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
        const SizedBox(height: 12), FilledButton(onPressed: busy || recording ? null : save,
          child: Padding(padding: const EdgeInsets.all(12), child: Text(busy ? 'در حال ذخیره…' : 'تأیید اطلاعات و ذخیره'))),
      ])))));
}
