import 'package:dalil_core/dalil_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

/// تقرير فحص الملف قبل الحفظ.
class ImportReport {
  const ImportReport({
    required this.totalRows,
    required this.valid,
    required this.willCreate,
    required this.willUpdate,
    required this.errorCount,
    required this.errors,
    this.errorsTruncated = false,
  });

  final int totalRows;
  final int valid;
  final int willCreate;
  final int willUpdate;
  final int errorCount;
  final List<RowError> errors;
  final bool errorsTruncated;

  bool get isClean => errorCount == 0;
  bool get hasAnythingToImport => valid > 0;

  factory ImportReport.fromJson(Map<String, dynamic> json) => ImportReport(
        totalRows: (json['total_rows'] as num?)?.toInt() ?? 0,
        valid: (json['valid'] as num?)?.toInt() ?? 0,
        willCreate: (json['will_create'] as num?)?.toInt() ?? 0,
        willUpdate: (json['will_update'] as num?)?.toInt() ?? 0,
        errorCount: (json['error_count'] as num?)?.toInt() ?? 0,
        errorsTruncated: json['errors_truncated'] as bool? ?? false,
        errors: (json['errors'] is List ? json['errors'] as List : const [])
            .whereType<Map<String, dynamic>>()
            .map(RowError.fromJson)
            .toList(growable: false),
      );
}

class RowError {
  const RowError({
    required this.row,
    required this.name,
    required this.problems,
  });

  final int row;
  final String name;
  final List<(String field, String message)> problems;

  factory RowError.fromJson(Map<String, dynamic> json) => RowError(
        row: (json['row'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '—',
        problems: (json['problems'] is List
                ? json['problems'] as List
                : const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (p) => (
                p['field'] as String? ?? '',
                p['message'] as String? ?? '',
              ),
            )
            .toList(growable: false),
      );
}

/// شاشة الرفع الجماعي.
///
/// تاجر عنده ٢٠٠ منتج لن يكتبها واحدًا واحدًا. الرحلة هنا:
/// نزّل ملفك ← عدّله في إكسل ← ارفعه ← شوف التقرير ← اعتمد.
///
/// خطوة التقرير ليست زينة: ملف من ٢٠٠ صف فيه ثلاثة أخطاء لا يجوز أن
/// يدخل نصفه بصمت. التاجر يشوف ما سيحدث قبل أن يحدث.
class BulkImportPage extends ConsumerStatefulWidget {
  const BulkImportPage({super.key});

  @override
  ConsumerState<BulkImportPage> createState() => _BulkImportPageState();
}

class _BulkImportPageState extends ConsumerState<BulkImportPage> {
  XFile? _file;
  ImportReport? _report;
  bool _busy = false;
  String? _error;
  String? _done;

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(merchantActionsProvider).downloadProductsFile(
            ref.read(currentShopProvider)!.id,
          );
      if (mounted) {
        setState(() => _done = 'اتنزّل الملف. افتحه بإكسل وعدّل فيه.');
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFile() async {
    const type = XTypeGroup(
      label: 'Excel',
      extensions: ['xlsx', 'xlsm', 'csv'],
    );
    final picked = await openFile(acceptedTypeGroups: const [type]);
    if (picked == null) return;

    setState(() {
      _file = picked;
      _report = null;
      _error = null;
      _done = null;
    });
    await _check();
  }

  Future<void> _check() async {
    if (_file == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await _file!.readAsBytes();
      final json = await ref.read(merchantActionsProvider).checkProductsFile(
            shopId: ref.read(currentShopProvider)!.id,
            bytes: bytes,
            filename: _file!.name,
          );
      if (mounted) setState(() => _report = ImportReport.fromJson(json));
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _report = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commit({required bool skipInvalid}) async {
    if (_file == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await _file!.readAsBytes();
      final json = await ref.read(merchantActionsProvider).commitProductsFile(
            shopId: ref.read(currentShopProvider)!.id,
            bytes: bytes,
            filename: _file!.name,
            skipInvalid: skipInvalid,
          );
      final created = (json['created'] as num?)?.toInt() ?? 0;
      final updated = (json['updated'] as num?)?.toInt() ?? 0;
      final skipped = (json['skipped'] as num?)?.toInt() ?? 0;

      if (mounted) {
        setState(() {
          _report = null;
          _file = null;
          _done = 'تم. اتضاف $created منتج، واتعدّل $updated'
              '${skipped > 0 ? '، واتساب $skipped فيهم مشاكل' : ''}.';
        });
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Shop.sign,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'رفع منتجات بملف',
          style: text.titleMedium?.copyWith(color: Colors.white, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Gap.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: Shop.jadeWash,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: Shop.jade.withValues(alpha: 0.25)),
            ),
            child: Text(
              'عندك منتجات كتير؟ نزّل الملف، املاه في إكسل، وارفعه. '
              'الصور بتتضاف من التطبيق بعد كده.',
              style: text.bodyMedium?.copyWith(height: 1.8),
            ),
          ),

          const SizedBox(height: Gap.xl),
          _Step(
            number: '١',
            title: 'نزّل الملف',
            body: 'هيجيلك بمنتجاتك الحالية جواه. لو لسه مابدأتش، '
                'هتلاقي صف مثال تمشي عليه.',
            action: OutlinedButton.icon(
              onPressed: _busy ? null : _download,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('نزّل ملف المنتجات'),
            ),
          ),

          const SizedBox(height: Gap.lg),
          _Step(
            number: '٢',
            title: 'عدّل في إكسل',
            body: 'عمود "المعرّف" متغيّرهوش — هو اللي بيربط الصف بالمنتج. '
                'صف من غير معرّف = منتج جديد.',
          ),

          const SizedBox(height: Gap.lg),
          _Step(
            number: '٣',
            title: 'ارفعه',
            body: 'هنفحصه ونوريك هيحصل إيه قبل ما نحفظ أي حاجة.',
            action: OutlinedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(_file == null ? 'اختار الملف' : 'غيّر الملف'),
            ),
          ),

          if (_file != null) ...[
            const SizedBox(height: Gap.md),
            Row(
              children: [
                const Icon(Icons.description_outlined,
                    size: 16, color: Shop.inkSoft),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(_file!.name, style: text.bodySmall),
                ),
              ],
            ),
          ],

          if (_busy) ...[
            const SizedBox(height: Gap.lg),
            const Loading(),
          ],

          if (_error != null) ...[
            const SizedBox(height: Gap.lg),
            _Banner(text: _error!, tone: Shop.clay),
          ],

          if (_done != null) ...[
            const SizedBox(height: Gap.lg),
            _Banner(text: _done!, tone: Shop.jade),
          ],

          if (_report != null && !_busy) ...[
            const SizedBox(height: Gap.xl),
            _ReportView(
              report: _report!,
              onCommit: _commit,
              onRecheck: _check,
            ),
          ],

          const SizedBox(height: Gap.xl),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    this.action,
  });

  final String number;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Shop.sign,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
              if (action != null) ...[
                const SizedBox(height: Gap.sm),
                action!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({
    required this.report,
    required this.onCommit,
    required this.onRecheck,
  });

  final ImportReport report;
  final void Function({required bool skipInvalid}) onCommit;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('نتيجة الفحص'),
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: Shop.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: Shop.rule),
          ),
          child: Row(
            children: [
              _Tally(
                value: report.willCreate,
                label: 'هيتضاف',
                tone: Shop.jade,
              ),
              _Bar(),
              _Tally(
                value: report.willUpdate,
                label: 'هيتعدّل',
                tone: Shop.sign,
              ),
              _Bar(),
              _Tally(
                value: report.errorCount,
                label: 'فيه مشكلة',
                tone: report.isClean ? Shop.inkFaint : Shop.clay,
              ),
            ],
          ),
        ),

