# 03 · แอปมือถือ (Flutter)

โค้ดอยู่ที่ `lib/` รันได้ทั้ง **Android** และ **Windows**
เวอร์ชันปัจจุบัน `3.12.0+29`

---

## 1. การแบ่งชั้น

```
lib/
├── main.dart            ประกอบทุกอย่าง สลับหน้า loading → login → AppShell
├── models/              โครงสร้างข้อมูล แปลงจาก JSON
├── services/            *_repository.dart (สัญญา) + *_service.dart (ตัวจริง)
├── controllers/         state ของแต่ละโดเมน (ChangeNotifier)
├── screens/             หน้าจอ
├── widgets/             ชิ้นส่วนที่ใช้ซ้ำ
├── utils/               ฟังก์ชันบริสุทธิ์
├── localization/        คำแปลไทย/อังกฤษ
└── theme/               สีและธีม
```

### ทำไมแยก `repository` กับ `service`

ทุกโดเมนมีสองไฟล์ ตัวอย่าง

```dart
// alert_repository.dart — สัญญา ไม่มีโค้ดจริง
abstract interface class AlertRepository {
  Future<List<SystemAlert>> fetchAlerts({int limit});
  Future<SystemAlert> acknowledge(String id);
}

// alert_service.dart — ตัวจริงที่ยิง HTTP
class AlertService implements AlertRepository { ... }
```

**ได้อะไร**

1. **เทสต์ได้โดยไม่ต้องมีเซิร์ฟเวอร์** — ใส่ `_MemoryAlertRepository` ที่คืน
   ข้อมูลตายตัวเข้าไปแทน เทสต์วิดเจ็ตทั้ง 89 เคสจึงรันได้โดยไม่ต่อเน็ต
2. **เปลี่ยนวิธีดึงข้อมูลได้โดยไม่แตะ UI** — ถ้าวันหนึ่งย้ายจาก REST ไป
   GraphQL หรือเพิ่ม cache ก็เขียน class ใหม่ที่ implement สัญญาเดิม
3. **UI ไม่รู้จัก HTTP เลย** ไม่มี `http.get()` ในไฟล์หน้าจอสักไฟล์

ทุก `*Service` มี constructor รับ `http.Client` และ `FlutterSecureStorage`
เป็น optional เพื่อให้ใส่ของปลอมได้ตอนเทสต์

### ทำไมใช้ `ChangeNotifier` ไม่ใช้ Riverpod / BLoC

- **มากับ Flutter อยู่แล้ว** ไม่เพิ่ม dependency
- ระบบนี้มี state ไม่ซับซ้อน แค่ "ดึงข้อมูลมา เก็บไว้ บอกให้วาดใหม่"
- `AnimatedBuilder` + `Listenable.merge([a, b])` ฟังหลายตัวพร้อมกันได้เลย

```dart
AnimatedBuilder(
  animation: Listenable.merge([controller, systemSettingsController]),
  builder: (context, _) { ... },
)
```

ข้อแลกเปลี่ยนคือต้องเรียก `notifyListeners()` เอง และถ้าลืมจะไม่วาดใหม่
ซึ่งยอมรับได้เมื่อแลกกับความง่ายในการอ่านโค้ด

---

## 2. `main.dart` — จุดประกอบ

```dart
CpeAirRemoteApp({
  this.authRepository,
  this.appSettingsController,
  this.scheduleRepository,
  this.airConditionerRepository,
  this.roomRepository,
  this.energyRepository,
  this.alertRepository,
  this.alertNotifier,
  this.systemSettingsRepository,
})
```

ทุกตัวเป็น **optional** ถ้าไม่ใส่จะสร้างตัวจริงเอง

```dart
_alertRepository = widget.alertRepository ?? AlertService();
```

นี่คือ **dependency injection แบบง่ายที่สุด** ที่ทำได้ใน Flutter
แอปจริงไม่ส่งอะไรเข้ามา ส่วนเทสต์ส่งของปลอมครบทุกตัว

### การตั้งค่าขนาดตัวอักษร

