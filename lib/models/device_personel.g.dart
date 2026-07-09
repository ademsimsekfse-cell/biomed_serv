// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_personel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DevicePersonelAdapter extends TypeAdapter<DevicePersonel> {
  @override
  final int typeId = 22;

  @override
  DevicePersonel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DevicePersonel(
      firstName: fields[0] as String,
      lastName: fields[1] as String,
      phone: fields[2] as String?,
      email: fields[3] as String?,
      title: fields[4] as String?,
      assignedDate: fields[5] as DateTime?,
      customer: fields[6] as HiveObject?,
    );
  }

  @override
  void write(BinaryWriter writer, DevicePersonel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.firstName)
      ..writeByte(1)
      ..write(obj.lastName)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.assignedDate)
      ..writeByte(6)
      ..write(obj.customer);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DevicePersonelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
