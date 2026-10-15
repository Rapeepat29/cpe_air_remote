# แอป Flutter ตอนที่ 2: หน้าจอหลักและวิดเจ็ต

บทนี้พาเดินดู "หน้าตา" ของแอปมือถือ RMUTT Save Energy ตั้งแต่หน้าเข้าสู่ระบบ ไปจนถึงหน้าควบคุมแอร์ทีละเครื่อง
เราจะเริ่มจากความรู้พื้นฐานของ Flutter ที่ต้องใช้ (Widget, State, Navigator, Form, Timer ฯลฯ) โดยยกตัวอย่างจากไฟล์จริงในโปรเจกต์
จากนั้นไล่ดูทีละหน้าจอว่า ผู้ใช้เห็นอะไร หน้าจออ่านข้อมูลจาก controller ตัวไหน และเมื่อกดปุ่มแล้วเกิดอะไรขึ้น
อ่านจบแล้วจะอธิบายได้ว่า การกดปุ่ม "เปิดเครื่อง" ในแอปเดินทางไปถึงแอร์ได้อย่างไร ทำไมหน้าจอดึงข้อมูลใหม่ทุก 10 วินาที
ทำไมนาฬิกานับถอยหลังปิดแอร์เดินเองบนมือถือ และกราฟพลังงานถูกวาดขึ้นมาอย่างไร

## ภาพรวม

แอป Flutter เป็น "หน้าบ้าน" ของระบบ ผู้ใช้ไม่ได้คุยกับ ESP32 หรือ MQTT โดยตรง ทุกอย่างผ่าน REST API (การเรียก HTTP ไปยัง Backend) ทั้งหมด

```text
ผู้ใช้กดปุ่ม
   │
   ▼
Screen / Widget  (บทนี้)
   │  เรียกเมธอด
   ▼
Controller (ChangeNotifier)   ← อธิบายในบท controllers
   │  เรียก
   ▼
Service / Repository  → HTTP → Backend Node.js → MQTT (Mosquitto) → ESP32 → IR หรือสายแอร์ → แอร์
                                    │
                                    └→ MariaDB (สถานะ, พลังงานจาก PZEM-004T, เซนเซอร์ LD2410)
```

ลำดับการแสดงผลของแอปเริ่มที่ `lib/main.dart` ซึ่งดูสถานะของ `AuthController` แล้วเลือกหน้าแรกให้

ไฟล์: lib/main.dart

```dart
home: AnimatedBuilder(
  animation: _authController,
  builder: (context, _) {
    return switch (_authController.status) {
      AuthStatus.loading => const AuthLoadingScreen(),
      AuthStatus.signedOut => LoginScreen(controller: _authController),
      AuthStatus.signedIn => AppShell(
```

1. **บรรทัด 1–3** — `AnimatedBuilder` ฟังการเปลี่ยนแปลงของ `_authController` ทุกครั้งที่ controller เรียก `notifyListeners()` ส่วนนี้จะ build ใหม่
2. **บรรทัด 4–7** — ใช้ `switch` เลือกหน้า: กำลังเช็ก session → `AuthLoadingScreen`, ยังไม่เข้าระบบ → `LoginScreen`, เข้าระบบแล้ว → `AppShell`

> [!WHY] ทำไมไม่ใช้ Navigator.push ไปหน้า Home หลังล็อกอิน
> เพราะ "เข้าระบบแล้วหรือยัง" เป็นสถานะของทั้งแอป ไม่ใช่การเปิดหน้าใหม่ ถ้าใช้ push ผู้ใช้จะกดย้อนกลับไปหน้าล็อกอินได้
> และตอน logout ต้องคอยล้าง stack เอง การให้ `home:` เปลี่ยนตามสถานะทำให้หน้าล็อกอินหายไปทันทีเมื่อเข้าระบบสำเร็จ
> และกลับมาเองทันทีเมื่อ logout หรือเปลี่ยนรหัสผ่าน

> [!NOTE] ทำไมในโค้ดมีแต่ข้อความภาษาอังกฤษ
> ทุกไฟล์ในบทนี้ import `localization/localized_material.dart` แทน `package:flutter/material.dart`
> ไฟล์นั้นซ่อน `Text` ตัวจริงของ Flutter แล้วสร้าง `Text` ตัวใหม่ที่แปลข้อความให้อัตโนมัติ
> ส่วน `context.tr('...')` คือฟังก์ชันแปลที่เรียกเองได้ การแปลใช้พจนานุกรมและ RegExp เช่น `'Floor 3'` → `'ชั้น 3'`
> ดังนั้นโค้ดเขียนเป็นอังกฤษ แต่จอแสดงภาษาไทยได้

## โครงสร้างไฟล์

| ไฟล์ | หน้าที่ |
|---|---|
| `lib/screens/auth/auth_loading_screen.dart` | หน้ารอ ตอนแอปกำลังตรวจว่า token เดิมยังใช้ได้ไหม (โลโก้ + วงหมุน) |
| `lib/screens/auth/login_screen.dart` | หน้าเข้าสู่ระบบ: ฟอร์ม username/password, จำชื่อผู้ใช้, ลิงก์ลืมรหัสผ่าน, แผ่นติดต่อแอดมิน (`_AdminContactSheet`) |
| `lib/screens/auth/forgot_password_screen.dart` | ลืมรหัสผ่าน 3 ขั้น: ขอ OTP → ยืนยัน OTP → ตั้งรหัสใหม่ พร้อมแถบความคืบหน้า `_ResetProgress` |
| `lib/widgets/auth/auth_background.dart` | พื้นหลังไล่สี + ลายเรขาคณิต (`_EnergyBackgroundPainter`), ปุ่มย้อนกลับ, และโลโก้ชื่อแอป `EnergyBrand` |
| `lib/widgets/auth/auth_text_field.dart` | ช่องกรอกข้อความหน้าตาเดียวกันทุกช่องของหน้า auth และแปลข้อความ error ของ validator |
| `lib/screens/app_shell.dart` | "โครง" หลังล็อกอิน: สร้าง controller ทั้งหมด, แถบเมนูล่าง 5 แท็บ, เปิดหน้าห้อง |
| `lib/screens/home_screen.dart` | แท็บหน้าหลัก: พลังงานรวม ค่าไฟโดยประมาณ และรายการแจ้งเตือนของระบบ |
| `lib/screens/analytics_screen.dart` | แท็บสถิติ: ยอดรวม กราฟ เปอร์เซ็นต์เปลี่ยนแปลง และการใช้ไฟรายห้อง แยกตามชั้น |
| `lib/screens/rooms_screen.dart` | แท็บควบคุม: รายการห้องแยกตามชั้น สถานะคน/ออนไลน์ และนับถอยหลังปิดแอร์ |
| `lib/screens/room_control_screen.dart` | หน้าห้องหนึ่งห้อง: สรุปห้อง, การ์ดแอร์ทุกเครื่อง, ปุ่มเพิ่มเซนเซอร์/ESP32 (แอดมิน) |
| `lib/screens/schedule_screen.dart` | แท็บตารางเรียน: เลื่อนทีละสัปดาห์ เลือกวันที่และชั้น ดูคาบเรียน + การใช้ห้อง (ประชุม สอบ กิจกรรม) สถานะภาคเรียน ดาวน์โหลด CSV |
| `lib/screens/booking_editor_screen.dart` | ฟอร์มเต็มจอเพิ่ม/แก้การใช้ห้อง ทำซ้ำ วันเดียว/ทุกวัน/ทุกสัปดาห์/ในตารางเรียน |
| `lib/screens/term_calendar_screen.dart` | ปฏิทินภาคเรียน: เพิ่ม/แก้/ลบวันเปิด–ปิดของแต่ละเทอม |
| `lib/widgets/air_control_card.dart` | การ์ดแอร์ 1 เครื่อง: ปรับอุณหภูมิ เปิด/ปิด โหมด พัดลม สวิง, กำลังไฟ, ป้ายนับถอยหลัง, เมนูแอดมิน และ ป้ายยี่ห้อ·วิธีควบคุม |
| `lib/widgets/full_remote_sheet.dart` | รีโมตเต็มรูปแบบแบบแผ่นเลื่อนขึ้นจากล่าง (bottom sheet) ปรับทุกค่าแล้วกดส่งครั้งเดียว แสดงเฉพาะปุ่มที่แอร์เครื่องนั้นทำได้จริง |
| `lib/widgets/air_control_badge.dart` | ป้ายเล็ก "Daikin · สายแอร์" / "Haier · รีโมต IR" บอกยี่ห้อและวิธีที่บอร์ดสั่งแอร์ |
| `lib/widgets/auto_off_countdown.dart` | นาฬิกานับถอยหลังก่อนระบบปิดแอร์เพราะห้องว่าง + ฟังก์ชัน `formatCountdown` |
| `lib/widgets/energy_usage_chart.dart` | กราฟแท่งพลังงาน วาดเองด้วย `CustomPainter` ป้ายเฉพาะแท่งสูงสุด เส้นเฉลี่ย แตะ/ลากดูรายละเอียดได้ |
| `lib/widgets/period_selector.dart` | ดรอปดาวน์เลือกช่วงเวลา (วันนี้/7 วัน/30 วัน/กำหนดเอง), ตัวเลือกช่วงวัน, ป้าย `ChangeBadge` |
| `lib/widgets/floor_selector.dart` | แถบเลือกชั้น (รองรับ "ทุกชั้น" = -1 และ "ห้องพิเศษ" = 0) |
| `lib/widgets/status_pill.dart` | ป้ายสถานะทรงเม็ดยา ปรับสีให้อ่านง่ายในธีมมืด |
| `lib/widgets/section_title.dart` | หัวข้อของแต่ละส่วน + วิดเจ็ตท้ายแถว (ถ้ามี) |
| `lib/widgets/brand_mark.dart` | โลโก้ตัว R กับใบไม้ วาดด้วยโค้ด (`BrandMark`) และชื่อแอปสองสี (`BrandWordmark`) |
| `lib/widgets/weekday_selector.dart` | แถบเลือกวันอาทิตย์–เสาร์ (index 0–6) |

## พื้นฐาน Flutter ที่ต้องรู้ก่อน

ส่วนนี้สรุปเฉพาะแนวคิดที่บทนี้ใช้จริง ทุกหัวข้อมีตัวอย่างจากไฟล์ในโปรเจกต์

### Widget และ Widget tree

> [!LEARN] Widget คืออะไร
> ใน Flutter ทุกอย่างบนจอคือ Widget (ชิ้นส่วน UI) ตั้งแต่ข้อความ ปุ่ม ไปจนถึงทั้งหน้าจอ
> Widget ซ้อนกันเป็นต้นไม้ (Widget tree) ตัวแม่กำหนดตำแหน่งและขนาดให้ตัวลูก
> Widget เป็น "พิมพ์เขียว" ที่ไม่เปลี่ยนค่า ถ้าอยากให้จอเปลี่ยน ต้องสร้าง Widget ชุดใหม่ (เรียกว่า rebuild)

ตัวอย่างต้นไม้ที่เล็กที่สุดในบทนี้คือหน้ารอ

ไฟล์: lib/screens/auth/auth_loading_screen.dart

```dart
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/brand/rmutt_save_energy_icon.png',
              width: 72,
              height: 72,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'RMUTT Save Energy',
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('Checking your session...'),
```

1. **บรรทัด 1** — เป็น `StatelessWidget` เพราะหน้านี้ไม่มีข้อมูลที่เปลี่ยนเอง
2. **บรรทัด 6–9** — ต้นไม้คือ `Scaffold` → `Center` → `Column` → ลูก 5 ตัว (`mainAxisSize: MainAxisSize.min` ให้ Column สูงเท่าที่ลูกต้องการ จึงอยู่กลางจอได้)
3. **บรรทัด 11–17** — โลโก้จากไฟล์ภาพใน assets
4. **บรรทัด 18, 22** — `SizedBox` ใช้เว้นระยะ เป็นวิธีมาตรฐานของ Flutter
5. **บรรทัด 19–21** — วงหมุนแสดงว่ากำลังโหลด สีดึงจากธีม (`Theme.of(context)`)

### StatelessWidget กับ StatefulWidget

| | StatelessWidget | StatefulWidget |
|---|---|---|
| มีข้อมูลที่เปลี่ยนเองได้ไหม | ไม่มี ทุกอย่างมาจากพารามิเตอร์ | มี เก็บใน object `State` |
| เมธอดสำคัญ | `build()` | `initState()`, `build()`, `didUpdateWidget()`, `dispose()` |
| ตัวอย่างในบทนี้ | `HomeScreen`, `AnalyticsScreen`, `PeriodSelector`, `StatusPill`, `FloorSelector` | `LoginScreen`, `AppShell`, `RoomsScreen`, `RoomControlScreen`, `AirControlCard`, `AutoOffCountdown`, `EnergyUsageChart` |

> [!TIP] หลักจำง่าย
> ถ้าหน้าจอต้องจำอะไรบางอย่างเอง เช่น "กำลังโหลดอยู่ไหม" (`_isLoading`), "แท็บไหนถูกเลือก" (`_selectedIndex`), "มี Timer ที่ต้องยกเลิกไหม"
> ให้ใช้ StatefulWidget ถ้าแค่แสดงข้อมูลที่ได้รับมา ให้ใช้ StatelessWidget
> สังเกตว่า `HomeScreen` เป็น Stateless แต่ข้อมูลก็เปลี่ยนได้ เพราะมันฟัง controller ผ่าน `AnimatedBuilder` (ดูหัวข้อถัดไป)

### build() และ setState()

`build()` คือเมธอดที่คืน Widget tree ของหน้าจอ Flutter เรียกมันใหม่ทุกครั้งที่ต้องวาดจอใหม่
`setState()` คือการบอก Flutter ว่า "ข้อมูลใน State เปลี่ยนแล้ว ช่วยเรียก build ใหม่"

ไฟล์: lib/screens/auth/login_screen.dart (ปุ่มแสดง/ซ่อนรหัสผ่าน)

```dart
onPressed: () {
  setState(() {
    _obscurePassword = !_obscurePassword;
  });
},
```

1. **บรรทัด 2–4** — สลับค่า `_obscurePassword` ภายใน `setState` Flutter จึง build ใหม่ แล้วช่องรหัสผ่านจะแสดงหรือซ่อนตัวอักษรตามค่าใหม่

> [!WARN] เปลี่ยนค่านอก setState จอจะไม่อัปเดต
> ถ้าเขียน `_obscurePassword = !_obscurePassword;` เฉย ๆ ค่าในหน่วยความจำเปลี่ยน แต่จอยังเหมือนเดิม จนกว่าจะมีอะไรอื่นสั่ง rebuild

### AnimatedBuilder กับ ChangeNotifier

Controller ทุกตัวในแอปสืบทอด `ChangeNotifier` (คลาสที่แจ้งเตือนผู้ฟังได้ด้วย `notifyListeners()`)
หน้าจอใช้ `AnimatedBuilder` (ชื่อชวนสับสน แต่ใช้กับ Listenable อะไรก็ได้ ไม่จำเป็นต้องเป็นอนิเมชัน) เพื่อ build ใหม่ทุกครั้งที่ controller แจ้ง

ไฟล์: lib/screens/analytics_screen.dart

```dart
return AnimatedBuilder(
  animation: Listenable.merge([
    dashboardController,
    appSettingsController,
  ]),
  builder: (context, _) {
    final summary = dashboardController.summary;
```

1. **บรรทัด 2–5** — `Listenable.merge` รวมสอง controller เป็นตัวเดียว เปลี่ยนช่วงเวลา (dashboard) หรือเปลี่ยนค่าไฟต่อหน่วย (app settings) ก็ rebuild
2. **บรรทัด 6–7** — ภายใน builder อ่านค่าล่าสุดจาก controller เสมอ

### BuildContext

> [!LEARN] BuildContext
> `BuildContext` คือ "ตำแหน่งของ Widget นี้ในต้นไม้" ใช้ค้นหาของที่อยู่เหนือขึ้นไป เช่น
> `Theme.of(context)` (ธีม), `Navigator.of(context)` (ตัวจัดการหน้า), `ScaffoldMessenger.of(context)` (แสดง SnackBar),
> `AppLocalizations.of(context)` (ภาษา) ถ้า Widget ถูกถอดออกจากต้นไม้แล้ว context นั้นก็ใช้ไม่ได้อีก จึงต้องเช็ก `mounted`

### Scaffold, AppBar, NavigationBar

- `Scaffold` = โครงหน้าจอมาตรฐาน มีช่อง `appBar`, `body`, `bottomNavigationBar`
- `AppBar` = แถบหัว ใช้ใน `RoomControlScreen` (มีชื่อห้องและปุ่มรีเฟรช)
- `NavigationBar` = แถบเมนูล่างแบบ Material 3 ใช้ใน `AppShell` 5 แท็บ

> [!NOTE] หน้าแท็บส่วนใหญ่ไม่มี AppBar
> `HomeScreen`, `RoomsScreen`, `ScheduleScreen` วาดแถบหัวเองด้วย `Container(height: 58, color: palette.bar, ...)`
> เพื่อคุมหน้าตาได้ละเอียดกว่า และเพราะทั้งหมดอยู่ใน `Scaffold` ตัวเดียวของ `AppShell` อยู่แล้ว

### Column, Row, Expanded, Flexible, ListView

- `Column` เรียงลูกแนวตั้ง `Row` เรียงแนวนอน
- `Expanded` = "ให้ลูกตัวนี้กินพื้นที่ที่เหลือทั้งหมด" ใช้บ่อยมาก เช่น `Expanded(child: RefreshIndicator(...))` ในหน้าหลัก ให้รายการเลื่อนได้เต็มพื้นที่ใต้แถบหัว
- `Flexible` = คล้าย Expanded แต่ลูก "หดได้" ไม่บังคับขยาย ใช้ในหน้าล็อกอินกับปุ่มสองปุ่มที่ข้อความไทยยาวเกินการ์ด (คอมเมนต์ในโค้ดบอกว่าล้น 88px) แล้วให้ตัดท้ายด้วย `...`
- `ListView` = รายการที่เลื่อนได้ ทุกแท็บใช้ `ListView(children: [...])` ภายใน `RefreshIndicator` (ดึงลงเพื่อรีเฟรช)
- `ListView.separated` ใน `FloorSelector` สร้างปุ่มชั้นแนวนอนพร้อมช่องว่างคั่น

> [!WARN] Column ใน Column ต้องระวัง
> ถ้าวาง `ListView` ตรง ๆ ใน `Column` จะ error เพราะ ListView อยากสูงไม่จำกัด ต้องห่อด้วย `Expanded` ก่อน ซึ่งเป็นรูปแบบที่ทุกแท็บในบทนี้ใช้

### Navigator push/pop และการรับค่ากลับ

`Navigator` จัดการ "กองหน้า" (stack) `push` วางหน้าใหม่ทับ `pop` เอาหน้าบนสุดออก และ `pop(ค่า)` ส่งค่ากลับไปให้คนที่ push ได้

ไฟล์: lib/screens/auth/login_screen.dart

```dart
final passwordWasReset = await Navigator.of(context).push<bool>(
  MaterialPageRoute(
    builder: (_) => ForgotPasswordScreen(
      repository: widget.controller.repository,
    ),
  ),
);
```

1. **บรรทัด 1** — `push<bool>` บอกว่าหน้านี้จะคืนค่า `bool` กลับมา และ `await` รอจนหน้านั้นถูกปิด
2. **บรรทัด 2–6** — `MaterialPageRoute` สร้างหน้าใหม่พร้อมอนิเมชันเลื่อนแบบ Android/iOS

ฝั่งหน้าลืมรหัสผ่าน เมื่อเปลี่ยนรหัสสำเร็จจะเรียก `Navigator.of(context).pop(true)` ค่า `true` จึงไปโผล่ที่ `passwordWasReset`
รูปแบบเดียวกันนี้ใช้ใน `RoomControlScreen` (`push<bool>` ไปหน้าตั้งค่า BLE แล้วรอ `saved == true`)

### showModalBottomSheet และ showDialog

ทั้งสองอย่างก็เป็น route บน Navigator เหมือนกัน แค่หน้าตาต่างกัน และคืนค่าผ่าน `pop` ได้เหมือนกัน

ไฟล์: lib/widgets/full_remote_sheet.dart

```dart
Future<AirConditioner?> showFullRemoteSheet(
  BuildContext context,
  AirConditioner air,
) {
  return showModalBottomSheet<AirConditioner>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (_) => FullRemoteSheet(air: air.editableCopy()),
  );
}
```

1. **บรรทัด 5** — แผ่นนี้จะคืน `AirConditioner` (ค่าที่ผู้ใช้ปรับแล้ว) หรือ `null` ถ้าปัดทิ้ง
2. **บรรทัด 7** — `isScrollControlled: true` ให้แผ่นสูงเกินครึ่งจอได้ (ค่าเริ่มต้นสูงได้แค่ครึ่ง)
3. **บรรทัด 9** — พื้นโปร่งใส เพื่อให้ Container ข้างในวาดมุมโค้งด้านบนเอง
4. **บรรทัด 11** — ส่ง **สำเนา** ของแอร์ (`editableCopy()`) เข้าไป ผู้ใช้จะปรับเล่นยังไงก็ไม่กระทบข้อมูลจริง จนกว่าจะกดส่ง

`showDialog` ใช้กับกล่องยืนยัน เช่น "ลบแอร์เครื่องนี้ไหม" (คืน `bool`) และกล่องเปลี่ยนชื่อ (คืน `String`)

### Form, validator และ TextEditingController

> [!LEARN] ส่วนประกอบของฟอร์ม
> - `Form` + `GlobalKey<FormState>` = กลุ่มของช่องกรอก เรียก `_formKey.currentState?.validate()` เพื่อตรวจทุกช่องพร้อมกัน
> - `TextFormField` มี `validator` เป็นฟังก์ชันที่คืน `null` ถ้าถูกต้อง หรือคืนข้อความ error ถ้าผิด ข้อความจะขึ้นใต้ช่องเป็นสีแดง
> - `TextEditingController` = ตัวถือข้อความในช่อง อ่านด้วย `.text` ตั้งค่าด้วย `.text = ...` ล้างด้วย `.clear()`

### dispose และ mounted

- `dispose()` ถูกเรียกเมื่อ State กำลังถูกทำลาย ต้องคืนทรัพยากรที่สร้างเอง เช่น `TextEditingController.dispose()`, `Timer.cancel()`, `removeListener(...)` ไม่งั้นหน่วยความจำรั่วหรือ Timer ยังเรียก setState หลังหน้าปิด
- `mounted` = State นี้ยังติดอยู่ในต้นไม้ไหม หลัง `await` ทุกครั้ง หน้าจออาจถูกปิดไปแล้ว (เช่นผู้ใช้กดย้อนกลับ หรือ login สำเร็จจน LoginScreen หายไป) ถ้าเรียก `setState` หรือใช้ `context` ตอนนั้นจะ error จึงเห็น `if (!mounted) return;` อยู่เต็มโค้ด

### Timer

`Timer.periodic(Duration, callback)` จาก `dart:async` เรียก callback ซ้ำทุกช่วงเวลา ในบทนี้มีสองแบบ

| Timer | อยู่ที่ไหน | ทำอะไร |
|---|---|---|
| ทุก 1 วินาที | `AutoOffCountdown`, `_CountdownChip` ใน `air_control_card.dart` | แค่ `setState(() {})` ให้ตัวเลขนับถอยหลังลดลง ไม่ยิงเน็ต |
| ทุก 10 วินาที | `AirConditionerController`, `RoomController` (บท controllers) | ดึงสถานะแอร์/ห้องจาก Backend |
| ทุก 30 วินาที | `DashboardController` | ดึงสรุปพลังงานและแจ้งเตือน |

### CustomPainter

เมื่อ Widget สำเร็จรูปวาดสิ่งที่ต้องการไม่ได้ Flutter ให้วาดเองบน `Canvas` ผ่าน `CustomPainter` (มีเมธอด `paint()` และ `shouldRepaint()`)
บทนี้มีสี่ตัว: กราฟพลังงาน (`EnergyChartPainter`), โลโก้ (`_BrandMarkPainter`), ลายพื้นหลังหน้า auth (`_EnergyBackgroundPainter`), เส้นประรอบการ์ดแอร์ที่ออฟไลน์ (`_DashedBorderPainter`)

## หน้าเข้าสู่ระบบ (กลุ่ม auth)

### AuthBackground และ EnergyBrand

ผู้ใช้เห็นพื้นหลังสีอ่อนไล่ลง มีรูปสามเหลี่ยมสีเขียวจาง ๆ และการ์ดสีขาวตรงกลาง
`AuthBackground` เป็น Stateless ที่ทุกหน้าในกลุ่ม auth ใช้ร่วมกัน โครงหลักคือ

- `Scaffold` → `DecoratedBox` (ไล่สีด้วย `LinearGradient`) → `Stack` สามชั้น
  1. `CustomPaint(painter: _EnergyBackgroundPainter())` วาดสามเหลี่ยมสามรูปด้วย `Path` ห่อด้วย `IgnorePointer` เพื่อไม่ให้กินการแตะ
  2. `SafeArea` → `LayoutBuilder` → `SingleChildScrollView` → `ConstrainedBox(maxWidth: 440, minHeight: constraints.maxHeight - 60)` ทำให้การ์ดไม่กว้างเกินบนแท็บเล็ต และยังอยู่กลางจอแนวตั้ง แต่เลื่อนได้เมื่อคีย์บอร์ดเด้งขึ้น
  3. ปุ่มย้อนกลับ (ถ้า `showBackButton`) วางไว้ **ท้ายสุด** ของ Stack

> [!WHY] ทำไมปุ่มย้อนกลับต้องอยู่ท้าย Stack
> Stack วาดลูกตามลำดับ ตัวท้ายอยู่บนสุดและรับการแตะก่อน คอมเมนต์ในโค้ดอธิบายว่าถ้าวางปุ่มก่อน `SingleChildScrollView` ที่เต็มจอ
> ตัวเลื่อนจะทับปุ่ม ผู้ใช้เห็นปุ่มแต่กดไม่ได้

`EnergyBrand` คือโลโก้ PNG มุมมน + ชื่อ "RMUTT Save Energy" + คำบรรยาย มีโหมด `compact` (ใช้ในหน้าลืมรหัสผ่าน) ทำให้เล็กลง

### AuthTextField

ช่องกรอกที่หน้าตาเหมือนกันทุกช่อง (ไอคอนนำหน้าสีหลัก ไม่ autocorrect) จุดสำคัญคือการแปลข้อความ error

ไฟล์: lib/widgets/auth/auth_text_field.dart

```dart
return TextFormField(
  controller: controller,
  validator: validator == null
      ? null
      : (value) {
          final message = validator!(value);
          return message == null ? null : context.tr(message);
        },
```

