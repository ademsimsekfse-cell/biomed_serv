// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenseAdapter extends TypeAdapter<Expense> {
  @override
  final int typeId = 33;

  @override
  Expense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Expense(
      date: fields[0] as DateTime,
      description: fields[1] as String,
      amount: fields[2] as double,
      customer: fields[3] as Customer?,
      device: fields[4] as Device?,
      status: fields[5] as ExpenseStatus,
      collectionType: fields[6] as CollectionType?,
      collectionDate: fields[7] as DateTime?,
      collectionNote: fields[8] as String?,
      reportedAt: fields[10] as DateTime?,
      reportNumber: fields[11] as String?,
    )..createdAt = fields[9] as DateTime;
  }

  @override
  void write(BinaryWriter writer, Expense obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.customer)
      ..writeByte(4)
      ..write(obj.device)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.collectionType)
      ..writeByte(7)
      ..write(obj.collectionDate)
      ..writeByte(8)
      ..write(obj.collectionNote)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.reportedAt)
      ..writeByte(11)
      ..write(obj.reportNumber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExpenseStatusAdapter extends TypeAdapter<ExpenseStatus> {
  @override
  final int typeId = 31;

  @override
  ExpenseStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExpenseStatus.pending;
      case 1:
        return ExpenseStatus.reported;
      case 2:
        return ExpenseStatus.collected;
      default:
        return ExpenseStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, ExpenseStatus obj) {
    switch (obj) {
      case ExpenseStatus.pending:
        writer.writeByte(0);
        break;
      case ExpenseStatus.reported:
        writer.writeByte(1);
        break;
      case ExpenseStatus.collected:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CollectionTypeAdapter extends TypeAdapter<CollectionType> {
  @override
  final int typeId = 32;

  @override
  CollectionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CollectionType.eft;
      case 1:
        return CollectionType.cash;
      case 2:
        return CollectionType.offset;
      default:
        return CollectionType.eft;
    }
  }

  @override
  void write(BinaryWriter writer, CollectionType obj) {
    switch (obj) {
      case CollectionType.eft:
        writer.writeByte(0);
        break;
      case CollectionType.cash:
        writer.writeByte(1);
        break;
      case CollectionType.offset:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
