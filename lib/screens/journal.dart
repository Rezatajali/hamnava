import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../platform/browser.dart';
import '../repository.dart';
import '../voice_composer.dart';
import '../widgets.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, required this.repo});
  final PersonalRepository repo;
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}
class _JournalScreenState extends State<JournalScreen> {
  int limit = 30;
  String search = '';
  late Stream<QuerySnapshot<Map<String, dynamic>>> stream = widget.repo.journalQuery(limit).snapshots();
  Future<void> edit([DocumentSnapshot<Map<String, dynamic>>? doc]) => showDialog<void>(
    context: context, barrierDismissible: false, builder: (_) => JournalEditor(repo: widget.repo, doc: doc));
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
    Text('امروزت چطور گذشت؟', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: forest)),
    const SizedBox(height: 8), const Text('اینجا لازم نیست کلماتت بی‌نقص باشند.'), const SizedBox(height: 24),
    paper(Column(children: [
      const Icon(Icons.spa_outlined, color: copper, size: 42), const SizedBox(height: 16),
      const Text('کمی مکث. یک نفس. از روزت بگو.', style: TextStyle(fontSize: 18)), const SizedBox(height: 20),
      FilledButton.icon(onPressed: () => edit(), icon: const Icon(Icons.mic_none),
        label: const Padding(padding: EdgeInsets.all(12), child: Text('یادداشت تازه'))),
    ]), color: const Color(0xffeee8dc)),
    TextField(decoration: const InputDecoration(labelText: 'جستجو در یادداشت‌ها', prefixIcon: Icon(Icons.search)),
      onChanged: (value) => setState(() => search = value.trim().toLowerCase())),
    const SizedBox(height: 24),
    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: stream, builder: (context, snapshot) {
      if (snapshot.hasError) return paper(Text(errorText(snapshot.error!)));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final all = snapshot.data!.docs;
      final docs = all.where((doc) => '${doc.data()['title']} ${doc.data()['text']} ${doc.data()['tags']}'.toLowerCase().contains(search)).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (docs.isEmpty) paper(Text(search.isEmpty ? 'اولین یادداشتت را با صدا یا متن ثبت کن.' : 'یادداشتی پیدا نشد. برای جستجوی نوشته‌های قدیمی‌تر، نمایش بیشتر را بزن.')),
        for (final doc in docs) entryCard(doc),
        if (all.length >= limit) OutlinedButton(onPressed: () => setState(() {
          limit += 30; stream = widget.repo.journalQuery(limit).snapshots();
        }), child: const Text('نمایش بیشتر')),
      ]);
    }),
  ]);
  Widget entryCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    final text = data['text'] as String? ?? '';
    final audioKey = data['audioKey'] as String? ?? '';
    return paper(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(date == null ? 'در انتظار ثبت…' : dateLabel(date), style: const TextStyle(color: copper, fontSize: 12))),
        Text(data['mood'] as String? ?? ''),
      ]),
      const SizedBox(height: 12), Text(data['title'] as String? ?? 'یادداشت روزانه', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12), if (text.isNotEmpty) SelectableText(text, style: const TextStyle(height: 1.9)),
      if ((data['tags'] as String? ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(data['tags'], style: const TextStyle(color: forest))),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (text.isNotEmpty) TextButton.icon(onPressed: () async {
          try { if (!await BrowserTools.speak(text, data['locale'] as String? ?? 'fa-IR') && mounted) notice(context, 'صدای این زبان روی دستگاه در دسترس نیست.'); }
          catch (_) { if (mounted) notice(context, 'خواندن متن در دسترس نیست.'); }
        }, icon: const Icon(Icons.volume_up_outlined), label: const Text('شنیدن متن')),
        if (audioKey.isNotEmpty) TextButton.icon(onPressed: () async {
          try { if (!await BrowserTools.play(audioKey) && mounted) notice(context, 'فایل صوتی در این مرورگر موجود نیست؛ ممکن است روی دستگاه دیگری ضبط شده باشد.'); }
          catch (_) { if (mounted) notice(context, 'فایل صوتی در دسترس نیست.'); }
        }, icon: const Icon(Icons.play_circle_outline), label: const Text('صدای ضبط‌شده')),
        if (audioKey.isNotEmpty) IconButton(tooltip: 'دانلود فایل صوتی', onPressed: () async {
          try { if (!await BrowserTools.downloadAudio(audioKey) && mounted) notice(context, 'فایل صوتی در این مرورگر موجود نیست.'); }
          catch (_) { if (mounted) notice(context, 'دانلود فایل انجام نشد.'); }
        }, icon: const Icon(Icons.download_outlined)),
        IconButton(tooltip: 'توقف پخش', onPressed: BrowserTools.stopPlayback, icon: const Icon(Icons.stop_circle_outlined)),
        IconButton(tooltip: 'ویرایش', onPressed: () => edit(doc), icon: const Icon(Icons.edit_outlined)),
        IconButton(tooltip: 'حذف', onPressed: () async {
          if (!await confirmDelete(context)) return;
          try {
            await widget.repo.delete('journal', doc.id);
            if (audioKey.isNotEmpty) { try { await BrowserTools.removeAudio(audioKey); } catch (_) {} }
          } catch (e) { if (mounted) notice(context, errorText(e)); }
        }, icon: const Icon(Icons.delete_outline)),
      ]),
    ]));
  }
}

