import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'platform/browser.dart';
import 'widgets.dart';

class VoiceComposer extends StatefulWidget {
  const VoiceComposer({super.key, required this.controller, required this.audioKey,
    required this.onAudio, this.transcriptionOnly = false, this.enabled = true, this.onLocale, this.onBusy});
  final TextEditingController controller;
  final String audioKey;
  final void Function(String) onAudio;
  final void Function(bool)? onBusy;
  final bool transcriptionOnly;
  final bool enabled;
  final void Function(String)? onLocale;
  @override
  State<VoiceComposer> createState() => _VoiceComposerState();
}
class _VoiceComposerState extends State<VoiceComposer> {
  bool running = false, pending = false;
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
          'permission-denied' || 'not-allowed' => 'دسترسی میکروفون را در تنظیمات مرورگر فعال کن.',
          'language-not-supported' => 'تشخیص گفتار این زبان در مرورگر در دسترس نیست.',
          'speech-unavailable' || 'speech-failed' => 'تبدیل گفتار در این مرورگر در دسترس نیست؛ ضبط صوتی می‌تواند جداگانه ادامه پیدا کند.',
          'no-speech' => 'گفتاری تشخیص داده نشد؛ دوباره تلاش کن.',
          'network' => 'تبدیل گفتار به اتصال اینترنت نیاز دارد یا سرویس مرورگر پاسخ نمی‌دهد.',
          'audio-storage-failed' => 'فایل صوتی ذخیره نشد؛ متن را بررسی و ذخیره کن.',
          _ => 'قابلیت صوتی پاسخ نداد؛ تنظیمات مرورگر را بررسی کن.',
        });
        break;
      case 'speech-ended':
        if (widget.transcriptionOnly) { stop(); }
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
      final ok = await BrowserTools.start(widget.transcriptionOnly ? '' : widget.audioKey, locale, event);
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
  @override
  Widget build(BuildContext context) => Column(children: [
    const SizedBox(height: 12),
    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
      shape: BoxShape.circle, border: Border.all(color: copper.withValues(alpha: .3), width: 2)),
      child: SizedBox(width: 96, height: 96, child: FilledButton(
        style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: running ? copper : forest),
        onPressed: pending || !widget.enabled ? null : running ? stop : start,
        child: Icon(running ? Icons.stop_rounded : Icons.mic_none_rounded, size: 40)))),
    const SizedBox(height: 12),
    Text(pending ? 'کمی صبر کن…' : running ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} · توقف ضبط' : 'برای گفتن، لمس کن'),
    if (running) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(color: copper)),
    if (interim.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(interim, style: const TextStyle(color: Colors.grey))),
    if (status.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(status, textAlign: TextAlign.center)),
    DropdownButton<String>(value: locale, onChanged: running || pending || !widget.enabled ? null : (value) { setState(() => locale = value!); widget.onLocale?.call(locale); },
      items: const [DropdownMenuItem(value: 'fa-IR', child: Text('گفتار فارسی')),
        DropdownMenuItem(value: 'de-DE', child: Text('گفتار آلمانی'))]),
    const Text('تشخیص گفتار ممکن است صدا را به سرویس مرورگر ارسال کند. پشتیبانی زبان به دستگاه بستگی دارد. هر ضبط حداکثر پنج دقیقه است.',
      style: TextStyle(fontSize: 11, height: 1.7), textAlign: TextAlign.center),
    const SizedBox(height: 18),
  ]);
}