```dart
builder: (context, child) {
  if (child == null) return const SizedBox.shrink();
  final media = MediaQuery.of(context);
  return MediaQuery(
    data: media.copyWith(
      textScaler: TextScaler.linear(
        _appSettingsController.resolvedTextScale(media.textScaler.scale(1)),
      ),
    ),
    child: child,
  );
},
```

**ทำไมวางที่ `builder` ของ `MaterialApp`** — เพราะ `builder` ครอบ
**ทุก route และทุก dialog** ถ้าไปวางที่ `home` แทน หน้าที่ push ขึ้นมาใหม่
และ dialog จะไม่ได้ขนาดตัวอักษรที่ตั้งไว้

**ทำไมเป็นตัวคูณ ไม่ใช่ค่าตายตัว**

```dart
double resolvedTextScale(double systemScale) {
  final combined = systemScale * _textScale.factor;
  if (!combined.isFinite || combined <= 0) return _textScale.factor;
  return combined.clamp(0.8, 2.0);
}
```

`media.textScaler.scale(1)` คือค่าที่ **ผู้ใช้ตั้งไว้ในระบบ Android**
คนสายตาไม่ดีที่ตั้งเครื่องไว้ 1.3 เท่าทั้งเครื่อง ถ้าแอปบังคับเป็น 1.0
เท่ากับพังการตั้งค่าช่วยเหลือการเข้าถึงของเขา

การคูณกันทำให้ค่าของระบบยังมีผล และ `clamp(0.8, 2.0)` กันไม่ให้ใหญ่จนปุ่มกดไม่ได้

---

## 3. รูปแบบ Controller

ทุก controller หน้าตาคล้ายกัน ขอยก `DashboardController` เป็นตัวอย่าง

```dart
class DashboardController extends ChangeNotifier {
  EnergySummary summary = EnergySummary.empty;
  bool isLoading = false;
  bool hasLoaded = false;
  String? errorMessage;

  Timer? _timer;
  Future<void>? _inFlight;
}
```

### `hasLoaded` แยกจาก `isLoading`

- `isLoading` = กำลังดึงอยู่ตอนนี้
- `hasLoaded` = เคยดึงสำเร็จอย่างน้อยหนึ่งครั้ง

ต้องแยกเพราะ **แถบโหลดควรขึ้นเฉพาะครั้งแรก** ถ้าขึ้นทุกครั้งที่รีเฟรชอัตโนมัติ
ทุก 30 วินาที หน้าจอจะกระพริบตลอดเวลา

```dart
if (dashboardController.isLoading && !dashboardController.hasLoaded)
  const LinearProgressIndicator(minHeight: 2),
```

### `_inFlight` — กันยิงซ้อน

```dart
Future<void>? _inFlight;

Future<void> refresh({bool silent = false}) async {
  final task = _inFlight ??= _run(silent);
  try { await task; }
  finally { if (identical(_inFlight, task)) _inFlight = null; }
}
```

**ปัญหาที่แก้** — ผู้ใช้ลากรีเฟรชขณะที่ timer เพิ่งยิงไปพอดี จะได้สองคำขอ
ที่ตอบกลับมาไม่เรียงกัน ถ้าอันแรกช้ากว่าอันหลัง ข้อมูลเก่าจะทับข้อมูลใหม่

`_inFlight` ทำให้คำขอที่สองไป **รอผลของคำขอแรก** แทนที่จะยิงใหม่

`identical()` ไม่ใช่ `==` เพราะต้องการเทียบว่าเป็น Future **ตัวเดียวกัน**
ไม่ใช่แค่ค่าเท่ากัน กันกรณีที่ล้างตัวที่คนอื่นตั้งไว้ทีหลัง

### การอัปเดตแบบมองโลกในแง่ดี (optimistic)

`SystemSettingsController` แสดงผลใหม่ทันทีก่อนเซิร์ฟเวอร์ตอบ

```dart
final previous = settings;
settings = SystemSettings(autoOffEnabled: enabled);
notifyListeners();                       // ขยับสวิตช์เลย

try {
  settings = await repository.setAutoOffEnabled(enabled);
  return true;
} catch (error) {
  settings = previous;                   // ถอยกลับถ้าไม่สำเร็จ
  errorMessage = _readable(error);
  return false;
}
```

