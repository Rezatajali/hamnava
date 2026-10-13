import 'dart:convert';
import 'package:flutter/material.dart';
import 'platform/browser.dart';
import 'receipts.dart';
import 'repository.dart';
import 'widgets.dart';

Future<void> downloadReceiptPdf(
  List<ReceiptPhoto> photos,
  String filename,
) async {
  final bytes = await receiptPdf(photos);
  BrowserTools.downloadBinary(base64Encode(bytes), filename, 'application/pdf');
}

class ReceiptTile extends StatelessWidget {
  const ReceiptTile({
    super.key,
    required this.photo,
    this.onRemove,
    this.enabled = true,
  });
  final ReceiptPhoto photo;
  final VoidCallback? onRemove;
  final bool enabled;
  void showPhoto(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(photo.name, maxLines: 2),
                ),
              ),
              IconButton(
                tooltip: 'بستن عکس',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Flexible(
            child: InteractiveViewer(
              child: Image.memory(
                photo.imageBytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Text('این عکس قابل نمایش نیست.'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xfff6f2e9),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: enabled ? () => showPhoto(context) : null,
              child: Semantics(
                button: true,
                label: 'مشاهدهٔ ${photo.name}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    photo.imageBytes,
                    width: 64,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 64,
                      height: 80,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    photo.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${photo.format} · ${(photo.bytes / 1024).ceil()} KB',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 14, color: mutedInk),
                  ),
                  if (photo.createdAt != null)
                    Text(
                      dateLabel(photo.createdAt!),
                      style: const TextStyle(fontSize: 14, color: mutedInk),
                    ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'حذف رسید',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: enabled ? () => showPhoto(context) : null,
              icon: const Icon(Icons.zoom_in),
              label: const Text('دیدن'),
            ),
            TextButton.icon(
              onPressed: enabled
                  ? () => BrowserTools.downloadBinary(
                      photo.image.split(',').last,
                      'receipt-${photo.id}.jpg',
                      'image/jpeg',
                    )
                  : null,
              icon: const Icon(Icons.download_outlined),
              label: const Text('عکس'),
            ),
            _SinglePdfButton(photo: photo, enabled: enabled),
          ],
        ),
      ],
    ),
  );
}

class _SinglePdfButton extends StatefulWidget {
  const _SinglePdfButton({required this.photo, required this.enabled});
  final ReceiptPhoto photo;
  final bool enabled;
  @override
  State<_SinglePdfButton> createState() => _SinglePdfButtonState();
}

class _SinglePdfButtonState extends State<_SinglePdfButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: busy || !widget.enabled
        ? null
        : () async {
            setState(() => busy = true);
            try {
              await downloadReceiptPdf([
                widget.photo,
              ], 'receipt-${widget.photo.id}.pdf');
            } catch (_) {
              if (mounted)
                notice(context, 'ساخت PDF انجام نشد؛ عکس رسید را دانلود کن.');
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
    icon: const Icon(Icons.picture_as_pdf_outlined),
    label: Text(busy ? 'آماده‌سازی…' : 'PDF'),
  );
}

class ReceiptGallery extends StatefulWidget {
  const ReceiptGallery({super.key, required this.repo, required this.month});
  final PersonalRepository repo;
  final DateTime month;
  @override
  State<ReceiptGallery> createState() => _ReceiptGalleryState();
}

class _ReceiptGalleryState extends State<ReceiptGallery> {
  late Future<List<ReceiptPhoto>> photos = widget.repo.monthReceipts(
    widget.month,
  );
  bool exporting = false;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'رسیدهای ${widget.month.year}/${widget.month.month}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'بستن رسیدها',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'عکس‌های فشرده در حساب خودت ذخیره و بین دستگاه‌ها همگام می‌شوند.',
              style: TextStyle(fontSize: 15, color: mutedInk),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<ReceiptPhoto>>(
              future: photos,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Column(
                    children: [
                      Text(errorText(snapshot.error!)),
                      TextButton(
                        onPressed: () => setState(
                          () =>
                              photos = widget.repo.monthReceipts(widget.month),
                        ),
                        child: const Text('تلاش دوباره'),
                      ),
                    ],
                  );
                if (!snapshot.hasData)
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                final items = snapshot.data!;
                if (items.isEmpty)
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'رسیدی برای این ماه ذخیره نکرده‌ای؛ در فرم تراکنش عکس بگیر یا از گالری انتخاب کن.',
                    ),
                  );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: exporting
                          ? null
                          : () async {
                              setState(() => exporting = true);
                              try {
                                await downloadReceiptPdf(
                                  items,
                                  'hamnava-receipts-${widget.month.year}-${widget.month.month}.pdf',
                                );
                              } catch (_) {
                                if (mounted)
                                  notice(
                                    context,
                                    'ساخت PDF انجام نشد؛ عکس‌ها را جداگانه دانلود کن.',
                                  );
                              } finally {
                                if (mounted) setState(() => exporting = false);
                              }
                            },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        exporting
                            ? 'ساخت PDF…'
                            : 'همهٔ ${items.length} رسید در یک PDF',
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final photo in items) ReceiptTile(photo: photo),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