1. **บรรทัด 3–4** — ถ้าผู้เรียกไม่ส่ง validator มา ก็ไม่ตรวจ
2. **บรรทัด 5–8** — ห่อ validator ของผู้เรียกอีกชั้น: เรียกตัวจริงก่อน ถ้าได้ข้อความ error ก็แปลด้วย `context.tr` ผู้เรียกจึงเขียน `'Enter your username'` เป็นอังกฤษได้เลย

นอกจากนี้ `enableSuggestions: !obscureText` ปิดคำแนะนำของคีย์บอร์ดในช่องรหัสผ่าน (คีย์บอร์ดจะได้ไม่จำรหัส)

### LoginScreen — สิ่งที่ผู้ใช้เห็น

จากบนลงล่าง: โลโก้ `EnergyBrand` → การ์ดขาวมีหัว "Sign In" → ช่อง Username → ช่อง Password (มีปุ่มตาแสดง/ซ่อน) → ช่องติ๊ก "Remember username" →
ปุ่ม "Forgot password?" กับ "Contact Admin" → ปุ่มเขียว "Sign In" → ข้อความ "Building 16 · Computer Engineering"

ข้อมูลที่ใช้: `AuthController` (ส่งมาทาง constructor จาก `main.dart`) — เรียก `login`, `loadRememberedLogin`, `clearRememberedLogin` และใช้ `controller.repository` ส่งต่อให้หน้าลืมรหัสผ่านและแผ่นติดต่อแอดมิน

### LoginScreen — State และวงจรชีวิต

ไฟล์: lib/screens/auth/login_screen.dart

```dart
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberPassword = false;
  bool _isLoadingRememberedLogin = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedLogin();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
```

1. **บรรทัด 2** — กุญแจของฟอร์ม ใช้สั่ง `validate()` ทุกช่องพร้อมกัน
2. **บรรทัด 3–4** — ตัวถือข้อความของสองช่อง สร้างครั้งเดียวตอนสร้าง State
3. **บรรทัด 6** — `true` = ซ่อนรหัสผ่านเป็นจุด ๆ (ค่าเริ่มต้น)
4. **บรรทัด 7** — สถานะช่องติ๊ก "จำชื่อผู้ใช้" (ชื่อตัวแปรยังเป็น "Password" จากรุ่นเก่า ดูหัวข้อข้อสังเกต)
5. **บรรทัด 8** — `true` ระหว่างอ่านค่าที่จำไว้จาก secure storage ช่วงนี้ช่องติ๊กจะกดไม่ได้
6. **บรรทัด 9** — `true` ระหว่างรอเซิร์ฟเวอร์ตอบการล็อกอิน ใช้ปิดปุ่มและแสดงวงหมุน
7. **บรรทัด 12–15** — `initState` ถูกเรียกครั้งเดียวตอนเปิดหน้า สั่งโหลดชื่อผู้ใช้ที่จำไว้ (ไม่ `await` เพราะ initState เป็น async ไม่ได้)
8. **บรรทัด 18–22** — คืนหน่วยความจำของ TextEditingController ทั้งสองตัวเมื่อหน้าถูกทำลาย

### LoginScreen — โหลดและล้าง "จำชื่อผู้ใช้"

```dart
Future<void> _loadRememberedLogin() async {
  try {
    final remembered = await widget.controller.loadRememberedLogin();
    if (!mounted) return;

    if (remembered != null) {
      _usernameController.text = remembered.username;
      if (remembered.password.isNotEmpty) {
        _passwordController.text = remembered.password;
      }
      _rememberPassword = true;
    }
  } catch (_) {
    // Secure storage must not prevent a normal manual login.
  } finally {
    if (mounted) {
      setState(() => _isLoadingRememberedLogin = false);
    }
  }
}

Future<void> _setRememberPassword(bool? value) async {
  final shouldRemember = value ?? false;
  setState(() => _rememberPassword = shouldRemember);

  if (!shouldRemember) {
    try {
      await widget.controller.clearRememberedLogin();
    } catch (_) {
      _showError('Could not remove the saved login details.');
    }
  }
}
```

1. **บรรทัด 3** — ขอค่าที่จำไว้ผ่าน controller → `AuthService` อ่านจาก `FlutterSecureStorage` (ที่เก็บแบบเข้ารหัสของเครื่อง)
2. **บรรทัด 4** — ระหว่าง await ผู้ใช้อาจออกจากหน้าไปแล้ว ถ้าไม่ mounted ให้หยุด
3. **บรรทัด 6–11** — ถ้ามีค่าที่จำไว้ เติมชื่อผู้ใช้ลงช่อง และติ๊กช่องจำไว้ให้ (บรรทัด 8–10 เติมรหัสผ่านด้วยถ้ามี แต่ `AuthService` รุ่นปัจจุบันคืนรหัสผ่านเป็น `''` เสมอ จึงไม่เคยทำงาน)
4. **บรรทัด 13–14** — ถ้า secure storage พัง ก็เงียบไว้ ผู้ใช้ยังพิมพ์ล็อกอินเองได้
5. **บรรทัด 15–18** — ไม่ว่าสำเร็จหรือพัง ปิดสถานะ "กำลังโหลด" และ rebuild (ค่าที่ตั้งในบรรทัด 7 และ 11 จะขึ้นจอพร้อมกันตรงนี้)
6. **บรรทัด 22–24** — เมื่อผู้ใช้ติ๊ก/เลิกติ๊ก อัปเดตช่องติ๊กทันที
7. **บรรทัด 26–31** — ถ้าเลิกติ๊ก ลบชื่อที่จำไว้ทันที ไม่ต้องรอล็อกอิน (ผู้ใช้คาดว่าเลิกติ๊กแล้วข้อมูลหายเลย)

> [!NOTE] จริง ๆ แล้วแอปจำแค่ชื่อผู้ใช้
> `AuthService.saveRememberedLogin` เขียนเฉพาะ username และลบ key รหัสผ่านเก่าทิ้งทุกครั้ง
> คอมเมนต์ในไฟล์ service ให้เหตุผลว่า ถ้ามือถือหายรหัสผ่านจะหลุด การอยู่ในระบบต่อใช้ token ที่หมดอายุเองและยกเลิกจากเซิร์ฟเวอร์ได้แทน
> ป้ายบนจอจึงเขียนว่า "Remember username" และมีคำเตือน "Recommended for personal devices only"

### LoginScreen — ส่งฟอร์มล็อกอิน

```dart
Future<void> _login() async {
  FocusScope.of(context).unfocus();
  if (!(_formKey.currentState?.validate() ?? false) || _isLoading) {
    return;
  }

  setState(() => _isLoading = true);
  try {
    await widget.controller.login(
      username: _usernameController.text,
      password: _passwordController.text,
      rememberPassword: _rememberPassword,
    );
  } on ApiException catch (error) {
    _showError(error.message);
  } catch (_) {
    _showError('Something went wrong. Please try again.');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
```

1. **บรรทัด 2** — ซ่อนคีย์บอร์ด (ปลด focus จากช่องที่พิมพ์อยู่) ผู้ใช้จะเห็น SnackBar error ได้ชัด
2. **บรรทัด 3** — `validate()` เรียก validator ทุกช่อง ถ้ามีช่องไหนคืนข้อความ error จะได้ `false` และข้อความแดงขึ้นใต้ช่อง
   `?? false` กันกรณี `currentState` เป็น null ส่วน `|| _isLoading` กันการกดซ้ำระหว่างรอ
3. **บรรทัด 7** — เปิดสถานะกำลังโหลด ปุ่มจะถูกปิดและเปลี่ยนเป็นวงหมุน
4. **บรรทัด 9–13** — ส่งต่อให้ `AuthController.login` ซึ่งเรียก API ล็อกอิน บันทึก/ล้างชื่อที่จำไว้ แล้วตั้ง `status = AuthStatus.signedIn` + `notifyListeners()`
5. **บรรทัด 14–15** — error ที่ service แปลงมาแล้ว (เช่น รหัสผิด เซิร์ฟเวอร์ช้า) แสดงข้อความของมันตรง ๆ
6. **บรรทัด 16–17** — error อื่นที่ไม่คาดคิด แสดงข้อความกลาง ๆ
7. **บรรทัด 18–21** — `finally` ทำทุกกรณี ปิดสถานะโหลด แต่ต้องเช็ก `mounted` ก่อน

> [!WHY] ทำไม finally ต้องเช็ก mounted
> ถ้าล็อกอินสำเร็จ controller แจ้งเปลี่ยนสถานะ `main.dart` จะสลับ `home` เป็น `AppShell` ทันที LoginScreen ถูกถอดออกจากต้นไม้
> ถึงตอนที่โค้ดมาถึง `finally` หน้านี้ไม่ mounted แล้ว ถ้าเรียก `setState` จะเกิด error "setState() called after dispose()"
> นี่คือตัวอย่างที่ชัดที่สุดของเหตุผลที่ต้องเช็ก mounted หลัง await

การแสดง error ใช้ SnackBar สีแดง

```dart
void _showError(String message) {
  if (!mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.red,
      ),
    );
}
```

1. **บรรทัด 2** — ไม่มีหน้าแล้วก็ไม่ต้องแสดง
2. **บรรทัด 3–5** — `..` คือ cascade (เรียกหลายเมธอดบน object เดียว) ซ่อน SnackBar เก่าก่อน ไม่ให้ต่อคิวกันยาว แล้วแสดงอันใหม่
3. **บรรทัด 7** — `Text` ตัวนี้เป็นตัวที่แปลอัตโนมัติ ข้อความอังกฤษจาก service จึงขึ้นเป็นไทยได้ถ้ามีในพจนานุกรม

### LoginScreen — ส่วน build ที่สำคัญ

ช่องรหัสผ่าน

```dart
AuthTextField(
  controller: _passwordController,
  label: context.tr('Password'),
  icon: Icons.lock_rounded,
  obscureText: _obscurePassword,
  textInputAction: TextInputAction.done,
  autofillHints: const [AutofillHints.password],
  onFieldSubmitted: (_) => _login(),
  suffixIcon: IconButton(
    tooltip: context.tr(
      _obscurePassword
          ? 'Show password'
          : 'Hide password',
    ),
    onPressed: () {
      setState(() {
        _obscurePassword = !_obscurePassword;
      });
    },
    icon: Icon(
      _obscurePassword
          ? Icons.visibility_off_rounded
          : Icons.visibility_rounded,
      color: colors.primary,
    ),
  ),
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Enter your password';
    }
    return null;
  },
),
```

1. **บรรทัด 5** — ซ่อน/แสดงตัวอักษรตาม state
2. **บรรทัด 6** — ปุ่มบนคีย์บอร์ดเป็น "Done" (ช่อง username ใช้ `next` เพื่อกระโดดมาช่องนี้)
3. **บรรทัด 7** — บอกระบบว่าเป็นช่องรหัสผ่าน ตัวจัดการรหัสผ่านของเครื่องเติมให้ได้ (ทั้งฟอร์มห่อด้วย `AutofillGroup`)
4. **บรรทัด 8** — กด Done บนคีย์บอร์ด = กดปุ่ม Sign In
5. **บรรทัด 9–26** — ปุ่มรูปตาท้ายช่อง ไอคอนและ tooltip เปลี่ยนตามสถานะ
6. **บรรทัด 27–32** — validator ช่องรหัสผ่านเช็กแค่ว่าไม่ว่าง (ช่อง username ใช้ `value.trim().isEmpty` เพื่อไม่ยอมรับช่องว่างล้วน แต่รหัสผ่านไม่ trim เพราะช่องว่างอาจเป็นส่วนของรหัสจริง)

ช่องติ๊กและปุ่มหลัก ปิดการกดด้วยการส่ง `null` ให้ `onChanged`/`onPressed`

```dart
CheckboxListTile(
  value: _rememberPassword,
  onChanged: _isLoading || _isLoadingRememberedLogin
      ? null
      : _setRememberPassword,
```

```dart
FilledButton(
  onPressed: _isLoading ? null : _login,
```

```dart
child: _isLoading
    ? const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
        ),
      )
    : Row(
```

> [!TIP] วิธีปิดปุ่มใน Flutter
> ปุ่มทุกชนิดของ Material จะกลายเป็นสีจางและกดไม่ได้เองเมื่อ `onPressed` เป็น `null` ไม่ต้องมี property `enabled` แยก

> [!NOTE] ทำไมการ์ดมี `Material(type: MaterialType.transparency)` คั่น
> คอมเมนต์ในโค้ดอธิบายว่า `CheckboxListTile` วาดเอฟเฟกต์กดลงบน `Material` ที่ใกล้ที่สุด ถ้าการ์ด (Container มีสีพื้น) ไม่มี Material ข้างใน
> สีพื้นจะบังเอฟเฟกต์ และ Flutter รุ่นใหม่จะโยน assertion ตอน build

### LoginScreen — แผ่นติดต่อแอดมิน (`_AdminContactSheet`)

กด "Contact Admin" → `showModalBottomSheet` แสดงแผ่นที่มีไอคอน ชื่อ และเบอร์โทรของผู้ดูแล พร้อมปุ่ม "Copy Phone Number"
แผ่นนี้เป็น StatefulWidget ที่เก็บ `Future<AdminContact>` ไว้ แล้วใช้ `FutureBuilder` แสดงสามสถานะ

- `connectionState != done` → วงหมุน
- `hasError` → ข้อความแดง + ปุ่ม "Try Again" ซึ่งเรียก `setState(_load)` สร้าง Future ใหม่
- สำเร็จ → `SelectableText` เบอร์โทร และปุ่มคัดลอกด้วย `Clipboard.setData` แล้วแสดง SnackBar (เช็ก `context.mounted` ก่อน)

> [!WHY] ทำไมสร้าง Future ใน initState ไม่สร้างใน build
> ถ้าเขียน `future: widget.repository.getAdminContact()` ใน build ทุกครั้งที่ rebuild จะยิงคำขอใหม่ เก็บไว้ในตัวแปร State จึงยิงครั้งเดียว และยิงใหม่เฉพาะเมื่อกดลองอีกครั้ง

### ForgotPasswordScreen — ตัวจัดการขั้นตอน (state machine)

ผู้ใช้เห็นการ์ดเดียวที่เปลี่ยนเนื้อหาไปทีละขั้น ด้านบนมีแถบ 3 ขีด (`_ResetProgress`) ไฮไลต์ตามขั้นปัจจุบัน
ขั้นตอนกำหนดด้วย enum `_ResetStage { requestOtp, verifyOtp, newPassword }` และค่า `_title`, `_subtitle`, `_buttonLabel` ใช้ `switch` ตามขั้น

ไฟล์: lib/screens/auth/forgot_password_screen.dart

```dart
Future<void> _submit() async {
  FocusScope.of(context).unfocus();
  if (!(_formKey.currentState?.validate() ?? false) || _isLoading) {
    return;
  }

  setState(() => _isLoading = true);
  try {
    switch (_stage) {
      case _ResetStage.requestOtp:
        _requestId = await widget.repository.requestPasswordReset(
          _identifierController.text,
        );
        _otpController.clear();
        if (!mounted) return;
        setState(() => _stage = _ResetStage.verifyOtp);
        _showMessage(
          'If the information is correct, a 6-digit OTP has been sent to the email on file.',
        );
        return;
      case _ResetStage.verifyOtp:
        _resetToken = await widget.repository.verifyPasswordResetOtp(
          requestId: _requestId!,
          otp: _otpController.text,
        );
        if (!mounted) return;
        setState(() => _stage = _ResetStage.newPassword);
        return;
```

1. **บรรทัด 1–7** — โครงเหมือน `_login`: ซ่อนคีย์บอร์ด ตรวจฟอร์ม กันกดซ้ำ เปิดสถานะโหลด
2. **บรรทัด 9** — ทำงานต่างกันตามขั้นปัจจุบัน ปุ่มเดียวใช้ได้ทุกขั้น
3. **บรรทัด 11–13** — ขั้น 1 ส่ง username หรืออีเมลไปขอ OTP ได้ `requestId` กลับมาเก็บไว้
4. **บรรทัด 16–19** — เลื่อนไปขั้น 2 และแจ้งว่า "ถ้าข้อมูลถูกต้อง" ได้ส่ง OTP แล้ว (ข้อความกลาง ๆ แบบนี้กันคนร้ายใช้หน้านี้เดาว่าบัญชีไหนมีอยู่จริง)
5. **บรรทัด 22–25** — ขั้น 2 ส่ง `requestId` + OTP 6 หลัก ได้ `resetToken` กลับมา
6. **บรรทัด 27** — เลื่อนไปขั้น 3

ขั้นที่ 3 เรียก `resetPassword(resetToken: ..., newPassword: ...)` แล้ว `clearRememberedLogin()` แสดง `AlertDialog` "Password changed"
เมื่อปิด dialog ก็ `Navigator.of(context).pop(true)` กลับหน้าล็อกอิน ซึ่งจะล้างช่องรหัสผ่านและเลิกติ๊กจำชื่อ (ดู `_openForgotPassword`)

> [!LEARN] return ใน try ยังวิ่งเข้า finally
> ทุก `case` จบด้วย `return` แต่ Dart ยังรัน `finally` เสมอ `_isLoading` จึงถูกปิดทุกครั้งโดยไม่ต้องเขียนซ้ำในแต่ละ case

ช่องกรอกแต่ละขั้นสลับด้วย `AnimatedSwitcher` (เฟดเปลี่ยน 220 ms) แต่ละช่องมี `ValueKey` ต่างกัน (`'identifier'`, `'otp'`, `'new-password'`) เพื่อให้ AnimatedSwitcher รู้ว่าเป็นคนละวิดเจ็ต
ช่อง OTP จำกัดเฉพาะตัวเลข (`FilteringTextInputFormatter.digitsOnly`) ยาว 6 (`maxLength: 6`) และ validator ใช้ `RegExp(r'^\d{6}$')`
ช่องยืนยันรหัสผ่านเทียบกับ `_newPasswordController.text` ส่วนรหัสใหม่ต้องยาวอย่างน้อย 8 ตัว
ขั้น 2 มีปุ่ม "Did not receive it? Resend OTP" (`_resendOtp`) ขอ `requestId` ใหม่

## AppShell — โครงหลักหลังล็อกอิน

### สิ่งที่ผู้ใช้เห็น

เนื้อหาเต็มจอ (กว้างไม่เกิน 480 px แม้บนแท็บเล็ต) และแถบเมนูล่าง 5 แท็บ

| index | ป้ายแท็บ | หน้าที่แสดง |
|---|---|---|
| 0 | Home | `HomeScreen` |
| 1 | Analytics | `AnalyticsScreen` |
| 2 | Schedule | `ScheduleScreen` |
| 3 | Control | `RoomsScreen` |
| 4 | Profile | `ProfileScreen` (อยู่ในบทถัดไป) |

### initState — เป็นเจ้าของ controller ทุกตัว

ไฟล์: lib/screens/app_shell.dart

```dart
@override
void initState() {
  super.initState();
  // Keep one room model for the whole signed-in AppShell lifecycle.
  // Rebuilding MaterialApp for a theme/language change creates a new
  // AppShell widget with new mock room objects, but this State and the
  // controller still own the original objects loaded from the backend.
  _rooms = widget.rooms;
  _scheduleController = ScheduleController(widget.scheduleRepository);
  _scheduleController.initialize();
  _roomController = RoomController(
    rooms: _rooms,
    repository: widget.roomRepository,
  );
  _airController = AirConditionerController(
    rooms: _rooms,
    repository: widget.airConditionerRepository,
  );
  _userController = UserController(
    repository: widget.userRepository,
    currentUsername: widget.user.username,
  );
  _energyController = EnergyController(
    repository: widget.energyRepository,
  );
  _dashboardController = DashboardController(
    energyRepository: widget.energyRepository,
    alertRepository: widget.alertRepository,
  );
  _dashboardController.alertPreferences =
      widget.appSettingsController.alertPreferences;
  _dashboardController.onNewAlerts = _handleNewAlerts;
  widget.appSettingsController.addListener(_syncAlertPreferences);
  _systemSettingsController = SystemSettingsController(
    repository: widget.systemSettingsRepository,
  );
  _systemSettingsController.initialize();
  _dashboardController.initialize();
  _initializeRoomsAndAir();
}
```

1. **บรรทัด 4–8** — เก็บรายการห้องไว้ใน State ครั้งเดียว `main.dart` ส่ง `MockData.createRooms()` มาเป็นค่าตั้งต้น และทุกครั้งที่เปลี่ยนธีม/ภาษา `MaterialApp` สร้าง `AppShell` ตัวใหม่พร้อม mock ชุดใหม่ แต่ State เดิมยังอยู่ (Flutter ใช้ State เดิมถ้าชนิดและตำแหน่งเหมือนเดิม) จึงต้องยึดรายการเดิมที่ controller กำลังใช้
2. **บรรทัด 9–10** — ตารางเรียน: สร้างแล้วโหลดครั้งเดียว
3. **บรรทัด 11–18** — `RoomController` กับ `AirConditionerController` ได้ **List เดียวกัน** (`_rooms`) ตัวหนึ่งเติมข้อมูลห้อง อีกตัวเติมแอร์ลงในห้องเหล่านั้น
4. **บรรทัด 19–25** — controller ของผู้ใช้และฐานข้อมูลพลังงาน (ใช้ในหน้า Profile)
5. **บรรทัด 26–29** — `DashboardController` ใช้ร่วมกันระหว่างหน้า Home และ Analytics เปลี่ยนช่วงเวลาที่หน้าไหนก็เห็นตรงกัน
6. **บรรทัด 30–33** — ส่งค่าตั้งการแจ้งเตือนเข้าไป และฟังการเปลี่ยนแปลงของค่าตั้ง (`addListener`) เพื่อซิงก์ทันที `onNewAlerts` คือ callback เด้งแจ้งเตือนของเครื่อง
7. **บรรทัด 37–39** — เริ่มโหลดข้อมูล `_initializeRoomsAndAir()` โหลดห้องก่อนแล้วค่อยโหลดแอร์ (await ต่อกัน) เพราะแอร์ต้องหาห้องที่ตัวเองสังกัดให้เจอ

> [!WHY] ทำไมสร้าง controller ไว้ที่ AppShell ไม่สร้างในแต่ละหน้า
> 1) ข้อมูลชุดเดียวกันถูกใช้หลายหน้า (ห้องใช้ใน Schedule, Control, หน้าห้อง) ถ้าแต่ละหน้าโหลดเองจะยิงซ้ำและค่าไม่ตรงกัน
> 2) controller มี Timer ดึงข้อมูลทุก 10/30 วินาที อายุควรเท่ากับช่วงที่ผู้ใช้ล็อกอินอยู่ ซึ่งก็คืออายุของ AppShell
> 3) เมื่อ logout `AppShell` ถูกทำลาย `dispose()` จะ dispose controller ทุกตัว Timer ทุกตัวหยุดพร้อมกัน

`dispose()` ของ AppShell ทำตรงข้ามกับ initState: `removeListener(_syncAlertPreferences)` แล้ว `dispose()` controller ทั้งเจ็ดตัว

### เปิดหน้าห้อง (`_openRoom`)

```dart
Future<void> _openRoom(Room room) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: RoomControlScreen(
              room: room,
              isAdmin: widget.user.role.toLowerCase() == 'admin',
              controller: _airController,
              roomController: _roomController,
              repository: widget.airConditionerRepository,
              occupancyRepository: widget.occupancySensorRepository,
              bleService: widget.bleProvisioningService,
            ),
          ),
        ),
      ),
    ),
  );
  if (mounted) {
    setState(() {});
  }
}
```

1. **บรรทัด 2–3** — push หน้าใหม่ทับแท็บทั้งหมด (แถบเมนูล่างจะหายไปในหน้าห้อง)
2. **บรรทัด 4–8** — ห่อด้วยพื้นสี + จำกัดความกว้าง 480 ให้หน้าตาเหมือนแท็บอื่นบนจอกว้าง
3. **บรรทัด 11** — สิทธิ์แอดมินตัดสินจาก `role` ของผู้ใช้ที่ล็อกอิน (เทียบแบบไม่สนตัวพิมพ์เล็ก/ใหญ่)
4. **บรรทัด 12–13** — ส่ง controller **ตัวเดียวกัน** ที่ AppShell ถืออยู่ หน้าห้องจึงไม่ต้องโหลดเอง และ Timer 10 วินาทีเดิมก็อัปเดตหน้าห้องด้วย
5. **บรรทัด 23–25** — เมื่อผู้ใช้ย้อนกลับมา rebuild หนึ่งครั้ง เผื่อข้อมูลเปลี่ยนระหว่างอยู่ในหน้าห้อง

ฟังก์ชันนี้ถูกส่งเป็น callback `onOpenRoom` ให้ Home (กดใบแจ้งเตือน), Schedule (กดการ์ดห้อง) และ Rooms (กดการ์ดห้อง) ทุกทางเข้าจึงเปิดหน้าห้องแบบเดียวกัน

### build — IndexedStack + NavigationBar

```dart
@override
Widget build(BuildContext context) {
  return AnimatedBuilder(
    animation: Listenable.merge([_airController, _roomController]),
    builder: (context, _) {
      final pages = [
    HomeScreen(
      rooms: _rooms,
      appSettingsController: widget.appSettingsController,
      dashboardController: _dashboardController,
      onOpenRoom: _openRoom,
      onOpenControl: () => setState(() => _selectedIndex = 3),
    ),
```

1. **บรรทัด 3–4** — rebuild ทุกหน้าเมื่อข้อมูลห้องหรือแอร์เปลี่ยน (ทุก 10 วินาทีหรือเมื่อสั่งงาน)
2. **บรรทัด 6** — สร้างรายการ 5 หน้า (โค้ดส่วนที่เหลือคือ Analytics, Schedule, Rooms, Profile)
3. **บรรทัด 12** — `onOpenControl` ให้หน้า Home สลับไปแท็บ index 3 (Control) ได้ เรียกเมื่อแตะแถบค่าไฟในการ์ดพลังงาน

```dart
return ColoredBox(
  color: Theme.of(context).colorScheme.surfaceContainerLow,
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
```

1. **บรรทัด 6** — `Scaffold` ตัวเดียวของทั้งโครง
2. **บรรทัด 7** — `IndexedStack` สร้างครบทั้ง 5 หน้า แต่แสดงเฉพาะหน้าที่ index ตรงกับ `_selectedIndex`
3. **บรรทัด 8–12** — แตะแท็บ → `setState` เปลี่ยน index → build ใหม่ → IndexedStack แสดงหน้าใหม่ และ NavigationBar ไฮไลต์แท็บใหม่

