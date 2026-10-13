import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../domain.dart';
import '../finance_widgets.dart';
import '../repository.dart';
import '../receipts.dart';
import '../receipt_widgets.dart';
import '../platform/browser.dart';
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
  late Stream<QuerySnapshot<Map<String, dynamic>>> stream = widget.repo
      .monthQuery(month)
      .snapshots();
  void changeMonth(int step) => setState(() {
    month = DateTime(month.year, month.month + step);
    stream = widget.repo.monthQuery(month).snapshots();
  });
  Future<void> edit([DocumentSnapshot<Map<String, dynamic>>? doc]) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            TransactionEditor(repo: widget.repo, doc: doc, initialDate: month),
      );
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'حساب این ماه',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(color: forest),
      ),
      const SizedBox(height: 8),
      const Text('یک نگاه روشن به درآمد و هزینه‌هایت.'),
      const SizedBox(height: 20),
      Row(
        children: [
          IconButton(
            tooltip: 'ماه قبل',
            onPressed: () => changeMonth(-1),
            icon: const Icon(Icons.chevron_right),
          ),
          Expanded(
            child: Text(
              '${month.year} / ${month.month} · ماه میلادی',
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: 'ماه بعد',
            onPressed: () => changeMonth(1),
            icon: const Icon(Icons.chevron_left),
          ),
        ],
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('ثبت تراکنش'),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => ReceiptGallery(repo: widget.repo, month: month),
        ),
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('رسیدهای این ماه · عکس و PDF'),
      ),
      const SizedBox(height: 24),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return paper(Text(errorText(snapshot.error!)));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = [...snapshot.data!.docs]
            ..sort(
              (a, b) =>
                  ((b.data()['date'] as Timestamp?)?.millisecondsSinceEpoch ??
                          0)
                      .compareTo(
                        (a.data()['date'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0,
                      ),
            );
          final visible = docs
              .where((doc) => doc.data()['currency'] == 'EUR')
              .toList();
          return FinanceOverview(
            items: visible.map((doc) {
              final data = doc.data();
              return FinanceItem(
                id: doc.id,
                category: data['category'] as String? ?? 'سایر',
                cents: data['cents'] as int? ?? 0,
                income: data['kind'] == 'income',
                date: (data['date'] as Timestamp?)?.toDate() ?? month,
                note: data['note'] as String? ?? '',
                receiptCount: (data['receiptIds'] as List?)?.length ?? 0,
              );
            }).toList(),
            onEdit: (id) => edit(visible.firstWhere((doc) => doc.id == id)),
            onDelete: (id) async {
              if (!await confirmDelete(context)) return;
              try {
                await widget.repo.deleteTransaction(id);
              } catch (e) {
                if (mounted) notice(context, errorText(e));
              }
            },
          );
        },
      ),
    ],
  );
}

