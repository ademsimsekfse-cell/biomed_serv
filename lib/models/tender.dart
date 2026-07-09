import 'package:hive/hive.dart';
import './customer.dart';

part 'tender.g.dart';

@HiveType(typeId: 3)
class Tender extends HiveObject {
  @HiveField(0)
  late String tenderNo;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late DateTime startDate;

  @HiveField(3)
  late DateTime endDate;

  @HiveField(4)
  late HiveList<Customer> customers;

  Tender({
    required this.tenderNo,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.customers,
  });
}
