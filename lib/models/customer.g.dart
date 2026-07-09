// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 1;

  @override
  Customer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Customer(
      name: fields[0] as String,
      address: fields[1] as String,
      phone: fields[2] as String,
      authorizedPerson: fields[3] as String,
      email: fields[4] as String?,
      vergiNo: fields[5] as String?,
      isActive: fields[6] as bool,
      unitManagerName: fields[7] as String?,
      unitManagerPhone: fields[8] as String?,
      unitResponsibleName: fields[9] as String?,
      unitResponsiblePhone: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.address)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.authorizedPerson)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.vergiNo)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.unitManagerName)
      ..writeByte(8)
      ..write(obj.unitManagerPhone)
      ..writeByte(9)
      ..write(obj.unitResponsibleName)
      ..writeByte(10)
      ..write(obj.unitResponsiblePhone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
