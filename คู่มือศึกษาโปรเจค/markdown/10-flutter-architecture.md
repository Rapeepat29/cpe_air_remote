# แอป Flutter ตอนที่ 1: โครงสร้าง ข้อมูล และ State

## ภาพรวม

แอป Flutter ชื่อ `cpe_air_remote` (ชื่อที่ผู้ใช้เห็นคือ **RMUTT Save Energy**) เป็นหน้าตาที่เจ้าหน้าที่ใช้สั่งแอร์และดูค่าไฟของอาคาร 16 จากมือถือ Android หรือคอมพิวเตอร์ Windows เวอร์ชันในโค้ดตอนนี้คือ `3.16.0+32` (ชื่อเวอร์ชัน `3.16.0` และหมายเลข build `32` ซึ่ง Android เรียกว่า versionCode) ถ้าเอกสารใดเขียนเลขไม่ตรงกัน ให้เชื่อ `pubspec.yaml`

แอป **ไม่ต่อฐานข้อมูลและไม่ต่อ MQTT ตรง** ทุกอย่างผ่าน REST API ของ Backend (Node.js) ผ่าน HTTPS ยกเว้นงานเดียวที่ไม่ผ่านเน็ตคือการตั้งค่า ESP32 ครั้งแรกผ่าน **Bluetooth Low Energy (BLE)** ตรงจากมือถือไปยังบอร์ด

```text
 ESP32 (แอร์/เซนเซอร์)  <--MQTT-->  Mosquitto  <-->  Backend (Node.js) <--> MariaDB
        ^                                                ^
        | BLE (ตั้งค่าครั้งแรกเท่านั้น)                    | HTTPS + JSON + Bearer token
        +----------------------  แอป Flutter  -----------+
```

บทนี้เป็น "รากฐาน" ของแอป ครอบคลุมสิ่งที่ไม่ใช่หน้าจอ ได้แก่ จุดเริ่มต้น `main.dart`, การตั้งค่า URL, **โมเดลข้อมูล**, **Service** (ชั้นที่ยิง HTTP), **Controller** (ชั้นที่เก็บ state), ฟังก์ชันช่วย (utils), ระบบแปลภาษา, ธีมสี, การตั้งค่า Android และชุดทดสอบ ส่วนหน้าจอและวิดเจ็ตอยู่ในบทถัดไป (`11a-flutter-screens.md` และ `11b-flutter-admin-screens.md`) บทนั้นจะอ้างถึง Controller และโมเดลที่อธิบายในบทนี้

## ความรู้ที่ต้องมีก่อนอ่านบทนี้

### Dart: ภาษาที่ใช้เขียน Flutter

- **ชนิดข้อมูลพื้นฐาน** `int` จำนวนเต็ม, `double` ทศนิยม, `bool` จริง/เท็จ, `String` ข้อความ, `List<T>` รายการ, `Map<K,V>` คู่ key-value, `Set<T>` ชุดที่ไม่ซ้ำ `dynamic` คือ "ชนิดอะไรก็ได้" (เลี่ยงให้มากที่สุด) `Object?` คือ "อะไรก็ได้ รวมถึง null" แต่ต้องตรวจชนิดก่อนใช้
- **Null safety** ตัวแปรปกติห้ามเป็น `null` ถ้าอยากให้เป็นได้ต้องเติม `?` เช่น `String? deviceId` ตัวดำเนินการที่ใช้บ่อยในโค้ดนี้
  - `a ?? b` ถ้า `a` เป็น null ให้ใช้ `b` เช่น `json['name'] as String? ?? ''`
  - `a?.foo()` เรียกเฉพาะเมื่อ `a` ไม่ null ไม่งั้นได้ null ทั้งนิพจน์
  - `a!` "ฉันรับรองว่า `a` ไม่ null" ถ้าผิดแอปจะ crash (ในโค้ดนี้ใช้เช่น `_authController.user!` เพราะรู้ว่าสถานะ signedIn แล้วต้องมี user)
  - `a ??= b` กำหนดค่าให้ `a` เฉพาะตอนที่ยัง null (ใช้กับ `_refreshTimer ??= Timer.periodic(...)` เพื่อไม่สร้างตัวจับเวลาซ้ำ)
- **`final` กับ `const`** `final` กำหนดค่าได้ครั้งเดียว (ตอนรันโปรแกรม) `const` คือค่าคงที่ที่รู้ตั้งแต่ตอนคอมไพล์ และ Flutter ใช้ object `const` ซ้ำได้ ทำให้ประหยัดการวาดใหม่ กฎ lint `prefer_const_constructors` ในโปรเจกต์นี้บังคับให้ใส่ `const` ทุกที่ที่ทำได้
- **คลาสและ constructor แบบ named parameter** `Room({required this.number, this.isOccupied = false})` พารามิเตอร์ในปีกกาเรียกด้วยชื่อ `Room(number: '16101', floor: 1, ...)` `required` คือห้ามลืม ส่วนที่มีค่าเริ่มต้น (`= false`) จะละได้ `this.number` คือทางลัดที่เอาค่ามาใส่ field ชื่อเดียวกันให้เลย
- **`factory` constructor และ `fromJson`/`toJson`** `factory` คือ constructor ที่ไม่จำเป็นต้องสร้าง object ใหม่ทันที เราใช้มันเป็น "โรงงานแปลง JSON เป็น object" ตามธรรมเนียม `Room.fromJson(Map<String,dynamic> json)` และมี method กลับทางคือ `toRequestJson()` / `toJson()` (ในโปรเจกต์นี้ไม่ใช้ตัวสร้างโค้ดอัตโนมัติอย่าง `json_serializable` เขียนมือทั้งหมด)
- **`async` / `await` / `Future`** `Future<T>` คือ "ค่าชนิด T ที่จะมาทีหลัง" (เช่นผลจากการยิงเน็ต) ฟังก์ชันที่ประกาศ `async` ใช้ `await` รอผลได้โดยไม่ค้างหน้าจอ `Future<void>` คือไม่มีค่าที่คืน `Future.wait([a, b])` รอหลายงานพร้อมกัน
- **`Stream`** คือ "Future ที่ส่งค่ามาได้หลายครั้ง" ในบทนี้พบใน BLE (`FlutterBluePlus.onScanResults`, `adapterState`) ใช้ `.listen(...)` รับค่า หรือ `.where(...).first` รอค่าแรกที่ตรงเงื่อนไข
- **`enum`** ชุดค่าคงที่ เช่น `enum AuthStatus { loading, signedOut, signedIn }` Dart 3 เพิ่มความสามารถให้ enum มี field และ constructor (เช่น `AppLanguage.thai('th')`) และ `.name` คืนชื่อเป็นข้อความ (`AirMode.cool.name == 'cool'`)
- **`extension`** เพิ่ม method ให้ชนิดที่มีอยู่แล้วโดยไม่ต้องแก้ชนิดนั้น เช่น `extension AirModeLabel on AirMode { String get label => ... }` ทำให้เขียน `AirMode.cool.label` ได้ และ `context.tr('Sign In')` ก็เป็น extension บน `BuildContext`
- **`switch` expression และ pattern** Dart 3 เขียน `switch (x) { A => 1, B => 2, _ => 0 }` เป็นนิพจน์ที่คืนค่าได้ `_` คือ "กรณีอื่นทั้งหมด" และใน `main.dart` ใช้ `switch` กับ enum โดยคอมไพเลอร์บังคับให้ครบทุกค่า
- **`abstract interface class`** คลาสที่เป็น "สัญญา" มีแต่หัวฟังก์ชัน สร้าง object ตรง ๆ ไม่ได้ คลาสอื่นต้อง `implements` และเขียนทุกฟังก์ชันเอง เป็นหัวใจของชั้น Repository (อธิบายละเอียดในหัวข้อสถาปัตยกรรม)
- **Generics** `List<Room>`, `Future<List<Room>>`, `Map<String, dynamic>` คือการระบุชนิดของสิ่งที่อยู่ข้างใน ฟังก์ชันเขียนครั้งเดียวใช้ได้หลายชนิด เช่น `T _enumByName<T extends Enum>(List<T> values, ...)` ใน `air_conditioner.dart` ใช้ได้กับ enum ทุกตัว
- **Cascade `..`** `list..clear()..addAll(x)` คือเรียกหลาย method บน object เดียวกันต่อเนื่อง ผลลัพธ์ของทั้งนิพจน์คือ object นั้น
- **Collection `if` / `for` ในลิสต์และแมป** `{ 'a': 1, if (x != null) 'b': x }` ใส่คีย์เฉพาะเมื่อเงื่อนไขจริง ใช้มากในตัวสร้าง JSON และ query string

### Flutter พื้นฐานที่บทนี้ต้องใช้

- **Widget** ทุกอย่างบนจอคือ widget (ปุ่ม ข้อความ แถว คอลัมน์) ประกอบเป็นต้นไม้ `StatelessWidget` ไม่มี state ภายใน `StatefulWidget` มี `State` ที่ `setState()` แล้ววาดใหม่ได้ `build()` คือฟังก์ชันที่บอกว่าหน้าตาตอนนี้เป็นอย่างไร
- **`ChangeNotifier` และ `notifyListeners()`** คลาสจาก Flutter ที่เก็บ state ได้ ใครสนใจก็ "ฟัง" (listen) เมื่อค่าเปลี่ยน เรียก `notifyListeners()` ทุกคนที่ฟังอยู่จะถูกเรียกให้วาดใหม่ นี่คือวิธีจัดการ state ของโปรเจกต์นี้ทั้งหมด
- **`AnimatedBuilder`** widget ที่รับ `animation:` (ซึ่ง `ChangeNotifier` ก็เป็นชนิดนั้น) แล้วเรียก `builder` ใหม่ทุกครั้งที่ตัวนั้น notify
- **`BuildContext`** ตัวบอกว่า widget อยู่ตรงไหนของต้นไม้ ใช้ถามหาธีม ภาษา ขนาดจอ ฯลฯ
- **Timer** `Timer.periodic(Duration(seconds: 10), callback)` เรียก callback ซ้ำทุก 10 วินาที ต้อง `.cancel()` ตอน `dispose()` ไม่งั้นรั่ว
- **`flutter run` / `flutter test` / `flutter build apk`** รันแอป รันเทสต์ และสร้างไฟล์ติดตั้ง Android

### ไลบรารีและแนวคิดอื่นที่เกี่ยวข้อง

- **`http` package** ยิง HTTP: `http.Client().send(request)` แล้วอ่านผล `http.Response` มี `statusCode` (200–299 = สำเร็จ) และ `body` (ข้อความ)
- **JSON** รูปแบบข้อความของข้อมูล `jsonDecode(text)` แปลงเป็น `Map`/`List` ของ Dart และ `jsonEncode(map)` แปลงกลับ ข้อมูลจากเซิร์ฟเวอร์ไม่น่าเชื่อถือเต็มที่ จึงต้อง "ตรวจชนิด" ก่อนใช้ (เช่น `value is Map<String, dynamic>`)
- **`flutter_secure_storage`** ที่เก็บแบบ key-value ที่เข้ารหัสในเครื่อง (บน Android ใช้ Keystore ของระบบ) **นี่คือที่เก็บเพียงอย่างเดียวของแอปนี้** ไม่มี `shared_preferences` ไม่มี SQLite
- **`flutter_blue_plus`** ไลบรารี BLE: สแกนอุปกรณ์ เชื่อมต่อ อ่าน/เขียน characteristic (ช่องข้อมูลของ BLE)
- **`--dart-define`** ธงตอน `flutter run`/`flutter build` ที่ฝังค่าลงแอปตอนคอมไพล์ อ่านในโค้ดด้วย `String.fromEnvironment('ชื่อ', defaultValue: ...)` เป็นวิธีเปลี่ยน URL Backend โดยไม่แก้โค้ด
- **Bearer token** วิธียืนยันตัวตนต่อ API: ล็อกอินแล้วได้ข้อความยาว ๆ (token) ส่งกลับทุกคำขอในหัว `Authorization: Bearer <token>`

## โครงสร้างโฟลเดอร์

```text
cpe_air_remote/
├── pubspec.yaml              รายการแพ็กเกจ เวอร์ชัน ฟอนต์
├── analysis_options.yaml     กฎ lint
├── lib/
│   ├── main.dart             จุดเริ่ม: ประกอบ Service/Controller แล้วสลับ loading → login → AppShell
│   ├── config/api_config.dart        URL ของ Backend
│   ├── data/mock_data.dart           โครงห้อง 21 ห้องตั้งต้น
│   ├── models/               ข้อมูล (12 ไฟล์) แปลง JSON ไป-กลับ
│   ├── services/             Repository (สัญญา) + Service (ยิง HTTP/BLE) รวม 20 ไฟล์
│   ├── controllers/          state ของแต่ละเรื่อง (9 ไฟล์) ใช้ ChangeNotifier
│   ├── utils/                ฟังก์ชันช่วย: วันที่ พ.ศ., ตัวเลข, ไฟล์, ค่าตั้งแจ้งเตือน
│   ├── localization/         ตัวแปลไทย/อังกฤษ
│   ├── theme/app_theme.dart  สีและธีม
│   ├── screens/              หน้าจอ (บทถัดไป)
│   └── widgets/              วิดเจ็ตที่ใช้ซ้ำ (บทถัดไป)
├── test/                     22 ไฟล์ทดสอบ (122 เคส)
├── android/                  ตั้งค่า Android (Gradle, Manifest)
├── web/                      ไฟล์ของ Flutter Web (ไม่ใช่เว็บแอปจริง ของจริงอยู่ที่ webapp/)
└── windows/                  ตัวห่อสำหรับ Windows (ไม่ได้อธิบายในบทนี้)
```

> [!NOTE]
> โฟลเดอร์ `assets/` (ฟอนต์ ChakraPetch และ `assets/brand/`) ที่ประกาศใน `pubspec.yaml` ไม่อยู่ในสำเนาโค้ดที่ใช้เขียนบทนี้ ส่วนไฟล์ `MainActivity.kt` ของ Android ก็ไม่อยู่ในสำเนาเช่นกัน (ปกติ `flutter create` สร้างให้เป็นคลาสว่างที่สืบทอด `FlutterActivity` ไม่มีโค้ดของโปรเจกต์) บทนี้จึงไม่ยืนยันเนื้อหาของสองส่วนนั้น

## pubspec.yaml และแพ็กเกจที่ใช้

**ไฟล์ `pubspec.yaml`**

| ส่วน | ค่า | ความหมาย |
|---|---|---|
| `name` | `cpe_air_remote` | ชื่อแพ็กเกจ Dart (ใช้ใน `import 'package:cpe_air_remote/...'` ของเทสต์) |
| `publish_to` | `"none"` | กันเผลอเอาไป publish ขึ้น pub.dev |
| `version` | `3.16.0+32` | `ชื่อเวอร์ชัน+หมายเลข build` ถูกส่งต่อไปเป็น `versionName`/`versionCode` ใน Gradle |
| `environment.sdk` | `>=3.8.0 <4.0.0` | ต้องใช้ Dart 3.8 ขึ้นไป (ภาษา Dart 3 ที่มี `switch` expression และ `abstract interface class`) |
| `uses-material-design` | `true` | รวมไอคอน Material ไปกับแอป |
| `assets` | `assets/brand/` | โฟลเดอร์รูปแบรนด์ |
| `fonts` | `ChakraPetch` น้ำหนัก 600/700 | ฟอนต์หัวข้อและตัวเลขใหญ่ ตัวเดียวกับโลโก้ รองรับอักษรไทย ใช้ผ่านค่าคงที่ `kDisplayFont` |

**แพ็กเกจใน `dependencies` ทุกตัว: ทำอะไร ใช้ที่ไหน**

| แพ็กเกจ | เวอร์ชัน | ทำอะไร | ใช้ที่ไหนในโค้ด |
|---|---|---|---|
| `flutter` (sdk) | ตาม SDK | ตัว Flutter เอง | ทุกไฟล์ UI |
| `flutter_localizations` (sdk) | ตาม SDK | ชุดคำแปล/ปฏิทินมาตรฐานของ Material, Widgets, Cupertino | `main.dart` ใส่ใน `localizationsDelegates` |
| `cupertino_icons` | `^1.0.8` | ไอคอนสไตล์ iOS (มากับแม่แบบ `flutter create`) | ไม่พบการใช้ใน `lib/` เป็นของที่ติดมากับแม่แบบ |
| `flutter_secure_storage` | `^9.2.4` | เก็บ key-value แบบเข้ารหัส | ทุก `*_service.dart` (อ่าน token) และ `auth_service.dart`, `app_settings_controller.dart` (เขียน) |
| `flutter_blue_plus` | `2.3.11` (ตรึงเวอร์ชัน) | BLE | `ble_provisioning_service.dart`, `models/provisioning.dart` |
| `flutter_blue_plus_winrt` | `0.0.20` (ตรึงเวอร์ชัน) | ตัวเชื่อม BLE สำหรับ Windows (WinRT) ที่ `flutter_blue_plus` ใช้เบื้องหลังบน Windows | ไม่ถูก import ตรงใน `lib/` ปลั๊กอินเลือกใช้เองตามแพลตฟอร์ม (README_BLE_WINDOWS_GATT_FIX_TH.txt อธิบายว่าตรึงเวอร์ชันนี้เพื่อความเสถียรของการเชื่อมต่อ) |
| `file_selector` | `^1.1.0` | กล่องเลือกไฟล์/บันทึกไฟล์ของเดสก์ท็อป | `utils/file_saver.dart` (`getSaveLocation`) และหน้านำเข้าตารางเรียน |
| `http` | `^1.2.2` | ยิง HTTP | ทุก `*_service.dart` |
| `path_provider` | `^2.1.4` | หาโฟลเดอร์ชั่วคราวของแอป | `utils/file_saver.dart` (`getTemporaryDirectory`) |
| `share_plus` | `>=11.0.0 <14.0.0` | เปิดเมนูแชร์ของเครื่อง | `utils/file_saver.dart` (`SharePlus.instance.share`) |

`dev_dependencies`: `flutter_test` (กรอบทดสอบของ Flutter) และ `flutter_lints ^5.0.0` (ชุดกฎ lint มาตรฐาน)

> [!WHY]
> **ทำไมตรึง `flutter_blue_plus` เป็น `2.3.11` เป๊ะ ๆ ไม่ใช้ `^`** BLE บน Windows มีปัญหาเรื่องการเชื่อมต่อที่ไวต่อเวอร์ชัน ถ้าปล่อยให้ `flutter pub get` ขยับเวอร์ชันเองอาจกลับไปมีบั๊กเดิม การตรึงเวอร์ชันทำให้ทุกเครื่องที่ build ได้พฤติกรรมเดียวกัน (ข้อเสียคือต้องอัปเดตเองเมื่อต้องการ)

**สิ่งที่ "ไม่มี" ใน pubspec ก็สำคัญ** ไม่มี `provider`, `riverpod`, `bloc`, `get_it` และไม่มี `shared_preferences`, `dio`, `flutter_local_notifications` (ผลคือการแจ้งเตือนบนเครื่องยังไม่มีตัวจริง ดูหัวข้อ `alert_notifier.dart`)

**ไฟล์ `analysis_options.yaml`**

```yaml:1
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    avoid_print: true
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
```

- บรรทัด 1: ดึงกฎมาตรฐานของ Flutter มาก่อน
- `avoid_print`: ห้ามใช้ `print()` ในโค้ดจริง (ให้ log อย่างอื่น ไม่ให้ข้อความหลุดในรุ่นที่ปล่อย)
- `prefer_const_constructors` และ `prefer_const_literals_to_create_immutables`: ใส่ `const` เมื่อทำได้ เพื่อให้ Flutter ใช้ widget ซ้ำและไม่วาดใหม่โดยไม่จำเป็น

## สถาปัตยกรรมของแอป: 5 ชั้น

แอปแยกโค้ดเป็นชั้น ทุกชั้นรู้จักแค่ชั้นที่อยู่ถัดลงไป

```text
 ┌───────────────────────────────────────────────────────────────┐
 │ Screen / Widget  (lib/screens, lib/widgets)                   │  วาดหน้าจอ รับการกดปุ่ม
 │   อ่านค่าจาก controller, ฟังด้วย AnimatedBuilder              │  ไม่มีโค้ด HTTP เลย
 └──────────────▲────────────────────────────────────────────────┘
                │ notifyListeners() เมื่อ state เปลี่ยน
 ┌──────────────┴────────────────────────────────────────────────┐
 │ Controller  (lib/controllers)  extends ChangeNotifier         │  เก็บ state: กำลังโหลด? error? รายการ?
 │   เรียก repository เท่านั้น ไม่รู้จัก http                    │  ตั้ง Timer ดึงซ้ำ
 └──────────────┬────────────────────────────────────────────────┘
                │ เรียกผ่านชนิด "Repository" (abstract interface class)
 ┌──────────────▼────────────────────────────────────────────────┐
 │ Repository  (lib/services/*_repository.dart)  = สัญญา         │  บอกว่า "ทำอะไรได้" ไม่บอกว่า "ทำอย่างไร"
 └──────────────▲────────────────────────────────────────────────┘
                │ implements
 ┌──────────────┴────────────────────────────────────────────────┐
 │ Service  (lib/services/*_service.dart)                        │  ยิง HTTP, อ่าน token, ตรวจ JSON,
 │   ใช้ http.Client + FlutterSecureStorage                      │  แปลง error เป็น ApiException
 └──────────────┬────────────────────────────────────────────────┘
                │ JSON ↔ Model
 ┌──────────────▼────────────────────────────────────────────────┐
 │ Model  (lib/models)  fromJson / toRequestJson                 │  รูปร่างของข้อมูล + กฎเล็ก ๆ ของข้อมูล
 └───────────────────────────────────────────────────────────────┘
```

**บทบาทของแต่ละชั้น**

- **Model** บอกว่าข้อมูลหนึ่งชิ้นมีฟิลด์อะไร และแปลง JSON ไป-กลับ ไม่รู้จักเน็ตหรือหน้าจอ
- **Repository** เป็น `abstract interface class` ที่ประกาศฟังก์ชันที่ชั้นบนต้องการ เช่น `fetchRooms()` ไม่มีโค้ดข้างใน
- **Service** คือ "ตัวจริง" ของ Repository ที่ยิง HTTP ไปยัง Backend
- **Controller** เก็บ state ที่หน้าจอต้องใช้ (`isLoading`, `errorMessage`, รายการข้อมูล) และสั่ง Service เมื่อผู้ใช้ทำอะไร จากนั้น `notifyListeners()`
- **Screen** แสดงผลตาม state และส่งเหตุการณ์ให้ Controller

> [!WHY]
> **ทำไมต้องมี Repository (abstract) คั่นระหว่าง Controller กับ Service**
> 1. **ทดสอบได้โดยไม่ต้องมีเซิร์ฟเวอร์** ในเทสต์ใส่คลาสปลอมที่ `implements RoomRepository` และคืนข้อมูลตายตัวแทน (เช่น `_MemoryRoomRepository` ใน `test/widget_test.dart`) เทสต์ทั้งแอปจึงรันออฟไลน์ได้
> 2. **เปลี่ยนแหล่งข้อมูลได้โดยไม่แตะ Controller/หน้าจอ** ถ้าวันหนึ่งเพิ่ม cache หรือเปลี่ยนวิธีดึง ก็เขียนคลาสใหม่ที่ `implements` สัญญาเดิม
> 3. **ชั้นบนไม่รู้จัก HTTP** ไม่มีบรรทัด `http.get` ในไฟล์ Controller หรือ Screen ถ้าไม่แยก โค้ดหน้าจอจะปนทั้ง UI, URL, JSON และ error ทำให้แก้ยากและเทสต์ไม่ได้
>
> ทางเลือกอื่นคือใช้ `mockito` สร้างของปลอมอัตโนมัติ แต่โปรเจกต์นี้เลือกเขียนคลาสปลอมมือ เพราะอ่านง่ายกว่าและไม่ต้องพึ่งแพ็กเกจเพิ่ม

> [!WHY]
> **ทำไมใช้ `ChangeNotifier` ไม่ใช้ Provider/Riverpod/BLoC** เพราะมากับ Flutter อยู่แล้ว ไม่ต้องเพิ่ม dependency และ state ของระบบนี้เรียบง่าย ("ดึงข้อมูลมา เก็บไว้ บอกให้วาดใหม่") ข้อเสียคือต้องส่ง Controller ลงไปทาง constructor เองทีละชั้น (ไม่มีตัวฉีดอัตโนมัติ) และต้อง `dispose()` ให้ครบเอง

### สิ่งที่ทุก Service ทำเหมือนกัน

ทุกไฟล์ `*_service.dart` มีรูปแบบเดียวกัน ซึ่งอธิบายครั้งเดียวที่นี่:

1. constructor รับของ 3 อย่างแบบ **optional** `http.Client? client`, `FlutterSecureStorage? storage`, `String baseUrl = ApiConfig.baseUrl` ถ้าไม่ส่งมาก็สร้างของจริง (`client ?? http.Client()`) เหตุผลคือให้เทสต์ใส่ของปลอมได้ (Dependency Injection แบบมือ)
2. `_baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '')` ตัด `/` ท้ายสุดออก กัน URL เป็น `.../api//rooms`
3. `_request(method, path, {body})` เป็นฟังก์ชันกลางของไฟล์: อ่าน token จาก secure storage (key `rmutt_access_token`) ถ้าไม่มีให้โยน `ApiException('Please sign in again.', statusCode: 401)` ทันที แล้วสร้าง `http.Request` ใส่หัว `Accept`, `Content-Type: application/json`, `Authorization: Bearer <token>` ใส่ body เป็น `jsonEncode(body)` และส่งด้วย `.timeout(...)` (15 วินาทีเป็นค่าทั่วไป)
4. `_decode(response)` แปลงเนื้อตอบเป็น `Map` ถ้ารหัสสถานะไม่ใช่ 2xx ให้โยน `ApiException(data['message'] ?? 'The server returned an error.', statusCode: ...)` (Backend ส่งข้อความผิดพลาดเป็นภาษาไทยใน `message` และตัวแปลภาษาจะแปลกลับเป็นอังกฤษให้ถ้าผู้ใช้เลือก English)
5. ดักข้อผิดพลาด 3 แบบ แล้วแปลงเป็น `ApiException` ข้อความอ่านรู้เรื่องเสมอ: `TimeoutException` → "The server took too long to respond." ; `ApiException` → โยนต่อ (`rethrow`) ; อย่างอื่น (เน็ตหลุด DNS ผิด) → "Could not connect to the server. Check API_BASE_URL."

> [!WHY]
> **ทำไมโค้ดนี้ซ้ำกันเกือบทุกไฟล์ (ไม่ดึงไปไว้คลาสแม่)** ผู้เขียนเลือกให้แต่ละ Service เป็นไฟล์เดี่ยวที่อ่านจบในตัวเอง แลกกับโค้ดซ้ำ ข้อเสียที่ต้องรู้ คือถ้าจะแก้พฤติกรรมกลาง (เช่นเพิ่มการออกจากระบบอัตโนมัติเมื่อได้ 401) ต้องแก้หลายไฟล์ ทางที่ดีกว่าคือทำคลาส `ApiClient` กลางตัวเดียวแล้วให้ทุก Service รับไปใช้ ซึ่งเป็นสิ่งที่ปรับปรุงได้ภายหลัง ใช้ตอบอาจารย์ได้ถ้าถามเรื่อง "ข้อจำกัดของการออกแบบ"

### ตัวอย่างเต็มหนึ่งแนวตั้ง: "ห้อง" (rooms)

ดูว่าข้อมูลห้องเดินทางผ่านทั้ง 5 ชั้นอย่างไร (ไฟล์จริงทั้งหมดอยู่ในโค้ด)

```text
 Backend GET /api/rooms  →  { "rooms": [ {roomNumber, floorNumber, roomIndex, roomType, ...}, ... ] }
        │
        ▼  room_service.dart  RoomService.fetchRooms()
        │    - _request('GET','/rooms') ใส่ Bearer token, timeout 15 วินาที
        │    - ตรวจว่า data['rooms'] เป็น List ไม่ใช่ก็โยน ApiException
        │    - .whereType<Map<String,dynamic>>().map(Room.fromJson).toList()
        ▼  room.dart  Room.fromJson  →  object Room (ค่าที่หายไปได้ค่าเริ่มต้น)
        ▼  room_repository.dart  RoomRepository.fetchRooms()  ← ชนิดที่ Controller รู้จัก
        ▼  room_controller.dart  RoomController.reload()
        │    - isLoading = true → notifyListeners()
        │    - ผสานข้อมูลใหม่เข้ากับห้องเดิม (คงรายการแอร์ที่โหลดไว้)
        │    - rooms.clear()..addAll(loaded)..sort(_compare)
        │    - notifyListeners() → หน้าจอวาดใหม่
        ▼  app_shell.dart  AnimatedBuilder(animation: Listenable.merge([_airController, _roomController]))
        ▼  rooms_screen.dart  RoomsScreen(rooms: _rooms, controller: _roomController) → แสดงการ์ดห้องตามชั้น
```

ขากลับ (แอดมินเพิ่มห้อง): `room_management_screen.dart` เรียก `controller.createRoom(room)` → `repository.createRoom` → `RoomService.createRoom` ส่ง `POST /rooms` ด้วย body จาก `room.toRequestJson()` → ได้ห้องที่เซิร์ฟเวอร์สร้างกลับมา → Controller `add` เข้ารายการ `sort` แล้ว `notifyListeners()`

