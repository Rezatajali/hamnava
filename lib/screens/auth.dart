import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets.dart';
import '../brand.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool signup = false, busy = false, hidden = true;
  String? error;
  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  Future<void> submit({bool reset = false}) async {
    if (busy) return;
    if (reset ? !email.text.trim().contains('@') : !form.currentState!.validate()) {
      if (reset) setState(() => error = 'اول ایمیلت را وارد کن.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final auth = FirebaseAuth.instance;
      if (reset) {
        await auth.sendPasswordResetEmail(email: email.text.trim());
        if (mounted) notice(context, 'اگر حسابی با این ایمیل وجود داشته باشد، لینک بازیابی ارسال می‌شود.');
      } else if (signup) {
        await auth.createUserWithEmailAndPassword(email: email.text.trim(), password: password.text);
      } else {
        await auth.signInWithEmailAndPassword(email: email.text.trim(), password: password.text);
      }
    } catch (e) { if (mounted) setState(() => error = errorText(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Center(child: HamnavaMark(size: 80)), const SizedBox(height: 16),
        Text('هم‌نوا', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall?.copyWith(color: forest)),
        const SizedBox(height: 8), const Text('روزت را بگو. خودت را بهتر بشنو.', textAlign: TextAlign.center),
        const SizedBox(height: 32),
        paper(Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(signup ? 'ساخت حساب' : 'خوش برگشتی', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          TextFormField(controller: email, enabled: !busy, textDirection: TextDirection.ltr,
            keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'ایمیل'),
            validator: (value) => value != null && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) ? null : 'ایمیل معتبر وارد کن.'),
          const SizedBox(height: 16),
          TextFormField(controller: password, enabled: !busy, obscureText: hidden,
            autofillHints: [signup ? AutofillHints.newPassword : AutofillHints.password],
            decoration: InputDecoration(labelText: 'رمز عبور', suffixIcon: IconButton(
              tooltip: hidden ? 'نمایش رمز' : 'پنهان کردن رمز', onPressed: () => setState(() => hidden = !hidden),
              icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
            onFieldSubmitted: (_) => submit(), validator: (value) => value != null && value.length >= 6 ? null : 'حداقل شش کاراکتر'),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 24),
          FilledButton(onPressed: busy ? null : () => submit(), child: Padding(padding: const EdgeInsets.all(12),
            child: Text(busy ? 'کمی صبر کن…' : signup ? 'ساخت حساب' : 'ورود'))),
          TextButton(onPressed: busy ? null : () => submit(reset: true), child: const Text('رمزم را فراموش کرده‌ام')),
          TextButton(onPressed: busy ? null : () => setState(() { signup = !signup; error = null; }),
            child: Text(signup ? 'حساب دارم؛ ورود' : 'حساب ندارم؛ ثبت‌نام')),
        ]))),
        const Text('متن‌ها، اطلاعات مالی و عکس رسیدها در حساب شخصی تو ذخیره می‌شوند. فایل‌های صوتی فقط در همین مرورگر می‌مانند.',
          textAlign: TextAlign.center, style: TextStyle(height: 1.8, fontSize: 14)),
      ])),
  ))));
}
