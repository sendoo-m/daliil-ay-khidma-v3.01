import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';

/// ختم حالة. النص واللون يأتيان من [RecordStamp] فلا تتضارب التسميات
/// بين شاشة وأخرى.
class StampBadge extends StatelessWidget {
  const StampBadge(this.stamp, {super.key, this.dense = false});

  final RecordStamp stamp;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 10,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: stamp.wash,
        border: Border.all(color: stamp.color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(DalilRadii.control),
      ),
      child: Text(
        stamp.label,
        style: TextStyle(
          fontSize: dense ? 10.5 : 11.5,
          fontWeight: FontWeight.w600,
          color: stamp.color,
          height: 1.4,
        ),
      ),
    );
  }
}

/// **العنصر المميِّز للتطبيق: بطاقة القيد.**
///
/// كل سجل — نشاط، تقييم، موظف — يظهر كقيد في دفتر: مسلسل بخط أحادي
/// على الحافة، عمود حبري رفيع بلون الحالة، ثم المحتوى. الشكل واحد في
/// كل الشاشات، فيتعلم الموظف قراءته مرة واحدة.
class RegistryEntry extends StatefulWidget {
  const RegistryEntry({
    super.key,
    required this.serial,
    required this.title,
    required this.stamp,
    this.subtitle,
    this.meta = const [],
    this.actions = const [],
    this.onTap,
  });

  /// المسلسل — رقم السجل. يُعرض بخط أحادي على الحافة.
  final String serial;
  final String title;
  final String? subtitle;
  final RecordStamp stamp;

  /// أزواج (تسمية، قيمة) تظهر في سطر البيانات أسفل العنوان.
  final List<(String, String)> meta;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  State<RegistryEntry> createState() => _RegistryEntryState();
}

class _RegistryEntryState extends State<RegistryEntry> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DalilDuration.fast,
          decoration: BoxDecoration(
            color: _hovered ? DalilColors.paper : DalilColors.surface,
            border: const Border(
              bottom: BorderSide(color: DalilColors.rule),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // العمود الحبري: يحمل لون الحالة على طول القيد.
                Container(width: 3, color: widget.stamp.color),

                // المسلسل على الحافة.
                Container(
                  width: 62,
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    widget.serial,
                    style: AdminTheme.mono(
                      size: 12,
                      color: DalilColors.inkFaint,
                    ),
                  ),
                ),

                const VerticalDivider(width: 1),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DalilSpacing.md,
                      vertical: DalilSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: text.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: DalilSpacing.sm),
                            StampBadge(widget.stamp, dense: true),
                          ],
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: text.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (widget.meta.isNotEmpty) ...[
                          const SizedBox(height: DalilSpacing.sm),
                          Wrap(
                            spacing: DalilSpacing.md,
                            runSpacing: DalilSpacing.xs,
                            children: [
                              for (final (label, value) in widget.meta)
                                _MetaPair(label: label, value: value),
                            ],
                          ),
                        ],
                        if (widget.actions.isNotEmpty) ...[
                          const SizedBox(height: DalilSpacing.md),
                          Wrap(
                            spacing: DalilSpacing.sm,
                            runSpacing: DalilSpacing.sm,
                            children: widget.actions,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaPair extends StatelessWidget {
  const _MetaPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: DalilSpacing.xs),
        Text(value, style: AdminTheme.mono(size: 12)),
      ],
    );
  }
}

/// عنوان قسم مع خط شعري ممتد — بديل عن ترويسة البطاقة المعتادة.
class SectionRule extends StatelessWidget {
  const SectionRule(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label.toUpperCase(), style: AdminTheme.eyebrow),
        const SizedBox(width: DalilSpacing.md),
        const Expanded(child: Divider()),
        if (trailing != null) ...[
          const SizedBox(width: DalilSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

/// حالة فارغة. دعوة لفعل، لا اعتذار.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.hint,
    this.action,
  });

  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DalilSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 1, color: DalilColors.rule),
            const SizedBox(height: DalilSpacing.lg),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: DalilSpacing.xs),
              Text(
                hint!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: DalilSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// حالة خطأ. تقول ما حدث وما العمل — ولا تعتذر.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.failure, this.onRetry});

  final ApiFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DalilSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 2, color: DalilColors.stamp),
            const SizedBox(height: DalilSpacing.lg),
            Text(
              failure.message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (failure.isRetryable && onRetry != null) ...[
              const SizedBox(height: DalilSpacing.lg),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('أعد المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// حارس صلاحية: يبني الطفل فقط لو الصلاحية موجودة.
///
/// القاعدة في هذا التطبيق: لا يُعرض زر لا يملك الموظف صلاحيته. الخادم
/// يمنع على أي حال، لكن إظهار زر يفشل عند الضغط تجربة سيئة.
class Allowed extends StatelessWidget {
  const Allowed({
    super.key,
    required this.session,
    required this.permission,
    required this.child,
    this.fallback,
  });

  final AdminSession session;
  final String permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    if (session.can(permission)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
