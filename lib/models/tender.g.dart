// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tender.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TenderAdapter extends TypeAdapter<Tender> {
  @override
  final int typeId = 3;

  @override
  Tender read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Tender(
      tenderNo: fields[0] as String,
      name: fields[1] as String,
      startDate: fields[2] as DateTime,
      endDate: fields[3] as DateTime,
      customers: (fields[4] as HiveList).castHiveList(),
    );
  }

  @override
  void write(BinaryWriter writer, Tender obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.tenderNo)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate)
      ..writeByte(4)
      ..write(obj.customers);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TenderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
