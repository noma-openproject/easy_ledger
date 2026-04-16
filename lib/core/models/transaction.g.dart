// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 1;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String,
      receiptId: fields[1] as String?,
      date: fields[2] as DateTime,
      time: fields[3] as String?,
      storeName: fields[4] as String,
      businessNumber: fields[5] as String?,
      total: fields[6] as int,
      tax: fields[7] as int?,
      paymentMethod: fields[8] as String,
      category: fields[9] as String,
      expenseType: fields[10] as String,
      taxCategory: fields[11] as String?,
      memo: fields[12] as String?,
      syncedToSheet: fields[13] as bool,
      createdAt: fields[14] as DateTime,
      sheetRowIndex: fields[15] as int?,
      sheetSyncedAt: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.receiptId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.time)
      ..writeByte(4)
      ..write(obj.storeName)
      ..writeByte(5)
      ..write(obj.businessNumber)
      ..writeByte(6)
      ..write(obj.total)
      ..writeByte(7)
      ..write(obj.tax)
      ..writeByte(8)
      ..write(obj.paymentMethod)
      ..writeByte(9)
      ..write(obj.category)
      ..writeByte(10)
      ..write(obj.expenseType)
      ..writeByte(11)
      ..write(obj.taxCategory)
      ..writeByte(12)
      ..write(obj.memo)
      ..writeByte(13)
      ..write(obj.syncedToSheet)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.sheetRowIndex)
      ..writeByte(16)
      ..write(obj.sheetSyncedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
