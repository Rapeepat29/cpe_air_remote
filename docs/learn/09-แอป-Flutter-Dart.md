# 09 · แอป Flutter (ภาษา Dart)

> แอปคือสิ่งที่ผู้ใช้เห็นและจับต้อง บทนี้สอน
> (1) Dart เท่าที่ต้องใช้ (2) Widget และ State คืออะไร (3) โครงสร้างโฟลเดอร์ `lib/`
> (4) ข้อมูลไหลจากหน้าจอไป Backend อย่างไร (5) คำสั่ง `flutter` ทั้งหมด
> (6) สร้างไฟล์ติดตั้ง APK (7) ทดสอบ
> เชิงลึก: `docs/study/03-flutter-app.md`

---

## ส่วนที่ 1 · Flutter และ Dart คืออะไร

- **Dart** = ภาษาโปรแกรม (โดย Google) หน้าตาคล้าย Java/JavaScript
- **Flutter** = เฟรมเวิร์กสร้างหน้าจอ เขียนครั้งเดียว ได้แอป Android, iOS, Windows, macOS, Linux, Web
- โปรเจกต์นี้ใช้ Android (มือถือ, ใช้ตั้งค่าบอร์ดผ่าน Bluetooth) และ Windows (ทดสอบ/ใช้บนคอม)

---

## ส่วนที่ 2 · Dart ที่ต้องรู้

### 2.1 ตัวแปรและชนิด

```dart
int floor = 3;
double watts = 465.2;
String room = '16302';
bool isOnline = true;
var auto = 'Dart เดาชนิดให้';       // ชนิด String
final name = 'แอร์ 1';             // กำหนดครั้งเดียว ตอนรัน
const timeout = Duration(seconds: 15);   // ค่าคงที่ตั้งแต่ตอนคอมไพล์
List<String> rooms = ['16301', '16302'];
Map<String, dynamic> json = {'roomNumber': '16302', 'floorNumber': 3};
```

### 2.2 Null safety — `?`, `!`, `??`

Dart บังคับให้บอกว่าตัวแปรไหน **ว่างได้**

```dart
String name = 'x';            // ห้ามเป็น null เด็ดขาด
String? bleName;              // ? = เป็น null ได้
bleName?.length;              // ถ้า null → ได้ null ไม่ error
bleName ?? 'ไม่มีชื่อ';          // ถ้า null → ใช้ค่าขวา
bleName!;                     // ! = "ฉันรับรองว่าไม่ null" (ถ้าผิด แอปพัง) ใช้ให้น้อยที่สุด
```

ตัวอย่างจริง `lib/models/room.dart`

```dart
floor: (json['floorNumber'] as num?)?.toInt() ?? 0,
```

อ่านว่า: เอา `floorNumber` จาก JSON → ถ้าเป็นตัวเลขแปลงเป็น int → ถ้าไม่มีใช้ 0

### 2.3 ฟังก์ชันและพารามิเตอร์แบบมีชื่อ

```dart
int add(int a, int b) => a + b;

// พารามิเตอร์แบบมีชื่อ {…} ใช้ทั่วทั้ง Flutter
void greet({required String name, int times = 1}) { ... }
greet(name: 'สมชาย', times: 2);
```

### 2.4 Class

```dart
class Room {
  Room({required this.number, required this.floor, this.isOccupied = false});

  final String number;      // final = ตั้งครั้งเดียวในตัวสร้าง
  final int floor;
  bool isOccupied;          // เปลี่ยนได้

  factory Room.fromJson(Map<String, dynamic> json) {     // ตัวสร้างพิเศษ: แปลง JSON → Room
    return Room(
      number: json['roomNumber'] as String? ?? '',
      floor: (json['floorNumber'] as num?)?.toInt() ?? 0,
    );
  }
}
```

### 2.5 Async

เหมือน JavaScript ต่างที่ใช้ `Future` แทน Promise

```dart
Future<List<Room>> fetchRooms() async {
  final data = await _request('GET', '/rooms');
  ...
}
```

### 2.6 `abstract interface class` — สัญญา

```dart
abstract interface class RoomRepository {
  Future<List<Room>> fetchRooms();
  Future<Room> createRoom(Room room);
}

class RoomService implements RoomRepository { ... }   // ตัวจริง ยิง HTTP
class _MemoryRoomRepository implements RoomRepository { ... }   // ตัวปลอม ใช้ใน test
```