**ทำไมต้องทำ** — สวิตช์ที่ค้างรอสองวินาทีทุกครั้งที่กดรู้สึกเหมือนแอปค้าง
ผู้ใช้จะกดซ้ำ ซึ่งทำให้แย่ลงไปอีก

**ที่ต้องระวัง** — ต้องเก็บค่าเดิมไว้ถอยกลับเสมอ ถ้าลืม สวิตช์จะค้างในสถานะ
ที่ไม่ตรงกับเซิร์ฟเวอร์ ซึ่งอันตรายกว่าการรอ

---

## 4. ระบบแปลภาษา — วิธีที่ไม่ต้องแตะทุกบรรทัด

### ปัญหาของวิธีปกติ

วิธีมาตรฐานคือทุกข้อความต้องเขียนเป็น key แล้วเรียกฟังก์ชันแปล

```dart
Text(AppLocalizations.of(context).roomsTitle)
```

ข้อเสียคือ **อ่านโค้ดแล้วไม่รู้ว่าข้อความคืออะไร** ต้องเปิดไฟล์แปลควบคู่ตลอด

### วิธีที่ใช้ในโปรเจกต์นี้

`lib/localization/localized_material.dart` สร้าง `Text` ตัวใหม่ที่ **ชื่อซ้ำกับ
ของ Flutter** แล้ว re-export material โดยซ่อนตัวเดิม

```dart
export 'package:flutter/material.dart' hide Text;

class Text extends material.StatelessWidget {
  const Text(String this.data, { ... });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.maybeOf(context);
    return material.Text(
      localizations?.translate(data!) ?? data!,
      ...
    );
  }
}
```

ทุกไฟล์หน้าจอ `import '../localization/localized_material.dart';`
แทน `package:flutter/material.dart` จากนั้นเขียน

```dart
Text('Choose a Room to Control')
```

แล้วมันจะกลายเป็น `เลือกห้องที่ต้องการควบคุม` เองเมื่อผู้ใช้เลือกภาษาไทย

**ข้อดี** — โค้ดอ่านรู้เรื่องทันที และการเพิ่มข้อความใหม่ไม่ต้องคิดชื่อ key

**ข้อเสียที่ต้องรู้**

- ถ้าลืม import ตัวที่ถูกต้อง จะได้ `Text` ของ Flutter ที่ไม่แปล
- ข้อความที่ยังไม่มีคำแปลจะผ่านออกไปเป็นภาษาอังกฤษเงียบ ๆ ไม่ error

### แผนที่คำแปลสองทิศ

```dart
const _thaiTranslations = <String, String>{ ... };      // EN → TH
const _englishTranslations = <String, String>{ ... };   // TH → EN
```

`_englishTranslations` มีไว้แปล **ข้อความ error ที่ Backend ส่งมาเป็นไทย**
เช่น `'ต้องส่ง enabled เป็น true หรือ false'` ให้กลายเป็นอังกฤษ
Backend จึงไม่ต้องรู้ภาษาของผู้ใช้เลย

### กฎ regex สำหรับข้อความที่มีตัวแปร

```dart
match = RegExp(r'^Estimated cost: THB ([0-9,]+\.[0-9]{2})$').firstMatch(source);
if (match != null) return 'ค่าไฟโดยประมาณ: ${match[1]} บาท';
```

**ทำไมต้องมี** — ภาษาไทยวางคำว่า "บาท" ไว้ **ท้าย** ตัวเลข
ส่วนอังกฤษวาง `THB` ไว้ **หน้า** ถ้าแปลทีละคำแล้วต่อกันเอง จะได้

```
ค่าไฟโดยประมาณ: บาท 1,420.13   ← ผิด
```

ต้องส่งประโยคอังกฤษทั้งก้อนเข้าไปให้ตัวแปลจัดลำดับใหม่

```dart
// ถูก
Text('Estimated cost: THB ${formatDecimal(cost)}')

// ผิด
Text('${context.tr('Estimated cost')}: ${context.tr('THB')} $cost')
```

> **นี่เป็นบั๊กจริงที่เกิดขึ้นในโปรเจกต์** และเทสต์จับได้ แต่ไปตกที่ขั้นตอน
> ก่อนหน้าทุกรอบจนไม่มีใครเห็นอยู่นาน

