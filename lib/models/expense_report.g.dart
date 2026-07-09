// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_report.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenseReportAdapter extends TypeAdapter<ExpenseReport> {
  @override
  final int typeId = 34;

  @override
  ExpenseReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExpenseReport(
      reportNumber: fields[0] as String,
      technician: fields[2] as Technician,
      expenseKeys: (fields[3] as List).cast<int>(),
      totalAmount: fields[4] as double,
      pdfPath: fields[5] as String?,
      isCollected: fields[6] as bool,
      collectionType: fields[7] as CollectionType?,
      collectionDate: fields[8] as DateTime?,
      collectionNote: fields[9] as String?,
      notes: fields[10] as String?,
      collectedAmount: fields[11] as double,
    )..createdAt = fields[1] as DateTime;
  }

  @override
  void write(BinaryWriter writer, ExpenseReport obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.reportNumber)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.technician)
      ..writeByte(3)
      ..write(obj.expenseKeys)
      ..writeByte(4)
      ..write(obj.totalAmount)
      ..writeByte(5)
      ..write(obj.pdfPath)
      ..writeByte(6)
      ..write(obj.isCollected)
      ..writeByte(7)
      ..write(obj.collectionType)
      ..writeByte(8)
      ..write(obj.collectionDate)
      ..writeByte(9)
      ..write(obj.collectionNote)
      ..writeByte(10)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.collectedAmount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
