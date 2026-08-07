import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';
import '../home/location_step.dart';
import 'onboarding_models.dart';

final onboardingProvider =
    FutureProvider.autoDispose<OnboardingState>((ref) async {
  final api = ref.watch(apiClientProvider);
  return OnboardingState.fromJson(await api.getJson('onboarding/'));
});

/// رحلة تجهيز النشاط.
///
/// لا تحفظ الشاشة أي حالة عن أين وصل التاجر. الخادم يحسب `next_action`
/// من البيانات الفعلية، والشاشة تفتح عليها. النتيجة أن الخروج والعودة —
/// أو التبديل بين الموبايل والويب — يكمل من نفس النقطة بلا مزامنة.
class OnboardingWizard extends ConsumerWidget {
  const OnboardingWizard({
    super.key,
    required this.onFinish,
    required this.onGoTo,
  });

  final VoidCallback onFinish;

  /// ينقل التاجر لتبويب داخل التطبيق. تُمرَّر من الصدفة لأن الرحلة
  /// تحلّ محلها ولا تُدفَع فوقها — فلا يوجد `pop` نعود به.
  final void Function(String target) onGoTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: Shop.paper,
      body: state.when(
        loading: () => const Loading(),
        error: (e, _) => ShopError(
          failure: ApiFailure.from(e),
          onRetry: () => ref.invalidate(onboardingProvider),
        ),
        data: (data) => _Body(
          data: data,
          onFinish: onFinish,
          onGoTo: onGoTo,
          onRefresh: () => ref.invalidate(onboardingProvider),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.data,
    required this.onFinish,
    required this.onGoTo,
    required this.onRefresh,
  });

  final OnboardingState data;
  final VoidCallback onFinish;
  final void Function(String) onGoTo;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      color: Shop.sign,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(data: data),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // الخطوة التالية أولًا وبكامل حجمها: قائمة من اثنتي عشرة
                // مهمة تشلّ القرار، وخطوة واحدة واضحة تُنجَز.
                _NextStep(
                  data: data,
                  onDone: onRefresh,
                  onFinish: onFinish,
                  onGoTo: onGoTo,
                ),

                const SizedBox(height: Gap.xl),
                const SectionTitle('باقي الخطوات'),
                for (final item in data.shopSteps)
                  _StepRow(item: item, dim: item.key == _actionKey(data)),

                const SizedBox(height: Gap.xl),
                OutlinedButton(
                  onPressed: onFinish,
                  child: const Text('كمّل بعدين — ادخل على لوحتي'),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'تقدر ترجع للتجهيز في أي وقت من الإعدادات.',
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Gap.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _actionKey(OnboardingState data) => switch (data.nextAction) {
        'add_logo' => 'logo_added',
        'add_cover' => 'cover_added',
        'add_location' => 'location_added',
        'add_working_hours' => 'working_hours_added',
        'add_contact' => 'contact_added',
        'add_product' => 'first_product',
        'add_deal' => 'first_deal',
        _ => '',
      };
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final OnboardingState data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: Shop.sign,
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'لنجهّز نشاطك',
              style: text.displaySmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              data.business?.nameAr ?? 'خطوة خطوة، ومش لازم تخلّصها كلها دلوقتي',
              style: const TextStyle(color: Color(0xFF9DB5AB), fontSize: 13.5),
            ),
            const SizedBox(height: Gap.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${data.progress}%',
                  style: MerchantTheme.figure(size: 40, color: Colors.white),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      data.remaining == 0
                          ? 'خلصت كل الخطوات'
                          : 'فاضل ${data.remaining} خطوات',
                      style: const TextStyle(
                        color: Color(0xFF9DB5AB),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: LinearProgressIndicator(
                value: data.progress / 100,
                minHeight: 7,
                backgroundColor: Shop.signSoft,
                color: Shop.brass,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة الخطوة الحالية — الجزء الوحيد الذي يطلب فعلًا.
class _NextStep extends ConsumerWidget {
  const _NextStep({
    required this.data,
    required this.onDone,
    required this.onFinish,
    required this.onGoTo,
  });

  final OnboardingState data;
  final VoidCallback onDone;
  final VoidCallback onFinish;
  final void Function(String) onGoTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = _specFor(data);

    if (spec == null) {
      return _AllDone(onFinish: onFinish);
    }

    return Container(
      decoration: BoxDecoration(
        color: Shop.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Shop.jade.withValues(alpha: 0.35), width: 1.5),
      ),
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(spec.icon, color: Shop.jade, size: 22),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  spec.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(spec.why, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Gap.lg),
          spec.build(context, ref, data, onDone, onGoTo),
        ],
      ),
    );
  }