### `const` map ห้ามมีคีย์ซ้ำ

`_thaiTranslations` เป็น `const` map ซึ่ง Dart **ปฏิเสธคีย์ซ้ำตอนคอมไพล์**
ทุกครั้งที่เพิ่มคำแปลต้องเช็คก่อนว่ามีอยู่แล้วหรือยัง ไม่งั้นคอมไพล์ไม่ผ่าน

ข้อจำกัดนี้ดูน่ารำคาญแต่มีประโยชน์ — มันกันไม่ให้มีคำแปลสองชุดของข้อความเดียวกัน
ที่ขัดแย้งกันเอง

---

## 5. หน้าจอสำคัญ

| หน้า | ไฟล์ | จุดที่น่าสนใจ |
|---|---|---|
| หน้าหลัก | `home_screen.dart` | ยอดรวมค่าไฟ + การ์ดแจ้งเตือน |
| รายการห้อง | `rooms_screen.dart` | นาฬิกานับถอยหลังบนการ์ดห้อง |
| ควบคุมแอร์ | `room_control_screen.dart` | รีโมตเต็มรูปแบบ + ค่าไฟสด |
| สถิติ | `analytics_screen.dart` | กราฟที่แตะดูรายจุดได้ |
| ฐานข้อมูลค่าไฟ | `energy_database_screen.dart` | 1,300 บรรทัด ค่าไฟสด + ส่งออก Excel |
| ตั้งค่า | `application_settings_screen.dart` | ธีม ภาษา ขนาดตัวอักษร สวิตช์ระบบ |
| แจ้งเตือน | `notification_settings_screen.dart` | สวิตช์แยกตามชนิด |

### กราฟค่าไฟ — `widgets/energy_usage_chart.dart`

จุดที่ออกแบบมาแล้วมีเหตุผล

**พิกัดแยกเป็นคลาสของตัวเอง**

```dart
abstract final class EnergyChartGeometry {
  static const double left = 18;
  static const double top = 24;
  static const double bottom = 28;
  static List<Offset> resolve(Size size, List<double> values) { ... }
}
```

ทั้งตัววาด (`CustomPainter`) และตัวรับสัมผัส (หาจุดที่ใกล้ที่สุด)
ใช้ฟังก์ชันนี้ตัวเดียวกัน **ถ้าคำนวณแยกกัน จุดที่แตะได้จะเลื่อนจากจุดที่เห็น
ทันทีที่มีคนแก้ระยะขอบ** ซึ่งเป็นบั๊กที่หายากมาก

**หน่วยร่วมของทั้งชุด**

```dart
final reference = energyScaleReference(values);  // ค่าสูงสุดของชุด
formatEnergy(value, scaleReference: reference)
```

ถ้าปล่อยให้แต่ละจุดเลือกหน่วยเอง จุดที่เป็น `900 Wh` จะไปอยู่ข้าง `1.2 kWh`
แล้วเลข 900 จะดูใหญ่กว่าทั้งที่น้อยกว่า

**การเว้นระยะป้ายคิดจากความกว้างจริง**

```dart
final spacing = points[1].dx - points.first.dx;
final needed = widest + 8;
final step = spacing <= 0
    ? points.length
    : (spacing >= needed ? 1 : (needed / spacing).ceil());
```

ไม่ได้เดาจากจำนวนจุด แต่วัดความกว้างของป้ายที่ยาวที่สุดจริง ๆ
ภาษาไทยกับตัวเลขยาวไม่เท่ากัน การเดาจึงผิดได้ง่าย

**`shouldRepaint` เทียบทีละสมาชิก**

```dart
bool _sameItems<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}
```

`List != List` ใน Dart เทียบ **ตัวตน** ไม่ใช่เนื้อหา ทุกครั้งที่ `build()`
จะสร้าง List ใหม่ ถ้าเทียบด้วย `!=` ตรง ๆ จะวาดใหม่ทุกเฟรมโดยไม่จำเป็น