> [!WHY] ทำไมใช้ IndexedStack แทนการสลับวิดเจ็ตเฉย ๆ
> IndexedStack เก็บทุกหน้าไว้ในต้นไม้ตลอด State ของแต่ละแท็บจึงไม่หาย เช่น ชั้นที่เลือกในแท็บ Control, วันที่เลือกในแท็บ Schedule, ตำแหน่งที่เลื่อนไว้
> ข้อเสียคือทุกหน้าถูก build แม้มองไม่เห็น ซึ่งรับได้เพราะมีแค่ 5 หน้าและข้อมูลไม่หนัก

## HomeScreen — หน้าหลัก

### สิ่งที่ผู้ใช้เห็น

- แถบหัวสีเข้ม: โลโก้ `BrandMark` + ชื่อ `BrandWordmark` + ป้าย "Building 16" (ถ้ามีแจ้งเตือนค้าง จะเป็นสีส้มพร้อมจำนวน)
- เส้นโหลดบาง ๆ ใต้หัว เฉพาะการโหลดครั้งแรก
- การ์ดพลังงาน: ดรอปดาวน์ช่วงเวลา (`PeriodSelector`) มุมขวา, ตัวเลขพลังงานใหญ่พร้อมหน่วยที่เลือกอัตโนมัติ, ช่วงวันที่, แถบ "Estimated cost: THB ..."
- หัวข้อ "System Alerts" + ป้ายส้ม "N need attention"
- รายการใบแจ้งเตือน (`_AlertCard`): ห้อง เวลา ข้อความ ชื่อเครื่อง ป้ายสถานะ และปุ่ม "Mark as handled" ถ้ายังค้าง หรือการ์ด "Nothing needs attention right now" ถ้าไม่มี

ข้อมูลมาจาก `DashboardController` (summary, alerts, openAlertCount, errorMessage, alertsErrorMessage) และ `AppSettingsController.calculateElectricityCost(...)` สำหรับค่าไฟ

### build

ไฟล์: lib/screens/home_screen.dart

```dart
@override
Widget build(BuildContext context) {
  return AnimatedBuilder(
    animation: dashboardController,
    builder: (context, _) {
      final summary = dashboardController.summary;
      final alerts = dashboardController.alerts;

      return SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HomeHeader(openAlerts: dashboardController.openAlertCount),
            if (dashboardController.isLoading &&
                !dashboardController.hasLoaded)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                onRefresh: dashboardController.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  children: [
                    _EnergyCard(
                      summary: summary,
                      controller: dashboardController,
                      electricityCost: appSettingsController
                          .calculateElectricityCost(summary.totalKwh),
                      onTap: onOpenControl,
                    ),
```

1. **บรรทัด 3–4** — HomeScreen เป็น Stateless แต่ฟัง `dashboardController` จึงอัปเดตทุก 30 วินาทีหรือเมื่อเปลี่ยนช่วงเวลา
2. **บรรทัด 7** — `alerts` เป็นรายการที่กรองตามค่าตั้งของผู้ใช้แล้ว (getter ใน controller)
3. **บรรทัด 9–10** — `SafeArea(bottom: false)` หลบรอยบากด้านบน แต่ไม่เว้นด้านล่างเพราะมี NavigationBar จัดการอยู่แล้ว
4. **บรรทัด 14–16** — แสดงเส้นโหลดเฉพาะ "โหลดครั้งแรกและยังไม่เคยได้ข้อมูล" รอบอัตโนมัติจะไม่กระพริบ
5. **บรรทัด 17–19** — `Expanded` ให้ส่วนรายการกินพื้นที่ที่เหลือ `RefreshIndicator` = ดึงจอลงเพื่อเรียก `dashboardController.refresh` (ซึ่งคืน Future วงหมุนจะหายเมื่อ Future จบ)
6. **บรรทัด 23–29** — การ์ดพลังงาน คำนวณค่าไฟตรงนี้จาก kWh × อัตราที่ผู้ใช้ตั้ง

ส่วนที่เหลือของ ListView: ถ้า `errorMessage` ไม่ว่างแสดง `_ErrorNote`, ตามด้วย `SectionTitle`, แล้วเลือกแสดง error ของแจ้งเตือน / การ์ดว่าง / รายการใบแจ้งเตือน ด้วย `if ... else if ... else` ภายใน list (collection-if ของ Dart) และ `...alerts.map(...)` (spread) เพื่อกางรายการลงใน children

### การ์ดพลังงานและหน่วยอัตโนมัติ

`_EnergyCard` ใช้ `formatEnergy(summary.totalKwh)` จาก `lib/utils/number_format.dart` ได้ทั้งตัวเลขและหน่วย แล้วแสดงตัวเลขขนาด 42 คู่กับหน่วยขนาด 16
คอมเมนต์อธิบายว่า "สลับหน่วยตามขนาดของค่า ที่ชาร์จมือถือระดับ 0.005 kWh จะได้ไม่กลายเป็น 0.0" (รายละเอียดฟังก์ชันอยู่ในหัวข้อกราฟ)

> [!NOTE] ประโยคค่าไฟประกอบเป็นอังกฤษก่อนแปล
> โค้ดเขียน `'Estimated cost: THB ' '${formatDecimal(electricityCost)}'` เป็นสตริงเดียวแล้วให้ตัวแปลจัดทั้งก้อน
> คอมเมนต์บอกว่าถ้าแปลทีละคำแล้วต่อกัน จะได้ "ค่าไฟโดยประมาณ: บาท 1,420.13" ซึ่งผิดลำดับภาษาไทย

### กดใบแจ้งเตือนและ "Mark as handled"

- แตะใบแจ้งเตือน → หา `Room` จากหมายเลขห้องด้วย `_room(alert.roomNumber)` → ถ้าเจอเรียก `onOpenRoom(room)` (= `AppShell._openRoom`)
- ปุ่ม "Mark as handled" แสดงเฉพาะใบที่ `alert.isOpen` กดแล้วเรียก `_acknowledge` → `dashboardController.acknowledge(alert.id)` ถ้าพังแสดง SnackBar แดง

```dart
Future<void> _acknowledge(BuildContext context, SystemAlert alert) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await dashboardController.acknowledge(alert.id);
  } catch (error) {
    messenger
```

1. **บรรทัด 2** — ดึง `ScaffoldMessenger` **ก่อน** await เพราะ HomeScreen เป็น Stateless ไม่มี `mounted` ให้เช็ก ถ้าใช้ `context` หลัง await อาจเป็น context ที่ตายแล้ว เก็บตัว messenger ไว้ก่อนจึงปลอดภัยกว่า

ป้ายสถานะของใบ: `'open'` → "Pending", `'acknowledged'` → "Handled", อื่น ๆ → "Completed" เวลาแสดงด้วย `formatClock` ที่แปลงเวลา UTC จากเซิร์ฟเวอร์เป็นเวลาเครื่อง (`toLocal()`)

## AnalyticsScreen — หน้าสถิติ

### สิ่งที่ผู้ใช้เห็น

- หัวสีเขียวมุมล่างโค้ง (`_SummaryHeader`): "Energy Summary" + `PeriodSelector` สีขาว, ช่วงวันที่, ยอดรวมพลังงาน, ค่าไฟ "≈ THB ...", ป้าย `ChangeBadge` (ขึ้น/ลงกี่ % เทียบช่วงก่อน), และกราฟ `EnergyUsageChart` สูง 162 px
- `FloorSelector` (แสดงเมื่อมีมากกว่า 1 ชั้น) มีตัวเลือก "All floors"
- หัวข้อ "Usage by Room" + ชั้นที่เลือก
- การ์ดรายห้อง (`_UsageRoomCard`): จำนวนเครื่อง, ชั้น·ห้อง, เวลาทำงานเป็นนาที, พลังงาน และค่าไฟ

### หน่วยร่วมของการ์ดทุกใบ

ไฟล์: lib/screens/analytics_screen.dart

```dart
final summary = dashboardController.summary;
final floors = rooms.map((room) => room.floor).toSet().toList()
  ..sort();
final visibleRooms = dashboardController.floor == null
    ? summary.rooms
    : summary.rooms
          .where(
            (usage) =>
                usage.floorNumber == dashboardController.floor,
          )
          .toList();
// ทุกการ์ดใช้หน่วยเดียวกัน คิดจากห้องที่กินไฟมากสุดของรายการที่เห็น
// ไม่งั้น 900 Wh จะดูเหมือนมากกว่า 1.2 kWh
final roomScale = energyScaleReference(
  visibleRooms.map((usage) => usage.kwh),
);
```

1. **บรรทัด 2–3** — หาชั้นทั้งหมดที่มี: `map` เอาเลขชั้น → `toSet()` ตัดซ้ำ → `toList()..sort()` เรียง
2. **บรรทัด 4–11** — ถ้าเลือก "ทุกชั้น" (`floor == null`) ใช้ทุกห้อง ไม่งั้นกรองเฉพาะชั้นนั้น
3. **บรรทัด 14–16** — หาค่ามากที่สุดของรายการที่เห็น ใช้เป็น `scaleReference` ให้ทุกการ์ด เพื่อทุกใบใช้หน่วยและทศนิยมเดียวกัน

FloorSelector ใช้ค่า `-1` แทน "ทุกชั้น" แล้วแปลงกลับเป็น `null` ก่อนส่ง `dashboardController.setFloor(floor == -1 ? null : floor)`
`setFloor` ใน controller จะยิงคำขอใหม่โดยส่ง `floor` ไปให้ Backend ด้วย

> [!NOTE] ยอดรวมใช้หน่วยของตัวเอง
> ใน `_SummaryHeader` เรียก `formatEnergy(summary.totalKwh)` โดยไม่มี scaleReference เพราะเป็นตัวเลขเดี่ยว ไม่ต้องเทียบกับใคร

## PeriodSelector — เลือกช่วงเวลา

### สิ่งที่ผู้ใช้เห็น

ปุ่มทรงแคปซูล แสดงช่วงปัจจุบัน ("Today", "Last 7 days", "Last 30 days" หรือช่วงวันที่ที่เลือกเอง เช่น "1 ส.ค. – 5 ส.ค.") กดแล้วเป็นเมนูดรอปดาวน์
ใช้สองที่: การ์ดพลังงานหน้า Home (พื้นสว่าง) และหัวหน้า Analytics (`onSurfaceDark: true` ตัวอักษรขาว)
ทั้งสองที่ใช้ `DashboardController` ตัวเดียวกัน เปลี่ยนที่หนึ่ง อีกที่เปลี่ยนตาม

### โค้ดหลัก

ไฟล์: lib/widgets/period_selector.dart

```dart
Future<void> _choose(BuildContext context, EnergyPeriodKind kind) async {
  if (kind != EnergyPeriodKind.custom) {
    await controller.setPeriod(kind);
    return;
  }
  await pickCustomRange(context, controller);
}
```

1. **บรรทัด 2–4** — ช่วงสำเร็จรูป (day/week/month) ส่งให้ controller ตรง ๆ controller ตั้งค่า แจ้ง UI แล้วยิงคำขอใหม่
2. **บรรทัด 6** — "กำหนดเอง" ต้องเลือกวันก่อน จึงเปิดปฏิทินแทน (ไม่เรียก `setPeriod(custom)` ตรง ๆ ช่วงจะยังไม่ถูกเปลี่ยนถ้าผู้ใช้กดยกเลิกปฏิทิน)

ส่วนสร้างดรอปดาวน์ใช้ `DropdownButton<EnergyPeriodKind>` ที่มีสองรายการคู่กัน

- `items:` = ตัวเลือกในเมนูที่กางออก แสดงชื่อช่วง (`kind.label` แปลแล้ว)
- `selectedItemBuilder:` = ข้อความบนปุ่มเมื่อปิดเมนู ถ้าเป็น custom จะแสดงช่วงวันที่จริงผ่าน `describeCustomRange` แทนคำว่า "Custom range"
- `onChanged:` เรียก `_choose`

```dart
Future<void> pickCustomRange(
  BuildContext context,
  DashboardController controller,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final initial = controller.customFrom != null && controller.customTo != null
      ? DateTimeRange(
          start: controller.customFrom!,
          end: controller.customTo!,
        )
      : DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );

  final picked = await showAppDateRangePicker(
    context: context,
    firstDate: DateTime(2024),
    lastDate: today,
    initialRange: initial,
    title: context.tr('Pick a date range'),
  );
  if (picked == null) return;
  await controller.setCustomRange(picked.start, picked.end);
}
```

1. **บรรทัด 5–6** — ตัดเวลาออกเหลือแค่วันที่ของวันนี้
2. **บรรทัด 7–15** — ช่วงตั้งต้นของปฏิทิน: ถ้าเคยเลือกไว้ใช้ช่วงเดิม ไม่งั้นใช้ 7 วันล่าสุด
3. **บรรทัด 17–23** — เปิดปฏิทินช่วงวัน (ฟังก์ชันช่วยใน `lib/utils/thai_date.dart` รองรับภาษาไทย) เลือกได้ตั้งแต่ปี 2024 ถึงวันนี้ (`lastDate: today` กันเลือกอนาคต)
4. **บรรทัด 24** — กดยกเลิก → `null` → ไม่ทำอะไร
5. **บรรทัด 25** — ส่งช่วงให้ controller ซึ่งสลับ from/to ให้ถ้าเลือกกลับด้าน แล้วโหลดใหม่

`ChangeBadge` (อยู่ในไฟล์เดียวกัน): ถ้า `changePercent == null` แสดง "No earlier data to compare" ไม่งั้นแสดงลูกศรลง (สีเขียว เมื่อ ≤ 0) หรือขึ้น (สีแดง) พร้อมเปอร์เซ็นต์ ค่า ≥ 10 ไม่มีทศนิยม ค่า < 10 มีทศนิยม 1 ตำแหน่ง

> [!TIP] สีเขียวแปลว่า "ใช้ไฟลดลง"
> ในแอปประหยัดพลังงาน การใช้ไฟลดลงคือข่าวดี จึงใช้สีเขียวกับลูกศรลง และสีแดงกับลูกศรขึ้น ตรงข้ามกับกราฟหุ้น

## EnergyUsageChart — กราฟแท่งพลังงาน

> [!NOTE]
> **ทำไมเป็นกราฟแท่ง** หน้าสถิติแสดง **หนึ่งแท่งต่อหนึ่งชั่วโมงหรือหนึ่งวัน** (`lib/widgets/energy_usage_chart.dart` 579 บรรทัด กล่องกราฟสูง 190 px) ถ้าใช้กราฟเส้นที่มีป้ายตัวเลขเหนือทุกจุด พอเลือก "วันนี้" (24 จุด) หรือ "30 วัน" ป้ายจะเบียดกันจนต้องข้ามบางป้าย และช่วงที่ไม่ใช้ไฟจะมีป้าย `0.00 kWh` ซ้ำเต็มแกน

### หลักการออกแบบ 5 ข้อ (จากคอมเมนต์หัวคลาส)

| ข้อ | กติกา | ทำไม |
|---|---|---|
| 1 | ไม่เขียนตัวเลขทุกแท่ง มีป้ายเฉพาะ **แท่งสูงสุด** ("สูงสุด 3.20 kWh") ค่าแท่งอื่นแตะเพื่อดู | 24–30 ป้ายบนจอมือถืออ่านไม่ออก คนส่วนใหญ่อยากรู้แค่ "ช่วงไหนใช้มากสุด" |
| 2 | ช่วงที่ไม่ใช้ไฟเหลือ **ขีดจาง ๆ** ไม่มีป้าย `0.00 kWh` | ยังรู้ว่ามีช่วงนี้อยู่ แต่ไม่แย่งสายตา |
| 3 | แกนตั้งเป็น **ตัวเลขกลม 3 ระดับ** (0, กลาง, บนสุด) และบอกหน่วยไว้บนสุดที่เดียว | แกนที่จบที่ 3.56 อ่านยาก จบที่ 4 มีเส้นกลางที่ 2 อ่านง่ายกว่ามาก |
| 4 | ป้ายแกนนอน: รายชั่วโมงทุก 6 ชม., ไม่เกิน 10 วันเป็นชื่อวันย่อ, เกินนั้นเป็นวันที่ทุก 7 วันกับวันสุดท้าย | 24 ป้ายเวลาเบียดกันจนอ่านไม่ได้ คนจำ "วันจันทร์" ได้ง่ายกว่า "5 ต.ค." |
| 5 | ข้อมูลรายวันตั้งแต่ 7 วันขึ้นไปมี **เส้นประค่าเฉลี่ยต่อวัน** (สีเหลือง) | เห็นทันทีว่าวันไหนสูงกว่าปกติ |

และกติกาเดิมที่ยังอยู่: **ทุกแท่งใช้หน่วยเดียวกัน** คิดจากค่าสูงสุดของชุด (`energyScaleReference`) ไม่งั้นแท่ง `900 Wh` จะดูเหมือนมากกว่า `1.2 kWh`

### โครงสร้างของไฟล์

```text
EnergyUsageChart (StatefulWidget, จำ _selectedIndex = แท่งที่ผู้ใช้แตะ)
 └─ LayoutBuilder (รู้ขนาดจริง)
     └─ GestureDetector (แตะ / ลากแนวนอน)
         └─ Stack
             ├─ CustomPaint(EnergyChartPainter)   ← วาดแกน แท่ง เส้นเฉลี่ย ป้าย
             └─ _Tooltip (ถ้ามีแท่งที่เลือก)       ← กล่องขาว วันที่ + พลังงาน + ค่าเงิน

ฟังก์ชันระดับไฟล์: axisLabelsFor, clampToBox, niceScaleMax, _tickText, _sameItems
คลาสพิกัด: EnergyChartGeometry (ใช้ร่วมกันระหว่างตัววาดกับตัวรับสัมผัส)
```

### ส่วน build: เตรียมข้อมูลก่อนวาด

ไฟล์ `lib/widgets/energy_usage_chart.dart` บรรทัด 66–78

```dart:66
    final isThai = AppLocalizations.of(context).isThai;
    final values = widget.points.map((point) => point.kwh).toList();
    final reference = energyScaleReference(values);
    final daily = widget.points.every((point) => point.hour == null);

    String? averageLabel;
    if (daily && values.length >= 7) {
      final average = values.reduce((a, b) => a + b) / values.length;
      if (average > 0) {
        final text = formatEnergy(average, scaleReference: reference).text;
        averageLabel = isThai ? 'เฉลี่ย $text/วัน' : 'Avg $text/day';
      }
    }
```

| บรรทัด | อธิบาย |
|---|---|
| 67 | ดึงเฉพาะค่า kWh ของทุกจุดเป็นลิสต์ตัวเลข |
| 68 | ค่าสูงสุดของชุด ใช้เลือกหน่วยร่วมของทั้งกราฟ |
| 69 | ข้อมูลเป็น **รายวัน** ถ้าทุกจุดไม่มี `hour` (ข้อมูล "วันนี้" ทุกจุดมี `hour` 0–23) |
| 71–78 | เส้นเฉลี่ยมีเฉพาะรายวันตั้งแต่ 7 จุด และค่าเฉลี่ยต้องมากกว่า 0 (ทั้งช่วงไม่ใช้ไฟเลยก็ไม่ต้องมีเส้น) ส่ง `null` = ไม่วาด |

ถ้ามีจุดน้อยกว่า 2 จุด (บรรทัด 57–64) แสดงข้อความ "ข้อมูลยังไม่พอวาดกราฟ" แทน

### ป้ายแกนนอน: `axisLabelsFor`

ไฟล์ `lib/widgets/energy_usage_chart.dart` บรรทัด 147–167

```dart:147
String _axisLabel(
  EnergySeriesPoint point,
  int index,
  int last,
  bool hourly,
  bool isThai,
) {
  if (hourly) {
    final hour = point.hour!;
    if (hour % 6 == 0) return '${hour.toString().padLeft(2, '0')}:00';
    return '';
  }

  final date = DateTime.tryParse(point.date);
  if (date == null) return index == 0 || index == last ? point.label : '';

  if (last + 1 <= 10) return formatWeekdayShort(date, isThai);
  if (index == last) return formatDayMonth(date, isThai);
  if (index % 7 == 0 && index < last - 3) return formatDayMonth(date, isThai);
  return '';
}
```

| บรรทัด | อธิบาย |
|---|---|
| 154–158 | รายชั่วโมง: เขียนเฉพาะชั่วโมงที่หาร 6 ลงตัว ได้ `00:00`, `06:00`, `12:00`, `18:00` ที่เหลือคืน `''` (= ไม่ต้องเขียน) |
| 160–161 | อ่านวันที่ไม่ได้ (ข้อมูลแปลก) ใช้ป้ายจาก Backend เฉพาะแท่งแรกกับแท่งสุดท้าย |
| 163 | จำนวนแท่งไม่เกิน 10 (เช่น 7 วัน) เขียนชื่อวันย่อทุกแท่ง `ส อา จ อ พ พฤ ศ` |
| 164 | มากกว่านั้น แท่งสุดท้ายเขียนวันที่เสมอ (วันล่าสุดคือวันที่คนอยากรู้) |
| 165 | แท่งที่ 0, 7, 14, 21 เขียนวันที่ **ยกเว้น** ตัวที่ชิดแท่งสุดท้ายเกินไป (`index < last − 3`) กันป้ายสองตัวทับกัน |

ตัวอย่างจากเทสต์: 30 วันได้ป้ายที่แท่ง `[0, 7, 14, 21, 29]` แท่ง 28 ไม่ได้ป้ายเพราะ 28 ไม่น้อยกว่า 29 − 3 = 26

### ตัวเลขกลมของแกนตั้ง: `niceScaleMax`

ไฟล์ `lib/widgets/energy_usage_chart.dart` บรรทัด 277–291

```dart:277
double niceScaleMax(double value) {
  if (value <= 0) return 1;
  var magnitude = 1.0;
  while (magnitude * 10 <= value) {
    magnitude *= 10;
  }
  while (magnitude > value) {
    magnitude /= 10;
  }
  for (final step in const [1.0, 2.0, 2.5, 4.0, 5.0, 10.0]) {
    final candidate = step * magnitude;
    if (candidate >= value - 1e-9) return candidate;
  }
  return 10 * magnitude;
}
```

| บรรทัด | อธิบาย |
|---|---|
| 278 | ไม่มีข้อมูลหรือเป็น 0 ทั้งหมด ใช้ 1 (กันหารด้วยศูนย์ตอนคำนวณความสูงแท่ง) |
| 279–285 | หา "หลัก" ของตัวเลข (กำลังของ 10 ที่ไม่เกินค่า) เช่น 3.56 → 1, 17.3 → 10, 212 → 100, 0.42 → 0.1 ลูปแรกขยายขึ้น ลูปที่สองหดลงสำหรับค่าน้อยกว่า 1 |
| 286–289 | ลองคูณหลักด้วย 1, 2, 2.5, 4, 5, 10 ตามลำดับ เอาตัวแรกที่ไม่น้อยกว่าค่าจริง `1e-9` คือค่าเผื่อความคลาดเคลื่อนของทศนิยมแบบ floating point |

| ค่าจริง | หลัก | ผล | เส้นกลาง |
|---|---|---|---|
| 3.56 | 1 | 4 | 2 |
| 17.3 | 10 | 20 | 10 |
| 0.42 | 0.1 | 0.5 | 0.25 |
| 212 | 100 | 250 | 125 |
| 0.005 | 0.001 | 0.005 | 0.0025 |

> [!NOTE]
> คอมเมนต์ของฟังก์ชันเขียนว่า "(1, 2, 2.5, 5 × 10^n)" แต่ลิสต์จริงมี `4.0` ด้วย (3.56 จึงได้ 4 ไม่ใช่ 5 ตามที่เทสต์ตรวจไว้) เป็นคอมเมนต์ที่ไม่ครบ ไม่ใช่บั๊ก

### พิกัดของแท่ง (ใช้ร่วมระหว่างตัววาดกับตัวรับสัมผัส)

ไฟล์ `lib/widgets/energy_usage_chart.dart` บรรทัด 296–347

```dart:296
abstract final class EnergyChartGeometry {
  /// เว้นซ้ายไว้ให้ตัวเลขแกนตั้ง
  static const double left = 30;

  /// เว้นด้านบนไว้ให้ป้ายค่าสูงสุดและหน่วยของแกน
  static const double top = 22;
  static const double bottom = 22;
  static const double right = 4;

  /// ความกว้างของช่องหนึ่งแท่ง
  static double slot(Size size, int count) {
    if (count <= 0) return 0;
    return (size.width - left - right) / count;
  }

  /// ความกว้างของตัวแท่งเอง เว้นช่องไฟ ~40% และไม่อ้วนเกิน 28 px
  static double barWidth(Size size, int count) {
    final width = slot(size, count) * 0.62;
    if (width > 28) return 28;
    if (width < 1.5) return 1.5;
    return width;
  }

  /// แท่งที่อยู่ตรง [dx] (คิดทั้งช่อง ไม่ต้องแตะโดนตัวแท่งพอดี)
  static int? indexAt(double dx, Size size, int count) {
    final width = slot(size, count);
    if (width <= 0) return null;
    final index = ((dx - left) / width).floor();
    if (index < 0) return 0;
    if (index >= count) return count - 1;
    return index;
  }

  /// จุดกึ่งกลางยอดของแต่ละแท่ง
  static List<Offset> resolve(Size size, List<double> values) {
    if (values.length < 2) return const [];

    final chartHeight = size.height - top - bottom;
    final width = slot(size, values.length);
    if (chartHeight <= 0 || width <= 0) return const [];

    final maxValue = niceScaleMax(energyScaleReference(values));

    return [
      for (var i = 0; i < values.length; i++)
        Offset(
          left + width * (i + 0.5),
          top + chartHeight * (1 - (values[i] / maxValue).clamp(0.0, 1.0)),
        ),
    ];
  }
}
```

| บรรทัด | อธิบาย |
|---|---|
| 296 | `abstract final class` = คลาสที่สร้าง object ไม่ได้และสืบทอดไม่ได้ ใช้เป็น "กล่องเก็บค่าคงที่กับฟังก์ชัน static" ล้วน ๆ |
| 298–303 | ระยะขอบ: ซ้าย 30 px ให้ตัวเลขแกนตั้ง บน 22 px ให้ป้าย "สูงสุด" และหน่วย ล่าง 22 px ให้ป้ายแกนนอน |
| 306–309 | แบ่งความกว้างที่เหลือเป็นช่องเท่า ๆ กัน หนึ่งช่องต่อหนึ่งแท่ง |
| 312–317 | ตัวแท่งกว้าง 62% ของช่อง (ช่องไฟ ~38%) แต่ไม่เกิน 28 px (7 วันบนจอกว้างแท่งจะไม่อ้วนเกิน) และไม่ต่ำกว่า 1.5 px (ยังมองเห็น) |
| 320–327 | **รับสัมผัสทั้งช่อง** ไม่ต้องแตะโดนแท่งเป๊ะ เช่น แท่งสูง 2 px ก็แตะช่องเหนือมันได้ หารเอาจำนวนเต็ม (`floor`) แล้วบีบไม่ให้หลุดซ้ายสุด/ขวาสุด ทำให้ลากนิ้วเลยขอบก็ยังเลือกแท่งริม |
| 337 | ความสูงเทียบกับ "ตัวเลขกลม" ไม่ใช่ค่าสูงสุดจริง แท่งสูงสุดจึงอาจไม่ชนเพดาน (3.56 จาก 4 = 89%) |
| 341–344 | x = กึ่งกลางช่อง (`i + 0.5`), y = ยิ่งค่ามากยิ่งอยู่สูง (พิกัดจอ y นับจากบนลงล่าง จึงใช้ `1 − สัดส่วน`) `clamp(0, 1)` กันแท่งทะลุกรอบ |

