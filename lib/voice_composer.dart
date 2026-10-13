import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'platform/browser.dart';
import 'widgets.dart';

class VoiceComposer extends StatefulWidget {
  const VoiceComposer({super.key, required this.controller, required this.audioKey,
    required this.onAudio, this.transcriptionOnly = false, this.compact = false, this.enabled = true, this.onLocale, this.onBusy});
  final TextEditingController controller;
  final String audioKey;
  final void Function(String) onAudio;
  final void Function(bool)? onBusy;
  final bool transcriptionOnly;
  final bool compact;
  final bool enabled;
  final void Function(String)? onLocale;
  @override
  State<VoiceComposer> createState() => _VoiceComposerState();
}
class _VoiceComposerState extends State<VoiceComposer> {
  bool running = false, pending = false;
  late bool dictating = widget.transcriptionOnly;
  int seconds = 0;
  String interim = '', status = '', locale = 'fa-IR';
  Timer? timer;
  @override
  void dispose() {
    timer?.cancel();
    if (running || pending) BrowserTools.cancel();
    super.dispose();
  }
  void event(String raw) {
    if (!mounted) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final value = data['value'] as String? ?? '';
    switch (data['type']) {
      case 'text':
        final previous = widget.controller.text.trimRight();
        widget.controller.text = '${previous.isEmpty ? '' : '$previous\n'}$value';
        widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length);
        break;
      case 'interim': setState(() => interim = value); break;
      case 'error':
        setState(() => status = switch (value) {
          'permission-denied' => 'اجازهٔ میکروفون رد شد؛ در Safari تنظیمات همین وب‌سایت را باز کن و Microphone را روی Allow بگذار.',
          'speech-permission-denied' || 'not-allowed' => 'اجازهٔ تبدیل گفتار از طرف مرورگر یا دستگاه صادر نشد؛ ضبط صدا یا میکروفون کیبورد آیفون را امتحان کن.',
          'insecure-context' => 'ضبط فقط از لینک امن https برنامه در دسترس است.',
          'recording-unavailable' => 'ضبط مستقیم در این مرورگر در دسترس نیست؛ از «افزودن فایل صوتی» استفاده کن.',
          'microphone-busy' || 'audio-capture' => 'میکروفون در اختیار برنامهٔ دیگری است یا در دسترس نیست؛ تماس یا ضبط دیگر را ببند و دوباره امتحان کن.',
          'microphone-missing' => 'میکروفون پیدا نشد؛ می‌توانی فایل صوتی اضافه کنی.',
          'recording-empty' => 'میکروفون فعال شد اما فایل صوتی تولید نشد. دوباره فقط حالت «ضبط صدا» را امتحان کن یا فایل Voice Memos آیفون را اضافه کن.',
          'service-not-allowed' => 'سرویس تبدیل گفتار اجازهٔ اجرا ندارد؛ ضبط صدا یا میکروفون کیبورد آیفون را امتحان کن.',
          'language-not-supported' => 'تشخیص گفتار این زبان در مرورگر در دسترس نیست.',
          'speech-unavailable' || 'speech-failed' => 'تبدیل گفتار در این مرورگر در دسترس نیست؛ ضبط صدا یا میکروفون کیبورد آیفون را امتحان کن.',
          'no-speech' => 'گفتاری تشخیص داده نشد؛ دوباره تلاش کن.',
          'network' => 'تبدیل گفتار به اتصال اینترنت نیاز دارد یا سرویس مرورگر پاسخ نمی‌دهد.',
          'audio-storage-failed' => 'فایل صوتی ذخیره نشد؛ متن را بررسی و ذخیره کن.',
          _ => 'قابلیت صوتی پاسخ نداد؛ تنظیمات مرورگر را بررسی کن.',
        });
        break;
      case 'speech-ended':
        if (dictating) { stop(); }
        else setState(() => status = 'تشخیص گفتار متوقف شد؛ ضبط صدا تا زدن توقف ادامه دارد.');
        break;
      case 'stopped':
        timer?.cancel();
        setState(() { running = false; pending = false; interim = ''; });
        widget.onBusy?.call(false);
        if (value.isNotEmpty) widget.onAudio(value);
        break;
    }
  }
  Future<void> start() async {
    if (running || pending || !widget.enabled) return;
    setState(() { pending = true; status = ''; interim = ''; seconds = 0; });
    widget.onBusy?.call(true);
    try {
      final ok = await BrowserTools.start(dictating ? '' : widget.audioKey, locale, event);
      if (!mounted) return;
      setState(() { pending = false; running = ok; });
      widget.onBusy?.call(ok);
      if (ok) {
        timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => seconds++); });
      } else if (status.isEmpty) setState(() => status = 'ضبط شروع نشد؛ ممکن است ضبط دیگری فعال باشد یا مرورگر پشتیبانی نکند.');
    } catch (_) {
      if (mounted) { setState(() { pending = false; status = 'میکروفون در دسترس نیست.'; }); widget.onBusy?.call(false); }
    }
  }
  Future<void> stop() async {
    if (!running || pending) return;
    setState(() => pending = true);
    try {
      final key = await BrowserTools.stop();
      if (key.isNotEmpty && mounted) widget.onAudio(key);
    } catch (_) { if (mounted) setState(() => status = 'توقف ضبط انجام نشد.'); }
    finally {
      timer?.cancel();
      if (mounted) { setState(() { running = false; pending = false; interim = ''; }); widget.onBusy?.call(false); }
    }
  }
  Future<void> importAudio() async {
    if (running || pending || !widget.enabled) return;
    setState(() { pending = true; status = ''; });
    widget.onBusy?.call(true);
    try {
      final raw = await BrowserTools.pickAudio(widget.audioKey);
      if (!mounted || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['key'] is String) {
        widget.onAudio(data['key'] as String);
        setState(() => status = 'فایل صوتی اضافه شد؛ فایل واردشده به متن تبدیل نمی‌شود.');
      } else {
        setState(() => status = switch (data['error']) {
          'audio-file-too-large' => 'فایل صوتی باید حداکثر ۲۰ مگابایت باشد.',
          'audio-file-format' => 'یک فایل صوتی مثل M4A یا MP3 انتخاب کن.',
          _ => 'فایل صوتی در مرورگر ذخیره نشد.',
        });
      }
    } catch (_) { if (mounted) setState(() => status = 'فایل صوتی اضافه نشد؛ دوباره امتحان کن.'); }
    finally { if (mounted) { setState(() => pending = false); widget.onBusy?.call(false); } }
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    if (!widget.transcriptionOnly) ...[
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final mode in [false, true]) ChoiceChip(
          label: Text(mode ? 'گفتار به متن' : 'ضبط صدا'), selected: dictating == mode,
          padding: const EdgeInsets.all(10),
          onSelected: running || pending || !widget.enabled ? null :
            (_) => setState(() { dictating = mode; status = ''; })),
      ]),
      const SizedBox(height: 12),
      Text(dictating ? 'در این حالت متن ثبت می‌شود؛ فایل صوتی ضبط نمی‌شود.' : 'در این حالت فایل صدا ضبط می‌شود؛ تبدیل به متن جداست.',
        style: const TextStyle(fontSize: 14, color: mutedInk), textAlign: TextAlign.center),
    ],
    const SizedBox(height: 12),
    if (widget.compact) FilledButton.icon(
      onPressed: pending || !widget.enabled ? null : running ? stop : start,
      icon: Icon(running ? Icons.stop_rounded : Icons.mic_none_rounded),
      label: Text(pending ? 'کمی صبر کن…' : running ? 'توقف گفتار' : 'شروع گفتار'),
    ) else Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
      shape: BoxShape.circle, border: Border.all(color: copper.withValues(alpha: .3), width: 2)),
      child: SizedBox(width: 96, height: 96, child: FilledButton(
        style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: running ? copper : forest),
        onPressed: pending || !widget.enabled ? null : running ? stop : start,
        child: Icon(running ? Icons.stop_rounded : Icons.mic_none_rounded, size: 40)))),
    const SizedBox(height: 12),
    Text(pending ? 'کمی صبر کن…' : running ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} · توقف ضبط' : dictating ? 'برای تبدیل گفتار به متن، لمس کن' : 'برای ضبط صدا، لمس کن'),
    if (running) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(color: copper)),
    if (interim.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(interim, style: const TextStyle(color: mutedInk))),
    if (status.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(status, textAlign: TextAlign.center)),
    if (!widget.transcriptionOnly) TextButton.icon(onPressed: running || pending || !widget.enabled ? null : importAudio,
      icon: const Icon(Icons.audio_file_outlined), label: const Text('افزودن فایل صوتی')),
    if (dictating && !BrowserTools.canRecognize) const Text('این مرورگر تبدیل گفتار ندارد. برای نوشتن با صدا، داخل کادر متن بزن و از میکروفون کیبورد آیفون استفاده کن.', style: TextStyle(fontSize: 14, color: mutedInk)),
    if (!dictating && !BrowserTools.canRecord) const Text('ضبط مستقیم در دسترس نیست؛ از افزودن فایل صوتی استفاده کن.', style: TextStyle(fontSize: 14, color: mutedInk)),
    if (dictating) ...[
      const Text('زبان گفتار', style: TextStyle(fontSize: 14, color: mutedInk)),
      Wrap(spacing: 8, children: [
        for (final language in const {'fa-IR': 'فارسی', 'de-DE': 'آلمانی'}.entries)
          ChoiceChip(label: Text(language.value), selected: locale == language.key,
            onSelected: running || pending || !widget.enabled ? null : (_) {
              setState(() => locale = language.key); widget.onLocale?.call(locale);
            }),
      ]),
    ],
    const Text('ضبط صدا محلی است و حداکثر پنج دقیقه طول می‌کشد. با پنهان‌شدن اپ متوقف می‌شود؛ بعد از توقف، یادداشت را ذخیره کن. تبدیل گفتار ممکن است صدا را به سرویس مرورگر ارسال کند؛ فارسی به دستگاه بستگی دارد.',
      style: TextStyle(fontSize: 14, height: 1.7), textAlign: TextAlign.center),
    const SizedBox(height: 18),
  ]);
}