class JournalEditor extends StatefulWidget {
  const JournalEditor({super.key, required this.repo, this.doc});
  final PersonalRepository repo;
  final DocumentSnapshot<Map<String, dynamic>>? doc;
  @override
  State<JournalEditor> createState() => _JournalEditorState();
}
class _JournalEditorState extends State<JournalEditor> {
  late final id = widget.doc?.id ?? widget.repo.collection('journal').doc().id;
  late final freshAudioKey = '${widget.repo.uid}/$id/${DateTime.now().microsecondsSinceEpoch}';
  late final title = TextEditingController(text: widget.doc?.data()?['title'] as String? ?? '');
  late final text = TextEditingController(text: widget.doc?.data()?['text'] as String? ?? BrowserTools.draft('hamnava-draft-${widget.repo.uid}'));
  late final tags = TextEditingController(text: widget.doc?.data()?['tags'] as String? ?? '');
  late String mood = widget.doc?.data()?['mood'] as String? ?? 'معمولی';
  late String audioKey = widget.doc?.data()?['audioKey'] as String? ?? '';
  bool busy = false, recording = false, committed = false;
  late String locale = widget.doc?.data()?['locale'] as String? ?? 'fa-IR';
  String? error;
  @override
  void initState() { super.initState(); text.addListener(saveDraft); }
  void saveDraft() { if (widget.doc == null) BrowserTools.setDraft('hamnava-draft-${widget.repo.uid}', text.text); }
  @override
  void dispose() {
    text.removeListener(saveDraft); title.dispose(); text.dispose(); tags.dispose();
    if (!committed && audioKey == freshAudioKey) { BrowserTools.removeAudio(audioKey).catchError((_) {}); }
    super.dispose();
  }
  Future<void> save() async {
    if (busy || recording) return;
    if (text.text.trim().isEmpty && audioKey.isEmpty) { setState(() => error = 'یک متن یا ضبط صوتی اضافه کن.'); return; }
    if (text.text.length > 50000 || title.text.length > 120 || tags.text.length > 300) { setState(() => error = 'عنوان تا ۱۲۰، متن تا ۵۰۰۰۰ و برچسب‌ها تا ۳۰۰ کاراکتر باشند.'); return; }
    setState(() { busy = true; error = null; });
    final previousAudio = widget.doc?.data()?['audioKey'] as String? ?? '';
    try {
      await widget.repo.saveJournal(id, {
        'title': title.text.trim().isEmpty ? 'یادداشت روزانه' : title.text.trim(),
        'text': text.text.trim(), 'tags': tags.text.trim(), 'mood': mood, 'audioKey': audioKey, 'locale': locale,
        'createdAt': widget.doc?.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      committed = true;
      if (widget.doc == null) BrowserTools.setDraft('hamnava-draft-${widget.repo.uid}', '');
      if (previousAudio.isNotEmpty && previousAudio != audioKey) { try { await BrowserTools.removeAudio(previousAudio); } catch (_) {} }
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) setState(() => error = errorText(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !recording && !busy,
    child: Dialog(insetPadding: const EdgeInsets.all(16), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620),
      child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: Text(widget.doc == null ? 'امروزت را بگو' : 'ویرایش یادداشت', style: Theme.of(context).textTheme.headlineSmall)),
          IconButton(tooltip: 'بستن', onPressed: recording || busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close))]),
        VoiceComposer(controller: text, enabled: !busy, onLocale: (value) => locale = value, audioKey: freshAudioKey, onAudio: (value) => setState(() => audioKey = value),
          onBusy: (value) => setState(() => recording = value)),
        if (audioKey.isNotEmpty) const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('فایل صوتی در همین مرورگر ذخیره شده است.', style: TextStyle(color: forest))),
        TextField(controller: title, enabled: !busy, maxLength: 120, decoration: const InputDecoration(labelText: 'عنوان (اختیاری)')),
        const SizedBox(height: 12), TextField(controller: text, enabled: !busy && !recording, minLines: 5, maxLines: 12,
          maxLength: 50000, decoration: const InputDecoration(labelText: 'متن قابل ویرایش')),
        const SizedBox(height: 12), TextField(controller: tags, enabled: !busy, maxLength: 300,
          decoration: const InputDecoration(labelText: 'برچسب‌ها؛ مثلاً کار، خانواده')),
        Wrap(spacing: 8, children: ['آرام', 'خوشحال', 'معمولی', 'خسته', 'غمگین'].map((value) => ChoiceChip(label: Text(value),
          selected: mood == value, onSelected: busy ? null : (_) => setState(() => mood = value))).toList()),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 16), FilledButton(onPressed: busy || recording ? null : save,
          child: Padding(padding: const EdgeInsets.all(12), child: Text(busy ? 'در حال ذخیره…' : 'ذخیره در دفترم'))),
      ])))));
}
