// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maintenance_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MaintenanceTemplateAdapter extends TypeAdapter<MaintenanceTemplate> {
  @override
  final int typeId = 7;

  @override
  MaintenanceTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MaintenanceTemplate(
      name: fields[0] as String,
      group: fields[1] as String?,
      actions: (fields[2] as List).cast<String>(),
      requiredParts: (fields[3] as HiveList).castHiveList(),
    );
  }

  @override
  void write(BinaryWriter writer, MaintenanceTemplate obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.group)
      ..writeByte(2)
      ..write(obj.actions)
      ..writeByte(3)
      ..write(obj.requiredParts);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
