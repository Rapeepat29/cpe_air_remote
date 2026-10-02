import 'package:cpe_air_remote/localization/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Thai is the default application language', () {
    const localizations = AppLocalizations(Locale('th'));

    expect(localizations.translate('Sign In'), 'เข้าสู่ระบบ');
    expect(localizations.translate('Room 16203'), 'ห้อง 16203');
    expect(
      localizations.translate('Floor 2 · Room 16203'),
      'ชั้น 2 · ห้อง 16203',
    );
    expect(localizations.translate('3/6 units'), '3/6 เครื่อง');
    expect(
      localizations.translate('Estimated cost: THB 1,420.13'),
      'ค่าไฟโดยประมาณ: 1,420.13 บาท',
    );
    expect(
      localizations.translate('≈ THB 1,420.13'),
      '≈ 1,420.13 บาท',
    );
    expect(
      localizations.translate('Connecting and checking ESP32...'),
      'กำลังเชื่อมต่อและตรวจสอบ ESP32...',
    );
    expect(
      localizations.translate('Try connecting again'),
      'ลองเชื่อมต่ออีกครั้ง',
    );
  });

  test('English mode converts Thai backend messages', () {
    const localizations = AppLocalizations(Locale('en'));

    expect(
      localizations.translate('Username หรือ Password ไม่ถูกต้อง'),
      'The username or password is incorrect.',
    );
    expect(
      localizations.translate('OTP ไม่ถูกต้องหรือหมดอายุแล้ว'),
      'The OTP is incorrect or has expired.',
    );
  });
}