> [!WHY]
> **ทำไมแยกพิกัดเป็นคลาสกลาง** ถ้าตัววาดกับตัวรับสัมผัสคำนวณพิกัดแยกกัน วันหนึ่งที่แก้ระยะขอบที่เดียว แท่งที่แตะได้จะเลื่อนไม่ตรงกับแท่งที่เห็น (คอมเมนต์ในโค้ดเขียนเหตุผลนี้ไว้) การมีสูตรเดียวทำให้เทสต์พิกัดได้โดยไม่ต้องวาดจริง เช่น เทสต์ "แตะตรงไหนของช่องก็ได้แท่งของช่องนั้น และไม่หลุดขอบ"

> [!NOTE]
> `indexAt` คำนวณแท่งที่นิ้วแตะตรง ๆ ด้วยการหารครั้งเดียว (O(1)) เพราะแท่งเรียงห่างเท่ากันเสมอ ไม่ต้องวนหาจุดที่ใกล้นิ้วที่สุดทุกครั้งที่ลาก (O(n)) แบบกราฟเส้น

### การวาดแท่ง

ไฟล์ `lib/widgets/energy_usage_chart.dart` บรรทัด 397–427

```dart:397
    final barWidth = EnergyChartGeometry.barWidth(size, values.length);
    final largest = values.reduce((a, b) => a > b ? a : b);
    final peakIndex = largest > 0 ? values.indexOf(largest) : -1;
    final selected = selectedIndex;
    final radius = Radius.circular(barWidth >= 6 ? 3 : 1);

    for (var i = 0; i < points.length; i++) {
      final x = points[i].dx - barWidth / 2;
      if (values[i] <= 0) {
        // ไม่ใช้ไฟเลย เหลือขีดจาง ๆ ให้รู้ว่ามีช่วงนี้อยู่ แต่ไม่แย่งสายตา
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, bottomY - 2.5, barWidth, 2.5),
            const Radius.circular(1),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.22),
        );
        continue;
      }
      // ค่าเล็กมากก็ยังต้องเห็นเป็นแท่ง ไม่ใช่หายไปกับเส้นฐาน
      final barTop = points[i].dy > bottomY - 2.5 ? bottomY - 2.5 : points[i].dy;
      final highlighted = i == selected || (selected == null && i == peakIndex);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(x, barTop, x + barWidth, bottomY),
          topLeft: radius,
          topRight: radius,
        ),
        Paint()..color = highlighted ? Colors.white : _barColor,
      );
    }
```

| บรรทัด | อธิบาย |
|---|---|
| 398–399 | หาแท่งสูงสุด ถ้าทุกแท่งเป็น 0 ได้ `-1` (ไม่มีแท่งสูงสุด ไม่ต้องมีป้าย) |
| 401 | มุมมนบนแท่ง 3 px ถ้าแท่งกว้างพอ แท่งผอม (30 วันบนจอแคบ) ใช้ 1 px ไม่งั้นมุมมนจะกินทั้งแท่ง |
| 404 | x ซ้ายของแท่ง = กึ่งกลางช่อง − ครึ่งความกว้างแท่ง |
| 405–415 | ค่า 0: วาดขีดสูง 2.5 px สีขาวโปร่ง 22% แล้วข้ามไปแท่งถัดไป (`continue`) |
| 417 | ค่าเล็กมาก (เช่น 5 Wh ในกราฟที่สูงสุด 3 kWh) จะคำนวณได้สูงไม่ถึง 1 px บังคับให้สูงอย่างน้อย 2.5 px **ให้ต่างจากค่า 0** ผู้ใช้จึงแยกได้ว่า "ใช้นิดเดียว" กับ "ไม่ใช้เลย" |
| 418 | แท่งที่เป็นสีขาว (เด่น): แท่งที่ผู้ใช้แตะ หรือถ้ายังไม่แตะอะไร = แท่งสูงสุด |
| 419–426 | `RRect.fromRectAndCorners` มนเฉพาะมุมบนซ้าย/ขวา ฐานแท่งตรง แท่งปกติสีเขียวอ่อน `0xFFBFE8CF` บนพื้นหัวสีเขียวของหน้าสถิติ |

หลังวาดแท่ง ตัววาดทำต่ออีก 3 อย่าง

- **เส้นเฉลี่ย** (`_paintAverage`, บรรทัด 491–525) Canvas ของ Flutter ไม่มีเส้นประในตัว จึงวาดเส้นสั้น 4 px เว้น 4 px วนไปจนสุดขอบ (`for (var x = left; x < right; x += 8)`) แล้วเขียนป้าย "เฉลี่ย 2.10 kWh/วัน" ชิดขวาเหนือเส้น
- **ป้ายแท่งสูงสุด** (บรรทัด 431–449) เขียน "สูงสุด 3.20 kWh" เหนือแท่ง **ซ่อนเมื่อมีแท่งที่เลือกอยู่** เพราะกล่องรายละเอียดบอกค่าแล้ว ตำแหน่ง x ผ่าน `clampToBox` ไม่ให้ล้นขอบ y ติดลบให้เป็น 0
- **ป้ายแกนนอน** (`_paintAxisLabels`, บรรทัด 527–543) ข้ามช่องที่เป็น `''` และถ้าป้ายจะชนป้ายก่อนหน้า (ห่างน้อยกว่า 4 px) ข้ามป้ายนั้นไป ป้องกันกรณีจอแคบมาก

### เส้นตารางและตัวเลขแกนตั้ง

ไฟล์ `lib/widgets/energy_usage_chart.dart` บรรทัด 462–488

```dart:462
    final reference = formatEnergy(maxValue);
    final factor = switch (reference.unit) {
      'Wh' => 1000.0,
      'MWh' => 0.001,
      _ => 1.0,
    };
    const style = TextStyle(color: _mutedText, fontSize: 9);

    for (var i = 0; i <= 2; i++) {
      final y = top + chartHeight * i / 2;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        Paint()
          ..color = Colors.white.withValues(alpha: i == 2 ? 0.45 : 0.18)
          ..strokeWidth = 1,
      );
      final value = maxValue * (2 - i) / 2 * factor;
      final painter = _text(_tickText(value), style);
      painter.paint(
        canvas,
        Offset(left - painter.width - 5, y - painter.height / 2),
      );
    }

    // หน่วยของแกนอยู่บนสุดที่เดียว ไม่ต้องติดทุกตัวเลข
    _text(reference.unit, style).paint(canvas, const Offset(0, 0));
```

| บรรทัด | อธิบาย |
|---|---|
| 462–467 | ใช้ `formatEnergy` หาหน่วยของค่าบนสุด แล้วหา "ตัวคูณ" แปลง kWh เป็นหน่วยนั้น (Wh คูณ 1000, MWh คูณ 0.001) ใช้ `switch` แบบ expression ของ Dart 3 |
| 470–477 | เส้นแนวนอน 3 เส้น: บน (i=0), กลาง (i=1), ฐาน (i=2) เส้นฐานเข้มกว่า (45%) อีกสองเส้นจาง (18%) |
| 478 | ค่าของแต่ละเส้น: บน = เต็ม, กลาง = ครึ่ง, ฐาน = 0 |
| 479–483 | `_tickText` ตัดศูนย์ท้ายทิ้ง (`4.00` → `4`, `2.50` → `2.5`) แล้ววางชิดขวาของพื้นที่ว่างด้านซ้าย กึ่งกลางแนวตั้งตรงกับเส้น |
| 488 | เขียนหน่วย (`kWh`) มุมบนซ้ายครั้งเดียว ตัวเลขแกนจึงสั้น |

### การแตะ/ลากเพื่อดูรายละเอียด

ไฟล์ `lib/widgets/energy_usage_chart.dart` บรรทัด 47–53

```dart:47
  void _selectAt(double dx, Size size, {bool toggle = false}) {
    final index = EnergyChartGeometry.indexAt(dx, size, widget.points.length);
    if (index == null) return;
    setState(() {
      _selectedIndex = toggle && _selectedIndex == index ? null : index;
    });
  }
```

`GestureDetector` เรียก `_selectAt(..., toggle: true)` ตอนแตะ (`onTapDown`) แตะแท่งเดิมซ้ำ = ปิดกล่อง และเรียกแบบไม่ toggle ตอนลากแนวนอน (`onHorizontalDragStart` / `Update`) ผู้ใช้จึงลากนิ้วไล่ดูทีละแท่งได้

เมื่อมีแท่งที่เลือก `_Tooltip` (กล่องขาวกว้าง 132 px) แสดงวันที่ (และชั่วโมงถ้าเป็นรายชั่วโมง) พลังงาน และค่าเงิน วางเหนือยอดแท่ง ถ้าชนขอบบนจะย้ายไปอยู่ใต้ยอดแท่งแทน `didUpdateWidget` (บรรทัด 37–45) ล้างการเลือกถ้าจำนวนแท่งลดลงจนดัชนีเดิมเกินขอบ (เช่น เปลี่ยนจาก 30 วันเป็น "วันนี้")

### `clampToBox` และ `shouldRepaint`

- **`clampToBox(value, limit)`** (บรรทัด 267–272) เขียนเองแทน `value.clamp(0, limit)` เพราะถ้าจอแคบกว่าป้ายหรือกล่อง `limit` จะติดลบ แล้ว `clamp` จะโยน `ArgumentError` (ขอบล่างมากกว่าขอบบน)
- **`shouldRepaint`** (บรรทัด 546–555) เทียบรายการทีละสมาชิกด้วย `_sameItems` แทน `!=` เพราะทุกครั้งที่ build จะสร้าง List ใหม่เสมอ ถ้าเทียบด้วย `!=` จะวาดใหม่ทุกเฟรมโดยไม่จำเป็น และเขียน `_sameItems` เองแทน `listEquals` เพราะไฟล์นี้ import แค่ `localized_material.dart` ซึ่งส่งต่อชื่อจาก `foundation.dart` มาไม่ครบ

### หน่วยอัตโนมัติ W / kWh / MWh

ป้ายทุกใบใช้ `formatEnergy` จาก utils

ไฟล์: lib/utils/number_format.dart

```dart
EnergyDisplay formatEnergy(double kwh, {double? scaleReference}) {
  final reference = (scaleReference ?? kwh).abs();

  // ยังไม่มีข้อมูลเลย แสดง kWh ทศนิยมเดียวตามที่หน้าจออื่นใช้กันอยู่
  if (reference == 0) {
    return EnergyDisplay(
      value: formatDecimal(kwh, decimalPlaces: 1),
      unit: 'kWh',
      decimalPlaces: 1,
    );
  }

  final String unit;
  final double scaled;
  final double scaledReference;

  if (reference >= 1000) {
    unit = 'MWh';
    scaled = kwh / 1000;
    scaledReference = reference / 1000;
  } else if (reference >= 1) {
    unit = 'kWh';
    scaled = kwh;
    scaledReference = reference;
  } else {
    unit = 'Wh';
    scaled = kwh * 1000;
    scaledReference = reference * 1000;
  }

  final decimalPlaces = _energyDecimalPlaces(scaledReference);
  return EnergyDisplay(
    value: formatDecimal(scaled, decimalPlaces: decimalPlaces),
    unit: unit,
    decimalPlaces: decimalPlaces,
  );
}
```

1. **บรรทัด 2** — ค่าอ้างอิงที่ใช้ตัดสินหน่วย ถ้าส่ง `scaleReference` มา (ค่ามากสุดของชุด) ใช้ค่านั้น ไม่งั้นใช้ค่าตัวเอง
2. **บรรทัด 5–11** — ยังไม่มีข้อมูล (0) แสดง `0.0 kWh`
3. **บรรทัด 17–20** — ค่าอ้างอิง ≥ 1000 kWh → หาร 1000 เป็น MWh
4. **บรรทัด 21–24** — 1 ถึง < 1000 → kWh ตามเดิม
5. **บรรทัด 25–29** — น้อยกว่า 1 kWh → คูณ 1000 เป็น Wh
6. **บรรทัด 31** — จำนวนทศนิยมคิดจากค่าอ้างอิงหลังแปลงหน่วย: ≥ 100 → 0 ตำแหน่ง, ≥ 10 → 1, ≥ 1 → 2, น้อยกว่านั้น → 3
7. **บรรทัด 32–36** — คืนตัวเลขที่คั่นหลักพันแล้ว (`formatDecimal`) + หน่วย ใช้ `.text` ได้ข้อความเต็ม เช่น `5.00 Wh`

ตัวอย่างผลลัพธ์จริง: 0.005 kWh → `5.00 Wh`, 12.5 kWh → `12.5 kWh`, 2400 kWh → `2.40 MWh`

> [!WHY] ทำไมทั้งกราฟต้องใช้หน่วยเดียวกัน
> ค่าในโปรเจกต์นี้กว้างมาก ตั้งแต่ที่ชาร์จมือถือ 0.005 kWh ถึงแอร์ทั้งอาคารหลักพัน kWh ถ้าตรึงไว้ที่ kWh ค่าน้อยจะกลายเป็น `0.0`
> แต่ถ้าแต่ละแท่งเลือกหน่วยเอง ป้าย `900 Wh` จะดูเหมือนมากกว่า `1.2 kWh` คนอ่านเปรียบเทียบผิด
> จึงส่งค่ามากสุดของชุดเป็น `scaleReference` ให้ทุกแท่ง ป้ายสูงสุด เส้นเฉลี่ย และกล่องรายละเอียดได้หน่วยและจำนวนทศนิยมเดียวกัน

> [!ASK]
> **ถาม:** ทำไมเปลี่ยนจากกราฟเส้นเป็นกราฟแท่ง?
> **ตอบ:** ข้อมูลเป็นพลังงาน "สะสมต่อช่วง" (kWh ต่อชั่วโมง/ต่อวัน) แต่ละช่วงแยกจากกัน กราฟแท่งสื่อความหมายนี้ตรงกว่า ส่วนกราฟเส้นทำให้ดูเหมือนค่าต่อเนื่องระหว่างจุด (เหมือนกำลังไฟ ณ เวลานั้น) อีกเหตุผลคืออ่านง่ายบนจอมือถือ: ถ้ามีป้ายทุกจุด พอ 24–30 จุดก็เบียดกัน กราฟนี้จึงมีป้ายแค่แท่งสูงสุด ค่า 0 เป็นขีดจาง แกนตั้งเป็นตัวเลขกลม และมีเส้นเฉลี่ยให้เทียบ ค่าแท่งอื่นแตะดูได้

> [!NOTE]
> การเปลี่ยนนี้เป็นของแอปมือถือเท่านั้น เว็บแอปยังใช้กราฟเส้นพื้นที่ (`areaChart` ใน `webapp/assets/js/charts.js` ดูบทเว็บแอป) ตัวเลขที่ได้ตรงกันเพราะมาจาก `GET /energy/summary` ตัวเดียวกัน ต่างแค่การแสดงผล

## RoomsScreen — แท็บควบคุม (เลือกห้อง)

### สิ่งที่ผู้ใช้เห็น

- แถบหัว "Choose a Room to Control" และปุ่มเฟือง "Manage Rooms" (เฉพาะแอดมิน เปิด `RoomManagementScreen`)
- `FloorSelector` เลือกชั้น (เริ่มที่ชั้น 3)
- หัว "Floor N" + ป้าย "X rooms"
- การ์ดห้อง (`_RoomCard`): ไอคอนแอร์, "Room 1601", ป้ายจำนวนเครื่อง, ประเภทห้อง, นับถอยหลังปิดแอร์ (ถ้ามี), สถานะคน (Occupied/Vacant/Sensor unavailable/No sensor), จุดเขียว/แดง Online/Offline

ข้อมูลจาก `widget.rooms` (List เดียวกับที่ `RoomController` ดูแล) และ `RoomController.isLoading/hasLoaded/reload`
หน้านี้ไม่มี `AnimatedBuilder` ของตัวเอง แต่ rebuild ได้เพราะ AppShell ห่อทุกแท็บด้วย `AnimatedBuilder` ที่ฟัง `_roomController` อยู่แล้ว

### เลือกชั้นอย่างปลอดภัย

ไฟล์: lib/screens/rooms_screen.dart

```dart
final colors = Theme.of(context).colorScheme;
final floors = widget.rooms.map((room) => room.floor).toSet().toList()
  ..sort();
if (floors.isEmpty) {
  _selectedFloor = 0;
} else if (!floors.contains(_selectedFloor)) {
  _selectedFloor = floors.first;
}
final filteredRooms = widget.rooms
    .where((room) => room.floor == _selectedFloor)
    .toList();
```

1. **บรรทัด 2–3** — ชั้นที่มีจริงจากข้อมูลห้อง
2. **บรรทัด 4–8** — ถ้าชั้นที่เลือกไว้ไม่มีอยู่จริง (เช่น ข้อมูลจาก Backend ไม่มีชั้น 3) เลื่อนไปชั้นแรกที่มี
3. **บรรทัด 9–11** — กรองเฉพาะห้องของชั้นที่เลือก

การ์ดห้องแสดง `AutoOffCountdown(compact: true)` เมื่อ `room.isAutoOffPending` (มี `autoOffDeadlineAt`) และแตะการ์ดแล้วเรียก `widget.onOpenRoom(room)`

> [!NOTE] เปลี่ยนค่า State ใน build
> โค้ดแก้ `_selectedFloor` ตรง ๆ ใน build (ไม่ผ่าน setState) ทำได้เพราะเป็นการปรับค่าก่อนนำไปใช้ในการ build รอบเดียวกันนั้นเอง
> ไม่ต้องสั่ง build ซ้ำ แต่เป็นรูปแบบที่ต้องระวังไม่ให้ใช้กับงานที่มีผลข้างเคียง

## RoomControlScreen — หน้าควบคุมห้อง

### สิ่งที่ผู้ใช้เห็น

- `AppBar`: "Room 1601" + ประเภทห้อง และปุ่มรีเฟรช (เป็นวงหมุนขณะโหลด)
- การ์ดสรุปห้อง (`_RoomSummaryCard`): จำนวนแอร์ที่เปิด / ทั้งหมด, กำลังไฟรวม (kW), แถว "ESP32 online", "Control mode: MQTT (real devices)", "Occupancy sensor" + เมนู (แอดมิน: Reconfigure / Add sensor / Remove)
- กล่อง error (ถ้าโหลดแอร์ไม่สำเร็จ)
- หัว "Air conditioner list" + "N / 6 units"
- การ์ดแอร์ (`AirControlCard`) ทีละเครื่อง หรือ `_EmptyAirCard` ถ้ายังไม่มี ESP32
- ปุ่มล่าง (แอดมิน): "Add sensor" (ถ้ายังไม่มีเซนเซอร์) และ "Add ESP32 device" (ปิดเมื่อครบ 6 เครื่อง)

### อ่านห้องล่าสุดเสมอ และดึงข้อมูลทันทีที่เปิด

ไฟล์: lib/screens/room_control_screen.dart

```dart
// RoomController.reload() สร้าง Room object ใหม่ทุกครั้ง ถ้าหน้าจอนี้ยึด
// object ที่ได้ตอนเปิดหน้า ค่าที่โหลดมาใหม่จะไม่ขึ้นจนกว่าจะออกแล้วเข้าห้อง
// ใหม่ จึงต้องอ่านห้องล่าสุดจาก controller ทุกครั้งที่ build
Room get room =>
    widget.roomController.roomByNumber(widget.room.number) ?? widget.room;

@override
void initState() {
  super.initState();
  // ดึงค่าล่าสุดทันทีที่เปิดห้อง ไม่ต้องรอรอบอัตโนมัติ 10 วินาที
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _refreshAll();
  });
}
```

1. **บรรทัด 4–5** — getter `room` ค้นห้องจาก controller ด้วยหมายเลขห้องทุกครั้งที่ถูกเรียก ถ้าหาไม่เจอ (เช่น ห้องถูกลบ) ใช้ object เดิมที่ได้ตอนเปิด
2. **บรรทัด 11** — `addPostFrameCallback` = "ทำหลังวาดเฟรมแรกเสร็จ" หน้าจอจึงขึ้นทันทีด้วยข้อมูลที่มีอยู่ แล้วค่อยดึงข้อมูลใหม่
3. **บรรทัด 12** — เช็ก mounted เผื่อผู้ใช้กดออกเร็วมาก แล้วเรียก `_refreshAll`

> [!WHY] ทำไมไม่เรียก _refreshAll() ใน initState ตรง ๆ
> `refresh()` ของ controller เรียก `notifyListeners()` ทันทีตอนเริ่ม (เพื่อแสดงวงหมุน) ถ้าเกิดระหว่างที่ Flutter กำลัง build หน้านี้อยู่
> ผู้ฟังรายอื่น (เช่น `AnimatedBuilder` ของ AppShell) จะถูกสั่ง rebuild กลางรอบ build ซึ่ง Flutter ไม่อนุญาต
> การเลื่อนไปหลังเฟรมแรกหลีกเลี่ยงปัญหานี้

### build — ฟังสอง controller

`build` ห่อทั้งหมดด้วย `AnimatedBuilder(animation: Listenable.merge([widget.controller, widget.roomController]))`
ทุกครั้งที่แอร์หรือห้องถูกโหลดใหม่ (รอบ 10 วินาที หรือหลังสั่งงาน) หน้านี้ rebuild และ getter `room` ก็ไปหยิบ object ใหม่มาให้

ปุ่มรีเฟรชบน AppBar

```dart
IconButton(
  tooltip: context.tr('Refresh devices'),
  onPressed: widget.controller.isLoading
      ? null
      : _refreshAll,
  icon: widget.controller.isLoading
      ? SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppPalette.of(context).onBar,
          ),
        )
      : Icon(
          Icons.refresh_rounded,
          color: AppPalette.of(context).onBar,
        ),
),
```

1. **บรรทัด 3–5** — ปิดปุ่มขณะ `AirConditionerController.isLoading` (เฉพาะการโหลดแบบไม่เงียบ) กันกดรัว
2. **บรรทัด 6–17** — สลับไอคอนเป็นวงหมุนเล็กขณะโหลด

```dart
Future<void> _refreshAll() async {
  await Future.wait([
    widget.controller.refresh(),
    widget.roomController.reload(),
  ]);
}
```

1. **บรรทัด 2–5** — ยิงสองคำขอพร้อมกัน (แอร์ และห้อง/เซนเซอร์) แล้วรอให้จบทั้งคู่ เร็วกว่ารอทีละอัน

### Timer 10 วินาทีอยู่ที่ไหน และ "รีเฟรชเองรอรอบที่ค้างอยู่" ทำงานอย่างไร

หน้าห้องไม่มี Timer ของตัวเอง การดึงทุก 10 วินาทีอยู่ใน controller ที่ AppShell สร้างไว้ (อธิบายละเอียดในบท controllers) ตรงนี้ยกมาเพื่อให้เห็นภาพรวมของหน้าห้อง

ไฟล์: lib/controllers/air_conditioner_controller.dart

