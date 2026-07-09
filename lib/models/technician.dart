import 'dart:typed_data';

import 'package:hive/hive.dart';

part 'technician.g.dart';

@HiveType(typeId: 0)
class Technician extends HiveObject {
  @HiveField(0)
  late String firstName;

  @HiveField(1)
  late String lastName;

  @HiveField(2)
  String? phone;

  @HiveField(3)
  String? email;

  @HiveField(4)
  String? title;

  @HiveField(5)
  Uint8List? photoBytes;

  @HiveField(6)
  String? address;

  String get fullName => '$firstName $lastName';

  Technician({
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
    this.title,
    this.photoBytes,
    this.address,
  });
}