**ไฟล์ที่เกี่ยวข้องโดยตรงเรียงตามชั้น:** `models/room.dart` → `services/room_repository.dart` → `services/room_service.dart` → `controllers/room_controller.dart` → `screens/rooms_screen.dart` (ในบทถัดไป)

## จุดเริ่มต้นและค่าตั้ง URL

(รายละเอียดทีละบรรทัดของ `main.dart` และ `api_config.dart` อยู่ในหัวข้อ "เจาะโค้ดทีละบรรทัด" ท้ายบท ที่นี่สรุปแนวคิด)

**ลำดับเมื่อเปิดแอป**

1. `main()` เรียก `runApp(const CpeAirRemoteApp())`
2. `_CpeAirRemoteAppState.initState()` สร้าง `AuthController` และ `AppSettingsController` พร้อม Service ทุกตัว (ใช้ตัวที่ส่งเข้ามาก่อน ถ้าไม่มีสร้างของจริง) แล้วเรียก `initialize()` ของสองตัวแรก
3. `build()` ห่อ `MaterialApp` ด้วย `AnimatedBuilder` ที่ฟัง `AppSettingsController` ดังนั้นเปลี่ยนภาษา/ธีม/ขนาดตัวอักษรแล้วทั้งแอปวาดใหม่ทันที
4. `home` ฟัง `AuthController.status` แล้ว `switch`: `loading` → `AuthLoadingScreen`, `signedOut` → `LoginScreen`, `signedIn` → `AppShell`

**`ApiConfig.baseUrl` ค่าเริ่มต้นคือ `https://rmutt-energy.tailb292b4.ts.net/api`**

- `ts.net` คือโดเมนของ **Tailscale** (VPN แบบ mesh) และ **Tailscale Funnel** คือฟีเจอร์ที่เปิดเซิร์ฟเวอร์ในเครือข่ายส่วนตัวให้เข้าได้จากอินเทอร์เน็ตสาธารณะผ่าน HTTPS โดยไม่ต้องเปิดพอร์ตเราเตอร์ มือถือของเจ้าหน้าที่จึงใช้แอปได้จากทุกที่ที่มีเน็ต แถมได้ใบรับรอง HTTPS จริงฟรี
- ส่วน `rmutt-energy.duckdns.org` (DuckDNS = บริการชื่อโดเมนฟรี) ชี้ไป IP ภายในมหาวิทยาลัย ใช้ได้เฉพาะตอนอยู่ในเครือข่ายตึก ไม่เหมาะเป็นค่าเริ่มต้นของแอปที่แจกให้พกออกนอกตึก (ตามคอมเมนต์ในไฟล์ และ `run_all.ps1` ยังใช้ DuckDNS เป็นค่าเริ่มต้นของสคริปต์ฝั่งเดสก์ท็อป)
- **override ตอน build:** `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api` (Windows ชี้ Backend ในเครื่อง) หรือ `http://10.0.2.2:3000/api` (Android Emulator: `10.0.2.2` คือชื่อพิเศษที่แทน `localhost` ของเครื่องคอมพิวเตอร์โฮสต์) สคริปต์ `build-apk.ps1` ส่ง `--dart-define=API_BASE_URL=$ApiBaseUrl` ให้ตอน `flutter build apk` และ `BUILD-ANDROID.bat` ส่ง URL ts.net เข้าไป
- `isProduction` คือ getter ที่เป็นจริงเมื่อ URL ขึ้นต้น `https://`

> [!WARN]
> `String.fromEnvironment` ต้องเป็น `const` และถูกแทนค่า **ตอนคอมไพล์** เปลี่ยน URL แล้วต้อง build ใหม่ (hot reload ไม่พอ) และในสำเนาโค้ดนี้ไม่พบ `usesCleartextTraffic` หรือ network security config ใน `AndroidManifest.xml` โดยปกติ Android 9 ขึ้นไปบล็อก `http://` ที่ไม่ใช่ HTTPS ดังนั้นการชี้ไป Backend แบบ `http://` บนมือถือจริงอาจถูกบล็อก (ตรวจเองก่อนบอกว่าใช้ได้) ค่าเริ่มต้นเป็น HTTPS จึงไม่มีปัญหา

## ระบบยืนยันตัวตน (Auth flow)

ชิ้นส่วน: `AuthRepository` (สัญญา) → `AuthService` (ตัวจริง) → `AuthController` (state) → `LoginScreen` / `ForgotPasswordScreen` (หน้าจอ) ที่เก็บถาวรคือ `FlutterSecureStorage` เท่านั้น

**คีย์ที่ `AuthService` ใช้ใน secure storage**

| คีย์ | ค่าที่เก็บ | หมายเหตุ |
|---|---|---|
| `rmutt_access_token` | token จาก Backend | ทุก Service อ่านคีย์เดียวกันนี้ในทุกคำขอ |
| `rmutt_remembered_username` | ชื่อผู้ใช้ที่จำไว้ | |
| `rmutt_remembered_password` | (รุ่นเก่าเคยเก็บรหัสผ่าน) | ปัจจุบัน **ลบทิ้งทุกครั้ง** ไม่เขียนอีกแล้ว |

**ลำดับ: เปิดแอป (remembered login / restore session)**

1. `AuthController.initialize()` เรียก `repository.restoreSession()`
2. `AuthService.restoreSession()` อ่าน token ถ้าไม่มี → คืน `null` (ไปหน้า login)
3. ถ้ามี token → ยิง `GET /auth/me` พร้อม Bearer ได้ผู้ใช้กลับมา → `AuthStatus.signedIn` เข้า AppShell ได้เลยโดยไม่ต้องพิมพ์รหัส
4. ถ้าเกิด `ApiException` ใด ๆ (token หมดอายุ/ถูกเพิกถอน และ **รวมถึงเน็ตหลุด** เพราะ `_get` แปลงทุกความล้มเหลวเป็น `ApiException`) → ลบ token แล้วคืน `null`

> [!WARN]
> ข้อ 4 มีผลข้างเคียงที่ควรรู้: ถ้าเปิดแอปตอนไม่มีอินเทอร์เน็ต token จะถูกลบและผู้ใช้ต้องล็อกอินใหม่ (ไม่ใช่แค่ "ต่อไม่ได้ชั่วคราว") เป็นข้อแลกเปลี่ยนที่ผู้เขียนเลือกเพื่อให้โค้ดง่าย

**ล็อกอิน**

`AuthController.login(username, password, rememberPassword)` → `repository.login` ส่ง `POST /auth/login` body `{username, password}` (ตัดช่องว่างของ username) ได้ `{token, user}` → เก็บ token ใน secure storage → คืน `AuthUser` จากนั้น Controller ตัดสินใจเรื่อง "จดจำชื่อผู้ใช้": ถ้าติ๊ก เรียก `saveRememberedLogin` (เก็บ **เฉพาะ username** ข้อความในโค้ดอธิบายว่ารุ่นเก่าเก็บรหัสผ่านจริง ถ้ามือถือหายรหัสจะหลุด จึงเลิกเก็บ) ถ้าไม่ติ๊กเรียก `clearRememberedLogin` แล้วตั้ง `status = signedIn` และ `notifyListeners()` ทำให้ `main.dart` สลับไป `AppShell`

ค่า `RememberedLogin.password` ยังคงอยู่ในโมเดลแต่ **ว่างเสมอ** เพื่อไม่ต้องแก้โค้ดและเทสต์เก่า (comment ในไฟล์บอกไว้)

**ออกจากระบบ**: `AuthController.logout()` → `repository.logout()` (ลบ token) → `user = null`, `status = signedOut` → หน้า login

**ลืมรหัสผ่าน** (3 ขั้น ทุกขั้นไม่ต้องมี token) `ForgotPasswordScreen` เรียก Repository ตรง ๆ:

1. `requestPasswordReset(identifier)` → `POST /auth/forgot-password` ได้ `requestId`
2. `verifyPasswordResetOtp(requestId, otp)` → `POST /auth/verify-otp` ได้ `resetToken` (ใช้ได้เฉพาะขั้นถัดไป)
3. `resetPassword(resetToken, newPassword)` → `POST /auth/reset-password` เสร็จแล้วหน้าจอเรียก `clearRememberedLogin()`

**แก้โปรไฟล์/เปลี่ยนรหัสผ่าน (ต้องล็อกอินอยู่)**: `updateProfile` ส่ง `PATCH /auth/me` ถ้าเปลี่ยนอีเมลต้องแนบ `currentPassword` (Backend บังคับ) `changePassword` ส่ง `POST /auth/me/password` แล้วลบ token ในเครื่องและล้าง remembered login เพราะ Backend ยกเลิก token เดิม Controller จึงตั้ง `signedOut` ให้เลย

**ติดต่อแอดมิน**: `getAdminContact()` ยิง `GET /public/admin-contact` (ไม่ต้องมี token เพราะใช้ในหน้า login) ได้ชื่อ/เบอร์ ไปแสดงใน `_AdminContactSheet`

**เมื่อได้ 401**: Service โยน `ApiException(statusCode: 401)` และหน้าจอที่เรียกแสดงข้อความ **ไม่มีตัวดักกลางที่ออกจากระบบให้อัตโนมัติ** (ค้นแล้วไม่พบโค้ดนอกชั้น Service ที่อ่าน `statusCode`) ผู้ใช้ที่ token หมดอายุระหว่างใช้งานจะเห็น error ในการดึงข้อมูลจนกว่าจะออกจากระบบเอง หรือปิดแล้วเปิดแอปใหม่ (ซึ่ง `restoreSession` จะลบ token ที่เสียและส่งไปหน้า login)

> [!WHY]
> **ทำไมเก็บ token ใน `flutter_secure_storage` ไม่ใช่ที่เก็บธรรมดา** token คือกุญแจเข้าระบบ ถ้าเก็บเป็นข้อความธรรมดา (เช่น shared preferences) แอปอื่นหรือผู้ที่เข้าถึงไฟล์เครื่องอ่านได้ ที่เก็บแบบ secure เข้ารหัสด้วยกุญแจในฮาร์ดแวร์/Keystore ของระบบ ส่วนการอ่าน token **ทุกคำขอ** (ไม่แคชไว้ในตัวแปร) ทำให้เมื่อ logout ลบคีย์แล้ว ทุก Service เลิกใช้ token เก่าทันทีโดยไม่ต้องบอกกัน

## อธิบายทีละไฟล์

### Models (`lib/models/`)

โมเดลทุกตัวมีรูปแบบร่วมกัน: ฟิลด์ `final` เป็นหลัก, `factory X.fromJson(Map<String,dynamic>)` ที่ **ไม่เชื่อ JSON** (ทุกฟิลด์มีค่าสำรอง เช่น `json['name'] as String? ?? ''`) เพื่อให้แอปไม่ crash เมื่อ Backend ส่งฟิลด์หาย/ผิดชนิด และบางตัวมี `toRequestJson()` / `toJson()` / `toCommitJson()` สำหรับส่งกลับ

> [!WHY]
> **ทำไมต้องป้องกัน JSON ขนาดนี้** แอปและ Backend อัปเดตไม่พร้อมกัน (มือถือบางเครื่องยังเป็นรุ่นเก่า) ถ้าตัวแปลงเชื่อว่าฟิลด์ต้องมีเสมอ `json['x'] as String` จะโยน error ตอนฟิลด์ขาดแล้วทั้งหน้าพัง การให้ค่าสำรองทำให้แอป "ดีเกรด" อย่างนุ่มนวลแทน

#### `air_conditioner.dart` — แอร์หนึ่งเครื่อง

- **enum** `AirMode {auto, cool, dry, fan, heat}`, `FanSpeed {auto, low, medium, high, turbo}`, `SwingMode {auto, top, upper, middle, lower, bottom, off}` ชื่อ enum ตรงกับสตริงที่ Backend/เฟิร์มแวร์ใช้ (ส่งด้วย `.name`) และมี extension `.label` สำหรับข้อความที่แสดง
- **คลาส `AirConditioner`** ฟิลด์แบ่งเป็นกลุ่ม: ตัวตน (`id` = เลข air ในห้อง, `deviceId` เช่น `ESP32-XXXXXXXXXXXX`, `roomNumber`, `bleName`, `protocol` ค่าเริ่มต้น `HAIER_AC160`, `provisionStatus`, `mqttTopic`, `dailyOn/dailyOff`), สถานะออนไลน์ (`isOnline`, `lastSeenAt`), **สถานะที่สั่ง** (`isOn`, `temperature`, `mode`, `fanSpeed`, `verticalSwing`, `eco`, `turbo` ฯลฯ), **ค่าที่วัดจริงจาก PZEM** (`voltage`, `current`, `power`, `energyKwh`, `frequencyHz`, `powerFactor`, `pzemAvailable`), `isRunning` (แอร์กำลังกินไฟจริงหรือไม่) และกลุ่มปิดอัตโนมัติ (`autoOffEnabled`, `autoOffDeadlineAt`, `autoOffAttempts`, `autoOffInClass`)
- **ข้อควรจำ:** `isOn` (คำสั่งล่าสุดที่ระบบส่ง ทั้งแบบยิง IR และแบบสายแอร์) กับ `isRunning` (กำลังไฟจริงจาก PZEM) เป็นคนละเรื่องกัน เพราะรีโมตอินฟราเรดไม่มีสัญญาณตอบกลับ และแม้บอร์ดสายแอร์จะอ่านสถานะจากสายได้ แอปก็ยังใช้กติกาเดียวกันทุกรุ่น `test/pzem_status_test.dart` ยืนยันว่าห้องนับแอร์ที่ "ทำงาน" จาก `isRunning` ไม่ใช่ `isOn`
- **getter `isPoweredOn`:** `isOn || (pzemAvailable && isRunning)` คือ "แอร์เปิดอยู่จริงไหม" ใช้แสดงผลบนหน้าจอแทน `isOn` แก้ปัญหาที่มีคนเปิดแอร์ด้วยรีโมตตัวจริง แล้วแอปขึ้นว่า "ปิดอยู่" ทั้งที่ PZEM วัดได้ว่ากินไฟ (เกณฑ์ ≥ 30 W ติดกัน 3 ครั้งจากเฟิร์มแวร์) ดูรายละเอียดในหัวข้อถัดไป
- **getter สิทธิ์ควบคุม:** `canControl => isProvisioned && isOnline && deviceId != null`
- **ยี่ห้อและวิธีควบคุม:** ฟังก์ชันนอกคลาส `airBrandOf(protocol)` / `airControlTypeOf(protocol)` และ getter `isWired`, `brand`, `controlTypeLabel` แยกแอร์ที่ **ยิง IR** ออกจากแอร์ที่ **ต่อสายแอร์ Daikin** (`protocol = 'DAIKIN_WIRED'`) ดูหัวข้อย่อยถัดไป
- **ข้อจำกัดตามโปรโตคอล:** `isSaijoDenki` (`protocol == 'SAIJO_DENKI'`) ทำให้ `minimumTemperature`/`maximumTemperature` เป็น 18/29 (ปกติ 16/30), `supportedModes` เหลือ cool/dry/fan, `supportedSwingModes` มี upper/lower แต่ไม่มี off และ `supportsAdditionalFunctions` เป็นเท็จ ส่วน `isWired` จำกัดโหมดเป็น cool/dry/fan พัดลมไม่มี turbo สวิงมีแค่ auto/off และฟังก์ชันเสริมเหลือ Sleep ผ่าน getter รายตัว `supportsEco`, `supportsSleep` ฯลฯ `normalizeForProtocol()` ถูกเรียกใน constructor และ `copyStateFrom` เพื่อบังคับค่าให้อยู่ในขอบเขต (`test/saijo_denki_support_test.dart`, `test/daikin_wired_support_test.dart`)
- `toCommandJson()` สร้าง body ของ `POST /air-conditioners/:deviceId/command`
- `editableCopy()` ทำสำเนาไว้ให้หน้าจอแก้ค่าก่อนกดยืนยัน `copyStateFrom(other)` คัดลอกเฉพาะฟิลด์สถานะสั่งการกลับ
- ฟังก์ชันช่วยส่วนตัว `_enumByName`, `_string`, `_int`, `_nullableInt`, `_double` แปลงค่าจาก JSON อย่างปลอดภัย (ดูบรรทัดต่อบรรทัดในหัวข้อเจาะโค้ด)
- ใช้โดย `AirConditionerService`, `AirConditionerController`, `Room.airConditioners` และหน้าควบคุมแอร์

##### บอร์ดสายแอร์ Daikin: ยี่ห้อ วิธีควบคุม และฟังก์ชันที่ทำได้

ระบบมีบอร์ดแอร์สองรุ่น รุ่นที่สองคือ `rmutt_esp32_air_wired` ซึ่ง **ไม่ยิงอินฟราเรด** แต่ต่อเข้ากับสายสัญญาณของแอร์ Daikin แทนรีโมตติดผนัง (คุยด้วยโปรโตคอลของสายแอร์ ดูบทเฟิร์มแวร์) ในฐานข้อมูลแอร์แบบนี้มี `protocol = 'DAIKIN_WIRED'` แอปไม่ได้เพิ่มฟิลด์ใหม่ในโมเดลแอร์ แต่ **อนุมานยี่ห้อและวิธีควบคุมจาก `protocol`** ด้วยฟังก์ชันระดับบนสุด (top-level function คือฟังก์ชันที่อยู่นอกคลาส เรียกได้โดยไม่ต้องมี object) สองตัว

**ไฟล์ `lib/models/air_conditioner.dart` บรรทัด 39–72**

```dart:39
/// บอร์ดรุ่นสายแอร์ (rmutt_esp32_air_wired) ต่อสายแอร์แทนรีโมตติดผนัง Daikin
const daikinWiredProtocol = 'DAIKIN_WIRED';

/// ชื่อยี่ห้อที่คนอ่านเข้าใจ จากชื่อโปรโตคอลที่เก็บในฐานข้อมูล
String airBrandOf(String protocol) {
  final value = protocol.trim().toUpperCase();
  if (value == daikinWiredProtocol || value.startsWith('DAIKIN')) {
    return 'Daikin';
  }
  if (value == 'SAIJO_DENKI') return 'Saijo Denki';
  if (value.startsWith('MITSUBISHI')) return 'Mitsubishi Electric';
  if (value.startsWith('HAIER')) return 'Haier';
  const names = {
    'PANASONIC_AC': 'Panasonic',
    'PANASONIC_AC32': 'Panasonic',
    'GREE': 'Gree',
    'MIDEA': 'Midea',
    'COOLIX': 'Midea',
    'LG': 'LG',
    'LG2': 'LG',
    'SAMSUNG_AC': 'Samsung',
    'TOSHIBA_AC': 'Toshiba',
    'HITACHI_AC': 'Hitachi',
    'FUJITSU_AC': 'Fujitsu',
    'KELVINATOR': 'Kelvinator',
    'SHARP_AC': 'Sharp',
    'ELECTRA_AC': 'Electra',
  };
  return names[value] ?? protocol;
}

/// `wired` สำหรับบอร์ดสายแอร์ นอกนั้น `ir`
String airControlTypeOf(String protocol) =>
    protocol.trim().toUpperCase() == daikinWiredProtocol ? 'wired' : 'ir';
```

| บรรทัด | อธิบาย |
|---|---|
| 40 | `const daikinWiredProtocol` ค่าคงที่ตัวเดียวที่ทั้งไฟล์และหน้าตั้งค่าบลูทูธใช้ร่วมกัน (พิมพ์ `'DAIKIN_WIRED'` ที่เดียว ลดโอกาสสะกดผิด) ตรงกับ `WIRED_PROTOCOL` ใน `backend/src/utils/air-conditioner.js` |
| 43–44 | `airBrandOf` รับชื่อโปรโตคอล ตัดช่องว่างและทำเป็นตัวใหญ่ก่อน (`trim().toUpperCase()`) เพื่อให้ `'daikin_wired'` กับ `'DAIKIN_WIRED'` ได้ผลเดียวกัน |
| 45–47 | ทั้ง `DAIKIN_WIRED` และ `DAIKIN` (บอร์ด IR) เป็นยี่ห้อ Daikin เหมือนกัน ต่างกันแค่วิธีควบคุม |
| 48–50 | โปรโตคอลที่มีหลายรุ่นใช้ `startsWith` จับทั้งตระกูล เช่น `HAIER_AC160`, `HAIER_AC176`, `HAIER_AC_YRW02`, `HAIER_AC` เป็น Haier ทั้งหมด |
| 51–66 | ตาราง (`Map`) ชื่อโปรโตคอลที่เหลือ → ชื่อยี่ห้อ หลายโปรโตคอลชี้ยี่ห้อเดียวกันได้ (`COOLIX` → Midea, `LG2` → LG) |
| 67 | `names[value] ?? protocol` ถ้าไม่รู้จัก คืนชื่อโปรโตคอลเดิม (ไม่คืนข้อความว่าง) ผู้ใช้ยังพอเดาได้ว่าเป็นเครื่องอะไร |
| 71–72 | `airControlTypeOf` คืน `'wired'` เฉพาะ `DAIKIN_WIRED` นอกนั้นเป็น `'ir'` ทั้งหมด `=>` คือฟังก์ชันที่มีคำสั่งเดียวและคืนค่านั้นเลย |

> [!WHY]
> **ทำไมอนุมานจาก `protocol` แทนที่จะอ่านฟิลด์ `controlType`** Backend ส่ง `controlType` มาใน JSON ของแอร์ด้วย (`publicAirConditioner` ใน `backend/src/utils/air-conditioner.js`) แต่ค่านั้นก็คำนวณจาก `protocol` ด้วยกติกาเดียวกัน (`controlTypeOf`) แอป Flutter จึงไม่อ่านฟิลด์นี้ คำนวณเองจาก `protocol` ข้อดีคือข้อมูลมีแหล่งเดียว ไม่มีทางเกิดกรณี `protocol = HAIER_AC160` แต่ `controlType = wired` ที่ขัดกันเอง และ Backend รับประกันว่าบอร์ดสายแอร์มี `protocol = DAIKIN_WIRED` เสมอ (ถ้าบอร์ดรายงาน status ว่า `controlMode: "wired"` แต่ในฐานข้อมูลยังเป็นยี่ห้อ IR จะแก้ให้ใน `protocolFromStatus`) ส่วนการเขียนเป็นฟังก์ชันนอกคลาส ทำให้วิดเจ็ตที่มีแค่ข้อความ `protocol` (เช่น `AirControlBadge`) เรียกใช้ได้โดยไม่ต้องสร้าง `AirConditioner` ทั้งตัว

getter ในคลาส `AirConditioner` ที่เพิ่มคู่กัน

**ไฟล์ `lib/models/air_conditioner.dart` บรรทัด 237–244**

```dart:237
  /// ควบคุมผ่านสายแอร์ (แทนรีโมตติดผนัง) ไม่ใช่ยิง IR
  bool get isWired => airControlTypeOf(protocol) == 'wired';

  /// ยี่ห้อแอร์ เช่น Daikin, Haier
  String get brand => airBrandOf(protocol);

  /// ข้อความสั้นบอกยี่ห้อ + วิธีควบคุม (ส่งผ่าน context.tr ก่อนแสดง)
  String get controlTypeLabel => isWired ? 'Wired' : 'IR remote';
```

| บรรทัด | อธิบาย |
|---|---|
| 238 | `isWired` จริงเมื่อเป็นบอร์ดสายแอร์ ใช้ตัดสินทุกข้อจำกัดด้านล่าง และใช้ใน `FullRemoteSheet` |
| 241 | `brand` ชื่อยี่ห้อสำหรับแสดงผล |
| 244 | `controlTypeLabel` คืนข้อความอังกฤษ `'Wired'` หรือ `'IR remote'` ซึ่งเป็น **กุญแจแปลภาษา** (แปลเป็น "สายแอร์" / "รีโมต IR") ตอนนี้ `brand` กับ `controlTypeLabel` ถูกใช้ในเทสต์ ส่วนวิดเจ็ตเรียก `airBrandOf`/`airControlTypeOf` ตรง ๆ |

ข้อจำกัดของแต่ละรุ่น (ใช้ทั้งการ์ดแอร์และรีโมตเต็ม เพื่อแสดงเฉพาะปุ่มที่แอร์ทำได้)

**ไฟล์ `lib/models/air_conditioner.dart` บรรทัด 248–264**

```dart:248
  List<AirMode> get supportedModes =>
      isSaijoDenki || isWired
          ? const [AirMode.cool, AirMode.dry, AirMode.fan]
          : AirMode.values;
  List<FanSpeed> get supportedFanSpeeds => isWired
      ? const [FanSpeed.auto, FanSpeed.low, FanSpeed.medium, FanSpeed.high]
      : isSaijoDenki
      ? const [
          FanSpeed.auto,
          FanSpeed.low,
          FanSpeed.medium,
          FanSpeed.high,
          FanSpeed.turbo,
        ]
      : FanSpeed.values;
  List<SwingMode> get supportedSwingModes => isWired
      ? const [SwingMode.auto, SwingMode.off]
```

| บรรทัด | อธิบาย |
|---|---|
| 248–251 | โหมดที่ใช้ได้: Saijo Denki **หรือ** สายแอร์ มีแค่ Cool / Dry / Fan (ไม่มี Auto และ Heat) รุ่นอื่นได้ทุกโหมด (`AirMode.values` = ทุกค่าใน enum) |
| 252–253 | ความเร็วพัดลมของสายแอร์: Auto / Low / Medium / High **ไม่มี Turbo** ตัวดำเนินการ `? :` ซ้อนกัน (ternary) อ่านว่า "ถ้าสายแอร์ใช้รายการนี้ ไม่งั้นถ้า Saijo ใช้รายการถัดไป ไม่งั้นทุกค่า" |
| 254–262 | ของเดิม: Saijo มี 5 ระดับรวม Turbo รุ่นอื่นได้ทุกค่า |
| 263–264 | สวิงแนวตั้งของสายแอร์มีแค่ "ส่าย" (`auto`) กับ "หยุด" (`off`) ไม่มีตำแหน่งบาน (top/middle/bottom) เพราะรีโมตติดผนังสั่งได้แค่เปิด/ปิดการส่าย |

**ไฟล์ `lib/models/air_conditioner.dart` บรรทัด 281–291**

```dart:281
  bool get supportsAdditionalFunctions => !isSaijoDenki;

  // ฟังก์ชันเสริมทีละตัว รุ่นสายแอร์มีแค่ Sleep (ใช้ไม่ได้ในโหมด Dry)
  bool get supportsHorizontalSwing => supportsAdditionalFunctions && !isWired;
  bool get supportsEco => supportsAdditionalFunctions && !isWired;
  bool get supportsTurbo => supportsAdditionalFunctions && !isWired;
  bool get supportsSleep =>
      supportsAdditionalFunctions && !(isWired && mode == AirMode.dry);
  bool get supportsQuiet => supportsAdditionalFunctions && !isWired;
  bool get supportsDisplayLight => supportsAdditionalFunctions && !isWired;
  bool get supportsClean => supportsAdditionalFunctions && !isWired;
```

| บรรทัด | อธิบาย |
|---|---|
| 281 | getter พื้นฐาน: Saijo Denki ไม่มีฟังก์ชันเสริมเลย getter อื่นใช้เป็นเงื่อนไขร่วม |
| 284–286 | สวิงแนวนอน, Eco, Turbo: ต้องรองรับฟังก์ชันเสริม **และ** ไม่ใช่สายแอร์ |
| 287–288 | Sleep: สายแอร์ใช้ได้ **ยกเว้นตอนอยู่โหมด Dry** (`!(isWired && mode == AirMode.dry)`) getter นี้ขึ้นกับ `mode` ปัจจุบัน จึงเปลี่ยนค่าทันทีเมื่อผู้ใช้สลับโหมด |
| 289–291 | Quiet, Display Light, Clean: สายแอร์ไม่มี |

> [!WHY]
> **ทำไมต้องมี 7 getter ไม่ใช่ `supportsAdditionalFunctions` ตัวเดียว** ถ้ามีแค่สองกรณี คือ "มีครบ 7 อย่าง" (IR ทั่วไป) กับ "ไม่มีเลย" (Saijo) บูลีนตัวเดียวก็พอ แต่สายแอร์ Daikin มี **บางอย่าง** (Sleep อย่างเดียว และมีเงื่อนไขตามโหมด) ถ้ายังใช้บูลีนตัวเดียว ต้องเลือกระหว่างซ่อน Sleep ที่ใช้ได้จริง หรือโชว์ปุ่ม Eco/Turbo ที่กดแล้วไม่มีผล การมี getter ต่อฟังก์ชันทำให้หน้าจอเขียน `if (air.supportsEco)` ได้ตรง ๆ และกติกาทั้งหมดอยู่ในโมเดลที่เดียว หน้าจอไม่ต้องรู้ว่าเป็นยี่ห้ออะไร

สรุปเป็นตาราง (ตรงกับข้อความในหน้าตั้งค่าบลูทูธ "ใช้ได้: เปิด/ปิด, 16–30 °C, Cool / Dry / Fan, พัดลม Low / Medium / High / Auto, ส่าย เปิด/ปิด และ Sleep")

