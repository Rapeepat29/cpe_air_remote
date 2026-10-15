import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('th'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('th'));
  }

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  bool get isThai => locale.languageCode == 'th';

  String translate(String source) {
    if (source.isEmpty) {
      return source;
    }

    return isThai ? _translateToThai(source) : _translateToEnglish(source);
  }

  String _translateToThai(String source) {
    final exact = _thaiTranslations[source];
    if (exact != null) {
      return exact;
    }

    RegExpMatch? match;

    match = RegExp(r'^On for (\d+) of (\d+) types$').firstMatch(source);
    if (match != null) {
      return 'เปิดรับ ${match[1]} จาก ${match[2]} ประเภท';
    }

    match = RegExp(r'^Room ([A-Z0-9_-]+) \((.+)\)$').firstMatch(source);
    if (match != null) {
      return 'ห้อง ${match[1]} (${_translateToThai(match[2]!)})';
    }

    match = RegExp(
      r'^Floor (\d+) · Room ([A-Z0-9_-]+)$',
    ).firstMatch(source);
    if (match != null) {
      return 'ชั้น ${match[1]} · ห้อง ${match[2]}';
    }

    match = RegExp(
      r'^Room ([A-Z0-9_-]+) · Unit (\d+)$',
    ).firstMatch(source);
    if (match != null) {
      return 'ห้อง ${match[1]} · เครื่องที่ ${match[2]}';
    }

    match = RegExp(
      r'^Room ([A-Z0-9_-]+) · (Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday)$',
    ).firstMatch(source);
    if (match != null) {
      return 'ห้อง ${match[1]} · ${_translateToThai(match[2]!)}';
    }

    match = RegExp(r'^Room ([A-Z0-9_-]+)$').firstMatch(source);
    if (match != null) {
      return 'ห้อง ${match[1]}';
    }

    match = RegExp(r'^Floor (\d+)$').firstMatch(source);
    if (match != null) {
      return 'ชั้น ${match[1]}';
    }

    match = RegExp(r'^Type: (.+)$').firstMatch(source);
    if (match != null) {
      return 'ประเภท: ${_translateToThai(match[1]!)}';
    }

    match = RegExp(r'^(\d+)/6 units$').firstMatch(source);
    if (match != null) {
      return '${match[1]}/6 เครื่อง';
    }

    match = RegExp(r'^(\d+) units$').firstMatch(source);
    if (match != null) {
      return '${match[1]} เครื่อง';
    }

    match = RegExp(r'^(\d+) rooms$').firstMatch(source);
    if (match != null) {
      return '${match[1]} ห้อง';
    }

    match = RegExp(r'^(\d+) hours stored$').firstMatch(source);
    if (match != null) {
      return 'เก็บไว้ ${match[1]} ชั่วโมง';
    }

    match = RegExp(r'^(\d+) need attention$').firstMatch(source);
    if (match != null) {
      return 'ต้องจัดการ ${match[1]} รายการ';
    }

    match = RegExp(r'^Turn (.+) On$').firstMatch(source);
    if (match != null) {
      return 'เปิด ${match[1]}';
    }

    match = RegExp(r'^Turn (.+) Off$').firstMatch(source);
    if (match != null) {
      return 'ปิด ${match[1]}';
    }

    match = RegExp(r'^Remove (.+) from this room\?$').firstMatch(source);
    if (match != null) {
      return 'นำ ${match[1]} ออกจากห้องนี้หรือไม่?';
    }

    match = RegExp(r'^(.+) added \(mock data\)$').firstMatch(source);
    if (match != null) {
      return 'เพิ่ม ${match[1]} แล้ว (ข้อมูลจำลอง)';
    }

    match = RegExp(r'^(.+) \(mock data\)$').firstMatch(source);
    if (match != null) {
      return '${_translateToThai(match[1]!)} (ข้อมูลจำลอง)';
    }

    match = RegExp(r'^Mock command sent to (.+)$').firstMatch(source);
    if (match != null) {
      return 'ส่งคำสั่งจำลองไปยัง ${match[1]} แล้ว';
    }

    match = RegExp(r'^(.+) is a UI preview for testing\.$').firstMatch(source);
    if (match != null) {
      return '${_translateToThai(match[1]!)} เป็นหน้าตัวอย่างสำหรับทดสอบ UI';
    }

    match = RegExp(r'^★ (.+)$').firstMatch(source);
    if (match != null) {
      return '★ ${_translateToThai(match[1]!)}';
    }

    match = RegExp(r'^(\d+) hr$').firstMatch(source);
    if (match != null) {
      return '${match[1]} ชม.';
    }

    match = RegExp(r'^(\d+) min$').firstMatch(source);
    if (match != null) {
      return '${match[1]} นาที';
    }

    match = RegExp(
      r'^Estimated cost: THB ([0-9,]+\.[0-9]{2})$',
    ).firstMatch(source);
    if (match != null) {
      return 'ค่าไฟโดยประมาณ: ${match[1]} บาท';
    }

    match = RegExp(r'^≈ THB ([0-9,]+\.[0-9]{2})$').firstMatch(source);
    if (match != null) {
      return '≈ ${match[1]} บาท';
    }

    match = RegExp(r'^(\d+) hr (\d+) min$').firstMatch(source);
    if (match != null) {
      return '${match[1]} ชม. ${match[2]} นาที';
    }

    match = RegExp(
      r'^Add the first class for Room ([A-Z0-9_-]+) on (.+)\.$',
    ).firstMatch(source);
    if (match != null) {
      return 'เพิ่มวิชาแรกสำหรับห้อง ${match[1]} ในวัน'
          '${_translateToThai(match[2]!)}';
    }

    match = RegExp(r'^(.+) · Fan (.+)$').firstMatch(source);
    if (match != null) {
      return '${_translateToThai(match[1]!)} · พัดลม '
          '${_translateToThai(match[2]!)}';
    }

    match = RegExp(r'^(\d{1,2}):(\d{2}) (AM|PM)$').firstMatch(source);
    if (match != null) {
      var hour = int.parse(match[1]!);
      final minute = match[2]!;
      final period = match[3]!;
      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
      return '${hour.toString().padLeft(2, '0')}:$minute น.';
    }

    return source;
  }

  String _translateToEnglish(String source) {
    return _englishTranslations[source] ?? source;
  }
}

