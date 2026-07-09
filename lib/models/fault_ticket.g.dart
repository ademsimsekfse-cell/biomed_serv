// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fault_ticket.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FaultTicketAdapter extends TypeAdapter<FaultTicket> {
  @override
  final int typeId = 40;

  @override
  FaultTicket read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FaultTicket(
      ticketNumber: fields[0] as String,
      customer: fields[1] as Customer,
      device: fields[2] as Device,
      technician: fields[3] as Technician?,
      reportDateTime: fields[4] as DateTime,
      startDateTime: fields[5] as DateTime?,
      endDateTime: fields[6] as DateTime?,
      ticketType: fields[7] as TicketType,
      problemDescription: fields[8] as String,
      actionsTaken: fields[9] as String?,
      status: fields[10] as TicketStatus,
      finalStatus: fields[11] as String?,
      technicianSignature: fields[12] as String?,
      responsibleName: fields[13] as String?,
      responsibleSignature: fields[14] as String?,
      createdAt: fields[15] as DateTime,
      updatedAt: fields[16] as DateTime?,
      technicianName: fields[17] as String?,
      serviceFormNumber: fields[18] as String?,
      assignedTechnicianId: fields[19] as String?,
      priority: fields[20] as String?,
      scheduledAt: fields[21] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, FaultTicket obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.ticketNumber)
      ..writeByte(1)
      ..write(obj.customer)
      ..writeByte(2)
      ..write(obj.device)
      ..writeByte(3)
      ..write(obj.technician)
      ..writeByte(4)
      ..write(obj.reportDateTime)
      ..writeByte(5)
      ..write(obj.startDateTime)
      ..writeByte(6)
      ..write(obj.endDateTime)
      ..writeByte(7)
      ..write(obj.ticketType)
      ..writeByte(8)
      ..write(obj.problemDescription)
      ..writeByte(9)
      ..write(obj.actionsTaken)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.finalStatus)
      ..writeByte(12)
      ..write(obj.technicianSignature)
      ..writeByte(13)
      ..write(obj.responsibleName)
      ..writeByte(14)
      ..write(obj.responsibleSignature)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.updatedAt)
      ..writeByte(17)
      ..write(obj.technicianName)
      ..writeByte(18)
      ..write(obj.serviceFormNumber)
      ..writeByte(19)
      ..write(obj.assignedTechnicianId)
      ..writeByte(20)
      ..write(obj.priority)
      ..writeByte(21)
      ..write(obj.scheduledAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaultTicketAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TicketStatusAdapter extends TypeAdapter<TicketStatus> {
  @override
  final int typeId = 41;

  @override
  TicketStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TicketStatus.pending;
      case 1:
        return TicketStatus.inProgress;
      case 2:
        return TicketStatus.waitingPart;
      case 3:
        return TicketStatus.devicePassive;
      case 4:
        return TicketStatus.completed;
      case 5:
        return TicketStatus.cancelled;
      default:
        return TicketStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, TicketStatus obj) {
    switch (obj) {
      case TicketStatus.pending:
        writer.writeByte(0);
        break;
      case TicketStatus.inProgress:
        writer.writeByte(1);
        break;
      case TicketStatus.waitingPart:
        writer.writeByte(2);
        break;
      case TicketStatus.devicePassive:
        writer.writeByte(3);
        break;
      case TicketStatus.completed:
        writer.writeByte(4);
        break;
      case TicketStatus.cancelled:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TicketStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TicketTypeAdapter extends TypeAdapter<TicketType> {
  @override
  final int typeId = 42;

  @override
  TicketType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TicketType.malfunction;
      case 1:
        return TicketType.installation;
      case 2:
        return TicketType.other;
      default:
        return TicketType.malfunction;
    }
  }

  @override
  void write(BinaryWriter writer, TicketType obj) {
    switch (obj) {
      case TicketType.malfunction:
        writer.writeByte(0);
        break;
      case TicketType.installation:
        writer.writeByte(1);
        break;
      case TicketType.other:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TicketTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