```dart
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

1. **บรรทัด 2** — โหลดครั้งแรกทันที
2. **บรรทัด 3–6** — ตั้ง Timer ทุก 10 วินาที แบบ `silent: true` (ไม่แสดงวงหมุน ไม่ทำให้จอกระพริบ) `??=` กันสร้างซ้ำถ้า initialize ถูกเรียกหลายครั้ง
3. **บรรทัด 12** — `_inFlight` คือ Future ของรอบที่กำลังวิ่งอยู่ (ถ้ามี)
4. **บรรทัด 14** — รอบอัตโนมัติเจอรอบที่ค้างอยู่ → ข้ามไปเลย ไม่ยิงซ้อน
5. **บรรทัด 15** — การกดรีเฟรชเอง (ไม่เงียบ) เจอรอบที่ค้าง → **รอให้รอบนั้นจบก่อน** แล้วค่อยยิงใหม่
6. **บรรทัด 17–22** — เริ่มรอบใหม่ จดเป็น `_inFlight` และเมื่อจบ ล้างเฉพาะถ้ายังเป็นรอบของตัวเอง (`identical`) ไม่ไปลบรอบที่ใหม่กว่า

> [!WHY] ทำไมกดรีเฟรชแล้วต้อง "รอแล้วยิงใหม่" แทนที่จะใช้ผลรอบที่ค้างอยู่
> รอบที่ค้างอาจเริ่มยิงไปก่อนที่ผู้ใช้จะเห็นปัญหา (เช่น เพิ่งเสียบปลั๊ก ESP32) ผลของมันอาจเก่าไปแล้ว
> ผู้ใช้ที่กดรีเฟรชคาดหวัง "ข้อมูล ณ ตอนที่กด" จึงต้องได้ชุดใหม่เสมอ ส่วนการรอให้รอบเดิมจบก่อนกันไม่ให้สองคำขอวิ่งพร้อมกันแล้วผลมาถึงสลับลำดับ ทำให้ข้อมูลเก่าทับข้อมูลใหม่

> [!WHY] ทำไมดึงข้อมูลเป็นรอบ (polling) แทนการรับแบบ push
> - แอปคุยกับ Backend ด้วย REST อย่างเดียว ไม่ได้ต่อ MQTT หรือ WebSocket เอง ข้อดีคือไม่ต้องให้มือถือเข้าถึง broker โดยตรง และไม่ต้องจัดการสิทธิ์ MQTT ต่อผู้ใช้มือถือ (สิทธิ์ทั้งหมดตรวจที่ REST API ด้วย token)
> - Backend เป็นผู้ฟัง MQTT จาก ESP32 และเก็บสถานะล่าสุดลง MariaDB อยู่แล้ว แอปแค่อ่านสถานะล่าสุดเป็นระยะ
> - การเชื่อมต่อแบบค้างไว้บนมือถือหลุดบ่อย (สลับ Wi-Fi/4G, แอปพักหลังจอ) ต้องเขียนต่อใหม่เอง ส่วน polling ทนกว่าและง่ายกว่า
> - ข้อมูลแบบนี้ (สถานะแอร์ กำลังไฟ ห้องว่าง) ช้าไป 10 วินาทีรับได้ ส่วนผลของคำสั่งที่ผู้ใช้กดเอง แอปอัปเดตบนจอทันทีหลังเซิร์ฟเวอร์ตอบรับ (ดู AirControlCard)
> ข้อเสียคือมีคำขอทุก 10 วินาทีแม้ไม่มีอะไรเปลี่ยน และข้อมูลจากฝั่งอุปกรณ์ช้าได้สูงสุด ~10 วินาที

### การ์ดสรุปห้อง

`_RoomSummaryCard` คำนวณ

- `onCount` = เครื่องที่ `air.canControl && air.isPoweredOn` (ควบคุมได้และเปิดอยู่จริง ทั้งจากคำสั่งของระบบหรือ PZEM ยืนยันว่ากินไฟ)
- `room.totalPower` = ผลรวม `power` (วัตต์จาก PZEM-004T) ของเครื่องที่ `isRunning` แสดงเป็น kW ทศนิยม 2 ตำแหน่ง
- `onlineCount` = เครื่องที่ ESP32 ออนไลน์
- `_sensorStatus` คืนคู่ค่า `(ข้อความ, สี)` (Dart record) เรียงจากปัญหาที่ต้องแก้ก่อน: ไม่มีเซนเซอร์ → รอยืนยัน → ออฟไลน์ → ข้อมูลเรดาร์ใช้ไม่ได้ → พบคน → ไม่พบคน

### การกระทำอื่นของแอดมิน

| ปุ่ม/เมนู | ฟังก์ชัน | ทำอะไร |
|---|---|---|
| Add ESP32 device / Set up again via Bluetooth | `_openProvisioning([existingAir])` | ถ้าเป็นเครื่องเดิม ส่งคำสั่ง `enterSetupMode` ผ่าน API (Backend ส่ง MQTT ให้ ESP32 เปิดโหมดตั้งค่า BLE) รอ 1.2 วินาที แล้ว push `BleProvisioningScreen` ถ้าได้ `true` รอ 2 วินาทีแล้ว `refresh()` |
| Add sensor / Reconfigure | `_openOccupancyProvisioning()` | เหมือนกันแต่กับ ESP32 ของเซนเซอร์ LD2410 เปิด `OccupancyProvisioningScreen` แล้ว `reload()` ห้อง |
| Remove (เซนเซอร์) | `_confirmRemoveOccupancySensor()` | `showDialog<bool>` ยืนยัน → `occupancyRepository.remove` (`DELETE /occupancy-sensors/:deviceId`) → `reload()` (Backend สั่งบอร์ดล้างค่าด้วย ดูหัวข้อถัดไป) |
| Remove Unit (แอร์) | `_confirmDeleteAir(air)` | `showDialog<bool>` ยืนยัน → `controller.remove(air)` (`DELETE /air-conditioners/:deviceId` แล้ว refresh) (Backend สั่งบอร์ดล้างค่าด้วย) |

> [!NOTE] ทำไมรอ 1.2 วินาที และ 2 วินาที
> 1.2 วินาทีเผื่อเวลาให้ ESP32 ได้รับคำสั่งทาง MQTT แล้วเปิด Bluetooth ก่อนหน้าค้นหาเริ่มสแกน
> 2 วินาทีหลังตั้งค่าเสร็จ เผื่อเวลาให้ ESP32 รีสตาร์ต ต่อ Wi-Fi/MQTT และรายงานตัวกับ Backend ก่อนดึงสถานะ

### ลบแอร์หรือเซ็นเซอร์แล้วบอร์ดเกิดอะไรขึ้น

ฝั่งแอปแค่เรียก API ลบ งานล้างบอร์ดทั้งหมดอยู่ที่ Backend และเฟิร์มแวร์ ดูเส้นทางฝั่งแอปก่อน

**ไฟล์ `lib/controllers/air_conditioner_controller.dart` บรรทัด 90–95**

```dart:90
  Future<void> remove(AirConditioner air) async {
    final deviceId = air.deviceId;
    if (deviceId == null) return;
    await repository.remove(deviceId);
    await refresh();
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 91–92 | แอร์ที่ยังไม่ผูกบอร์ด (ไม่มี `deviceId`) ไม่มีอะไรให้ลบที่เซิร์ฟเวอร์ จบเลย |
| 93 | `AirConditionerService.remove` ยิง `DELETE /air-conditioners/$deviceId` ผ่าน `_request` ซึ่งคืน `Map` ของคำตอบ แต่ `remove` มีชนิดคืนเป็น `Future<void>` จึง **ทิ้งเนื้อหาคำตอบไป** |
| 94 | ดึงรายการแอร์ใหม่ เครื่องที่ลบจะหายจากหน้าห้อง |

สิ่งที่ Backend ทำหลังได้ `DELETE` (ทั้งแอร์และเซ็นเซอร์ ฟังก์ชัน `unprovisionDevice` ใน `backend/src/services/mqtt.js`)

1. ลบแถวในฐานข้อมูล
2. **ใหม่:** publish `{"action":"unprovision","deviceId":...}` ไปที่ `<prefix>/<deviceId>/command` แล้วรอให้บอร์ดตอบ `{"unprovisioned":true}` ทาง topic `status` ไม่เกิน 4 วินาที (`UNPROVISION_ACK_TIMEOUT_MS = 4000`)
3. บอร์ดที่ออนไลน์ (แอร์ 2.5.1, สายแอร์ 2.5.2-slm8, เซ็นเซอร์ 1.3.2) ตรวจ `deviceId` ตรงกับตัวเอง ล้าง retained ของตัวเอง ล้าง NVS (Wi-Fi, MQTT, ห้อง และข้อมูลย้อนหลังของบอร์ดแอร์) แล้วรีบูตเข้าโหมดตั้งค่าบลูทูธ
4. Backend ล้าง retained และลบบัญชี MQTT ของบอร์ด (ต้องทำ **หลัง** ข้อ 2 เพราะลบบัญชีก่อน Broker จะตัดบอร์ดทันที คำสั่งไปไม่ถึง)
5. ตอบแอปด้วย JSON ที่มี `boardCleared: true` (บอร์ดยืนยัน) หรือ `false` (บอร์ดออฟไลน์หรือไม่ตอบ)

> [!WARN]
> **แอปไม่แสดง `boardCleared`** ค้นทั้ง `lib/` แล้วไม่มีโค้ด Dart อ่านค่านี้ (`remove` ของทั้ง `AirConditionerService` และ `OccupancySensorService` คืน `Future<void>`) ผู้ใช้เห็นแค่ว่าเครื่องหายจากรายการเสมอ ถ้าบอร์ดออฟไลน์ตอนกดลบ บอร์ดยังจำ Wi-Fi/ห้องเดิมไว้ (แต่ต่อ MQTT ไม่ได้แล้วเพราะบัญชีถูกลบ) ต้องไปล้างที่ตัวบอร์ดเอง (แฟลช/รีเซ็ต หรือตั้งค่าใหม่ผ่านบลูทูธ) อีกจุดคือระหว่างรอคำตอบสูงสุดราว 4 วินาที กล่องยืนยันปิดไปแล้วและหน้าจอไม่มีตัวหมุนบอกว่ากำลังลบ

> [!WHY]
> **ทำไมต้องให้บอร์ดล้างตัวเอง** ถ้า Backend ลบแค่แถวในฐานข้อมูล ข้อความ retained และบัญชี MQTT บอร์ดจะยังจำ Wi-Fi/MQTT/ห้องใน NVS และสั่งแอร์ตามตารางเวลาที่จำไว้ต่อ การสั่ง unprovision ทำให้บอร์ดกลับเป็น "ของใหม่" ที่พร้อมนำไปติดห้องอื่นด้วยบลูทูธได้ทันที ส่วนการ "รอแค่ 4 วินาทีแล้วลบต่อแม้บอร์ดไม่ตอบ" ทำให้การลบในระบบสำเร็จเสมอ ไม่ติดค้างเพราะบอร์ดเสีย

## AirControlCard — การ์ดแอร์และการส่งคำสั่ง

### สามหน้าตาตามสถานะ

| สถานะ | เงื่อนไข | สิ่งที่เห็น |
|---|---|---|
| เชื่อมต่อแล้ว เปิดอยู่ | `air.canControl && air.isPoweredOn` | ส่วนบนพื้นสีเน้น, "● Running now" หรือป้ายนับถอยหลัง, ปุ่มแรกคือ "Turn off" ตัวสีเน้น |
| เชื่อมต่อแล้ว ปิดอยู่ | `air.canControl && !air.isPoweredOn` | ส่วนอุณหภูมิจางลง (opacity 0.55), "● Switched off", ปุ่ม "Turn on" พื้นสีเต็มเด่นปุ่มเดียว |
| ยังไม่เชื่อมต่อ | `!air.canControl` | `_buildDisconnected`: เส้นประรอบการ์ด, ป้าย "Awaiting confirmation" หรือ "Offline", คำอธิบาย, ปุ่ม "Set up again via Bluetooth" (แอดมิน) และ "Try again" |

`canControl` นิยามใน model ว่า `isProvisioned && isOnline && deviceId != null` คือ ตั้งค่าเสร็จแล้ว ESP32 ออนไลน์ และมี Device ID

ส่วนที่แสดงเสมอเมื่อควบคุมได้: ชื่อเครื่อง, ปุ่ม −/+ อุณหภูมิ, ตัวเลขอุณหภูมิใหญ่ + โหมด·พัดลม, แถว "Power now" (โวลต์ แอมป์ พลังงานสะสม และวัตต์ — ข้อมูลจาก PZEM-004T ถ้า `pzemAvailable` ไม่งั้นขึ้น `–`) และแถวปุ่ม 5 ปุ่ม: Power, Mode, Fan, Swing, More

**ป้ายยี่ห้อ·วิธีควบคุม** ใต้แถวชื่อเครื่องมี `AirControlBadge` ทั้งในหน้าตาปกติและหน้าตา "ยังไม่เชื่อมต่อ" (`_buildDisconnected` บรรทัด 386) ผู้ใช้จึงเห็นยี่ห้อแม้บอร์ดออฟไลน์

**ไฟล์ `lib/widgets/air_control_card.dart` บรรทัด 128–132**

```dart:128
                Align(
                  alignment: Alignment.centerLeft,
                  child: AirControlBadge(protocol: air.protocol),
                ),
                const SizedBox(height: 4),
```

| บรรทัด | อธิบาย |
|---|---|
| 128–129 | `Align` ชิดซ้าย เพราะแถวนี้อยู่ใน `Column` ที่ยืดลูกเต็มความกว้าง ถ้าไม่ห่อ ป้ายจะถูกยืดหรือไปอยู่กลาง |
| 130 | ส่งแค่ `protocol` ให้ป้ายคำนวณยี่ห้อและวิธีควบคุมเอง |
| 132 | เว้นระยะ 4 px ก่อนแถวอุณหภูมิ |

ปุ่ม Mode / Fan / Swing บนการ์ดวนตาม `supportedModes` / `supportedFanSpeeds` / `supportedSwingModes` อยู่แล้ว (บรรทัด 279–303) การ์ดจึงไม่ต้องแก้ตรรกะ แอร์สายแอร์ Daikin จะวน Cool → Dry → Fan, พัดลม Auto → Low → Medium → High และสวิง Auto ↔ Off เองตามโมเดล

### State และ getter

ไฟล์: lib/widgets/air_control_card.dart

```dart
class _AirControlCardState extends State<AirControlCard> {
  bool _busy = false;

  AirConditioner get air => widget.air;

  bool get _canControl => !_busy && air.canControl;

  /// นาฬิกาปิดอัตโนมัติที่ใช้กับเครื่องนี้ (ของเครื่องก่อน แล้วค่อยของห้อง)
  DateTime? get _deadline {
    if (!air.isPoweredOn) return null;
    return air.autoOffDeadlineAt ?? widget.roomAutoOffDeadline;
  }

  int get _attempts => air.autoOffDeadlineAt != null
      ? air.autoOffAttempts
      : widget.roomAutoOffAttempts;
```

1. **บรรทัด 2** — `_busy` = กำลังส่งคำสั่งอยู่ ใช้ปิดทุกปุ่มและแสดงวงหมุนบนปุ่ม Power
2. **บรรทัด 4** — อ่านแอร์จาก `widget` ทุกครั้ง เมื่อรอบ 10 วินาทีสร้าง object ใหม่ การ์ดก็เห็นค่าใหม่ (State ไม่หายเพราะหน้าห้องให้ `ValueKey(air.deviceId ?? air.id)`)
3. **บรรทัด 6** — ปุ่มทุกปุ่มกดได้เมื่อ "ไม่ได้กำลังส่ง" และ "เครื่องควบคุมได้"
4. **บรรทัด 9–12** — ป้ายนับถอยหลังแสดงเฉพาะเมื่อแอร์เปิดอยู่จริง (`isPoweredOn` รวมกรณีเปิดด้วยรีโมตจริงที่ PZEM ยืนยัน) ใช้นาฬิกาของเครื่องก่อน ถ้าไม่มีใช้นาฬิกาของห้อง
5. **บรรทัด 14–16** — จำนวนครั้งที่ระบบยิงคำสั่งปิดไปแล้ว ใช้แหล่งเดียวกับ deadline

ใน build ตัวแปร `on` มาจาก `air.isPoweredOn` (ไม่ใช่ `air.isOn`) ปุ่ม Power จึงขึ้น "Turn off" ถูกต้องแม้แอร์ถูกเปิดด้วยรีโมตจริง

ใน build `sending = deadline != null && _attempts > 0` ถ้าเป็นจริง (นับครบแล้ว ระบบกำลังยิงคำสั่งปิด) จะแสดงแถบ `_InfoLine` "Sending the off command  N/5" แทนป้ายนับถอยหลัง

### ปุ่มแต่ละปุ่มสร้าง "ร่าง" แล้วส่ง

ปุ่มทั้งหมดเรียก `_change` พร้อมฟังก์ชันที่แก้ร่าง ตัวอย่างปุ่ม Power

```dart
_ActionButton(
  key: Key('air-${air.id}-power'),
  icon: Icons.power_settings_new_rounded,
  label: context.tr(on ? 'Turn off' : 'Turn on'),
  highlighted: !on,
  accent: on,
  busy: _busy,
  onPressed: _canControl
      ? () => _change((d) => d.isOn = !on)
      : null,
),
```

1. **บรรทัด 4** — ป้ายตามสถานะปัจจุบัน
2. **บรรทัด 5–6** — ปิดอยู่ → ปุ่มพื้นเต็ม (`highlighted`), เปิดอยู่ → ตัวหนังสือสีเน้น (`accent`)
3. **บรรทัด 8–10** — กดแล้วสั่งกลับสถานะ ส่ง `null` เมื่อควบคุมไม่ได้ ปุ่มจะจางและกดไม่ได้

ปุ่มอื่นทำแบบเดียวกัน: −/+ ลด/เพิ่ม `temperature` 1 องศา (ปิดเมื่อถึง `minimumTemperature`/`maximumTemperature` ของรุ่น), Mode/Fan/Swing วนไปค่าถัดไปในรายการที่รุ่นนั้นรองรับด้วยสูตร `list[(list.indexOf(current) + 1) % list.length]`

### เส้นทางของคำสั่ง (โค้ดแกนหลัก)

```dart
Future<void> _change(void Function(AirConditioner draft) mutation) async {
  final draft = air.editableCopy();
  mutation(draft);
  await _sendDraft(draft);
}

Future<void> _openRemote() async {
  final draft = await showFullRemoteSheet(context, air);
  if (draft != null) await _sendDraft(draft);
}

Future<void> _sendDraft(AirConditioner draft) async {
  draft.normalizeForProtocol();
  setState(() => _busy = true);
  try {
    await widget.onCommand(draft);
    if (!mounted) return;
    setState(() => air.copyStateFrom(draft));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.tr('MQTT command sent successfully')),
        ),
      );
  } catch (error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$error')));
  } finally {
    if (mounted) setState(() => _busy = false);
  }
}
```

1. **บรรทัด 2** — ทำสำเนาของแอร์ (`editableCopy`) ไม่แตะ object จริง
2. **บรรทัด 3** — ให้ฟังก์ชันของปุ่มแก้สำเนา เช่น `d.temperature += 1`
3. **บรรทัด 7–10** — ปุ่ม More เปิดรีโมตเต็ม ซึ่งคืนร่างที่ผู้ใช้ปรับแล้ว (หรือ null ถ้าปัดทิ้ง) แล้วส่งด้วยเส้นทางเดียวกัน
4. **บรรทัด 13** — `normalizeForProtocol` ปรับร่างให้ถูกกับรุ่นแอร์ เช่น บีบอุณหภูมิให้อยู่ในช่วง รุ่น `SAIJO_DENKI` ปิดฟังก์ชันเสริมที่ไม่รองรับ และ รุ่น `DAIKIN_WIRED` เปลี่ยน Turbo เป็น High, สวิงที่ไม่มีเป็น Auto และปิดทุกฟังก์ชันเสริมยกเว้น Sleep (ดูบทสถาปัตยกรรม)
5. **บรรทัด 14** — `_busy = true` ทุกปุ่มถูกปิด ปุ่ม Power เป็นวงหมุน
6. **บรรทัด 16** — `onCommand` = `AirConditionerController.sendCommand` → `AirConditionerService.sendCommand` ยิง `POST /air-conditioners/{deviceId}/command` พร้อม `toCommandJson()` (power, temperature, mode, fanSpeed, swing, eco, turbo, ... ทั้งชุด) Backend จึง publish MQTT ไปหา ESP32 ซึ่งยิง IR ไปที่แอร์ (หรือบอร์ดสายแอร์ส่งคำสั่งเข้าสายแทนรีโมตติดผนัง)
7. **บรรทัด 17** — หลัง await หน้าอาจถูกปิดแล้ว
8. **บรรทัด 18** — **เซิร์ฟเวอร์ตอบรับแล้ว** จึงคัดลอกค่าจากร่างลง object จริง จอเปลี่ยนทันทีโดยไม่ต้องรอรอบ 10 วินาที
9. **บรรทัด 19–25** — แจ้งว่าส่งคำสั่งสำเร็จ
10. **บรรทัด 26–30** — ถ้าพัง (ออฟไลน์ เซิร์ฟเวอร์ปฏิเสธ) แสดงข้อความ error และ **ไม่** แก้ค่าบนจอ ผู้ใช้จะเห็นค่าเดิมซึ่งตรงกับความจริง
11. **บรรทัด 31–32** — ปลด `_busy` เสมอ

> [!WHY] ทำไมส่ง "สถานะเต็มชุด" ไม่ส่งแค่ "กด +1"
> รีโมต IR ของแอร์ส่วนใหญ่ส่งสถานะทั้งหมดในทุกครั้งที่กดปุ่ม (อุณหภูมิ โหมด พัดลม ฯลฯ ในแพ็กเก็ตเดียว) ไม่ได้ส่ง "เพิ่ม 1 องศา"
> การส่งชุดเต็มจากแอปจึงตรงกับวิธีที่ ESP32 ต้องยิง IR และถ้าคำสั่งก่อนหน้าหาย คำสั่งถัดไปก็ยังทำให้แอร์อยู่ในสถานะที่ถูกต้อง (idempotent) บอร์ดสายแอร์ ใช้ JSON รูปแบบเดียวกัน แอปจึงไม่ต้องรู้ว่าปลายทางเป็นบอร์ดแบบไหน

> [!WHY] ทำไมใช้ "ร่าง" แล้วค่อย copy กลับ แทนการแก้ object ตรง ๆ
> ถ้าแก้ object จริงก่อนส่ง แล้วการส่งล้มเหลว จอจะแสดงค่าที่แอร์ไม่ได้รับ (เช่น 24° ทั้งที่แอร์ยัง 25°) ต้องเขียนโค้ดย้อนค่ากลับเอง
> แบบร่างทำให้ "จอเปลี่ยนเมื่อเซิร์ฟเวอร์ตอบรับแล้วเท่านั้น" ง่ายและไม่หลอกผู้ใช้

> [!NOTE] "ส่งสำเร็จ" หมายถึงอะไร
> SnackBar "MQTT command sent successfully" ยืนยันว่า Backend รับคำสั่งและส่งต่อทาง MQTT แล้ว ไม่ได้ยืนยันว่าแอร์รับสัญญาณ IR (หรือคำสั่งทางสายแอร์) จริง
> สิ่งที่ยืนยันได้จริงคือค่ากำลังไฟจาก PZEM-004T (`isRunning`, `power`) ที่จะเปลี่ยนในรอบ polling ถัดไป

### ป้ายนับถอยหลังในการ์ด (`_CountdownChip`) และกล่องเปลี่ยนชื่อ

`_CountdownChip` เป็น StatefulWidget เล็ก ๆ ที่สร้าง `Timer.periodic(1 วินาที)` ใน `initState` และ `cancel()` ใน `dispose` ทุกวินาทีเรียก `setState(() {})` แล้วคำนวณ `widget.deadline.difference(DateTime.now()).inSeconds` ใหม่ แสดงเป็น `mm:ss` ด้วย `formatCountdown` (นำเข้าจาก `auto_off_countdown.dart`) ใช้ `FontFeature.tabularFigures()` ให้ตัวเลขกว้างเท่ากัน ตัวเลขจะได้ไม่ส่ายตอนเปลี่ยน

`_RenameDialog` เป็นตัวอย่างการจัดการ `TextEditingController` ใน dialog ที่ถูกต้อง: ให้ State ของ dialog เป็นเจ้าของ controller และ dispose ใน `dispose()` ของตัวเอง
คอมเมนต์อธิบายว่ารุ่นเดิมสร้าง controller นอก dialog แล้ว dispose ทันทีที่ `showDialog` คืนค่า แต่ตอนนั้น dialog ยังเล่นอนิเมชันปิดอยู่ TextField ยังใช้ controller นั้น Flutter จึงโยน assertion

## FullRemoteSheet — รีโมตเต็มรูปแบบ

### สิ่งที่ผู้ใช้เห็น

แผ่นเลื่อนขึ้นจากล่างสูง 92% ของจอ (ลากย่อได้ถึง 65% ขยายได้ถึง 97% ด้วย `DraggableScrollableSheet`) ประกอบด้วย

- จอรีโมตสีเขียว (เปิด) / เทา (ปิด) แสดง ON/OFF, ปุ่ม Power, ปุ่ม −/+ และอุณหภูมิ °C
- Operating mode, Fan speed, Vertical swing เป็นชิปให้เลือก (`ChoiceChip`) แสดงเฉพาะค่าที่รุ่นนั้นรองรับ
- ใต้หัวข้อมี `AirControlBadge` และถ้าเป็นสายแอร์ มีบรรทัดอธิบาย "เครื่องนี้สั่งผ่านสายแอร์ จึงใช้ได้เฉพาะฟังก์ชันที่รีโมตติดผนัง Daikin มี"
- Additional functions (สวิตช์ Horizontal Swing, Eco, Turbo, Sleep, Quiet, Display Light, Clean) แสดง **ทีละสวิตช์** ตาม getter `supportsHorizontalSwing`, `supportsEco`, ... ของโมเดล และซ่อนทั้งหัวข้อถ้าไม่มีสวิตช์ไหนใช้ได้เลย
- Timer: "Turn on in" / "Turn off in" กดแล้วเปิดแผ่นซ้อนเลือก 30 นาที, 1, 2, 4, 6, 8 ชั่วโมง หรือ Clear Timer
- ปุ่ม "Send command via MQTT"

### การทำงาน

ทุกการแตะในแผ่นนี้แค่ `setState(() => air.xxx = ...)` บนสำเนา ยังไม่ส่งอะไร เมื่อกดปุ่มส่ง

```dart
FilledButton.icon(
  key: const Key('send-mqtt-command-button'),
  onPressed: () => Navigator.of(context).pop(air),
```

1. **บรรทัด 3** — ปิดแผ่นและคืนสำเนาที่ปรับแล้วกลับไปให้ `_openRemote` ในการ์ด ซึ่งส่งต่อเข้า `_sendDraft` (คำสั่งเดียวรวมทุกการเปลี่ยนแปลง)

> [!WHY] ทำไมรีโมตเต็มต้องกดส่งทีเดียว แต่ปุ่มบนการ์ดส่งทันที
> ปุ่มบนการ์ดเป็นการกระทำที่ใช้บ่อยและต้องการผลทันที (เปิด/ปิด, ±1 องศา) ส่วนรีโมตเต็มผู้ใช้มักปรับหลายอย่างพร้อมกัน
> ถ้าส่งทุกครั้งที่แตะชิปจะเกิดคำสั่งหลายครั้งติดกัน ESP32 ต้องยิง IR ซ้ำ ๆ และแอร์มักส่งเสียงบี๊บทุกครั้งที่รับสัญญาณ การรวมเป็นคำสั่งเดียวลดทั้งภาระเครือข่ายและเสียงรบกวน

ตัวเลือกเวลา `_pickTimer` ใช้ค่า `-1` แทน "Clear Timer" เพราะ `null` ถูกใช้หมายถึง "ปัดแผ่นทิ้งโดยไม่เลือก" แล้ว จึงต้องแยกสองกรณีนี้ออกจากกัน

### ซ่อนปุ่มที่แอร์ทำไม่ได้

ตั้งแต่มีบอร์ดสายแอร์ Daikin รีโมตเต็มต้องแสดงคนละชุดปุ่มตามเครื่อง ผลลัพธ์บนจอเมื่อเปิดรีโมตของแอร์ `DAIKIN_WIRED`: โหมดมี Cool / Dry / Fan, พัดลมมี Auto / Low / Medium / High, สวิงแนวตั้งมี Auto / Off และ "Additional functions" เหลือสวิตช์ Sleep สวิตช์เดียว (หายไปเมื่อเลือก Dry)

**ไฟล์ `lib/widgets/full_remote_sheet.dart` บรรทัด 67–81** (หัวของแผ่นรีโมต)

```dart:67
            const SizedBox(height: 6),
            Row(
              children: [
                AirControlBadge(protocol: air.protocol),
              ],
            ),
            if (air.isWired) ...[
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'This unit is controlled through its cable, so only the functions of the Daikin wall remote are available.',
                ),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
```

| บรรทัด | อธิบาย |
|---|---|
| 68–72 | ห่อป้ายด้วย `Row` เพื่อให้ป้ายกว้างเท่าเนื้อหา ไม่ยืดเต็มแผ่น |
| 73 | `if (...) ...[ ]` คือ **collection if + spread**: ใส่วิดเจ็ตหลายตัวในรายการ `children` เฉพาะเมื่อเงื่อนไขจริง (`...` กระจายรายการย่อยเข้าไปในรายการหลัก) |
| 75–79 | บอกเหตุผลที่ปุ่มน้อยกว่าเครื่องอื่น ข้อความอังกฤษเป็นกุญแจแปล ภาษาไทยได้ "เครื่องนี้สั่งผ่านสายแอร์ จึงใช้ได้เฉพาะฟังก์ชันที่รีโมตติดผนัง Daikin มี" |

**ไฟล์ `lib/widgets/full_remote_sheet.dart` บรรทัด 116–121** (เลือกโหมด)

```dart:116
                        onSelected: air.supportedModes.length > 1
                            ? (_) => setState(() {
                                air.mode = mode;
                                if (air.isWired) air.normalizeForProtocol();
                              })
                            : null,
```

| บรรทัด | อธิบาย |
|---|---|
| 116 | มีโหมดให้เลือกมากกว่า 1 ถึงจะกดได้ ไม่งั้น `null` (ชิปกดไม่ได้) |
| 118 | ตั้งโหมดในสำเนา |
| 119 | สายแอร์: ปรับค่าทันทีหลังเปลี่ยนโหมด เพราะกติกา "Sleep ใช้ไม่ได้ในโหมด Dry" ขึ้นกับโหมด ถ้าเลือก Dry ค่า `sleep` จะถูกปิดและสวิตช์ Sleep หายไปจากจอในเฟรมเดียวกัน |

**ไฟล์ `lib/widgets/full_remote_sheet.dart` บรรทัด 165–184** (ฟังก์ชันเสริม)

```dart:165
            if (air.supportsHorizontalSwing ||
                air.supportsEco ||
                air.supportsTurbo ||
                air.supportsSleep ||
                air.supportsQuiet ||
                air.supportsDisplayLight ||
                air.supportsClean) ...[
              const SizedBox(height: 12),
              _Section(
                title: context.tr('Additional functions'),
                child: Column(
                  children: [
                    if (air.supportsHorizontalSwing)
                      _FeatureSwitch(
                        title: context.tr('Horizontal Swing'),
                        value: air.horizontalSwing,
                        onChanged: (value) {
                          setState(() => air.horizontalSwing = value);
                        },
                      ),
```

| บรรทัด | อธิบาย |
|---|---|
| 165–171 | แสดงหัวข้อ "Additional functions" เมื่อมีอย่างน้อยหนึ่งสวิตช์ที่ใช้ได้ (`||` = หรือ) Saijo Denki ไม่มีเลยจึงไม่เห็นหัวข้อนี้ เหมือนเดิม |
| 177–184 | แต่ละสวิตช์มี `if (air.supportsXxx)` ของตัวเอง สวิตช์อื่น (Eco, Turbo, Sleep, Quiet, Display Light, Clean บรรทัด 185–222) เขียนรูปแบบเดียวกัน |

> [!WHY]
> **ทำไมซ่อนปุ่ม ไม่ใช่แค่ทำให้กดไม่ได้ (disable)** ปุ่มที่ไม่มีวันใช้ได้กับแอร์เครื่องนี้ (Eco, Turbo ของสายแอร์) แสดงไว้ก็ทำให้ผู้ใช้สงสัยว่าทำไมกดไม่ได้ และเปลืองพื้นที่จอมือถือ ส่วนกรณีที่ "บางทีใช้ได้" อย่าง Sleep ในโหมด Dry ก็ซ่อนเช่นกันเพื่อให้กติกาเดียว และมีบรรทัดอธิบายใต้หัวแผ่นบอกเหตุผลแล้ว หน้าจอเพียงถามโมเดลว่า `supportsXxx` ไม่ต้องรู้จักยี่ห้อเลย ถ้าวันหน้าเพิ่มบอร์ดยี่ห้ออื่น แก้ที่โมเดลจุดเดียว

> [!NOTE]
> ข้อความ "ESP32 ยิง IR ซ้ำ ๆ แอร์ส่งเสียงบี๊บ" ในกล่อง WHY ด้านบนเป็นกรณีบอร์ด IR บอร์ดสายแอร์ไม่ได้ยิงแสง แต่การรวมเป็นคำสั่งเดียวก็ยังลดจำนวนคำสั่งที่ต้องส่งเข้าสายแอร์และภาระของ MQTT เหมือนกัน

## AirControlBadge — ป้ายยี่ห้อและวิธีควบคุม

วิดเจ็ตเล็ก 33 บรรทัด ใช้ 3 จุด: การ์ดแอร์สองหน้าตา (ปกติ และยังไม่เชื่อมต่อ) กับหัวรีโมตเต็ม (`ble_provisioning_screen.dart` import ไฟล์นี้ไว้ แต่ยังไม่ได้เรียกใช้ หน้านั้นเขียนช่องยี่ห้อของตัวเองใน `_WiredBrandField`) แสดงข้อความเช่น "Daikin · สายแอร์" (สีฟ้า ไอคอนสายไฟ) หรือ "Haier · รีโมต IR" (สีเทา ไอคอนรีโมต) กดค้าง/ชี้เมาส์จะเห็นคำอธิบายเต็ม

**ไฟล์ `lib/widgets/air_control_badge.dart` บรรทัด 1–33**

```dart:1
import '../localization/localized_material.dart';
import '../models/air_conditioner.dart';
import '../theme/app_theme.dart';
import 'status_pill.dart';

/// ป้ายบอกยี่ห้อแอร์และวิธีที่บอร์ดสั่งแอร์ เช่น "Daikin · สายแอร์" หรือ "Haier · รีโมต IR"
///
/// ผู้ใช้จะรู้ได้ว่าเครื่องนี้ต่อสายแอร์แทนรีโมตติดผนัง (ฟังก์ชันน้อยกว่า)
/// หรือยิง IR เหมือนรีโมตมือถือ
class AirControlBadge extends StatelessWidget {
  const AirControlBadge({required this.protocol, super.key});

  final String protocol;

  @override
  Widget build(BuildContext context) {
    final wired = airControlTypeOf(protocol) == 'wired';
    final brand = airBrandOf(protocol);
    final type = context.tr(wired ? 'Wired' : 'IR remote');
    return Tooltip(
      message: context.tr(
        wired
            ? 'Controlled through the air-conditioner cable in place of the wall remote'
            : 'Controlled by infrared, like a handheld remote',
      ),
      child: StatusPill(
        label: brand.isEmpty ? type : '$brand · $type',
        color: wired ? AppColors.blue : AppColors.textSecondary,
        icon: wired ? Icons.cable_rounded : Icons.settings_remote_rounded,
      ),
    );
  }
}
```

| บรรทัด | อธิบาย |
|---|---|
| 1–4 | import ตัวแปลภาษา (`Text`/`context.tr`), โมเดลแอร์ (เอาฟังก์ชัน `airBrandOf`/`airControlTypeOf`), สีของแอป และ `StatusPill` ที่มีอยู่แล้ว |
| 10 | `StatelessWidget` เพราะไม่มีข้อมูลที่เปลี่ยนเอง วาดจาก `protocol` อย่างเดียว |
| 11–13 | รับแค่ข้อความ `protocol` (ไม่รับทั้ง `AirConditioner`) จึงใช้ได้ทุกที่ที่รู้โปรโตคอล |
| 17 | `wired` จริงเมื่อเป็น `DAIKIN_WIRED` |
| 18 | ชื่อยี่ห้อ เช่น `HAIER_AC176` → `Haier` |
| 19 | ข้อความชนิดที่แปลแล้ว: "สายแอร์" หรือ "รีโมต IR" |
| 20–25 | `Tooltip` ข้อความยาวที่ขึ้นเมื่อกดค้าง (มือถือ) หรือชี้เมาส์ (Windows) อธิบายว่าสั่งแอร์ด้วยวิธีไหน |
| 26–30 | ใช้ `StatusPill` เดิม ข้อความ "ยี่ห้อ · ชนิด" (ถ้าไม่รู้ยี่ห้อแสดงแค่ชนิด) สายแอร์สีฟ้า `AppColors.blue` ไอคอน `cable_rounded` ส่วน IR สีเทา `AppColors.textSecondary` ไอคอน `settings_remote_rounded` |

> [!WHY]
> **ทำไมต้องมีป้ายนี้** แอร์ Daikin ในตึกอาจเป็นได้ทั้งบอร์ด IR (`DAIKIN`) และบอร์ดสายแอร์ (`DAIKIN_WIRED`) ซึ่งทำงานได้ไม่เท่ากัน ถ้าไม่บอก ผู้ใช้จะสงสัยว่าทำไมเครื่องหนึ่งมีปุ่ม Eco อีกเครื่องไม่มี ป้ายสีต่างกันและไอคอนต่างกันทำให้แยกได้ในพริบตา การใช้ `StatusPill` ซ้ำทำให้หน้าตาเข้ากับป้ายสถานะอื่นของแอป (และได้การปรับสีในธีมมืดฟรี) ส่วนการแยกเป็นไฟล์ของตัวเองทำให้ทุกจุดที่ใช้แสดงเหมือนกัน

## AutoOffCountdown — นาฬิกานับถอยหลังปิดแอร์

### บทบาทในระบบ

เมื่อเซนเซอร์ LD2410 รายงานว่าห้องว่าง Backend จะเริ่มนับถอยหลังและบันทึก "เวลาที่จะสั่งปิด" (`autoOffDeadlineAt`) ถ้าหมดเวลาแล้วยังไม่มีคนกลับมา Backend จะยิงคำสั่งปิด (นับ `autoOffAttempts` สูงสุด 5 ครั้ง ทุก 20 วินาทีตามข้อความในแอป) จนกำลังไฟลดลง
แอปได้ค่าเหล่านี้ทาง JSON ของห้อง (`Room`) และของแอร์แต่ละเครื่อง (`AirConditioner`) ใน polling ปกติ

วิดเจ็ตนี้ใช้ในการ์ดห้องของ `RoomsScreen` แบบ `compact: true` (ส่วนการ์ดแอร์ใช้ `_CountdownChip` ที่เล็กกว่า)

### โค้ดหลัก

ไฟล์: lib/widgets/auto_off_countdown.dart

```dart
class _AutoOffCountdownState extends State<AutoOffCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(AutoOffCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final needsTicker = widget.deadline != null;
    if (needsTicker && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needsTicker && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
```

1. **บรรทัด 2** — Timer อาจไม่มีก็ได้ (`?`) เพราะถ้าไม่มี deadline ไม่ต้องเดิน
2. **บรรทัด 4–8** — ตอนสร้าง ตรวจว่าต้องเดินนาฬิกาไหม
3. **บรรทัด 10–14** — `didUpdateWidget` ถูกเรียกเมื่อพ่อ rebuild แล้วส่งค่าใหม่มา (เช่นรอบ polling ได้ deadline ใหม่ หรือ deadline หายไปเพราะมีคนเข้าห้อง) จึงตรวจซ้ำ
4. **บรรทัด 16–25** — มี deadline แต่ยังไม่มี Timer → สร้าง Timer ทุก 1 วินาที ที่แค่สั่ง rebuild ไม่มี deadline แต่มี Timer → หยุดและทิ้ง
5. **บรรทัด 28–31** — ปิด Timer เมื่อวิดเจ็ตถูกทำลาย ไม่งั้น Timer จะเรียก setState บน State ที่ตายแล้ว

```dart
@override
Widget build(BuildContext context) {
  final deadline = widget.deadline;
  if (deadline == null) return const SizedBox.shrink();

  final remaining = deadline.difference(DateTime.now());
  final seconds = remaining.inSeconds;
  final isCommanding = widget.attempts > 0 || seconds <= 0;

  final label = isCommanding
      ? '${context.tr('Sending the off command')} '
            '(${widget.attempts}/${widget.maxAttempts})'
      : '${context.tr('Empty room · switching off in')} '
            '${formatCountdown(seconds)}';

  final color = isCommanding ? AppColors.red : AppColors.orange;
```

1. **บรรทัด 4** — ไม่มีนาฬิกา → คืนวิดเจ็ตว่างขนาดศูนย์
2. **บรรทัด 6–7** — เวลาที่เหลือ = deadline (จากเซิร์ฟเวอร์) − เวลาปัจจุบันของเครื่อง คำนวณใหม่ทุกครั้งที่ Timer สั่ง build
3. **บรรทัด 8** — ถือว่า "กำลังสั่งปิด" ถ้าเซิร์ฟเวอร์ยิงไปแล้ว (`attempts > 0`) หรือเวลาหมดแล้ว (≤ 0) แม้รอบ polling ยังไม่มาบอก
4. **บรรทัด 10–14** — ข้อความตามสถานะ: "Sending the off command (N/5)" หรือ "Empty room · switching off in mm:ss"
5. **บรรทัด 16** — สีแดงตอนสั่งปิด สีส้มตอนนับถอยหลัง

แบบเต็ม (ไม่ compact) มีบรรทัดอธิบายเพิ่ม: กำลังสั่ง → "Retrying every 20 seconds until the power draw drops.", มีคาบเรียน (`inClass`) → "A class is scheduled now, so the wait is longer. Anyone entering cancels it.", ปกติ → "Anyone entering the room cancels this."

```dart
String formatCountdown(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final minutes = (safe ~/ 60).toString().padLeft(2, '0');
  final rest = (safe % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}
```

1. **บรรทัด 2** — ค่าติดลบ (เลยเวลาแล้ว) แสดงเป็น 0
2. **บรรทัด 3–4** — `~/` คือหารเอาจำนวนเต็ม `%` เอาเศษ `padLeft(2, '0')` เติมศูนย์หน้าให้ครบ 2 หลัก เช่น 125 → `02:05`

> [!WHY] ทำไมเซิร์ฟเวอร์ส่ง "เวลาสิ้นสุด" แล้วให้แอปเดินนาฬิกาเอง
> - ถ้าให้เซิร์ฟเวอร์ส่ง "เหลือกี่วินาที" แอปต้องถามทุกวินาทีตัวเลขถึงจะลดลงต่อเนื่อง ซึ่งเปลืองเน็ตและแบตมาก polling ทุก 10 วินาทีจะทำให้ตัวเลขกระโดดทีละ 10
> - ส่ง deadline ครั้งเดียว แอปคำนวณ `deadline - now` เองทุกวินาทีได้ฟรี ไม่ต้องใช้เน็ต ตัวเลขลดลงลื่น ๆ
> - deadline เป็นค่าคงที่ ไม่ว่ารอบ polling มาช้าหรือเร็ว ตัวเลขก็ถูกต้อง ไม่สะสมความคลาดเคลื่อนเหมือนการลบ 1 ทุกวินาที
> - การตัดสินใจปิดแอร์จริงอยู่ที่เซิร์ฟเวอร์ทั้งหมด แอปแค่แสดงผล ถ้าปิดแอปหรือเน็ตหลุด แอร์ก็ยังถูกปิดตามกำหนด
> - เมื่อมีคนเข้าห้อง เซิร์ฟเวอร์ล้าง deadline รอบ polling ถัดไปส่ง `null` มา `didUpdateWidget` หยุด Timer และป้ายหายไปเอง

> [!WARN] ข้อจำกัดของการเดินนาฬิกาเอง
> ใช้ `DateTime.now()` ของมือถือ ถ้านาฬิกามือถือเพี้ยนจากเซิร์ฟเวอร์ ตัวเลขจะเพี้ยนตาม (deadline เป็นเวลาสัมบูรณ์แบบ UTC ไม่มีปัญหาเรื่องเขตเวลา แต่มีปัญหาถ้าเวลาเครื่องผิด)

## ScheduleScreen — แท็บตารางเรียน

> [!NOTE]
> แท็บนี้ดูตาม **วันที่จริง** ไม่ใช่แค่ "วันในสัปดาห์" เลื่อนทีละสัปดาห์ได้ และรวม 3 อย่างไว้ในหน้าเดียว คือ คาบเรียนประจำ การใช้ห้องนอกตาราง (ประชุม สอบ กิจกรรม) และวันเปิด–ปิดภาคเรียน วันพุธสัปดาห์นี้กับวันพุธช่วงปิดภาคจึงแสดงไม่เหมือนกัน ไฟล์ `lib/screens/schedule_screen.dart` มี 1,373 บรรทัด และมีหน้าจอประกอบอีก 2 ไฟล์ (`booking_editor_screen.dart`, `term_calendar_screen.dart`) อธิบายในหัวข้อถัดไป

### สิ่งที่ผู้ใช้เห็น (จากบนลงล่าง)

| ส่วน | วิดเจ็ต | ใครเห็น | รายละเอียด |
|---|---|---|---|
| แถบหัว | `_ScheduleHeader` | ทุกคน | "Room Schedule" + "Today · ศ. 9 ต.ค. 2569" (หรือ "Selected date" ถ้าไม่ใช่วันนี้) ปุ่มซ้าย **เพิ่มการใช้ห้อง** และปุ่มขวา **จัดการตาราง** เฉพาะแอดมิน |
| การ์ดตารางที่ใช้อยู่ | `_TimetableInfoCard` | ทุกคน | "ตารางเรียนภาคเรียน 1/2569", "312 คาบ ใน 18 ห้อง · นำเข้าเมื่อ ... โดย ...", สถานะภาคเรียน และปุ่ม "ปฏิทินภาคเรียน" / "ดาวน์โหลด CSV" |
| ตัวเลือกสัปดาห์ | `_WeekNavigator` | ทุกคน | ลูกศร ‹ › เลื่อนทีละ 7 วัน ป้ายช่วงวันที่ "4 ต.ค. 2569 – 10 ต.ค. 2569" + "สัปดาห์นี้/สัปดาห์ถัดไป/สัปดาห์ที่ผ่านมา" ปุ่ม "Today" (ถ้าไม่ได้ดูวันนี้) และแถว 7 วันพร้อมเลขวันที่ |
| เลือกชั้น | `FloorSelector` | ทุกคน | เหมือนเดิม |
| กล่องเตือนนอกภาค | `_NoteBox` (ส้ม) | ทุกคน | "วันที่นี้อยู่นอกภาคเรียน 1/2569 (...) ตารางเรียนไม่มีผล ห้องที่ไม่มีการใช้ห้องอื่นถือว่าว่าง" |
| กล่องเตือนโหลดพลาด | `_NoteBox` (แดง) | ทุกคน | โหลดการใช้ห้องหรือปฏิทินไม่สำเร็จ ดึงจอลงเพื่อลองใหม่ |
| Classrooms (Scheduled Control) | `_ScheduleCard` | ทุกคน | การ์ดห้องที่มีคาบ **หรือ** มีการใช้ห้องในวันนั้น รายการเรียงรวมกันตามเวลาเริ่ม |
| Offices / Other Rooms | `_CompactRoomCard` | ทุกคน | ห้องที่ไม่มีอะไรในวันนั้น |

### State ของหน้าและการโหลดทีละสัปดาห์

ไฟล์ `lib/screens/schedule_screen.dart` บรรทัด 58–92

```dart:58
class _ScheduleScreenState extends State<ScheduleScreen> {
  /// วันที่ที่กำลังดู `yyyy-MM-dd` (null = วันนี้)
  String? _selectedDate;
  int _selectedFloor = 3;

  String get _today => widget.controller.today;
  String get _date => _selectedDate ?? _today;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeek());
  }

  Future<void> _loadWeek() async {
    if (!mounted) return;
    final start = weekStartIso(_date);
    await widget.controller.loadBookings(from: start, to: addDaysIso(start, 6));
  }

  void _selectDate(String date) {
    final before = weekStartIso(_date);
    setState(() => _selectedDate = date);
    if (weekStartIso(date) != before) _loadWeek();
  }

  Future<void> _refresh() async {
    await widget.controller.reload();
    final start = weekStartIso(_date);
    await widget.controller.loadBookings(
      from: start,
      to: addDaysIso(start, 6),
      force: true,
    );
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 60 | เก็บวันที่ที่ดูเป็นข้อความ `yyyy-MM-dd` (ไม่ใช่เลขวัน 0–6 เพราะต้องแยกวันพุธแต่ละสัปดาห์) `null` หมายถึง "วันนี้" |
| 63 | "วันนี้" มาจาก `controller.today` ซึ่งเป็นวันที่ตามเวลาไทยของเซิร์ฟเวอร์ (ถ้ายังไม่รู้ใช้ของเครื่อง) |
| 64 | getter รวม: ถ้ายังไม่เลือก ใช้วันนี้ |
| 69 | รอให้เฟรมแรกวาดเสร็จก่อนค่อยโหลด (`addPostFrameCallback`) เพราะการโหลดเรียก `notifyListeners()` ซึ่งทำให้ widget rebuild ถ้าเรียกระหว่าง build ครั้งแรกจะ error |
| 72–76 | โหลดการใช้ห้องของ **ทั้งสัปดาห์** อาทิตย์ถึงเสาร์ (`weekStartIso` + 6 วัน) |
| 78–82 | เปลี่ยนวัน: ถ้ายังอยู่สัปดาห์เดิม แค่ `setState` ไม่ยิงเน็ต ถ้าข้ามสัปดาห์ (กดลูกศร หรือกด Today จากสัปดาห์อื่น) ค่อยโหลดสัปดาห์ใหม่ |
| 84–92 | ดึงจอลง: โหลดตาราง + ปฏิทินใหม่ แล้วบังคับโหลดการใช้ห้องของสัปดาห์ปัจจุบัน (`force: true` ข้ามแคช) |

### เลือกว่าห้องไหนอยู่กลุ่มไหน

ไฟล์ `lib/screens/schedule_screen.dart` บรรทัด 347–368

```dart:347
    final date = _date;
    final today = _today;
    final floors = widget.rooms.map((room) => room.floor).toSet().toList()
      ..sort();
    if (floors.isNotEmpty && !floors.contains(_selectedFloor)) {
      _selectedFloor = floors.first;
    }
    final floorRooms = widget.rooms
        .where((room) => room.floor == _selectedFloor)
        .toList();
    bool hasEntries(Room room) =>
        controller.classesOn(room.number, date).isNotEmpty ||
        controller.bookingsOn(room.number, date).isNotEmpty;
    final scheduledRooms = floorRooms.where(hasEntries).toList();
    final otherRooms = floorRooms
        .where((room) => !scheduledRooms.contains(room))
        .toList();
    final term = controller.activeTimetableTerm;
    final outsideTerm = controller.isOutsideTerm(date);
    final now = TimeOfDay.now();
    final nowText = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
```

| บรรทัด | อธิบาย |
|---|---|
| 349–353 | หาชั้นที่มีและแก้ชั้นที่เลือกถ้าไม่มีจริง (แบบเดียวกับ RoomsScreen) |
| 354–356 | ห้องของชั้นที่เลือก |
| 357–359 | **ฟังก์ชันซ้อน (local function)** ห้อง "มีรายการ" ถ้ามีคาบที่มีผลในวันนั้น (`classesOn` ซึ่งคืนว่างถ้านอกภาค) **หรือ** มีการใช้ห้อง |
| 360–363 | แบ่งเป็นสองกลุ่ม: มีรายการ / ไม่มี |
| 364–365 | เทอมของตาราง และวันนี้อยู่นอกภาคไหม ใช้ตัดสินว่าจะขึ้นกล่องส้มหรือไม่ |
| 366–368 | เวลาตอนนี้แบบ `HH:mm` ส่งให้การ์ดไฮไลต์คาบที่ "กำลังเรียนอยู่" (ส่งเฉพาะตอนดูวันนี้ บรรทัด 459 `nowText: date == today ? nowText : null`) |

### การ์ดห้อง: คาบเรียนกับการใช้ห้องเรียงรวมกัน

ไฟล์ `lib/screens/schedule_screen.dart` บรรทัด 977–1016

```dart:977
  bool _isNow(String start, String end) {
    final now = nowText;
    return now != null && now.compareTo(start) >= 0 && now.compareTo(end) < 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // คาบเรียนกับการใช้ห้องเรียงรวมกันตามเวลาเริ่ม
    final rows = <({String start, Widget child})>[
      for (final schedule in schedules)
        (
          start: schedule.startTime,
          child: _EntryRow(
            time: '${schedule.startTime} - ${schedule.endTime}',
            title: schedule.subjectName,
            lines: [
              if (schedule.section.isNotEmpty) schedule.section,
              if (schedule.instructor.isNotEmpty) schedule.instructor,
            ],
            isNow: _isNow(schedule.startTime, schedule.endTime),
          ),
        ),
      for (final booking in bookings)
        (
          start: booking.startTime,
          child: _EntryRow(
            key: Key('booking-row-${booking.id}'),
            time: '${booking.startTime} - ${booking.endTime}',
            title: booking.title,
            tag: bookingCategoryLabel(booking.category, isThai),
            lines: [
              if (booking.note.isNotEmpty) booking.note,
              describeBookingRepeat(booking, isThai),
            ],
            isNow: _isNow(booking.startTime, booking.endTime),
            onTap: isAdmin ? () => onBookingTap(booking) : null,
          ),
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));
```

| บรรทัด | อธิบาย |
|---|---|
| 977–980 | "กำลังเกิดขึ้นตอนนี้" = เวลาตอนนี้ ≥ เวลาเริ่ม และ < เวลาจบ เทียบข้อความ `HH:mm` ได้ตรงเพราะเติมศูนย์ครบสองหลัก |
| 986 | **Record ของ Dart 3** `({String start, Widget child})` คือคู่ข้อมูลแบบมีชื่อ ไม่ต้องสร้างคลาสใหม่แค่เพื่อจับคู่ "เวลาเริ่ม" กับ "วิดเจ็ต" |
| 987–999 | หนึ่งแถวต่อหนึ่งคาบเรียน: เวลา ชื่อวิชา กลุ่มเรียน อาจารย์ |
| 1000–1015 | หนึ่งแถวต่อหนึ่งการใช้ห้อง: มีป้ายประเภท (`tag` เช่น "ประชุม") และบรรทัดอธิบายการทำซ้ำ เช่น "ทุกวันพุธ · 7 ต.ค. 2569 – 31 ธ.ค. 2569" แอดมินแตะได้ (`onTap`) คนอื่นแตะไม่ได้ (`null`) |
| 1016 | เรียงรวมทั้งสองชนิดตามเวลาเริ่ม ด้วย cascade `..sort` แล้วนำ `.child` ไปแสดง |

`_EntryRow` ใช้สีหลัก (เขียว) กับคาบเรียน และสีฟ้า (`AppColors.blue`) กับการใช้ห้อง แถวที่กำลังเกิดขึ้นมีพื้นสีจาง ๆ และแถวที่แตะได้มีไอคอน ⋮ ท้ายแถว ป้ายนับบนหัวการ์ดเปลี่ยนจาก "N คาบ" เป็น "N รายการ" เพราะนับรวมการใช้ห้องด้วย

### เมนูของการใช้ห้อง: แก้ / หยุดตั้งแต่วันนี้ / ลบทั้งชุด

แอดมินแตะแถวการใช้ห้อง → `_bookingActions` เปิดแผ่นเลื่อนจากล่าง (`showModalBottomSheet`) มี 3 ตัวเลือก

ไฟล์ `lib/screens/schedule_screen.dart` บรรทัด 147–151

```dart:147
  Future<void> _bookingActions(RoomBooking booking) async {
    final isThai = AppLocalizations.of(context).isThai;
    final date = _date;
    final repeating = booking.repeat != BookingRepeat.once;
    final canStop = repeating && date.compareTo(booking.startDate) > 0;
```

| ตัวเลือก | แสดงเมื่อ | ทำอะไร |
|---|---|---|
| แก้ไข | เสมอ | เปิด `showBookingEditor(..., booking: booking)` ฟอร์มเดียวกับตอนเพิ่ม แต่ใส่ค่าเดิมไว้ |
| หยุดตั้งแต่ (วันที่ดู) | การจองที่ทำซ้ำ **และ** วันที่ดูอยู่หลังวันเริ่ม (`canStop`) | `updateBooking(booking.copyWith(endDate: addDaysIso(date, -1)))` ตั้งวันสิ้นสุดเป็น **เมื่อวานของวันที่ดู** ครั้งก่อนหน้ายังเก็บไว้ |
| ลบ / ลบทั้งชุด | เสมอ | ถามยืนยันด้วย `AlertDialog` (บอกการทำซ้ำในเนื้อหา) แล้ว `deleteBooking(id)` |

> [!WHY]
> **ทำไมมี "หยุดตั้งแต่วันนี้" แยกจาก "ลบ"** การประชุมประจำทุกวันพุธที่ทำมาแล้ว 5 สัปดาห์แล้วยกเลิก ถ้าลบทั้งชุด ประวัติ 5 ครั้งที่ผ่านมาจะหายไปด้วย (ข้อมูลนี้มีผลกับการตัดสินของระบบปิดแอร์ย้อนหลัง และใช้ตอบคำถามว่าทำไมวันนั้นแอร์ไม่ปิด) การตัดวันสิ้นสุดเก็บอดีตไว้และหยุดเฉพาะอนาคต เงื่อนไข `date > startDate` กันกรณีหยุดตั้งแต่วันแรก ซึ่งจะทำให้วันสิ้นสุดก่อนวันเริ่ม (ใช้ลบแทน)

> [!NOTE]
> โค้ดเก็บ `final messenger = ScaffoldMessenger.of(context);` ไว้ **ก่อน** `await` (บรรทัด 229) แล้วค่อยใช้หลัง await หลักนี้กันปัญหา "ใช้ `BuildContext` ข้ามช่วง async" ซึ่ง lint `use_build_context_synchronously` เตือน หน้าปฏิทินภาคเรียนใช้หลักเดียวกัน (สร้างข้อความ `done` ก่อน `await`)

### ดาวน์โหลดตารางเป็น CSV

ไฟล์ `lib/screens/schedule_screen.dart` บรรทัด 283–305

```dart:283
  Future<void> _downloadCsv() async {
    final controller = widget.controller;
    final semester = controller.timetable?.semester ?? '';
    final label = semester.isEmpty ? 'current' : semester.replaceAll('/', '-');
    final csv = schedulesToCsv(controller.schedules, semester);
    final result = await saveExportFile(
      fileName: 'rmutt-timetable-$label-$_today.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
      fileExtension: 'csv',
      mimeType: 'text/csv',
      typeLabel: 'CSV',
    );
    if (!mounted) return;
    if (result.status == FileSaveStatus.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(result.error ?? 'Error'))),
      );
    } else if (result.status == FileSaveStatus.saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('CSV file saved.'))),
      );
    }
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 286 | ชื่อไฟล์ใช้ภาคเรียนแต่เปลี่ยน `/` เป็น `-` (`1/2569` → `1-2569`) เพราะ `/` คือตัวแบ่งโฟลเดอร์ ไม่มีภาคเรียนใช้คำว่า `current` |
| 287 | สร้าง CSV ในเครื่องจากข้อมูลที่โหลดไว้แล้ว ไม่ต้องขอเซิร์ฟเวอร์ |
| 288–294 | ใช้ตัวบันทึกไฟล์กลาง: มือถือเปิดเมนูแชร์ คอมพิวเตอร์เปิดกล่องบันทึกเป็น ได้ชื่อเช่น `rmutt-timetable-1-2569-2026-10-09.csv` |
| 290 | `utf8.encode` แปลงข้อความเป็นไบต์แบบ UTF-8 (ภาษาไทยหนึ่งตัวใช้ 3 ไบต์) |
| 296–304 | แจ้งผลเฉพาะ "พลาด" กับ "บันทึกแล้ว" กรณีแชร์หรือผู้ใช้กดยกเลิกไม่ต้องแจ้ง |