class TransactionEditor extends StatefulWidget {
  const TransactionEditor({
    super.key,
    required this.repo,
    required this.initialDate,
    this.doc,
  });
  final PersonalRepository repo;
  final DateTime initialDate;
  final DocumentSnapshot<Map<String, dynamic>>? doc;
  @override
  State<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends State<TransactionEditor> {
  late final id =
      widget.doc?.id ?? widget.repo.collection('transactions').doc().id;
  final transcript = TextEditingController();
  late final amount = TextEditingController(
    text: widget.doc == null
        ? ''
        : ((widget.doc!.data()!['cents'] as int) / 100).toStringAsFixed(2),
  );
  late final note = TextEditingController(
    text: widget.doc?.data()?['note'] as String? ?? '',
  );
  late String category = widget.doc?.data()?['category'] as String? ?? 'سایر';
  late TransactionKind kind = widget.doc?.data()?['kind'] == 'income'
      ? TransactionKind.income
      : TransactionKind.expense;
  late DateTime date =
      (widget.doc?.data()?['date'] as Timestamp?)?.toDate() ??
      (widget.initialDate.year == DateTime.now().year &&
              widget.initialDate.month == DateTime.now().month
          ? DateTime.now()
          : widget.initialDate);
  bool busy = false, recording = false, voiceExpanded = false;
  String? error, receiptLoadError;
  bool pickingPhoto = false, loadingReceipts = false;
  final photos = <ReceiptPhoto>[];
  final pendingPhotoIds = <String>{}, removedPhotoIds = <String>{};
  @override
  void initState() {
    super.initState();
    if (widget.doc != null) loadPhotos();
  }

  Future<void> loadPhotos() async {
    setState(() {
      loadingReceipts = true;
      receiptLoadError = null;
    });
    try {
      final loaded = await widget.repo.transactionReceipts(widget.doc!.data()!);
      if (mounted)
        setState(() {
          photos.clear();
          photos.addAll(loaded);
        });
    } catch (e) {
      if (mounted) setState(() => receiptLoadError = errorText(e));
    } finally {
      if (mounted) setState(() => loadingReceipts = false);
    }
  }

  Future<void> pickPhoto(bool camera) async {
    if (busy || recording || pickingPhoto || photos.length >= 3) return;
    setState(() {
      pickingPhoto = true;
      error = null;
    });
    try {
      final raw = await BrowserTools.pickReceipt(camera: camera);
      if (!mounted || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['error'] != null) {
        setState(
          () => error = switch (data['error']) {
            'image-format' =>
              'این عکس قابل خواندن نیست؛ JPEG یا PNG انتخاب کن. اگر HEIC باز نشد، از رسید اسکرین‌شات بگیر.',
            'image-too-large' =>
              'عکس خیلی بزرگ است؛ عکس کوچک‌تر یا اسکرین‌شات انتخاب کن.',
            'image-too-detailed' =>
              'عکس به اندازهٔ مناسب نرسید؛ اطراف رسید را برش بده و دوباره انتخاب کن.',
            _ => 'عکس آماده نشد؛ دوباره انتخاب کن.',
          },
        );
        return;
      }
      final photoId = widget.repo.collection('receipts').doc().id;
      final photo = ReceiptPhoto.fromMap(photoId, data);
      setState(() {
        photos.add(photo);
        pendingPhotoIds.add(photoId);
      });
    } catch (_) {
      if (mounted) setState(() => error = 'عکس اضافه نشد؛ دوباره امتحان کن.');
    } finally {
      if (mounted) setState(() => pickingPhoto = false);
    }
  }

  @override
  void dispose() {
    transcript.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  void suggest() {
    final suggestion = suggestTransaction(transcript.text);
    if (suggestion == null) {
      setState(
        () => error = 'مبلغ یورو تشخیص داده نشد؛ مبلغ و دسته را دستی وارد کن.',
      );
      return;
    }
    setState(() {
      amount.text = (suggestion.cents / 100).toStringAsFixed(2);
      category = suggestion.category;
      kind = suggestion.kind;
      note.text = transcript.text;
      error =
          'این فقط یک پیشنهاد است؛ مبلغ، نوع و دسته را قبل از ذخیره بررسی کن.';
    });
  }

  Future<void> save() async {
    if (busy ||
        recording ||
        pickingPhoto ||
        loadingReceipts ||
        receiptLoadError != null)
      return;
    final cents = parseCents(amount.text);
    if (cents == null || note.text.length > 2000) {
      setState(
        () => error =
            'مبلغ مثبت با حداکثر دو رقم اعشار و توضیح تا ۲۰۰۰ کاراکتر وارد کن.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repo.saveTransaction(
        id,
        {
          'cents': cents,
          'kind': kind.name,
          'currency': 'EUR',
          'category': category,
          'note': note.text.trim(),
          'date': Timestamp.fromDate(date),
          'month': '${date.year}-${date.month.toString().padLeft(2, '0')}',
          'createdAt':
              widget.doc?.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        added: photos
            .where((photo) => pendingPhotoIds.contains(photo.id))
            .toList(),
        removed: removedPhotoIds.toList(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && !recording && !pickingPhoto,
    child: Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ثبت مالی',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'بستن',
                    onPressed: busy || recording || pickingPhoto
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'مبلغ و دسته را انتخاب کن؛ توضیح اختیاری است.',
                style: TextStyle(color: mutedInk),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amount,
                enabled: !busy && !pickingPhoto,
                autofocus: widget.doc == null,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'مبلغ',
                  hintText: '0.00',
                  suffixText: '€',
                  helperText: 'به یورو · مثلاً ۱۲٫۵۰',
                ),
              ),
              const SizedBox(height: 20),
              SegmentedButton<TransactionKind>(
                segments: const [
                  ButtonSegment(
                    value: TransactionKind.expense,
                    label: Text('هزینه'),
                  ),
                  ButtonSegment(
                    value: TransactionKind.income,
                    label: Text('درآمد'),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: busy
                    ? null
                    : (values) => setState(() => kind = values.first),
              ),
              const SizedBox(height: 20),
              const Text('دسته', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: ['غذا', 'رفت‌وآمد', 'خرید', 'خانه', 'حقوق', 'سایر']
                    .map(
                      (value) => ChoiceChip(
                        label: Text(value),
                        avatar: Icon(categoryIcon(value), size: 20),
                        selected: category == value,
                        onSelected: busy
                            ? null
                            : (_) => setState(() => category = value),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (selected != null && mounted)
                          setState(() => date = selected);
                      },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(dateLabel(date)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                enabled: !busy && !pickingPhoto,
                maxLength: 2000,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'توضیح (اختیاری)',
                  hintText: 'مثلاً ناهار با دوستان',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'رسیدها (اختیاری)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'تا ۳ عکس فشرده، همگام در حساب تو. افزودن یا حذف با دکمهٔ ذخیره ثبت می‌شود.',
                style: TextStyle(fontSize: 14, color: mutedInk),
              ),
              const SizedBox(height: 12),
              if (loadingReceipts) const LinearProgressIndicator(),
              if (receiptLoadError != null) ...[
                Text(receiptLoadError!),
                TextButton(
                  onPressed: loadPhotos,
                  child: const Text('بارگذاری دوبارهٔ رسیدها'),
                ),
              ],
              for (final photo in photos)
                ReceiptTile(
                  photo: photo,
                  enabled: !busy && !pickingPhoto && !recording,
                  onRemove: () => setState(() {
                    photos.removeWhere((item) => item.id == photo.id);
                    pendingPhotoIds.remove(photo.id);
                    // A timed-out save may already have committed this image.
                    removedPhotoIds.add(photo.id);
                  }),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        busy ||
                            recording ||
                            pickingPhoto ||
                            loadingReceipts ||
                            receiptLoadError != null ||
                            photos.length >= 3
                        ? null
                        : () => pickPhoto(true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('عکس گرفتن'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        busy ||
                            recording ||
                            pickingPhoto ||
                            loadingReceipts ||
                            receiptLoadError != null ||
                            photos.length >= 3
                        ? null
                        : () => pickPhoto(false),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('انتخاب عکس'),
                  ),
                ],
              ),
              if (pickingPhoto)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('آماده‌سازی عکس…'),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: busy || recording || pickingPhoto
                    ? null
                    : () => setState(() => voiceExpanded = !voiceExpanded),
                icon: Icon(voiceExpanded ? Icons.expand_less : Icons.mic_none),
                label: Text(
                  voiceExpanded
                      ? 'بستن ورودی صوتی'
                      : 'ورود با جمله یا صدا (اختیاری)',
                ),
              ),
              if (voiceExpanded) ...[
                const Text(
                  'یک جمله بگو یا بنویس؛ مبلغ پیشنهادی را قبل از ذخیره بررسی کن.',
                  style: TextStyle(fontSize: 15, color: mutedInk),
                ),
                VoiceComposer(
                  controller: transcript,
                  enabled: !busy && !pickingPhoto,
                  audioKey: '',
                  transcriptionOnly: true,
                  compact: true,
                  onAudio: (_) {},
                  onBusy: (value) => setState(() => recording = value),
                ),
                TextField(
                  controller: transcript,
                  enabled: !busy && !recording && !pickingPhoto,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'جمله مالی',
                    hintText: 'دوازده یورو برای ناهار خرج کردم',
                  ),
                ),
                TextButton(
                  onPressed: busy || recording || pickingPhoto ? null : suggest,
                  child: const Text('پیشنهاد مبلغ و دسته'),
                ),
              ],
              if (error != null)
                Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed:
                    busy ||
                        recording ||
                        pickingPhoto ||
                        loadingReceipts ||
                        receiptLoadError != null
                    ? null
                    : save,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(busy ? 'در حال ذخیره…' : 'تأیید اطلاعات و ذخیره'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
