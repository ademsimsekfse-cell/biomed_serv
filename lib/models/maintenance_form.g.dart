// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maintenance_form.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MaintenanceFormAdapter extends TypeAdapter<MaintenanceForm> {
  @override
  final int typeId = 6;

  @override
  MaintenanceForm read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MaintenanceForm(
      formNumber: fields[0] as String,
      createdAt: fields[1] as DateTime,
      customer: fields[2] as Customer,
      device: fields[3] as Device,
      maintenancePeriod: fields[4] as String,
      actionsTaken: (fields[5] as List).cast<String>(),
      notes: fields[6] as String?,
      partsUsed: (fields[7] as HiveList).castHiveList(),
      finalStatus: fields[8] as String?,
      technicianSignature: fields[9] as String?,
      customerSignature: fields[10] as String?,
      technicianName: fields[11] as String?,
      customerName: fields[12] as String?,
      pdfPath: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MaintenanceForm obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.formNumber)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.customer)
      ..writeByte(3)
      ..write(obj.device)
      ..writeByte(4)
      ..write(obj.maintenancePeriod)
      ..writeByte(5)
      ..write(obj.actionsTaken)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.partsUsed)
      ..writeByte(8)
      ..write(obj.finalStatus)
      ..writeByte(9)
      ..write(obj.technicianSignature)
      ..writeByte(10)
      ..write(obj.customerSignature)
      ..writeByte(11)
      ..write(obj.technicianName)
      ..writeByte(12)
      ..write(obj.customerName)
      ..writeByte(13)
      ..write(obj.pdfPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceFormAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
