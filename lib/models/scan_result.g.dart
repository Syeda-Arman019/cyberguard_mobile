// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanResultAdapter extends TypeAdapter<ScanResult> {
  @override
  final int typeId = 0;

  @override
  ScanResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanResult(
      url: fields[0] as String,
      riskScore: fields[1] as int,
      riskLevel: fields[2] as RiskLevel,
      threatType: fields[3] as ThreatType,
      reasons: (fields[4] as List).cast<String>(),
      recommendation: fields[5] as String,
      source: fields[6] as ScanSource,
      timestamp: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ScanResult obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.url)
      ..writeByte(1)
      ..write(obj.riskScore)
      ..writeByte(2)
      ..write(obj.riskLevel)
      ..writeByte(3)
      ..write(obj.threatType)
      ..writeByte(4)
      ..write(obj.reasons)
      ..writeByte(5)
      ..write(obj.recommendation)
      ..writeByte(6)
      ..write(obj.source)
      ..writeByte(7)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RiskLevelAdapter extends TypeAdapter<RiskLevel> {
  @override
  final int typeId = 1;

  @override
  RiskLevel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RiskLevel.safe;
      case 1:
        return RiskLevel.suspicious;
      case 2:
        return RiskLevel.malicious;
      default:
        return RiskLevel.safe;
    }
  }

  @override
  void write(BinaryWriter writer, RiskLevel obj) {
    switch (obj) {
      case RiskLevel.safe:
        writer.writeByte(0);
        break;
      case RiskLevel.suspicious:
        writer.writeByte(1);
        break;
      case RiskLevel.malicious:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiskLevelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ThreatTypeAdapter extends TypeAdapter<ThreatType> {
  @override
  final int typeId = 2;

  @override
  ThreatType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ThreatType.none;
      case 1:
        return ThreatType.phishing;
      case 2:
        return ThreatType.malware;
      case 3:
        return ThreatType.suspiciousDomain;
      case 4:
        return ThreatType.brandImpersonation;
      default:
        return ThreatType.none;
    }
  }

  @override
  void write(BinaryWriter writer, ThreatType obj) {
    switch (obj) {
      case ThreatType.none:
        writer.writeByte(0);
        break;
      case ThreatType.phishing:
        writer.writeByte(1);
        break;
      case ThreatType.malware:
        writer.writeByte(2);
        break;
      case ThreatType.suspiciousDomain:
        writer.writeByte(3);
        break;
      case ThreatType.brandImpersonation:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreatTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ScanSourceAdapter extends TypeAdapter<ScanSource> {
  @override
  final int typeId = 3;

  @override
  ScanSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ScanSource.manual;
      case 1:
        return ScanSource.qr;
      case 2:
        return ScanSource.share;
      case 3:
        return ScanSource.autoProtection;
      default:
        return ScanSource.manual;
    }
  }

  @override
  void write(BinaryWriter writer, ScanSource obj) {
    switch (obj) {
      case ScanSource.manual:
        writer.writeByte(0);
        break;
      case ScanSource.qr:
        writer.writeByte(1);
        break;
      case ScanSource.share:
        writer.writeByte(2);
        break;
      case ScanSource.autoProtection:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
