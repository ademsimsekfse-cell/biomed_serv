import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/tender.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/tender_provider.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TenderManagementScreen extends StatelessWidget {
  const TenderManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İhale Yönetimi'),
      ),
      body: Consumer<TenderProvider>(
        builder: (context, provider, child) {
          if (provider.tenders.isEmpty) {
            return const Center(
              child: Text('Henüz ihale eklenmemiş.'),
            );
          }
          return ListView.builder(
            itemCount: provider.tenders.length,
            itemBuilder: (context, index) {
              final tender = provider.tenders[index];
              final formattedStartDate = DateFormat('dd/MM/yyyy').format(tender.startDate);
              final formattedEndDate = DateFormat('dd/MM/yyyy').format(tender.endDate);

              return ListTile(
                title: Text(tender.name),
                subtitle: Text('No: ${tender.tenderNo} | Tarihler: $formattedStartDate - $formattedEndDate'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('İhaleyi Sil'),
                        content: Text('"${tender.name}" adlı ihaleyi silmek istediğinizden emin misiniz?'),
                        actions: [
                          TextButton(
                            child: const Text('İptal'),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          TextButton(
                            child: const Text('Sil'),
                            onPressed: () {
                              provider.deleteTender(tender.key);
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0288D1).withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddTenderDialog(context),
          tooltip: 'Yeni İhale Ekle',
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  void _showAddTenderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const AddTenderDialog(),
    );
  }
}

class AddTenderDialog extends StatefulWidget {
  const AddTenderDialog({super.key});

  @override
  _AddTenderDialogState createState() => _AddTenderDialogState();
}

class _AddTenderDialogState extends State<AddTenderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tenderNoController = TextEditingController();
  final _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final List<Customer> _selectedCustomers = [];

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni İhale Ekle'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _tenderNoController,
                decoration: const InputDecoration(labelText: 'İhale No'),
                validator: (v) => v!.isEmpty ? 'Bu alan boş bırakılamaz' : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'İhale Adı'),
                validator: (v) => v!.isEmpty ? 'Bu alan boş bırakılamaz' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(_startDate == null ? 'Başlangıç Tarihi Seç' : DateFormat('dd/MM/yyyy').format(_startDate!)),
                  ),
                  IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _selectDate(context, true)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(_endDate == null ? 'Bitiş Tarihi Seç' : DateFormat('dd/MM/yyyy').format(_endDate!)),
                  ),
                  IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _selectDate(context, false)),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Müşteriler'),
              _buildCustomerSelection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(child: const Text('İptal'), onPressed: () => Navigator.of(context).pop()),
        ElevatedButton(
          child: const Text('Ekle'),
          onPressed: () {
             if (_formKey.currentState!.validate() && _startDate != null && _endDate != null && _selectedCustomers.isNotEmpty) {
                final tenderProvider = Provider.of<TenderProvider>(context, listen: false);
                final newTender = Tender(
                  tenderNo: _tenderNoController.text,
                  name: _nameController.text,
                  startDate: _startDate!,
                  endDate: _endDate!,
                  customers: HiveList(Hive.box<Customer>('customers'), objects: _selectedCustomers),
                );
                tenderProvider.addTender(newTender);
                Navigator.of(context).pop();
              } else {
                // Kullanıcıya eksik alanlar hakkında bilgi ver
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen tüm alanları doldurun ve en az bir müşteri seçin.')),
                  );
              }
          },
        ),
      ],
    );
  }

  Widget _buildCustomerSelection() {
    final customerProvider = Provider.of<CustomerProvider>(context);
    if (customerProvider.customers.isEmpty) {
      return const Text('Önce müşteri eklemelisiniz.', style: TextStyle(color: Colors.red));
    }
    return SizedBox(
      height: 150,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: customerProvider.customers.length,
        itemBuilder: (context, index) {
          final customer = customerProvider.customers[index];
          return CheckboxListTile(
            title: Text(customer.name),
            value: _selectedCustomers.contains(customer),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedCustomers.add(customer);
                } else {
                  _selectedCustomers.remove(customer);
                }
              });
            },
          );
        },
      ),
    );
  }
}
