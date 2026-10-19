import 'package:cpe_air_remote/models/air_conditioner.dart';
import 'package:cpe_air_remote/models/room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses measured PZEM and running status separately from IR command', () {
    final air = AirConditioner.fromJson({
      'deviceId': 'ESP32-AABBCCDDEEFF',
      'roomNumber': '16203',
      'airNumber': 1,
      'name': 'Air 1',
      'state': {'power': false},
      'pzemAvailable': true,
      'acRunning': true,
      'outsideSchedule': true,
      'voltage': 229.8,
      'current': 2.14,
      'powerWatts': 465.2,
      'energyKwh': 12.345,
      'frequencyHz': 50.0,
      'powerFactor': 0.94,
    });

    expect(air.isOn, isFalse);
    expect(air.isRunning, isTrue);
    expect(air.outsideSchedule, isTrue);
    expect(air.pzemAvailable, isTrue);
    expect(air.energyKwh, 12.345);
  });

  test('room running count uses PZEM status instead of the IR command', () {
    final room = Room(
      number: '16203',
      floor: 2,
      roomIndex: 3,
      type: 'Laboratory',
      airConditioners: [
        AirConditioner(
          id: 1,
          name: 'Air 1',
          isOn: false,
          isRunning: true,
          pzemAvailable: true,
          power: 450,
        ),
      ],
    );

    expect(room.runningAirCount, 1);
    expect(room.totalPower, 450);
  });

  test('air turned on with the physical remote shows as on', () {
    final air = AirConditioner(
      id: 1,
      name: 'Air 1',
      isOn: false,
      isRunning: true,
      pzemAvailable: true,
      power: 158,
    );

    expect(air.isPoweredOn, isTrue);
    // คำสั่งถัดไปต้องเริ่มจาก "เปิด" กดปรับอุณหภูมิจะได้ไม่เผลอสั่งปิดแอร์
    expect(air.editableCopy().isOn, isTrue);
  });

  test('turning off clears the running flag until PZEM reports again', () {
    final air = AirConditioner(
      id: 1,
      name: 'Air 1',
      isOn: false,
      isRunning: true,
      pzemAvailable: true,
    );
    final draft = air.editableCopy()..isOn = false;
    air.copyStateFrom(draft);

    expect(air.isPoweredOn, isFalse);
  });

  test('without PZEM the IR command decides', () {
    final air = AirConditioner(
      id: 1,
      name: 'Air 1',
      isOn: false,
      isRunning: true,
      pzemAvailable: false,
    );

    expect(air.isPoweredOn, isFalse);
  });

  test('pressing turn on keeps the button on during the 20s grace period even at 2 W', () {
    final air = AirConditioner(
      id: 1,
      name: 'Air 1',
      isOn: false,
      isRunning: false,
      pzemAvailable: true,
      power: 2,
    );

    final draft = air.editableCopy()..isOn = true;
    final sentAt = DateTime.now().subtract(const Duration(seconds: 5));
    air.copyStateFrom(draft, commandedAt: sentAt);

    // อยู่ในช่วง 5–20 วินาทีแรกหลังกดเปิด ยังไม่เด้งกลับเป็นปิดแม้ไฟเพิ่งขึ้น 2 W
    expect(air.inCommandGracePeriod(), isTrue);
    expect(air.isPoweredOn, isTrue);
  });

  test('reverts to off after the 20s grace period when power stays at 2 W', () {
    final air = AirConditioner(
      id: 1,
      name: 'Air 1',
      isOn: false,
      isRunning: false,
      pzemAvailable: true,
      power: 2,
    );

    final draft = air.editableCopy()..isOn = true;
    final sentAt = DateTime.now().subtract(const Duration(seconds: 21));
    air.copyStateFrom(draft, commandedAt: sentAt);

    // พ้น 20 วินาทีแล้วแต่ไฟยังขึ้นแค่ 2 W (isRunning = false) แอปต้องเปลี่ยนเป็นปิด
    expect(air.inCommandGracePeriod(), isFalse);
    expect(air.isPoweredOn, isFalse);
    expect(air.editableCopy().isOn, isFalse);
  });
}