### `_TimetableInfoCard`: บอกว่าตารางนี้ของเทอมไหน และมีผลไหม

ตารางแต่ละเทอมไม่เหมือนกัน ถ้าลืมเปลี่ยน ระบบปิดแอร์จะใช้คาบของเทอมเก่า (คอมเมนต์ในโค้ด) การ์ดนี้จึงแสดงสถานะ 3 แบบ

| สถานการณ์ | สิ่งที่แสดง |
|---|---|
| ยังไม่รู้ภาคเรียน (นำเข้าด้วยรุ่นเก่า หรือเพิ่มคาบเอง) | "ยังไม่ระบุภาคเรียน — นำเข้าจากไฟล์ครั้งถัดไประบบจะจำให้" |
| รู้ภาคเรียน แต่ยังไม่ตั้งวันเปิด–ปิด | ป้ายส้ม "ยังไม่ได้ตั้งวันเปิด–ปิดภาค" + "ระบบใช้ตารางนี้ทุกวัน รวมช่วงปิดภาค" + ปุ่ม "ตั้งวันเปิด–ปิด" (แอดมิน) |
| ตั้งวันแล้ว | ป้ายสถานะ (เขียว "กำลังเปิดภาค" / ฟ้า "ยังไม่เปิดภาค" / เทา "ปิดภาคแล้ว") + ช่วงวันที่ + "อีก N วันปิดภาค" หรือ "ทุกห้องถือว่าว่างจนถึงวันเปิดภาค (อีก N วัน)" |