"interface" บอกว่า **ต้องมีฟังก์ชันอะไรบ้าง** โดยไม่สนว่าทำอย่างไร
หน้าจอรู้จักแค่ `RoomRepository` → ตอนใช้จริงใส่ `RoomService`, ตอน test ใส่ตัวปลอม

---

## ส่วนที่ 3 · Widget — ทุกอย่างบนจอคือ Widget

### 3.1 แนวคิด
หน้าจอ Flutter ประกอบจาก **Widget** ซ้อนกันเป็นต้นไม้ เหมือนกล่องในกล่อง

```text
MaterialApp
 └─ Scaffold (โครงหน้า: แถบบน + เนื้อหา + แถบล่าง)
     ├─ AppBar
     │   └─ Text('ห้อง')
     └─ Column (เรียงแนวตั้ง)
         ├─ FloorSelector (ปุ่มเลือกชั้น — widget ของโปรเจกต์)
         └─ ListView (รายการเลื่อนได้)
             ├─ Card → Row → [Icon, Text('16301'), StatusPill]
             └─ Card → ...
```

Widget ที่เจอบ่อย

| Widget | ใช้ทำอะไร |
|---|---|
| `Text` | ข้อความ |
| `Icon` | ไอคอน |
| `Row` / `Column` | เรียงแนวนอน / แนวตั้ง |
| `Padding`, `SizedBox` | เว้นระยะ |
| `Container`, `Card` | กล่อง มีสี ขอบ เงา |
| `ListView` | รายการที่เลื่อนได้ |
| `ElevatedButton`, `TextButton`, `IconButton` | ปุ่ม |
| `TextField` | ช่องกรอก |
| `Switch` | สวิตช์ |
| `Scaffold`, `AppBar` | โครงหน้า |
| `Navigator.push` | เปิดหน้าใหม่ |
| `showDialog` | กล่องโต้ตอบ |

### 3.2 StatelessWidget vs StatefulWidget

| | Stateless | Stateful |
|---|---|---|
| มีข้อมูลที่เปลี่ยนเองไหม | ไม่มี แสดงตามที่ได้รับ | มี (เช่นชั้นที่เลือก) |
| ตัวอย่าง | `StatusPill`, `SectionTitle` | `RoomsScreen`, `LoginScreen` |

ตัวอย่างจริง `lib/screens/rooms_screen.dart`

```dart
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({required this.rooms, required this.controller,
                     required this.isAdmin, required this.onOpenRoom, super.key});
  final List<Room> rooms;
  ...
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  int _selectedFloor = 3;           // ← state: ชั้นที่เลือกอยู่ (ขึ้นต้นด้วย _ = private)

  @override
  Widget build(BuildContext context) {
    final filteredRooms = widget.rooms
        .where((room) => room.floor == _selectedFloor)
        .toList();
    ...
  }
}
```

เมื่อผู้ใช้กดเปลี่ยนชั้น

```dart
setState(() => _selectedFloor = 2);   // เปลี่ยนค่า + สั่งวาดหน้าจอใหม่ (build ถูกเรียกอีกรอบ)
```

> 💡 **หลักสำคัญ**: หน้าจอ = ฟังก์ชันของข้อมูล  เปลี่ยนข้อมูล → Flutter วาดใหม่ให้เอง
> ไม่ต้องไปสั่ง "เปลี่ยนตัวหนังสือบรรทัดที่ 3" เอง

### 3.3 ChangeNotifier + AnimatedBuilder — state ที่แชร์หลายหน้าจอ

ข้อมูลบางอย่าง (ผู้ใช้ที่ล็อกอิน, รายการห้อง) หลายหน้าต้องใช้ร่วมกัน
โปรเจกต์เก็บไว้ใน **Controller** ที่ `extends ChangeNotifier`

```dart
class RoomController extends ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;

  Future<void> reload() async {
    isLoading = true;
    notifyListeners();                          // ← "ข้อมูลเปลี่ยนแล้ว ใครฟังอยู่วาดใหม่ได้"
    final loaded = await repository.fetchRooms();
    ...
    isLoading = false;
    notifyListeners();
  }
}
```

หน้าจอฟังด้วย `AnimatedBuilder` (จาก `lib/main.dart`)