extension AppLocalizationsBuildContext on BuildContext {
  String tr(String source) => AppLocalizations.of(this).translate(source);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const _thaiTranslations = <String, String>{
  // บอร์ดสายแอร์ / ยี่ห้อแอร์ (v3.16.0)
  'Wired': 'สายแอร์',
  'IR remote': 'รีโมต IR',
  'Controlled through the air-conditioner cable in place of the wall remote':
      'สั่งงานผ่านสายแอร์ แทนรีโมตติดผนัง',
  'Controlled by infrared, like a handheld remote':
      'สั่งงานด้วยอินฟราเรด เหมือนรีโมตแบบถือ',
  'This unit is controlled through its cable, so only the functions of the Daikin wall remote are available.':
      'เครื่องนี้สั่งผ่านสายแอร์ จึงใช้ได้เฉพาะฟังก์ชันที่รีโมตติดผนัง Daikin มี',
  'Board type: wired controller (replaces the wall remote)':
      'ชนิดบอร์ด: ควบคุมผ่านสายแอร์ (ใช้แทนรีโมตติดผนัง)',
  'Board type: IR remote': 'ชนิดบอร์ด: รีโมต IR',
  'Set by the board': 'บอร์ดกำหนดให้',
  'Wired (replaces the wall remote)': 'สายแอร์ (ใช้แทนรีโมตติดผนัง)',
  'This board plugs into the air-conditioner cable in place of the Daikin wall remote. Available: on/off, 16–30 °C, Cool / Dry / Fan, fan Low / Medium / High / Auto, swing on/off and Sleep.':
      'บอร์ดนี้ต่อเข้ากับสายแอร์แทนรีโมตติดผนัง Daikin ใช้ได้: เปิด/ปิด, 16–30 °C, Cool / Dry / Fan, พัดลม Low / Medium / High / Auto, ส่าย เปิด/ปิด และ Sleep',
  // หน้าตั้งค่าการแจ้งเตือนแยกตามชนิด (v3.12.0)
  'Alerts by type': 'แจ้งเตือนแยกตามชนิด',
  // นำเข้าตารางเรียน: ช่วงวันที่ใช้ตาราง
  'Use day/month/year, e.g. 01/06/2569': 'ใช้รูปแบบ วัน/เดือน/ปี พ.ศ. เช่น 01/06/2569',
  'Choose a date between': 'เลือกวันที่ระหว่าง',
  'The last day must not be before the first day': 'วันสุดท้ายต้องไม่อยู่ก่อนวันแรก',
  'Tap a date': 'แตะเลือกวันที่',
  'Tap the first day': 'แตะเลือกวันแรก',
  'Choose a date range': 'เลือกช่วงวันที่',
  'Choose a date': 'เลือกวันที่',
  'Type the date': 'พิมพ์วันที่',
  'Pick from calendar': 'เลือกจากปฏิทิน',
  'First day': 'วันแรก',
  'Last day': 'วันสุดท้าย',
  'Tap the first day of the semester': 'แตะเลือกวันเปิดภาคเรียน',
  'tap the last day': 'แตะเลือกวันปิดภาค',
  'Previous month': 'เดือนก่อนหน้า',
  'Next month': 'เดือนถัดไป',
  'Semester dates': 'วันเปิด-ปิดภาคเรียน',
  'Period this timetable applies to': 'ช่วงเวลาที่ใช้ตารางนี้',
  'Outside these dates the system treats every room as having no classes, for example during the semester break.': 'นอกช่วงวันที่นี้ ระบบจะถือว่าทุกห้องไม่มีคาบเรียน เช่น ช่วงปิดภาคเรียน',
  'Use semester/year, e.g. 1/2569': 'ใช้รูปแบบ ภาคเรียน/ปีการศึกษา เช่น 1/2569',
  'Choose the first and last day': 'เลือกวันเปิดภาคและวันปิดภาค',
  'Choose the semester dates first': 'เลือกช่วงวันที่ของภาคเรียนก่อน',
  // หน้าห้อง: การ์ดสรุปและการ์ดแอร์แบบใหม่
  'Running now': 'กำลังทำงาน',
  'Switched off': 'ปิดอยู่',
  'Lower temperature': 'ลดอุณหภูมิ',
  'Raise temperature': 'เพิ่มอุณหภูมิ',
  'Power now': 'กำลังไฟขณะนี้',
  'Accumulated': 'สะสม',
  'Turn off': 'ปิดเครื่อง',
  'Turn on': 'เปิดเครื่อง',
  'Mode': 'โหมด',
  'Swing': 'สวิง',
  'More': 'เพิ่มเติม',
  'Awaiting confirmation': 'รอการยืนยัน',
  'Not connected to MQTT': 'ยังไม่ได้เชื่อมต่อ MQTT',
  'Commands and power readings are unavailable. Check the ESP32 power supply and Wi-Fi signal.': 'ยังสั่งงานและอ่านกำลังไฟของเครื่องนี้ไม่ได้ ตรวจสอบไฟเลี้ยงของ ESP32 และสัญญาณ Wi‑Fi',
  'Set up again via Bluetooth': 'ตั้งค่าใหม่ผ่านบลูทูธ',
  'Try again': 'ลองอีกครั้ง',
  'Air conditioner list': 'รายการเครื่องปรับอากาศ',
  'Air conditioners running': 'เครื่องปรับอากาศที่เปิดอยู่',
  'Total power': 'กำลังไฟรวม',
  'of': 'จาก',
  'Control mode': 'โหมดควบคุม',
  'MQTT (real devices)': 'MQTT (อุปกรณ์จริง)',
  'Occupancy sensor': 'เซนเซอร์ตรวจจับคน',
  'Not installed': 'ยังไม่ได้ติดตั้ง',
  'Sensor offline': 'เซนเซอร์ออฟไลน์',
  'Radar data unavailable': 'ไม่มีข้อมูลเรดาร์',
  'People detected': 'พบคนในห้อง',
  'No people detected': 'ไม่พบคนในห้อง',
  'Add ESP32 device': 'เพิ่มอุปกรณ์ ESP32',
  'This room has no ESP32 device yet': 'ยังไม่มีอุปกรณ์ ESP32 ในห้องนี้',
  'Find the device via Bluetooth to set up Wi-Fi and MQTT.': 'ค้นหาอุปกรณ์ผ่านบลูทูธ เพื่อตั้งค่า Wi‑Fi และ MQTT',
  // หน้าตั้งค่าแอปและหน้าตั้งค่าการแจ้งเตือน (รายการเรียบ ใช้ถ้อยคำทางการ)
  'General': 'ทั่วไป',
  'Text display': 'การแสดงผลตัวอักษร',
  'For administrators': 'สำหรับผู้ดูแลระบบ',
  'Notifications': 'การแจ้งเตือน',
  'All notifications are off': 'ปิดการแจ้งเตือนทั้งหมด',
  'Notification settings': 'ตั้งค่าการแจ้งเตือน',
  'Allow notifications': 'รับการแจ้งเตือน',
  'Receive notifications on this device for the types selected below.': 'รับการแจ้งเตือนบนอุปกรณ์นี้ตามประเภทที่เลือกไว้ด้านล่าง',
  'Notification types': 'ประเภทการแจ้งเตือน',
  'All notifications remain available in the app.': 'รายการแจ้งเตือนทั้งหมดยังคงแสดงในแอปพลิเคชันตามปกติ',
  'Choose the display language': 'เลือกภาษาที่ใช้แสดงผล',
  'Choose a theme': 'เลือกธีม',
  'Applies to every screen and follows the text size set on this device.': 'มีผลกับทุกหน้า และปรับตามขนาดตัวอักษรที่ตั้งไว้ในอุปกรณ์',
  'Sample text: Room 16103 is using 1.20 kWh': 'ตัวอย่างข้อความ: ห้อง 16103 ใช้พลังงานไฟฟ้า 1.20 kWh',
  'When an air conditioner runs in an empty room, the system counts down 5 minutes and then sends the off command.': 'เมื่อแอร์ทำงานแต่ไม่มีผู้ใช้ห้อง ระบบจะนับถอยหลัง 5 นาที แล้วส่งคำสั่งปิด',
  'Only administrators can change this setting because it applies to the whole building.': 'เฉพาะผู้ดูแลระบบเท่านั้นที่เปลี่ยนการตั้งค่านี้ได้ เนื่องจากมีผลกับทั้งอาคาร',
  'This applies to every room. No countdown or off command will run until it is turned back on.': 'มีผลกับทุกห้อง ระบบจะไม่นับถอยหลังและไม่ส่งคำสั่งปิดจนกว่าจะเปิดใช้งานอีกครั้ง',
  'The setting could not be saved. Please try again.': 'บันทึกการตั้งค่าไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
  'In the app': 'ในแอป',
  'On this phone': 'บนอุปกรณ์นี้',
  // สวิตช์รวมของระบบปิดแอร์อัตโนมัติ (v3.10.0)
  'AUTOMATIC SHUTDOWN': 'ระบบปิดแอร์อัตโนมัติ',
  'Switch air conditioners off automatically': 'ปิดแอร์อัตโนมัติเมื่อห้องว่าง',
  'Counts down 5 minutes when a room is empty with the air conditioner running, then sends the off signal.': 'เมื่อแอร์ทำงานอยู่แต่ไม่มีคนในห้อง จะนับถอยหลัง 5 นาที แล้วส่งสัญญาณปิด',
  'Only an admin can change this. It applies to the whole building.': 'เฉพาะผู้ดูแลระบบเท่านั้นที่เปลี่ยนการตั้งค่านี้ได้ เนื่องจากมีผลกับทั้งอาคาร',
  'Every room is affected. No countdown runs and nothing is switched off until this is turned back on.': 'มีผลกับทุกห้อง จะไม่มีการนับถอยหลังและไม่มีการสั่งปิด จนกว่าจะเปิดใหม่',
  'Could not save the setting. Please try again.': 'บันทึกค่าไม่สำเร็จ ลองใหม่อีกครั้ง',
  // ตั้งค่าขนาดตัวอักษรและการแจ้งเตือน (v3.10.0)
  'TEXT SIZE': 'ขนาดตัวอักษร',
  'NOTIFICATIONS': 'การแจ้งเตือน',
  'Text size': 'ขนาดตัวอักษร',
  'Applies to every screen. It is combined with the size set on your phone.': 'มีผลกับทุกหน้าจอ และคูณกับขนาดที่ตั้งไว้ในเครื่องของคุณอีกที',
  'Small': 'เล็ก',
  'Normal': 'ปกติ',
  'Large': 'ใหญ่',
  'Extra large': 'ใหญ่มาก',
  'Sample: room 16103 is using 1.20 kWh right now': 'ตัวอย่าง: ห้อง 16103 กำลังใช้ไฟ 1.20 kWh',
  'Alert me on this phone': 'รับการแจ้งเตือนบนอุปกรณ์นี้',
  'Running outside class hours': 'แอร์ทำงานนอกเวลาเรียน',
  'Air conditioner switched off': 'ปิดแอร์อัตโนมัติสำเร็จ',
  'Automatic shutdown failed': 'ปิดแอร์อัตโนมัติไม่สำเร็จ',
  'Configure ESP32 via Bluetooth': 'ตั้งค่า ESP32 ผ่านบลูทูธ',
  'Reconfigure ESP32 via Bluetooth': 'ตั้งค่าบอร์ด',
  'The app could not request Bluetooth setup through MQTT. The ESP32 may already be in recovery mode; try searching. If it is not found, hold BOOT and press RESET.':
      'แอปสั่งให้ ESP32 เปิดโหมดตั้งค่าผ่าน MQTT ไม่สำเร็จ บอร์ดอาจอยู่ในโหมดกู้คืนแล้ว ให้ลองค้นหาก่อน หากยังไม่พบให้กด BOOT ค้างแล้วกด RESET',
  'Reconfigure via Bluetooth': 'ตั้งค่าบอร์ด',
  'Find nearby RMUTT ESP32': 'ค้นหา ESP32 ของ RMUTT ที่อยู่ใกล้',
  'Search Bluetooth': 'ค้นหาบลูทูธ',
  'Searching...': 'กำลังค้นหา...',
  'Connecting and checking ESP32...':
      'กำลังเชื่อมต่อและตรวจสอบ ESP32...',
  'Try connecting again': 'ลองเชื่อมต่ออีกครั้ง',
  'Turn on the ESP32 in setup mode. Its name must start with RMUTT-AC-.':
      'เปิด ESP32 ในโหมดตั้งค่า โดยชื่อต้องขึ้นต้นด้วย RMUTT-AC-',
  'Could not finish the Bluetooth connection after 3 attempts. Restart the ESP32 and try again.':
      'เชื่อมต่อบลูทูธไม่สำเร็จหลังลอง 3 ครั้ง ให้กด EN/RESET บน ESP32 แล้วลองอีกครั้ง',
  'RMUTT ESP32 service was not found after connecting.':
      'เชื่อมต่อบลูทูธแล้ว แต่ไม่พบ RMUTT ESP32 Service กรุณาแฟลชเฟิร์มแวร์ 1.6.0 แล้วลองใหม่',
  'ESP32 Bluetooth characteristics are incomplete.':
      'ข้อมูล Bluetooth Characteristic ของ ESP32 ไม่ครบ กรุณาแฟลชเฟิร์มแวร์ 1.6.0 แล้วลองใหม่',
  'ESP32 returned invalid identity data.':
      'ESP32 ส่งข้อมูลตัวตนกลับมาไม่ถูกต้อง',
  'Bluetooth name and ESP32 Device ID do not match.':
      'ชื่อบลูทูธกับ Device ID ของ ESP32 ไม่ตรงกัน',
  'Bluetooth Low Energy is not supported on this computer.':
      'คอมพิวเตอร์เครื่องนี้ไม่รองรับ Bluetooth Low Energy',
  'Please turn on Bluetooth and try again.':
      'กรุณาเปิดบลูทูธแล้วลองใหม่',
  'Select room and air conditioner number': 'เลือกห้องและหมายเลขแอร์',
  'Room': 'ห้อง',
  'Air number': 'หมายเลขแอร์',
  'Unit': 'เครื่องที่',
  'IRremoteESP8266 protocol': 'โปรโตคอลแอร์ IRremoteESP8266',
  'Air Conditioner Brand / Protocol': 'ยี่ห้อแอร์ / โปรโตคอล',
  'Wi-Fi and MQTT settings': 'ตั้งค่า Wi-Fi และ MQTT',
  'Select Wi-Fi and enter its password': 'เลือก Wi-Fi และกรอกรหัสผ่าน',
  'Wi-Fi name (SSID)': 'ชื่อ Wi-Fi (SSID)',
  'Wi-Fi password': 'รหัสผ่าน Wi-Fi',
  'Leave blank to keep the password already saved on ESP32.':
      'เว้นว่างไว้เพื่อใช้รหัสผ่านเดิมที่บันทึกอยู่ใน ESP32',
  'Tap the scan button to view Wi-Fi detected by this ESP32.':
      'กดปุ่มสแกนเพื่อดู Wi-Fi ที่ ESP32 ตัวนี้ตรวจพบ',
  'Tap to select Wi-Fi detected by this ESP32.':
      'แตะเพื่อเลือก Wi-Fi ที่ ESP32 ตัวนี้ตรวจพบ',
  'Scan nearby Wi-Fi': 'สแกน Wi-Fi ใกล้เคียง',
  'Use the LAN IP of the computer running MQTT, not 127.0.0.1.':
      'ใช้ LAN IP ของคอมที่เปิด MQTT เช่น 192.168.1.153 ห้ามใช้ 127.0.0.1',
  'Clear MQTT Host': 'ล้างค่า MQTT Host',
  'Wi-Fi detected by ESP32': 'Wi-Fi ที่ ESP32 ตรวจพบ',
  'Select and verify an ESP32 before scanning Wi-Fi.':
      'เลือกและตรวจสอบ ESP32 ก่อนสแกน Wi-Fi',
  'No Wi-Fi network was detected. You can enter the SSID manually.':
      'ไม่พบเครือข่าย Wi-Fi กรุณาขยับ ESP32 ให้ใกล้เราเตอร์แล้วสแกนอีกครั้ง',
  'If the network is hidden, close this list and enter its SSID manually.':
      'หากเป็นเครือข่ายซ่อน ให้ปิดรายการนี้แล้วพิมพ์ชื่อ SSID เอง',
  'Only Wi-Fi detected by this ESP32 can be selected.':
      'เลือกได้เฉพาะ Wi-Fi ที่ ESP32 ตัวนี้ตรวจพบ',
  'Update the ESP32 firmware before scanning nearby Wi-Fi.':
      'อัปเดตเฟิร์มแวร์ ESP32 ก่อนสแกน Wi-Fi ใกล้เคียง',
  'ESP32 Wi-Fi scan timed out. Please try again.':
      'ESP32 สแกน Wi-Fi ไม่ทันเวลา กรุณาลองใหม่',
  'ESP32 could not scan Wi-Fi.': 'ESP32 ไม่สามารถสแกน Wi-Fi ได้',
  'ESP32 returned invalid Wi-Fi scan data.':
      'ESP32 ส่งข้อมูลการสแกน Wi-Fi ไม่ถูกต้อง',
  'Enter at least 8 characters': 'กรอกอย่างน้อย 8 ตัวอักษร',
  'Invalid port': 'พอร์ตไม่ถูกต้อง',
  'MQTT username': 'ชื่อผู้ใช้ MQTT',
  'MQTT password': 'รหัสผ่าน MQTT',
  'Leave blank to keep the MQTT password already saved on ESP32.':
      'เว้นว่างไว้เพื่อใช้รหัสผ่าน MQTT เดิมที่บันทึกอยู่ใน ESP32',
  'MQTT is configured automatically by the server. No MQTT settings are required here.':
      'ระบบตั้งค่า MQTT จากเซิร์ฟเวอร์ให้อัตโนมัติ ไม่ต้องกรอกค่า MQTT ในหน้านี้',
  'Daily automatic schedule (optional)': 'เวลาเปิด–ปิดอัตโนมัติรายวัน (ไม่บังคับ)',
  'Auto On': 'เวลาเปิด',
  'Auto Off': 'เวลาปิด',
  'Saving to ESP32...': 'กำลังบันทึกลง ESP32...',
  'Save configuration to ESP32': 'บันทึกการตั้งค่าลง ESP32',
  'The app checks the database for duplicate room/unit and Device ID before writing to ESP32.':
      'แอปจะตรวจห้อง/หมายเลขแอร์และ Device ID ที่ซ้ำในฐานข้อมูลก่อนเขียนลง ESP32',
  'No RMUTT ESP32 was found nearby.': 'ไม่พบ ESP32 ของ RMUTT ในบริเวณใกล้เคียง',
  'Select and verify an ESP32 before saving.':
      'เลือกและตรวจสอบ ESP32 ก่อนบันทึก',
  'Select the same ESP32 that is already assigned to this air conditioner.':
      'กรุณาเลือก ESP32 ตัวเดิมที่กำหนดให้แอร์เครื่องนี้',
  'Configuration saved. ESP32 is connecting to Wi-Fi and MQTT.':
      'บันทึกการตั้งค่าแล้ว ESP32 กำลังเชื่อมต่อ Wi-Fi และ MQTT',
  'Wi-Fi verified and configuration saved. ESP32 is connecting to MQTT.':
      'ตรวจสอบ Wi-Fi และบันทึกการตั้งค่าแล้ว ESP32 กำลังเชื่อมต่อ MQTT',
  'Unable to connect to Wi-Fi. Check the SSID and password, then try again.':
      'เชื่อมต่อ Wi-Fi ไม่สำเร็จ กรุณาตรวจชื่อ SSID และรหัสผ่าน แล้วลองบันทึกอีกครั้ง',
  'Wi-Fi recovery: only Wi-Fi can change. Hold BOOT and reset to change room or server.':
      'บอร์ดอยู่ในโหมดกู้ Wi-Fi แก้ได้เฉพาะ Wi-Fi ถ้าจะเปลี่ยนห้องหรือเซิร์ฟเวอร์ ให้กดปุ่ม BOOT ค้างไว้แล้วกดรีเซ็ตบอร์ด',
  'Correct the Wi-Fi password and press Save again. You do not need to scan for the ESP32 again.':
      'แก้รหัสผ่าน Wi-Fi แล้วกดบันทึกซ้ำได้ทันที ไม่ต้องสแกนหา ESP32 ใหม่',
  'ESP32 did not finish testing Wi-Fi or saving the configuration.':
      'ESP32 ทดสอบ Wi-Fi หรือบันทึกการตั้งค่าไม่เสร็จภายในเวลาที่กำหนด',
  'This field is required': 'จำเป็นต้องกรอกช่องนี้',
  'Refresh devices': 'รีเฟรชอุปกรณ์',
  'ESP32 online': 'ESP32 ออนไลน์',
  'MQTT': 'MQTT',
  'Real control': 'ควบคุมจริง',
  'Add ESP32 Air Conditioner': 'เพิ่มแอร์ด้วย ESP32',
  'This room has no registered ESP32 yet':
      'ห้องนี้ยังไม่มี ESP32 ที่ลงทะเบียน',
  'Find the board via Bluetooth to configure Wi-Fi and MQTT.':
      'ค้นหาบอร์ดผ่านบลูทูธเพื่อตั้งค่า Wi-Fi และ MQTT',
  'An administrator must configure the ESP32 via Bluetooth.':
      'ผู้ดูแลระบบต้องตั้งค่า ESP32 ผ่านบลูทูธ',
  'Find ESP32': 'ค้นหา ESP32',
  'Waiting for MQTT activation': 'กำลังรอยืนยันผ่าน MQTT',
  'MQTT command sent successfully': 'ส่งคำสั่งผ่าน MQTT สำเร็จ',
  'Rename': 'เปลี่ยนชื่อ',
  'Remove Unit': 'นำเครื่องออก',
  'Full Remote': 'รีโมตแบบเต็ม',
  'Operating mode': 'โหมดการทำงาน',
  'Fan speed': 'ความเร็วพัดลม',
  'Vertical swing': 'สวิงแนวตั้ง',
  'Additional functions': 'ฟังก์ชันเพิ่มเติม',
  'Horizontal Swing': 'สวิงแนวนอน',
  'Eco': 'ประหยัดพลังงาน',
  'Turbo': 'เทอร์โบ',
  'Sleep': 'โหมดนอน',
  'Quiet': 'โหมดเงียบ',
  'Display Light': 'ไฟหน้าจอ',
  'Clean': 'ทำความสะอาด',
  'Send command via MQTT': 'ส่งคำสั่งผ่าน MQTT',
  'Open Full Remote': 'เปิดรีโมตแบบเต็ม',
  'Voltage': 'แรงดัน',
  'Current': 'กระแส',
  'Power': 'กำลังไฟ',
  'Online': 'ออนไลน์',
  'Offline': 'ออฟไลน์',
  'Something went wrong. Please try again.':
      'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
  'Could not remove the saved login details.':
      'ไม่สามารถลบข้อมูลเข้าสู่ระบบที่บันทึกไว้ได้',
  'Sign In': 'เข้าสู่ระบบ',
  'Enter your username and password': 'กรอกชื่อผู้ใช้และรหัสผ่าน',
  'Username': 'ชื่อผู้ใช้',
  'Enter your username': 'กรุณากรอกชื่อผู้ใช้',
  'Password': 'รหัสผ่าน',
  'Show password': 'แสดงรหัสผ่าน',
  'Hide password': 'ซ่อนรหัสผ่าน',
  'Enter your password': 'กรุณากรอกรหัสผ่าน',
  'Remember password': 'จดจำรหัสผ่าน',
  'Remember username': 'จดจำชื่อผู้ใช้',
  'Recommended for personal devices only': 'แนะนำให้ใช้เฉพาะเครื่องส่วนตัว',
  'Forgot password?': 'ลืมรหัสผ่าน?',
  'Contact Admin': 'ติดต่อผู้ดูแลระบบ',
  'Building 16 · Computer Engineering': 'อาคาร 16 · วิศวกรรมคอมพิวเตอร์',
  'Could not load the administrator contact details.':
      'ไม่สามารถโหลดข้อมูลติดต่อผู้ดูแลระบบได้',
  'Try Again': 'ลองอีกครั้ง',
  'Phone number copied': 'คัดลอกหมายเลขโทรศัพท์แล้ว',
  'Copy Phone Number': 'คัดลอกหมายเลขโทรศัพท์',
  'Building 16 Energy Management System': 'ระบบจัดการพลังงาน อาคาร 16',
  'Back': 'กลับ',
  'Checking your session...': 'กำลังตรวจสอบสถานะการเข้าสู่ระบบ...',
  'If the information is correct, a 6-digit OTP has been sent to the email on file.':
      'หากข้อมูลถูกต้อง ระบบได้ส่ง OTP 6 หลักไปยังอีเมลที่ลงทะเบียนไว้',
  'Password changed': 'เปลี่ยนรหัสผ่านแล้ว',
  'You can now sign in with your new password.':
      'ขณะนี้คุณสามารถเข้าสู่ระบบด้วยรหัสผ่านใหม่ได้',
  'Back to Sign In': 'กลับไปหน้าเข้าสู่ระบบ',
  'A new OTP has been sent. Please check your email.':
      'ส่ง OTP ใหม่แล้ว กรุณาตรวจสอบอีเมล',
  'Forgot Password': 'ลืมรหัสผ่าน',
  'Verify OTP': 'ยืนยัน OTP',
  'Create New Password': 'สร้างรหัสผ่านใหม่',
  'Enter the username or email registered in the system':
      'กรอกชื่อผู้ใช้หรืออีเมลที่ลงทะเบียนในระบบ',
  'Enter the 6-digit code sent to the email on file':
      'กรอกรหัส 6 หลักที่ส่งไปยังอีเมลที่ลงทะเบียนไว้',
  'Your new password must contain at least 8 characters':
      'รหัสผ่านใหม่ต้องมีอย่างน้อย 8 ตัวอักษร',
  'Send OTP': 'ส่ง OTP',
  'Save New Password': 'บันทึกรหัสผ่านใหม่',
  'Did not receive it? Resend OTP': 'ยังไม่ได้รับรหัส? ส่ง OTP อีกครั้ง',
  'Username or Email': 'ชื่อผู้ใช้หรืออีเมล',
  'Enter your username or email': 'กรุณากรอกชื่อผู้ใช้หรืออีเมล',
  '6-digit OTP': 'OTP 6 หลัก',
  'Enter the complete 6-digit OTP': 'กรุณากรอก OTP ให้ครบ 6 หลัก',
  'New Password': 'รหัสผ่านใหม่',
  'Password must contain at least 8 characters':
      'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร',
  'Confirm New Password': 'ยืนยันรหัสผ่านใหม่',
  'The passwords do not match': 'รหัสผ่านไม่ตรงกัน',
  'The server did not return an access token.':
      'เซิร์ฟเวอร์ไม่ได้ส่งรหัสเข้าสู่ระบบกลับมา',
  'Could not create a password reset request.':
      'ไม่สามารถสร้างคำขอเปลี่ยนรหัสผ่านได้',
  'Could not verify the OTP.': 'ไม่สามารถยืนยัน OTP ได้',
  'The server took too long to respond.': 'เซิร์ฟเวอร์ใช้เวลาตอบกลับนานเกินไป',
  'Could not connect to the server. Check the network and API_BASE_URL.':
      'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบเครือข่ายและ API_BASE_URL',
  'The server returned an error.': 'เซิร์ฟเวอร์ส่งข้อผิดพลาดกลับมา',
  'The server returned invalid data.': 'เซิร์ฟเวอร์ส่งข้อมูลไม่ถูกต้อง',
  'The server returned invalid schedule data.':
      'เซิร์ฟเวอร์ส่งข้อมูลตารางเรียนไม่ถูกต้อง',
  'Please sign in again.': 'กรุณาเข้าสู่ระบบใหม่',
  'CPE Green Office': 'CPE Green Office',
  'Building 16': 'อาคาร 16',
  '🔔 System Alerts': '🔔 การแจ้งเตือนระบบ',
  'Energy Used This Week': 'พลังงานที่ใช้ในสัปดาห์นี้',
  'Estimated cost: THB 1,217.25': 'ค่าไฟโดยประมาณ: 1,217.25 บาท',
  'Pending': 'รอดำเนินการ',
  'Completed': 'เสร็จสิ้น',
  'Air conditioner on outside class hours (occupancy detected)':
      'ตรวจพบคนและมีการเปิดแอร์นอกเวลาเรียน',
  'Air conditioner turned off automatically (class ended/vacant)':
      'ปิดแอร์อัตโนมัติเมื่อหมดเวลาเรียนหรือไม่มีคน',
  'Energy Summary': 'สรุปการใช้พลังงาน',
  'This Week': 'สัปดาห์นี้',
  '≈ THB 1,217.25': '≈ 1,217.25 บาท',
  'Down 5%': 'ลดลง 5%',
  'Sun': 'อา.',
  'Mon': 'จ.',
  'Tue': 'อ.',
  'Wed': 'พ.',
  'Thu': 'พฤ.',
  'Fri': 'ศ.',
  'Sat': 'ส.',
  'Today': 'วันนี้',
  'Selected date': 'วันที่เลือก',
  'Usage by Room': 'การใช้งานแยกตามห้อง',
  'Air Conditioners': 'เครื่องปรับอากาศ',
  'Room Schedule': 'ตารางใช้งานห้อง',
  'Manage Timetable': 'จัดการตารางเรียน',
  'Import Excel or CSV': 'นำเข้า Excel หรือ CSV',
  'Import Timetable': 'นำเข้าตารางเรียน',
  'Import this timetable?': 'นำเข้าตารางเรียนนี้หรือไม่?',
  'Timetable imported.': 'นำเข้าตารางเรียนแล้ว',
  'Importing...': 'กำลังนำเข้า...',
  'Done': 'เสร็จสิ้น',
  'Excel is converted automatically': 'ระบบแปลง Excel ให้อัตโนมัติ',
  'Choose the original .xlsx file. The app reads every room sheet, checks the times, and shows a preview before saving.':
      'เลือกไฟล์ .xlsx ต้นฉบับ แอปจะอ่านทุกชีตของห้อง ตรวจสอบเวลา และแสดงตัวอย่างก่อนบันทึก',
  'Choose an Excel or CSV file': 'เลือกไฟล์ Excel หรือ CSV',
  'Supports .xlsx and normalized .csv files up to 8 MB.':
      'รองรับไฟล์ .xlsx และ .csv รูปแบบมาตรฐาน ขนาดไม่เกิน 8 MB',
  'Select File': 'เลือกไฟล์',
  'Reading and checking the timetable...':
      'กำลังอ่านและตรวจสอบตารางเรียน...',
  'Choose another file': 'เลือกไฟล์อื่น',
  'Semester': 'ภาคเรียน',
  'Semester not specified': 'ไม่ได้ระบุภาคเรียน',
  'Rooms': 'ห้อง',
  'Classes': 'รายการ',
  'Warnings': 'ข้อสังเกต',
  'Please review': 'กรุณาตรวจสอบ',
  'Save CSV': 'บันทึก CSV',
  'CSV file saved.': 'บันทึกไฟล์ CSV แล้ว',
  'Nothing is saved yet. Import replaces schedules only for the rooms found in this file. Other rooms are unchanged.':
      'ขณะนี้ยังไม่มีการบันทึก เมื่อนำเข้า ระบบจะแทนที่ตารางเฉพาะห้องที่พบในไฟล์ ส่วนห้องอื่นจะไม่เปลี่ยนแปลง',
  'The file must not exceed 8 MB.': 'ไฟล์ต้องมีขนาดไม่เกิน 8 MB',
  'Choose a room and day, then add or edit its class schedule.':
      'เลือกห้องและวัน จากนั้นเพิ่มหรือแก้ไขตารางเรียน',
  'Floor': 'ชั้น',
  'Day': 'วัน',
  'Sunday': 'อาทิตย์',
  'Monday': 'จันทร์',
  'Tuesday': 'อังคาร',
  'Wednesday': 'พุธ',
  'Thursday': 'พฤหัสบดี',
  'Friday': 'ศุกร์',
  'Saturday': 'เสาร์',
  'Add Class': 'เพิ่มวิชา',
  'Edit': 'แก้ไข',
  'Delete': 'ลบ',
  'Delete class schedule?': 'ลบตารางเรียนหรือไม่?',
  'Class schedule deleted.': 'ลบตารางเรียนแล้ว',
  'Clear all schedules': 'ล้างตารางทั้งหมด',
  'Clear all class schedules?': 'ล้างตารางเรียนทั้งหมดหรือไม่?',
  'This will permanently delete all {count} class schedules from every room. Rooms, air conditioners, users, and other settings will not be deleted.':
      'ระบบจะลบตารางเรียนทั้ง {count} รายการจากทุกห้องอย่างถาวร โดยจะไม่ลบห้อง เครื่องปรับอากาศ ผู้ใช้ หรือการตั้งค่าอื่น',
  'This action cannot be undone.': 'การดำเนินการนี้ไม่สามารถย้อนกลับได้',
  'Clear all': 'ล้างทั้งหมด',
  'Clearing...': 'กำลังล้าง...',
  'All class schedules have been cleared.':
      'ล้างตารางเรียนทั้งหมดเรียบร้อยแล้ว',
  'No classes have been added yet.': 'ยังไม่ได้เพิ่มวิชา',
  'Add Class Schedule': 'เพิ่มตารางเรียน',
  'Edit Class Schedule': 'แก้ไขตารางเรียน',
  'Subject name': 'ชื่อวิชา',
  'Section': 'กลุ่มเรียน',
  'Instructor': 'อาจารย์ผู้สอน',
  'e.g. (T) 68346CPE': 'เช่น (T) 68346CPE',
  'e.g. Dr. or lecturer name': 'เช่น ชื่ออาจารย์ผู้สอน',
  'The section must not exceed 80 characters.':
      'กลุ่มเรียนต้องมีความยาวไม่เกิน 80 ตัวอักษร',
  'The instructor name must not exceed 150 characters.':
      'ชื่ออาจารย์ต้องมีความยาวไม่เกิน 150 ตัวอักษร',
  'e.g. Computer Network': 'เช่น เครือข่ายคอมพิวเตอร์',
  'Start time': 'เวลาเริ่ม',
  'End time': 'เวลาเลิก',
  'Save Changes': 'บันทึกการแก้ไข',
  'Please enter a subject name.': 'กรุณากรอกชื่อวิชา',
  'The subject name must not exceed 150 characters.':
      'ชื่อวิชาต้องมีความยาวไม่เกิน 150 ตัวอักษร',
  'End time must be after start time.': 'เวลาเลิกต้องอยู่หลังเวลาเริ่ม',
  'This time overlaps an existing class.':
      'ช่วงเวลานี้ซ้อนกับวิชาที่มีอยู่แล้ว',
  'Scheduled': 'มีตารางเรียน',
  'No class schedule for this floor and day.':
      'ไม่มีตารางเรียนสำหรับชั้นและวันที่เลือก',
  'Use the calendar button at the top right to add a class.':
      'กดปุ่มปฏิทินมุมขวาบนเพื่อเพิ่มวิชา',
  'Could not load the class schedule.': 'ไม่สามารถโหลดตารางเรียนได้',
  'Classrooms (Scheduled Control)': 'ห้องเรียน (ควบคุมตามตาราง)',
  'Offices / Other Rooms': 'สำนักงาน / ห้องอื่น ๆ',
  'Computer Network': 'เครือข่ายคอมพิวเตอร์',
  'Cyber Security': 'ความมั่นคงปลอดภัยไซเบอร์',
  'Machine Learning': 'การเรียนรู้ของเครื่อง',
  'Embedded Systems': 'ระบบสมองกลฝังตัว',
  'In Use': 'กำลังใช้งาน',
  'Choose a Room to Control': 'เลือกห้องที่ต้องการควบคุม',
  'Select a floor, then choose a room.': 'เลือกชั้น แล้วเลือกห้องที่ต้องการ',
  'Manage Rooms': 'จัดการห้อง',
  'Add Room': 'เพิ่มห้อง',
  'Edit Room': 'แก้ไขห้อง',
  'Special': 'ห้องพิเศษ',
  'Special rooms': 'ห้องพิเศษ',
  'No rooms in this group.': 'ไม่มีห้องในกลุ่มนี้',
  'Add standard or special rooms such as CL503. Use floor 0 to place a room in the Special group.':
      'เพิ่มห้องปกติหรือห้องพิเศษ เช่น CL503 โดยใช้ชั้น 0 เพื่อจัดไว้ในกลุ่มห้องพิเศษ',
  'Room code': 'รหัสห้อง',
  'e.g. 16203 or CL503': 'เช่น 16203 หรือ CL503',
  'Display order': 'ลำดับการแสดง',
  'Room type or name': 'ประเภทหรือชื่อห้อง',
  'e.g. Computer Laboratory': 'เช่น ห้องปฏิบัติการคอมพิวเตอร์',
  '0 = Special': '0 = ห้องพิเศษ',
  'Special Computer Laboratory': 'ห้องปฏิบัติการคอมพิวเตอร์พิเศษ',
  'Occupied': 'มีคนอยู่',
  'Vacant': 'ไม่มีคน',
  'No sensor': 'ไม่มีเซ็นเซอร์',
  'Sensor unavailable': 'เซ็นเซอร์ไม่พร้อมใช้งาน',
  'No occupancy detected': 'ไม่พบคนในห้อง',
  'No occupancy sensor': 'ยังไม่มีเซ็นเซอร์ตรวจจับคน',
  'Add one ESP32 + LD2410 for this room':
      'เพิ่ม ESP32 + LD2410 หนึ่งชุดสำหรับห้องนี้',
  'Occupancy sensor offline': 'เซ็นเซอร์ตรวจจับคนออฟไลน์',
  'The last room state may be out of date':
      'สถานะล่าสุดของห้องอาจไม่เป็นปัจจุบัน',
  'LD2410 data unavailable': 'อ่านข้อมูล LD2410 ไม่ได้',
  'Check the radar UART connection': 'ตรวจสอบการเชื่อมต่อ UART ของเรดาร์',
  'People detected in this room': 'ตรวจพบคนอยู่ภายในห้อง',
  'A static target gate is greater than 25':
      'มีค่า Static target อย่างน้อยหนึ่ง Gate มากกว่า 25',
  'No people detected in this room': 'ไม่พบคนอยู่ภายในห้อง',
  'Every static target gate is 25 or lower':
      'ค่า Static target ทุก Gate ไม่เกิน 25',
  'Add sensor': 'เพิ่มเซ็นเซอร์',
  'Reconfigure': 'ตั้งค่าใหม่',
  'Remove occupancy sensor': 'นำเซ็นเซอร์ตรวจจับคนออก',
  'Remove the occupancy sensor from this room?':
      'นำเซ็นเซอร์ตรวจจับคนออกจากห้องนี้หรือไม่',
  'Add room occupancy sensor': 'เพิ่มเซ็นเซอร์ตรวจจับคนประจำห้อง',
  'Reconfigure room occupancy sensor':
      'ตั้งค่าเซ็นเซอร์ตรวจจับคนประจำห้องใหม่',
  'Find nearby RMUTT-OCC ESP32': 'ค้นหา ESP32 รุ่น RMUTT-OCC ที่อยู่ใกล้',
  'Turn on the occupancy ESP32 in setup mode. Its name must start with RMUTT-OCC-.':
      'เปิด ESP32 ตรวจจับคนในโหมดตั้งค่า โดยชื่อต้องขึ้นต้นด้วย RMUTT-OCC-',
  'No RMUTT-OCC occupancy ESP32 was found nearby.':
      'ไม่พบ ESP32 ตรวจจับคน RMUTT-OCC ที่อยู่ใกล้',
  'This ESP32 is not occupancy-sensor firmware.':
      'ESP32 เครื่องนี้ไม่ได้ใช้เฟิร์มแวร์เซ็นเซอร์ตรวจจับคน',
  'Select the same occupancy ESP32 already assigned to this room.':
      'กรุณาเลือก ESP32 ตรวจจับคนเครื่องเดิมที่ผูกกับห้องนี้',
  'Room and detection rule': 'ห้องและกฎการตรวจจับ',
  'Occupied when any LD2410 static target gate is greater than 25. Other radar values are not sent to the app.':
      'ถือว่ามีคนเมื่อค่า Static target ของ LD2410 มี Gate ใดมากกว่า 25 โดยจะไม่ส่งค่าเรดาร์อื่นไปยังแอป',
  'Occupancy sensor configuration saved. ESP32 is connecting to MQTT.':
      'บันทึกค่าเซ็นเซอร์ตรวจจับคนแล้ว ESP32 กำลังเชื่อมต่อ MQTT',
  'The occupancy ESP32 may already be in setup mode. If it is not found, hold BOOT and press RESET.':
      'ESP32 ตรวจจับคนอาจอยู่ในโหมดตั้งค่าแล้ว หากค้นหาไม่พบ ให้กด BOOT ค้างแล้วกด RESET',
  'System: Manual': 'ระบบ: ควบคุมเอง',
  'System: Auto': 'ระบบ: อัตโนมัติ',
  '6-unit limit reached': 'ครบจำนวนสูงสุด 6 เครื่องแล้ว',
  'Add Air Conditioner': 'เพิ่มเครื่องปรับอากาศ',
  'A room can have up to 6 air conditioners.':
      'หนึ่งห้องเพิ่มเครื่องปรับอากาศได้สูงสุด 6 เครื่อง',
  'Air Conditioner Name': 'ชื่อเครื่องปรับอากาศ',
  'e.g. Front unit': 'เช่น เครื่องด้านหน้า',
  'Cancel': 'ยกเลิก',
  'Add': 'เพิ่ม',
  'Remove Air Conditioner': 'นำเครื่องปรับอากาศออก',
  'Remove': 'นำออก',
  'This room has no air conditioners yet': 'ห้องนี้ยังไม่มีเครื่องปรับอากาศ',
  'Add First Unit': 'เพิ่มเครื่องแรก',
  'User Profile': 'โปรไฟล์ผู้ใช้',
  'Administrator': 'ผู้ดูแลระบบ',
  'Staff': 'เจ้าหน้าที่',
  'System Management': 'การจัดการระบบ',
  'Manage User Permissions': 'จัดการสิทธิ์ผู้ใช้',
  'Assign Admin and Staff access': 'กำหนดสิทธิ์ผู้ดูแลระบบและเจ้าหน้าที่',
  'Database': 'ฐานข้อมูล',
  'Status: Connected and up to date': 'สถานะ: เชื่อมต่อและเป็นข้อมูลล่าสุด',
  'Account & Settings': 'บัญชีและการตั้งค่า',
  'Electricity Rate': 'อัตราค่าไฟฟ้า',
  'Set the rate per kWh for cost estimates':
      'กำหนดอัตราต่อ kWh สำหรับคำนวณค่าใช้จ่าย',
  'Current rate': 'อัตราปัจจุบัน',
  'Rate per kWh': 'อัตราต่อ kWh',
  'Please enter an electricity rate.': 'กรุณากรอกอัตราค่าไฟฟ้า',
  'Enter a rate from 0.01 to 100.00.': 'กรุณากรอกอัตราตั้งแต่ 0.01 ถึง 100.00',
  'e.g. 4.50': 'เช่น 4.50',
  'THB / kWh': 'บาท / kWh',
  'Enter a rate from 0.01 to 100.00 per kWh.':
      'กรอกอัตราตั้งแต่ 0.01 ถึง 100.00 บาทต่อ kWh',
  'Calculation Preview': 'ตัวอย่างการคำนวณ',
  'Energy usage': 'พลังงานที่ใช้',
  'Electricity rate': 'อัตราค่าไฟฟ้า',
  'Estimated cost': 'ค่าไฟโดยประมาณ',
  'Cost = Energy (kWh) × Electricity rate':
      'ค่าไฟ = พลังงาน (kWh) × อัตราค่าไฟฟ้า',
  'Save Rate': 'บันทึกอัตราค่าไฟ',
  'Electricity rate saved.': 'บันทึกอัตราค่าไฟแล้ว',
  'Application Settings': 'ตั้งค่าแอปพลิเคชัน',
  'Language and appearance': 'ภาษาและรูปแบบการแสดงผล',
  'Log Out': 'ออกจากระบบ',
  'Remove the saved session from this device':
      'ลบสถานะการเข้าสู่ระบบที่บันทึกไว้ในเครื่องนี้',
  'Log out?': 'ออกจากระบบหรือไม่?',
  'You will need to sign in again next time.':
      'ครั้งถัดไปคุณจะต้องเข้าสู่ระบบใหม่',
  'Log out': 'ออกจากระบบ',
  'APPEARANCE': 'รูปแบบการแสดงผล',
  'Dark mode': 'โหมดมืด',
  'Use a dark color theme throughout the app': 'ใช้ชุดสีมืดกับทุกหน้าภายในแอป',
  'Theme colors': 'ธีมสี',
  'Colors come from the RMUTT Save Energy logo. Saved on this phone.':
      'สีทั้งหมดมาจากโลโก้ RMUTT Save Energy บันทึกไว้ในเครื่องนี้',
  'White': 'ขาว',
  'Gray': 'เทา',
  'Black': 'ดำ',
  'Green': 'เขียว',
  'Match phone': 'ตามเครื่อง',
  'Bright and easy to read in sunny rooms': 'สว่าง อ่านง่ายในห้องที่แสงจ้า',
  'The logo charcoal, gentle on the eyes': 'โทนเดียวกับพื้นโลโก้ สบายตา',
  'Fully dark for screens left on at night': 'มืดสนิท สำหรับจอที่เปิดค้างตอนกลางคืน',
  'Deep green header with light content': 'แถบหัวเขียวเข้ม เนื้อหาพื้นสว่าง',
  'White in light mode, Gray in dark mode':
      'เครื่องโหมดสว่างใช้ ขาว โหมดมืดใช้ เทา',
  'LANGUAGE': 'ภาษา',
  'App language': 'ภาษาของแอป',
  'Choose Thai or English. Your selection is saved automatically.':
      'เลือกภาษาไทยหรืออังกฤษ ระบบจะบันทึกให้อัตโนมัติ',
  'Home': 'หน้าหลัก',
  'Analytics': 'สถิติ',
  'Schedule': 'ตารางเวลา',
  'Control': 'ควบคุม',
  'Profile': 'โปรไฟล์',
  'Options': 'ตัวเลือก',
  'ON': 'เปิด',
  'OFF': 'ปิด',
  'MODE': 'โหมด',
  'FAN': 'พัดลม',
  'SWING': 'สวิง',
  'Rename Air Conditioner': 'เปลี่ยนชื่อเครื่องปรับอากาศ',
  'Save': 'บันทึก',
  'Not set': 'ยังไม่ตั้งค่า',
  'Air Conditioner Remote': 'รีโมตเครื่องปรับอากาศ',
  'Close': 'ปิด',
  'Operating Mode': 'โหมดการทำงาน',
  'Fan Speed': 'ความเร็วพัดลม',
  'Airflow Direction': 'ทิศทางลม',
  'Special Functions': 'ฟังก์ชันพิเศษ',
  'Timer': 'ตั้งเวลา',
  'Turn on in': 'เปิดในอีก',
  'Turn off in': 'ปิดในอีก',
  'Send Mock Command': 'ส่งคำสั่งจำลอง',
  'Set Auto-On Timer': 'ตั้งเวลาเปิดอัตโนมัติ',
  'Set Auto-Off Timer': 'ตั้งเวลาปิดอัตโนมัติ',
  'Clear Timer': 'ล้างการตั้งเวลา',
  'COOLING': 'กำลังทำความเย็น',
  'PZEM meter unavailable': 'ไม่พบมิเตอร์ PZEM',
  'Air conditioner running outside schedule':
      'เครื่องปรับอากาศกำลังทำงานนอกตาราง',
  'Air conditioner is running': 'เครื่องปรับอากาศกำลังทำงาน',
  'Air conditioner is stopped': 'เครื่องปรับอากาศหยุดทำงาน',
  'Energy': 'พลังงาน',
  'Auto': 'อัตโนมัติ',
  'Cool': 'ทำความเย็น',
  'Dry': 'ลดความชื้น',
  'Fan': 'พัดลม',
  'Heat': 'ทำความร้อน',
  'Low': 'ต่ำ',
  'Medium': 'ปานกลาง',
  'High': 'สูง',
  'Level 1': 'ระดับ 1',
  'Level 2': 'ระดับ 2',
  'Level 3': 'ระดับ 3',
  'Level 4': 'ระดับ 4',
  'Up': 'ขึ้น',
  'Upper': 'ค่อนบน',
  'Middle': 'กึ่งกลาง',
  'Lower': 'ค่อนล่าง',
  'Down': 'ลง',
  'Off': 'ปิด',
  'Administration Office': 'สำนักงานธุรการ',
  'Meeting Room': 'ห้องประชุม',
  'Classroom': 'ห้องเรียน',
  'Laboratory': 'ห้องปฏิบัติการ',
  'Faculty Office': 'ห้องพักอาจารย์',
  'Project Room': 'ห้องโครงงาน',
  'Network Room': 'ห้องเครือข่าย',
  'Storage Room': 'ห้องเก็บของ',
  'Faculty Project Room': 'ห้องโครงงานอาจารย์',
  'Equipment Storage': 'ห้องเก็บอุปกรณ์',

  'Floor 3': 'ชั้น 3',

  // --- คำที่ใช้ประกอบกับตัวแปรในประโยค ---
  'Delete Room': 'ลบห้อง',
  'THB': 'บาท',
  'Type': 'ประเภท',
  'deleted.': 'ถูกลบแล้ว',
  'from this room?': 'ออกจากห้องนี้ใช่ไหม',
  'hr': 'ชม.',
  'min': 'นาที',
  'rooms': 'ห้อง',
  'units': 'เครื่อง',

  // --- Occupancy sensor provisioning state ---
  'Occupancy sensor not activated yet': 'เซ็นเซอร์ตรวจจับคนยังไม่พร้อมใช้งาน',
  'Saved in the database but the ESP32 has not confirmed over MQTT. Set it up over Bluetooth again.':
      'บันทึกในฐานข้อมูลแล้ว แต่ ESP32 ยังไม่ยืนยันผ่าน MQTT '
          'กรุณาตั้งค่าผ่านบลูทูธอีกครั้ง',

  // --- User permission management (v3.7.0) ---
  'Add User': 'เพิ่มผู้ใช้',
  'Create Account': 'สร้างบัญชี',
  'Refresh': 'รีเฟรช',
  'You': 'คุณ',
  'Active': 'ใช้งานอยู่',
  'Suspended': 'ถูกระงับ',
  'Delete User': 'ลบผู้ใช้',
  'Confirm': 'ยืนยัน',
  'Confirm your password': 'ยืนยันรหัสผ่าน',
  'Changing the email requires your current password.':
      'OTP ลืมรหัสผ่านจะส่งไปที่อีเมลนี้ จึงต้องใส่รหัสผ่านปัจจุบันก่อนเปลี่ยน',
  'Role': 'สิทธิ์',
  'First name': 'ชื่อ',
  'Last name': 'นามสกุล',
  'Email': 'อีเมล',
  'Phone': 'เบอร์โทร',
  'Never signed in': 'ยังไม่เคยเข้าสู่ระบบ',
  'Last sign-in': 'เข้าสู่ระบบล่าสุด',
  'No user accounts found.': 'ไม่พบบัญชีผู้ใช้ในระบบ',
  'Administrators manage rooms, schedules, devices and user permissions. Staff can view rooms and control air conditioners only.':
      'ผู้ดูแลระบบจัดการห้อง ตารางเรียน อุปกรณ์ และสิทธิ์ผู้ใช้ได้ '
          'ส่วนเจ้าหน้าที่ดูห้องและควบคุมเครื่องปรับอากาศได้เท่านั้น',
  'The account can sign in immediately with this password.':
      'บัญชีนี้จะเข้าสู่ระบบได้ทันทีด้วยรหัสผ่านที่ตั้งไว้',
  'Change permission?': 'ยืนยันการเปลี่ยนสิทธิ์',
  'will be changed to': 'จะถูกเปลี่ยนสิทธิ์เป็น',
  'They will be signed out and must sign in again.':
      'ผู้ใช้จะถูกออกจากระบบและต้องเข้าสู่ระบบใหม่',
  'This permanently removes the account': 'การลบนี้จะลบบัญชีถาวรคือ',
  'Suspending the account keeps its history instead.':
      'หากต้องการเก็บประวัติไว้ ให้ใช้การระงับบัญชีแทน',
  'Permission updated.': 'เปลี่ยนสิทธิ์เรียบร้อยแล้ว',
  'Account enabled.': 'เปิดใช้งานบัญชีแล้ว',
  'Account suspended.': 'ระงับบัญชีแล้ว',
  'User created.': 'สร้างบัญชีผู้ใช้แล้ว',
  'User deleted.': 'ลบบัญชีผู้ใช้แล้ว',
  'Username must contain at least 3 characters.':
      'Username ต้องมีอย่างน้อย 3 ตัวอักษร',
  'Password must contain at least 8 characters.':
      'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร',
  'Please enter the first and last name.': 'กรุณากรอกชื่อและนามสกุล',
  'Please enter a valid email address.': 'กรุณากรอกอีเมลให้ถูกต้อง',

  // --- Energy database and Excel export (v3.7.0) ---
  'Live readings': 'ค่าไฟสด',
  'Export to Excel': 'ส่งออกเป็น Excel',
  'Live readings and hourly Excel export':
      'ดูค่าไฟแบบสด และดาวน์โหลดข้อมูลรายชั่วโมงเป็น Excel',
  'Update every': 'อัปเดตทุก',
  'sec': 'วินาที',
  'Pause': 'หยุดชั่วคราว',
  'Resume': 'ดูต่อ',
  'Every air conditioner': 'แอร์ทุกเครื่อง',
  'No electrical data yet': 'ยังไม่มีข้อมูลไฟฟ้า',
  'Values appear here once an ESP32 with a PZEM-004T reports '
    'in.':
      'ค่าจะขึ้นที่นี่เมื่อ ESP32 ที่ต่อ PZEM-004T '
      'ส่งข้อมูลเข้ามา',
  'PZEM-004T v3.0 measures voltage, current, active power, '
    'accumulated energy, frequency and power factor.':
      'PZEM-004T v3.0 วัดได้ 6 ค่า คือ แรงดัน กระแส กำลังไฟจริง '
      'พลังงานสะสม ความถี่ และตัวประกอบกำลัง',
  'Power drawn right now': 'กำลังไฟที่ใช้อยู่ตอนนี้',
  'hour': 'ชั่วโมง',
  'THB per hour': 'บาทต่อชั่วโมง',
  'Running': 'กำลังทำงาน',
  'Registered': 'ลงทะเบียนไว้',
  'Idle': 'ยังไม่ทำงาน',
  'The PZEM-004T on this unit is not responding.':
      'PZEM-004T ของเครื่องนี้ไม่ตอบสนอง',
  'Meter energy': 'พลังงานสะสม',
  'Frequency': 'ความถี่',
  'Power factor': 'ตัวประกอบกำลัง',
  'Date range': 'ช่วงวันที่',
  'Single day': 'วันเดียว',
  'Date': 'วันที่',
  'From': 'ตั้งแต่วันที่',
  'To': 'ถึงวันที่',
  'No stored hours yet.': 'ยังไม่มีข้อมูลรายชั่วโมงในฐานข้อมูล',
  'Stored data covers': 'ข้อมูลที่เก็บไว้มีตั้งแต่',
  'Level of detail': 'ระดับรายละเอียด',
  'High detail': 'รายละเอียดสูง',
  'Whole building': 'ทั้งอาคาร',
  'By room': 'แยกตามห้อง',
  'By air conditioner': 'แยกตามเครื่องแอร์',
  'One row per hour, totalling every air conditioner in '
    'Building 16':
      'หนึ่งแถวต่อหนึ่งชั่วโมง รวมแอร์ทุกเครื่องในอาคาร 16',
  'One row per hour for each room you pick':
      'หนึ่งแถวต่อหนึ่งชั่วโมง แยกตามห้องที่เลือก',
  'One row per hour for each air conditioner you pick':
      'หนึ่งแถวต่อหนึ่งชั่วโมง แยกตามเครื่องแอร์ที่เลือก',
  'Select all': 'เลือกทั้งหมด',
  'Clear': 'ล้างที่เลือก',
  'Leaving every room unticked includes all of them.':
      'ถ้าไม่ติ๊กห้องไหนเลย ระบบจะเอาทุกห้อง',
  'No rooms with data yet': 'ยังไม่มีห้องที่มีข้อมูล',
  'A room appears here after one of its air conditioners '
    'reports electrical data.':
      'ห้องจะขึ้นที่นี่เมื่อแอร์ในห้องนั้นส่งค่าไฟเข้ามาแล้ว',
  'Air conditioners': 'เครื่องปรับอากาศ',
  'Leaving every unit unticked includes all units in the '
    'selected rooms.':
      'ถ้าไม่ติ๊กเครื่องไหนเลย ระบบจะเอาทุกเครื่องในห้องที่เลือก',
  'No air conditioners with data yet':
      'ยังไม่มีเครื่องปรับอากาศที่มีข้อมูล',
  'Pick different rooms, or wait until a unit reports in.':
      'ลองเลือกห้องอื่น หรือรอให้เครื่องส่งค่าเข้ามาก่อน',
  'removed': 'นำออกแล้ว',
  'Values to include': 'ค่าที่ต้องการ',
  'High detail mode unlocks minimum, maximum and runtime '
    'columns as well.':
      'โหมดรายละเอียดสูงเปิดให้เลือกค่าต่ำสุด สูงสุด '
      'และเวลาทำงานเพิ่มได้ด้วย',
  'Switch to a high detail level to unlock more columns.':
      'เปลี่ยนเป็นระดับรายละเอียดสูงเพื่อเลือกค่าได้มากขึ้น',
  'Add an estimated cost column': 'เพิ่มคอลัมน์ค่าไฟโดยประมาณ',
  'Uses the rate': 'คิดที่อัตรา',
  'THB per kWh': 'บาทต่อหน่วย',
  'Preview': 'ดูตัวอย่าง',
  'Download Excel': 'ดาวน์โหลด Excel',
  'No data in the selected range': 'ไม่พบข้อมูลในช่วงที่เลือก',
  'Try a wider date range, or pick different rooms and units.':
      'ลองขยายช่วงวัน หรือเลือกห้องกับเครื่องอื่น',
  'rows': 'แถว',
  'Showing the first': 'แสดงเฉพาะ',
  'rows. The Excel file contains all of them.':
      'แถวแรก ส่วนไฟล์ Excel มีครบทุกแถว',
  'Air unit': 'เครื่องปรับอากาศ',
  'Excel file saved to': 'บันทึกไฟล์ Excel ไว้ที่',
  'Excel file is ready to share.':
      'ไฟล์ Excel พร้อมแล้ว เลือกที่เก็บได้เลย',
  'Saving was cancelled.': 'ยกเลิกการบันทึกแล้ว',
  'Could not save the file.': 'บันทึกไฟล์ไม่สำเร็จ',
  'The server returned an invalid list of values.':
      'เซิร์ฟเวอร์ส่งรายการค่าที่วัดได้มาไม่ถูกต้อง',
  'Could not build the Excel file.': 'สร้างไฟล์ Excel ไม่สำเร็จ',

  // --- Auto switch-off, dashboard and account (v3.8.0) ---
  'Empty room · switching off in': 'ห้องว่าง จะปิดแอร์ใน',
  'Sending the off command': 'กำลังส่งคำสั่งปิด',
  'Anyone entering the room cancels this.':
      'ถ้ามีคนเข้าห้องเมื่อไหร่ ระบบจะยกเลิกให้ทันที',
  'A class is scheduled now, so the wait is longer. Anyone '
      'entering cancels it.':
      'ตอนนี้มีคาบเรียนอยู่ ระบบจึงรอนานกว่าปกติ '
      'ถ้ามีคนเข้าห้องจะยกเลิกให้ทันที',
  'Retrying every 20 seconds until the power draw drops.':
      'จะยิงซ้ำทุก 20 วินาที จนกว่ากำลังไฟจะลดลง',
  'Air conditioner running outside class hours with people in '
      'the room':
      'มีคนอยู่ในห้องและเปิดแอร์นอกเวลาเรียน',
  'Empty room: the air conditioner was switched off '
      'automatically':
      'ห้องว่าง ระบบปิดแอร์ให้อัตโนมัติแล้ว',
  'Could not switch the air conditioner off. Please check it '
      'by hand.':
      'สั่งปิดแอร์ไม่สำเร็จ กรุณาไปตรวจสอบที่ห้อง',
  'System event': 'เหตุการณ์ของระบบ',
  'Mark as handled': 'รับทราบแล้ว',
  'Nothing needs attention right now': 'ตอนนี้ไม่มีเรื่องที่ต้องจัดการ',
  'Alerts appear here when an air conditioner runs outside '
      'class hours, or after the system switches one off.':
      'การแจ้งเตือนจะขึ้นที่นี่เมื่อมีการเปิดแอร์นอกเวลาเรียน '
      'หรือเมื่อระบบปิดแอร์ให้อัตโนมัติ',
  'Energy used': 'พลังงานที่ใช้',
  'Last 7 days': '7 วันล่าสุด',
  'Last 30 days': '30 วันล่าสุด',
  'Custom range': 'กำหนดช่วงเอง',
  'Pick a date range': 'เลือกช่วงวันที่',
  'Apply': 'ใช้ช่วงนี้',
  'No earlier data to compare': 'ยังไม่มีข้อมูลช่วงก่อนหน้าให้เทียบ',
  'Not enough data to draw a chart yet': 'ข้อมูลยังไม่พอวาดกราฟ',
  'No stored energy for this period yet. Values appear once '
      'an ESP32 with a PZEM-004T reports in.':
      'ยังไม่มีข้อมูลไฟฟ้าในช่วงนี้ ค่าจะขึ้นเมื่อ ESP32 ที่ต่อ '
      'PZEM-004T ส่งข้อมูลเข้ามา',
  'All floors': 'ทุกชั้น',
  'Runtime': 'เวลาทำงาน',
  'Account Settings': 'ตั้งค่าบัญชีผู้ใช้',
  'Name, email, phone number and password':
      'ชื่อ อีเมล เบอร์โทร และรหัสผ่าน',
  'Personal details': 'ข้อมูลส่วนตัว',
  'Phone number': 'เบอร์โทรศัพท์',
  'Save changes': 'บันทึกการเปลี่ยนแปลง',
  'Your account details were saved.': 'บันทึกข้อมูลบัญชีเรียบร้อยแล้ว',
  'Admins reach you at this number and email, and password '
      'resets are sent to this email.':
      'ผู้ดูแลระบบใช้เบอร์และอีเมลนี้ติดต่อคุณ และ OTP '
      'เปลี่ยนรหัสผ่านจะถูกส่งไปที่อีเมลนี้',
  'Username and permission are set by an administrator.':
      'Username และสิทธิ์ ต้องให้ผู้ดูแลระบบเป็นคนแก้',
  'Change password': 'เปลี่ยนรหัสผ่าน',
  'Change the password?': 'ยืนยันเปลี่ยนรหัสผ่าน?',
  'Every device signed in with this account will be signed '
      'out, including this one.':
      'ทุกเครื่องที่เข้าสู่ระบบด้วยบัญชีนี้จะถูกออกจากระบบ '
      'รวมถึงเครื่องนี้ด้วย',
  'Current password': 'รหัสผ่านปัจจุบัน',
  'New password': 'รหัสผ่านใหม่',
  'Confirm the new password': 'ยืนยันรหัสผ่านใหม่',
  'Please enter the current password.': 'กรุณากรอกรหัสผ่านปัจจุบัน',
  'Please enter the first name.': 'กรุณากรอกชื่อ',
  'Please enter the last name.': 'กรุณากรอกนามสกุล',
  'The new password must differ from the current one.':
      'รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสผ่านเดิม',
  'The passwords do not match.': 'รหัสผ่านทั้งสองช่องไม่ตรงกัน',
  'The phone number format is invalid.': 'รูปแบบเบอร์โทรไม่ถูกต้อง',
};

const _englishTranslations = <String, String>{
  // Wired (DAIKIN_WIRED) air-conditioner validation
  'แอร์แบบสายแอร์รองรับโหมด Cool, Dry และ Fan':
      'Wired air conditioners support Cool, Dry and Fan modes only.',
  'แอร์แบบสายแอร์ไม่มีพัดลมระดับ Turbo':
      'Wired air conditioners have no Turbo fan speed.',
  'แอร์แบบสายแอร์มีเฉพาะส่าย (Auto) หรือหยุด (Off)':
      'Wired air conditioners only support swing (Auto) or stop (Off).',
  'ไม่พบ API ที่เรียกใช้งาน': 'The requested API was not found.',
  'เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์': 'An internal server error occurred.',
  'ยังไม่ได้กำหนดเบอร์แอดมินในฐานข้อมูล':
      'The administrator phone number has not been configured.',
  'ลองเข้าสู่ระบบหลายครั้งเกินไป กรุณารอ 15 นาที':
      'Too many sign-in attempts. Please wait 15 minutes.',
  'ขอเปลี่ยนรหัสผ่านบ่อยเกินไป กรุณาลองใหม่ภายหลัง':
      'Too many password reset requests. Please try again later.',
  'กรุณากรอก Username และ Password': 'Please enter your username and password.',
  'Username หรือ Password ไม่ถูกต้อง': 'The username or password is incorrect.',
  'กรุณากรอก Username หรือ Email': 'Please enter your username or email.',
  'หากข้อมูลถูกต้อง ระบบจะส่ง OTP ไปยังอีเมลในฐานข้อมูล':
      'If the information is correct, an OTP will be sent to the email on file.',
  'OTP ไม่ถูกต้องหรือหมดอายุแล้ว': 'The OTP is incorrect or has expired.',
  'สิทธิ์เปลี่ยนรหัสผ่านไม่ถูกต้องหรือหมดอายุแล้ว':
      'The password reset authorization is invalid or has expired.',
  'รหัสผ่านใหม่ต้องมีอย่างน้อย 8 ตัวอักษร และไม่ยาวเกิน 72 ไบต์':
      'The new password must contain at least 8 characters and no more than 72 bytes.',
  'เปลี่ยนรหัสผ่านสำเร็จ': 'Password changed successfully.',
  'กรุณาเข้าสู่ระบบ': 'Please sign in.',
  'รหัสเข้าสู่ระบบหมดอายุหรือไม่ถูกต้อง':
      'The access token is invalid or has expired.',
  'กรุณาเข้าสู่ระบบใหม่': 'Please sign in again.',
  'เฉพาะผู้ดูแลระบบเท่านั้นที่แก้ไขตารางเรียนได้':
      'Only administrators can edit the class schedule.',
  'ไม่พบรายการตารางเรียนนี้': 'This class schedule entry was not found.',
  'ชั้นต้องอยู่ระหว่าง 1 ถึง 3': 'Floor must be between 1 and 3.',
  'วันในสัปดาห์ไม่ถูกต้อง': 'The day of the week is invalid.',
  'หมายเลขห้องไม่ถูกต้อง': 'The room number is invalid.',
  'ชื่อวิชาต้องมีความยาว 1 ถึง 150 ตัวอักษร':
      'The subject name must contain 1 to 150 characters.',
  'รูปแบบเวลาต้องเป็น HH:mm': 'Time must use the HH:mm format.',
  'เวลาเลิกต้องอยู่หลังเวลาเริ่ม': 'End time must be after start time.',
  'ช่วงเวลานี้ซ้อนกับตารางเรียนที่มีอยู่แล้ว':
      'This time overlaps an existing class.',
  'รหัสรายการตารางเรียนไม่ถูกต้อง': 'The class schedule entry ID is invalid.',
  'ตัวกรองตารางเรียนไม่ถูกต้อง': 'The class schedule filter is invalid.',
  'ไฟล์ตารางเรียนว่างเปล่า': 'The timetable file is empty.',
  'รองรับเฉพาะไฟล์ .xlsx และ .csv':
      'Only .xlsx and .csv files are supported.',
  'เปิดไฟล์ Excel ไม่สำเร็จ กรุณาตรวจว่าเป็นไฟล์ .xlsx ที่ไม่เสียหาย':
      'Could not open the Excel file. Make sure it is a valid .xlsx file.',
  'ไม่พบตารางเรียนที่นำเข้าได้จากไฟล์ Excel':
      'No importable timetable entries were found in the Excel file.',
  'ไฟล์ CSV ไม่มีข้อมูลตารางเรียน':
      'The CSV file contains no timetable entries.',
  'หัวคอลัมน์ CSV ไม่ครบ กรุณาใช้ไฟล์ CSV ที่ระบบสร้างให้':
      'The CSV headers are incomplete. Please use a CSV created by the app.',
  'ไม่พบรายการตารางเรียนสำหรับนำเข้า':
      'No timetable entries were provided for import.',
  'ชื่อไฟล์ไม่ถูกต้อง': 'The file name is invalid.',
  'ไฟล์หรือข้อมูลที่ส่งมามีขนาดใหญ่เกินไป':
      'The uploaded file or data is too large.',
  'ไฟล์ Excel มีข้อมูลภายในมากเกินไป':
      'The Excel file contains too much uncompressed data.',

  // --- User permission management (v3.7.0) ---
  'เฉพาะผู้ดูแลระบบเท่านั้นที่ทำรายการนี้ได้':
      'Only administrators can perform this action.',
  'Username ต้องยาว 3–30 ตัว ใช้ได้เฉพาะ A–Z, 0–9, จุด, ขีดกลางและขีดล่าง':
      'The username must be 3–30 characters using A–Z, 0–9, dot, hyphen or underscore.',
  'สิทธิ์ต้องเป็น admin หรือ staff เท่านั้น':
      'The role must be either admin or staff.',
  'กรุณากรอกชื่อ': 'Please enter the first name.',
  'กรุณากรอกนามสกุล': 'Please enter the last name.',
  'รูปแบบอีเมลไม่ถูกต้อง': 'The email format is invalid.',
  'รูปแบบเบอร์โทรไม่ถูกต้อง': 'The phone number format is invalid.',
  'เบอร์โทรต้องเป็นตัวเลข 9–10 หลัก ขึ้นต้นด้วย 0':
      'The phone number must be 9–10 digits starting with 0.',
  'สถานะบัญชีต้องเป็น true หรือ false':
      'The account status must be true or false.',
  'ไม่มีข้อมูลที่ต้องแก้ไข': 'There is nothing to update.',
  'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร และไม่ยาวเกิน 72 ไบต์':
      'The password must contain at least 8 characters and no more than 72 bytes.',
  'มี Username หรืออีเมลนี้ในระบบแล้ว':
      'That username or email already exists.',
  'ไม่สามารถเปลี่ยนสิทธิ์หรือปิดบัญชีของตัวเองได้':
      'You cannot change the permission or status of your own account.',
  'ไม่สามารถลบบัญชีของตัวเองได้': 'You cannot delete your own account.',
  'ไม่พบผู้ใช้นี้ในระบบ': 'This user was not found.',
  'ระบบต้องมีผู้ดูแลระบบที่ใช้งานอยู่อย่างน้อย 1 บัญชี':
      'The system must keep at least one active administrator.',

  // --- Energy database and Excel export (v3.7.0) ---
  'ต้องระบุวันที่เริ่มต้นในรูปแบบ YYYY-MM-DD':
      'A start date in YYYY-MM-DD format is required.',
  'วันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด':
      'The start date must not be later than the end date.',
  'เลือกช่วงวันได้สูงสุด 366 วันต่อครั้ง':
      'You can export at most 366 days at a time.',
  'ไม่พบข้อมูลในช่วงเวลาที่เลือก '
    'ลองขยายช่วงวันหรือเลือกอุปกรณ์อื่น':
      'No data was found in the selected range. Try a wider range '
      'or other devices.',
  'ข้อมูลเกินขนาดที่ส่งออกได้ในครั้งเดียว':
      'That is more data than can be exported in one file.',

  // --- Auto switch-off and account settings (v3.8.0) ---
  'ค่าปิดอัตโนมัติต้องเป็น true หรือ false':
      'The auto switch-off setting must be true or false.',
  'รหัสการแจ้งเตือนไม่ถูกต้อง': 'That alert id is invalid.',
  'ไม่พบการแจ้งเตือนนี้ หรือรับทราบไปแล้ว':
      'That alert was not found, or it has already been handled.',
  'มีอีเมลนี้ในระบบแล้ว': 'That email address is already in use.',
  'กรุณากรอกรหัสผ่านปัจจุบัน': 'Please enter the current password.',
  'รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสผ่านเดิม':
      'The new password must differ from the current one.',
  'รหัสผ่านปัจจุบันไม่ถูกต้อง': 'The current password is incorrect.',
  'กรุณากรอกรหัสผ่านปัจจุบันเพื่อยืนยันการเปลี่ยนอีเมล':
      'Enter your current password to change the email address.',
  'ยืนยันรหัสผ่านผิดหลายครั้งเกินไป กรุณารอ 15 นาที':
      'Too many incorrect password confirmations. Please wait 15 minutes.',
  'ชั้นต้องเป็นตัวเลข 0–99':
      'The floor must be a number between 0 and 99.',
};
