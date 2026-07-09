// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeviceAdapter extends TypeAdapter<Device> {
  @override
  final int typeId = 2;

  @override
  Device read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Device(
      name: fields[0] as String,
      brand: fields[1] as String,
      model: fields[2] as String,
      serialNumber: fields[3] as String,
      customer: fields[4] as HiveObject?,
      tender: fields[5] as HiveObject?,
      productionDate: fields[6] as DateTime?,
      installationDate: fields[7] as DateTime?,
      economicLife: fields[8] as int?,
      group: fields[9] as String?,
      barcode: fields[10] as String?,
      moduleType: fields[11] as DeviceModuleType,
      ownershipStatus: fields[12] as OwnershipStatus,
      controlModule: fields[13] as HiveObject?,
      serviceDuration: fields[14] as int?,
      responsiblePerson: fields[15] as DevicePersonel?,
      warrantyStartDate: fields[16] as DateTime?,
      warrantyEndDate: fields[17] as DateTime?,
      location: fields[18] as String?,
      deviceCategory: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Device obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.brand)
      ..writeByte(2)
      ..write(obj.model)
      ..writeByte(3)
      ..write(obj.serialNumber)
      ..writeByte(4)
      ..write(obj.customer)
      ..writeByte(5)
      ..write(obj.tender)
      ..writeByte(6)
      ..write(obj.productionDate)
      ..writeByte(7)
      ..write(obj.installationDate)
      ..writeByte(8)
      ..write(obj.economicLife)
      ..writeByte(9)
      ..write(obj.group)
      ..writeByte(10)
      ..write(obj.barcode)
      ..writeByte(11)
      ..write(obj.moduleType)
      ..writeByte(12)
      ..write(obj.ownershipStatus)
      ..writeByte(13)
      ..write(obj.controlModule)
      ..writeByte(14)
      ..write(obj.serviceDuration)
      ..writeByte(15)
      ..write(obj.responsiblePerson)
      ..writeByte(16)
      ..write(obj.warrantyStartDate)
      ..writeByte(17)
      ..write(obj.warrantyEndDate)
      ..writeByte(18)
      ..write(obj.location)
      ..writeByte(19)
      ..write(obj.deviceCategory);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OwnershipStatusAdapter extends TypeAdapter<OwnershipStatus> {
  @override
  final int typeId = 20;

  @override
  OwnershipStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OwnershipStatus.sold;
      case 1:
        return OwnershipStatus.rented;
      default:
        return OwnershipStatus.sold;
    }
  }

  @override
  void write(BinaryWriter writer, OwnershipStatus obj) {
    switch (obj) {
      case OwnershipStatus.sold:
        writer.writeByte(0);
        break;
      case OwnershipStatus.rented:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OwnershipStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DeviceModuleTypeAdapter extends TypeAdapter<DeviceModuleType> {
  @override
  final int typeId = 21;

  @override
  DeviceModuleType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DeviceModuleType.standalone;
      case 1:
        return DeviceModuleType.modularControl;
      case 2:
        return DeviceModuleType.modularProcessing;
      default:
        return DeviceModuleType.standalone;
    }
  }

  @override
  void write(BinaryWriter writer, DeviceModuleType obj) {
    switch (obj) {
      case DeviceModuleType.standalone:
        writer.writeByte(0);
        break;
      case DeviceModuleType.modularControl:
        writer.writeByte(1);
        break;
      case DeviceModuleType.modularProcessing:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceModuleTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
