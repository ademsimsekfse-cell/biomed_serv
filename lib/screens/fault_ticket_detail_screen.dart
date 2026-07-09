import 'dart:convert';
import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/providers/company_provider.dart';
import 'package:biomed_serv/providers/fault_ticket_provider.dart';
import 'package:biomed_serv/providers/report_template_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/screens/pdf_preview_screen.dart';
import 'package:biomed_serv/screens/service_form_screen.dart';
import 'package:biomed_serv/services/pdf_service.dart';
import 'package:biomed_serv/utils/turkish_text_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

class FaultTicketDetailScreen extends StatefulWidget {
  final FaultTicket ticket;

  const FaultTicketDetailScreen({super.key, required this.ticket});

  @override
  State<FaultTicketDetailScreen> createState() =>
      _FaultTicketDetailScreenState();
}

class _FaultTicketDetailScreenState extends State<FaultTicketDetailScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');
  final _actionsController = TextEditingController();
  final _finalStatusController = TextEditingController();
  final _responsibleNameController = TextEditingController();

  late SignatureController _techSignatureController;
  late SignatureController _responsibleSignatureController;

  final PdfService _pdfService = PdfService();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _actionsController.text = widget.ticket.actionsTaken ?? '';
    _finalStatusController.text = widget.ticket.finalStatus ?? '';
    _responsibleNameController.text = widget.ticket.responsibleName ?? '';

    _techSignatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    _responsibleSignatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _actionsController.dispose();
    _finalStatusController.dispose();
    _responsibleNameController.dispose();
    _techSignatureController.dispose();
    _responsibleSignatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.ticket.isCompleted;
    final isOpen = widget.ticket.isOpen;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticket.ticketNumber),
        actions: [
          if (isOpen)
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _showCancelDialog(),
              tooltip: 'İptal Et',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Durum Kartı
            _buildStatusCard(),
            const SizedBox(height: 16),

            _buildWorkflowCard(),
            const SizedBox(height: 16),

            if (isOpen) ...[
              _buildConvertToServiceCard(),
              const SizedBox(height: 16),
            ],

            // Temel Bilgiler
            _buildSectionTitle('Temel Bilgiler'),
            _buildInfoCard(),
            const SizedBox(height: 16),

            // Aşama 1: Problem Bildirimi (Sadece görüntüleme)
            _buildSectionTitle('1. Problem Bildirimi'),
            _buildProblemCard(),
            const SizedBox(height: 16),

            // Aşama 2: Müdahale (Eğer tamamlanmamışsa düzenlenebilir)
            if (!isCompleted) ...[
              _buildSectionTitle('2. Müdahale ve Yapılan İşlemler'),
              _buildInterventionCard(),
              const SizedBox(height: 16),
            ] else ...[
              _buildSectionTitle('2. Yapılan İşlemler'),
              _buildCompletedActionsCard(),
              const SizedBox(height: 16),
            ],

            // Aşama 3: Cihaz Son Durumu (Eğer tamamlanmamışsa)
            if (!isCompleted) ...[
              _buildSectionTitle('3. Cihaz Son Durumu'),
              _buildFinalStatusCard(),
              const SizedBox(height: 16),

              // Aşama 4: İmzalar
              _buildSectionTitle('4. İmzalar'),
              _buildSignaturesCard(),
              const SizedBox(height: 24),

              // Rapor Butonu
              _buildReportButton(),
            ] else ...[
              _buildSectionTitle('3. Cihaz Son Durumu'),
              _buildCompletedFinalStatusCard(),
              const SizedBox(height: 16),

              _buildSectionTitle('4. İmzalar'),
              _buildCompletedSignaturesCard(),
              const SizedBox(height: 24),

              // Tekrar Rapor Butonu
              _buildReprintButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusColor = Color(widget.ticket.statusColor);

    return Card(
      color: statusColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _getStatusIcon(widget.ticket.status),
              color: statusColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Durum: ${widget.ticket.statusText}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Arıza Tipi: ${widget.ticket.ticketTypeText}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowCard() {
    final ticket = widget.ticket;
    final summaryColor = Color(ticket.statusColor);
    final scheduledText = ticket.scheduledAt == null
        ? 'Plan tarihi yok'
        : _dateFormat.format(ticket.scheduledAt!);
    final canStartWork =
        ticket.status == TicketStatus.pending && ticket.key is int;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: summaryColor.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_outlined, color: summaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Is emri ozeti',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: summaryColor,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: summaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    ticket.workflowStageText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: summaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _workflowChip(
                    Icons.event_available_outlined, 'Plan: $scheduledText'),
                _workflowChip(
                  Icons.priority_high,
                  'Oncelik: ${ticket.priorityText}',
                ),
                if (ticket.hasServiceForm)
                  _workflowChip(
                    Icons.description_outlined,
                    'Servis formu: ${ticket.serviceFormNumber}',
                    accent: const Color(0xFF2E7D32),
                  ),
                if (ticket.technicianName != null &&
                    ticket.technicianName!.trim().isNotEmpty)
                  _workflowChip(
                    Icons.person_outline,
                    'Teknisyen: ${ticket.technicianName}',
                  ),
              ],
            ),
            if (canStartWork) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _startIntervention,
                      icon: const Icon(Icons.play_circle_outline),
                      label: Text(
                        ticket.isScheduled
                            ? 'Planli isi baslat'
                            : 'Mudahale baslat',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _workflowChip(IconData icon, String text, {Color? accent}) {
    final chipColor = accent ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('Kurum', widget.ticket.customer.name, Icons.business),
            const Divider(),
            _buildInfoRow(
                'Cihaz',
                '${widget.ticket.device.name} (${widget.ticket.device.serialNumber})',
                Icons.devices),
            const Divider(),
            _buildInfoRow(
                'Bildirim Tarihi',
                _dateFormat.format(widget.ticket.reportDateTime),
                Icons.calendar_today),
            if (widget.ticket.startDateTime != null) ...[
              const Divider(),
              _buildInfoRow(
                  'Müdahale Başlangıç',
                  _dateFormat.format(widget.ticket.startDateTime!),
                  Icons.engineering),
            ],
            if (widget.ticket.technicianName != null) ...[
              const Divider(),
              _buildInfoRow(
                  'Teknisyen', widget.ticket.technicianName!, Icons.person),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConvertToServiceCard() {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_turned_in, color: Colors.blue.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bu talebi servis formuna dönüştür',
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Kurum, cihaz, bildirim tarihi ve problem açıklaması servis formuna otomatik aktarılır. Form kaydedilince bu arıza kaydı tamamlandı olarak kapanır.',
              style: TextStyle(
                color: Colors.blue.shade900,
                fontSize: 12,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openServiceFormFromTicket,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Servis Formu Aç'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProblemCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.ticket.ticketTypeText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.ticket.problemDescription,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterventionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _actionsController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: const [TurkishUpperCaseTextFormatter()],
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Arıza Tespiti ve Yapılan İşlemler',
                hintText: 'Yapılan işlemleri detaylı yazın...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Durum butonları
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(TicketStatus.waitingPart),
                    icon: const Icon(Icons.inventory_2, size: 18),
                    label: const Text('Parça Bekleniyor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(TicketStatus.devicePassive),
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Cihaz Pasif'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yapılan İşlemler:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.ticket.actionsTaken ?? 'Belirtilmemiş',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _finalStatusController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: const [TurkishUpperCaseTextFormatter()],
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Cihazın Son Durumu Açıklaması',
                hintText: 'Örn: Cihaz çalışır durumda teslim edildi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _completeTicket(true),
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: const Text('CİHAZ AKTİF\nİş Emri Tamamla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedFinalStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Son Durum:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.ticket.finalStatus ?? 'Belirtilmemiş',
              style: const TextStyle(fontSize: 14),
            ),
            if (widget.ticket.endDateTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Tamamlanma: ${_dateFormat.format(widget.ticket.endDateTime!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignaturesCard() {
    final techName =
        Provider.of<TechnicianProvider>(context).currentTechnician?.fullName ??
            '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Teknisyen İmza
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Teknisyen: $techName',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Signature(
                          controller: _techSignatureController,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _techSignatureController.clear(),
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Temizle'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Birim Sorumlusu İmza
                Expanded(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _responsibleNameController,
                        decoration: const InputDecoration(
                          labelText: 'Birim Sorumlusu Ad Soyad',
                          hintText: 'Ad Soyad girin',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Signature(
                          controller: _responsibleSignatureController,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _responsibleSignatureController.clear(),
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Temizle'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedSignaturesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Teknisyen',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (widget.ticket.technicianSignature != null)
                        Image.memory(
                          base64Decode(widget.ticket.technicianSignature!),
                          height: 60,
                          fit: BoxFit.contain,
                        )
                      else
                        const Text('İmza yok'),
                      Text(widget.ticket.technicianName ?? ''),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Birim Sorumlusu',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (widget.ticket.responsibleSignature != null)
                        Image.memory(
                          base64Decode(widget.ticket.responsibleSignature!),
                          height: 60,
                          fit: BoxFit.contain,
                        )
                      else
                        const Text('İmza yok'),
                      Text(widget.ticket.responsibleName ?? ''),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _generateReport,
        icon: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.print),
        label: Text(
          _isProcessing ? 'Rapor Oluşturuluyor...' : 'RAPOR YAZDIR VE PAYLAŞ',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildReprintButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _generateReport,
        icon: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.print),
        label: Text(
          _isProcessing ? 'Rapor Oluşturuluyor...' : 'RAPORU TEKRAR YAZDIR',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(TicketStatus status) {
    switch (status) {
      case TicketStatus.pending:
        return Icons.schedule;
      case TicketStatus.inProgress:
        return Icons.engineering;
      case TicketStatus.waitingPart:
        return Icons.inventory_2;
      case TicketStatus.devicePassive:
        return Icons.block;
      case TicketStatus.completed:
        return Icons.check_circle;
      case TicketStatus.cancelled:
        return Icons.cancel;
    }
  }

  Future<void> _startIntervention() async {
    final provider = Provider.of<FaultTicketProvider>(context, listen: false);
    final technicianName =
        Provider.of<TechnicianProvider>(context, listen: false)
                .currentTechnician
                ?.fullName ??
            widget.ticket.technicianName ??
            '';
    final ticketKey = widget.ticket.key;
    if (ticketKey is! int) return;

    await provider.startIntervention(ticketKey, technicianName);
    if (!mounted) return;
    await provider.refresh();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Is emri sahada calisiliyor olarak guncellendi.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _openServiceFormFromTicket() async {
    final provider = Provider.of<FaultTicketProvider>(context, listen: false);
    final technicianName =
        Provider.of<TechnicianProvider>(context, listen: false)
                .currentTechnician
                ?.fullName ??
            widget.ticket.technicianName ??
            '';

    final ticketKey = widget.ticket.key;
    if (ticketKey is int && widget.ticket.status == TicketStatus.pending) {
      await provider.startIntervention(ticketKey, technicianName);
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceFormScreen(initialTicket: widget.ticket),
      ),
    );

    if (mounted) {
      await provider.refresh();
      setState(() {});
    }
  }

  Future<void> _updateStatus(TicketStatus status) async {
    await Provider.of<FaultTicketProvider>(context, listen: false)
        .updateStatus(widget.ticket.key as int, status);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Durum güncellendi: ${widget.ticket.statusText}'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _completeTicket(bool isActive) async {
    // Validasyonlar
    if (_actionsController.text.trim().isEmpty) {
      _showError('Yapılan işlemler alanı zorunludur');
      return;
    }

    if (_finalStatusController.text.trim().isEmpty) {
      _showError('Cihaz son durumu açıklaması zorunludur');
      return;
    }

    if (_responsibleNameController.text.trim().isEmpty) {
      _showError('Birim sorumlusu adı zorunludur');
      return;
    }

    // İmza kontrolü
    if (_techSignatureController.isEmpty) {
      _showError('Teknisyen imzası zorunludur');
      return;
    }

    if (_responsibleSignatureController.isEmpty) {
      _showError('Birim sorumlusu imzası zorunludur');
      return;
    }

    setState(() => _isProcessing = true);
    final ticketProvider =
        Provider.of<FaultTicketProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // İmzaları al
      final techSignBytes = await _techSignatureController.toPngBytes();
      final respSignBytes = await _responsibleSignatureController.toPngBytes();

      if (techSignBytes == null || respSignBytes == null) {
        throw Exception('İmza dönüştürme hatası');
      }

      final techSign = base64Encode(techSignBytes);
      final respSign = base64Encode(respSignBytes);

      // Final status metni
      final finalDescription =
          normalizeDescriptionText(_finalStatusController.text);
      final finalStatus = isActive
          ? 'CİHAZ AKTİF - $finalDescription'
          : 'CİHAZ PASİF - $finalDescription';

      // Tamamla
      await ticketProvider.completeTicket(
        widget.ticket.key as int,
        actionsTaken: normalizeDescriptionText(_actionsController.text),
        finalStatus: finalStatus,
        technicianSignature: techSign,
        responsibleName: _responsibleNameController.text.trim(),
        responsibleSignature: respSign,
      );

      // PDF oluştur
      await _generateFaultTicketPdf();

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Arıza kaydı tamamlandı ve rapor oluşturuldu!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Hata: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _generateFaultTicketPdf() async {
    // PDF servisine bilgileri ayarla
    final reportTemplateProvider =
        Provider.of<ReportTemplateProvider>(context, listen: false);
    final companyProvider =
        Provider.of<CompanyProvider>(context, listen: false);
    final technicianProvider =
        Provider.of<TechnicianProvider>(context, listen: false);

    _pdfService.setTemplate(reportTemplateProvider.defaultServiceTemplate);
    _pdfService.setCompanyInfo(companyProvider.companyInfo);
    _pdfService.setTechnician(technicianProvider.currentTechnician);

    // Fault Ticket PDF'i oluştur ve paylaşmadan önce önizle
    final pdfFile = await _pdfService.generateFaultTicketPdf(widget.ticket);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          filePath: pdfFile.path,
          title: 'Arıza Raporu Önizleme',
          shareText: 'Arıza Raporu',
        ),
      ),
    );
  }

  Future<void> _generateReport() async {
    setState(() => _isProcessing = true);
    try {
      await _generateFaultTicketPdf();
    } catch (e) {
      _showError('PDF oluşturma hatası: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showCancelDialog() {
    final ticketProvider =
        Provider.of<FaultTicketProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arıza Kaydını İptal Et'),
        content: const Text(
          'Bu arıza kaydını iptal etmek istediğinize emin misiniz?\n\n'
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await ticketProvider.cancelTicket(widget.ticket.key as int);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Arıza kaydı iptal edildi'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            icon: const Icon(Icons.cancel),
            label: const Text('İptal Et'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