> เขียนฟังก์ชันเองแทน `listEquals` เพราะ `listEquals` อยู่ใน
> `foundation.dart` ซึ่ง `widgets.dart` ส่งต่อมาให้แค่บางชื่อด้วย `show`
> และไม่มีชื่อนี้อยู่ด้วย — **เป็นบั๊กจริงที่เกิดขึ้นแล้วในโปรเจกต์นี้**

---

## 6. `utils/number_format.dart` — การจัดหน่วยพลังงาน

```dart
EnergyDisplay formatEnergy(double kwh, {double? scaleReference})
```

| ช่วงค่า | หน่วย | ตัวอย่าง |
|---|---|---|
| ต่ำกว่า 1 kWh | `Wh` | `0.005 kWh` → `5.00 Wh` |
| 1–999 kWh | `kWh` | `12.5 kWh` |
| ตั้งแต่ 1000 kWh | `MWh` | `2400 kWh` → `2.40 MWh` |

**ทำไมต้องมี** — เดิมทุกหน้าจอตรึงไว้ที่ `kWh` ทศนิยมตำแหน่งเดียว
พอลองวัดโหลดเล็ก ๆ อย่างที่ชาร์จมือถือ (21 W) ค่าจริง `0.005 kWh`
ถูกปัดเหลือ `0.0 kWh` ทุกจุด อ่านอะไรไม่ได้เลย

**จำนวนทศนิยมลดลงเมื่อตัวเลขใหญ่ขึ้น**

```dart
int _energyDecimalPlaces(double scaledValue) {
  final size = scaledValue.abs();
  if (size >= 100) return 0;
  if (size >= 10) return 1;
  if (size >= 1) return 2;
  return 3;
}
```

เหตุผลคือ **ทศนิยมของ `142.4 kWh` ไม่มีใครใช้ แต่ทศนิยมของ `0.400 Wh`
คือค่าทั้งหมดที่มี**

---

## 7. การทดสอบฝั่งแอป

```powershell
flutter analyze
flutter test
```

**89 เคส** กระจายอยู่ใน

| ไฟล์ | ทดสอบอะไร |
|---|---|
| `widget_test.dart` | เส้นทางหลักทั้งแอป ล็อกอิน → หน้าหลัก → สลับภาษา |
| `energy_database_test.dart` | หน้าฐานข้อมูลค่าไฟและตัวเลือกส่งออก |
| `app_preferences_test.dart` | ขนาดตัวอักษรและสวิตช์แจ้งเตือน |
| `system_settings_test.dart` | สวิตช์รวมและการถอยกลับเมื่อเซิร์ฟเวอร์ปฏิเสธ |
| `auto_off_countdown_test.dart` | นาฬิกานับถอยหลัง |
| `app_localizations_test.dart` | คำแปล |
| `user_management_test.dart` | จัดการผู้ใช้ |

### บทเรียนจากเทสต์ชุดนี้

**จอทดสอบมาตรฐานคือ 800×600 ซึ่งเตี้ยกว่าหน้าจอจริง**

```dart
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
```

การ์ดล็อกอินสูงราว 726px ปุ่ม `เข้าสู่ระบบ` จึงอยู่ใต้ขอบจอ
`tap()` ยิงไม่โดน และของที่อยู่ใต้ขอบจอใน `ListView` **จะไม่ถูกสร้างขึ้นมาเลย**
`finder` จึงหาไม่เจอ ทั้งที่บนเครื่องจริงเลื่อนดูได้ปกติ

`addTearDown(tester.view.reset)` สำคัญ ไม่งั้นขนาดจอจะรั่วไปเทสต์ถัดไป

**Flutter รุ่นใหม่เพิ่ม assertion ว่า `ListTile` ห้ามอยู่ใต้กล่องที่มีสีพื้นหลัง**

```dart
child: Material(
  type: MaterialType.transparency,
  child: Column(children: [ ... SwitchListTile(...) ... ]),
),
```

เพราะ `ListTile` วาดพื้นหลังและเอฟเฟกต์กดลงบน `Material` ที่ใกล้ที่สุด
ถ้ากล่องที่มีสีอยู่ระหว่างกลาง เอฟเฟกต์จะถูกบัง
`MaterialType.transparency` ให้ `Material` โดยไม่เพิ่มสีทับ