        if (!report.isClean) ...[
          const SizedBox(height: Gap.lg),
          Text('الصفوف اللي فيها مشاكل', style: MerchantTheme.eyebrow),
          const SizedBox(height: Gap.sm),
          for (final error in report.errors)
            Container(
              margin: const EdgeInsets.only(bottom: Gap.sm),
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: Shop.clayWash,
                borderRadius: BorderRadius.circular(Radii.control),
                border: Border(
                  right: BorderSide(color: Shop.clay, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'صف ${error.row} · ${error.name}',
                    style: text.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  for (final (field, message) in error.problems)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '$field: $message',
                        style: text.bodySmall?.copyWith(color: Shop.clay),
                      ),
                    ),
                ],
              ),
            ),
          if (report.errorsTruncated)
            Text(
              'وفيه أخطاء تانية مش معروضة. صلّح دول الأول.',
              style: text.bodySmall,
            ),
        ],

        const SizedBox(height: Gap.lg),

        if (report.isClean && report.hasAnythingToImport)
          FilledButton(
            onPressed: () => onCommit(skipInvalid: false),
            child: Text('اعتمد ${report.valid} منتج'),
          )
        else if (report.hasAnythingToImport) ...[
          // اختيار حقيقي بين طريقين، والقرار للتاجر لا لنا.
          FilledButton(
            onPressed: () => onCommit(skipInvalid: true),
            child: Text('استورد الـ${report.valid} السليمة وسيب الباقي'),
          ),
          const SizedBox(height: Gap.sm),
          OutlinedButton(
            onPressed: onRecheck,
            child: const Text('صلّحت الملف — افحص تاني'),
          ),
        ] else
          _Banner(
            text: 'مفيش ولا صف سليم في الملف. صلّح المشاكل وارفعه تاني.',
            tone: Shop.clay,
          ),
      ],
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({
    required this.value,
    required this.label,
    required this.tone,
  });

  final int value;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: MerchantTheme.figure(size: 26, color: tone)),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: Shop.rule);
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: tone, fontSize: 13, height: 1.7),
      ),
    );
  }
}