  _StepSpec? _specFor(OnboardingState data) {
    // الخطوات خارج التطبيق (الدفع، مراجعة الإدارة) لها بطاقاتها الخاصة.
    switch (data.nextAction) {
      case 'select_plan':
        return const _StepSpec(
          title: 'اختار خطتك',
          why: 'الخطة بتحدد كام نشاط ومنتج تقدر تضيف.',
          icon: Icons.workspace_premium_outlined,
          external: 'اختيار الخطة بيتم من تطبيق الدليل أو من الويب.',
        );
      case 'create_business':
        return const _StepSpec(
          title: 'أنشئ نشاطك',
          why: 'بعدها تقدر تضيف منتجاتك وعروضك من هنا.',
          icon: Icons.storefront_outlined,
          external: 'إنشاء النشاط بيتم من الويب دلوقتي.',
        );
      case 'submit_payment':
        return const _StepSpec(
          title: 'ارفع بيانات الدفع',
          why: 'بعد ما الإدارة تراجعها، اشتراكك بيتفعّل.',
          icon: Icons.receipt_long_outlined,
          external: 'رفع بيانات الدفع بيتم من الويب.',
        );
      case 'await_admin_review':
        return const _StepSpec(
          title: 'طلبك تحت المراجعة',
          why: 'هنبعتلك إشعار أول ما يتفعّل. مفيش حاجة مطلوبة منك دلوقتي.',
          icon: Icons.hourglass_empty,
          waiting: true,
        );
      case 'add_location':
        return const _StepSpec(
          title: 'حدد موقع المحل',
          why: 'من غير موقع، محلك مش هيظهر على الخريطة ولا لما حد يدوّر '
              'على أقرب مكان ليه.',
          icon: Icons.place_outlined,
          kind: _StepKind.location,
        );
      case 'add_logo':
        return const _StepSpec(
          title: 'ارفع شعار المحل',
          why: 'الشعار بيظهر جنب اسمك في نتايج البحث.',
          icon: Icons.image_outlined,
          kind: _StepKind.goTo,
          target: 'shop',
          cta: 'افتح بيانات النشاط',
        );
      case 'add_cover':
        return const _StepSpec(
          title: 'ضيف صورة غلاف',
          why: 'الغلاف أول حاجة الزبون بيشوفها في صفحة محلك.',
          icon: Icons.panorama_outlined,
          kind: _StepKind.goTo,
          target: 'shop',
          cta: 'افتح بيانات النشاط',
        );
      case 'add_working_hours':
        return const _StepSpec(
          title: 'اكتب مواعيد العمل',
          why: 'الزبون بيدوّر على اللي فاتح دلوقتي.',
          icon: Icons.schedule_outlined,
          kind: _StepKind.goTo,
          target: 'shop',
          cta: 'افتح بيانات النشاط',
        );
      case 'add_contact':
        return const _StepSpec(
          title: 'ضيف رقم للتواصل',
          why: 'التليفون والواتساب هما اللي بيوصلوا الزبون بيك.',
          icon: Icons.phone_outlined,
          kind: _StepKind.goTo,
          target: 'shop',
          cta: 'افتح بيانات النشاط',
        );
      case 'add_product':
        return const _StepSpec(
          title: 'ضيف أول منتج أو خدمة',
          why: 'المحلات اللي عندها منتجات بأسعار واضحة بتجيب زيارات أكتر.',
          icon: Icons.inventory_2_outlined,
          kind: _StepKind.goTo,
          target: 'products',
          cta: 'افتح المنتجات',
        );
      case 'add_deal':
        return const _StepSpec(
          title: 'اعمل أول عرض',
          why: 'العرض بيحطّ محلك في صفحة العروض.',
          icon: Icons.local_offer_outlined,
          kind: _StepKind.goTo,
          target: 'deals',
          cta: 'افتح العروض',
        );
      default:
        return null;
    }
  }
}

enum _StepKind { location, goTo, info }

class _StepSpec {
  const _StepSpec({
    required this.title,
    required this.why,
    required this.icon,
    this.kind = _StepKind.info,
    this.target = '',
    this.cta = '',
    this.external = '',
    this.waiting = false,
  });

  final String title;
  final String why;
  final IconData icon;
  final _StepKind kind;
  final String target;
  final String cta;

  /// خطوة تُنجَز خارج التطبيق — نقولها صراحةً بدل زر يفشل.
  final String external;
  final bool waiting;

  Widget build(
    BuildContext context,
    WidgetRef ref,
    OnboardingState data,
    VoidCallback onDone,
    void Function(String) onGoTo,
  ) {
    if (waiting) {
      return const _Waiting();
    }

    if (external.isNotEmpty) {
      return _Elsewhere(message: external);
    }

    if (kind == _StepKind.location && data.business != null) {
      return LocationStep(
        shopId: data.business!.id,
        onSaved: onDone,
      );
    }

    return FilledButton(
      onPressed: () => onGoTo(target),
      child: Text(cta.isEmpty ? 'يلا نبدأ' : cta),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Shop.brassWash,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Shop.brass),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              'مفيش حاجة مطلوبة منك دلوقتي.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// خطوة تتم في مكان آخر. نقولها بوضوح بدل زر يقود إلى لا شيء.
class _Elsewhere extends StatelessWidget {
  const _Elsewhere({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Shop.paper,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: Shop.rule),
      ),
      child: Row(
        children: [
          const Icon(Icons.open_in_new, size: 18, color: Shop.inkSoft),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Shop.jadeWash,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Shop.jade.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, color: Shop.jade, size: 34),
          const SizedBox(height: Gap.md),
          Text(
            'نشاطك جاهز',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'خلّصت كل الخطوات. محلك ظاهر للناس دلوقتي.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Gap.lg),
          FilledButton(
            onPressed: onFinish,
            child: const Text('ادخل على لوحتي'),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.item, required this.dim});

  final OnboardingItem item;

  /// الخطوة الحالية معروضة فوق بالفعل — نخفّها هنا حتى لا تتكرر بنفس الوزن.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final done = item.isDone;

    return Opacity(
      opacity: dim ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: done ? Shop.jade : Shop.inkFaint,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                item.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: done ? Shop.inkSoft : Shop.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: Shop.inkFaint,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
