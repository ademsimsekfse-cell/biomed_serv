// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReportTemplateAdapter extends TypeAdapter<ReportTemplate> {
  @override
  final int typeId = 28;

  @override
  ReportTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReportTemplate(
      name: fields[0] as String,
      description: fields[1] as String?,
      sections: (fields[2] as List?)?.cast<ReportSection>(),
      isDefault: fields[3] as bool,
      style: fields[4] as ReportStyle?,
      isActive: fields[5] as bool,
      layoutType: fields[8] as ReportLayoutType,
    )
      ..createdAt = fields[6] as DateTime
      ..updatedAt = fields[7] as DateTime;
  }

  @override
  void write(BinaryWriter writer, ReportTemplate obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.sections)
      ..writeByte(3)
      ..write(obj.isDefault)
      ..writeByte(4)
      ..write(obj.style)
      ..writeByte(8)
      ..write(obj.layoutType)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReportSectionAdapter extends TypeAdapter<ReportSection> {
  @override
  final int typeId = 29;

  @override
  ReportSection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReportSection(
      type: fields[0] as ReportSectionType,
      isVisible: fields[1] as bool,
      order: fields[2] as int,
      title: fields[3] as String?,
      isRequired: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ReportSection obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.isVisible)
      ..writeByte(2)
      ..write(obj.order)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.isRequired);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportSectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReportStyleAdapter extends TypeAdapter<ReportStyle> {
  @override
  final int typeId = 30;

  @override
  ReportStyle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReportStyle(
      primaryColor: fields[0] as int,
      secondaryColor: fields[1] as int,
      accentColor: fields[2] as int,
      fontFamily: fields[3] as String,
      companyName: fields[4] as String,
      showLogo: fields[5] as bool,
      logoPath: fields[6] as String?,
      logoPosition: fields[7] as LogoPosition,
      showTechnician: fields[8] as bool,
      showCompanyDetails: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ReportStyle obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.primaryColor)
      ..writeByte(1)
      ..write(obj.secondaryColor)
      ..writeByte(2)
      ..write(obj.accentColor)
      ..writeByte(3)
      ..write(obj.fontFamily)
      ..writeByte(4)
      ..write(obj.companyName)
      ..writeByte(5)
      ..write(obj.showLogo)
      ..writeByte(6)
      ..write(obj.logoPath)
      ..writeByte(7)
      ..write(obj.logoPosition)
      ..writeByte(8)
      ..write(obj.showTechnician)
      ..writeByte(9)
      ..write(obj.showCompanyDetails);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportStyleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReportSectionTypeAdapter extends TypeAdapter<ReportSectionType> {
  @override
  final int typeId = 27;

  @override
  ReportSectionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReportSectionType.companyHeader;
      case 1:
        return ReportSectionType.formNumber;
      case 2:
        return ReportSectionType.customerDetail;
      case 3:
        return ReportSectionType.deviceInfo;
      case 4:
        return ReportSectionType.serviceTimes;
      case 5:
        return ReportSectionType.problemDetails;
      case 6:
        return ReportSectionType.actionsTaken;
      case 7:
        return ReportSectionType.finalStatus;
      case 8:
        return ReportSectionType.spareParts;
      case 9:
        return ReportSectionType.signatures;
      case 10:
        return ReportSectionType.maintenancePeriod;
      case 11:
        return ReportSectionType.notes;
      case 12:
        return ReportSectionType.technicianInfo;
      default:
        return ReportSectionType.companyHeader;
    }
  }

  @override
  void write(BinaryWriter writer, ReportSectionType obj) {
    switch (obj) {
      case ReportSectionType.companyHeader:
        writer.writeByte(0);
        break;
      case ReportSectionType.formNumber:
        writer.writeByte(1);
        break;
      case ReportSectionType.customerDetail:
        writer.writeByte(2);
        break;
      case ReportSectionType.deviceInfo:
        writer.writeByte(3);
        break;
      case ReportSectionType.serviceTimes:
        writer.writeByte(4);
        break;
      case ReportSectionType.problemDetails:
        writer.writeByte(5);
        break;
      case ReportSectionType.actionsTaken:
        writer.writeByte(6);
        break;
      case ReportSectionType.finalStatus:
        writer.writeByte(7);
        break;
      case ReportSectionType.spareParts:
        writer.writeByte(8);
        break;
      case ReportSectionType.signatures:
        writer.writeByte(9);
        break;
      case ReportSectionType.maintenancePeriod:
        writer.writeByte(10);
        break;
      case ReportSectionType.notes:
        writer.writeByte(11);
        break;
      case ReportSectionType.technicianInfo:
        writer.writeByte(12);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportSectionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReportLayoutTypeAdapter extends TypeAdapter<ReportLayoutType> {
  @override
  final int typeId = 43;

  @override
  ReportLayoutType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReportLayoutType.classic;
      case 1:
        return ReportLayoutType.modern;
      case 2:
        return ReportLayoutType.minimal;
      case 3:
        return ReportLayoutType.professional;
      case 4:
        return ReportLayoutType.compact;
      default:
        return ReportLayoutType.classic;
    }
  }

  @override
  void write(BinaryWriter writer, ReportLayoutType obj) {
    switch (obj) {
      case ReportLayoutType.classic:
        writer.writeByte(0);
        break;
      case ReportLayoutType.modern:
        writer.writeByte(1);
        break;
      case ReportLayoutType.minimal:
        writer.writeByte(2);
        break;
      case ReportLayoutType.professional:
        writer.writeByte(3);
        break;
      case ReportLayoutType.compact:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportLayoutTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LogoPositionAdapter extends TypeAdapter<LogoPosition> {
  @override
  final int typeId = 44;

  @override
  LogoPosition read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return LogoPosition.top;
      case 1:
        return LogoPosition.left;
      case 2:
        return LogoPosition.right;
      case 3:
        return LogoPosition.center;
      default:
        return LogoPosition.top;
    }
  }

  @override
  void write(BinaryWriter writer, LogoPosition obj) {
    switch (obj) {
      case LogoPosition.top:
        writer.writeByte(0);
        break;
      case LogoPosition.left:
        writer.writeByte(1);
        break;
      case LogoPosition.right:
        writer.writeByte(2);
        break;
      case LogoPosition.center:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogoPositionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