```dart
home: AnimatedBuilder(
  animation: _authController,                   // ฟัง controller นี้
  builder: (context, _) {
    return switch (_authController.status) {    // วาดใหม่ทุกครั้งที่ notifyListeners()
      AuthStatus.loading   => const AuthLoadingScreen(),
      AuthStatus.signedOut => LoginScreen(controller: _authController),
      AuthStatus.signedIn  => AppShell(...),
    };
  },
),
```

นี่คือเหตุผลที่กดออกจากระบบแล้ว **หน้าล็อกอินขึ้นมาเอง** — `status` เปลี่ยน → สร้างหน้าใหม่

---

## ส่วนที่ 4 · โครงสร้าง `lib/` และการไหลของข้อมูล

```text
lib/
├── main.dart          ประกอบทุกชิ้น: สร้าง service/controller แล้วส่งต่อให้หน้าจอ
├── config/            api_config.dart — ที่อยู่ Backend
├── models/            "รูปร่างของข้อมูล" + fromJson/toJson
├── services/          *_repository.dart = สัญญา, *_service.dart = ตัวจริงที่ยิง HTTP/BLE
├── controllers/       ถือ state + ตรรกะของหน้าจอ (ChangeNotifier)
├── screens/           หน้าจอทั้งหน้า
├── widgets/           ชิ้นส่วนที่ใช้ซ้ำ (การ์ดแอร์, กราฟ, ปุ่มเลือกชั้น...)
├── theme/             สี ฟอนต์ ธีมสว่าง/มืด
├── localization/      ไทย/อังกฤษ
├── utils/             จัดรูปแบบตัวเลข, บันทึกไฟล์, ค่าตั้งการแจ้งเตือน
└── data/              mock_data.dart — ข้อมูลตัวอย่าง
```

### การไหลของข้อมูล: ตัวอย่างโหลดรายการห้อง

```text
RoomsScreen (หน้าจอ)
   │ เรียก controller.initialize()
   ▼
RoomController (controllers/room_controller.dart)
   │ repository.fetchRooms()    + ตั้ง Timer ดึงซ้ำทุก 10 วินาที
   ▼
RoomRepository (สัญญา) ← ตัวจริงคือ RoomService (services/room_service.dart)
   │ อ่าน token จาก FlutterSecureStorage
   │ http GET  {ApiConfig.baseUrl}/rooms   Authorization: Bearer <token>
   ▼
Backend  GET /api/rooms  → JSON {"rooms":[{...},{...}]}
   │
   ▼
RoomService._decode()  ตรวจ status code, แปลง JSON
   │ Room.fromJson() ทีละห้อง
   ▼
RoomController อัปเดตรายการ → notifyListeners()
   ▼
RoomsScreen วาดใหม่
```

### `services/room_service.dart` — ส่วนที่ยิง HTTP

```dart
Future<Map<String, dynamic>> _request(String method, String path, {Map<String, dynamic>? body}) async {
  final token = await _storage.read(key: _accessTokenKey);           // (1)
  if (token == null || token.isEmpty) {
    throw const ApiException('Please sign in again.', statusCode: 401);
  }
  try {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll({                                                // (2)
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);                 // (3)
    final streamed = await _client.send(request).timeout(_timeout);    // (4) รอไม่เกิน 15 วินาที
    final response = await http.Response.fromStream(streamed);
    return _decode(response);                                           // (5)
  } on TimeoutException {
    throw const ApiException('The server took too long to respond.');
  } catch (_) {
    throw const ApiException('Could not connect to the server. Check the network and API_BASE_URL.');
  }
}
```

1. **FlutterSecureStorage** = ที่เก็บลับของระบบ (Android Keystore / Windows Credential) เก็บ token ไว้หลังล็อกอิน
2. แนบ token ทุกคำขอ
3. แปลง Map เป็น JSON
4. ป้องกันแอปค้างถ้าเน็ตช้า
5. status ไม่ใช่ 2xx → โยน `ApiException` พร้อมข้อความภาษาไทยจาก Backend

> 💡 ข้อความ "Could not connect to the server. Check the network and API_BASE_URL."
> ที่เห็นในแอป = แอปต่อ Backend ไม่ได้เลย (ไม่ใช่ Backend ตอบ error)
> ตรวจว่า Backend รันอยู่ และ `API_BASE_URL` ถูก

### `main.dart` — Dependency Injection แบบง่าย

```dart
class CpeAirRemoteApp extends StatefulWidget {
  const CpeAirRemoteApp({this.authRepository, this.roomRepository, ...});
  final AuthRepository? authRepository;
  ...
}

// ใน initState
_roomRepository = widget.roomRepository ?? RoomService();
```

