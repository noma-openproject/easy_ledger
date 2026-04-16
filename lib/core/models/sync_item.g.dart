// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncItemAdapter extends TypeAdapter<SyncItem> {
  @override
  final int typeId = 4;

  @override
  SyncItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncItem(
      id: fields[0] as String,
      transactionId: fields[1] as String,
      createdAt: fields[2] as DateTime,
      retryCount: fields[3] as int,
      lastError: fields[4] as String?,
      operation: fields[5] as String,
      preferredSheetRowIndex: fields[6] as int?,
      fallbackDateText: fields[7] as String?,
      fallbackTime: fields[8] as String?,
      fallbackStoreName: fields[9] as String?,
      fallbackTotal: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, SyncItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.transactionId)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.retryCount)
      ..writeByte(4)
      ..write(obj.lastError)
      ..writeByte(5)
      ..write(obj.operation)
      ..writeByte(6)
      ..write(obj.preferredSheetRowIndex)
      ..writeByte(7)
      ..write(obj.fallbackDateText)
      ..writeByte(8)
      ..write(obj.fallbackTime)
      ..writeByte(9)
      ..write(obj.fallbackStoreName)
      ..writeByte(10)
      ..write(obj.fallbackTotal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