| ความสามารถ | IR ทั่วไป (เช่น Haier, Daikin IR) | Saijo Denki (IR) | Daikin สายแอร์ (`DAIKIN_WIRED`) |
|---|---|---|---|
| อุณหภูมิ | 16–30 °C | 18–29 °C | 16–30 °C |
| โหมด | Auto, Cool, Dry, Fan, Heat | Cool, Dry, Fan | Cool, Dry, Fan |
| พัดลม | Auto, Low, Medium, High, Turbo | Auto + 3 ระดับ + Turbo | Auto, Low, Medium, High |
| สวิงแนวตั้ง | Auto, Top, Middle, Bottom, Off | Auto + 5 ตำแหน่ง (ไม่มี Off) | Auto (ส่าย), Off (หยุด) |
| สวิงแนวนอน / Eco / Turbo / Quiet / Display Light / Clean | มี | ไม่มี | ไม่มี |
| Sleep | มี | ไม่มี | มี ยกเว้นโหมด Dry |

ตัวบังคับค่าให้ถูกรุ่น `normalizeForProtocol()` ได้กิ่งใหม่สำหรับสายแอร์

**ไฟล์ `lib/models/air_conditioner.dart` บรรทัด 304–321**

```dart:304
  void normalizeForProtocol() {
    temperature = temperature
        .clamp(minimumTemperature, maximumTemperature)
        .toInt();
    if (isWired) {
      if (!supportedModes.contains(mode)) mode = AirMode.cool;
      if (fanSpeed == FanSpeed.turbo) fanSpeed = FanSpeed.high;
      if (!supportedSwingModes.contains(verticalSwing)) {
        verticalSwing = SwingMode.auto;
      }
      horizontalSwing = false;
      eco = false;
      turbo = false;
      quiet = false;
      clean = false;
      if (mode == AirMode.dry) sleep = false;
      return;
    }
```

| บรรทัด | อธิบาย |
|---|---|
| 305–307 | บีบอุณหภูมิให้อยู่ในช่วงของรุ่น (ใช้กับทุกรุ่น) |
| 308 | เข้ากิ่งสายแอร์ |
| 309 | โหมดที่ไม่รองรับ (Auto, Heat) → Cool |
| 310 | พัดลม Turbo → High (ระดับใกล้ที่สุดที่มีจริง แทนที่จะโยน error) |
| 311–313 | ตำแหน่งสวิงที่ไม่มี (เช่น `middle`) → `auto` คือ "ส่าย" |
| 314–318 | ปิดฟังก์ชันเสริมที่สายแอร์ไม่มี |
| 319 | Sleep ปิดเมื่ออยู่โหมด Dry |
| 320 | `return` จบเลย ไม่ไหลไปกิ่ง Saijo ข้างล่าง |

> [!WHY]
> **ทำไมต้อง "ปรับค่า" ในแอป ทั้งที่ Backend ก็ตรวจซ้ำ** Backend (`validateAirState` ใน `backend/src/utils/air-conditioner.js`) **ปฏิเสธ** คำสั่งสายแอร์ที่โหมดไม่ใช่ Cool/Dry/Fan, พัดลม Turbo หรือสวิงที่ไม่ใช่ Auto/Off ด้วย HTTP 400 (ข้อความ "แอร์แบบสายแอร์รองรับโหมด Cool, Dry และ Fan" ฯลฯ ซึ่งแอปเพิ่มคำแปลอังกฤษไว้แล้ว) ถ้าแอปส่งร่างที่ค้างค่าเก่าจาก IR (เช่น เคยเป็น Heat) ผู้ใช้จะเจอ error ทั้งที่แค่กด +1 องศา การปรับค่าก่อนส่ง (`_sendDraft` เรียก `normalizeForProtocol()` ทุกครั้ง) จึงทำให้คำสั่งผ่านเสมอ ส่วนการตรวจที่ Backend ยังจำเป็นเพราะใครก็ยิง API ตรงได้ ฝั่ง Backend ยังบังคับ `horizontalSwing/eco/turbo/quiet/clean = false` และ `sleep = false` ในโหมด Dry ซ้ำอีกชั้นด้วย

> [!NOTE]
> `displayLight` ไม่ถูกรีเซ็ตในกิ่งสายแอร์ (สวิตช์ถูกซ่อนในรีโมตเต็ม แต่ค่ายังถูกส่งไปตามเดิม Backend ก็ส่งผ่าน) เฟิร์มแวร์สายแอร์แค่จำค่านี้ไว้ใน NVS และรายงานกลับ ไม่ได้ใช้สร้างข้อมูลที่ส่งเข้าสายแอร์ จึงไม่มีผลกับเครื่อง

`normalizeForProtocol()` ถูกเรียกใน constructor (บรรทัด 116) และใน `copyStateFrom` (บรรทัด 407) ดังนั้นแอร์ที่อ่านจาก JSON เป็นค่าที่ถูกรุ่นเสมอ ผลทั้งหมดนี้ถูกตรวจใน `test/daikin_wired_support_test.dart` (ดูหัวข้อการทดสอบ)


#### `room.dart` — ห้อง

- ฟิลด์หลัก `number` (เช่น `16301`), `floor`, `roomIndex`, `type` (เช่น Classroom), `airConditioners` (List ที่ Controller เติมให้ทีหลัง) และกลุ่มเซนเซอร์คนในห้อง (`occupancySensorDeviceId`, `...Online`, `...Available`, `occupancyStaticThreshold` ค่าเริ่มต้น 25, `occupancyUpdatedAt`, `isOccupied`) กับกลุ่มปิดอัตโนมัติระดับห้อง
- `Room.fromJson` ใส่ `airConditioners: <AirConditioner>[]` เสมอ เพราะ `GET /rooms` ไม่ส่งแอร์มาด้วย (แอร์มาจาก `/air-conditioners` แล้ว Controller แยกเข้าห้อง)
- `toRequestJson({includeNumber})` ส่งเฉพาะ `roomNumber`, `floorNumber`, `roomIndex`, `roomType` ใช้ `includeNumber: false` ตอน PUT เพราะเลขห้องอยู่ใน URL
- `copyWith(...)` สร้างสำเนาที่เปลี่ยนบางฟิลด์ (แพทเทิร์นของ object ที่ฟิลด์ส่วนใหญ่ `final`)
- getter `runningAirCount`, `totalPower` (รวมเฉพาะแอร์ที่ `isRunning`), `displayedAirCount`, `hasOccupancySensor`, `isAutoOffPending`
- คลาส `Room` ไม่ได้เป็น immutable เต็มตัว: `isOccupied`, `isOnline` และฟิลด์เซนเซอร์เป็น non-final เพื่อให้ Controller อัปเดตแบบแทนที่ค่าในที่เดิมโดยไม่ต้องสร้าง object ใหม่ทุกครั้ง (หน้าจอที่ถือ object เดิมอยู่จะเห็นค่าใหม่)

##### สถานะเปิด/ปิดจริง: `isPoweredOn`

**ไฟล์ `lib/models/air_conditioner.dart` บรรทัด 226–231**

```dart:226
  /// เครื่องเปิดอยู่จริงหรือไม่ ใช้แสดงผลและเป็นค่าตั้งต้นของคำสั่งถัดไป
  ///
  /// `isOn` คือคำสั่งล่าสุดที่ระบบยิง IR ไป ถ้ามีคนเปิดแอร์ด้วยรีโมตจริง
  /// ค่านี้จะยังเป็น false ทั้งที่แอร์กินไฟอยู่ จึงเชื่อ PZEM ด้วย:
  /// ถ้าเฟิร์มแวร์ยืนยันแล้วว่าแอร์ทำงาน (>= 30 W ติดกัน 3 ครั้ง) ถือว่าเปิดอยู่
  bool get isPoweredOn => isOn || (pzemAvailable && isRunning);
```

| บรรทัด | ความหมาย |
|---|---|
| 226–230 | คอมเมนต์บอกเหตุผล: `isOn` เป็นแค่ "คำสั่งล่าสุดที่ระบบส่ง" ไม่รู้ว่ามีคนกดรีโมตจริง |
| 231 | `get` คือ getter (คำนวณใหม่ทุกครั้งที่อ่าน ไม่เก็บค่า) ถือว่าเปิดถ้า **ระบบสั่งเปิด** หรือ **PZEM ใช้ได้และยืนยันว่าแอร์ทำงาน** ต้องเช็ก `pzemAvailable` ก่อน เพราะถ้าไม่มีมิเตอร์ ค่า `isRunning` เชื่อไม่ได้ |

อีกสองจุดที่ทำงานคู่กับ `isPoweredOn`:

- **`editableCopy()`** สร้างร่างด้วย `isOn: isPoweredOn` ถ้าแอร์ถูกเปิดด้วยรีโมตจริง แล้วผู้ใช้กดปุ่ม + อุณหภูมิในแอป คำสั่งที่ส่งจะเป็น "เปิด 26°C" ไม่ใช่ "ปิด" (ถ้าร่างเริ่มจาก `isOn = false` การกดปรับอุณหภูมิจะกลายเป็นสั่งปิดแอร์โดยไม่ตั้งใจ)
- **`copyStateFrom()`** ถ้าคำสั่งที่เพิ่งส่งเป็น "ปิด" จะตั้ง `isRunning = false` ทันที หน้าจอขึ้นว่าปิดเลยไม่ต้องรอ PZEM ราว 6 วินาที (3 รอบ × 2 วินาที) ถ้าแอร์ไม่ดับจริง รอบดึงข้อมูลถัดไปจะได้ `acRunning = true` กลับมาเอง

> [!WHY]
> รีโมตอินฟราเรดส่งทางเดียว ระบบจึงไม่มีทางรู้ว่ามีคนกดรีโมตตัวจริง แหล่งความจริงเดียวที่มีคือไฟฟ้าที่ PZEM วัดได้ การรวมสองแหล่ง (คำสั่ง OR กำลังไฟ) ทำให้หน้าจอตรงกับความจริงมากขึ้น และกันการสั่งผิดทาง

> [!ASK]
> **ถาม:** ถ้ามีคนเปิดแอร์ด้วยรีโมตจริง แอปจะรู้ไหม?
> **ตอบ:** รู้ครับ ภายในราว 6 วินาทีที่ PZEM วัดได้ ≥ 30 W ติดกัน 3 ครั้ง บอร์ดส่ง `acRunning = true` แอปใช้ `isPoweredOn` ซึ่งเชื่อทั้งคำสั่งล่าสุดและค่าไฟจริง จึงขึ้นว่าเปิดอยู่ และถ้าผู้ใช้ปรับอุณหภูมิต่อ คำสั่งจะยังเป็น "เปิด" เว็บแอปใช้กติกาเดียวกัน แต่รู้แค่เปิด/ปิด ไม่รู้ว่าตั้งกี่องศาบนรีโมต

#### `auth_user.dart`, `remembered_login.dart`, `admin_contact.dart`, `managed_user.dart` — ผู้ใช้และคนติดต่อ

- `AuthUser` ผู้ใช้ที่ล็อกอินอยู่: `username`, `firstName`, `lastName`, `email`, `phone`, `role` (ค่าสำรอง `'staff'`) getter `displayName` (ต่อชื่อ-นามสกุล ถ้าว่างใช้ username) และ `roleLabel` (`admin` → Administrator ที่เหลือ Staff) ตัวเทียบสิทธิ์ที่หน้าจอใช้คือ `user.role.toLowerCase() == 'admin'`
- `RememberedLogin` มีแค่ `username` กับ `password` (ว่างเสมอ)
- `AdminContact` ชื่อ (สำรอง `'Administrator'`) และเบอร์
- `ManagedUser` ผู้ใช้ในหน้าจัดการ: เพิ่ม `isActive`, `lastLoginAt`, `createdAt` (แปลง `DateTime.tryParse(...)?.toLocal()` เป็นเวลาท้องถิ่น) `role` ถูกแปลงเป็นตัวพิมพ์เล็กเสมอ getter `isAdmin`, `displayName`, `initials` (ตัวอักษรย่อสำหรับวงกลมรูปโปรไฟล์) และ `copyWith({role, isActive})` ที่เปลี่ยนได้เฉพาะสองฟิลด์นี้ (`test/user_management_test.dart`)

#### `class_schedule.dart` — คาบเรียน

- ฟิลด์ `id`, `roomNumber`, `dayOfWeek` (0 = อาทิตย์ ... 6 = เสาร์ ตามดัชนีตารางที่ `schedule_screen.dart` ใช้), `subjectName`, `section`, `instructor`, `startTime`/`endTime` เป็นข้อความ `HH:mm` แบบ 24 ชั่วโมง
- `timesOverlap(firstStart, firstEnd, secondStart, secondEnd)` ตรวจเวลาทับกันด้วยการเทียบข้อความ: `firstStart < secondEnd && firstEnd > secondStart` (ใช้ `<` และ `>` ไม่ใช่ `<=` ดังนั้นคาบ 09:00–12:00 กับ 12:00–13:00 **ไม่ทับกัน** ตามที่ `class_schedule_test.dart` ยืนยัน)

> [!WHY]
> **ทำไมเทียบเวลาเป็นข้อความได้** เพราะรูปแบบ `HH:mm` เติมศูนย์นำหน้าเสมอ ลำดับตามตัวอักษรจึงตรงกับลำดับเวลา (`'09:00' < '12:00'`) ไม่ต้องแปลงเป็นนาที ข้อเสียคือถ้ามีใครส่ง `9:00` (ไม่มีศูนย์) จะเทียบผิด จึงต้องให้ Backend/ฟอร์มรับประกันรูปแบบ

#### `schedule_import.dart` — นำเข้าตารางจาก Excel

`ScheduleImportEntry` (หนึ่งคาบที่อ่านจากไฟล์), `ScheduleImportRoom` (ห้องที่ยังไม่มีในระบบ ค่าสำรอง roomType `'Special'`), `ScheduleImportPreview` (ผลพรีวิวทั้งไฟล์: คาบ ห้อง ห้องใหม่ คำเตือน ชีตที่ข้าม csv) และ `ScheduleImportResult` (ผลหลังยืนยัน: `importedCount`, `replacedRooms`, `createdRooms`) จุดสำคัญคือ `withTerm(...)` สร้างสำเนาที่ติดภาคเรียนและช่วงวันที่ (`isoDate` → `yyyy-MM-dd`) และ `toCommitJson()` สร้าง body ของ `POST /schedules/import/commit`: `createMissingRooms` เป็นจริงเมื่อมีห้องใหม่, ใส่ `semester`/`startDate`/`endDate` เฉพาะเมื่อผู้ใช้เลือกภาคเรียนแล้ว (`test/schedule_import_test.dart`) ฟังก์ชัน `_strings` กรองลิสต์ให้เหลือเฉพาะ `String` `ScheduleImportPreview` มีฟิลด์ใหม่ `replaceAll` (ค่าเริ่มต้น `false`) และเมธอด `withReplaceAll(bool)` ที่สร้างสำเนาเหมือน `withTerm` `toCommitJson()` ใส่ `'replaceAll': true` เฉพาะตอนเลือก "เปลี่ยนภาคเรียน" (ใช้ collection-if `if (replaceAll) 'replaceAll': true`) เหตุผลเขียนไว้ในคอมเมนต์ของโค้ด: ไฟล์ของเทอมใหม่มักไม่มีชีตของห้องที่เทอมนี้ไม่มีเรียน ถ้าไม่ล้าง ห้องพวกนั้นจะค้างตารางเทอมเก่า และระบบปิดแอร์จะคิดว่ายังมีคาบ (รอ 15 นาทีแทน 5) รายละเอียดหน้าจออยู่ในบทหน้าจอผู้ดูแล

#### `room_calendar.dart` — ปฏิทินการใช้ห้องและภาคเรียน (353 บรรทัด)

ไฟล์นี้เกิดขึ้นเพื่อให้แอปมือถือ "จัดการตารางเรียนได้เหมือนเว็บแอป" คอมเมนต์หัวไฟล์บอกตรง ๆ ว่าตรรกะวันที่ทั้งหมด **เหมือนกับ Backend** (`backend/src/utils/room-booking.js`) และเว็บแอป (`webapp/assets/js/views/booking-form.js`) ผลของทั้งสามฝั่งจึงตรงกัน

| ส่วน | หน้าที่ |
|---|---|
| `isoDateOf`, `dateOfIso` | แปลง `DateTime` ↔ ข้อความ `yyyy-MM-dd` |
| `dayOfWeekOfIso` | วันในสัปดาห์ของวันที่ (0 = อาทิตย์ ตรงกับ Backend และตารางเรียน) |
| `addDaysIso`, `daysBetweenIso` | บวกวัน / นับจำนวนวันระหว่างสองวัน |
| `weekStartIso` | วันอาทิตย์ของสัปดาห์ที่มีวันนั้น (สัปดาห์เรียงอาทิตย์–เสาร์ เหมือนเว็บ) |
| `enum BookingRepeat {once, daily, weekly}` | แบบการทำซ้ำของการใช้ห้อง |
| `bookingCategories`, `bookingCategoryLabel` | ประเภท `meeting`, `class`, `exam`, `event`, `other` ตรงกับ `BOOKING_CATEGORIES` ของ Backend พร้อมชื่อไทย/อังกฤษ |
| `RoomBooking` | การใช้ห้องหนึ่งรายการ: ห้อง ชื่อ ประเภท หมายเหตุ การทำซ้ำ วันในสัปดาห์ ช่วงวันที่ ช่วงเวลา |
| `countBookingOccurrences` | นับว่าการจองเกิดกี่ครั้ง ใช้สรุปให้ผู้ใช้เห็นก่อนบันทึก |
| `enum TermStatus`, `AcademicTerm` | ภาคเรียนหนึ่งเทอม (`1/2569`) วันเปิด–ปิด และสถานะ ก่อนเปิด / กำลังเปิด / ปิดแล้ว |
| `AcademicCalendar` | ปฏิทินทั้งหมด + "วันนี้" ตามเวลาไทยจากเซิร์ฟเวอร์ |
| `TimetableInfo` | ตารางที่ใช้อยู่เป็นของภาคเรียนไหน ใครนำเข้า เมื่อไร |
| `ScheduleBundle` | ผลของ `GET /schedules`: รายการคาบ + `timetable` + `supportsTimetable` |
| `schedulesToCsv` | สร้างไฟล์ CSV ของตารางเรียนในรูปแบบเดียวกับที่ Backend และเว็บส่งออก |

> [!WHY]
> **ทำไมเก็บวันที่เป็นข้อความ `yyyy-MM-dd` ไม่ใช่ `DateTime`** การจองห้องสนใจแค่ "วันที่ในปฏิทิน" ไม่สนเวลาและเขตเวลา ถ้าเก็บเป็น `DateTime` จะเจอปัญหาเที่ยงคืนของเขตเวลาหนึ่งเป็นอีกวันของอีกเขต ข้อความรูปแบบนี้ยัง **เรียงตามตัวอักษรได้ตรงกับเรียงตามวัน** (`'2026-10-09' < '2026-10-10'`) จึงเทียบด้วย `compareTo` ได้ทันที หลักเดียวกับเวลา `HH:mm` ใน `class_schedule.dart`

ไฟล์ `lib/models/room_calendar.dart` บรรทัด 29–42

```dart:29
/// บวกวัน ใช้ DateTime(y, m, d + n) เพราะไม่โดนผลของเวลาออมแสง
String addDaysIso(String value, int days) {
  final date = dateOfIso(value);
  return isoDateOf(DateTime(date.year, date.month, date.day + days));
}

/// จำนวนวันจาก [from] ถึง [to]
int daysBetweenIso(String from, String to) {
  final start = dateOfIso(from);
  final end = dateOfIso(to);
  return DateTime.utc(end.year, end.month, end.day)
      .difference(DateTime.utc(start.year, start.month, start.day))
      .inDays;
}
```

| บรรทัด | อธิบาย |
|---|---|
| 30–33 | บวกวันด้วยการสร้าง `DateTime(ปี, เดือน, วัน + n)` ใหม่ Dart จัดการวันเกินเดือนให้เอง เช่น 31 + 1 ของตุลาคมกลายเป็น 1 พฤศจิกายน |
| 29 | เหตุที่ไม่ใช้ `date.add(Duration(days: n))` คือ `Duration` นับเป็นชั่วโมงจริง (24 ชม. × n) ในประเทศที่มีเวลาออมแสง บางวันยาว 23 หรือ 25 ชั่วโมง ผลจะเพี้ยนไปหนึ่งวันได้ |
| 36–42 | นับวันโดยแปลงทั้งสองฝั่งเป็น UTC ก่อนลบ UTC ไม่มีเวลาออมแสง ทุกวันยาว 24 ชั่วโมงพอดี `inDays` จึงได้จำนวนเต็มที่ถูก |

ไฟล์ `lib/models/room_calendar.dart` บรรทัด 146–161

```dart:146
  /// การจองนี้มีในวันที่ [date] หรือไม่ (ตรรกะเดียวกับ Backend)
  bool occursOn(String date) {
    if (date.compareTo(startDate) < 0) return false;
    final last = repeat == BookingRepeat.once ? startDate : endDate;
    if (date.compareTo(last) > 0) return false;
    if (repeat == BookingRepeat.weekly) {
      return daysOfWeek.contains(dayOfWeekOfIso(date));
    }
    return true;
  }

  /// ทับช่วงวันที่ [from]–[to] อย่างน้อยหนึ่งวันหรือไม่ (ไม่ได้ดูวันในสัปดาห์)
  bool overlapsRange(String from, String to) {
    final last = repeat == BookingRepeat.once ? startDate : endDate;
    return startDate.compareTo(to) <= 0 && last.compareTo(from) >= 0;
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 148 | วันที่ถามมาก่อนวันเริ่ม → ไม่มี |
| 149 | วันสุดท้าย: ถ้าเป็น "วันเดียว" ใช้วันเริ่มเป็นวันสุดท้าย (ไม่เชื่อ `endDate` ที่อาจค้างค่าเก่ามา) |
| 150 | เลยวันสุดท้าย → ไม่มี |
| 151–153 | แบบรายสัปดาห์ ต้องตรงวันที่เลือกด้วย เช่น เลือก `[3]` (พุธ) ก็มีแค่วันพุธในช่วง |
| 154 | แบบวันเดียวหรือรายวัน ผ่านสองด่านแรกแล้วถือว่ามี |
| 158–161 | สูตรมาตรฐานของ "สองช่วงทับกัน": ช่วง A เริ่มก่อน B จบ **และ** A จบหลัง B เริ่ม ใช้กรองการจองที่เกี่ยวกับสัปดาห์ที่กำลังดู |

ไฟล์ `lib/models/room_calendar.dart` บรรทัด 178–196

```dart:178
int countBookingOccurrences({
  required BookingRepeat repeat,
  required String startDate,
  required String endDate,
  List<int> daysOfWeek = const [],
}) {
  if (repeat == BookingRepeat.once) return 1;
  final span = daysBetweenIso(startDate, endDate);
  if (span < 0) return 0;
  if (repeat == BookingRepeat.daily) return span + 1;
  final days = daysOfWeek.toSet();
  if (days.isEmpty) return 0;
  var count = 0;
  final first = dayOfWeekOfIso(startDate);
  for (var index = 0; index <= span; index++) {
    if (days.contains((first + index) % 7)) count++;
  }
  return count;
}
```

| บรรทัด | อธิบาย |
|---|---|
| 184 | วันเดียว = 1 ครั้งเสมอ |
| 185–186 | ช่วงวันที่กลับด้าน (วันจบก่อนวันเริ่ม) = 0 ครั้ง ฟอร์มใช้ค่านี้บอกผู้ใช้ว่าตั้งผิด |
| 187 | รายวัน = จำนวนวันในช่วง + 1 (นับทั้งวันแรกและวันสุดท้าย เช่น 1–7 ต.ค. = 6 + 1 = 7 วัน) |
| 188–189 | รายสัปดาห์แต่ไม่ได้เลือกวัน = 0 |
| 191–194 | ไล่ทีละวันในช่วง หาวันในสัปดาห์ด้วย `(วันแรก + index) % 7` ไม่ต้องสร้าง `DateTime` ทุกรอบ แล้วนับเฉพาะวันที่เลือก |

ตัวอย่าง: ทุกวันพุธ 7 ต.ค. – 31 ธ.ค. 2569 ได้ 13 ครั้ง หน้าฟอร์มแสดงว่า "ทุกวันพุธ · 7 ต.ค. 2569 – 31 ธ.ค. 2569 · 13:00–15:00 · รวม 13 ครั้ง"

**`AcademicTerm`** มี `contains(date)` (รวมวันเปิดและวันปิด), `statusOn(today)` (ก่อน / ระหว่าง / หลัง) และ `semesterPattern = ^[1-3]/\d{4}$` เมธอด `statusOn` มีไว้ใช้แทนสถานะที่ Backend ส่งมา เพราะคอมเมนต์บอกว่า "ใช้แทนค่าจาก Backend เมื่อข้ามวันระหว่างเปิดแอปค้าง" เช่น เปิดแอปค้างไว้ข้ามคืนวันเปิดภาค สถานะจากเซิร์ฟเวอร์ที่โหลดไว้จะยังเป็น "ยังไม่เปิดภาค"

**`ScheduleBundle.supportsTimetable`** บอกว่า Backend รุ่นนี้ส่งช่อง `timetable` มาไหม (`data.containsKey('timetable')`) ถ้าเป็น Backend รุ่นเก่า แอปจะซ่อนฟีเจอร์ที่ต้องใช้ภาคเรียน เช่น ตัวเลือก "เปลี่ยนภาคเรียน" และ "เพิ่มในตารางเรียน" แทนที่จะส่งคำขอที่เซิร์ฟเวอร์ไม่รู้จัก

ไฟล์ `lib/models/room_calendar.dart` บรรทัด 332–353

```dart:332
  String escape(String value) {
    if (!RegExp(r'[",\r\n]').hasMatch(value)) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  final lines = [
    header.join(','),
    for (final row in sorted)
      [
        semester,
        row.roomNumber,
        row.dayOfWeek >= 0 && row.dayOfWeek < 7 ? _dayCodes[row.dayOfWeek] : '',
        row.startTime,
        row.endTime,
        row.subjectName,
        row.section,
        row.instructor,
        'true',
      ].map(escape).join(','),
  ];
  return '﻿${lines.join('\r\n')}\r\n';
}
```

| บรรทัด | อธิบาย |
|---|---|
| 332–335 | กติกา CSV มาตรฐาน (RFC 4180): ช่องที่มีจุลภาค เครื่องหมายคำพูด หรือขึ้นบรรทัด ต้องครอบด้วย `"` และเครื่องหมาย `"` ข้างในต้องเขียนซ้ำเป็น `""` เช่น ชื่อวิชา `Lab "A", B` กลายเป็น `"Lab ""A"", B"` |
| 337–351 | หนึ่งแถวต่อหนึ่งคาบ เรียงตาม ห้อง → วัน → เวลา (เรียงไว้ก่อนหน้านี้ที่บรรทัด 324–331) วันแปลงเป็นรหัส `SUN`–`SAT` ที่ตัวนำเข้าของ Backend อ่านได้ |
| 352 | ขึ้นบรรทัดแบบ `\r\n` (มาตรฐาน CSV) และมีอักขระมองไม่เห็น **BOM** (`U+FEFF`) อยู่หน้าสุด เพื่อให้ Excel รู้ว่าเป็น UTF-8 ไม่งั้นภาษาไทยจะกลายเป็นตัวอักษรเพี้ยน |

> [!TIP]
> หัวตาราง `semester, room_code, day, start_time, end_time, subject, section, instructor, enabled` ตรงกับไฟล์ที่ Backend ส่งออก ไฟล์ที่ดาวน์โหลดจากแอปจึงนำกลับเข้าระบบด้วยปุ่มนำเข้าได้ทันที (`room_calendar_test.dart` มีเคสยืนยันข้อนี้)



#### `system_alert.dart` — การแจ้งเตือนของระบบ

- `enum SystemAlertKind {outsideScheduleOccupied, autoOffSucceeded, autoOffFailed, unknown}` แปลงจากรหัสของ Backend ด้วย `SystemAlertKindLabel.fromApi` (`'outside_schedule_occupied'`, `'auto_off_succeeded'`, `'auto_off_failed'`, อื่น ๆ → `unknown`)
- extension มี `message` (ข้อความอังกฤษที่ส่งผ่านตัวแปลอีกที) และ `isWarning` (ทุกชนิดยกเว้น `autoOffSucceeded`)
- `SystemAlert`: `id`, `kind`, `roomNumber`, `status` (`open` / `acknowledged` / `resolved`), `createdAt`, `deviceId`, `deviceName`, `detail`, `acknowledgedBy` + getter `isOpen`, `isWarning` + `copyWith({status, acknowledgedBy})`

> [!WHY]
> **ทำไม Backend ส่ง "รหัสชนิด" ไม่ส่งข้อความสำเร็จรูป** เพื่อให้แอปเลือกถ้อยคำและภาษาเองได้ (ไทย/อังกฤษ) และมีชนิด `unknown` ไว้รับชนิดใหม่ที่แอปรุ่นเก่ายังไม่รู้จักแบบไม่พัง

#### `energy_data.dart` — พลังงานและรายงาน (ไฟล์ใหญ่สุด 631 บรรทัด)

| คลาส/enum | ใช้ทำอะไร |
|---|---|
| `EnergyScope {building, room, device}` + extension `EnergyScopeApi` | ระดับการรวมของรายงาน (`apiValue`, `label`, `description`, `isHighDetail` = ทุกระดับที่ไม่ใช่ building) |
| `EnergyMetric` | ค่าไฟหนึ่งชนิดที่เลือกใส่รายงานได้ (key, ป้ายไทย/อังกฤษ, หน่วย, ทศนิยม, `detailOnly`, `isDefault`) มาจาก `GET /energy/metrics` |
| `EnergyLiveReading` / `EnergyLiveSnapshot` | ค่าล่าสุดของแอร์รายเครื่องและผลรวม (devices/online/running/totalPowerWatts) จาก `GET /energy/live` ค่าที่อาจไม่มีเป็น `double?` และ `receivedAt` = `DateTime.now()` ตอนรับ |
| `EnergyRoomSource`, `EnergyDeviceSource`, `EnergySourceCatalog` | ห้อง/เครื่องที่เลือกใส่รายงานได้ + ช่วงวันที่ที่มีข้อมูล (`coverage.oldest/newest`) `devicesInRooms(...)` กรองเครื่องตามห้อง |
| `EnergyHistoryRow`, `EnergyHistoryResult` | แถวรายชั่วโมงของรายงาน (`values` เป็น `Map<String,double?>`) และผลรวม |
| `EnergyQuery` | เงื่อนไขที่ผู้ใช้เลือก → `toQueryParameters()` สร้าง query string (`from`, `to`, `scope`, `detail` = `high`/`summary`, และ `rooms`, `devices`, `metrics`, `rate` เมื่อมีค่า) |
| `EnergyExportFile` | ไฟล์ Excel ที่ดาวน์โหลดมา: `fileName`, `bytes` (`Uint8List`), `rowCount` |
| `EnergyPeriodKind {day, week, month, custom}` | ช่วงเวลาของหน้าหลัก/สถิติ (`apiValue`, `label`, `fromApi` ที่ค่าสำรองคือ `week`) |
| `EnergySeriesPoint`, `EnergyRoomUsage`, `EnergyDeviceUsage`, `EnergySummary` | ตัวเลขสรุปจาก `GET /energy/summary`: ยอด kWh ช่วงนี้/ช่วงก่อน `changePercent` (null = เทียบไม่ได้) เวลาใช้งาน กำลังไฟสูงสุด และอนุกรมเวลาแบบรายชั่วโมงหรือรายวัน `EnergySummary.empty` คือค่าตั้งต้นก่อนโหลดเสร็จ |

ฟังก์ชันส่วนตัว `_toDouble(Object?)` แปลงค่าใดก็ได้ (num/ข้อความ/null) เป็น `double?` เพราะ Backend (MariaDB) อาจส่งตัวเลขทศนิยมมาเป็นข้อความ `"12.345"` ได้

#### `provisioning.dart` — ตั้งค่า ESP32 ผ่าน BLE

| คลาส | ใช้ทำอะไร |
|---|---|
| `BleDeviceCandidate` | อุปกรณ์ BLE ที่สแกนเจอ (`BluetoothDevice`, ชื่อ, `rssi` = ความแรงสัญญาณ) |
| `WifiNetworkCandidate` | Wi-Fi ที่ ESP32 มองเห็น `fromCompactJson(List)` รับรูปแบบย่อ `[ssid, rssi, isSecure]` ตรวจชนิดทีละช่อง ถ้าผิดโยน `FormatException` (ประหยัดไบต์ เพราะ BLE ส่งได้ทีละน้อย) |
| `BleDeviceIdentity` | ตัวตนที่บอร์ดรายงานตอนเชื่อมต่อ: `deviceId`, `bleName`, `firmwareVersion`, `configured`, `deviceType` (ค่าสำรอง `air`), ห้อง/เลข air, Wi-Fi, MQTT, `dailyOn/dailyOff` และ **`hasWifiPassword`/`hasMqttPassword` (บูลีน ไม่ส่งรหัสจริงกลับมา)** `controlType` (`ir`/`wired`), `brand` และ getter `isWired` |
| `AirProvisioningRequest` / `AirProvisioningReservation` | คำขอจากฟอร์ม และ "ใบจอง" ที่ Backend ตอบ (มี `mqttTopic`, `mqttHost`, `mqttPort`, ชื่อผู้ใช้/รหัสผ่าน MQTT, `mqttTls`, `provisioningToken`) `toReservationJson()` = body ที่ส่งจอง, `toBleJson(reservation)` = JSON ที่จะเขียนลงบอร์ดผ่าน BLE |
| `OccupancyProvisioningRequest` / `OccupancyProvisioningReservation` | แบบเดียวกันสำหรับเซนเซอร์คนในห้อง (`deviceType: 'occupancy'`, `staticThreshold`) |

JSON ที่เขียนลงบอร์ดมี `version: 1`, `token` (provisioning token), `wifi {ssid, password, keepPassword}`, `mqtt {host, port, username, password, keepPassword: false, topic, tls}` และของแอร์มี `schedule {dailyOn, dailyOff, timezone: 'Asia/Bangkok'}` เพิ่ม

> [!WHY]
> **ทำไมแอปต้อง "จอง" กับ Backend ก่อนเขียนลงบอร์ด** ข้อมูล MQTT (host, ผู้ใช้, รหัส) และ token เป็นของที่ Backend เป็นผู้ออก แอปแค่ขนส่งผ่าน BLE ไปให้บอร์ดโดยไม่ต้องรู้จักรหัสล่วงหน้า และ token ทำให้บอร์ดยืนยันได้ว่าคำสั่งตั้งค่ามาจากการจองที่ชอบธรรม `keepWifiPassword` ใช้ตอนตั้งค่าซ้ำ ให้บอร์ดคงรหัส Wi-Fi เดิมโดยแอปไม่ต้องรู้รหัสนั้น

##### `controlType` และ `brand` ใน identity ของบอร์ด

ตอนแอปอ่าน identity ผ่าน BLE บอร์ดบอกชนิดของตัวเองมาด้วย เฟิร์มแวร์สายแอร์ (`2.5.2-slm8`) ส่ง `controlType: "wired"` และ `brand: "Daikin"` ส่วนเฟิร์มแวร์ IR รุ่นใหม่ส่ง `controlType: "ir"` แอปใช้ค่านี้ตัดสินว่าหน้าตั้งค่าต้องล็อกยี่ห้อหรือให้เลือก (ดูบทหน้าจอผู้ดูแลระบบ)

**ไฟล์ `lib/models/provisioning.dart` บรรทัด 83–86**

```dart:83
      // บอร์ดรุ่นเก่าไม่ส่งสองช่องนี้ = บอร์ด IR
      controlType:
          (json['controlType'] as String? ?? 'ir').trim().toLowerCase(),
      brand: json['brand'] as String? ?? '',
