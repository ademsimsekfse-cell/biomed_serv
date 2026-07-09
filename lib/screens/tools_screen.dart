import 'package:flutter/material.dart';

import 'backup_import_screen.dart';
import 'barcode_scanner_screen.dart';
import 'desktop_shell_screen.dart';
import 'document_scanner_screen.dart';
import 'qr_generator_screen.dart';
import 'smart_document_converter_screen.dart';
import 'unit_converter_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = [
      _ToolItem(
        icon: Icons.document_scanner,
        title: 'Belge Tarayici',
        subtitle: 'A4 evraklari PDF yap',
        color: Colors.blue,
        screen: const DocumentScannerScreen(),
      ),
      _ToolItem(
        icon: Icons.table_chart,
        title: 'Akilli Donusturucu',
        subtitle: 'Excel, Word ve PDF',
        color: Colors.indigo,
        screen: const SmartDocumentConverterScreen(),
      ),
      _ToolItem(
        icon: Icons.qr_code_scanner,
        title: 'Barkod Okuyucu',
        subtitle: 'QR, EAN, GTIN',
        color: Colors.red,
        screen: const BarcodeScannerScreen(),
      ),
      _ToolItem(
        icon: Icons.qr_code,
        title: 'QR Olusturucu',
        subtitle: 'Kurumsal QR kod',
        color: Colors.purple,
        screen: const QrGeneratorScreen(),
      ),
      _ToolItem(
        icon: Icons.download,
        title: 'Veri Ice Aktar',
        subtitle: 'Eski yedeklerden al',
        color: Colors.orange,
        screen: const BackupImportScreen(),
      ),
      const _ToolItem(
        icon: Icons.calculate,
        title: 'Hesaplayici',
        subtitle: 'ng, ug, mg, g, kg donustur',
        color: Colors.blueGrey,
        screen: UnitConverterScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Araclar'),
        backgroundColor: Colors.teal,
      ),
      backgroundColor: Colors.grey.shade50,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return GridView.builder(
            padding: EdgeInsets.all(isWide ? 20 : 14),
            itemCount: tools.length,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isWide ? 280 : 240,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: isWide ? 2.45 : 2.15,
            ),
            itemBuilder: (context, index) {
              final item = tools[index];
              return _buildToolCard(
                context: context,
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle,
                color: item.color,
                onTap: item.screen == null
                    ? () => _showComingSoon(context)
                    : () => _openTool(context, item.screen!),
              );
            },
          );
        },
      ),
    );
  }

  void _openTool(BuildContext context, Widget screen) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1180;
    if (isDesktop) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DesktopShellScreen(child: screen),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.055),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.16)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.14)),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.18,
                        color: Colors.grey.shade700,
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

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bu ozellik yakinda gelecek!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget? screen;

  const _ToolItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.screen,
  });
}
