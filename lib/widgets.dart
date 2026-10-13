import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const forest = Color(0xff244f43);
const copper = Color(0xffad7852);
const expenseInk = Color(0xff855433);
const mutedInk = Color(0xff58665e);

String errorText(Object error) {
  if (error is TimeoutException) return 'ذخیره هنوز از سرور تأیید نشده؛ اینترنت را بررسی کن و دوباره تلاش کن.';
  if (error is FirebaseException) {
    switch (error.code) {
      case 'invalid-email': return 'آدرس ایمیل معتبر وارد کن.';
      case 'weak-password': return 'رمز عبور حداقل شش کاراکتر باشد.';
      case 'email-already-in-use': return 'این ایمیل قبلاً ثبت شده؛ وارد حساب شو.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found': return 'ایمیل یا رمز عبور درست نیست.';
      case 'too-many-requests': return 'تلاش‌ها زیاد بوده؛ کمی بعد دوباره امتحان کن.';
      case 'permission-denied': return 'اجازه دسترسی صادر نشد؛ ورود به حساب و تنظیمات دسترسی را بررسی کن.';
      case 'unavailable':
      case 'network-request-failed': return 'اتصال برقرار نیست؛ اینترنت را بررسی کن.';
      case 'operation-not-allowed': return 'ورود با ایمیل در فایربیس هنوز فعال نشده است.';
      case 'requires-recent-login': return 'برای این کار باید دوباره وارد حساب شوی.';
    }
  }
  return 'این کار انجام نشد؛ دوباره تلاش کن.';
}

void notice(BuildContext context, String message) => ScaffoldMessenger.of(context)
  .showSnackBar(SnackBar(content: Text(message)));

Widget paper(Widget child, {Color? color}) => Card(elevation: 0, color: color ?? Colors.white,
  margin: const EdgeInsets.only(bottom: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
  child: Padding(padding: const EdgeInsets.all(24), child: child));

String dateLabel(DateTime date) => '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
String money(int cents, [String currency = 'EUR']) => '${(cents / 100).toStringAsFixed(2)} ${currency == 'EUR' ? '€' : currency}';

Future<bool> confirmDelete(BuildContext context) async => await showDialog<bool>(context: context,
  builder: (context) => AlertDialog(title: const Text('حذف این مورد؟'),
    content: const Text('این تغییر قابل برگشت نیست.'), actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
    ])) ?? false;