สถานะคำนวณในเครื่องด้วย `term.statusOn(today)` และนับวันด้วย `daysBetweenIso` (บรรทัด 700–717) ไม่ใช้สถานะที่เซิร์ฟเวอร์ส่งมา เพื่อให้ถูกต้องแม้เปิดแอปค้างข้ามวัน

> [!WHY]
> **ทำไมต้องบอกผลต่อระบบปิดแอร์ในข้อความ** ผู้ใช้ทั่วไปไม่รู้ว่าวันเปิด–ปิดภาคเกี่ยวกับแอร์อย่างไร ข้อความ "ทุกห้องถือว่าว่าง" บอกตรง ๆ ว่าช่วงนั้นระบบจะรอแค่ 5 นาที (แทน 15) แล้วสั่งปิด และจะแจ้งเตือนเมื่อมีคนเปิดแอร์ใช้ ถ้าเห็นแอร์ถูกปิดเร็วในช่วงสอบหรือภาคฤดูร้อน ผู้ใช้จะรู้ว่าต้องไปตั้งวันหรือเพิ่มการใช้ห้อง

### เลขวันในสัปดาห์ (ฟังก์ชันเดิม ยังใช้อยู่)

ไฟล์ `lib/screens/schedule_screen.dart` บรรทัด 19–31

```dart:19
int scheduleDayIndexForDate(DateTime date) => date.weekday % 7;

DateTime scheduleDateForDay(DateTime anchorDate, int scheduleDay) {
  assert(scheduleDay >= 0 && scheduleDay <= 6);
  final dateOnly = DateTime(
    anchorDate.year,
    anchorDate.month,
    anchorDate.day,
  );
  return dateOnly.add(
    Duration(days: scheduleDay - scheduleDayIndexForDate(dateOnly)),
  );
}
```

1. **บรรทัด 19** — Dart ให้ `weekday` จันทร์ = 1 … อาทิตย์ = 7 แต่ตารางเรียนในระบบใช้อาทิตย์ = 0 … เสาร์ = 6 (`% 7` แปลง 7 เป็น 0)
2. **บรรทัด 21–31** — หาวันที่จริงของ "วัน X ในสัปดาห์เดียวกับวันนี้" ตอนนี้หน้าจอใช้ตัวช่วยแบบข้อความใน `room_calendar.dart` (`dayOfWeekOfIso`, `weekStartIso`) เป็นหลัก แต่สองฟังก์ชันนี้ยังอยู่ เพราะ `_formatScheduleDate` ของแถบหัวใช้ `scheduleDayIndexForDate` หาชื่อวัน และ `schedule_date_test.dart` ทดสอบทั้งสองฟังก์ชัน

> [!NOTE] ตารางเรียนไม่ได้ poll
> `ScheduleController` โหลดตารางครั้งเดียวตอนเข้าระบบ โหลดการใช้ห้องทีละสัปดาห์เมื่อเปลี่ยนสัปดาห์ และโหลดใหม่ทั้งหมดเมื่อดึงจอลง (`RefreshIndicator`) หรือหลังแอดมินแก้/นำเข้า เพราะข้อมูลพวกนี้เปลี่ยนนานครั้ง ไม่จำเป็นต้องดึงทุก 10 วินาทีเหมือนสถานะแอร์

## BookingEditorScreen — เพิ่ม/แก้การใช้ห้อง (824 บรรทัด)

ฟอร์มเต็มจอ (`fullscreenDialog: true` จึงมีปุ่ม ✕ แทนลูกศรย้อนกลับ) เปิดจากปุ่มบนหัวหน้าตารางเรียน ปุ่ม ⊕ บนการ์ดห้อง (เลือกห้องให้แล้ว) หรือ "แก้ไข" ในเมนูของรายการ คอมเมนต์หัวไฟล์บอกว่าเหมือนฟอร์มของเว็บแอป (`booking-form.js`)

**ข้อความบนสุดของฟอร์ม** อธิบายผลต่อระบบไว้ก่อนเลย: "ระหว่างเวลาที่ใช้ห้อง ระบบจะถือว่าห้องอยู่ในคาบ: ห้องว่างจะรอ 15 นาทีก่อนปิดแอร์ และไม่แจ้งเตือนว่าใช้แอร์นอกคาบ" (ตรงกับ `services/room-bookings.js` ฝั่ง Backend ที่ระบบปิดแอร์ใช้ถามว่า "ตอนนี้มีการจองไหม")

### ช่องในฟอร์ม

| ช่อง | วิดเจ็ต | ค่าเริ่มต้น (ตอนเพิ่มใหม่) | หมายเหตุ |
|---|---|---|---|
| ห้อง | `DropdownButtonFormField` | ห้องที่ส่งมา หรือว่าง | เรียงตาม ชั้น → เลขห้อง แสดง "16302 · Classroom" |
| ประเภท | `ChoiceChip` 5 อัน | ประชุม | ประชุม คาบเรียน สอบ กิจกรรม อื่น ๆ |
| ใช้ห้องเพื่อ | `TextField` (สูงสุด 150 ตัว) | ว่าง | บังคับกรอก |
| รายละเอียด | `TextField` (สูงสุด 255 ตัว) | ว่าง | ไม่บังคับ ผู้รับผิดชอบ/อาจารย์/กลุ่มเรียน |
| เวลาเริ่ม / สิ้นสุด | `_PickerField` + `showTimePicker` | 13:00 / 15:00 | บังคับรูปแบบ 24 ชั่วโมง และเปิดแบบพิมพ์ตัวเลข |
| ทำซ้ำ | `RadioGroup` + `RadioListTile` | วันเดียว | 3 หรือ 4 แบบ (ดูตารางถัดไป) |
| รายละเอียดการทำซ้ำ | `_repeatDetail` | ตามแบบ | วันที่ / ช่วงวันที่ / วันในสัปดาห์ / ปุ่มลัด |
| สรุป | กล่องสีอ่อน | — | เช่น "ทุกวันพุธ · 7 ต.ค. 2569 – 31 ธ.ค. 2569 · 13:00–15:00 · รวม 13 ครั้ง" |

### การทำซ้ำ 4 แบบ

| แบบ | ช่องที่เห็น | ปุ่มลัดวันสิ้นสุด | บันทึกเป็น |
|---|---|---|---|
| วันเดียว | วันที่ | — | การจอง `once` |
| ทุกวัน | ตั้งแต่ / ถึงวันที่ | "ถึงสิ้นสัปดาห์นี้", "5 วัน" | การจอง `daily` |
| ทุกสัปดาห์ | วันในสัปดาห์ (FilterChip 7 อัน) + ตั้งแต่ / ถึงวันที่ | "ถึงวันปิดภาค (...)" ถ้ามี, "4 สัปดาห์", "3 เดือน" | การจอง `weekly` |
| ในตารางเรียน | วันในสัปดาห์ | — | **คาบเรียนในตาราง** (ไม่ใช่การจอง) หนึ่งคาบต่อหนึ่งวันที่เลือก |

แบบ "ในตารางเรียน" แสดงเฉพาะเมื่อ (1) เป็นการเพิ่มใหม่ (2) Backend รองรับภาคเรียน (`supportsReplaceAll`) และ (3) เลือกประเภท "คาบเรียน" ถ้าผู้ใช้เปลี่ยนประเภทเป็นอย่างอื่นขณะเลือกแบบนี้อยู่ `_setCategory` จะสลับไป "ทุกสัปดาห์" ให้อัตโนมัติ

> [!WHY]
> **ทำไมคาบเรียนประจำถึงไม่บันทึกเป็นการจองรายสัปดาห์** คาบที่ใช้ทั้งเทอมควรอยู่ใน "ตารางเรียน" เพราะมีผลตามวันเปิด–ปิดภาค ถูกล้างพร้อมกันเมื่อนำเข้าตารางเทอมใหม่ และส่งออกเป็น CSV ได้ ถ้าบันทึกเป็นการจอง ข้อมูลจะกระจายสองที่ และอาจค้างข้ามเทอม ส่วนคาบชดเชยไม่กี่ครั้งเหมาะกับการจองที่มีวันที่กำกับ

### การตั้งค่าเริ่มต้นที่ช่วยผู้ใช้

ไฟล์ `lib/screens/booking_editor_screen.dart` บรรทัด 147–154

```dart:147
    _startDate = booking?.startDate ?? date;
    _endDate =
        booking?.endDate ?? addDaysIso(date, 6 - dayOfWeekOfIso(date));
    _startTime = booking?.startTime ?? '13:00';
    _endTime = booking?.endTime ?? '15:00';
    _days = booking != null && booking.daysOfWeek.isNotEmpty
        ? booking.daysOfWeek.toSet()
        : {dayOfWeekOfIso(date)};
```

| บรรทัด | อธิบาย |
|---|---|
| 147 | วันเริ่ม = วันที่ที่กำลังดูอยู่ในหน้าตารางเรียน (ไม่ใช่วันนี้เสมอไป) ผู้ใช้เลื่อนไปวันที่ต้องการก่อนแล้วกดเพิ่มได้เลย |
| 148–149 | วันสิ้นสุดเริ่มที่ **วันเสาร์ของสัปดาห์นั้น** (`6 − วันในสัปดาห์`) เหมาะกับแบบ "ทุกวัน" ที่มักใช้ทั้งสัปดาห์ |
| 152–154 | วันในสัปดาห์เริ่มด้วยวันของวันที่ที่ดู เช่น ดูวันพุธ ก็ติ๊กพุธไว้ให้ |

`_setRepeat` (บรรทัด 216–227) ถ้าเปลี่ยนเป็น "ทุกสัปดาห์" แล้ววันสิ้นสุดยังไม่หลังวันเริ่ม จะตั้งวันสิ้นสุดให้เป็นวันปิดภาค (ถ้ามีและอยู่หลังวันเริ่ม) ไม่งั้นบวก 27 วัน (4 สัปดาห์) ส่วน `_pickDate` ถ้าเลือกวันเริ่มเลยวันสิ้นสุด จะดันวันสิ้นสุดตามมาให้เท่ากัน

### ตรวจข้อมูลก่อนบันทึก

ไฟล์ `lib/screens/booking_editor_screen.dart` บรรทัด 300–339 ตรวจทีละเงื่อนไขตามลำดับ เจอข้อแรกที่ผิดก็หยุดแล้วแสดงข้อความสีแดงใต้กล่องสรุป

| ลำดับ | เงื่อนไข | ข้อความ |
|---|---|---|
| 1 | ไม่ได้เลือกห้อง | กรุณาเลือกห้อง |
| 2 | ไม่ได้กรอกชื่อ | กรุณากรอกชื่อการใช้ห้อง |
| 3 | เวลาสิ้นสุดไม่หลังเวลาเริ่ม | เวลาสิ้นสุดต้องหลังเวลาเริ่ม |
| 4 | ทุกสัปดาห์/ในตาราง แต่ไม่เลือกวัน | กรุณาเลือกวันในสัปดาห์อย่างน้อยหนึ่งวัน |
| 5 | วันสิ้นสุดก่อนวันเริ่ม | วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่ม |
| 6 | นับแล้วได้ 0 ครั้ง (เช่น เลือกวันอาทิตย์ แต่ช่วงวันที่มีแค่จันทร์–ศุกร์) | ในช่วงวันที่ที่เลือกไม่มีวันที่ตรงกับวันในสัปดาห์ที่เลือกเลย |
| 7 | แบบในตาราง และเวลาทับคาบเดิม (`controller.overlaps`) | เวลานี้ทับคาบเรียนเดิมในวัน... |

ไฟล์ `lib/screens/booking_editor_screen.dart` บรรทัด 349–368

```dart:349
    try {
      if (_repeat == _Repeat.timetable) {
        // คาบเรียนประจำ: หนึ่งแถวต่อหนึ่งวัน ผ่าน API ตารางเรียนเดิม
        for (final day in _days.toList()..sort()) {
          await widget.controller.createSchedule(
            ClassSchedule(
              id: '',
              roomNumber: _roomNumber,
              dayOfWeek: day,
              subjectName: _title.text.trim(),
              section: _note.text.trim(),
              startTime: _startTime,
              endTime: _endTime,
            ),
          );
        }
        if (!mounted) return;
        Navigator.of(context).pop(BookingEditorResult.timetable);
        return;
      }
```

| บรรทัด | อธิบาย |
|---|---|
| 352 | วนตามวันที่เลือก เรียงอาทิตย์ → เสาร์ |
| 353–363 | สร้างคาบทีละวันผ่าน `POST /schedules` เดิม (ไม่ต้องมี API ใหม่) ชื่อการใช้ห้องกลายเป็นชื่อวิชา รายละเอียดกลายเป็นกลุ่มเรียน |
| 366 | ปิดฟอร์มพร้อมบอกหน้าก่อนว่า "บันทึกเป็นคาบเรียน" หน้าตารางเรียนจึงขึ้น SnackBar ต่างกัน ("เพิ่มคาบเรียนในตารางแล้ว" กับ "เพิ่มการใช้ห้องแล้ว") ผ่าน `enum BookingEditorResult {booking, timetable}` |

> [!WARN]
> แบบ "ในตารางเรียน" สร้างคาบทีละวันด้วยคำขอแยกกัน ไม่อยู่ใน transaction เดียว ถ้าเลือก 3 วันแล้วเน็ตหลุดหลังวันที่ 2 จะได้แค่ 2 คาบ (ฟอร์มขึ้น error และยังเปิดอยู่ ผู้ใช้เห็นได้ในหน้าตารางเรียนว่าคาบไหนเข้าแล้ว) เป็นข้อแลกเพื่อใช้ API เดิมโดยไม่ต้องเพิ่ม endpoint

กรณีอื่นสร้าง `RoomBooking` แล้วเรียก `createBooking` หรือ `updateBooking` (ถ้าแก้ไข) ระหว่างบันทึก `_busy = true` ปิดทุกช่องและเปลี่ยนไอคอนปุ่มเป็นวงหมุน กันกดซ้ำ ถ้าเซิร์ฟเวอร์ปฏิเสธ (เช่น ห้องไม่มีจริง) ข้อความ error แสดงในฟอร์มโดยไม่ปิดฟอร์ม ผู้ใช้แก้แล้วกดใหม่ได้

ฟังก์ชันระดับไฟล์ที่หน้าอื่นใช้ร่วม: `l10n(context, ไทย, อังกฤษ)` (เลือกข้อความตามภาษา ใช้กับข้อความใหม่ที่ยังไม่อยู่ในตารางแปล), `shortIsoDate(iso, isThai)` (`9 ต.ค. 2569`), `describeBookingRepeat(booking, isThai)`, `thaiDayNames`, `englishDayNames`

## TermCalendarScreen — ปฏิทินภาคเรียน (496 บรรทัด)

เปิดจากปุ่ม "ปฏิทินภาคเรียน" ในการ์ดตาราง ทุกคนดูได้ แต่เพิ่ม/แก้/ลบได้เฉพาะแอดมิน (ปุ่มลอย "เพิ่มภาคเรียน" และปุ่มแก้/ลบบนการ์ดแสดงเมื่อ `isAdmin`) ข้อความอธิบายบนสุดของหน้าสรุปกติกาทั้งหมด

> ตารางเรียนมีผลเฉพาะระหว่างวันเปิด–ปิดของภาคเรียนของมัน ก่อนเปิดหรือหลังปิดภาค ระบบถือว่าทุกห้องว่าง: ห้องว่างเกิน 5 นาทีสั่งปิดแอร์ และแจ้งเตือนเมื่อมีคนเปิดแอร์ใช้ จึงไม่ต้องล้างตารางตอนปิดภาค และนำเข้าตารางเทอมหน้าไว้ล่วงหน้าได้ ภาคเรียนที่ไม่ได้ตั้งวันไว้ ระบบใช้ตารางทุกวัน

> [!WHY]
> **ทำไมใช้วันเปิด–ปิดแทนการล้างตาราง** ถ้าต้องล้างตารางทุกครั้งที่ปิดภาค คนต้องจำไปกดในวันนั้นพอดี ลืมเมื่อไรระบบก็ใช้ตารางเก่าตลอดช่วงปิดภาค (แอร์ห้องว่างรอ 15 นาทีแทน 5 และไม่แจ้งเตือน) การตั้งวันไว้ล่วงหน้าทำให้ระบบ "เปลี่ยนโหมด" เองตามปฏิทิน และยังนำเข้าตารางเทอมหน้าไว้ก่อนได้โดยไม่กระทบเทอมปัจจุบัน

### ส่วนประกอบ

| ส่วน | หน้าที่ |
|---|---|
| `TermCalendarScreen` (StatelessWidget) | รายการเทอม ฟัง `controller` ผ่าน `AnimatedBuilder` ดึงจอลงเพื่อ `reloadCalendar()` |
| `_TermCard` | การ์ดหนึ่งเทอม: ชื่อเทอม ช่วงวันที่ ป้ายสถานะ กรอบเขียวหนาถ้าเป็นเทอมของตารางที่ใช้อยู่ ปุ่มแก้ ✎ และลบ 🗑 (แอดมิน) |
| `editAcademicTerm(context, controller, {term, presetSemester})` | ฟังก์ชันระดับไฟล์ เปิด `_TermDialog` ใช้ได้ทั้งจากหน้านี้และจากปุ่ม "ตั้งวันเปิด–ปิด" ในหน้าตารางเรียน |
| `_TermDialog` | กล่องกรอกภาคเรียน (`1/2569`) + ปุ่มเลือกช่วงวัน (`showAppDateRangePicker` ปฏิทิน พ.ศ. ของแอป) |
| `termStatusLabel(status, isThai)` | คืน Record `(ข้อความ, สี)` ใช้ร่วมกับ `_TimetableInfoCard` |

### เดาภาคเรียนถัดไปให้

ไฟล์ `lib/screens/term_calendar_screen.dart` บรรทัด 127–139

```dart:127
  String _suggestSemester() {
    final preset = presetSemester;
    if (preset != null && preset.isNotEmpty) return preset;
    final current = controller.timetable?.semester ?? '';
    if (current.isNotEmpty && controller.termFor(current) == null) return current;
    final terms = controller.terms;
    final last = terms.isEmpty ? current : terms.last.semester;
    final match = RegExp(r'^([1-3])/(\d{4})$').firstMatch(last);
    if (match == null) return '';
    final term = int.parse(match.group(1)!);
    final year = int.parse(match.group(2)!);
    return term >= 2 ? '1/${year + 1}' : '2/$year';
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 128–129 | ถ้าถูกเปิดพร้อมชื่อเทอมที่กำหนด ใช้ชื่อนั้น |
| 130–131 | ถ้าตารางที่ใช้อยู่เป็นของเทอมที่ **ยังไม่ได้ตั้งวัน** เสนอเทอมนั้นก่อน (สำคัญที่สุด เพราะกระทบระบบปิดแอร์ตอนนี้) |
| 132–135 | ไม่งั้นดูเทอมล่าสุดในปฏิทิน แยกเลขเทอมกับปีด้วย Regex กลุ่ม `()` |
| 136–138 | เทอม 1 → เสนอ 2 ปีเดียวกัน, เทอม 2 หรือ 3 (ฤดูร้อน) → เสนอเทอม 1 ปีถัดไป เช่น `2/2569` → `1/2570` |

### บันทึกและลบ

- `_TermDialog._save()` ตรวจรูปแบบด้วย `AcademicTerm.semesterPattern` (`^[1-3]/\d{4}$`) และต้องเลือกครบทั้งวันเปิดและวันปิด แล้วเรียก `controller.saveAcademicTerm(..., previousSemester: ชื่อเดิม)` (ถ้าแก้ชื่อเทอม Controller ลบชื่อเดิมให้)
- `_deleteTerm` ถามยืนยัน ข้อความเปลี่ยนตามว่าเป็นเทอมของตารางที่ใช้อยู่ไหม: ถ้าใช่ เตือนว่า "เมื่อลบแล้วระบบจะใช้ตารางทุกวัน รวมช่วงปิดภาค" ถ้าไม่ใช่ บอกว่า "ตารางเรียนและข้อมูลไฟฟ้าไม่ถูกลบ"

ไฟล์ `lib/screens/term_calendar_screen.dart` บรรทัด 177–191

```dart:177
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final done = l10n(
      context,
      'ลบภาคเรียน ${term.semester} แล้ว',
      'Semester ${term.semester} removed.',
    );
    try {
      await controller.deleteAcademicTerm(term.semester);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(context.tr(error.toString()))));
    }
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 177 | หน้านี้เป็น `StatelessWidget` จึงไม่มี `mounted` ของ State ใช้ `context.mounted` แทน (มีใน Flutter 3.7 ขึ้นไป) |
| 178–183 | **เตรียมทุกอย่างที่ต้องใช้ `context` ก่อน `await`** ทั้งตัวแสดง SnackBar และข้อความ "ลบแล้ว" (ข้อความต้องใช้ `context` เพื่อรู้ภาษา) |
| 185–186 | หลัง await ใช้แค่ตัวแปรที่เตรียมไว้ ไม่แตะ `context` |
| 188 | ในกรณีพลาด ต้องใช้ `context.tr` แปลข้อความ จึงเช็ก `context.mounted` ก่อน |

