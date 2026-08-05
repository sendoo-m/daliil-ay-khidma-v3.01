import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/widgets.dart';

/// شاشة العروض — قيد البناء.
///
/// نقول بوضوح إيه اللي جاي، مش "قريبًا". الوعد المبهم أسوأ من غيابه.
class DealsPage extends StatelessWidget {
  const DealsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: ShopEmpty(
        title: 'إدارة العروض',
        hint: 'الـAPI جاهز: إنشاء عرض، تحديد مدته، وتمديده قبل ما يخلص.\n'
            'الشاشة هي اللي فاضلة.',
        action: OutlinedButton(
          onPressed: () {},
          child: const Text('تمام'),
        ),
      ),
    );
  }
}
