import 'package:biomed_serv/models/notification.dart' as model;
import 'package:biomed_serv/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// 🔔 Bildirim ve Hatırlatıcı Ekranı - Geliştirilmiş UI
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bildirimler & Hatırlatıcılar'),
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.notifications_active, size: 24),
                text: 'Bildirimler',
              ),
              Tab(
                icon: Icon(Icons.alarm_on, size: 24),
                text: 'Hatırlatıcılar',
              ),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            indicatorColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
          ),
          actions: [
            // 🔔 Tümünü okundu işaretle - BELİRGİN BUTON
            Consumer<NotificationProvider>(
              builder: (context, provider, child) {
                if (provider.unreadCount == 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: _buildActionButton(
                    icon: Icons.done_all,
                    label: 'Tümünü Okundu',
                    color: Colors.green,
                    onPressed: () => provider.markAllAsRead(),
                  ),
                );
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _NotificationsTab(),
            _RemindersTab(),
          ],
        ),
        // 🎯 Modern Floating Action Button - Belirgin renkler
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.orange.shade600, Colors.orange.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.shade400.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => _showAddReminderDialog(context),
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(Icons.add_alarm, color: Colors.white),
            label: const Text(
              'Hatırlatıcı Ekle',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 BELİRGİN Aksiyon Butonu
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔔 Modern Hatırlatıcı Ekleme Dialogu
  void _showAddReminderDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isRepeating = false;
    String repeatInterval = 'daily';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_alarm, color: Colors.orange.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Yeni Hatırlatıcı',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Başlık *',
                    hintText: 'Örn: Haftalık Rapor',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.title),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
                // Açıklama
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Açıklama',
                    hintText: 'Detaylı açıklama...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.description),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                // Tarih ve Saat - Yan yana
                Row(
                  children: [
                    // Tarih Seçimi
                    Expanded(
                      child: _buildDateTimeCard(
                        icon: Icons.calendar_today,
                        label: 'Tarih',
                        value: DateFormat('dd.MM.yyyy').format(selectedDate),
                        color: Colors.blue,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.blue.shade700,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Saat Seçimi
                    Expanded(
                      child: _buildDateTimeCard(
                        icon: Icons.access_time,
                        label: 'Saat',
                        value: selectedTime.format(context),
                        color: Colors.purple,
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.purple.shade700,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (time != null) {
                            setState(() => selectedTime = time);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tekrarlayan Switch
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isRepeating ? Colors.purple.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRepeating ? Colors.purple.shade200 : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Tekrarlayan Hatırlatıcı',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isRepeating ? 'Otomatik olarak tekrarlayacak' : 'Tek seferlik hatırlatıcı',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: isRepeating,
                        activeColor: Colors.purple,
                        onChanged: (v) => setState(() => isRepeating = v),
                      ),
                      if (isRepeating)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                          child: DropdownButtonFormField<String>(
                            value: repeatInterval,
                            decoration: InputDecoration(
                              labelText: 'Tekrar Aralığı',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              prefixIcon: const Icon(Icons.repeat),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: [
                              _buildRepeatItem('daily', 'Her Gün', Icons.today),
                              _buildRepeatItem('weekly', 'Her Hafta', Icons.view_week),
                              _buildRepeatItem('monthly', 'Her Ay', Icons.calendar_view_month),
                            ],
                            onChanged: (v) => setState(() => repeatInterval = v!),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // İptal Butonu
            TextButton.icon(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('İptal'),
            ),
            // Ekle Butonu - BELİRGİN
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [Colors.green.shade500, Colors.green.shade700],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.shade400.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  if (titleController.text.isNotEmpty) {
                    final reminder = model.Reminder(
                      title: titleController.text,
                      description: descController.text.isEmpty
                          ? null
                          : descController.text,
                      reminderDate: DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      ),
                      isRepeating: isRepeating,
                      repeatInterval: isRepeating ? repeatInterval : null,
                    );
                    Provider.of<NotificationProvider>(context, listen: false)
                        .addReminder(reminder);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('✅ Hatırlatıcı eklendi'),
                        backgroundColor: Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Başlık alanı zorunludur'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add_circle, color: Colors.white),
                label: const Text(
                  'Ekle',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 📅 Tarih/Saat Seçim Kartı
  Widget _buildDateTimeCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔄 Tekrar Dropdown Item
  DropdownMenuItem<String> _buildRepeatItem(String value, String text, IconData icon) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.purple),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

/// Bildirimler Sekmesi
class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final notifications = provider.notifications;

        if (notifications.isEmpty) {
          return _buildEmptyState(
            icon: Icons.notifications_off_outlined,
            title: 'Henüz bildirim yok',
            subtitle: 'Yeni bildirimler burada görünecek',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildNotificationCard(
              context,
              notification,
              dateFormat,
              provider,
            );
          },
        );
      },
    );
  }

  // 🎨 Modern Bildirim Kartı
  Widget _buildNotificationCard(
    BuildContext context,
    model.AppNotification notification,
    DateFormat dateFormat,
    NotificationProvider provider,
  ) {
    final color = Color(notification.priorityColor);

    return Dismissible(
      key: Key(notification.key.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Sil',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      onDismissed: (_) {
        if (notification.key != null) {
          provider.deleteNotification(notification.key!);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead ? Colors.grey.shade200 : color.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!notification.isRead && notification.key != null) {
              provider.markAsRead(notification.key!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 🎨 İkon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: notification.isRead
                          ? [Colors.grey.shade200, Colors.grey.shade300]
                          : [color.withOpacity(0.2), color.withOpacity(0.4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForType(notification.type),
                    color: notification.isRead ? Colors.grey.shade500 : color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                // 📝 Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık + Okunmadı noktası
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 15,
                                color: notification.isRead
                                    ? Colors.grey.shade700
                                    : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.4),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Tip + Tarih
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notification.typeText,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(notification.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (notification.message != null && notification.message!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          notification.message!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // 🎯 Hızlı Eylem Butonu
                if (!notification.isRead)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (notification.key != null) {
                            provider.markAsRead(notification.key!);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.done,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                        ),
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

  IconData _getIconForType(model.NotificationType type) {
    switch (type) {
      case model.NotificationType.serviceReminder:
        return Icons.build;
      case model.NotificationType.maintenanceReminder:
        return Icons.handyman;
      case model.NotificationType.warrantyExpiration:
        return Icons.security;
      case model.NotificationType.stockAlert:
        return Icons.inventory_2;
      case model.NotificationType.taskAssignment:
        return Icons.assignment;
      case model.NotificationType.general:
        return Icons.notifications;
      case model.NotificationType.device:
        return Icons.devices;
      case model.NotificationType.expense:
        return Icons.payments;
    }
    return Icons.notifications;
  }

  // 🎨 Modern Boş Durum Ekranı
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🎨 Gradient arka plan ile ikon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade100,
                    Colors.blue.shade200,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 60,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hatırlatıcılar Sekmesi
class _RemindersTab extends StatelessWidget {
  const _RemindersTab();

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final reminders = provider.reminders;

        if (reminders.isEmpty) {
          return _buildEmptyState(
            icon: Icons.alarm_off_outlined,
            title: 'Henüz hatırlatıcı yok',
            subtitle: 'Yeni hatırlatıcı eklemek için + butonuna tıklayın',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reminders.length,
          itemBuilder: (context, index) {
            final reminder = reminders[index];
            return _buildReminderCard(
              context,
              reminder,
              dateFormat,
              provider,
            );
          },
        );
      },
    );
  }

  // 🎨 Modern Hatırlatıcı Kartı
  Widget _buildReminderCard(
    BuildContext context,
    model.Reminder reminder,
    DateFormat dateFormat,
    NotificationProvider provider,
  ) {
    final isOverdue = reminder.reminderDate.isBefore(DateTime.now());
    final isToday = _isToday(reminder.reminderDate);
    
    // Durum rengini belirle
    Color statusColor;
    IconData statusIcon;
    if (!reminder.isActive) {
      statusColor = Colors.grey;
      statusIcon = Icons.alarm_off;
    } else if (isOverdue) {
      statusColor = Colors.red;
      statusIcon = Icons.alarm;
    } else if (isToday) {
      statusColor = Colors.orange;
      statusIcon = Icons.alarm_on;
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.alarm;
    }

    return Dismissible(
      key: Key(reminder.key.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Sil',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      onDismissed: (_) {
        if (reminder.key != null) {
          provider.deleteReminder(reminder.key!);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: !reminder.isActive
              ? Colors.grey.shade50
              : isOverdue
                  ? Colors.red.shade50
                  : isToday
                      ? Colors.orange.shade50
                      : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: !reminder.isActive
                ? Colors.grey.shade300
                : isOverdue
                    ? Colors.red.shade200
                    : isToday
                        ? Colors.orange.shade200
                        : Colors.blue.shade100,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst satır: İkon + Başlık + Switch
              Row(
                children: [
                  // 🎨 Durum İkonu
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: !reminder.isActive
                            ? [Colors.grey.shade300, Colors.grey.shade400]
                            : isOverdue
                                ? [Colors.red.shade200, Colors.red.shade300]
                                : isToday
                                    ? [Colors.orange.shade200, Colors.orange.shade300]
                                    : [Colors.blue.shade200, Colors.blue.shade300],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      statusIcon,
                      color: !reminder.isActive ? Colors.white70 : Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Başlık
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: !reminder.isActive
                                ? TextDecoration.lineThrough
                                : null,
                            color: !reminder.isActive
                                ? Colors.grey.shade600
                                : Colors.black87,
                          ),
                        ),
                        if (reminder.description != null && reminder.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            reminder.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: !reminder.isActive
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 🎯 Aktif/Pasif Switch
                  Container(
                    decoration: BoxDecoration(
                      color: reminder.isActive
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Switch(
                      value: reminder.isActive,
                      onChanged: (_) {
                        if (reminder.key != null) {
                          provider.toggleReminderStatus(reminder.key!);
                        }
                      },
                      activeColor: Colors.green.shade700,
                      inactiveThumbColor: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Alt satır: Tarih + Tekrar + Durum
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: !reminder.isActive
                      ? Colors.grey.shade100
                      : isOverdue
                          ? Colors.red.shade100
                          : isToday
                              ? Colors.orange.shade100
                              : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Tarih ve Saat
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: isOverdue ? Colors.red.shade700 : statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateFormat.format(reminder.reminderDate),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isOverdue
                              ? Colors.red.shade700
                              : !reminder.isActive
                                  ? Colors.grey.shade600
                                  : Colors.black87,
                        ),
                      ),
                    ),
                    // Tekrar Badge
                    if (reminder.isRepeating)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.repeat, size: 14, color: Colors.purple.shade700),
                            const SizedBox(width: 4),
                            Text(
                              _getRepeatText(reminder.repeatInterval),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Gecikti Badge
                    if (isOverdue && reminder.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.shade400.withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'GECİKTİ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _getRepeatText(String? interval) {
    switch (interval) {
      case 'daily':
        return 'Her Gün';
      case 'weekly':
        return 'Her Hafta';
      case 'monthly':
        return 'Her Ay';
      default:
        return 'Tekrarlı';
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