อ่านว่า: ถ้ามีคนส่ง repository มาให้ (ตอน test) ใช้อันนั้น ถ้าไม่มี (ตอนใช้จริง) สร้าง `RoomService()`
→ test ทั้งแอปได้โดยไม่ต้องมี Backend จริง

### ไลบรารีใน `pubspec.yaml`

| แพ็กเกจ | ทำอะไร |
|---|---|
| `flutter_localizations` | ข้อความระบบภาษาไทย (ปุ่มยกเลิก, ปฏิทิน) |
| `flutter_secure_storage` | เก็บ token/รหัสที่จำไว้ อย่างปลอดภัย |
| `flutter_blue_plus` (+`_winrt`) | Bluetooth Low Energy (Android + Windows) ใช้ตั้งค่า ESP32 |
| `http` | เรียก API |
| `file_selector`, `path_provider`, `share_plus` | เลือกไฟล์ Excel นำเข้า, บันทึก/แชร์ไฟล์ส่งออก |
| `flutter_lints` (dev) | กฎตรวจรูปแบบโค้ด (`flutter analyze`) |

`version: 3.16.0+32` = ชื่อรุ่น `3.16.0` + เลข build `32` (Android ใช้เลข build ตัดสินว่าอัปเดตทับได้ไหม ต้องเพิ่มทุกครั้งที่แจก)

### การแปลภาษา
`localization/localized_material.dart` สร้าง `Text` ของตัวเองมาแทน `Text` ของ Flutter
ทุกข้อความผ่านตัวแปลโดยอัตโนมัติ หน้าจอจึงเขียน `Text('ห้อง')` ธรรมดาได้เลย
(ไฟล์ในโปรเจกต์ import `localized_material.dart` แทน `package:flutter/material.dart`)

---

## ส่วนที่ 5 · ที่อยู่ Backend: `--dart-define`

`lib/config/api_config.dart`

```dart
static const baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://rmutt-energy.duckdns.org/api',
);
```

- `String.fromEnvironment` = อ่านค่าที่ส่งมา **ตอนคอมไพล์** ผ่าน `--dart-define`
- ถ้าไม่ส่ง → ใช้เซิร์ฟเวอร์จริง

| รันที่ไหน | Backend อยู่ไหน | คำสั่ง |
|---|---|---|
| Windows | เครื่องเดียวกัน | `flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api` |
| Android Emulator | คอมที่รัน emulator | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api` |
| มือถือจริง (Wi-Fi เดียวกัน) | คอม | `flutter run --dart-define=API_BASE_URL=http://<LAN IP>:3000/api` |
| ที่ไหนก็ได้ | เซิร์ฟเวอร์จริง | `flutter run` (ไม่ต้องใส่) |

> ⚠️ **มือถือจริง + HTTP (ไม่ใช่ HTTPS)**: Android บล็อก HTTP ธรรมดาโดยค่าเริ่มต้น
> ต้องเพิ่ม `android:usesCleartextTraffic="true"` ใน `<application>` ของ
> `android/app/src/main/AndroidManifest.xml` **เฉพาะตอนทดสอบ** แล้วเอาออกก่อนแจกจริง
> และเปิด Windows Firewall ให้พอร์ต 3000 (บท 15)

---

## ส่วนที่ 6 · คำสั่ง `flutter` ทั้งหมดที่ใช้

> 📁 ทุกคำสั่งรันที่โฟลเดอร์หลัก `cpe_air_remote` (ที่มี `pubspec.yaml`)

### 6.1 เตรียม

