// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompanyInfoAdapter extends TypeAdapter<CompanyInfo> {
  @override
  final int typeId = 50;

  @override
  CompanyInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CompanyInfo(
      companyName: fields[0] as String,
      taxNumber: fields[1] as String?,
      taxOffice: fields[2] as String?,
      address: fields[3] as String?,
      phone: fields[4] as String?,
      email: fields[5] as String?,
      website: fields[6] as String?,
      logoBytes: fields[7] as Uint8List?,
      logoWidth: fields[8] as double?,
      logoHeight: fields[9] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, CompanyInfo obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.companyName)
      ..writeByte(1)
      ..write(obj.taxNumber)
      ..writeByte(2)
      ..write(obj.taxOffice)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.phone)
      ..writeByte(5)
      ..write(obj.email)
      ..writeByte(6)
      ..write(obj.website)
      ..writeByte(7)
      ..write(obj.logoBytes)
      ..writeByte(8)
      ..write(obj.logoWidth)
      ..writeByte(9)
      ..write(obj.logoHeight);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanyInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
