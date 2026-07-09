import 'package:hive/hive.dart';

part 'stock.g.dart';

@HiveType(typeId: 4)
class Stock extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late int quantity;

  @HiveField(2)
  late String? barcode;

  @HiveField(3)
  late String? referenceNo;

  @HiveField(4)
  late int criticalStockThreshold;

  Stock({
    required this.name,
    required this.quantity,
    this.barcode,
    this.referenceNo,
    this.criticalStockThreshold = 10, // Varsayılan kritik stok eşiği
  });
}
