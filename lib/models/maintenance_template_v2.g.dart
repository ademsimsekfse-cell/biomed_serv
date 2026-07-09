// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maintenance_template_v2.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MaintenanceTemplateLineAdapter
    extends TypeAdapter<MaintenanceTemplateLine> {
  @override
  final int typeId = 24;

  @override
  MaintenanceTemplateLine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MaintenanceTemplateLine(
      description: fields[0] as String,
      isRequired: fields[1] as bool,
      partName: fields[2] as String?,
      partQuantity: fields[3] as int?,
      stockReferenceNo: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MaintenanceTemplateLine obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.description)
      ..writeByte(1)
      ..write(obj.isRequired)
      ..writeByte(2)
      ..write(obj.partName)
      ..writeByte(3)
      ..write(obj.partQuantity)
      ..writeByte(4)
      ..write(obj.stockReferenceNo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceTemplateLineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MaintenanceTemplateV2Adapter extends TypeAdapter<MaintenanceTemplateV2> {
  @override
  final int typeId = 26;

  @override
  MaintenanceTemplateV2 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MaintenanceTemplateV2(
      name: fields[0] as String,
      description: fields[1] as String?,
      deviceModel: fields[2] as String?,
      deviceBrand: fields[3] as String?,
      periodType: fields[4] as MaintenancePeriodType,
      customPeriodDays: fields[5] as int?,
      lines: (fields[6] as List?)?.cast<MaintenanceTemplateLine>(),
      isActive: fields[9] as bool,
    )
      ..createdAt = fields[7] as DateTime
      ..updatedAt = fields[8] as DateTime;
  }

  @override
  void write(BinaryWriter writer, MaintenanceTemplateV2 obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.deviceModel)
      ..writeByte(3)
      ..write(obj.deviceBrand)
      ..writeByte(4)
      ..write(obj.periodType)
      ..writeByte(5)
      ..write(obj.customPeriodDays)
      ..writeByte(6)
      ..write(obj.lines)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceTemplateV2Adapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MaintenancePeriodTypeAdapter extends TypeAdapter<MaintenancePeriodType> {
  @override
  final int typeId = 25;

  @override
  MaintenancePeriodType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MaintenancePeriodType.weekly;
      case 1:
        return MaintenancePeriodType.monthly;
      case 2:
        return MaintenancePeriodType.quarterly;
      case 3:
        return MaintenancePeriodType.biannual;
      case 4:
        return MaintenancePeriodType.annual;
      case 5:
        return MaintenancePeriodType.biennial;
      case 6:
        return MaintenancePeriodType.custom;
      default:
        return MaintenancePeriodType.weekly;
    }
  }

  @override
  void write(BinaryWriter writer, MaintenancePeriodType obj) {
    switch (obj) {
      case MaintenancePeriodType.weekly:
        writer.writeByte(0);
        break;
      case MaintenancePeriodType.monthly:
        writer.writeByte(1);
        break;
      case MaintenancePeriodType.quarterly:
        writer.writeByte(2);
        break;
      case MaintenancePeriodType.biannual:
        writer.writeByte(3);
        break;
      case MaintenancePeriodType.annual:
        writer.writeByte(4);
        break;
      case MaintenancePeriodType.biennial:
        writer.writeByte(5);
        break;
      case MaintenancePeriodType.custom:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenancePeriodTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