| คำสั่ง | ทำอะไร | ใช้เมื่อ |
|---|---|---|
| `flutter doctor` | ตรวจเครื่องมือครบไหม | ติดตั้งใหม่ / มีปัญหา |
| `flutter devices` | อุปกรณ์ที่รันได้ | ก่อน run |
| `flutter create --platforms=android,windows,web .` | สร้างโฟลเดอร์แพลตฟอร์มที่ขาด | ครั้งแรก |
| `flutter pub get` | ดาวน์โหลดแพ็กเกจตาม `pubspec.yaml` | ครั้งแรก / แก้ pubspec |
| `flutter pub outdated` | แพ็กเกจที่มีรุ่นใหม่ | ดูแลรักษา |
| `flutter clean` | ลบผล build เก่าทั้งหมด (`build\`, `.dart_tool\`) | build แปลก ๆ / เปลี่ยนรุ่น Flutter |

### 6.2 รันระหว่างพัฒนา

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

- `-d windows` = เลือกอุปกรณ์ (ดูชื่อจาก `flutter devices` เช่น `-d chrome`, `-d emulator-5554`, หรือ ID มือถือ)

**ระหว่างที่แอปรันอยู่ พิมพ์ในหน้าต่าง PowerShell ได้**

| ปุ่ม | ชื่อ | ทำอะไร |
|---|---|---|
| `r` | **Hot reload** | ใส่โค้ดใหม่เข้าแอปใน ~1 วินาที **state ไม่หาย** (ยังล็อกอินอยู่ ยังอยู่หน้าเดิม) |
| `R` | Hot restart | เริ่มแอปใหม่ state หาย (ใช้เมื่อแก้ `initState`, `main`) |
| `q` | Quit | ปิดแอป |
| `d` | Detach | ปล่อยแอปรันต่อ แต่เลิกเชื่อมกับ terminal |
| `h` | Help | ดูปุ่มทั้งหมด |

> 💡 Hot reload คือจุดแข็งที่สุดของ Flutter แก้สี แก้ข้อความ กด `r` เห็นผลทันที

### 6.3 ตรวจคุณภาพ

```powershell
flutter analyze            # หาข้อผิดพลาดและโค้ดที่ไม่ตามกฎ (ไม่ต้องรันแอป)
flutter test               # รันชุดทดสอบทั้งหมดใน test\
flutter test test/number_format_test.dart    # ไฟล์เดียว
dart format lib            # จัดรูปแบบโค้ดให้เป็นมาตรฐาน
```

### 6.4 สร้างไฟล์ติดตั้ง

```powershell
# Android APK
flutter build apk --release --dart-define=API_BASE_URL=https://<โดเมน>/api
# ผลลัพธ์: build\app\outputs\flutter-apk\app-release.apk

# Android APK แบบ debug (ติดตั้งง่าย ไม่ต้องเซ็น ขนาดใหญ่กว่า ช้ากว่า)
flutter build apk --debug --dart-define=API_BASE_URL=https://<โดเมน>/api

# Windows
flutter build windows --release --dart-define=API_BASE_URL=https://<โดเมน>/api
# ผลลัพธ์: build\windows\x64\runner\Release\  (คัดลอกทั้งโฟลเดอร์ไปใช้)
```

### 6.5 สคริปต์สร้าง APK ของโปรเจกต์

```powershell
.\create-keystore.ps1      # ครั้งเดียวในชีวิตโปรเจกต์
.\build-apk.ps1            # ทุกครั้งที่จะแจกแอปรุ่นใหม่
.\build-apk.ps1 -DebugApk  # APK debug
.\build-apk.ps1 -ApiBaseUrl https://อื่น/api
```

`build-apk.ps1` ทำ 4 ขั้น
1. ถ้าไม่มีโฟลเดอร์ `android` → `flutter create --platforms=android --org th.ac.rmutt.cpe .`
2. เติมสิทธิ์ที่ขาดใน `AndroidManifest.xml`: `INTERNET`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`,
   `ACCESS_FINE_LOCATION` (Android ≤ 11 ต้องมีสิทธิ์ตำแหน่งจึงสแกน BLE ได้)
3. `flutter pub get` → `flutter build apk --release --dart-define=API_BASE_URL=...`
   (ที่อยู่อ่านจาก `deploy\server.config.json`)
4. บอกที่อยู่และขนาดไฟล์ APK

**Keystore คืออะไร** — กุญแจดิจิทัลที่ใช้ "เซ็น" APK Android ยอมให้ติดตั้งทับรุ่นเก่า
**ก็ต่อเมื่อเซ็นด้วยกุญแจเดียวกัน**

`create-keystore.ps1`
- หา `keytool` (มากับ Android Studio/JDK)
- ถามรหัสผ่าน แล้วสร้างไฟล์ `%USERPROFILE%\rmutt-save-energy-upload.jks` (RSA 2048, อายุ 10,000 วัน)
- เขียน `android\key.properties` ให้ Gradle ใช้เซ็นอัตโนมัติ

> ⚠️ **สำรองไฟล์ `.jks` และรหัสผ่านไว้อย่างน้อย 2 ที่** ถ้าหาย
> จะอัปเดตแอปที่ผู้ใช้ติดตั้งไปแล้วไม่ได้อีกเลย ทุกคนต้องลบแอปแล้วลงใหม่

ติดตั้ง APK บนมือถือ: ส่งไฟล์เข้ามือถือ → เปิด → อนุญาต "ติดตั้งจากแหล่งที่ไม่รู้จัก"
หรือเสียบสาย USB แล้ว `flutter install` (หลัง build)

---

## ส่วนที่ 7 · การทดสอบฝั่งแอป

ไฟล์ใน `test\` มี 2 แบบ

**Unit test** — ทดสอบฟังก์ชัน เช่น `test/number_format_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('ชื่อการทดสอบ', () {
    expect(ผลที่ได้, ค่าที่คาดหวัง);
  });
}
```

**Widget test** — สร้างแอปทั้งแอปในหน่วยความจำ กดปุ่ม ตรวจข้อความ เช่น `test/widget_test.dart`

```dart
testWidgets('requires login before showing the energy dashboard', (tester) async {
  await tester.pumpWidget(
    CpeAirRemoteApp(
      authRepository: _FakeAuthRepository(),            // ตัวปลอม ไม่ต้องมี Backend
      roomRepository: _MemoryRoomRepository(),
      energyRepository: _MemoryEnergyRepository(),
      ...
    ),
  );
  await tester.pumpAndSettle();                         // รอจนภาพนิ่ง

  expect(find.text('RMUTT Save Energy'), findsOneWidget);
  expect(find.text('เข้าสู่ระบบ'), findsNWidgets(2));     // หัวข้อ + ปุ่ม

  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'admin');        // พิมพ์ username
  await tester.enterText(fields.at(1), 'test-password');
  await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
  await tester.pumpAndSettle();

  expect(find.text('CPE Green Office'), findsOneWidget);  // เข้าหน้าหลักแล้ว
  expect(find.text('42.5'), findsOneWidget);              // ตัวเลขจาก energyRepository ปลอม

  await tester.tap(find.text('ควบคุม'));                  // กดแท็บ "ควบคุม"
  await tester.pumpAndSettle();
  expect(find.text('ห้อง 16301'), findsOneWidget);
});
```

| คำสั่ง | ความหมาย |
|---|---|
| `tester.pumpWidget(w)` | วาด widget |
| `tester.pump()` / `pumpAndSettle()` | เดินเวลา / รอจนแอนิเมชันจบ |
| `find.text('x')`, `find.byType(T)`, `find.byIcon(i)`, `find.widgetWithText(T, 'x')` | หา widget |
| `tester.tap(f)`, `tester.enterText(f, 'x')` | กด / พิมพ์ |
| `expect(f, findsOneWidget / findsNWidgets(n) / findsNothing / findsWidgets)` | ตรวจ |

---

## ส่วนที่ 8 · ลองแก้แอปเอง (แบบฝึกหัดลงมือ)

**เป้าหมาย 1: เปลี่ยนชั้นเริ่มต้นในหน้าห้อง**
1. `flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api`
2. เปิด `lib/screens/rooms_screen.dart` หา `int _selectedFloor = 3;`
3. เปลี่ยนเป็น `1` บันทึก แล้วกด `R` (hot restart เพราะเป็นค่าเริ่มต้นของ state)
4. เข้าหน้าห้อง ต้องเห็นชั้น 1 ก่อน → แก้กลับเป็น `3`

**เป้าหมาย 2: ดูว่าสีมาจากไหน**
1. เปิด `lib/theme/app_theme.dart` หาสีเขียวหลัก `static const primary = Color(0xFF0D7A4B);`
   (`0xFF` = ทึบ 100%, `0D7A4B` = รหัสสี RGB แบบเดียวกับในเว็บ)
2. เปลี่ยนเป็นสีอื่น กด `r` ดูผล แล้วเปลี่ยนกลับ

**เป้าหมาย 3: ตามรอยปุ่ม**
1. ในแอปกดปุ่ม Power ของแอร์ แล้วหาใน VS Code (`Ctrl+Shift+F`) ว่าปุ่มนั้นอยู่ไฟล์ไหน
   (ใบ้: `widgets/air_control_card.dart`)
2. ตามต่อไปว่าเรียกฟังก์ชันอะไรใน controller และ service จนถึงบรรทัดที่ยิง HTTP
   (ใบ้: `controllers/air_conditioner_controller.dart` → `services/air_conditioner_service.dart`)

---

## ส่วนที่ 9 · ปัญหาที่พบบ่อยฝั่ง Flutter

| อาการ | สาเหตุ / วิธีแก้ |
|---|---|
| `No supported devices connected` | ยังไม่ได้เลือก `-d windows` หรือยังไม่ได้ติดตั้ง Visual Studio C++ |
| `Unable to find suitable Visual Studio toolchain` | ติดตั้ง Workload "Desktop development with C++" |
| `Because cpe_air_remote requires SDK version >=3.8.0` | Flutter เก่าไป → `flutter upgrade` |
| build พังหลังอัปเดต Flutter/แพ็กเกจ | `flutter clean` แล้ว `flutter pub get` |
| แอปล็อกอินไม่ได้ "Could not connect to the server" | Backend ไม่รัน / `API_BASE_URL` ผิด / firewall |
| ล็อกอินได้แต่ข้อมูลเป็นของเซิร์ฟเวอร์จริง | ลืมใส่ `--dart-define` แอปเลยใช้ค่าเริ่มต้น |
| หน้า Bluetooth ไม่เจอบอร์ด | บอร์ดไม่ได้อยู่ใน Setup Mode / เปิด Bluetooth ไม่ได้ / Android ไม่ได้ให้สิทธิ์ (ดูบท 11–12) |
| `Gradle task assembleRelease failed` | ดูข้อความด้านบนให้ละเอียด, `flutter doctor --android-licenses`, ตรวจ `key.properties` |

---

## ฟีเจอร์ที่เพิ่มล่าสุด (9–14 ต.ค. 2569, แอป 3.16.0+32)

| ฟีเจอร์ | ไฟล์หลัก |
|---|---|
| กราฟพลังงานเปลี่ยนเป็น **กราฟแท่ง** ปัดสเกลแกนให้สวย (1, 2, 2.5, 4, 5 × 10^n) | `lib/widgets/energy_usage_chart.dart` |
| จัดการตารางเรียนจากมือถือ: จองห้อง, ปฏิทินภาคเรียน, นำเข้าแบบแทนที่ทั้งหมด, ส่งออก CSV | `lib/screens/booking_editor_screen.dart`, `term_calendar_screen.dart`, `schedule_management_screen.dart` |
| ป้ายบอกชนิดการควบคุมแอร์ (IR / ต่อสาย Daikin) | `lib/widgets/air_control_badge.dart` |
| ถือว่าแอร์ "เปิด" เมื่อสั่งเปิด **หรือ** PZEM วัดได้ว่ากำลังทำงาน | `isPoweredOn = isOn \|\| (pzemAvailable && isRunning)` |
| ลบห้องแล้วสั่งล้างการตั้งค่าบอร์ด (unprovision) ให้ด้วย | รอการตอบกลับ `boardCleared` 4 วินาที |
| GitHub Actions: `test.yml` (analyze + test), `build-android.yml`, `build-ios.yml` | `.github/workflows/` |

---

## สรุปบท

- Dart: null safety (`?`, `??`, `!`), named parameter, class, `Future`/`async`
- ทุกอย่างคือ Widget, state เปลี่ยน → `setState`/`notifyListeners` → วาดใหม่
- ชั้น: screens → controllers → repositories(สัญญา)/services(ตัวจริง) → Backend
- ที่อยู่ Backend กำหนดตอน build ด้วย `--dart-define=API_BASE_URL=...`
- `flutter run` + `r` (hot reload), `flutter analyze`, `flutter test`, `flutter build apk`
- APK ต้องเซ็นด้วย keystore เดิมเสมอ — สำรองไว้

## 🧪 แบบฝึกหัด

1. รัน `flutter analyze` และ `flutter test` ให้ผ่านทั้งหมด
2. ทำเป้าหมาย 1–3 ในส่วนที่ 8
3. เปิด `lib/models/air_conditioner.dart` หาว่า JSON ฟิลด์ `powerWatts` ถูกเก็บลงตัวแปรชื่ออะไร (ใบ้: `power`)
4. อธิบายว่าทำไม test ทั้งแอปรันได้โดยไม่ต้องเปิด Backend
5. ถ้าจะให้เพื่อนที่อยู่ Wi-Fi เดียวกันลองแอปบนมือถือกับ Backend ในเครื่องคุณ ต้องทำอะไรบ้าง (ตอบให้ครบ 4 ข้อ)

ถัดไป: **บท 10 เว็บแอป**
