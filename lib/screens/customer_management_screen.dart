import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/screens/customer_detail_screen.dart';
import 'package:biomed_serv/services/sound_service.dart';
import 'package:biomed_serv/widgets/address_autocomplete_field.dart';
import 'package:biomed_serv/widgets/contact_picker_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CustomerManagementScreen extends StatelessWidget {
  const CustomerManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Müşteri Yönetimi'),
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.customers.isEmpty) {
            return const Center(
              child: Text('Henüz müşteri eklenmemiş.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.customers.length,
            itemBuilder: (context, index) {
              final customer = provider.customers[index];
              return _buildCustomerCard(context, customer);
            },
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFB74D), Color(0xFFF57C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF57C00).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddEditCustomerDialog(context),
          tooltip: 'Yeni Müşteri Ekle',
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  /// Müşteri Kartı - Kompakt
  Widget _buildCustomerCard(BuildContext context, Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerDetailScreen(customer: customer),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // İkon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.business, size: 22, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 10),
              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst satır: İsim + Durum
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: customer.isActive
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            customer.isActive ? 'Aktif' : 'Pasif',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: customer.isActive
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Alt satır: Detaylar yan yana
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                        children: [
                          if (customer.authorizedPerson.isNotEmpty)
                            TextSpan(text: customer.authorizedPerson),
                          if (customer.phone.isNotEmpty) ...[
                            if (customer.authorizedPerson.isNotEmpty)
                              const TextSpan(text: ' • '),
                            TextSpan(text: customer.phone),
                          ],
                          if (customer.address.isNotEmpty) ...[
                            const TextSpan(text: ' • '),
                            TextSpan(
                              text: customer.address,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              // Sağ: Butonlar
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon:
                        Icon(Icons.edit, color: Colors.blue.shade600, size: 20),
                    onPressed: () =>
                        _showAddEditCustomerDialog(context, customer: customer),
                    tooltip: 'Düzenle',
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete,
                        color: Colors.red.shade400, size: 20),
                    onPressed: () =>
                        _showDeleteConfirmDialog(context, customer),
                    tooltip: 'Sil',
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Müşteri Kartı (Eski Detaylı Görünüm - Geriye Uyumluluk)
  // ignore: unused_element
  Widget _buildCustomerCardDetailed(BuildContext context, Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerDetailScreen(customer: customer),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık Satırı: İsim + Durum + Butonlar
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İsim ve Durum
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.business,
                                color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Aktif/Pasif Durumu
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: customer.isActive
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            customer.isActive ? 'Aktif' : 'Pasif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: customer.isActive
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Düzenle ve Sil Butonları
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showAddEditCustomerDialog(context,
                            customer: customer),
                        tooltip: 'Düzenle',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _showDeleteConfirmDialog(context, customer),
                        tooltip: 'Sil',
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),

              // Temel Bilgiler
              _buildInfoRow(
                  Icons.location_on_outlined, 'Adres', customer.address),
              _buildInfoRow(Icons.phone_outlined, 'Telefon', customer.phone),
              _buildInfoRow(Icons.person_outline, 'Yetkili Kişi',
                  customer.authorizedPerson),

              if (customer.email != null && customer.email!.isNotEmpty)
                _buildInfoRow(Icons.email_outlined, 'E-Posta', customer.email!),

              if (customer.vergiNo != null && customer.vergiNo!.isNotEmpty)
                _buildInfoRow(
                    Icons.numbers_outlined, 'Vergi No', customer.vergiNo!),

              // Birim Amiri Bilgileri (varsa)
              if (customer.unitManagerName != null &&
                  customer.unitManagerName!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.manage_accounts,
                              size: 16, color: Colors.purple.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Birim Amiri',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        customer.unitManagerName!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (customer.unitManagerPhone != null &&
                          customer.unitManagerPhone!.isNotEmpty)
                        Text(
                          '📱 ${customer.unitManagerPhone}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                    ],
                  ),
                ),
              ],

              // Birim Sorumlusu Bilgileri (varsa)
              if (customer.unitResponsibleName != null &&
                  customer.unitResponsibleName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.supervisor_account,
                              size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Birim Sorumlusu',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        customer.unitResponsibleName!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (customer.unitResponsiblePhone != null &&
                          customer.unitResponsiblePhone!.isNotEmpty)
                        Text(
                          '📱 ${customer.unitResponsiblePhone}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Bilgi satırı widget'ı
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Silme onay dialogu
  void _showDeleteConfirmDialog(BuildContext context, Customer customer) {
    final linkedDevices = context
        .read<DeviceProvider>()
        .devices
        .where((device) => device.customer?.key == customer.key)
        .toList();
    final canDelete = linkedDevices.isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Müşteriyi Sil'),
        content: Text(
          canDelete
              ? '"${customer.name}" adlı müşteriyi silmek istediğinizden emin misiniz?'
              : '"${customer.name}" carisine bağlı ${linkedDevices.length} cihaz var. Önce cihaz kayıtlarından kurum ilişkisini kaldırın veya cihazları başka cariye taşıyın.',
        ),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          if (canDelete)
            TextButton(
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
              onPressed: () {
                context.read<CustomerProvider>().deleteCustomer(customer.key);
                Navigator.of(ctx).pop();
              },
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tamam'),
            ),
        ],
      ),
    );
  }

  /// Müşteri Ekle/Düzenle Dialog
  void _showAddEditCustomerDialog(BuildContext context, {Customer? customer}) {
    final isEditing = customer != null;
    final formKey = GlobalKey<FormState>();

    // Temel bilgiler
    final nameController = TextEditingController(text: customer?.name ?? '');
    final addressController =
        TextEditingController(text: customer?.address ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final authorizedPersonController =
        TextEditingController(text: customer?.authorizedPerson ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final vergiNoController =
        TextEditingController(text: customer?.vergiNo ?? '');

    // Birim Amiri
    final unitManagerNameController =
        TextEditingController(text: customer?.unitManagerName ?? '');
    final unitManagerPhoneController =
        TextEditingController(text: customer?.unitManagerPhone ?? '');

    // Birim Sorumlusu
    final unitResponsibleNameController =
        TextEditingController(text: customer?.unitResponsibleName ?? '');
    final unitResponsiblePhoneController =
        TextEditingController(text: customer?.unitResponsiblePhone ?? '');

    // Aktif/Pasif durumu
    bool isActive = customer?.isActive ?? true;

    // 🎯 AKILLI ÖNERİ LİSTELERİ - Provider'dan al
    final customerProvider =
        Provider.of<CustomerProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.person_add,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(isEditing ? 'Müşteri Düzenle' : 'Yeni Müşteri Ekle'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // === TEMEL BİLGİLER ===
                        _buildSectionTitle('Temel Bilgiler', Icons.business),
                        // 🎯 MÜŞTERİ ADI - Her kelime başı büyük
                        TextFormField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Müşteri Adı *',
                            prefixIcon: Icon(Icons.business),
                          ),
                          validator: (v) {
                            final name = v?.trim() ?? '';
                            if (name.isEmpty) return 'Bu alan zorunludur';
                            final existing = customerProvider.customerWithName(
                              name,
                              excludeKey: customer?.key is int
                                  ? customer!.key as int
                                  : null,
                            );
                            if (existing != null) {
                              return 'Bu cari adi zaten kayitli';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // 🗺️ ADRES - OpenStreetMap entegrasyonlu (Ücretsiz)
                        AddressAutocompleteField(
                          controller: addressController,
                          label: 'Adres',
                          hint: 'Mahalle, Sokak veya Kurum adı yazın...',
                          required: true,
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Adres zorunludur' : null,
                        ),
                        const SizedBox(height: 12),

                        // 🎯 YETKİLİ KİŞİ + TELEFON - Rehber entegrasyonlu
                        ContactPickerField(
                          nameController: authorizedPersonController,
                          phoneController: phoneController,
                          label: 'Yetkili Kişi Bilgileri',
                          hintName: 'Yetkili Kişi Ad Soyad *',
                          hintPhone: 'Telefon *',
                          nameRequired: true,
                          phoneRequired: true,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'E-Posta',
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: vergiNoController,
                          decoration: const InputDecoration(
                            labelText: 'Vergi Numarası',
                            prefixIcon: Icon(Icons.numbers),
                          ),
                        ),

                        // Aktif/Pasif Switch
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Aktif Müşteri'),
                          subtitle: Text(
                            isActive
                                ? 'Bu müşteri aktif olarak işaretlenecek'
                                : 'Bu müşteri pasif olarak işaretlenecek',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          value: isActive,
                          activeThumbColor: Colors.green,
                          onChanged: (value) =>
                              setState(() => isActive = value),
                        ),

                        const Divider(height: 32),

                        // === BİRİM AMİRİ ===
                        _buildSectionTitle(
                            'Birim Amiri', Icons.manage_accounts),
                        ContactPickerField(
                          nameController: unitManagerNameController,
                          phoneController: unitManagerPhoneController,
                          label: '',
                          hintName: 'Birim Amiri Ad Soyad',
                          hintPhone: 'Birim Amiri Telefon',
                        ),

                        const Divider(height: 32),

                        // === BİRİM SORUMLUSU ===
                        _buildSectionTitle(
                            'Birim Sorumlusu', Icons.supervisor_account),
                        ContactPickerField(
                          nameController: unitResponsibleNameController,
                          phoneController: unitResponsiblePhoneController,
                          label: '',
                          hintName: 'Birim Sorumlusu Ad Soyad',
                          hintPhone: 'Birim Sorumlusu Telefon',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('İptal'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                ElevatedButton.icon(
                  icon: Icon(isEditing ? Icons.save : Icons.add),
                  label: Text(isEditing ? 'Kaydet' : 'Ekle'),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        final updatedCustomer = Customer(
                          name: nameController.text.trim(),
                          address: addressController.text.trim(),
                          phone: phoneController.text.trim(),
                          authorizedPerson:
                              authorizedPersonController.text.trim(),
                          email: emailController.text.trim().isEmpty
                              ? null
                              : emailController.text.trim(),
                          vergiNo: vergiNoController.text.trim().isEmpty
                              ? null
                              : vergiNoController.text.trim(),
                          isActive: isActive,
                          unitManagerName:
                              unitManagerNameController.text.trim().isEmpty
                                  ? null
                                  : unitManagerNameController.text.trim(),
                          unitManagerPhone:
                              unitManagerPhoneController.text.trim().isEmpty
                                  ? null
                                  : unitManagerPhoneController.text.trim(),
                          unitResponsibleName:
                              unitResponsibleNameController.text.trim().isEmpty
                                  ? null
                                  : unitResponsibleNameController.text.trim(),
                          unitResponsiblePhone:
                              unitResponsiblePhoneController.text.trim().isEmpty
                                  ? null
                                  : unitResponsiblePhoneController.text.trim(),
                        );

                        if (isEditing && customer.key != null) {
                          // 🟡 GÜNCELLEME
                          await context
                              .read<CustomerProvider>()
                              .updateCustomer(customer.key!, updatedCustomer);
                          // 🔊 Başarı sesi
                          await SoundService().playSaveSuccess();
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Müşteri güncellendi'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          // 🟢 YENİ EKLEME
                          await context
                              .read<CustomerProvider>()
                              .addCustomer(updatedCustomer);
                          // 🔊 Başarı sesi
                          await SoundService().playSaveSuccess();
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Yeni müşteri eklendi'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }

                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      } catch (e) {
                        // 🔊 Hata sesi
                        await SoundService().playError();
                        debugPrint('🚨 Müşteri kaydetme hatası: $e');
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('❌ Hata: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Bölüm başlığı
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