> [!NOTE]
> ข้อความถูกสร้างด้วย `l10n(context, ...)` **ก่อน** `await controller.deleteAcademicTerm(...)` เพราะถ้าสร้างหลัง await แล้วผู้ใช้ออกจากหน้าไประหว่างรอ `context` จะใช้ไม่ได้แล้ว lint `use_build_context_synchronously` ของ `flutter analyze` (ที่ CI รันทุก push) จะเตือนทันที

## วิดเจ็ตย่อยที่ใช้ซ้ำ

### FloorSelector

แถบปุ่มชั้นในกรอบโค้ง ปุ่มที่เลือกพื้นสีหลัก ใช้ `LayoutBuilder` คำนวณความกว้างปุ่ม = (ความกว้างทั้งหมด − ช่องว่าง) / จำนวนปุ่ม แต่ไม่น้อยกว่า 88 px ถ้าชั้นเยอะจนแคบกว่านั้น `ListView.separated` แนวนอนให้เลื่อนได้
ค่าพิเศษ: `-1` → "All floors" (หน้า Analytics), `0` → "Special" (ห้องพิเศษ), อื่น ๆ → "Floor N" ถ้ารายการว่างจะแสดง `[0]`
เปลี่ยนสีแบบนุ่มนวลด้วย `AnimatedContainer` (180 ms)

### WeekdaySelector

7 ปุ่มเท่ากันด้วย `Expanded` ใน `Row` (`List.generate(7, ...)`) ปุ่มที่เลือกพื้นสีหลัก ห่อด้วย `Semantics(button: true, selected: ...)` เพื่อโปรแกรมอ่านหน้าจอ และให้ `Key('$dayKeyPrefix-$index')` ไว้สำหรับเทสต์

### StatusPill

ป้ายทรงแคปซูลมีข้อความ (และไอคอนถ้ามี ผ่านพารามิเตอร์ `icon` ซึ่ง `AirControlBadge` ใช้) สีพื้นเป็นสีเดียวกับตัวอักษรแต่โปร่ง 12% ในธีมมืดผสมสีขาว 45% เข้าไปในตัวอักษร (`Color.lerp(color, Colors.white, 0.45)`) เพราะสีสถานะออกแบบมาสำหรับพื้นสว่าง บนพื้นเข้มจะจมหาย

### SectionTitle

`Row` ที่มีหัวข้อตัวหนาใน `Expanded` และวิดเจ็ตท้าย (ถ้ามี) เช่น ป้าย "3 need attention" ในหน้า Home ช่วยให้ทุกหน้ามีหัวข้อหน้าตาเดียวกัน

### BrandMark และ BrandWordmark

`BrandMark` วาดโลโก้ด้วย `CustomPainter`: พื้นสี่เหลี่ยมมุมมนสีถ่าน ใบไม้สีเขียว (เส้นโค้ง `cubicTo` สองเส้น) เส้นกลางใบ และตัว R สีขาว (`lineTo` + `arcToPoint`)
พิกัดทั้งหมดมาจากไฟล์ SVG ขนาด 240×240 แล้ว `canvas.scale(size.shortestSide / 240)` ให้ย่อขยายได้ทุกขนาดโดยไม่เบลอ
คอมเมนต์บอกเหตุผลว่าแอปยังไม่มีแพ็กเกจอ่าน SVG และ PNG จะเบลอเมื่อขยาย `shouldRepaint` คืน `false` เพราะรูปไม่เคยเปลี่ยน

`BrandWordmark` ใช้ `Text.rich` กับ `TextSpan` สามท่อน: "R" สีเขียว, "MUTT " สีตามแถบหัว, "Energy" สีเขียว

## เส้นทางของผู้ใช้ (User journey)

| ขั้น | หน้าจอ | สิ่งที่เกิด |
|---|---|---|
| 1 | `AuthLoadingScreen` | เปิดแอป `AuthController.initialize()` ลองกู้ session จาก token ที่เก็บไว้ |
| 2 | `LoginScreen` | ไม่มี session → กรอกชื่อ/รหัส (หรือไป `ForgotPasswordScreen` / แผ่นติดต่อแอดมิน) |
| 3 | `AppShell` → `HomeScreen` | ล็อกอินสำเร็จ controller ทั้งหมดเริ่มโหลดและตั้ง Timer เห็นพลังงานรวมและแจ้งเตือน |
| 4 | `AnalyticsScreen` | ดูกราฟ เปลี่ยนช่วงเวลา (`PeriodSelector`) และชั้น ดูห้องที่กินไฟมาก |
| 5 | `ScheduleScreen` | ดูว่าวันนี้ (หรือวันไหนก็ได้ เลื่อนทีละสัปดาห์) ห้องไหนมีคาบหรือมีการใช้ห้อง แอดมินเพิ่มการใช้ห้อง (`BookingEditorScreen`) หรือตั้งวันเปิด–ปิดภาค (`TermCalendarScreen`) |
| 6 | `RoomsScreen` (แท็บ Control) | เลือกชั้นและห้อง เห็นสถานะคนและนับถอยหลัง |
| 7 | `RoomControlScreen` | ดึงข้อมูลห้องทันที เห็นการ์ดแอร์ทุกเครื่อง |
| 8 | `AirControlCard` / `FullRemoteSheet` | กดสั่งงาน → REST → Backend → MQTT → ESP32 → IR (หรือสายแอร์ Daikin) → แอร์ |
| 9 | กลับ (pop) | กลับแท็บเดิม State ของแท็บยังอยู่ (IndexedStack) |

ทางลัด: แตะใบแจ้งเตือนในหน้า Home หรือการ์ดห้องในหน้า Schedule ก็เข้าขั้น 7 ได้เลย

## ข้อสังเกตและจุดที่ไม่สอดคล้องในโค้ด

> [!WARN] สิ่งที่ควรรู้ก่อนถูกอาจารย์ถาม
> 1. **ชื่อตัวแปรค้างจากรุ่นเก่า** — `LoginScreen` ใช้ `_rememberPassword`, `_setRememberPassword` และพารามิเตอร์ `rememberPassword` แต่จริง ๆ จำแค่ชื่อผู้ใช้ (ป้ายบนจอเขียนถูก "Remember username") โค้ดเติมรหัสผ่านจาก `remembered.password` ไม่เคยทำงานเพราะ service คืน `''` เสมอ
> 2. **มี mock rooms ตอนเริ่มต้น** — `main.dart` ส่ง `MockData.createRooms()` ให้ `AppShell` ก่อนข้อมูลจริงจาก Backend จะมาแทน ถ้า Backend โหลดไม่สำเร็จ แท็บ Control/Schedule จะยังแสดงห้องจำลอง ซึ่งอาจทำให้เข้าใจผิดว่าเป็นข้อมูลจริง
> 3. **นิยาม "เปิดอยู่" ในการ์ดสรุปห้อง** — จำนวน "Air conditioners running" ใช้ `isPoweredOn` จึงนับแอร์ที่เปิดด้วยรีโมตจริงด้วย แต่ยังขัดกับ "Total power" ได้ในกรณีกลับกัน คือระบบสั่งเปิดแล้วแต่ IR ไม่ถึงแอร์ (`isOn` เป็นจริง แต่ `isRunning` เป็นเท็จ)
> 4. **นาฬิกาสองตัวทำงานไม่เหมือนกัน** — `AutoOffCountdown` เปลี่ยนเป็น "Sending the off command" เมื่อเวลาหมด (`seconds <= 0`) แต่ `_CountdownChip` ในการ์ดแอร์จะค้างที่ `00:00` จนรอบ polling ถัดไปส่ง `attempts > 0` มา (สูงสุด ~10 วินาที)
> 5. **ปุ่มรีเฟรชในหน้าห้องอาจยิงซ้อน** — ปุ่มปิดตาม `isLoading` ซึ่งเป็น true เฉพาะตอนรอบของตัวเองวิ่ง ระหว่างที่รอรอบอัตโนมัติที่ค้างอยู่ (`await inFlight`) ปุ่มยังกดได้ ถ้ากดสองครั้งในช่วงนั้น ทั้งสองจะยิงคำขอใหม่หลังรอบเดิมจบ (ไม่ทำให้ข้อมูลผิด แค่ยิงเกิน) และปุ่มไม่ดู `roomController.isLoading`
> 6. **การ์ดพลังงานหน้า Home กดแล้วไปแท็บ Control** — แตะแถบ "Estimated cost" เรียก `onOpenControl` ไปหน้าเลือกห้อง ซึ่งไม่เกี่ยวกับค่าไฟโดยตรง ผู้ใช้อาจคาดว่าจะไปหน้า Analytics
> 7. **ป้ายแท็บไม่ตรงชื่อไฟล์** — แท็บ "Control" (index 3) แสดง `RoomsScreen` ไม่ใช่ `RoomControlScreen` ซึ่งเปิดแยกด้วย Navigator
> 8. **ห้องในหน้า Schedule แสดงประเภทซ้ำ** — `_CompactRoomCard` แสดง `room.type` ใต้หมายเลขห้อง และถ้าห้องไม่มีคนก็แสดง `room.type` ซ้ำอีกที่ท้ายแถว (ถ้ามีคนแสดง "In Use")
> 9. **"วันนี้" อัปเดตตอนโหลดใหม่เท่านั้น** — `today` เป็น getter ที่อ่าน `controller.today` (วันที่ตามเวลาไทยจากเซิร์ฟเวอร์) แต่ค่านี้ได้มาตอน `reloadCalendar()` ถ้าเปิดแอปค้างข้ามคืนโดยไม่ดึงจอลง "Today" ยังเป็นวันเก่า
> 10. **`editableCopy()` ไม่คัดลอกฟิลด์ปิดอัตโนมัติ** — สำเนาไม่มี `autoOffEnabled`, `autoOffDeadlineAt`, `autoOffAttempts`, `autoOffInClass` ไม่กระทบการส่งคำสั่ง (ฟิลด์เหล่านี้ไม่อยู่ใน `toCommandJson`) แต่ถ้าวันหนึ่งรีโมตเต็มต้องแสดงนับถอยหลังจะได้ค่าว่าง
> 11. **คำอธิบายใน `formatEnergy` ขัดกันเอง** — คอมเมนต์ตัวอย่างเขียน `0.42 kWh -> 420.00 Wh` แล้ววงเล็บบอก "เหลือ 420 Wh" ผลจริงคือ `420 Wh` (≥ 100 ใช้ทศนิยม 0 ตำแหน่ง)
> 12. **กรองชั้นสองชั้นในหน้า Analytics** — controller ส่ง `floor` ให้ Backend กรองแล้ว หน้าจอยังกรอง `summary.rooms` ด้วย `floorNumber` อีกรอบ ไม่ผิดแต่ซ้ำซ้อน (และกันไว้ได้ถ้า Backend ไม่กรอง)

## หลักการออกแบบที่ควรจำ

- **หน้าจอไม่ยิง HTTP เอง** ทุกอย่างผ่าน controller → service ทำให้หน้าจอเรียบง่าย และเปลี่ยน service เป็นตัวจำลองตอนเทสต์ได้
- **controller อยู่ที่ AppShell** อายุเท่ากับช่วงที่ล็อกอิน ใช้ร่วมหลายหน้า และถูก dispose พร้อมกันตอน logout
- **ฟังการเปลี่ยนแปลงด้วย AnimatedBuilder + ChangeNotifier** แทน state management ภายนอก (เช่น Provider, Bloc) ลด dependency
- **Polling ทุก 10 วินาที (ห้อง/แอร์) และ 30 วินาที (สรุปพลังงาน/แจ้งเตือน)** เพราะแอปคุยแค่ REST, เชื่อถือได้บนมือถือ และความล่าช้าระดับวินาทีรับได้ รอบอัตโนมัติไม่ซ้อนกัน ส่วนรีเฟรชเองได้ข้อมูลใหม่เสมอ
- **ดึงทันทีเมื่อเปิดหน้าห้อง** (`addPostFrameCallback`) ไม่ต้องรอรอบถัดไป
- **คำสั่งแอร์เป็น "สถานะเต็มชุด" และใช้ร่าง** จอเปลี่ยนเมื่อเซิร์ฟเวอร์รับแล้ว ถ้าล้มเหลวจอไม่โกหก
- **ปิดปุ่มระหว่างส่ง** (`_busy`, `_isLoading`) กันกดซ้ำ ด้วยการส่ง `onPressed: null`
- **นับถอยหลังเดินบนเครื่องจาก deadline ของเซิร์ฟเวอร์** ลื่น ไม่เปลืองเน็ต และการตัดสินใจจริงอยู่ที่เซิร์ฟเวอร์
- **หน่วยพลังงานอัตโนมัติแต่ใช้หน่วยร่วมในชุดเดียวกัน** อ่านง่ายและเปรียบเทียบได้ตรง
- **วาดกราฟเองด้วย CustomPainter** คุมหน้าตา ป้ายกันทับกัน และสูตรพิกัดเดียวระหว่างวาดกับแตะ โดยไม่ต้องพึ่งแพ็กเกจกราฟ
- **เช็ก `mounted` หลังทุก `await`** และ **dispose ทุกอย่างที่สร้างเอง** (TextEditingController, Timer, listener)
- **จำกัดความกว้าง 480 px** ให้หน้าตาเหมือนมือถือแม้เปิดบนแท็บเล็ตหรือเดสก์ท็อป
- **เขียนข้อความเป็นอังกฤษแล้วแปลอัตโนมัติ** ผ่าน `Text` ที่ถูกแทนที่และ `context.tr` ประกอบประโยคเต็มก่อนแปลเพื่อให้ลำดับคำภาษาไทยถูก

## คำถามที่อาจารย์อาจถาม

1. **StatelessWidget กับ StatefulWidget ต่างกันอย่างไร ยกตัวอย่างจากโปรเจกต์**
   Stateless ไม่มีข้อมูลที่เปลี่ยนเอง เช่น `StatusPill`, `HomeScreen` (เปลี่ยนได้เพราะฟัง controller ผ่าน AnimatedBuilder) Stateful มี State ที่จำค่าเองและมีวงจรชีวิต เช่น `LoginScreen` จำ `_isLoading`, `AutoOffCountdown` ถือ Timer ที่ต้อง cancel ใน dispose

2. **กดปุ่มเปิดแอร์ในแอปแล้วเกิดอะไรขึ้นบ้าง**
   `AirControlCard._change` สร้างร่าง (`editableCopy`) ตั้ง `isOn` → `_sendDraft` ปิดปุ่ม → `AirConditionerController.sendCommand` → `POST /air-conditioners/{deviceId}/command` พร้อมสถานะเต็มชุด → Backend publish MQTT → ESP32 ยิง IR (บอร์ดสายแอร์ส่งเข้าสายแทน) → เซิร์ฟเวอร์ตอบ 200 → แอป copy ร่างลง object จริง จอเปลี่ยน + SnackBar → รอบ polling ถัดไปยืนยันด้วยกำลังไฟจาก PZEM

3. **ทำไมใช้ polling ไม่ใช้ push แบบ real-time**
   แอปคุยแค่ REST ไม่ต้องเปิด MQTT สู่สาธารณะ การเชื่อมต่อค้างบนมือถือหลุดบ่อย polling ง่ายและทนกว่า ข้อมูลช้า 10 วินาทีรับได้ และผลของคำสั่งที่ผู้ใช้กดเองขึ้นจอทันทีอยู่แล้ว

4. **ถ้ากดรีเฟรชตอนที่รอบอัตโนมัติกำลังโหลดอยู่ จะเกิดอะไร**
   `refresh(silent: false)` เห็น `_inFlight` จะ `await` ให้รอบนั้นจบก่อน แล้วยิงรอบใหม่ จึงได้ข้อมูล ณ ตอนกดเสมอ และไม่มีสองคำขอวิ่งพร้อมกัน ส่วนรอบอัตโนมัติที่ชนรอบอื่นจะถูกข้าม

5. **ทำไมนาฬิกานับถอยหลังไม่ถามเซิร์ฟเวอร์ทุกวินาที**
   เซิร์ฟเวอร์ส่ง deadline ครั้งเดียว แอปคำนวณ `deadline − now` ทุกวินาทีด้วย Timer ในเครื่อง ไม่เปลืองเน็ต ตัวเลขลื่น และค่าถูกเสมอเพราะอิงเวลาสัมบูรณ์ การสั่งปิดจริงทำที่เซิร์ฟเวอร์ แอปแค่แสดง

6. **`mounted` คืออะไร ทำไมต้องเช็ก**
   บอกว่า State ยังอยู่ในต้นไม้ไหม หลัง await หน้าอาจถูกปิดแล้ว เช่นล็อกอินสำเร็จทำให้ LoginScreen หายไปก่อนถึง `finally` ถ้าเรียก setState หรือใช้ context ตอนนั้นจะ error

7. **กราฟวาดอย่างไร ใช้ไลบรารีอะไร**
   ไม่ใช้ไลบรารี วาดเองด้วย `CustomPainter` เป็นกราฟแท่ง: แบ่งความกว้างเป็นช่องเท่ากัน หนึ่งแท่งต่อชั่วโมง/วัน (`EnergyChartGeometry.slot`) ความสูงเทียบกับตัวเลขกลมจาก `niceScaleMax` (เช่น สูงสุดจริง 3.56 → แกน 4) วาดเส้นตาราง 3 เส้น แท่งมุมมน ค่า 0 เป็นขีดจาง ป้ายเฉพาะแท่งสูงสุด และเส้นประค่าเฉลี่ยเมื่อเป็นรายวัน ≥ 7 วัน ส่วนการแตะใช้ `GestureDetector` + `indexAt` หาร x ด้วยความกว้างช่องได้แท่งทันที

8. **ทำไมหน่วยบนกราฟเปลี่ยนเป็น Wh บ้าง kWh บ้าง**
   `formatEnergy` เลือกหน่วยตามขนาด (< 1 kWh → Wh, ≥ 1000 → MWh) เพื่อค่าน้อยไม่กลายเป็น 0.0 แต่ส่งค่าสูงสุดของชุดเป็น `scaleReference` ทุกจุดในกราฟเดียวกันจึงใช้หน่วยเดียวกัน เทียบกันได้ตรง

9. **ทำไมสลับแท็บแล้วชั้นหรือวันที่เลือกไว้ไม่หาย**
   `AppShell` ใช้ `IndexedStack` ซึ่งเก็บทุกหน้าไว้ในต้นไม้ตลอด State ของแต่ละแท็บจึงอยู่ครบ แค่ซ่อนหน้าที่ไม่ได้เลือก

10. **หน้าตารางเรียนรู้ได้อย่างไรว่าวันไหน "ไม่มีเรียน" ทั้งที่ตารางมีคาบวันพุธ**
    `ScheduleController.classesOn(ห้อง, วันที่)` เช็ก `isOutsideTerm(วันที่)` ก่อน ถ้าภาคเรียนของตารางตั้งวันเปิด–ปิดไว้และวันนั้นอยู่นอกช่วง จะคืนรายการว่าง หน้าจอขึ้นกล่องส้ม "อยู่นอกภาคเรียน" ตรรกะเดียวกับที่ระบบปิดแอร์ของ Backend ใช้ จึงเห็นตรงกับที่ระบบตัดสินจริง

11. **ถ้าจะใช้ห้องประชุมวันพุธทุกสัปดาห์ถึงสิ้นเทอม ทำอย่างไร และระบบปิดแอร์รู้ได้อย่างไร**
    แอดมินกด "เพิ่มการใช้ห้อง" เลือกห้อง ประเภท "ประชุม" แบบ "ทุกสัปดาห์" ติ๊กวันพุธ กดปุ่มลัด "ถึงวันปิดภาค" ฟอร์มสรุปจำนวนครั้งให้ก่อนบันทึก แอปส่ง `POST /bookings` เก็บในตาราง `room_bookings` ระบบปิดแอร์ถาม `services/room-bookings.js` ทุกรอบว่าตอนนี้มีการจองไหม ถ้ามีถือว่าอยู่ในคาบ (รอ 15 นาที ไม่แจ้งเตือน)

12. **ฟอร์มล็อกอินตรวจข้อมูลอย่างไร และแสดง error อย่างไร**
    `Form` + `GlobalKey<FormState>` เรียก `validate()` ซึ่งรัน validator ของทุก `TextFormField` (ห้ามว่าง) ข้อความ error ขึ้นใต้ช่อง ส่วน error จากเซิร์ฟเวอร์ (รหัสผิด เซิร์ฟเวอร์ช้า) จับด้วย `on ApiException` แล้วแสดง SnackBar สีแดง

13. **แอร์บางเครื่องมีปุ่มน้อยกว่าเครื่องอื่น เพราะอะไร**
    เครื่องที่ป้ายขึ้น "Daikin · สายแอร์" ใช้บอร์ดที่ต่อสายแอร์แทนรีโมตติดผนัง (`protocol = DAIKIN_WIRED`) ซึ่งสั่งได้แค่ที่รีโมตติดผนังทำได้: เปิด/ปิด 16–30 °C, Cool/Dry/Fan, พัดลม 4 ระดับ, ส่าย/หยุด และ Sleep `FullRemoteSheet` ถาม getter `supportsEco`, `supportsSleep` ฯลฯ ของโมเดลแล้วซ่อนสวิตช์ที่ทำไม่ได้ และ `normalizeForProtocol()` ปรับร่างก่อนส่งเพื่อไม่ให้ Backend ตอบ 400

14. **ลบแอร์หรือเซ็นเซอร์ในแอปแล้ว บอร์ดจริงเป็นอย่างไร**
    แอปเรียก `DELETE /air-conditioners/:deviceId` (หรือ `/occupancy-sensors/:deviceId`) แล้ว Backend ส่ง `{"action":"unprovision"}` ไปที่ topic `command` ของบอร์ดและรอคำตอบไม่เกิน 4 วินาที บอร์ดที่ออนไลน์จะล้าง Wi-Fi/MQTT/ห้องใน NVS แล้วรีบูตเข้าโหมดตั้งค่าบลูทูธ จากนั้น Backend จึงล้าง retained และลบบัญชี MQTT ผลว่าบอร์ดยืนยันไหมอยู่ในช่อง `boardCleared` ของคำตอบ แต่แอปไม่ได้อ่านค่านี้ ผู้ใช้จึงไม่รู้จากแอปว่าบอร์ดออฟไลน์อยู่และยังจำค่าเดิม

15. **ป้าย "Daikin · สายแอร์" รู้ยี่ห้อได้อย่างไร และทำไมรับแค่ `protocol` ไม่รับทั้งแอร์**
    `AirControlBadge` เรียก `airBrandOf(protocol)` กับ `airControlTypeOf(protocol)` จากไฟล์โมเดล เช่น `HAIER_AC176` → "Haier · รีโมต IR" (สีเทา ไอคอนรีโมต) และ `DAIKIN_WIRED` → "Daikin · สายแอร์" (สีฟ้า ไอคอนสายไฟ) รับแค่ข้อความเพราะป้ายไม่ต้องรู้สถานะอื่นของแอร์ จะเอาไปวางที่ไหนก็ได้ที่รู้โปรโตคอล และใช้ `StatusPill` เดิม จึงได้สีที่ปรับให้อ่านง่ายในธีมมืดไปด้วย ป้ายแสดงทั้งตอนแอร์ออนไลน์และออฟไลน์ เพื่อให้รู้ว่าเครื่องนี้ปุ่มน้อยกว่าเพราะชนิดบอร์ด ไม่ใช่เพราะแอปเสีย

16. **ทำไมเลือกโหมด Dry ในรีโมตเต็มแล้วสวิตช์ Sleep หายไป**
    รีโมตติดผนังของ Daikin ใช้ Sleep ในโหมด Dry ไม่ได้ โมเดลจึงเขียน `supportsSleep` ขึ้นกับ `mode` และตอนกดชิปโหมด `FullRemoteSheet` เรียก `normalizeForProtocol()` ทันทีสำหรับเครื่องสายแอร์ ค่า `sleep` จึงถูกปิดในร่างคำสั่ง และ `setState` วาดจอใหม่โดยไม่มีสวิตช์ Sleep ในเฟรมเดียวกัน ถ้าไม่ปรับค่า ร่างจะส่ง `sleep: true` ในโหมด Dry ไปให้ Backend ซึ่งบังคับปิดซ้ำอยู่ดี

## สรุปและเช็กลิสต์ความเข้าใจ

ถ้าตอบข้อเหล่านี้ได้โดยไม่เปิดโค้ด แปลว่าเข้าใจบทนี้แล้ว

- [ ] อธิบายความต่างของ `StatelessWidget` กับ `StatefulWidget` และยกตัวอย่างจากโปรเจกต์ได้อย่างละตัว
- [ ] เล่าเส้นทางของการกดปุ่ม "เปิดเครื่อง" ตั้งแต่ `AirControlCard` จนถึงแอร์ และบอกได้ว่าหน้าจอรู้ผลจากอะไร (คำตอบ HTTP + `isRunning` จาก PZEM)
- [ ] บอกได้ว่า Timer 10 วินาทีอยู่ที่ไหน และ `_inFlight` กันคำขอซ้อนอย่างไร
- [ ] อธิบายได้ว่าทำไมนาฬิกานับถอยหลังปิดแอร์คำนวณในเครื่องจาก deadline ไม่ถามเซิร์ฟเวอร์ทุกวินาที
- [ ] อธิบายการวาดกราฟแท่งด้วย `CustomPainter` (`niceScaleMax`, `EnergyChartGeometry`, การแตะดูค่า) และการเลือกหน่วย W/kWh/MWh
- [ ] อธิบายได้ว่า `IndexedStack` ใน `AppShell` ทำให้สลับแท็บแล้วค่าที่เลือกไม่หายอย่างไร
- [ ] อธิบายว่าทำไมปุ่มบนการ์ดส่งคำสั่งทันที แต่รีโมตเต็มต้องกดส่งครั้งเดียว
- [ ] บอกได้ว่า `AirControlBadge` แสดงที่ไหนบ้าง (การ์ดสองหน้าตา + หัวรีโมตเต็ม) สีและไอคอนต่างกันอย่างไรระหว่างสายแอร์กับ IR
- [ ] อธิบายได้ว่ารีโมตเต็มซ่อนสวิตช์ทีละตัวด้วย `supportsXxx` อย่างไร ซ่อนหัวข้อทั้งหมดเมื่อไหร่ และทำไมเลือกซ่อนแทน disable
- [ ] อธิบายได้ว่าลบแอร์ในแอปแล้วบอร์ดถูกล้างค่า (unprovision) อย่างไร และข้อจำกัดที่แอปไม่แสดง `boardCleared`
- [ ] อธิบายหน้าตารางเรียน: โหลดทีละสัปดาห์ คาบเรียนกับการใช้ห้องเรียงรวมกัน และวันนอกภาคเรียนขึ้นว่าไม่มีเรียน
