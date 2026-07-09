// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_form.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ServiceFormAdapter extends TypeAdapter<ServiceForm> {
  @override
  final int typeId = 5;

  @override
  ServiceForm read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ServiceForm(
      formNumber: fields[0] as String,
      createdAt: fields[1] as DateTime,
      customer: fields[2] as Customer,
      device: fields[3] as Device,
      problemDescription: fields[4] as String?,
      actionsTaken: fields[5] as String?,
      finalStatus: fields[6] as String?,
      problemTypes: (fields[7] as List).cast<String>(),
      resultStatus: fields[8] as String?,
      feeStatus: fields[9] as String?,
      problemDateTime: fields[10] as DateTime?,
      interventionDateTime: fields[11] as DateTime?,
      solutionDateTime: fields[12] as DateTime?,
      travelHours: fields[13] as int?,
      repairHours: fields[14] as int?,
      trainingHours: fields[15] as int?,
      assemblyHours: fields[16] as int?,
      modificationHours: fields[17] as int?,
      totalFee: fields[18] as double?,
      totalFeeWithVAT: fields[19] as double?,
      partsUsed: (fields[20] as HiveList).castHiveList(),
      technicianSignature: fields[21] as String?,
      customerSignature: fields[22] as String?,
      technicianName: fields[23] as String?,
      customerName: fields[24] as String?,
      sourceTicketNumber: fields[25] as String?,
      pdfPath: fields[26] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ServiceForm obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.formNumber)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.customer)
      ..writeByte(3)
      ..write(obj.device)
      ..writeByte(4)
      ..write(obj.problemDescription)
      ..writeByte(5)
      ..write(obj.actionsTaken)
      ..writeByte(6)
      ..write(obj.finalStatus)
      ..writeByte(7)
      ..write(obj.problemTypes)
      ..writeByte(8)
      ..write(obj.resultStatus)
      ..writeByte(9)
      ..write(obj.feeStatus)
      ..writeByte(10)
      ..write(obj.problemDateTime)
      ..writeByte(11)
      ..write(obj.interventionDateTime)
      ..writeByte(12)
      ..write(obj.solutionDateTime)
      ..writeByte(13)
      ..write(obj.travelHours)
      ..writeByte(14)
      ..write(obj.repairHours)
      ..writeByte(15)
      ..write(obj.trainingHours)
      ..writeByte(16)
      ..write(obj.assemblyHours)
      ..writeByte(17)
      ..write(obj.modificationHours)
      ..writeByte(18)
      ..write(obj.totalFee)
      ..writeByte(19)
      ..write(obj.totalFeeWithVAT)
      ..writeByte(20)
      ..write(obj.partsUsed)
      ..writeByte(21)
      ..write(obj.technicianSignature)
      ..writeByte(22)
      ..write(obj.customerSignature)
      ..writeByte(23)
      ..write(obj.technicianName)
      ..writeByte(24)
      ..write(obj.customerName)
      ..writeByte(25)
      ..write(obj.sourceTicketNumber)
      ..writeByte(26)
      ..write(obj.pdfPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceFormAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
