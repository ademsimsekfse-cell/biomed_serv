// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_module.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeviceModuleAdapter extends TypeAdapter<DeviceModule> {
  @override
  final int typeId = 23;

  @override
  DeviceModule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeviceModule(
      controlModule: fields[0] as HiveObject,
      processingModuleKeys: (fields[1] as List?)?.cast<int>(),
      description: fields[3] as String?,
    )..createdAt = fields[2] as DateTime;
  }

  @override
  void write(BinaryWriter writer, DeviceModule obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.controlModule)
      ..writeByte(1)
      ..write(obj.processingModuleKeys)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceModuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
