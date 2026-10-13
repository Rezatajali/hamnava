import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../platform/browser.dart';
import '../repository.dart';
import '../widgets.dart';
import '../brand.dart';
import '../receipt_widgets.dart';
import 'journal.dart';
import 'finance.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});
  final User user;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int page = 0;
  bool exporting = false;
  bool exportingReceipts = false;
  late final repo = PersonalRepository(widget.user.uid);
  Future<void> export() async {
    setState(() => exporting = true);
    try {
      final data = await repo.exportAll();
      BrowserTools.download(const JsonEncoder.withIndent('  ').convert(data), 'hamnava-${dateLabel(DateTime.now()).replaceAll('/', '-')}.json');
      if (mounted) notice(context, 'خروجی نوشته‌ها، تراکنش‌ها و عکس‌های فشردهٔ رسید آماده شد؛ صداها را جداگانه دانلود کن.');
    } catch (e) { if (mounted) notice(context, errorText(e)); }
    finally { if (mounted) setState(() => exporting = false); }
  }
  Future<void> exportReceipts() async {
    setState(() => exportingReceipts = true);
    try {
      final photos = await repo.allReceipts();
      if (photos.isEmpty) { if (mounted) notice(context, 'هنوز رسیدی ذخیره نکرده‌ای.'); return; }
      await downloadReceiptPdf(photos, 'hamnava-all-receipts.pdf');
    } catch (e) { if (mounted) notice(context, errorText(e)); }
    finally { if (mounted) setState(() => exportingReceipts = false); }
  }
  Widget settings() => ListView(padding: const EdgeInsets.all(24), children: [
    const Text('نسخهٔ ۰٫۲ · ورود ماندگار، پوشهٔ روزانه و رسیدها', style: TextStyle(fontSize: 14, color: mutedInk)),
    const SizedBox(height: 12),
    Text('فضای شخصی تو', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 24),
    paper(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.user.email ?? '', textDirection: TextDirection.ltr), const SizedBox(height: 20),
      FilledButton.icon(onPressed: exporting || exportingReceipts ? null : export, icon: const Icon(Icons.download_outlined),
        label: Text(exporting ? 'آماده‌سازی خروجی…' : 'دانلود همه نوشته‌ها، تراکنش‌ها و رسیدها')),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: exporting || exportingReceipts ? null : exportReceipts,
        icon: const Icon(Icons.picture_as_pdf_outlined), label: Text(exportingReceipts ? 'ساخت PDF رسیدها…' : 'همهٔ رسیدها در یک PDF')),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: () async {
        try { await widget.user.sendEmailVerification(); if (mounted) notice(context, 'ایمیل تأیید ارسال شد.'); }
        catch (e) { if (mounted) notice(context, errorText(e)); }
      }, child: const Text('ارسال ایمیل تأیید حساب')),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: () async {
        try { await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.user.email!); if (mounted) notice(context, 'لینک تغییر رمز ارسال شد.'); }
        catch (e) { if (mounted) notice(context, errorText(e)); }
      }, child: const Text('تغییر رمز عبور')),
    ])),
    paper(const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('داده‌ها کجا می‌مانند؟', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 12), Text('نوشته‌ها، تراکنش‌ها و عکس‌های فشردهٔ رسید در حساب فایربیس تو ذخیره می‌شوند. فایل صوتی فقط در همین مرورگر ذخیره می‌شود و به دستگاه دیگر منتقل نمی‌شود. پاک‌کردن داده‌های مرورگر می‌تواند فایل‌های صوتی را حذف کند.', style: TextStyle(height: 1.9)),
      SizedBox(height: 12), Text('خواندن متن، صدای مصنوعی دستگاه است. ممکن است صدای فارسی نصب نباشد. تشخیص گفتار می‌تواند از اینترنت و سرویس مرورگر استفاده کند.', style: TextStyle(height: 1.9)),
    ])),
    const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('ورود روی این دستگاه می‌ماند. روی دستگاه مشترک، بعد از استفاده از حساب خارج شو.', style: TextStyle(fontSize: 14, color: mutedInk))),
    OutlinedButton.icon(onPressed: () async {
      BrowserTools.cancel(); BrowserTools.setDraft('hamnava-draft-${widget.user.uid}', '');
      try { await FirebaseAuth.instance.signOut(); } catch (e) { if (mounted) notice(context, errorText(e)); }
    }, icon: const Icon(Icons.logout), label: const Text('خروج از حساب')),
  ]);
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final content = IndexedStack(index: page, children: [
      JournalScreen(repo: repo), FinanceScreen(repo: repo), settings(),
    ]);
    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: const HamnavaWordmark(), actions: [
        if (wide) Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Center(child: Text(dateLabel(DateTime.now()), style: const TextStyle(fontSize: 15, color: forest)))),
      ]),
      body: SafeArea(child: wide ? Row(children: [
        NavigationRail(selectedIndex: page, onDestinationSelected: (value) => setState(() => page = value),
          labelType: NavigationRailLabelType.all, backgroundColor: Colors.transparent, destinations: const [
            NavigationRailDestination(icon: Icon(Icons.auto_stories_outlined), label: Text('ژورنال')),
            NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: Text('مالی')),
            NavigationRailDestination(icon: Icon(Icons.tune), label: Text('تنظیمات')),
          ]),
        Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: content))),
      ]) : content),
      bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: page,
        onDestinationSelected: (value) => setState(() => page = value), destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_stories_outlined), label: 'ژورنال'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'مالی'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'تنظیمات'),
        ]),
    );
  }
}
