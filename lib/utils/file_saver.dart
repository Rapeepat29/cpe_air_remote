import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as picker;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

enum FileSaveStatus {
  /// บันทึกลงที่ที่ผู้ใช้เลือกแล้ว
  saved,

  /// ส่งเข้าเมนูแชร์ของเครื่องแล้ว ผู้ใช้เลือกปลายทางเอง
  shared,

  /// ผู้ใช้กดยกเลิกเอง ไม่ใช่ข้อผิดพลาด
  cancelled,

  /// บันทึกไม่สำเร็จ
  failed,
}

class FileSaveResult {
  const FileSaveResult(this.status, {this.path, this.error});

  final FileSaveStatus status;
  final String? path;
  final String? error;

  bool get isSuccess =>
      status == FileSaveStatus.saved || status == FileSaveStatus.shared;
}

/// บันทึกไฟล์ที่ Backend สร้างมาให้ลงเครื่องของผู้ใช้
///
/// Windows กับเครื่องเดสก์ท็อปอื่นเปิดกล่อง `บันทึกเป็น` ให้เลือกโฟลเดอร์ได้
/// ส่วน Android กับ iOS ไม่มีกล่องแบบนั้น จึงเขียนลงพื้นที่ชั่วคราวของแอป
/// แล้วเปิดเมนูแชร์ให้ผู้ใช้เลือกเองว่าจะเก็บลงไฟล์ ส่งไลน์ หรือส่งอีเมล
Future<FileSaveResult> saveExportFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  final safeName = sanitizeFileName(fileName);

  try {
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}$safeName');
      await file.writeAsBytes(bytes, flush: true);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: _xlsxMimeType)],
          subject: safeName,
        ),
      );

      if (result.status == ShareResultStatus.dismissed) {
        return const FileSaveResult(FileSaveStatus.cancelled);
      }
      return FileSaveResult(FileSaveStatus.shared, path: file.path);
    }

    final location = await picker.getSaveLocation(
      suggestedName: safeName,
      acceptedTypeGroups: const [
        picker.XTypeGroup(
          label: 'Excel',
          extensions: ['xlsx'],
          mimeTypes: [_xlsxMimeType],
        ),
      ],
    );
    if (location == null) {
      return const FileSaveResult(FileSaveStatus.cancelled);
    }

    final path = location.path.toLowerCase().endsWith('.xlsx')
        ? location.path
        : '${location.path}.xlsx';
    await File(path).writeAsBytes(bytes, flush: true);
    return FileSaveResult(FileSaveStatus.saved, path: path);
  } catch (error) {
    return FileSaveResult(FileSaveStatus.failed, error: error.toString());
  }
}

/// ตัดอักขระที่ระบบไฟล์ไม่รับออก ชื่อภาษาไทยยังใช้ได้ตามปกติ
String sanitizeFileName(String value) {
  final trimmed = value.trim();
  final cleaned = trimmed
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ');
  final name = cleaned.isEmpty ? 'energy-export.xlsx' : cleaned;
  return name.toLowerCase().endsWith('.xlsx') ? name : '$name.xlsx';
}