```

| บรรทัด | อธิบาย |
|---|---|
| 83 | คอมเมนต์บอกกติกาความเข้ากันได้ย้อนหลัง: บอร์ดที่ยังเป็นเฟิร์มแวร์เก่าไม่มีสองช่องนี้ |
| 84–85 | ไม่มีค่า → `'ir'` แล้ว `trim().toLowerCase()` ให้ `"Wired"` หรือ `" wired "` ได้ผลเดียวกับ `"wired"` |
| 86 | ยี่ห้อ ไม่มีค่า → ข้อความว่าง (บอร์ด IR ไม่บอกยี่ห้อ เพราะยี่ห้อขึ้นกับว่าแอดมินเลือกโปรโตคอลอะไร) |

**ไฟล์ `lib/models/provisioning.dart` บรรทัด 108–114**

```dart:108
  /// `ir` = ยิงรีโมต IR, `wired` = ต่อสายแอร์แทนรีโมตติดผนัง
  final String controlType;

  /// ยี่ห้อแอร์ที่บอร์ดรุ่นสายแอร์รองรับ (ว่างสำหรับบอร์ด IR)
  final String brand;

  bool get isWired => controlType == 'wired';
```

| บรรทัด | อธิบาย |
|---|---|
| 109, 112 | ฟิลด์ใหม่ใน constructor เป็นพารามิเตอร์ไม่บังคับ มีค่าเริ่มต้น `this.controlType = 'ir'`, `this.brand = ''` (บรรทัด 60–61) โค้ดเดิมที่สร้าง `BleDeviceIdentity` โดยไม่ส่งสองค่านี้ (เช่นในเทสต์) จึงไม่ต้องแก้ |
| 114 | `isWired` ให้หน้าจอเขียน `identity.isWired` แทนการเทียบข้อความเอง |

> [!WHY]
> **ทำไมให้บอร์ดบอกชนิดตัวเอง แทนที่จะให้แอดมินเลือก** บอร์ดสายแอร์กับบอร์ด IR ใช้ชื่อ BLE ขึ้นต้น `RMUTT-AC-` เหมือนกัน หน้าตาในรายการสแกนจึงแยกไม่ออก ถ้าให้แอดมินเลือกเอง อาจเลือกยี่ห้อ IR ให้บอร์ดสายแอร์ แล้วคำสั่งจะไม่ตรงกับความสามารถจริงของบอร์ด ฮาร์ดแวร์รู้ดีที่สุดว่าตัวเองเป็นแบบไหน การให้ค่าเริ่มต้นเป็น `'ir'` ทำให้บอร์ดรุ่นเก่าที่ยังไม่อัปเดตเฟิร์มแวร์ทำงานได้เหมือนเดิม (`test/daikin_wired_support_test.dart` ตรวจทั้งสองกรณี)

### Services (`lib/services/`)

ตารางสรุป Service ทั้งหมด (ทุกตัวใช้รูปแบบ `_request` ที่อธิบายไว้ข้างบน เว้นแต่ที่ระบุ):

| Repository / Service | Endpoint (ต่อท้าย `/api`) | หมายเหตุ |
|---|---|---|
| `AirConditionerRepository` / `AirConditionerService` | `GET /air-conditioners`, `POST /air-conditioners/reservations`, `POST /air-conditioners/:deviceId/command`, `POST .../:deviceId/setup-mode`, `PATCH /air-conditioners/:deviceId` (เปลี่ยนชื่อ), `DELETE /air-conditioners/:deviceId` | `sendCommand` โยน `ApiException` ถ้าไม่มี `deviceId` |
| `AlertRepository` / `AlertService` | `GET /alerts?limit=N` (ค่าเริ่มต้น 30), `POST /alerts/:id/acknowledge` | |
| `EnergyRepository` / `EnergyService` | `GET /energy/metrics`, `/energy/live`, `/energy/sources`, `/energy/summary`, `/energy/history`, `/energy/export` | timeout 20 วินาที, ดาวน์โหลด Excel 60 วินาที; ใช้ query string; อ่านหัว `x-export-filename` (ถอดด้วย `Uri.decodeComponent` เพราะชื่อไฟล์ไทยถูกเข้ารหัสมา) และ `x-export-rows` |
| `OccupancySensorRepository` / `OccupancySensorService` | `POST /occupancy-sensors/reservations`, `POST /occupancy-sensors/:deviceId/setup-mode`, `DELETE /occupancy-sensors/:deviceId` | |
| `RoomRepository` / `RoomService` | `GET/POST /rooms`, `PUT/DELETE /rooms/:roomNumber` | ใช้ `Uri.encodeComponent(room.number)` กันอักขระพิเศษใน URL (ห้องพิเศษอย่าง `CL503`) |
| `ScheduleRepository` / `ScheduleService` | `GET/POST/DELETE /schedules`, `PUT/DELETE /schedules/:id`, `POST /schedules/import/preview`, `POST /schedules/import/commit`, `GET/PUT/DELETE /schedules/terms`, `GET /bookings?from=&to=`, `POST /bookings`, `PUT/DELETE /bookings/:id` | `fetchScheduleBundle()` คืนตาราง + `timetable` ในคำขอเดียว ส่วน `fetchSchedules()` เป็นตัวห่อที่เรียก `fetchScheduleBundle()` แล้วคืนแค่ `.schedules` | พรีวิวส่ง **ไฟล์ดิบ** เป็น `application/octet-stream` + หัว `X-File-Name` (เข้ารหัส URL) timeout 45 วินาที |
| `SystemSettingsRepository` / `SystemSettingsService` | `GET /settings`, `PATCH /settings/auto-off` body `{enabled}` | ไฟล์ repository ยังนิยามคลาส `SystemSettings` ไว้ในที่เดียวกัน |
| `UserRepository` / `UserService` | `GET/POST /users`, `PATCH/DELETE /users/:username` | |
| `AuthRepository` / `AuthService` | `POST /auth/login`, `GET/PATCH /auth/me`, `POST /auth/me/password`, `POST /auth/forgot-password`, `/auth/verify-otp`, `/auth/reset-password`, `GET /public/admin-contact` | ดูหัวข้อ Auth |

#### `auth_service.dart` — ตัวจริงของ Auth และ `ApiException`

- ไฟล์นี้นิยาม `class ApiException implements Exception` (`message`, `statusCode`, `toString()` คืน `message`) ซึ่ง **ทุก Service import ไปใช้** (ไฟล์อื่นเลยมี `import 'auth_service.dart'`) แค่เพื่อใช้ชนิดนี้
- ใช้ `_get`, `_post`, `_send(method, path, token:, body:)` ต่างจาก Service อื่นที่มี `_request` ตัวเดียว เพราะ Auth มีทั้งแบบมี/ไม่มี token
- `_map(Object? value)` ตรวจว่าเป็น `Map<String,dynamic>` ไม่ใช่โยน "The server returned invalid data."
- รายละเอียดการจัดการ token ดูหัวข้อ Auth flow และบรรทัดต่อบรรทัดในหัวข้อเจาะโค้ด

#### `ble_provisioning_service.dart` — ตั้งค่าบอร์ดผ่าน BLE (ไม่มี Repository)

คลาสเดียว `BleProvisioningService` ไม่มี interface เพราะผูกกับฮาร์ดแวร์ ในเทสต์ส่งตัวปลอมที่สืบทอดคลาสเข้า `CpeAirRemoteApp(bleProvisioningService: ...)` ได้เท่าที่จำเป็น

- **UUID ของบริการ BLE ของโปรเจกต์** ทุกตัวตามแพทเทิร์น `7b57000N-a243-4e5b-8f13-179af81b2457`: `serviceUuid` (…0001), `configUuid` (…0002 เขียน config), `statusUuid` (…0003 รับ ACK ผ่าน notify), `identityUuid` (…0004 อ่านตัวตน), `wifiScanUuid` (…0005), `settingsUuid` (…0006 ค่าที่บันทึกไว้) ต้องตรงกับเฟิร์มแวร์ ESP32 เป๊ะ
- `scan({duration = 8 วินาที, namePrefix = 'RMUTT-AC-'})`: ตรวจ `FlutterBluePlus.isSupported`, รอให้ Bluetooth เปิด (timeout 5 วินาที) แล้วสแกน **ไม่กรองตาม service UUID** (คอมเมนต์ในโค้ดอธิบายว่าบน Windows บางไดรเวอร์จับคู่ผิดเมื่อชื่ออยู่ใน scan response และ UUID อยู่ใน advertisement หลัก จึงกรองด้วยชื่อ `RMUTT-AC-` แล้วค่อยตรวจ identity ทีหลัง) เก็บผลใน `Map` ตาม `remoteId` เรียงตาม `rssi` มากไปน้อย
- `readIdentity(candidate)`: เชื่อมต่อ อ่าน identity (JSON) ถ้า `configured == true` และมี characteristic settings ก็อ่านต่อแล้วรวม (`addAll`) เข้าด้วยกัน ตรวจว่าเป็นแอร์ (`RMUTT-AC-` + `ESP32-<hex 12 ตัว>`) หรือเซนเซอร์ (`RMUTT-OCC-` + `OCC32-<hex 12 ตัว>` + `deviceType == 'occupancy'`) และชื่อ BLE ต้องตรง `deviceId` ไม่งั้นโยน "Bluetooth name and ESP32 Device ID do not match." (กันเชื่อมกับบอร์ดผิดตัว) แล้ว `disconnect()` ใน `finally` เสมอ
- `scanWifiNetworks(candidate)`: อ่าน characteristic `wifiScan` (timeout 20 วินาที) ได้ `{ok, networks: [[ssid, rssi, secure], ...]}` ข้ามรายการที่รูปแบบผิดโดยเก็บรายการอื่นไว้ เรียงตามสัญญาณ
- `provision(candidate, config)`: สมัครรับ notify ของ `status`, แปลง `config` เป็น JSON → ไบต์ UTF-8 แล้ว **หั่นเป็นก้อนละ 150 ไบต์** แต่ละแพ็กเก็ตมีหัว 6 ไบต์ `[1, 1, seq สูง, seq ต่ำ, total สูง, total ต่ำ]` แล้วตามด้วยข้อมูล เขียนทีละก้อนแบบ **มีการตอบรับ** (`withoutResponse: false`) จากนั้นรอ ACK จาก notify สูงสุด 40 วินาที ถ้า `ok != true` โยนข้อความที่บอร์ดส่งมา
- `_connect(device)`: หยุดสแกน, ตัดการเชื่อมต่อเก่า, `device.connect(license: License.nonprofit, timeout: 45 วินาที)` (flutter_blue_plus 2.x บังคับให้ระบุสัญญาอนุญาตการใช้งาน โปรเจกต์นี้เป็นงานการศึกษา/ไม่แสวงหากำไร), รอ 1.2 วินาทีให้สถานะนิ่ง แล้วลองค้นหา service **สูงสุด 3 ครั้ง** (เว้น 900 มิลลิวินาที × ครั้งที่) หา service/characteristic ตาม UUID ถ้าไม่ครบ `config`/`status`/`identity` โยน error ส่วน `wifiScan` และ `settings` เป็น optional (เฟิร์มแวร์เก่าไม่มี)
- `BleProvisioningException(message)` เป็นข้อผิดพลาดเฉพาะของ BLE ข้อความหลายอันเป็นภาษาอังกฤษแล้วให้ตัวแปลแปลต่อ
- ใช้โดย `BleProvisioningScreen` และ `OccupancyProvisioningScreen` (บทถัดไป) ผ่าน `AppShell`

> [!WHY]
> **ทำไมหั่น config เป็นก้อน 150 ไบต์** BLE รับข้อมูลต่อครั้งได้จำกัดตาม MTU (ขนาดแพ็กเก็ต) ซึ่งมักเล็กกว่า JSON ของ config ที่มีรหัส Wi-Fi และ MQTT การหั่นพร้อมลำดับ (`seq`/`total`) ทำให้บอร์ดประกอบกลับได้ถูกลำดับและรู้ว่าครบหรือยัง ใช้แบบมี response เพื่อให้แน่ใจว่าแต่ละก้อนถึงจริงก่อนส่งก้อนถัดไป

#### `alert_notifier.dart` — สัญญาตัวเด้งแจ้งเตือน

- `abstract interface class AlertNotifier { Future<bool> initialize(); Future<void> show({alert, title, body}); }`
- `NoopAlertNotifier` ตัวที่ไม่ทำอะไร (`initialize` คืน `false`, `show` ว่าง)
- `AlertNotificationText {title, body}` และฟังก์ชัน `describeAlert(SystemAlert, AppLocalizations)` สร้างหัวข้อและเนื้อความตามภาษา: หัวข้อแปลจากชนิด, เนื้อความเป็น `ห้อง XXX · ชื่อเครื่อง — ข้อความ` (ไม่รับ `BuildContext` เพราะผู้เรียกอยู่ใน Controller/State ที่ไม่ได้อยู่ในต้นไม้วิดเจ็ตและหน้าจอนั้นอาจถูกถอดไปแล้ว)
- **สถานะจริงของโค้ด:** ในโปรเจกต์นี้ไม่มีคลาสไหน `implements AlertNotifier` นอกจาก `NoopAlertNotifier` และ `main()` ไม่ได้ส่ง `alertNotifier` เข้า `CpeAirRemoteApp` ดังนั้นใน `AppShell._handleNewAlerts` ตัวแปร `notifier` เป็น `null` และ **การเด้งแจ้งเตือนบนเครื่องยังไม่ทำงานจริง** (ไม่มีปลั๊กอินแจ้งเตือนใน `pubspec.yaml`) สิ่งที่ทำงานจริงคือรายการแจ้งเตือนในแอปและหน้าตั้งค่าที่จำสวิตช์ไว้ เป็นโครงรอการต่อ (คอมเมนต์บอกว่าวันหลังอาจย้ายไป FCM โดยเปลี่ยนเฉพาะตัวที่ implement สัญญานี้)

### Controllers (`lib/controllers/`)

ทุกตัว `extends ChangeNotifier` และมีรูปแบบร่วมกัน

- ฟิลด์ state สาธารณะ: `isLoading`, `hasLoaded`, `errorMessage` (ข้อความที่ตัด `'ApiException: '` ออกด้วย `error.toString().replaceFirst('ApiException: ', '')`)
- `initialize()` โหลดครั้งแรก (มียามกันซ้ำ `if (hasLoaded || isLoading) return;`) และบางตัวตั้ง `Timer.periodic`
- **รอบเงียบ (`silent: true`)** คือรอบอัตโนมัติจาก Timer ที่ไม่เปิด `isLoading` ไม่ให้หน้าจอกระพริบหมุนติ้ว
- **กันคำขอซ้อน (`_inFlight`)** ถ้ารอบอัตโนมัติมาตอนที่ยังดึงอยู่ → ข้าม (`if (silent) return;`) แต่ถ้าผู้ใช้กดรีเฟรชเอง → รอรอบเดิมให้จบก่อนแล้วดึงใหม่ เพื่อให้ได้ข้อมูลสดแน่
- `dispose()` ยกเลิก Timer

**ตารางรอบดึงข้อมูล (polling)**

| Controller | รอบ | หมายเหตุ |
|---|---|---|
| `RoomController` | 10 วินาที (`reload(silent: true)`) | เริ่มหลังโหลดครั้งแรกสำเร็จ |
| `AirConditionerController` | 10 วินาที (`refresh(silent: true)`) | |
| `DashboardController` | 30 วินาที (`_refreshInterval`) | ดึงสรุปพลังงาน + แจ้งเตือนพร้อมกัน |
| `EnergyController` | ผู้ใช้เลือกได้ `kEnergyRefreshChoices = [2, 5, 10, 30, 60]` วินาที ค่าเริ่มต้น `refreshSeconds = 5` | เริ่ม/หยุดด้วย `startLiveUpdates()`/`stopLiveUpdates()` (ตอนเปิดหน้านั้น) คอมเมนต์: ESP32 อ่าน PZEM ทุก 2 วินาที |
| `ScheduleController`, `UserController`, `SystemSettingsController` | ไม่มี Timer | โหลดเมื่อเปิด/รีเฟรชเอง |

> [!WHY]
> **ทำไมใช้ polling (ดึงซ้ำ) ไม่ใช้ WebSocket/SSE** polling ง่าย ผ่าน HTTPS/Tailscale Funnel ได้ตรงไปตรงมาและไม่ต้องดูแลการเชื่อมต่อค้าง ข้อเสียคือเห็นการเปลี่ยนแปลงช้าสุดเท่ารอบ (10–30 วินาที) และยิงคำขอสม่ำเสมอ เหมาะกับข้อมูลที่เปลี่ยนไม่ถี่อย่างสถานะแอร์ ส่วนค่าไฟสดให้ผู้ใช้ปรับรอบเองเพื่อสมดุลความสดกับภาระเครือข่าย

#### `auth_controller.dart`

`enum AuthStatus {loading, signedOut, signedIn}` ฟิลด์ `status` (เริ่ม `loading`) และ `user` เมธอด `initialize`, `login`, `loadRememberedLogin`, `clearRememberedLogin`, `updateProfile` (อัปเดต `user` แล้ว notify), `changePassword` (จบด้วย `signedOut`), `logout` เป็นตัวเดียวที่ `main.dart` สร้างเองและ `LoginScreen` รับผ่าน constructor (รายละเอียดใน Auth flow)

#### `app_settings_controller.dart` — ค่าตั้งของเครื่อง

- `abstract interface class AppSettingsStore` สัญญาที่เก็บค่าตั้ง (โหลด/บันทึก dark mode เดิม, รหัสธีม, ภาษา, อัตราค่าไฟ, ขนาดตัวอักษร, ค่าแจ้งเตือน) และ `SecureAppSettingsStore` ตัวจริงที่ใช้ `flutter_secure_storage` คีย์ `app_dark_mode`, `app_theme`, `app_language_code`, `app_electricity_rate`, `app_text_scale`, `app_alert_preferences`
- `enum AppLanguage {thai('th'), english('en')}` ค่าสำรอง `thai`
- `enum AppTextScale {small 0.90, normal 1.00, large 1.15, extraLarge 1.30}` มี `code`, `factor`, `label`, `fromCode` (ค่าสำรอง `normal`)
- `AppSettingsController({AppSettingsStore? store})` ค่าคงที่ `defaultElectricityRate = 4.50`, `minimumElectricityRate = 0.01`, `maximumElectricityRate = 100.00`
- getter: `themeChoice`, `isDarkMode` (เทา/ดำ), `language`, `electricityRate`, `textScale`, `alertPreferences`, `locale`
- `resolvedTextScale(systemScale)` คูณตัวคูณของระบบกับของแอป ถ้าค่าผิดปกติ (NaN/≤0) ใช้ของแอปอย่างเดียว ส่งผลลัพธ์ผ่าน `clamp(0.8, 2.0)`
- `calculateElectricityCost(kWh)` = `kWh * อัตรา`; `isValidElectricityRate(double?)` ตรวจช่วง 0.01–100 และต้องไม่ใช่ NaN/อนันต์
- `initialize()` อ่านทีละค่าใน `try/catch` แยกกัน ถ้าค่าไหนอ่านไม่ได้ ใช้ค่าเริ่มต้น แล้ว `notifyListeners()` ครั้งเดียว และมีการแปลงค่าเก่า: ถ้าไม่มีรหัสธีมแต่เคยเปิดโหมดมืด (`loadDarkMode`) ให้ได้ธีมเทา
- `setTheme`, `setLanguage`, `setTextScale`, `setAlertChannels`, `setNotificationsEnabled`, `setElectricityRate` ทุกตัวทำเหมือนกัน: ถ้าค่าเท่าเดิมไม่ทำอะไร (ไม่ notify) → เปลี่ยน state → `notifyListeners()` ทันที → ค่อยบันทึกใน `try/catch` (ถ้าบันทึกพลาดค่าที่เลือกยังใช้ได้ในรอบนี้) `setElectricityRate` โยน `ArgumentError` ถ้าค่าไม่ถูกต้อง
- `export '../theme/app_theme.dart' show AppThemeChoice;` ให้ไฟล์ที่ import controller นี้ใช้ `AppThemeChoice` ได้เลย

> [!WHY]
> **ทำไมเปลี่ยน state ก่อนแล้วค่อยบันทึก** ผู้ใช้เห็นผลทันทีโดยไม่รอเขียนดิสก์ และถ้าเขียนล้มเหลวแอปก็ยังไม่พัง (แค่ไม่จำค่าหลังปิดแอป) เป็นหลัก "UI ไม่ควรรอ storage"

#### `dashboard_controller.dart` — สรุปพลังงาน + แจ้งเตือน

ใช้ร่วมกันทั้งหน้าหลักและหน้าสถิติ (เปลี่ยนช่วงเวลาที่หน้าไหนอีกหน้าเห็นตรงกัน) ถือ `EnergyRepository` และ `AlertRepository`

- state: `summary` (เริ่ม `EnergySummary.empty`), `period` (เริ่ม `week`), `customFrom/customTo`, `floor` (null = ทุกชั้น), `alerts` (กรองตามค่าตั้งแล้ว), `allAlerts`, `openAlertCount`, `alertsErrorMessage` (แยกจาก `errorMessage` เพราะสองงานล้มแยกกันได้)
- `needsCustomRange` เมื่อเลือก custom แต่ยังไม่ครบวัน จะยังไม่ยิง
- `_run` ใช้ `Future.wait([_loadSummary(), _loadAlerts()])` ดึงสองอย่างพร้อมกัน แต่ **ล้มแยกกัน** (แต่ละตัวมี `try/catch` ของตัวเอง)
- **ตรวจใบแจ้งเตือนใหม่:** `freshAlerts(alerts: loaded, seenIds: _seenAlertIds)` หาใบที่ยังไม่เคยเห็น เรียก callback `onNewAlerts` เฉพาะ **หลังรอบโหลดแรก** (`_hasSeededAlerts`) ไม่งั้นเปิดแอปจะเด้งแจ้งเตือนย้อนหลัง 30 ใบรวดเดียว
- `acknowledge(id)` เรียก Backend แล้วแทนที่ใบนั้นในลิสต์ด้วยฉบับที่อัปเดต
- setter `alertPreferences` (ถ้าเท่าเดิมไม่ notify) — `AppShell` ส่งค่าตั้งล่าสุดเข้ามา

#### `energy_controller.dart` — ค่าไฟสดและรายงาน

ใช้กับหน้า "ฐานข้อมูล" แบ่งเป็น 3 กลุ่ม state: **ค่าไฟสด** (`live`, `isLiveLoading`, `liveError`, `refreshSeconds`, Timer), **แคตตาล็อกตัวเลือกรายงาน** (`metrics`, `sources`, `loadCatalog()` ใช้ `Future.wait` ดึง metrics+sources) และ **พรีวิว/ส่งออก** (`preview`, `loadPreview(query)`, `clearPreview()`, `exportExcel(query, english:)` ที่ตั้ง `isExporting` ระหว่างทำงาน) `metricsFor(scope)` ซ่อนตัวเลือก `detailOnly` เมื่ออยู่โหมดสรุป `setRefreshSeconds` รับเฉพาะค่าใน `kEnergyRefreshChoices`

#### `room_controller.dart`, `air_conditioner_controller.dart` — ห้องและแอร์

ทั้งสองถือ **ลิสต์ `rooms` ตัวเดียวกัน** (ส่งเข้ามาจาก `AppShell`) `RoomController` โหลดห้องจาก Backend แล้วแทนที่เนื้อลิสต์ (ห้องที่มีอยู่เดิมจะถูกสร้างใหม่ด้วย `copyWith` โดยคงรายการแอร์และสถานะออนไลน์ของห้องเดิมไว้) ส่วน `AirConditionerController` ดึงแอร์ทั้งหมดแล้ว "แจก" เข้า `room.airConditioners` ตามเลขห้อง และตั้ง `room.isOnline` (เป็นจริงถ้าไม่มีแอร์ หรือมีอย่างน้อยหนึ่งเครื่องออนไลน์) รายละเอียดเป็นหัวข้อเจาะโค้ด

- `RoomController.roomByNumber(number)` หาห้องล่าสุดตามเลข เพราะทุก reload สร้าง object `Room` ใหม่ หน้าจอที่ถือ object เก่าจะเห็นค่าค้าง
- `RoomController.floors` ชั้นที่มีอยู่ (ไม่ซ้ำ เรียงลำดับ), `_compare` เรียงห้องตาม ชั้น → `roomIndex` → เลขห้อง
- `createRoom` / `updateRoom` / `deleteRoom` เรียก Repository แล้วอัปเดตลิสต์ในเครื่อง (ไม่ดึงใหม่ทั้งหมด) `updateRoom` คงค่าที่ Backend ไม่ส่งมา (แอร์ เซนเซอร์) จากห้องเดิม
- `AirConditionerController.sendCommand/rename/remove` — `remove` ตามด้วย `refresh()` เต็มรอบ

#### `schedule_controller.dart` (306 บรรทัด)

เก็บ `_schedules` เป็น field ส่วนตัวและเปิดผ่าน getter ที่คืน `List.unmodifiable` (กันหน้าจอแก้ลิสต์ตรง ๆ) ต่างจาก Controller อื่นที่เปิดฟิลด์สาธารณะ มี `schedulesFor(room, day)` กรอง+เรียง, `createSchedule`/`updateSchedule`/`deleteSchedule`/`deleteAllSchedules` (อัปเดตลิสต์ในเครื่อง), `previewScheduleFile` (ส่งต่อ Repository), `importSchedulePreview` (เสร็จแล้ว `reload()` ทั้งหมด), `overlaps(...)` ตรวจเวลาทับกับคาบเดิมในห้อง/วันเดียวกันโดยข้าม `ignoredId` (ใช้ตอนแก้ไขคาบของตัวเอง) และ `_compare` เรียง วัน → ห้อง → เวลาเริ่ม → ชื่อวิชา

นอกจากตารางเรียน Controller นี้ดูแลข้อมูลอีก 3 ชุด ทำให้หน้าตารางเรียนดูเป็น "วันที่จริง" ได้ ไม่ใช่แค่ "วันในสัปดาห์"

| ข้อมูลใหม่ | getter / เมธอด | ความหมาย |
|---|---|---|
| ภาคเรียนของตาราง | `timetable`, `supportsReplaceAll` | ตารางที่ใช้อยู่เป็นของเทอมไหน และ Backend รองรับ "เปลี่ยนภาคเรียน" ไหม |
| ปฏิทินภาคเรียน | `terms`, `termFor(semester)`, `activeTimetableTerm`, `isOutsideTerm(date)`, `today`, `reloadCalendar()`, `saveAcademicTerm()`, `deleteAcademicTerm()` | วันเปิด–ปิดของแต่ละเทอม และวันนี้ตามเวลาไทยของเซิร์ฟเวอร์ |
| การใช้ห้องนอกตาราง | `bookings`, `bookingsLoading`, `bookingsOn(room, date)`, `loadBookings(from, to, force)`, `createBooking()`, `updateBooking()`, `deleteBooking()` | ประชุม สอบ กิจกรรม คาบชดเชย ที่มีวันที่กำกับ |
| ข้อผิดพลาดแยก | `calendarError` | โหลดปฏิทิน/การใช้ห้องพลาด แต่ตารางเรียนหลักยังใช้ได้ |

ไฟล์ `lib/controllers/schedule_controller.dart` บรรทัด 46–83

```dart:46
  /// วันนี้ตามเวลาไทยจากเซิร์ฟเวอร์ ถ้ายังไม่รู้ใช้วันที่ของเครื่อง
  String get today =>
      _serverToday.isNotEmpty ? _serverToday : isoDateOf(DateTime.now());

  /// ปฏิทินของภาคเรียนหนึ่ง หรือ null
  AcademicTerm? termFor(String? semester) {
    if (semester == null || semester.isEmpty) return null;
    for (final term in _terms) {
      if (term.semester == semester) return term;
    }
    return null;
  }

  /// ภาคเรียนของตารางที่ใช้อยู่ ถ้าตั้งวันเปิด–ปิดไว้
  AcademicTerm? get activeTimetableTerm => termFor(_timetable?.semester);

  /// วันที่นี้ตารางเรียนไม่มีผล เพราะอยู่นอกวันเปิด–ปิดของภาคเรียน
  bool isOutsideTerm(String date) {
    final term = activeTimetableTerm;
    return term != null && !term.contains(date);
  }

  /// การใช้ห้องของห้องหนึ่งในวันที่หนึ่ง
  List<RoomBooking> bookingsOn(String roomNumber, String date) {
    return _bookings
        .where(
          (booking) =>
              booking.roomNumber == roomNumber && booking.occursOn(date),
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// คาบเรียนที่มีผลจริงในวันที่หนึ่ง (นอกภาคเรียน = ไม่มี)
  List<ClassSchedule> classesOn(String roomNumber, String date) {
    if (isOutsideTerm(date)) return const [];
    return schedulesFor(roomNumber, dayOfWeekOfIso(date));
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 47–48 | "วันนี้" ใช้ของเซิร์ฟเวอร์ (เวลาไทย) ก่อน ถ้ายังโหลดไม่เสร็จค่อยใช้ของเครื่อง กันกรณีนาฬิกามือถือเพี้ยนหรือตั้งเขตเวลาอื่น แล้วแอปตัดสินว่า "นอกภาคเรียน" ไม่ตรงกับที่ระบบปิดแอร์ของ Backend ตัดสิน |
| 51–57 | หาเทอมจากชื่อ วนลูปธรรมดา (จำนวนเทอมมีไม่กี่รายการ) |
| 60 | เทอมของ "ตารางที่ใช้อยู่" ถ้าตารางยังไม่รู้ภาคเรียน หรือเทอมนั้นยังไม่ได้ตั้งวัน ได้ `null` |
| 63–66 | นอกภาคเรียน = มีการตั้งวันไว้ **และ** วันที่นั้นไม่อยู่ในช่วง ถ้าไม่ได้ตั้งวันเลย (`term == null`) ถือว่าตารางมีผลทุกวัน ตรงกับกติกาของ Backend |
| 69–77 | การใช้ห้องของห้องหนึ่งในวันหนึ่ง ใช้ `occursOn` จากโมเดล แล้วเรียงตามเวลาเริ่ม |
| 80–83 | **หัวใจของการเปลี่ยนแปลง:** หน้าจอเรียก `classesOn(ห้อง, วันที่)` แทน `schedulesFor(ห้อง, วันในสัปดาห์)` ถ้าวันนั้นอยู่นอกภาคเรียน จะได้รายการว่าง ทำให้ "วันพุธช่วงปิดเทอม" ไม่ขึ้นคาบเรียนเหมือน "วันพุธในเทอม" |

ไฟล์ `lib/controllers/schedule_controller.dart` บรรทัด 109–170

```dart:109
  Future<void> reload() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loaded = await repository.fetchScheduleBundle();
      _schedules
        ..clear()
        ..addAll(loaded.schedules)
        ..sort(_compare);
      _timetable = loaded.timetable;
      _supportsTimetable = loaded.supportsTimetable;
      _hasLoaded = true;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    await reloadCalendar();
  }

  /// ดึงปฏิทินภาคเรียนใหม่ ถ้าพลาดไม่ทำให้ตารางเรียนใช้ไม่ได้
  Future<void> reloadCalendar() async {
    try {
      final calendar = await repository.fetchAcademicCalendar();
      _terms = calendar.terms;
      _serverToday = calendar.today;
      _calendarError = null;
    } catch (error) {
      _calendarError = error.toString();
    }
    notifyListeners();
  }

  /// ดึงการใช้ห้องของช่วงวันที่ (ปกติคือหนึ่งสัปดาห์ที่กำลังดู)
  ///
  /// ช่วงเดิมที่ดึงไว้แล้วไม่ดึงซ้ำ เว้นแต่ [force]
  Future<void> loadBookings({
    required String from,
    required String to,
    bool force = false,
  }) async {
    if (!force && _bookingsFrom == from && _bookingsTo == to) return;
    _bookingsLoading = true;
    notifyListeners();
    try {
      final loaded = await repository.fetchBookings(from: from, to: to);
      _bookings
        ..clear()
        ..addAll(loaded);
      _bookingsFrom = from;
      _bookingsTo = to;
      _calendarError = null;
    } catch (error) {
      _calendarError = error.toString();
    } finally {
      _bookingsLoading = false;
      notifyListeners();
    }
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 115 | ใช้ `fetchScheduleBundle()` ได้ทั้งคาบและภาคเรียนของตารางในคำขอเดียว |
| 120–121 | จำภาคเรียนของตาราง และจำว่า Backend รุ่นนี้รู้จักฟีเจอร์ภาคเรียนไหม |
| 129 | โหลดตารางเสร็จ (สำเร็จหรือพลาด) แล้วค่อยโหลดปฏิทินต่อ |
| 133–143 | ปฏิทินพลาดเก็บไว้ที่ `_calendarError` **แยกจาก** `_errorMessage` ของตาราง หน้าจอจึงยังแสดงตารางเรียนได้ แค่ขึ้นแถบแดงเล็ก ๆ ว่าโหลดการใช้ห้องหรือปฏิทินไม่สำเร็จ |
| 153 | **แคชช่วงล่าสุด:** ช่วงวันที่เดิมไม่ดึงซ้ำ การกดเลือกวันอื่นในสัปดาห์เดียวกันจึงไม่ยิงเน็ต ดึงใหม่เฉพาะตอนข้ามสัปดาห์ หรือสั่ง `force: true` (ดึงจอลง หรือหลังเพิ่ม/แก้/ลบ) |
| 157–162 | แทนที่รายการทั้งชุด และจำช่วงที่ดึงไว้ |

> [!WHY]
> **ทำไมดึงการใช้ห้องทีละสัปดาห์ ไม่ดึงทั้งหมด** การจองสะสมไปเรื่อย ๆ ทุกเทอม ถ้าดึงทั้งหมดทุกครั้งจะช้าลงเรื่อย ๆ หน้าจอแสดงทีละสัปดาห์อยู่แล้ว จึงดึงแค่การจองที่ "ทับ" สัปดาห์นั้น (`GET /bookings?from=อาทิตย์&to=เสาร์`) ซึ่ง Backend กรองด้วยสูตรเดียวกับ `overlapsRange`

หลังเพิ่ม/แก้/ลบการใช้ห้อง (`createBooking`, `updateBooking`, `deleteBooking`) Controller เรียก `_refreshBookings()` ซึ่งดึงช่วงเดิมซ้ำแบบ `force: true` ไม่ได้แก้รายการในเครื่องเอง เพราะการจองแบบทำซ้ำหนึ่งรายการอาจโผล่หลายวัน และ Backend เป็นผู้ตรวจความถูกต้องสุดท้าย ดึงใหม่จึงปลอดภัยกว่าเดา

`saveAcademicTerm(term, {previousSemester})` ถ้าผู้ใช้แก้ชื่อภาคเรียน (เช่น พิมพ์ผิดเป็น `1/2568` แล้วแก้เป็น `1/2569`) Backend บันทึกแบบ upsert ตามชื่อ จึงต้องลบชื่อเดิมทิ้งเอง ไม่งั้นจะเหลือสองเทอม ส่วน `deleteAllSchedules()` ล้าง `_timetable = null` ด้วย เพราะ Backend ล้างภาคเรียนของตารางไปพร้อมกัน

#### `system_settings_controller.dart`, `user_controller.dart`

- `SystemSettingsController` ค่าตั้งระดับระบบจากเซิร์ฟเวอร์ (ต่างจาก `AppSettingsController` ที่เป็นของเครื่องผู้ใช้) เริ่มจาก `SystemSettings.unknown` (`autoOffEnabled: true` ตรงกับค่าเริ่มต้นฝั่ง Backend) `setAutoOffEnabled` ทำ **optimistic update** (อธิบายในเจาะโค้ด)
- `UserController({repository, currentUsername})` เก็บ `users`, `adminCount` (แอดมินที่ยังใช้งานอยู่), `isSelf(user)`, `changeRole`, `setActive`, `createUser`, `deleteUser` และ `_sort` เรียงแอดมินก่อน → ใช้งานอยู่ก่อน → ชื่อ A–Z ใช้ `_reloadInProgress` แทน `_inFlight` (รอบซ้อนถูกข้ามหมด)

### Utils (`lib/utils/`)

#### `alert_preferences.dart` — ค่าตั้งแจ้งเตือน

- `AlertChannels {inApp, push}` สองช่องทางของแจ้งเตือนหนึ่งชนิด (แยกกันเพราะความรำคาญต่างกัน)
- `AlertPreferences` เก็บ `Map<SystemAlertKind, AlertChannels>` และสวิตช์หลัก `enabled` `configurableKinds` คือสามชนิดที่ผู้ใช้ตั้งได้ (**ไม่รวม `unknown`**) ค่าเริ่มต้น `defaults()` เปิดทุกช่อง
- `showsInApp(kind)` **เป็นจริงเสมอ** (ผู้ใช้ปิดรายการในแอปไม่ได้) `pushesToPhone(kind)` = `enabled && channelsFor(kind).push` `typeSelected` ใช้แสดงสวิตช์รายชนิดในหน้าตั้งค่าโดยไม่สนสวิตช์หลัก (เปิดสวิตช์หลักกลับมาแล้วค่าเลือกเดิมยังอยู่)
- `visible(alerts)` / `pushable(alerts)` กรองใบตามสองข้อด้านบน
- `encode()` → JSON `{enabled, <ชื่อ enum>: {inApp, push}}` และ `decode(String?)` ที่ **ทนข้อมูลเสีย** (null/ว่าง/ไม่ใช่ JSON/ไม่ใช่ Map → ค่าเริ่มต้น; ชนิดที่ไม่มีในข้อมูลเก่าได้ค่าเริ่มต้นของมัน; `inApp` ถูกบังคับ `true`; ไม่มี `enabled` ถือว่าเปิด)
- `operator ==` และ `hashCode` เทียบตามเนื้อหา (ใช้ให้ `DashboardController` และ `AppSettingsController` รู้ว่า "ค่าเปลี่ยนจริงไหม" ก่อน notify)
- `freshAlerts(alerts:, seenIds:)` ฟังก์ชันระดับไฟล์: คืนใบที่มี `id` ไม่ว่างและยังไม่อยู่ใน `seenIds` (ใบที่ไม่มี id ถือว่าไม่ใหม่ กันเด้งซ้ำไม่รู้จบ)

#### `number_format.dart` — จัดรูปตัวเลข

- `formatDecimal(value, {decimalPlaces = 2})` คั่นหลักพัน (`1217.25` → `1,217.25`) เขียนเองด้วย `StringBuffer` ไม่ใช้ `intl`
- `EnergyDisplay {value, unit, decimalPlaces}` พร้อม `text`
- `formatEnergy(kWh, {scaleReference})` เลือกหน่วย `Wh` (<1 kWh) / `kWh` (1–<1000) / `MWh` (≥1000) และจำนวนทศนิยมลดลงเมื่อเลขใหญ่ (≥100 → 0 ตำแหน่ง, ≥10 → 1, ≥1 → 2, ไม่ถึง 1 → 3) และ `energyScaleReference(values)` คืนค่ามากสุดของชุด ใช้ให้ทุกจุดบนกราฟ/ตารางใช้หน่วยเดียวกัน (`test/energy_format_test.dart`)

> [!WHY]
> **ทำไมต้องเลื่อนหน่วยอัตโนมัติ และทำไมต้องมี `scaleReference`** ค่าจริงกว้างมาก (ตั้งแต่ชาร์จมือถือ 0.005 kWh ไปจนถึงทั้งอาคารหลักพัน kWh) ถ้าตรึง kWh ค่าน้อยจะถูกปัดเป็น `0.0` ส่วนการให้แต่ละจุดเลือกหน่วยเอง จะทำให้ "900 Wh" ดูใหญ่กว่า "1.2 kWh" ทั้งที่น้อยกว่า การบังคับหน่วยร่วมกันของทั้งชุดจึงกันความเข้าใจผิดในกราฟและตาราง

#### `file_saver.dart` — บันทึกไฟล์ (Excel และ CSV)

- `enum FileSaveStatus {saved, shared, cancelled, failed}` และ `FileSaveResult {status, path, error}` พร้อม `isSuccess`
- `saveExportFile({fileName, bytes, fileExtension = 'xlsx', mimeType = <xlsx>, typeLabel = 'Excel'})`: บน **Android/iOS** เขียนไฟล์ลงโฟลเดอร์ชั่วคราว (`getTemporaryDirectory`) แล้วเปิดเมนูแชร์ (`SharePlus.instance.share`) ให้ผู้ใช้เลือกปลายทางเอง (เก็บลงไฟล์/ไลน์/อีเมล); บน **เดสก์ท็อป** (Windows) เปิดกล่อง Save As (`getSaveLocation`) แล้วเติมนามสกุลถ้าขาด ข้อผิดพลาดทั้งหมดถูกจับเป็น `FileSaveStatus.failed`
- รับนามสกุล ชนิดไฟล์ (MIME) และชื่อกลุ่มไฟล์เป็นพารามิเตอร์ ค่าเริ่มต้นเป็น Excel ทุกตัว หน้าส่งออกพลังงานเรียกแบบไม่ส่งพารามิเตอร์จึงได้ Excel ส่วนหน้าตารางเรียนและหน้านำเข้าตารางเรียกด้วย `fileExtension: 'csv'`, `mimeType: 'text/csv'`, `typeLabel: 'CSV'`
- `sanitizeFileName(value, {fileExtension = 'xlsx'})` แทนอักขระที่ระบบไฟล์ไม่รับ (`\ / : * ? " < > |`) ด้วย `_` และบีบช่องว่าง ชื่อภาษาไทยผ่านได้ ถ้าว่างใช้ `energy-export.<นามสกุล>`

> [!NOTE]
> `acceptedTypeGroups: [...]` ไม่มี `const` นำหน้า เพราะข้างในใช้ตัวแปร (`typeLabel`, `fileExtension`, `mimeType`) ซึ่งไม่ใช่ค่าคงที่ตอนคอมไพล์ ถ้าใส่ `const` จะคอมไพล์ไม่ผ่าน และ CI (`flutter analyze`) จะจับได้ทันที

#### `thai_date.dart` — วันที่ไทย (พ.ศ.)

ฟังก์ชันจัดรูป `formatDisplayDate` (`9 มิ.ย. 2569`), `formatDisplayDateTime`, `formatDayMonth`, `formatWeekdayShort` (ชื่อวันย่อ `จ`/`Mo` ใช้ใต้กราฟรายวัน ดัชนี `date.weekday % 7` เพื่อให้อาทิตย์ = 0), `formatMonthYear`, `formatNumericDate` (`09/06/2569`), `formatIsoDateText`, `displayYear`, `parseNumericDate` และปฏิทินเลือกวัน `showAppDatePicker` / `showAppDateRangePicker` / `AppDatePickerDialog` ที่แอปเขียนเอง (เพราะ `showDatePicker` ของ Flutter แสดงได้แค่ ค.ศ.) มีโหมดแตะปฏิทินหรือพิมพ์เอง ค่าคงที่ `buddhistEraOffset = 543` ไฟล์นี้ import `localized_material.dart` แทน `material.dart` ตรง ๆ เพื่อให้ `Text` ในปฏิทินถูกแปลอัตโนมัติ (รายละเอียดดูเจาะโค้ด)

### Localization และ Theme

#### `localization/app_localizations.dart` (1,212 บรรทัด)

ตัวแปลภาษาที่เขียนเองทั้งหมด **ไม่ใช้ไฟล์ `.arb`/`intl`** โครงสร้าง:

- `class AppLocalizations(locale)` มี `supportedLocales = [Locale('th'), Locale('en')]`, `delegate`, `of(context)` (คืนภาษาไทยถ้าหาไม่เจอ), `maybeOf`, `isThai`, และ `translate(String source)`
- **กุญแจ (key) คือข้อความภาษาอังกฤษในโค้ด** เช่น `Text('Sign In')` → ภาษาไทยได้ `'เข้าสู่ระบบ'`
- `_translateToThai(source)`: (1) ค้นใน `_thaiTranslations` (map ขนาดใหญ่ประมาณ 680 รายการ ตั้งแต่บรรทัด 238) แบบตรงตัว (2) ถ้าไม่เจอลอง **regex** สำหรับข้อความที่มีตัวแปร เช่น `^Room ([A-Z0-9_-]+)$` → `ห้อง $1`, `^(\d+)/6 units$` → `$1/6 เครื่อง`, `^Floor (\d+) · Room ...$`, เวลา AM/PM → `HH:mm น.` (3) ถ้ายังไม่เจอคืนข้อความเดิม
- `_translateToEnglish(source)`: ค้นใน `_englishTranslations` (ประมาณ 70 รายการ บรรทัด 1092 เป็นต้นไป) **กุญแจเป็นข้อความภาษาไทยที่ Backend ส่งมา** เช่น `'Username หรือ Password ไม่ถูกต้อง'` → `'The username or password is incorrect.'` ไว้แปลข้อความผิดพลาดของ Backend เมื่อผู้ใช้เลือก English
- extension `AppLocalizationsBuildContext` ให้ `context.tr('...')` แปลในโค้ดที่ไม่ใช่ `Text`
- `_AppLocalizationsDelegate` ตัว `load` คืน `SynchronousFuture` (โหลดทันทีเพราะเป็น map ในหน่วยความจำ) และ `isSupported` เช็กรหัสภาษา
- ** ข้อความของบอร์ดสายแอร์ 13 รายการ:** ฝั่งไทย 10 รายการอยู่บนสุดของ map ใต้คอมเมนต์ `// บอร์ดสายแอร์ / ยี่ห้อแอร์ (v3.16.0)` เช่น `'Wired'` → `'สายแอร์'`, `'IR remote'` → `'รีโมต IR'`, `'Set by the board'` → `'บอร์ดกำหนดให้'`, `'Board type: IR remote'` → `'ชนิดบอร์ด: รีโมต IR'` และข้อความยาวที่อธิบายว่าสายแอร์ใช้ฟังก์ชันอะไรได้ ฝั่งอังกฤษ 3 รายการแปล error ภาษาไทยของ Backend เช่น `'แอร์แบบสายแอร์ไม่มีพัดลมระดับ Turbo'` → `'Wired air conditioners have no Turbo fan speed.'` (รวม 23 บรรทัดที่เพิ่ม เพราะบางรายการยาวจนต้องขึ้นบรรทัดใหม่)

#### `localization/localized_material.dart` — `Text` ที่แปลให้เอง

```dart:5
export 'app_localizations.dart';
export 'package:flutter/material.dart' hide Text;
```

ไฟล์นี้ re-export ทั้ง Material **ยกเว้น `Text`** แล้วนิยามคลาส `Text` ของตัวเอง (บรรทัด 8) ที่รับ `String` และใน `build` เรียก `localizations?.translate(data!) ?? data!` ก่อนส่งให้ `material.Text` ของจริง มี `Text.rich` ที่เดินแปลทุก `TextSpan` ด้วย `_translateSpan` เมื่อหน้าจอ import `'../localization/localized_material.dart'` แทน `material.dart` ข้อความทั้งหน้าจะถูกแปลตามภาษาอัตโนมัติโดยไม่ต้องใส่ `context.tr()` ทุกที่

> [!WHY]
> **ทำไมเลือกวิธีนี้แทน `AppLocalizations` + ไฟล์ arb ตามคู่มือ Flutter** ข้อดีคือเขียนข้อความอังกฤษตรง ๆ ในโค้ด แล้วแปลจาก map เดียว ไม่ต้องสร้างกุญแจและเรียก `S.of(context).xxx` ทุกบรรทัด เพิ่มภาษาง่าย และรับมือข้อความที่มาจาก Backend ได้ด้วย (map ย้อนกลับ) ข้อเสียที่ต้องรู้คือ กุญแจเป็นข้อความที่ต้อง "สะกดตรงเป๊ะ" ถ้าพิมพ์ผิดหนึ่งตัวอักษรจะไม่แปล (ไม่มีคอมไพเลอร์ช่วยเตือน) ไฟล์ใหญ่ และเทียบกับของมาตรฐานการแปลที่ซับซ้อน (พหูพจน์) ต้องเขียน regex เอง ตัวป้องกันคือ `test/app_localizations_test.dart`

#### `theme/app_theme.dart` — สีและธีม (524 บรรทัด)

- `AppColors` สีแบรนด์คงที่จากโลโก้: เทาถ่าน `#2F3438` (`charcoal`), เขียวใบไม้ `#2EB872` (`leaf`), `primary #0F7D45` (เข้มกว่า `#128C4E` ของโลโก้ เพื่อให้ตัวหนังสือบนพื้นขาวมีคอนทราสต์ ≥ 4.5:1 ตามเกณฑ์อ่านง่าย) ฯลฯ
- `kDisplayFont = 'ChakraPetch'` ชื่อฟอนต์ที่ประกาศใน `pubspec.yaml`
- `enum AppThemeChoice {white, gray, black, green, system}` พร้อม `code`, `label`, `description`, `fromCode` (คืน `null` ถ้ารหัสไม่รู้จัก) `system` แปลว่า "ตามเครื่อง"
- `AppPalette extends ThemeExtension<AppPalette>` ชุดสีที่เปลี่ยนตามธีมซึ่ง `ColorScheme` ของ Material ไม่มีช่องให้ ได้แก่ `bar`/`onBar` (แถบหัวจอ), `barLogoGreen`, `accent`/`accentSoft`, `fill`/`fillSoft` (กราฟ), `warn`/`warnSoft`, `danger`/`dangerSoft`, `info`, `mutedText` และ 4 ชุดคงที่ `_white`, `_gray`, `_black`, `_green` เรียกด้วย `AppPalette.of(context)` ถ้าไม่เจอ (เช่นในเทสต์ที่ไม่ได้ใช้ AppTheme) คืนชุดขาว มี `copyWith` และ `lerp` (ผสมสีเวลาเปลี่ยนธีมแบบเคลื่อนไหว)
- `_ThemeSpec` + `_whiteSpec/_graySpec/_blackSpec/_greenSpec` ค่าสีพื้นฐานของแต่ละธีม
- `AppTheme.forChoice(choice)` ประกอบ `ThemeData` (Material 3, `ColorScheme.fromSeed(seedColor: AppColors.leaf)` แล้ว `copyWith` ทับ) `white` และ `system` ใช้ชุดขาวเหมือนกัน, `AppTheme.light` = ขาว, `AppTheme.dark` = เทา, `previewColors(choice)` ให้สี 4 ช่องสำหรับการ์ดตัวอย่างในหน้าตั้งค่า

| ธีม | `bar` (แถบหัวจอ) | ลักษณะ |
|---|---|---|
| ขาว (white, ค่าเริ่มต้น) | `#FFFFFF` | สว่าง อ่านง่ายในห้องแดดจ้า |
| เทา (gray) | `#23272B` | เทาถ่านของโลโก้ ถนอมสายตา ใช้เป็นโหมดมืดของ "ตามเครื่อง" |
| ดำ (black) | `#0B0D0E` | มืดสนิท สำหรับจอที่เปิดทิ้งกลางคืน |
| เขียว (green) | `#0E5A34` | แถบหัวเขียวเข้ม เนื้อหาสว่าง |
| ตามเครื่อง (system) | — | ขาวเมื่อเครื่องเป็นโหมดสว่าง เทาเมื่อเป็นโหมดมืด |

ใน `main.dart` ธีมที่ผู้ใช้เลือกส่งเข้า `theme:` เสมอ ส่วน `darkTheme:` (เทา) จะถูกใช้เมื่อเลือก "ตามเครื่อง" และเครื่องอยู่ในโหมดมืดเท่านั้น (`themeMode` เป็น `ThemeMode.system` เมื่อเลือก system นอกนั้นตรึง `ThemeMode.light` เพื่อให้ `theme` ที่เลือกถูกใช้เสมอ แม้ธีมนั้นจะเป็นสีมืดอย่างเทา/ดำ)

### `lib/data/mock_data.dart`

`MockData.createRooms()` สร้างห้องเปล่า 21 ห้อง (ชั้น 1–3 ชั้นละ 7 ห้อง) เลขห้อง `16` + ชั้น + ลำดับ 2 หลัก (เช่น `16101`…`16307`) พร้อมชนิดห้อง และกำหนดค่าเริ่มต้น `isOccupied` กับ `isOnline` (ห้อง `16206` ออฟไลน์) `airConditioners` เป็นลิสต์ว่างเสมอ (คอมเมนต์ในโค้ด: อุปกรณ์จริงโหลดจาก MariaDB หลังล็อกอิน) `main.dart` ส่งผลลัพธ์นี้เป็น `rooms` ให้ `AppShell` แล้ว `RoomController.reload()` จะ **แทนที่เนื้อลิสต์ด้วยห้องจริงจาก Backend** หมายความว่า 21 ห้องนี้เป็นเพียง "ที่นั่งชั่วคราว" ก่อนข้อมูลจริงมา (เทสต์ `mock_data_test.dart` ตรวจว่ามี 21 ห้อง 7 ห้องต่อชั้น)

### ไฟล์ Android และ Web

#### `android/app/build.gradle.kts`

- `plugins { id("com.android.application"); id("dev.flutter.flutter-gradle-plugin") }` (Flutter plugin ต้องมาหลัง Android plugin)
- บรรทัดต้นไฟล์อ่าน `android/key.properties` ถ้ามี (`hasReleaseKey`) ถ้าไม่มีจะ `logger.warn(...)` เตือนว่า APK release จะเซ็นด้วย debug key
- `namespace` และ `applicationId` = `th.ac.rmutt.cpe.cpe_air_remote` (รหัสแอปบน Android และโดเมนกลับด้านของมหาวิทยาลัย `ac.th`)
- `compileSdk`, `minSdk`, `targetSdk`, `versionCode`, `versionName` ใช้ค่า `flutter.xxx` ที่ Flutter SDK กำหนด (ค่าตัวเลขจริงขึ้นกับเวอร์ชัน Flutter ที่ติดตั้ง ไม่ได้ระบุในโปรเจกต์) `versionCode`/`versionName` มาจาก `version: 3.16.0+32` ใน `pubspec.yaml`
- `compileOptions` และ `kotlin.compilerOptions` ตั้ง Java/Kotlin เป็น **17**
- `signingConfigs.release` (สร้างเมื่อมี key.properties) อ่าน `keyAlias`, `keyPassword`, `storeFile`, `storePassword` จากไฟล์ และ `buildTypes.release.signingConfig` เลือก release ถ้ามีกุญแจ ไม่งั้นใช้ debug

> [!WARN]
> `key.properties` และไฟล์ `.jks`/`.keystore` ถูกกันออกจาก git ใน `android/.gitignore` ห้าม commit และต้องสำรองไว้เอง ถ้าหายจะอัปเดตแอปทับของเดิมบนเครื่องผู้ใช้ไม่ได้ (Android ต้องการลายเซ็นเดียวกัน) สคริปต์ `create-keystore.ps1` สร้างให้ ส่วนค่ารหัสจริงห้ามใส่ในเอกสารหรือที่สาธารณะ

> [!WHY]
> **ทำไมปล่อยให้ build ผ่านแม้ไม่มี key.properties (แค่เตือน)** เพื่อให้นักพัฒนาคนอื่น build ทดสอบได้ทันทีโดยไม่ต้องมีกุญแจจริง ราคาที่จ่ายคือ APK ที่ได้เซ็นด้วย debug key (ใครก็มี) จึงไม่ควรแจกจ่าย จึงใส่คำเตือนให้เห็นชัดตอน build

#### `android/build.gradle.kts`, `settings.gradle.kts`, `gradle.properties`

- `build.gradle.kts` (ระดับโปรเจกต์) ตั้ง `google()` + `mavenCentral()` และย้ายโฟลเดอร์ build ไปไว้ `../../build` (นอกโฟลเดอร์ android) กับ task `clean`
- `settings.gradle.kts` อ่าน `flutter.sdk` จาก `local.properties` (ไฟล์เฉพาะเครื่อง ไม่ commit) แล้ว `includeBuild` Gradle plugin ของ Flutter และประกาศเวอร์ชัน plugin: `com.android.application` **9.0.1**, `org.jetbrains.kotlin.android` **2.3.20**
- `gradle.properties` ตั้งหน่วยความจำ JVM `-Xmx8G`, `android.useAndroidX=true` และแฟลก `android.newDsl=false`, `android.builtInKotlin=false` (ที่แม่แบบ Flutter ใส่ให้เข้ากับ AGP 9)

#### `AndroidManifest.xml`

```html
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>
```

| สิทธิ์ | ทำไมต้องมี |
|---|---|
| `INTERNET` | ยิง API (ปกติ release ต้องประกาศเอง) |
| `BLUETOOTH_SCAN` + `neverForLocation` | สแกนหา ESP32 บน Android 12 (API 31) ขึ้นไป แฟลก `neverForLocation` ประกาศว่าไม่ใช้ผลสแกนหาพิกัดผู้ใช้ จึงไม่ต้องขอสิทธิ์ตำแหน่งบน Android 12+ |
| `BLUETOOTH_CONNECT` | เชื่อมต่อและคุยกับอุปกรณ์ BLE บน Android 12+ |
| `ACCESS_FINE_LOCATION` `maxSdkVersion="30"` | Android 11 (API 30) ลงไปบังคับให้ขอสิทธิ์ตำแหน่งเพื่อสแกน BLE จึงขอเฉพาะรุ่นเก่าเหล่านี้ (รุ่นใหม่ไม่ขอ ลดสิทธิ์ที่ไม่จำเป็น) |

นอกจากนี้ `android:label="RMUTT Energy"` (ชื่อใต้ไอคอน), `MainActivity` เป็น `exported="true"` พร้อม intent-filter MAIN/LAUNCHER, `launchMode="singleTop"`, `windowSoftInputMode="adjustResize"` (ดันหน้าจอขึ้นเมื่อคีย์บอร์ดเปิด), `configChanges` ที่ให้ Flutter จัดการการหมุนจอ/ภาษา/ขนาดตัวอักษรเองโดยไม่รีสตาร์ท Activity และ `flutterEmbedding = 2`

> [!NOTE]
> **ผู้ใช้ต้องกด "อนุญาต" สิทธิ์ Bluetooth เองตอนใช้งาน** (สำหรับ Android 12+) การประกาศใน Manifest เป็นแค่การ "ขอได้" ส่วนหน้าต่างถามผู้ใช้จริงมาจากไลบรารี BLE ตอนสแกน

#### `web/index.html` และ `web/manifest.json`

เป็นไฟล์ของ **Flutter Web** (`flutter build web`) ไม่ใช่เว็บแอปที่ใช้งานจริง คอมเมนต์ใน `index.html` บอกชัดว่าเว็บแอป HTML/JS ที่เสิร์ฟจริงอยู่ในโฟลเดอร์ `webapp/` `index.html` มี `<base href="$FLUTTER_BASE_HREF">` (Flutter แทนค่าตอน build), เมตาแท็กชื่อแอป และโหลด `flutter_bootstrap.js` แบบ `async` `manifest.json` ระบุ `name: "RMUTT Save Energy"`, `short_name: "Save Energy"`, `display: standalone`, `orientation: portrait-primary`, `theme_color #16834B`, `background_color #F3F8F4` และ `icons: []` (ยังไม่มีไอคอน) ทั้งคู่เป็นของที่ติดมาจากแม่แบบและแก้ชื่อ ตัวแอปจริงที่ใช้งานคือ Android และ Windows

## วันที่ ค่าไฟ และแจ้งเตือน: สรุปรวม

**วันที่ พ.ศ.** ข้อมูลที่เก็บและส่งไป Backend เป็น ค.ศ. เสมอ (`DateTime`, `yyyy-MM-dd`) ไฟล์ `thai_date.dart` แปลง "ตอนแสดงผล" กับ "ตอนรับที่ผู้ใช้พิมพ์" เท่านั้น: `displayYear(date, isThai) = isThai ? date.year + 543 : date.year` ผู้ใช้พิมพ์ปีตั้งแต่ 2400 ขึ้นไปจะถูกมองเป็น พ.ศ. แล้วลบ 543 (ดังนั้นพิมพ์ ค.ศ. ก็ได้)

**ตัวเลข** ไม่ใช้แพ็กเกจ `intl` ในแอปนี้ `formatDecimal` เขียนคั่นหลักพันเอง ค่าไฟรวมที่ต้องแสดงเป็นบาทคือ `AppSettingsController.calculateElectricityCost(kWh)` = kWh × อัตราต่อหน่วย (ค่าเริ่มต้น 4.50 บาท/หน่วย ผู้ใช้ปรับได้ที่หน้าอัตราค่าไฟ ช่วง 0.01–100 เก็บในเครื่อง ไม่ใช่ใน Backend) และอัตรานี้ถูกส่งเป็นพารามิเตอร์ `rate` ใน `EnergyQuery` เมื่อส่งออกรายงาน

**แจ้งเตือน (ภาพรวมทั้งสายพาน)**

1. `DashboardController` ดึง `GET /alerts?limit=30` ทุก 30 วินาที
2. `freshAlerts` หาใบที่ยังไม่เคยเห็น → เรียก `onNewAlerts(fresh)` (หลังรอบแรก)
3. `AppShell._handleNewAlerts` กรองด้วย `AlertPreferences.pushable(fresh)` แล้วเรียก `AlertNotifier.show(...)` (ปัจจุบัน `alertNotifier` เป็น `null` จึงไม่เด้ง)
4. ในแอป `DashboardController.alerts` = `AlertPreferences.visible(...)` แสดงครบทุกใบเสมอ
5. ผู้ใช้กดรับทราบ → `acknowledge(id)` → `POST /alerts/:id/acknowledge`

## การทดสอบ (test/)

**วิธีรัน** (จากโฟลเดอร์รากของโปรเจกต์ Flutter)

```bash
flutter pub get          # ดึงแพ็กเกจครั้งแรก
flutter test             # รันทุกไฟล์ใน test/
flutter test test/thai_date_test.dart            # รันไฟล์เดียว
flutter test --name "พิมพ์ปี พ.ศ."                # รันเฉพาะเคสที่ชื่อตรง
flutter analyze          # ตรวจ lint ตาม analysis_options.yaml
```

รวม **122 เคส** ใน 22 ไฟล์ (นับด้วย `grep` บรรทัดที่ขึ้นต้นด้วย `test(` และ `testWidgets(`) ทุกเทสต์รัน **ออฟไลน์** เพราะฉีด Repository/Store ปลอมแทนของจริง (นี่คือผลตอบแทนของการแยกชั้น)

เทสต์มี 2 แบบ: `test(...)` คือเทสต์ฟังก์ชัน/คลาสธรรมดา (เร็ว ไม่มี UI) และ `testWidgets(...)` คือเทสต์ที่สร้างหน้าจอเสมือนแล้ว `tester.pumpWidget`, `tester.tap`, `find.text(...)`

| ไฟล์ | จำนวนเคสโดยประมาณ | ทดสอบอะไร |
|---|---|---|
| `app_localizations_test.dart` | 2 | ภาษาไทยเป็นค่าเริ่มต้น (`Sign In` → `เข้าสู่ระบบ`, `Room 16203` → `ห้อง 16203`, `3/6 units`) และโหมดอังกฤษแปลข้อความไทยจาก Backend |
| `app_preferences_test.dart` | 23 | ธีม (รหัสอ่านกลับได้ครบ, ผู้ใช้เก่าโหมดมืด → ธีมเทา), `AppTextScale`, `resolvedTextScale` (คูณกับค่าของระบบ มีเพดาน 2.0 ทน NaN), `AlertPreferences` (encode/decode, ข้อมูลเสีย, สวิตช์หลัก, `unknown`), `freshAlerts`, และการจำค่าด้วย `_MemoryStore` รวมถึงว่า "ตั้งค่าเดิมซ้ำไม่ notify" |
| `auto_off_countdown_test.dart` | 8 | `formatCountdown` (`300` → `05:00`, ติดลบ → `00:00`), วิดเจ็ตนับถอยหลังแบบต่าง ๆ, ฟิลด์ปิดอัตโนมัติของ `Room` และ `Room.fromJson` |
| `ble_identity_test.dart` | 2 | identity ของเฟิร์มแวร์ 1.6 (สั้น) เปิดการตั้งค่าครั้งแรกได้ และการรวม identity กับ settings |
| `class_schedule_test.dart` | 2 | `timesOverlap` และ `ClassSchedule.fromJson` |
| `daikin_wired_support_test.dart` | 3 | แอร์ `DAIKIN_WIRED` ที่สร้างด้วยค่าที่รุ่นนี้ไม่มี (Heat, Turbo, สวิง middle, Eco/Quiet/Clean เปิด) ถูกปรับเป็น Cool, High, Auto และปิดฟังก์ชันเสริม แต่ Sleep ยังอยู่; เปลี่ยนเป็นโหมด Dry แล้ว `supportsSleep` เป็นเท็จและ Sleep ถูกปิด; แอร์ IR (`HAIER_AC160`) บอก `brand = Haier`, `controlTypeLabel = 'IR remote'`; `airBrandOf`/`airControlTypeOf` (ตัวพิมพ์เล็กก็ได้); identity BLE ที่มี `controlType: wired` กับ identity เฟิร์มแวร์เก่าที่ไม่มีช่องนี้ (= `ir`) |
| `energy_database_test.dart` | 5 | หน้าฐานข้อมูล: ค่าไฟสดภาษาไทย (812 W → `0.812 kW`), เปลี่ยนรอบอัปเดต, โหมดสรุปซ่อนตัวเลือก, เลือกรายเครื่อง, พรีวิว |
| `energy_format_test.dart` | 10 | `formatEnergy`/`energyScaleReference` (Wh/kWh/MWh, ทศนิยม, หน่วยร่วม) |
| `energy_usage_chart_test.dart` | 14 | `EnergyChartGeometry` 5 เคส (แท่งอยู่กลางช่อง, ค่าสูงสุดบนสุด/ศูนย์ล่างสุด, ทุกค่าเป็นศูนย์ไม่หารศูนย์, จุดเดียวคืนว่าง, แตะตรงไหนของช่องก็ได้และไม่หลุดขอบ), `niceScaleMax` (3.56 → 4, 17.3 → 20, 0.42 → 0.5, 212 → 250, 0 → 1), `axisLabelsFor` 3 เคส (ทุก 6 ชม., 7 วันเป็นชื่อวัน, 30 วันเป็นวันที่ทุก 7 วัน + วันสุดท้าย) และวิดเจ็ต 5 เคส (ข้อมูลไม่พอ, แตะแล้วขึ้นค่า, แตะซ้ำปิด, แตะแท่งอื่นกล่องย้าย, เปลี่ยนช่วงแล้วไม่พัง) |
| `mock_data_test.dart` | 1 | 21 ห้อง ชั้นละ 7 |
| `number_format_test.dart` | 1 | `formatDecimal` (`1217.25` → `1,217.25`, `270.5 * 5.25` → `1,420.13`) |
| `occupancy_status_test.dart` | 2 | `Room.fromJson` ฟิลด์เซนเซอร์ และ identity `OCC32-...` |
| `pzem_status_test.dart` | 5 | `isRunning` มาจาก PZEM ไม่ใช่คำสั่ง IR; แอร์ที่เปิดด้วยรีโมตจริงต้องขึ้นว่าเปิด และร่างคำสั่งต้องเริ่มจาก "เปิด", สั่งปิดแล้วหน้าจอขึ้นปิดทันที, ไม่มี PZEM ให้เชื่อคำสั่ง IR |
| `room_calendar_test.dart` | 11 | ตัวช่วยวันที่ (วันในสัปดาห์/ต้นสัปดาห์ตรง Backend, บวกวันข้ามเดือนข้ามปี), `RoomBooking` (วันเดียว, รายสัปดาห์, รายวัน, JSON ที่ส่ง/อ่าน), `AcademicTerm` (รวมวันเปิดปิด, สถานะ, รูปแบบ `1/2569`), CSV ตารางเรียนนำกลับเข้ามาได้ |
| `saijo_denki_support_test.dart` | 2 | ข้อจำกัดของโปรโตคอล Saijo Denki (อุณหภูมิ 18–29, ไม่มี swing off, ปิดฟังก์ชันเสริม) เทียบกับ Haier |
| `schedule_date_test.dart` | 2 | `scheduleDayIndexForDate`, `scheduleDateForDay` (สัปดาห์เริ่มวันอาทิตย์) จาก `schedule_screen.dart` |
| `schedule_import_test.dart` | 2 | พรีวิวห้องใหม่ → `createMissingRooms`, `withTerm`, ผลนำเข้า |
| `system_settings_test.dart` | 6 | `SystemSettingsController` (optimistic update, ถอยกลับ, กันกดซ้ำ) |
| `thai_date_test.dart` | 4 | วันที่ พ.ศ./ค.ศ. `parseNumericDate`, `formatIsoDateText` |
| `user_management_test.dart` | 6 | `ManagedUser`, `UserController` (เรียงลำดับ, เปลี่ยน role, ระงับ/ลบ, error) |
| `widget_test.dart` | 7 | ทั้งแอปผ่าน `CpeAirRemoteApp` (login → dashboard → เมนูควบคุม), จำชื่อผู้ใช้, สลับภาษา/ธีม, ค่าไฟ, แอดมินเพิ่ม/แก้คาบเรียน, เพิ่มการใช้ห้องให้ห้อง 16302 แล้วตรวจว่าขึ้นในการ์ด, เพิ่ม/ลบห้อง CL503 |
| `wifi_network_candidate_test.dart` | 4 | `WifiNetworkCandidate`, identity ที่บอร์ดส่ง, `toBleJson` ของใบจอง (MQTT host/port/user, `keepPassword`) |

**จุดที่น่าสนใจของเทสต์**

- `widget_test.dart` ประกอบแอปจริงด้วย `CpeAirRemoteApp(authRepository: _FakeAuthRepository(), roomRepository: _MemoryRoomRepository(), ...)` นี่คือเหตุผลที่ constructor ใน `main.dart` รับ Repository แบบ optional ทุกตัว (ดูหัวข้อเจาะโค้ด)
- ฟังก์ชัน `_useTallScreen` ขยายจอเสมือนเป็น 800x1400 เพราะค่าเริ่มต้นของเทสต์ (800x600) เตี้ยกว่าการ์ดล็อกอิน ปุ่มไปอยู่นอกจอ `tap()` เลยไม่โดน
- เทสต์เซ็ต/เคลียร์ "จดจำชื่อผู้ใช้" ยังใช้ `RememberedLogin(password: 'remembered-password')` ได้ เพราะเก็บช่อง `password` ไว้ในโมเดลเพื่อความเข้ากันได้ย้อนหลัง

## เจาะโค้ดทีละบรรทัด

### 1. `lib/main.dart` — ประกอบแอปและสลับหน้า

**ไฟล์ `lib/main.dart` บรรทัด 33–35 และ 85–107**

```dart:33
void main() {
  runApp(const CpeAirRemoteApp());
}
```

```dart:85
  @override
  void initState() {
    super.initState();
    _authController = AuthController(widget.authRepository ?? AuthService());
    _ownsAppSettingsController = widget.appSettingsController == null;
    _appSettingsController =
        widget.appSettingsController ?? AppSettingsController();
    _scheduleRepository = widget.scheduleRepository ?? ScheduleService();
    _roomRepository = widget.roomRepository ?? RoomService();
    _airConditionerRepository =
        widget.airConditionerRepository ?? AirConditionerService();
    ...
    _systemSettingsRepository =
        widget.systemSettingsRepository ?? SystemSettingsService();
    _authController.initialize();
    _appSettingsController.initialize();
  }
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 33–35 | `void main() { runApp(const CpeAirRemoteApp()); }` | จุดเริ่มของโปรแกรม Dart `runApp` ใส่ widget รากเข้าหน้าจอ `const` เพราะ widget นี้ไม่มีค่าที่เปลี่ยนตอนสร้าง (ทุก field เป็น null เมื่อรันจริง) |
| 37–52 | `const CpeAirRemoteApp({this.authRepository, ..., super.key})` | constructor แบบ named parameter ทุกตัวเป็น **optional** (ไม่มี `required`) และชนิดเป็น nullable (`AuthRepository?`) เพราะรันจริงไม่ส่งอะไรมาเลย แต่เทสต์ส่งของปลอมเข้ามา `super.key` ส่ง `key` ต่อให้คลาสแม่ |
| 54–65 | `final AuthRepository? authRepository; ...` | เก็บของที่ส่งเข้ามาไว้ (ชนิดคือ **interface** ไม่ใช่ `AuthService` จึงรับตัวปลอมได้) |
| 71–83 | `late final AuthController _authController; ...` | `late` = "ฉันจะกำหนดค่าทีหลัง (ใน initState) แต่จะไม่ null ตอนใช้" `final` = กำหนดแล้วเปลี่ยนไม่ได้ |
| 88 | `AuthController(widget.authRepository ?? AuthService())` | ถ้ามีตัวส่งเข้ามาใช้ตัวนั้น ไม่งั้นสร้าง `AuthService()` ของจริง `widget` คือตัว `CpeAirRemoteApp` ที่ `State` นี้ผูกอยู่ นี่คือ **dependency injection แบบมือ**: Controller ไม่รู้ว่าได้ของจริงหรือของปลอม |
| 89–91 | `_ownsAppSettingsController = widget.appSettingsController == null;` | จำว่า "เราเป็นคนสร้างเองหรือเปล่า" เพื่อ `dispose()` เฉพาะที่เราสร้าง (ตัวที่เทสต์ส่งมา เจ้าของเทสต์ดูแลเอง) |
| 92–104 | `_scheduleRepository = widget.scheduleRepository ?? ScheduleService();` ... | สร้าง Service ที่เหลือด้วยแพทเทิร์นเดียวกัน ทำครั้งเดียวใน `initState` ดังนั้นทั้งแอปใช้ Service ชุดเดียว (ไม่สร้างใหม่ทุกครั้งที่วาดหน้า) |
| 105–106 | `_authController.initialize(); _appSettingsController.initialize();` | เริ่มกระบวนการโหลดแบบ async (กู้ session และอ่านค่าตั้งจาก secure storage) โดยไม่ `await` เพราะ `initState` เป็น async ไม่ได้ ผลลัพธ์จะมาทาง `notifyListeners()` |

**บรรทัด 118–135 และ 157–182 (build)**

```dart:157
          home: AnimatedBuilder(
            animation: _authController,
            builder: (context, _) {
              return switch (_authController.status) {
                AuthStatus.loading => const AuthLoadingScreen(),
                AuthStatus.signedOut => LoginScreen(controller: _authController),
                AuthStatus.signedIn => AppShell(
                  rooms: MockData.createRooms(),
                  user: _authController.user!,
                  appSettingsController: _appSettingsController,
                  scheduleRepository: _scheduleRepository,
                  ...
                  authController: _authController,
                  onLogout: _authController.logout,
                ),
              };
            },
          ),
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 120–122 | `AnimatedBuilder(animation: _appSettingsController, builder: (context, _) => MaterialApp(...))` | ห่อ `MaterialApp` ทั้งตัว เมื่อผู้ใช้เปลี่ยนภาษา/ธีม/ขนาดตัวอักษร (`notifyListeners()`) แอปทั้งต้นวาดใหม่ด้วยค่าใหม่ทันที `_` คือพารามิเตอร์ที่ไม่ใช้ |
| 125–132 | `locale:`, `supportedLocales:`, `localizationsDelegates:` | ภาษาปัจจุบัน (th/en) และตัวแปลที่ใช้: `AppLocalizations.delegate` ของโปรเจกต์ บวก 3 ตัวมาตรฐานของ Flutter (ข้อความของปุ่ม ปฏิทิน ฯลฯ) |
| 135–136 | `theme: AppTheme.forChoice(...)`, `darkTheme: AppTheme.dark` | ธีมที่เลือกเข้า `theme` เสมอ `darkTheme` (เทา) ใช้เฉพาะ "ตามเครื่อง" ตอนเครื่องมืด |
| 139–152 | `builder: (context, child) {...}` | ครอบ **ทุกหน้า รวม dialog** ด้วย `MediaQuery` ที่ปรับ `textScaler` เป็น `resolvedTextScale(ค่าของระบบ)` (ตัวคูณของระบบ × ตัวคูณของแอป) ถ้า `child == null` คืน `SizedBox.shrink()` (widget ว่าง) |
| 153–156 | `themeMode: ... == AppThemeChoice.system ? ThemeMode.system : ThemeMode.light` | ถ้าเลือก "ตามเครื่อง" ให้ระบบตัดสินสว่าง/มืด นอกนั้นตรึงใช้ `theme` เสมอ |
| 157–158 | `home: AnimatedBuilder(animation: _authController, ...)` | หน้าแรกฟังสถานะล็อกอิน ล็อกอิน/ออกจากระบบแล้วสลับหน้าอัตโนมัติ ไม่ต้องสั่ง `Navigator` เอง |
| 160–180 | `return switch (_authController.status) { ... }` | switch expression บน enum ที่ **ครบทุกค่า** ถ้าเพิ่มสถานะใหม่ใน enum แต่ลืมที่นี่ คอมไพเลอร์ฟ้องทันที |
| 161 | `AuthStatus.loading => const AuthLoadingScreen()` | ระหว่างตรวจ token ที่เก็บไว้ |
| 162 | `AuthStatus.signedOut => LoginScreen(controller: ...)` | ยังไม่ล็อกอิน |
| 163–179 | `AuthStatus.signedIn => AppShell(...)` | `rooms: MockData.createRooms()` ห้องตั้งต้น 21 ห้อง (AppShell เก็บชุดแรกไว้ใน `initState` ไม่ว่า build นี้จะถูกเรียกกี่ครั้ง), `user: _authController.user!` (`!` ปลอดภัยเพราะ signedIn แปลว่ามี user), ส่ง Repository ทุกตัว, `alertNotifier: widget.alertNotifier` (null ในแอปจริง), `onLogout: _authController.logout` ส่ง **ฟังก์ชัน** (ไม่มี `()`) ให้ปุ่มออกจากระบบเรียกเอง |

### 2. `lib/config/api_config.dart` — URL ของ Backend ทั้งไฟล์

**ไฟล์ `lib/config/api_config.dart` บรรทัด 1 และ 10–16**

```dart:1
abstract final class ApiConfig {
```

```dart:10
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://rmutt-energy.tailb292b4.ts.net/api',
  );

  /// true เมื่อชี้ไปเซิร์ฟเวอร์จริง ใช้แสดงผลหรือ debug ได้
  static bool get isProduction => baseUrl.startsWith('https://');
}
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 1 | `abstract final class ApiConfig` | คลาสที่ไม่มีไว้สร้าง object: `abstract` สร้างไม่ได้ `final` สืบทอดไม่ได้ ใช้เป็น "ที่รวมค่าคงที่" (Dart 3) ใช้งานด้วย `ApiConfig.baseUrl` |
| 2–9 | `///` คอมเมนต์ | เอกสารในโค้ด: แอปไม่ต่อ MariaDB ตรง, ค่าเริ่มต้นคือเซิร์ฟเวอร์จริงผ่าน Tailscale Funnel, DuckDNS ใช้ได้เฉพาะในตึก และตัวอย่างคำสั่ง override |
| 10 | `static const baseUrl = String.fromEnvironment(` | `static` = เป็นของคลาส ไม่ใช่ของ object `const` = ค่าคงที่ตอนคอมไพล์ `String.fromEnvironment` อ่านค่าที่ฝังด้วย `--dart-define` ตอน build |
| 11 | `'API_BASE_URL',` | ชื่อตัวแปรที่ค้นหา ต้องสะกดตรงกับธง `--dart-define=API_BASE_URL=...` |
| 12 | `defaultValue: 'https://rmutt-energy.tailb292b4.ts.net/api'` | ถ้าไม่ส่ง `--dart-define` ใช้ URL นี้ ลงท้าย `/api` เพราะ Service ต่อ path เช่น `/rooms` ต่อท้ายตรง ๆ |
| 16 | `static bool get isProduction => baseUrl.startsWith('https://');` | getter (คำนวณทุกครั้งที่เรียก) ตรวจว่าเป็น HTTPS หรือไม่ `=>` คือทางลัดของ `{ return ...; }` |

**ทำไมค่าเริ่มต้นเป็น URL `ts.net`:** `flutter run` เปล่า ๆ หรือ APK ที่ build เฉย ๆ ก็ใช้งานกับเซิร์ฟเวอร์จริงได้ทันที ทุกที่ที่มีเน็ต (Tailscale Funnel เปิดเซิร์ฟเวอร์สู่สาธารณะผ่าน HTTPS) ผู้ที่อยากทดสอบกับ Backend ในเครื่องค่อยใส่ `--dart-define` ทับ ทางเลือกอื่นคือเขียน URL ในโค้ดตรง ๆ (แก้ที ต้อง build ใหม่และกระทบทุกคน) หรืออ่านจากไฟล์ตั้งค่าตอนรัน (ต้องมีที่เก็บไฟล์บนมือถือ ซับซ้อนกว่า) `--dart-define` คือจุดกึ่งกลางที่ไม่ต้องแก้โค้ด

### 3. `lib/models/air_conditioner.dart` — `fromJson` และตัวช่วยแปลงค่า

**ไฟล์ `lib/models/air_conditioner.dart` บรรทัด 119–138**

```dart:119
  factory AirConditioner.fromJson(Map<String, dynamic> json) {
    final state = json['state'] is Map<String, dynamic>
        ? json['state'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AirConditioner(
      id: _int(json['airNumber'], 1),
      name: _string(json['name'], 'Air Conditioner'),
      deviceId: json['deviceId'] as String?,
      roomNumber: json['roomNumber'] as String?,
      bleName: json['bleName'] as String?,
      protocol: _string(json['protocol'], 'HAIER_AC160'),
      provisionStatus: _string(json['provisionStatus'], 'reserved'),
      isOnline: json['isOnline'] == true,
      mqttTopic: json['mqttTopic'] as String?,
      dailyOn: json['dailyOn'] as String?,
      dailyOff: json['dailyOff'] as String?,
      lastSeenAt: DateTime.tryParse(_string(json['lastSeenAt'], '')),
      isOn: state['power'] == true,
      temperature: _int(state['temperature'], 25).clamp(16, 30).toInt(),
      mode: _enumByName(AirMode.values, state['mode'], AirMode.cool),
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 119 | `factory AirConditioner.fromJson(Map<String, dynamic> json)` | โรงงานสร้าง `AirConditioner` จาก JSON ที่ `jsonDecode` ได้ |
| 120–122 | `final state = json['state'] is Map<String, dynamic> ? ... : <String, dynamic>{};` | สถานะที่สั่ง (`power`, `temperature`, ...) ซ้อนอยู่ในคีย์ `state` ถ้ามีและเป็น Map ใช้เลย ไม่งั้นใช้ Map ว่าง จึงอ่าน `state['power']` ได้โดยไม่ error แม้เซิร์ฟเวอร์ไม่ส่ง `state` |
| 124 | `id: _int(json['airNumber'], 1)` | `id` ของแอร์คือ "เลขเครื่องในห้อง" (`airNumber`) ไม่ใช่ id ในฐานข้อมูล ถ้าอ่านไม่ได้ใช้ 1 |
| 125 | `_string(json['name'], 'Air Conditioner')` | ข้อความ ถ้าไม่ใช่ String หรือว่าง ใช้ค่าสำรอง |
| 126–128 | `json['deviceId'] as String?` | `as String?` = "ถ้าเป็น String ให้ใช้ ถ้า null ก็ null" (ถ้าเป็นชนิดอื่นเช่นตัวเลข จะโยน error ต่างจาก `_string`) ฟิลด์ที่ปล่อยเป็น nullable ได้เพราะแอร์ที่ยังไม่ผูกบอร์ดไม่มีค่านี้ |
| 129–130 | `_string(json['protocol'], 'HAIER_AC160')`, `provisionStatus ... 'reserved'` | ค่าสำรองที่ปลอดภัย: ถ้าไม่รู้โปรโตคอลถือเป็น Haier, ถ้าไม่รู้สถานะถือเป็น reserved (ยังไม่ใช่ active จึงสั่งงานไม่ได้) |
| 131 | `isOnline: json['isOnline'] == true` | เทียบกับ `true` ตรง ๆ ดังนั้น null/ข้อความ/ไม่มี → `false` (ไม่เชื่อว่าออนไลน์ถ้าไม่แน่ใจ) |
| 135 | `DateTime.tryParse(_string(json['lastSeenAt'], ''))` | `tryParse` คืน `null` ถ้าแปลงไม่ได้ (ต่างจาก `parse` ที่โยน error) ข้อความว่างจึงให้ `null` |
| 136 | `isOn: state['power'] == true` | สถานะ "สั่งเปิด" |
| 137 | `_int(state['temperature'], 25).clamp(16, 30).toInt()` | อ่านเลข ค่าสำรอง 25 แล้ว `clamp(16, 30)` บีบให้อยู่ในช่วง 16–30 (`clamp` คืน `num` จึง `.toInt()`) กันค่าแปลกจากเซิร์ฟเวอร์ ส่วนช่วงเฉพาะโปรโตคอลถูกบีบอีกรอบใน `normalizeForProtocol()` ที่ constructor |
| 138 | `_enumByName(AirMode.values, state['mode'], AirMode.cool)` | แปลงข้อความ (`"cool"`) เป็น enum ถ้าไม่รู้จักใช้ `cool` |

**ไฟล์เดียวกัน บรรทัด 411–426 (ตัวช่วยแบบ generic)**

```dart:411
T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
  final name = value is String ? value : '';
  for (final item in values) {
    if (item.name == name) return item;
  }
  return fallback;
}

String _string(Object? value, String fallback) {
  return value is String && value.isNotEmpty ? value : fallback;
}

int _int(Object? value, int fallback) {
  final result = value is num ? value.toInt() : int.tryParse('$value');
  return result ?? fallback;
}
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 411 | `T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback)` | **generic**: `T` คือ enum ชนิดใดก็ได้ (`extends Enum`) เขียนครั้งเดียวใช้กับ `AirMode`, `FanSpeed`, `SwingMode` ชื่อขึ้นต้นด้วย `_` แปลว่าใช้ได้เฉพาะในไฟล์นี้ (private) |
| 412 | `final name = value is String ? value : '';` | ถ้าเป็น String ใช้ ไม่งั้นเป็นข้อความว่าง (Dart "promote" ชนิดให้อัตโนมัติหลัง `is`) |
| 413–415 | `for (final item in values) { if (item.name == name) return item; }` | วนหา enum ที่ชื่อตรง `.name` ของ enum คืนชื่อสมาชิกเป็นข้อความ |
| 416 | `return fallback;` | ไม่เจอ → ค่าสำรอง ไม่ crash |
| 420 | `value is String && value.isNotEmpty ? value : fallback` | ต้องเป็น String และไม่ว่างจึงใช้ |
| 424 | `value is num ? value.toInt() : int.tryParse('$value')` | ถ้าเป็นตัวเลขแปลงเป็น int เลย ไม่งั้นลองแปลงจากข้อความ (`'$value'` คือ string interpolation) `tryParse` คืน null ถ้าแปลงไม่ได้ |
| 425 | `return result ?? fallback;` | null → ค่าสำรอง |

### 4. `lib/services/auth_service.dart` — token, จำชื่อผู้ใช้, กู้ session, ล็อกอิน

**ไฟล์ `lib/services/auth_service.dart` บรรทัด 23–35**

```dart:23
class AuthService implements AuthRepository {
  AuthService({
    http.Client? client,
    FlutterSecureStorage? storage,
    String baseUrl = ApiConfig.baseUrl,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage(),
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

  static const _tokenKey = 'rmutt_access_token';
  static const _rememberedUsernameKey = 'rmutt_remembered_username';
  static const _rememberedPasswordKey = 'rmutt_remembered_password';
  static const _timeout = Duration(seconds: 15);
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 23 | `class AuthService implements AuthRepository` | บอกว่าคลาสนี้ทำตามสัญญา `AuthRepository` ครบทุกฟังก์ชัน (ถ้าขาด คอมไพเลอร์ฟ้อง) |
| 24–28 | constructor ที่รับ `client`, `storage`, `baseUrl` ทั้งหมดเป็นตัวเลือก | ของจริงเรียก `AuthService()` เปล่า ๆ เทสต์ส่ง `http.Client` ปลอม (เช่น `MockClient`) และ storage ปลอมเข้ามา |
| 28–30 | `: _client = client ?? http.Client(), ...` | **initializer list** (ส่วนหลัง `:`) กำหนดค่า field `final` ก่อนเข้าตัว constructor `??` = ถ้า null ใช้ของจริง |
| 30 | `baseUrl.replaceFirst(RegExp(r'/$'), '')` | ตัด `/` ท้ายสุดออกหนึ่งตัว (`r'...'` = raw string ไม่ต้อง escape `\`) |
| 32–34 | `static const _tokenKey = ...` | ชื่อคีย์ใน secure storage `static const` = ค่าคงที่ของคลาส ต้นชื่อ `_` = private |
| 35 | `Duration(seconds: 15)` | เวลารอคำตอบสูงสุด เกินแล้วเป็น `TimeoutException` |

**บรรทัด 41–54 (จำชื่อผู้ใช้)**

```dart:47
  Future<RememberedLogin?> loadRememberedLogin() async {
    // ลบรหัสผ่านที่รุ่นเก่าเคยเก็บไว้ทิ้งทุกครั้ง
    await _storage.delete(key: _rememberedPasswordKey);
    final username =
        (await _storage.read(key: _rememberedUsernameKey))?.trim() ?? '';
    if (username.isEmpty) return null;
    return RememberedLogin(username: username, password: '');
  }
```

| บรรทัด | ความหมาย |
|---|---|
| 47 | คืน `Future<RememberedLogin?>` (อาจเป็น null ถ้าไม่เคยจำ) |
| 49 | **ลบรหัสผ่านเก่าทิ้งทุกครั้ง** เพื่อกวาดรหัสที่แอปรุ่นก่อนเคยเก็บ ผู้ใช้ที่อัปเดตแอปจึงไม่มีรหัสผ่านค้างในเครื่อง |
| 50–51 | อ่านชื่อผู้ใช้ `(await ...)?.trim() ?? ''` อ่านค่า → ถ้าไม่ null ตัดช่องว่าง → ถ้า null ใช้ข้อความว่าง (วงเล็บล้อม `await` จำเป็น เพื่อให้ `?.` ทำงานกับผลลัพธ์) |
| 52–53 | ว่าง → `null` ไม่งั้นคืนโมเดลที่ `password: ''` เสมอ |

**บรรทัด 76–112 (กู้ session และล็อกอิน)**

```dart:77
  Future<AuthUser?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final data = await _get('/auth/me', token: token);
      return AuthUser.fromJson(_map(data['user']));
    } on ApiException {
      await _storage.delete(key: _tokenKey);
      return null;
    }
  }
