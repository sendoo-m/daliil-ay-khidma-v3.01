import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../../catalog/presentation/catalog_detail_pages.dart';
import '../../directory/presentation/business_detail_page.dart';
import '../data/notification_repository.dart';

enum _NotificationFilter { all, unread, read }

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  List<AppNotification> _items = const [];
  var _filter = _NotificationFilter.all;
  var _loading = true;
  var _working = false;
  String? _error;

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode == 'ar';

  String _tr(String ar, String en) => _isArabic ? ar : en;

  int get _unreadCount => _items.where((item) => !item.isRead).length;
  int get _readCount => _items.length - _unreadCount;

  List<AppNotification> get _visibleItems => switch (_filter) {
        _NotificationFilter.unread =>
          _items.where((item) => !item.isRead).toList(growable: false),
        _NotificationFilter.read =>
          _items.where((item) => item.isRead).toList(growable: false),
        _NotificationFilter.all => _items,
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(notificationRepositoryProvider).list();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = ApiFailure.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surfaceMuted,
        appBar: AppBar(
          title: Text(_tr('الإشعارات', 'Notifications')),
          actions: [
            PopupMenuButton<String>(
              tooltip: _tr('المزيد', 'More'),
              enabled: !_working && _items.isNotEmpty,
              onSelected: (value) {
                if (value == 'read-all') _markAllRead();
                if (value == 'delete-read') _deleteRead();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'read-all',
                  enabled: _unreadCount > 0,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.done_all_rounded),
                    title: Text(_tr('تحديد الكل كمقروء', 'Mark all as read')),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete-read',
                  enabled: _readCount > 0,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_sweep_outlined),
                    title: Text(_tr('حذف الإشعارات المقروءة', 'Delete read notifications')),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _body(),
      );

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        title: _tr('تعذر تحميل الإشعارات', 'Could not load notifications'),
        message: _error!,
        actionLabel: _tr('إعادة المحاولة', 'Try again'),
        onAction: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            sliver: SliverToBoxAdapter(
              child: _NotificationsHeader(
                total: _items.length,
                unread: _unreadCount,
                read: _readCount,
                isArabic: _isArabic,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            sliver: SliverToBoxAdapter(child: _filters()),
          ),
          if (_visibleItems.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _MessageState(
                icon: _items.isEmpty
                    ? Icons.notifications_none_rounded
                    : Icons.filter_alt_off_outlined,
                title: _items.isEmpty
                    ? _tr('لا توجد إشعارات حتى الآن', 'No notifications yet')
                    : _tr('لا توجد نتائج في هذا القسم', 'No notifications in this filter'),
                message: _items.isEmpty
                    ? _tr(
                        'ستظهر هنا أحدث العروض والتحديثات المهمة لحسابك.',
                        'Important offers and account updates will appear here.',
                      )
                    : _tr(
                        'اختر قسمًا آخر أو اسحب لأسفل لتحديث القائمة.',
                        'Choose another filter or pull down to refresh.',
                      ),
                actionLabel: _tr('تحديث', 'Refresh'),
                onAction: _load,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList.separated(
                itemCount: _visibleItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _visibleItems[index];
                  return Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDelete(),
                    onDismissed: (_) => _delete(item),
                    background: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      alignment: AlignmentDirectional.centerEnd,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    child: _NotificationCard(
                      item: item,
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

  Widget _filters() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<_NotificationFilter>(
          segments: [
            ButtonSegment(
              value: _NotificationFilter.all,
              icon: const Icon(Icons.notifications_outlined),
              label: Text('${_tr('الكل', 'All')} (${_items.length})'),
            ),
            ButtonSegment(
              value: _NotificationFilter.unread,
              icon: const Icon(Icons.mark_email_unread_outlined),
              label: Text('${_tr('غير مقروءة', 'Unread')} ($_unreadCount)'),
            ),
            ButtonSegment(
              value: _NotificationFilter.read,
              icon: const Icon(Icons.drafts_outlined),
              label: Text('${_tr('مقروءة', 'Read')} ($_readCount)'),
            ),
          ],
          selected: {_filter},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            setState(() => _filter = selection.first);
          },
        ),
      );

  Future<bool> _confirmDelete() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_tr('حذف الإشعار؟', 'Delete notification?')),
          content: Text(
            _tr(
              'لن تتمكن من استعادته بعد الحذف.',
              'You will not be able to restore it after deletion.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_tr('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tr('حذف', 'Delete')),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _open(AppNotification item) async {
    if (!item.isRead) await _markRead(item);
    if (!mounted) return;

    Widget? destination;
    if (item.dealSlug != null) {
      destination = DealDetailPage(slug: item.dealSlug!);
    } else if (item.productSlug != null) {
      destination = ProductDetailPage(slug: item.productSlug!);
    } else if (item.businessSlug != null) {
      destination = BusinessDetailPage(slug: item.businessSlug!);
    }

    if (destination != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => destination!),
      );
    }
  }

  Future<void> _markRead(AppNotification item) async {
    final index = _items.indexWhere((element) => element.id == item.id);
    if (index < 0 || item.isRead) return;
    setState(() => _items[index] = item.copyWith(isRead: true));
    try {
      final updated =
          await ref.read(notificationRepositoryProvider).markRead(item.id);
      if (!mounted) return;
      final updatedIndex =
          _items.indexWhere((element) => element.id == item.id);
      if (updatedIndex >= 0) {
        setState(() => _items[updatedIndex] = updated);
      }
    } catch (error) {
      if (!mounted) return;
      final rollbackIndex =
          _items.indexWhere((element) => element.id == item.id);
      if (rollbackIndex >= 0) setState(() => _items[rollbackIndex] = item);
      _showError(error);
    }
  }

  Future<void> _markAllRead() async {
    final previous = _items;
    setState(() {
      _working = true;
      _items = _items.map((item) => item.copyWith(isRead: true)).toList();
    });
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('تمت قراءة كل الإشعارات', 'All notifications marked as read'))),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _items = previous);
        _showError(error);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete(AppNotification item) async {
    final previous = _items;
    setState(() => _items = _items.where((element) => element.id != item.id).toList());
    try {
      await ref.read(notificationRepositoryProvider).delete(item.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _items = previous);
      _showError(error);
    }
  }

  Future<void> _deleteRead() async {
    final readItems = _items.where((item) => item.isRead).toList();
    if (readItems.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('حذف الإشعارات المقروءة؟', 'Delete read notifications?')),
        content: Text(
          _tr(
            'سيتم حذف ${readItems.length} إشعارًا مقروءًا نهائيًا.',
            '${readItems.length} read notifications will be permanently deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
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
          .read(notificationRepositoryProvider)
          .deleteMany(readItems.map((item) => item.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('تم حذف الإشعارات المقروءة', 'Read notifications deleted'))),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _items = previous);
        _showError(error);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ApiFailure.message(error))),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.total,
    required this.unread,
    required this.read,
    required this.isArabic,
  });

  final int total;
  final int unread;
  final int read;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0x33FFFFFF),
                  child: Icon(Icons.notifications_active_outlined, color: Colors.white),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'مركز الإشعارات' : 'Notification center',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        unread == 0
                            ? (isArabic ? 'أنت مطّلع على كل جديد' : 'You are all caught up')
                            : (isArabic
                                ? 'لديك $unread إشعار غير مقروء'
                                : 'You have $unread unread notifications'),
                        style: const TextStyle(color: Color(0xFFE5F5EF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _Metric(value: total, label: isArabic ? 'الإجمالي' : 'Total')),
                const SizedBox(width: 9),
                Expanded(child: _Metric(value: unread, label: isArabic ? 'جديدة' : 'Unread')),
                const SizedBox(width: 9),
                Expanded(child: _Metric(value: read, label: isArabic ? 'مقروءة' : 'Read')),
              ],
            ),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(label, style: const TextStyle(color: Color(0xFFE5F5EF))),
          ],
        ),
      );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isArabic,
    required this.onTap,
  });

  final AppNotification item;
  final bool isArabic;
  final VoidCallback onTap;

  bool get _hasDestination =>
      item.dealSlug != null ||
      item.productSlug != null ||
      item.businessSlug != null;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: item.isRead
          ? colors.surface
          : colors.primaryContainer.withValues(alpha: .55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: item.isRead
              ? AppColors.border
              : colors.primary.withValues(alpha: .28),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accent(context).withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_iconFor(item.type), color: _accent(context)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: item.isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsetsDirectional.only(start: 8, top: 5),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.body,
                        style: const TextStyle(height: 1.55, color: AppColors.muted),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: colors.outline),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _timeLabel(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (_hasDestination)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isArabic ? 'فتح' : 'Open',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.arrow_forward_rounded, size: 17, color: colors.primary),
                            ],
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

  String _timeLabel() {
    final date = item.createdAt;
    if (date == null) return isArabic ? 'الآن' : 'Now';
    final local = date.toLocal();
    final difference = DateTime.now().difference(local);
    if (difference.inMinutes < 1) return isArabic ? 'الآن' : 'Now';
    if (difference.inHours < 1) {
      return isArabic
          ? 'منذ ${difference.inMinutes} دقيقة'
          : '${difference.inMinutes} min ago';
    }
    if (difference.inDays < 1) {
      return isArabic
          ? 'منذ ${difference.inHours} ساعة'
          : '${difference.inHours} hr ago';
    }
    if (difference.inDays < 7) {
      return isArabic
          ? 'منذ ${difference.inDays} يوم'
          : '${difference.inDays} days ago';
    }
    return DateFormat(isArabic ? 'd MMM، h:mm a' : 'MMM d, h:mm a', isArabic ? 'ar' : 'en')
        .format(local);
  }

  Color _accent(BuildContext context) => switch (item.type) {
        'deal' => Colors.deepOrange,
        'business' => Theme.of(context).colorScheme.primary,
        'product' => Colors.indigo,
        'review' => Colors.amber.shade800,
        'system' => Colors.blueGrey,
        _ => Theme.of(context).colorScheme.secondary,
      };

  IconData _iconFor(String type) => switch (type) {
        'deal' => Icons.local_offer_outlined,
        'business' => Icons.storefront_outlined,
        'product' => Icons.inventory_2_outlined,
        'review' => Icons.star_outline_rounded,
        'system' => Icons.settings_outlined,
        _ => Icons.notifications_none_rounded,
      };
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 42, color: AppColors.primary),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.6, color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      );
}