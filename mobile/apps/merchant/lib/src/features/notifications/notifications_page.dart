import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/widgets.dart';
import 'notification_repository.dart';

enum _InboxFilter { all, unread, reviews, deals, system }

class MerchantNotificationsPage extends ConsumerStatefulWidget {
  const MerchantNotificationsPage({
    super.key,
    required this.onOpenTab,
  });

  final void Function(int index) onOpenTab;

  @override
  ConsumerState<MerchantNotificationsPage> createState() =>
      _MerchantNotificationsPageState();
}

class _MerchantNotificationsPageState
    extends ConsumerState<MerchantNotificationsPage> {
  List<MerchantNotification> _items = const [];
  _InboxFilter _filter = _InboxFilter.all;
  bool _loading = true;
  bool _working = false;
  String? _error;

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  String _tr(String ar, String en) => _isArabic ? ar : en;

  int get _unread => _items.where((item) => !item.isRead).length;
  int get _read => _items.length - _unread;

  List<MerchantNotification> get _visible {
    return _items.where((item) {
      return switch (_filter) {
        _InboxFilter.all => true,
        _InboxFilter.unread => !item.isRead,
        _InboxFilter.reviews => item.type == 'review',
        _InboxFilter.deals => item.type == 'deal',
        _InboxFilter.system =>
          item.type == 'system' || item.type == 'general',
      };
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final language = _isArabic ? 'ar' : 'en';
      final result = await ref
          .read(merchantNotificationRepositoryProvider)
          .list(language: language);
      if (!mounted) return;
      setState(() => _items = result);
      ref.invalidate(merchantUnreadNotificationsProvider);
    } catch (error) {
      if (mounted) setState(() => _error = ApiFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Shop.paper,
      appBar: AppBar(
        backgroundColor: Shop.sign,
        foregroundColor: Colors.white,
        title: Text(_tr('الإشعارات', 'Notifications')),
        actions: [
          PopupMenuButton<String>(
            enabled: !_working && _items.isNotEmpty,
            tooltip: _tr('المزيد', 'More'),
            onSelected: (value) {
              if (value == 'read-all') _markAllRead();
              if (value == 'delete-read') _deleteRead();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'read-all',
                enabled: _unread > 0,
                child: Row(
                  children: [
                    const Icon(Icons.done_all_rounded),
                    const SizedBox(width: Gap.sm),
                    Text(_tr('تحديد الكل كمقروء', 'Mark all as read')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete-read',
                enabled: _read > 0,
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_outlined),
                    const SizedBox(width: Gap.sm),
                    Text(_tr('حذف المقروء', 'Delete read')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Loading();
    if (_error != null) {
      return ShopError(
        failure: ApiFailure(message: _error!),
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      color: Shop.sign,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
            sliver: SliverToBoxAdapter(child: _header()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
            sliver: SliverToBoxAdapter(child: _filters()),
          ),
          if (_visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ShopEmpty(
                title: _items.isEmpty
                    ? _tr('مفيش إشعارات لسه', 'No notifications yet')
                    : _tr('مفيش إشعارات في القسم ده', 'No notifications here'),
                hint: _items.isEmpty
                    ? _tr(
                        'التقييمات الجديدة وحالة عروضك وتحديثات حسابك هتظهر هنا.',
                        'New reviews, deal updates, and account alerts will appear here.',
                      )
                    : _tr(
                        'جرّب قسم تاني أو اسحب لتحديث القائمة.',
                        'Try another filter or pull to refresh.',
                      ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Gap.md,
                0,
                Gap.md,
                Gap.xl,
              ),
              sliver: SliverList.separated(
                itemCount: _visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
                itemBuilder: (context, index) {
                  final item = _visible[index];
                  return Dismissible(
                    key: ValueKey('merchant-notification-${item.id}'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDelete(),
                    onDismissed: (_) => _delete(item),
                    background: Container(
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                      decoration: BoxDecoration(
                        color: Shop.clay.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(Radii.card),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Shop.clay,
                      ),
                    ),
                    child: _NotificationCard(
                      notification: item,
                      isArabic: _isArabic,
                      onTap: () => _open(item),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Shop.sign,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Shop.sign.withValues(alpha: .12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr('مركز التنبيهات', 'Notification center'),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _unread == 0
                          ? _tr(
                              'أنت متابع كل جديد في نشاطك',
                              'You are all caught up',
                            )
                          : _tr(
                              'عندك $_unread إشعار محتاج تشوفه',
                              'You have $_unread unread notifications',
                            ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(
                  value: '${_items.length}',
                  label: _tr('الإجمالي', 'Total'),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _HeaderMetric(
                  value: '$_unread',
                  label: _tr('جديد', 'Unread'),
                  emphasized: _unread > 0,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _HeaderMetric(
                  value: '$_read',
                  label: _tr('تمت قراءته', 'Read'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    final filters = <(_InboxFilter, String, IconData)>[
      (_InboxFilter.all, _tr('الكل', 'All'), Icons.inbox_outlined),
      (
        _InboxFilter.unread,
        _tr('غير مقروء', 'Unread'),
        Icons.mark_email_unread_outlined,
      ),
      (_InboxFilter.reviews, _tr('تقييمات', 'Reviews'), Icons.star_outline),
      (_InboxFilter.deals, _tr('عروض', 'Deals'), Icons.local_offer_outlined),
      (
        _InboxFilter.system,
        _tr('النظام', 'System'),
        Icons.campaign_outlined,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < filters.length; i++) ...[
            if (i > 0) const SizedBox(width: Gap.sm),
            _FilterChip(
              label: filters[i].$2,
              icon: filters[i].$3,
              selected: _filter == filters[i].$1,
              onTap: () => setState(() => _filter = filters[i].$1),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _open(MerchantNotification item) async {
    if (!item.isRead) await _markRead(item);
    if (!mounted) return;

    final target = item.target ?? '';
    int? tab;
    if (target.contains('review')) {
      tab = 1;
    } else if (target.contains('deal') || target.contains('product')) {
      tab = 2;
    } else if (target.contains('analytic') || target.contains('insight')) {
      tab = 3;
    } else if (target.contains('business') || target.contains('profile')) {
      tab = 4;
    }

    if (tab != null) {
      Navigator.of(context).pop();
      widget.onOpenTab(tab);
    }
  }

  Future<void> _markRead(MerchantNotification item) async {
    if (item.isRead) return;
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index < 0) return;

    setState(() => _items[index] = item.copyWith(isRead: true));
    ref.invalidate(merchantUnreadNotificationsProvider);

    try {
      final updated = await ref.read(merchantNotificationRepositoryProvider).markRead(
            item.id,
            language: _isArabic ? 'ar' : 'en',
          );
      if (!mounted) return;
      final currentIndex = _items.indexWhere((entry) => entry.id == item.id);
      if (currentIndex >= 0) {
        setState(() => _items[currentIndex] = updated);
      }
    } catch (error) {
      if (!mounted) return;
      final rollbackIndex = _items.indexWhere((entry) => entry.id == item.id);
      if (rollbackIndex >= 0) setState(() => _items[rollbackIndex] = item);
      ref.invalidate(merchantUnreadNotificationsProvider);
      _showError(error);
    }
  }

  Future<void> _markAllRead() async {
    if (_unread == 0) return;
    final previous = _items;
    setState(() {
      _working = true;
      _items = _items.map((item) => item.copyWith(isRead: true)).toList();
    });
    ref.invalidate(merchantUnreadNotificationsProvider);

    try {
      await ref.read(merchantNotificationRepositoryProvider).markAllRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('اتعلمت كلها كمقروءة', 'All marked as read')),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _items = previous);
        ref.invalidate(merchantUnreadNotificationsProvider);
        _showError(error);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete(MerchantNotification item) async {
    final previous = _items;
    setState(() {
      _items = _items.where((entry) => entry.id != item.id).toList();
    });
    ref.invalidate(merchantUnreadNotificationsProvider);

    try {
      await ref.read(merchantNotificationRepositoryProvider).delete(item.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _items = previous);
      ref.invalidate(merchantUnreadNotificationsProvider);
      _showError(error);
    }
  }

  Future<void> _deleteRead() async {
    final readItems = _items.where((item) => item.isRead).toList();
    if (readItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Shop.surface,
        title: Text(_tr('حذف الإشعارات المقروءة؟', 'Delete read notifications?')),
        content: Text(
          _tr(
            'هيتم حذف ${readItems.length} إشعار نهائيًا.',
            '${readItems.length} notifications will be permanently deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Shop.clay),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final previous = _items;
    setState(() {
      _working = true;
      _items = _items.where((item) => !item.isRead).toList();
    });

    try {
      await ref
          .read(merchantNotificationRepositoryProvider)
          .deleteMany(readItems.map((item) => item.id));
    } catch (error) {
      if (mounted) {
        setState(() => _items = previous);
        _showError(error);
      }
    } finally {
      ref.invalidate(merchantUnreadNotificationsProvider);
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Shop.surface,
            title: Text(_tr('حذف الإشعار؟', 'Delete notification?')),
            content: Text(
              _tr(
                'مش هتقدر ترجعه بعد الحذف.',
                'You cannot restore it after deletion.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_tr('رجوع', 'Cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Shop.clay),
                onPressed: () => Navigator.pop(context, true),
                child: Text(_tr('حذف', 'Delete')),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ApiFailure.from(error).message)),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.value,
    required this.label,
    this.emphasized = false,
  });

  final String value;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: emphasized ? .16 : .08),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: MerchantTheme.figure(
              size: 20,
              color: emphasized ? Shop.brass : Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .68),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Shop.sign : Shop.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? Shop.sign : Shop.rule),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : Shop.inkSoft,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : Shop.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isArabic,
    required this.onTap,
  });

  final MerchantNotification notification;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, tone, labelAr, labelEn) = switch (notification.type) {
      'review' => (Icons.star_rounded, Shop.brass, 'تقييم', 'Review'),
      'deal' => (Icons.local_offer_rounded, Shop.clay, 'عرض', 'Deal'),
      'business' => (Icons.storefront_rounded, Shop.jade, 'النشاط', 'Business'),
      'system' => (Icons.settings_suggest_rounded, Shop.inkSoft, 'النظام', 'System'),
      _ => (Icons.notifications_rounded, Shop.sign, 'تنبيه', 'Alert'),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: notification.isRead ? Shop.surface : Shop.jadeWash,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: notification.isRead
                  ? Shop.rule
                  : Shop.jade.withValues(alpha: .28),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: tone, size: 21),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: notification.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Shop.jade,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: Gap.sm),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tone.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Text(
                            isArabic ? labelAr : labelEn,
                            style: TextStyle(
                              color: tone,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          timeAgo(notification.createdAt),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.chevron_left_rounded,
                          size: 17,
                          color: Shop.inkFaint,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