```

```dart:105
    final token = data['token'] as String? ?? '';
    if (token.isEmpty) {
      throw const ApiException('The server did not return an access token.');
    }

    await _storage.write(key: _tokenKey, value: token);
    return AuthUser.fromJson(_map(data['user']));
```

| บรรทัด | ความหมาย |
|---|---|
| 78–81 | ไม่มี token → ไม่ล็อกอิน (`null`) ไม่ต้องถามเซิร์ฟเวอร์ |
| 84 | มี token → ถาม `GET /auth/me` เพื่อ **ให้เซิร์ฟเวอร์ยืนยันว่ายังใช้ได้** (ไม่เชื่อ token ที่เก็บไว้ลอย ๆ เพราะอาจหมดอายุหรือถูกเพิกถอน) |
| 85 | `AuthUser.fromJson(_map(data['user']))` `_map` ตรวจให้แน่ใจว่าเป็น Map ก่อนแปลง |
| 86–88 | `on ApiException` ดักเฉพาะชนิดนี้: ล้มเหลว → ลบ token เสีย → `null` (ตามที่เตือนไว้: รวมกรณีเน็ตหลุดด้วย) |
| 105 | `data['token'] as String? ?? ''` ได้ token จากคำตอบ ถ้าไม่ใช่ String หรือไม่มี → ข้อความว่าง |
| 106–108 | token ว่างถือเป็นผิดปกติ โยน `ApiException` (`const` เพราะข้อความคงที่) |
| 110 | **เขียน token ลง secure storage** นี่คือจุดเดียวที่ token ถูกบันทึก ทุก Service อื่นแค่อ่านคีย์เดียวกันนี้ |
| 111 | คืนข้อมูลผู้ใช้ให้ `AuthController` เก็บใน state |

### 5. คู่ Repository + Service: `room_repository.dart` กับ `room_service.dart`

**ไฟล์ `lib/services/room_repository.dart` บรรทัด 1–11 (สัญญา)**

```dart:1
import '../models/room.dart';

abstract interface class RoomRepository {
  Future<List<Room>> fetchRooms();

  Future<Room> createRoom(Room room);

  Future<Room> updateRoom(Room room);

  Future<void> deleteRoom(String roomNumber);
}
```

**ไฟล์ `lib/services/room_service.dart` บรรทัด 28–39 และ 70–101 (ตัวจริง)**

```dart:28
  @override
  Future<List<Room>> fetchRooms() async {
    final data = await _request('GET', '/rooms');
    final rooms = data['rooms'];
    if (rooms is! List) {
      throw const ApiException('The server returned invalid room data.');
    }
    return rooms
        .whereType<Map<String, dynamic>>()
        .map(Room.fromJson)
        .toList();
  }
```

```dart:80
        final request = http.Request(method, Uri.parse('$_baseUrl$path'))
          ..headers.addAll({
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          });
        if (body != null) {
          request.body = jsonEncode(body);
        }
        final streamedResponse = await _client.send(request).timeout(_timeout);
        final response = await http.Response.fromStream(streamedResponse);
        return _decode(response);
      } on TimeoutException {
        throw const ApiException('The server took too long to respond.');
      } on ApiException {
        rethrow;
      } catch (_) {
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| repo 3 | `abstract interface class RoomRepository` | สัญญา: มีแต่หัวฟังก์ชัน ไม่มีเนื้อ (`;` ท้ายบรรทัด) สร้าง object จากมันตรง ๆ ไม่ได้ |
| repo 4–10 | `Future<List<Room>> fetchRooms(); ...` | สิ่งที่ Controller ขอได้ ดึงทั้งหมด สร้าง แก้ ลบ ผลเป็น `Future` เพราะต้องรอเครือข่าย ไม่ได้บอกเลยว่าใช้ HTTP |
| svc 28–29 | `@override Future<List<Room>> fetchRooms() async` | `@override` = "ฉันทำตามฟังก์ชันของสัญญา" ถ้าชื่อไม่ตรง จะฟ้อง |
| svc 30 | `await _request('GET', '/rooms')` | ยิง `GET {baseUrl}/rooms` ได้ Map ที่ถอด JSON แล้ว |
| svc 31–34 | `final rooms = data['rooms']; if (rooms is! List) throw ...` | ตรวจ **ก่อนใช้** ว่าเป็น List `is!` = "ไม่ใช่ชนิดนี้" ถ้าเซิร์ฟเวอร์ตอบรูปทรงผิด จะได้ข้อความอ่านรู้เรื่องแทน crash |
| svc 35–38 | `rooms.whereType<Map<String,dynamic>>().map(Room.fromJson).toList()` | `whereType` กรองเอาเฉพาะสมาชิกที่เป็น Map (ข้ามของแปลกปลอม) → `map(Room.fromJson)` แปลงทีละตัว (ส่งฟังก์ชัน `Room.fromJson` เป็นค่าได้เลย ไม่ต้องเขียน `(m) => Room.fromJson(m)`) → `toList()` เพราะ `map` คืน lazy iterable |
| svc 80–85 | `http.Request(method, Uri.parse(...))..headers.addAll({...})` | สร้างคำขอแล้วใช้ cascade `..` เติมหัว: `Accept` (ขอ JSON), `Content-Type` (ส่ง JSON), `Authorization: Bearer $token` (ยืนยันตัวตน) |
| svc 86–88 | `if (body != null) request.body = jsonEncode(body);` | GET/DELETE ไม่มี body |
| svc 89 | `await _client.send(request).timeout(_timeout)` | ส่งคำขอและรอไม่เกิน 15 วินาที `send` คืน stream ของคำตอบ |
| svc 90 | `await http.Response.fromStream(streamedResponse)` | อ่าน stream ทั้งหมดเป็น `Response` ที่มี `statusCode`/`body` |
| svc 92–95 | `on TimeoutException { throw const ApiException(...) }` | แปลงเป็นข้อความของแอปเอง |
| svc 94–95 | `on ApiException { rethrow; }` | `_decode` โยน `ApiException` (เช่น 401, 404) ซึ่งต้อง **ไม่** ถูก `catch (_)` ข้างล่างกลืนไปเป็น "เชื่อมต่อไม่ได้" จึงต้อง `rethrow` ก่อน ลำดับของ `on/catch` สำคัญ |

### 6. Controller: `air_conditioner_controller.dart` และ `system_settings_controller.dart`

**ไฟล์ `lib/controllers/air_conditioner_controller.dart` บรรทัด 23–46**

```dart:23
  Future<void> initialize() async {
    await refresh();
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => refresh(silent: true),
    );
  }

  /// การกดปุ่มรีเฟรชจะได้ข้อมูลชุดใหม่เสมอ ถ้ามีรอบอัตโนมัติค้างอยู่จะรอให้จบ
  /// ก่อนแล้วค่อยดึงซ้ำ ส่วนรอบอัตโนมัติที่ชนกันเองจะข้ามไปเพื่อไม่ให้ซ้อนกัน
  Future<void> refresh({bool silent = false}) async {
    final inFlight = _inFlight;
    if (inFlight != null) {
      if (silent) return;
      await inFlight;
    }
    final task = _runRefresh(silent);
    _inFlight = task;
    try {
      await task;
    } finally {
      if (identical(_inFlight, task)) _inFlight = null;
    }
  }
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 24 | `await refresh();` | โหลดครั้งแรก (แบบไม่เงียบ → ขึ้นหมุนติ้ว) |
| 25–28 | `_refreshTimer ??= Timer.periodic(10 วินาที, (_) => refresh(silent: true))` | `??=` สร้าง Timer เฉพาะเมื่อยังไม่มี กัน `initialize()` ถูกเรียกซ้ำแล้วได้ Timer ซ้อน callback ทิ้งผลด้วย `(_) =>` และรอบอัตโนมัติเป็น `silent` |
| 33 | `Future<void> refresh({bool silent = false})` | named parameter ที่มีค่าเริ่มต้น เรียก `refresh()` (ผู้ใช้กด) หรือ `refresh(silent: true)` (Timer) |
| 34 | `final inFlight = _inFlight;` | งานที่กำลังวิ่งอยู่ (เก็บไว้ในตัวแปรท้องถิ่นเพราะ `_inFlight` เปลี่ยนค่าได้ระหว่าง `await`) |
| 35–38 | `if (inFlight != null) { if (silent) return; await inFlight; }` | **มีงานค้าง:** ถ้าเป็นรอบอัตโนมัติ ข้ามทิ้ง ไม่ต้องซ้อน ถ้าผู้ใช้กดเอง รอให้งานเก่าจบก่อน แล้วค่อยดึงใหม่ เพื่อให้ได้ข้อมูลสดล่าสุดจริง |
| 39–40 | `final task = _runRefresh(silent); _inFlight = task;` | เริ่มงานใหม่และจำไว้ (ยังไม่ `await`) |
| 41–46 | `try { await task; } finally { if (identical(_inFlight, task)) _inFlight = null; }` | รอให้จบ แล้วเคลียร์ธงใน `finally` (ทำเสมอแม้ error) `identical` เช็กว่าเป็น object เดียวกัน (ถ้ามีงานใหม่มาแทนแล้ว ไม่ไปลบของใหม่) |

**บรรทัด 48–69 (`_runRefresh`)**

```dart:48
  Future<void> _runRefresh(bool silent) async {
    if (!silent) isLoading = true;
    errorMessage = null;
    if (!silent) notifyListeners();
    try {
      final devices = await repository.fetchAll();
      for (final room in rooms) {
        room.airConditioners
          ..clear()
          ..addAll(
            devices.where((air) => air.roomNumber == room.number),
          );
        room.isOnline = room.airConditioners.isEmpty
            || room.airConditioners.any((air) => air.isOnline);
      }
    } catch (error) {
      errorMessage = error.toString().replaceFirst('ApiException: ', '');
    } finally {
      if (!silent) isLoading = false;
      notifyListeners();
    }
  }
```

| บรรทัด | ความหมาย |
|---|---|
| 49–51 | เริ่มรอบ: ถ้าไม่เงียบ เปิดสถานะโหลดแล้ว notify ให้หน้าจอขึ้นตัวหมุน ล้าง error เดิม |
| 53 | `repository.fetchAll()` เรียกผ่าน **ชนิด Repository** ไม่รู้ว่าเป็น HTTP หรือของปลอม |
| 54–59 | วนทุกห้อง ล้างลิสต์แอร์เก่าแล้วเติมแอร์ที่ `roomNumber` ตรงกับห้อง (`..clear()..addAll(...)` เป็น cascade บนลิสต์เดียวกัน ไม่สร้างลิสต์ใหม่ เพื่อให้หน้าจอที่อ้างลิสต์นี้อยู่เห็นค่าใหม่) |
| 60–61 | ห้องถือว่าออนไลน์ถ้า "ไม่มีแอร์" หรือ "มีอย่างน้อยหนึ่งเครื่องออนไลน์" (ห้องที่ยังไม่มีอุปกรณ์ไม่ควรขึ้นว่าออฟไลน์) |
| 63–64 | ล้มเหลว → เก็บข้อความ โดยตัดคำนำหน้า `ApiException: ` ที่ `toString()` ของ Exception บางชนิดใส่มา (ของเราเองคืน `message` เปล่าอยู่แล้ว) **ไม่โยนต่อ** เพราะ Timer เรียกโดยไม่มีใครดัก |
| 65–68 | `finally`: ปิดสถานะโหลดและ `notifyListeners()` ทุกกรณี (สำเร็จ/ล้ม/เงียบ) ให้หน้าจอวาดค่าล่าสุด |

**ไฟล์ `lib/controllers/system_settings_controller.dart` บรรทัด 47–67 (optimistic update)**

```dart:47
  Future<bool> setAutoOffEnabled(bool enabled) async {
    if (isSaving) return false;

    final previous = settings;
    settings = SystemSettings(autoOffEnabled: enabled);
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      settings = await repository.setAutoOffEnabled(enabled);
      return true;
    } catch (error) {
      settings = previous;
      errorMessage = _readable(error);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
```

| บรรทัด | ความหมาย |
|---|---|
| 48 | กำลังบันทึกอยู่ → ปฏิเสธคำสั่งใหม่ (กดรัวไม่ยิงซ้อน) คืน `false` |
| 50 | `previous` จำค่าเดิมไว้เผื่อถอยกลับ |
| 51 | **เปลี่ยน state ทันทีก่อนได้คำตอบ** สวิตช์บนจอขยับตอนกดเลย (optimistic update) |
| 52–54 | ตั้งธงกำลังบันทึก ล้าง error แล้ว notify |
| 57–58 | ส่งไป Backend (`PATCH /settings/auto-off`) แล้ว **ใช้ค่าที่เซิร์ฟเวอร์ยืนยันกลับมา** ทับของที่เดาไว้ คืน `true` |
| 59–62 | ล้มเหลว → **ถอยกลับ** เป็นค่าเดิม เก็บข้อความ คืน `false` ให้ผู้เรียกแสดง SnackBar |
| 63–66 | `finally` ปลดธงและ notify เสมอ ทั้งสองทางหน้าจอได้รับการอัปเดต |

> [!WHY]
> **ทำไมใช้ optimistic update กับสวิตช์นี้** ถ้ารอเซิร์ฟเวอร์ตอบก่อนแล้วค่อยขยับสวิตช์ ผู้ใช้จะรู้สึกว่าหน่วงทุกครั้งที่กด (เน็ตช้าเป็นวินาที) การขยับทันทีแล้วถอยกลับเมื่อพลาดให้ความรู้สึกไว และยังปลอดภัยเพราะมีการถอยกลับกับข้อความผิดพลาดเสมอ ข้อเสียคือผู้ใช้อาจเห็นค่าเปลี่ยนแล้วเด้งกลับ ถ้าเซิร์ฟเวอร์ปฏิเสธ (ซึ่งเป็นเรื่องที่ควรเห็นอยู่แล้ว)

### 7. `lib/utils/thai_date.dart` — ปี พ.ศ. และการอ่านวันที่

**ไฟล์ `lib/utils/thai_date.dart` บรรทัด 27–45 และ 78–95**

```dart:27
/// ผลต่างระหว่าง พ.ศ. กับ ค.ศ.
const buddhistEraOffset = 543;

String _two(int value) => value.toString().padLeft(2, '0');

/// ปีตามภาษา: ไทย = พ.ศ. อังกฤษ = ค.ศ.
int displayYear(DateTime date, bool isThai) =>
    isThai ? date.year + buddhistEraOffset : date.year;

/// เช่น `9 มิ.ย. 2569` / `9 Jun 2026`
String formatDisplayDate(DateTime date, bool isThai) {
  final months = isThai ? _thaiMonthsShort : _englishMonthsShort;
  return '${date.day} ${months[date.month - 1]} ${displayYear(date, isThai)}';
}
```

```dart:78
/// อ่านวันที่ที่ผู้ใช้พิมพ์ `วว/ดด/ปปปป` (ใช้ / - หรือ . คั่นก็ได้)
///
/// ปีตั้งแต่ 2400 ขึ้นไปถือเป็น พ.ศ. แล้วลบ 543 ให้ คนพิมพ์ ค.ศ. ก็ยังใช้ได้
/// คืน null ถ้ารูปแบบผิดหรือไม่มีวันนั้นจริง (เช่น 31/02)
DateTime? parseNumericDate(String text) {
  final match = RegExp(
    r'^\s*(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})\s*$',
  ).firstMatch(text);
  if (match == null) return null;
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  var year = int.parse(match[3]!);
  if (year >= 2400) year -= buddhistEraOffset;
  if (month < 1 || month > 12 || day < 1) return null;
  final date = DateTime(year, month, day);
  if (date.month != month || date.day != day) return null;
  return date;
}
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 28 | `const buddhistEraOffset = 543;` | พ.ศ. = ค.ศ. + 543 (ค.ศ. 2026 = พ.ศ. 2569) |
| 30 | `String _two(int value) => value.toString().padLeft(2, '0');` | เติมศูนย์ให้ครบ 2 หลัก (`9` → `09`) |
| 33–34 | `displayYear(...) => isThai ? date.year + 543 : date.year` | เลือกปีตามภาษา เก็บ `DateTime` เป็น ค.ศ. ตลอด |
| 37–40 | `formatDisplayDate` | เลือกรายชื่อเดือนย่อไทย/อังกฤษ แล้วประกอบ `วัน เดือน ปี` ใช้ `date.month - 1` เพราะเดือนใน `DateTime` เริ่มที่ 1 แต่ลิสต์เริ่มที่ 0 |
| 82 | `DateTime? parseNumericDate(String text)` | คืน `null` ได้ (ชนิดมี `?`) = อ่านไม่ได้ |
| 83–85 | `RegExp(r'^\s*(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})\s*$')` | นิพจน์ปรกติ: ช่องว่างหัวท้ายได้, วัน 1–2 หลัก, ตัวคั่น `/` `.` หรือ `-`, เดือน 1–2 หลัก, ปี 4 หลัก วงเล็บ `( )` คือกลุ่มที่เก็บไว้ (match[1], [2], [3]) |
| 86 | `if (match == null) return null;` | รูปแบบไม่ตรง |
| 87–89 | `int.parse(match[1]!)` | แปลงข้อความเป็นเลข `!` เพราะรู้ว่ากลุ่มนั้นต้องมีเมื่อ regex ผ่าน |
| 90 | `if (year >= 2400) year -= buddhistEraOffset;` | ปี ≥ 2400 ถือเป็น พ.ศ. แล้วลบ 543 (ปี ค.ศ. ยังไม่ถึง 2400 ในอีกร้อยปี) พิมพ์ได้ทั้งสองแบบ |
| 91 | `if (month < 1 || month > 12 || day < 1) return null;` | กรองค่าออกนอกช่วงก่อน |
| 92–94 | `final date = DateTime(year, month, day); if (date.month != month || date.day != day) return null;` | **เทคนิคตรวจวันที่ไม่มีจริง:** `DateTime(2569-543, 2, 31)` ไม่ error แต่ "ล้น" ไปเป็น 3 มีนาคม พอเทียบเดือน/วันกับที่ตั้งใจแล้วไม่ตรง แปลว่าวันนั้นไม่มีจริง คืน `null` (เทสต์ `31/02/2569` → `isNull`) |

### 8. เทสต์หนึ่งเคส: `test/system_settings_test.dart` (ถอยกลับเมื่อเซิร์ฟเวอร์ปฏิเสธ)

**ไฟล์ `test/system_settings_test.dart` บรรทัด 44–54 และตัวปลอมบรรทัด 83–112**

```dart:44
    test('เซิร์ฟเวอร์ปฏิเสธแล้วสวิตช์ต้องเด้งกลับ ไม่ใช่ค้างผิด', () async {
      final repository = _MemoryRepository(failOnWrite: true);
      final controller = SystemSettingsController(repository: repository);
      await controller.initialize();
      expect(controller.autoOffEnabled, isTrue);

      expect(await controller.setAutoOffEnabled(false), isFalse);

      expect(controller.autoOffEnabled, isTrue);
      expect(controller.errorMessage, isNotNull);
    });
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 44 | `test('ชื่อเคส', () async { ... })` | นิยามหนึ่งเคส ชื่อบอกพฤติกรรมที่คาดหวัง เป็น `async` เพราะรอ Future |
| 45 | `_MemoryRepository(failOnWrite: true)` | Repository ปลอมที่ **ตั้งใจให้การเขียนล้ม** (คลาสนี้ `implements SystemSettingsRepository` และเก็บค่าไว้ในหน่วยความจำ บรรทัด 83–112) |
| 46 | `SystemSettingsController(repository: repository)` | ฉีดของปลอมเข้า Controller ตัวจริง นี่คือผลประโยชน์ของชั้น Repository |
| 47–48 | `await controller.initialize(); expect(controller.autoOffEnabled, isTrue);` | โหลดค่าเริ่มต้น (ค่าเริ่มต้นเปิดอยู่) แล้วยืนยันก่อนทำการทดสอบจริง |
| 50 | `expect(await controller.setAutoOffEnabled(false), isFalse);` | สั่งปิด ผลต้องเป็น `false` (ล้มเหลว) `expect(ค่าจริง, ตัวตรวจ)` |
| 52 | `expect(controller.autoOffEnabled, isTrue);` | **สาระของเคส:** แม้ตอนกดสวิตช์ขยับเป็นปิดไปชั่วคราว พอเซิร์ฟเวอร์ปฏิเสธต้องกลับเป็นเปิด |
| 53 | `expect(controller.errorMessage, isNotNull);` | และต้องมีข้อความผิดพลาดให้ผู้ใช้เห็น |
| 100/107 | `throw Exception('ApiException: ...')` ในตัวปลอม | ตัวปลอมโยน `Exception` ที่ข้อความขึ้นต้น `ApiException:` เพื่อทดสอบว่า `_readable` ตัดคำนำหน้าได้ |

### 9. เทสต์บอร์ดสายแอร์: `test/daikin_wired_support_test.dart`

ไฟล์ 83 บรรทัด 3 เคส ต่างจากเทสต์ในหัวข้อก่อนตรงที่ **ไม่ต้องมีของปลอมเลย** เพราะสิ่งที่ทดสอบคือกติกาในโมเดลล้วน ๆ (getter และ `normalizeForProtocol()`) ไม่ได้แตะ HTTP หรือที่เก็บข้อมูล จึงสร้าง object แล้วตรวจค่าได้ทันที

**ไฟล์ `test/daikin_wired_support_test.dart` บรรทัด 6–30** (เคสแรก: สร้างแอร์ด้วยค่าที่รุ่นนี้ทำไม่ได้)

```dart:6
  test('Daikin wired board keeps only wall-remote functions', () {
    final air = AirConditioner(
      id: 1,
      name: 'Daikin',
      protocol: 'DAIKIN_WIRED',
      temperature: 16,
      mode: AirMode.heat,
      fanSpeed: FanSpeed.turbo,
      verticalSwing: SwingMode.middle,
      horizontalSwing: true,
      eco: true,
      turbo: true,
      sleep: true,
      quiet: true,
      clean: true,
    );

    expect(air.isWired, isTrue);
    expect(air.brand, 'Daikin');
    expect(air.controlTypeLabel, 'Wired');
    expect(air.minimumTemperature, 16);
    expect(air.maximumTemperature, 30);
    expect(air.mode, AirMode.cool);
    expect(air.fanSpeed, FanSpeed.high);
    expect(air.verticalSwing, SwingMode.auto);
```

| บรรทัด | อธิบาย |
|---|---|
| 6 | `test('ชื่อเคส', () { ... })` ไม่มี `async` เพราะไม่มีอะไรต้องรอ ทุกอย่างเป็นการคำนวณในหน่วยความจำ |
| 7–21 | สร้างแอร์ `DAIKIN_WIRED` โดย **ตั้งใจใส่ค่าที่ผิดเกือบทุกช่อง**: โหมด Heat (สายแอร์ไม่มี), พัดลม Turbo (ไม่มี), สวิง `middle` (มีแค่ auto/off), เปิด Eco/Turbo/Quiet/Clean (ไม่มีทั้งหมด) และ Sleep (มีจริง) จำลองสถานการณ์ "ข้อมูลเก่าค้างจากตอนที่เครื่องนี้ยังเป็นบอร์ด IR" |
| 23–25 | ตัวตนถูกต้อง: เป็นสายแอร์ ยี่ห้อ Daikin และกุญแจข้อความ `'Wired'` (เทียบกับกุญแจภาษาอังกฤษ ไม่ใช่คำแปล เพราะเทสต์นี้ไม่มี `BuildContext` ให้แปล) |
| 26–27 | ช่วงอุณหภูมิ 16–30 เหมือน IR ทั่วไป (ไม่ใช่ 18–29 แบบ Saijo) |
| 28–30 | **หัวใจของเคส:** ไม่มีใครเรียก `normalizeForProtocol()` ในเทสต์ แต่ค่าถูกปรับแล้ว (Heat → Cool, Turbo → High, middle → auto) พิสูจน์ว่า constructor เรียกให้เอง (`air_conditioner.dart` บรรทัด 116) |

บรรทัด 31–42 ตรวจต่อว่า `horizontalSwing/eco/turbo/quiet/clean` ถูกปิด แต่ `sleep` ยังเป็น `true` (บรรทัด 36: ฟังก์ชันที่รุ่นนี้มีจริงต้องไม่ถูกปิดทิ้งไปด้วย) และรายการ `supported...` ตรงตามตารางความสามารถ จากนั้นเป็นส่วนที่ทดสอบ "กติกาที่ขึ้นกับโหมด"

**ไฟล์ `test/daikin_wired_support_test.dart` บรรทัด 44–47**

```dart:44
    air.mode = AirMode.dry;
    expect(air.supportsSleep, isFalse);
    air.normalizeForProtocol();
    expect(air.sleep, isFalse);
```

| บรรทัด | อธิบาย |
|---|---|
| 44 | จำลองผู้ใช้กดเลือกโหมด Dry ในรีโมตเต็ม |
| 45 | `supportsSleep` เป็น getter จึงคำนวณใหม่ทันทีจาก `mode` ปัจจุบัน ไม่ต้องเรียกอะไรเพิ่ม (นี่คือเหตุผลที่สวิตช์ Sleep หายจากจอทันทีที่เลือก Dry) |
| 46–47 | แต่ **ค่า** `sleep` ยังเป็น `true` จนกว่าจะเรียก `normalizeForProtocol()` นี่คือเหตุผลที่ `FullRemoteSheet` ต้องเรียกฟังก์ชันนี้ทุกครั้งที่สายแอร์เปลี่ยนโหมด ถ้าไม่เรียก ร่างคำสั่งจะส่ง `sleep: true` ในโหมด Dry ไปให้ Backend |

เคสที่สองตรวจฝั่ง IR (`HAIER_AC160` → `brand = 'Haier'`, `controlTypeLabel = 'IR remote'`, `supportsEco = true`) และฟังก์ชันนอกคลาสโดยตรง เช่น `airControlTypeOf('daikin_wired')` ต้องได้ `'wired'` (ตัวพิมพ์เล็กก็ต้องผ่าน) เคสที่สามตรวจ identity ของ BLE ทั้งแบบที่บอร์ดบอก `controlType: 'wired'` และแบบเฟิร์มแวร์เก่า

**ไฟล์ `test/daikin_wired_support_test.dart` บรรทัด 74–81** (identity จากเฟิร์มแวร์รุ่นเก่า)

```dart:74
    final legacy = BleDeviceIdentity.fromJson(const {
      'deviceId': 'ESP32-705F1971FE68',
      'bleName': 'RMUTT-AC-705F1971FE68',
      'firmwareVersion': '2.4.1',
      'configured': false,
    });
    expect(legacy.isWired, isFalse);
    expect(legacy.controlType, 'ir');
```

| บรรทัด | อธิบาย |
|---|---|
| 74 | `const { ... }` แผนที่ค่าคงที่ จำลอง JSON ที่บอร์ดส่งผ่าน BLE |
| 77 | เฟิร์มแวร์ `2.4.1` เป็นรุ่นก่อนมีบอร์ดสายแอร์ จึง **ไม่มี** `controlType` และ `brand` ในข้อมูล |
| 80–81 | ต้องได้ `ir` จากค่าสำรองใน `fromJson` ถ้าเคสนี้พัง แปลว่าบอร์ด IR ทุกตัวที่ยังไม่อัปเดตเฟิร์มแวร์จะถูกมองผิดชนิด และหน้าตั้งค่าบลูทูธจะล็อกยี่ห้อผิด |

> [!WHY]
> **ทำไมต้องเขียนเคส "รุ่นเก่า" แยก** ในอาคารจะมีบอร์ดหลายรุ่นปนกันเสมอ เพราะอัปเดตเฟิร์มแวร์ไม่พร้อมกัน (ดูหน้าเฟิร์มแวร์ในบทเว็บแอป ที่แสดงว่าบอร์ดไหนยังเก่า) ความเข้ากันได้ย้อนหลังจึงเป็นพฤติกรรมที่ต้องรับประกัน ไม่ใช่ผลพลอยได้ ถ้าวันหนึ่งมีคนแก้ `fromJson` ให้ `controlType` เป็นช่องบังคับ เทสต์นี้จะพังทันทีก่อนแอปถึงมือผู้ใช้

## หลักการเขียนโค้ดที่ใช้ในส่วนนี้

1. **แยกชั้น (Layered architecture)** model → repository → service → controller → screen ใช้ตลอด `lib/` ดูแผนภาพข้างต้น ทำไม: ชั้นล่างเปลี่ยนได้โดยชั้นบนไม่รู้ตัว และทดสอบแต่ละชั้นได้ลำพัง
2. **Dependency Injection แบบมือ (constructor injection)** `CpeAirRemoteApp` และ Service ทุกตัวรับ dependency ผ่าน constructor แบบ optional (`widget.x ?? XService()`) ใช้ใน `main.dart`, `*_service.dart` ทำไม: เทสต์ใส่ของปลอมได้ ไม่ต้องมีเฟรมเวิร์ก DI
3. **โปรแกรมต่อกับสัญญา ไม่ใช่ตัวจริง (program to an interface)** Controller ถือ `RoomRepository` ไม่ใช่ `RoomService` ใช้ `abstract interface class` ทำไม: เปลี่ยนตัวจริงได้โดยไม่แก้ Controller
4. **Observer pattern ด้วย `ChangeNotifier`** state เปลี่ยน → `notifyListeners()` → `AnimatedBuilder` วาดใหม่ ใช้ใน `controllers/*` และ `main.dart` ทำไม: เบา มากับ Flutter UI ไม่ต้องรู้ว่าข้อมูลมาจากไหน
5. **Defensive parsing (ไม่เชื่อข้อมูลภายนอก)** ทุก `fromJson` ใช้ `as T? ?? ค่าสำรอง`, `whereType`, `tryParse`, `_enumByName` ทำไม: Backend/แอปเปลี่ยนไม่พร้อมกัน ข้อมูลเสียเป็นเรื่องปกติ แอปต้องไม่ล้ม
6. **Fail-safe defaults** ค่าที่ไม่รู้จักถอยไปทางปลอดภัย เช่น `provisionStatus` = `reserved` (สั่งไม่ได้), `isOnline` ที่ไม่ใช่ `true` = ออฟไลน์, `AlertPreferences.decode` เสีย → ค่าเริ่มต้น (เปิดทุกอย่าง) ทำไม: ผิดแล้วต้องไม่เสี่ยงสั่งงานอุปกรณ์จริง/ไม่พลาดแจ้งเตือนสำคัญ
7. **Polling พร้อมกันซ้อน (single-flight)** `_inFlight` + `silent` ใน Controller ที่มี Timer ทำไม: ไม่ยิงคำขอซ้อนเมื่อเน็ตช้า แต่การกดเองยังได้ข้อมูลสด
8. **Optimistic update + rollback** `SystemSettingsController.setAutoOffEnabled` และการตั้งค่าในเครื่องที่เปลี่ยนก่อนบันทึก ทำไม: UI ไวและไม่พังเมื่อบันทึกล้มเหลว
9. **Pure function** `utils/*` (`formatEnergy`, `formatDecimal`, `parseNumericDate`, `freshAlerts`, `AlertPreferences.decode`) ไม่มีผลข้างเคียง ผลลัพธ์ขึ้นกับ input อย่างเดียว ทำไม: ทดสอบง่ายที่สุด (ดู `energy_format_test.dart`)
10. **เก็บข้อมูลเป็น ค.ศ. แสดงผลเป็น พ.ศ.** ที่ `thai_date.dart` ทำไม: ข้อมูลที่ส่งไป Backend และเรียงลำดับต้องเป็นสากล การแปลงเป็นเรื่องของชั้นแสดงผลเท่านั้น
11. **ลดข้อมูลลับในเครื่อง (least privilege / data minimization)** เลิกเก็บรหัสผ่านและลบของเก่าทุกครั้ง (`loadRememberedLogin`), ใช้ token เป็นตัวแทน, สิทธิ์ตำแหน่ง Android ขอเฉพาะรุ่นที่จำเป็น (`maxSdkVersion="30"`) ทำไม: ถ้าเครื่องหาย ข้อมูลที่หลุดต้องน้อยที่สุด
12. **Graceful degradation ของค่าตั้ง** `AppSettingsController.initialize` อ่านทีละค่าใน `try/catch` แยกกัน ทำไม: ค่าหนึ่งเสียต้องไม่ทำให้ค่าอื่นหายหรือแอปเปิดไม่ขึ้น

## คำถามที่อาจารย์อาจถาม

> [!ASK]
> **ถาม: ทำไมแอปไม่ต่อฐานข้อมูลหรือ MQTT ตรง แต่ผ่าน Backend?**
> ตอบ: ความปลอดภัยและการควบคุมสิทธิ์ ถ้าแอปต่อ MariaDB ตรง รหัสฐานข้อมูลต้องอยู่ในแอปที่ทุกคนถอดได้ และแก้กฎธุรกิจต้องอัปเดตทุกเครื่อง ผ่าน Backend แล้ว Backend ตรวจ token สิทธิ์ admin/staff และตรวจข้อมูลก่อนเขียน ส่วนที่ไม่ผ่าน Backend มีอย่างเดียวคือ BLE ตั้งค่าบอร์ดครั้งแรก เพราะบอร์ดยังไม่มี Wi-Fi จึงยังไม่ต่อเน็ต

> [!ASK]
> **ถาม: จัดการ state ด้วยอะไร ทำไมไม่ใช้ Provider/Riverpod/BLoC?**
> ตอบ: ใช้ `ChangeNotifier` ที่มากับ Flutter คู่กับ `AnimatedBuilder` (ดู `pubspec.yaml` ไม่มีแพ็กเกจจัดการ state เพิ่ม) state ของระบบเรียบง่าย คือ โหลด เก็บ แจ้งให้วาดใหม่ ข้อเสียคือต้องส่ง Controller ลงไปทาง constructor เองและ dispose เอง ถ้าแอปโตขึ้นมากอาจย้ายไป Riverpod ได้โดยไม่แตะ Repository/Service

> [!ASK]
> **ถาม: ทำไมต้องมี Repository (abstract) ทั้งที่มี Service อยู่แล้ว?**
> ตอบ: เพื่อเทสต์และเปลี่ยนตัวจริงได้ Controller ผูกกับสัญญา ในเทสต์เราส่ง `_MemoryRoomRepository` ที่คืนข้อมูลตายตัว ทำให้เทสต์ทั้งแอป (`widget_test.dart`) รันออฟไลน์ ถ้าไม่แยก ทุกเทสต์ต้องมีเซิร์ฟเวอร์จริง

> [!ASK]
> **ถาม: token เก็บที่ไหน ปลอดภัยแค่ไหน? แล้วรหัสผ่านล่ะ?**
> ตอบ: เก็บใน `flutter_secure_storage` (คีย์ `rmutt_access_token`) ซึ่งเข้ารหัสโดยใช้ Keystore ของ Android รหัสผ่านแอป **ไม่เก็บเลย** (เก็บแค่ชื่อผู้ใช้เมื่อติ๊กจดจำ) รุ่นเก่าเคยเก็บรหัสผ่าน ตอนนี้โค้ดลบของเก่าทิ้งทุกครั้งที่เปิดหน้าล็อกอิน ถ้ามือถือหาย token ยกเลิกได้จากเซิร์ฟเวอร์ แต่รหัสผ่านที่คนมักใช้ซ้ำหลายที่ไม่หลุดไปด้วย

> [!ASK]
> **ถาม: ถ้า token หมดอายุระหว่างใช้งาน แอปทำอย่างไร?**
> ตอบ: ตอบตามจริง: ไม่มีตัวดักกลางที่ออกจากระบบให้อัตโนมัติ Service จะโยน `ApiException` สถานะ 401 และหน้าจอแสดงข้อความ จนกว่าผู้ใช้จะออกจากระบบหรือเปิดแอปใหม่ ตอนเปิดใหม่ `restoreSession` เรียก `/auth/me` ถ้าไม่ผ่านจะลบ token แล้วไปหน้าล็อกอิน จุดปรับปรุงคือทำ `ApiClient` กลางที่จับ 401 แล้วเรียก `AuthController.logout()` (และข้อควรรู้: ถ้าเปิดแอปตอนไม่มีเน็ต token ก็ถูกลบด้วย เพราะ `restoreSession` จับ `ApiException` ทุกชนิด)

> [!ASK]
> **ถาม: ทำไม URL ค่าเริ่มต้นเป็น `ts.net` และเปลี่ยนได้อย่างไร?**
> ตอบ: เป็น Tailscale Funnel ที่เปิดเซิร์ฟเวอร์ในตึกให้เข้าได้จากอินเทอร์เน็ตด้วย HTTPS จริง มือถือใช้ได้ทุกที่โดยไม่ต้องต่อ VPN ส่วน DuckDNS ชี้ไป IP ภายในมหาวิทยาลัย ใช้ได้เฉพาะในตึก เปลี่ยน URL ได้ด้วย `--dart-define=API_BASE_URL=...` ตอน `flutter run` หรือ `flutter build apk` (`build-apk.ps1` ส่งให้) ค่าถูกฝังตอนคอมไพล์ผ่าน `String.fromEnvironment`

> [!ASK]
> **ถาม: แอปรู้ได้อย่างไรว่าแอร์ "ทำงานอยู่จริง" ทั้งที่สั่งด้วยรีโมตอินฟราเรดไม่มีสัญญาณตอบกลับ?**
> ตอบ: แยกสองค่า `isOn` คือคำสั่งที่สั่งล่าสุด ส่วน `isRunning` (`acRunning` ใน JSON) มาจากเซนเซอร์วัดไฟ PZEM-004T ที่ ESP32 อ่านจริงแล้วส่งขึ้นระบบ ห้องนับแอร์ที่ทำงานและกำลังไฟรวมจาก `isRunning` (`Room.runningAirCount`, `totalPower`) ไม่ใช่ `isOn` เทสต์ `pzem_status_test.dart` ยืนยัน

> [!ASK]
> **ถาม: แอปรู้ได้อย่างไรว่าแอร์เครื่องไหนเป็นบอร์ดสายแอร์ Daikin และทำไมปุ่มบางปุ่มหายไป?**
> **ตอบ:** ดูจาก `protocol` ถ้าเป็น `DAIKIN_WIRED` ฟังก์ชัน `airControlTypeOf` คืน `'wired'` ทำให้ `isWired` เป็นจริง โมเดลจึงจำกัดโหมดเหลือ Cool/Dry/Fan พัดลม 4 ระดับไม่มี Turbo สวิงแค่ส่าย/หยุด และฟังก์ชันเสริมเหลือ Sleep (ใช้ไม่ได้ในโหมด Dry) เพราะบอร์ดนี้สั่งแอร์แทนรีโมตติดผนังของ Daikin ซึ่งมีปุ่มแค่นั้น หน้าจอถาม getter รายตัว เช่น `supportsEco` แล้วซ่อนปุ่มที่แอร์ทำไม่ได้ ส่วน `normalizeForProtocol()` ปรับร่างคำสั่งก่อนส่ง เพื่อไม่ให้ Backend ตอบ 400 ตอนตั้งค่าบอร์ด BLE บอร์ดเองก็บอก `controlType: "wired"` มาใน identity แอปจึงล็อกยี่ห้อให้

> [!ASK]
> **ถาม: ทดสอบอย่างไรว่าบอร์ดสายแอร์ไม่ถูกส่งคำสั่งที่ทำไม่ได้ และบอร์ดเฟิร์มแวร์เก่ายังใช้ได้?**
> **ตอบ:** `test/daikin_wired_support_test.dart` มี 3 เคส เคสแรกสร้างแอร์ `DAIKIN_WIRED` ด้วยค่าที่ผิดเกือบทั้งหมด (Heat, Turbo, สวิง middle, Eco เปิด) แล้วตรวจว่าโมเดลปรับเป็น Cool, High, Auto และปิด Eco ให้เองโดยไม่ต้องเรียกอะไร เพราะ constructor เรียก `normalizeForProtocol()` จากนั้นสลับเป็นโหมด Dry เพื่อตรวจว่า Sleep ถูกปิด เคสสองตรวจว่าแอร์ IR ยังมีฟังก์ชันครบ เคสสามอ่าน identity BLE ทั้งแบบที่มี `controlType: "wired"` และแบบเฟิร์มแวร์ 2.4.1 ที่ไม่มีช่องนี้ ซึ่งต้องได้ `ir` ทั้งหมดรันออฟไลน์ ไม่ต้องมีบอร์ดจริง

> [!ASK]
> **ถาม: ทำไม Backend ส่ง `controlType` มาแล้ว แต่แอปยังคำนวณเองจาก `protocol`?**
> **ตอบ:** เพราะค่า `controlType` ของ Backend ก็คำนวณจาก `protocol` อยู่แล้ว ถ้าแอปเก็บสองค่าแยกกันจะมีโอกาสขัดกันเอง (เช่น `HAIER_AC160` แต่ `wired`) การมีแหล่งความจริงเดียวคือ `protocol` ทำให้ไม่ต้องคิดว่าจะเชื่อค่าไหน และวิดเจ็ตที่รู้แค่ข้อความ `protocol` (เช่น `AirControlBadge`) ก็เรียก `airControlTypeOf` ได้เลย

> [!ASK]
> **ถาม: แอปดึงข้อมูลบ่อยแค่ไหน และทำไมไม่ใช้ WebSocket?**
> ตอบ: ห้องและแอร์ทุก 10 วินาที, สรุปพลังงานกับแจ้งเตือนทุก 30 วินาที, ค่าไฟสดผู้ใช้เลือกได้ 2/5/10/30/60 วินาที (ค่าเริ่มต้น 5) ใช้ polling เพราะง่าย ผ่าน HTTPS/Funnel ตรง ๆ และข้อมูลไม่ได้เปลี่ยนรายวินาที มีตัวกันคำขอซ้อน (`_inFlight`) และรอบเงียบ (`silent`) ไม่ให้หน้าจอกระพริบ

> [!ASK]
> **ถาม: ระบบแปลภาษาทำงานอย่างไร ทำไมไม่ใช้ไฟล์ arb?**
> ตอบ: เขียนข้อความอังกฤษในโค้ดแล้วแปลจาก map ใน `app_localizations.dart` (ไทย ~680 รายการ + regex สำหรับข้อความที่มีเลข) และ `localized_material.dart` แทนที่ `Text` ให้แปลอัตโนมัติ ภาษาอังกฤษมี map ย้อนกลับไว้แปลข้อความผิดพลาดภาษาไทยที่ Backend ส่งมา ข้อดี: เขียนเร็ว ไม่ต้องตั้งกุญแจ ข้อเสีย: กุญแจต้องสะกดเป๊ะ ไม่มีตัวช่วยตรวจตอนคอมไพล์ จึงมีเทสต์ `app_localizations_test.dart` คุม

> [!ASK]
> **ถาม: แอปรองรับวันที่แบบ พ.ศ. อย่างไร ข้อมูลเก็บเป็นปีอะไร?**
> ตอบ: เก็บและส่ง Backend เป็น ค.ศ. เสมอ แปลงเป็น พ.ศ. (+543) ตอนแสดงผลใน `thai_date.dart` ภาษาอังกฤษแสดง ค.ศ. ปฏิทินเลือกวันเขียนเองเพราะ `showDatePicker` ของ Flutter แสดงได้แค่ ค.ศ. และตอนผู้ใช้พิมพ์วันที่ ปี ≥ 2400 ถือเป็น พ.ศ.

> [!ASK]
> **ถาม: ทำไม APK ของคุณต้องมีสิทธิ์ Bluetooth/ตำแหน่ง? และถ้าไม่มี key.properties จะเกิดอะไร?**
> ตอบ: ใช้ BLE ตั้งค่า ESP32 ครั้งแรก Android 12+ ใช้ `BLUETOOTH_SCAN` (ประกาศ `neverForLocation` จึงไม่ต้องขอตำแหน่ง) และ `BLUETOOTH_CONNECT` ส่วน `ACCESS_FINE_LOCATION` ขอเฉพาะ Android 11 ลงไป (`maxSdkVersion="30"`) ที่ระบบบังคับ ถ้าไม่มี `android/key.properties` build จะผ่านแต่เซ็น release ด้วย debug key และเตือนในคอนโซล ห้ามแจกและอัปเดตทับแอปที่เซ็นด้วยกุญแจจริงไม่ได้

> [!ASK]
> **ถาม: การแจ้งเตือนบนมือถือทำงานจริงหรือยัง?**
> ตอบ: ตามโค้ดตอนนี้ **ยัง** ครึ่งทาง ตัวตรวจใบแจ้งเตือนใหม่ ค่าตั้งรายชนิด และสัญญา `AlertNotifier` พร้อมแล้ว แต่ไม่มีตัวที่ implement จริง (มีแค่ `NoopAlertNotifier`) และ `main()` ไม่ส่ง `alertNotifier` เข้าไป ที่ทำงานจริงคือรายการแจ้งเตือนในแอป การจะเด้งบนเครื่องต้องเพิ่มปลั๊กอินแจ้งเตือนและคลาสที่ implement `AlertNotifier`

## สรุปและเช็กลิสต์ความเข้าใจ

ถ้าตอบข้อเหล่านี้ได้โดยไม่ต้องเปิดโค้ด แปลว่าเข้าใจบทนี้แล้ว

- [ ] วาดแผนภาพ 5 ชั้น (Model, Repository, Service, Controller, Screen) และบอกได้ว่าชั้นไหนรู้จัก HTTP
- [ ] อธิบายได้ว่าทำไม Controller ถือ `Repository` (interface) ไม่ถือ `Service` และยกตัวอย่างเทสต์ที่ได้ประโยชน์
- [ ] เล่าเส้นทางข้อมูล "ห้อง" จาก `GET /rooms` จนถึงหน้าจอได้ทุกไฟล์
- [ ] อธิบายได้ว่า `main.dart` สลับ loading/login/AppShell อย่างไรและ `AnimatedBuilder` สองชั้นทำหน้าที่อะไร
- [ ] บอกได้ว่า `ApiConfig.baseUrl` มาจากไหน ค่าเริ่มต้นคืออะไร ทำไม และ override อย่างไร
- [ ] อธิบายขั้นตอน login, จดจำชื่อผู้ใช้ (ไม่เก็บรหัสผ่าน), restore session, logout, ลืมรหัสผ่าน 3 ขั้น และจุดอ่อนเรื่อง 401/ออฟไลน์
- [ ] บอกที่เก็บข้อมูลของแอป (`flutter_secure_storage`) และคีย์สำคัญ รวมถึงสิ่งที่ "ไม่มี" ใน pubspec
- [ ] อธิบายความหมายของ `?`, `??`, `?.`, `!`, `??=`, `late final`, `factory`, `implements`, `abstract interface class`, `..` ได้พร้อมตัวอย่างจากโปรเจกต์
- [ ] อธิบาย `fromJson` ของ `AirConditioner` ได้ รวมถึงเหตุผลของค่าสำรองและ `_enumByName`
- [ ] บอกได้ว่า `airBrandOf`/`airControlTypeOf` อนุมานยี่ห้อและวิธีควบคุมจาก `protocol` อย่างไร และสายแอร์ Daikin (`DAIKIN_WIRED`) ทำอะไรได้/ไม่ได้เทียบกับ IR และ Saijo Denki
- [ ] อธิบายได้ว่าทำไมต้องมี getter รายฟังก์ชัน (`supportsEco`, `supportsSleep` ฯลฯ) แทน `supportsAdditionalFunctions` ตัวเดียว และทำไม `supportsSleep` เปลี่ยนตามโหมด
- [ ] เล่าได้ว่า `daikin_wired_support_test.dart` ตรวจอะไร 3 เคส และทำไมเคส identity ของเฟิร์มแวร์ 2.4.1 (ไม่มี `controlType`) สำคัญ
- [ ] บอกรอบ polling ของแต่ละ Controller และหลักการ `_inFlight`/`silent`
- [ ] อธิบาย optimistic update ของ `SystemSettingsController` พร้อมทางถอยกลับ
- [ ] อธิบาย `AlertPreferences` (สวิตช์หลัก, รายชนิด, `unknown`, `freshAlerts` ไม่เด้งรอบแรก) และสถานะจริงของการแจ้งเตือนบนเครื่อง
- [ ] อธิบายระบบแปลภาษา (`translate`, regex, map ย้อนกลับ, `localized_material.dart`) และข้อดี/ข้อเสีย
- [ ] อธิบายวันที่ พ.ศ. (+543, เก็บ ค.ศ., `parseNumericDate` ตรวจ 31/02) และการเลือกหน่วยพลังงาน (`formatEnergy`, `scaleReference`)
- [ ] อธิบายธีม 4 แบบ + ตามเครื่อง และบทบาทของ `AppPalette`
- [ ] บอก `applicationId`, สิทธิ์ BLE/ตำแหน่งและเหตุผล, การเซ็น release ด้วย `key.properties` (โดยไม่เปิดเผยรหัส)
- [ ] อธิบายขั้นตอน BLE provisioning ระดับแพ็กเก็ต (UUID, หั่น 150 ไบต์, ACK 40 วินาที)
- [ ] รันเทสต์ได้ (`flutter test`) และอธิบายได้ว่าเทสต์ออฟไลน์เพราะฉีดของปลอม
