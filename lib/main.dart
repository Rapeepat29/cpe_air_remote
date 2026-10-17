import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'controllers/app_settings_controller.dart';
import 'controllers/auth_controller.dart';
import 'data/mock_data.dart';
import 'localization/app_localizations.dart';
import 'screens/auth/auth_loading_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/app_shell.dart';
import 'services/auth_repository.dart';
import 'services/auth_service.dart';
import 'services/air_conditioner_repository.dart';
import 'services/air_conditioner_service.dart';
import 'services/ble_provisioning_service.dart';
import 'services/alert_notifier.dart';
import 'services/mobile_notification_gateway.dart';
import 'services/alert_repository.dart';
import 'services/alert_service.dart';
import 'services/energy_repository.dart';
import 'services/energy_service.dart';
import 'services/occupancy_sensor_repository.dart';
import 'services/occupancy_sensor_service.dart';
import 'services/schedule_repository.dart';
import 'services/schedule_service.dart';
import 'services/room_repository.dart';
import 'services/room_service.dart';
import 'services/user_repository.dart';
import 'services/system_settings_repository.dart';
import 'services/system_settings_service.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const CpeAirRemoteApp());
}

class CpeAirRemoteApp extends StatefulWidget {
  const CpeAirRemoteApp({
    this.authRepository,
    this.appSettingsController,
    this.scheduleRepository,
    this.roomRepository,
    this.airConditionerRepository,
    this.bleProvisioningService,
    this.occupancySensorRepository,
    this.userRepository,
    this.energyRepository,
    this.alertRepository,
    this.alertNotifier,
    this.systemSettingsRepository,
    super.key,
  });

  final AuthRepository? authRepository;
  final AppSettingsController? appSettingsController;
  final ScheduleRepository? scheduleRepository;
  final RoomRepository? roomRepository;
  final AirConditionerRepository? airConditionerRepository;
  final BleProvisioningService? bleProvisioningService;
  final OccupancySensorRepository? occupancySensorRepository;
  final UserRepository? userRepository;
  final EnergyRepository? energyRepository;
  final AlertRepository? alertRepository;
  final AlertNotifier? alertNotifier;
  final SystemSettingsRepository? systemSettingsRepository;

  @override
  State<CpeAirRemoteApp> createState() => _CpeAirRemoteAppState();
}

class _CpeAirRemoteAppState extends State<CpeAirRemoteApp> {
  late final AuthController _authController;
  late final AppSettingsController _appSettingsController;
  late final ScheduleRepository _scheduleRepository;
  late final RoomRepository _roomRepository;
  late final AirConditionerRepository _airConditionerRepository;
  late final BleProvisioningService _bleProvisioningService;
  late final OccupancySensorRepository _occupancySensorRepository;
  late final UserRepository _userRepository;
  late final EnergyRepository _energyRepository;
  late final AlertRepository _alertRepository;
  late final AlertNotifier _alertNotifier;
  late final SystemSettingsRepository _systemSettingsRepository;
  late final bool _ownsAppSettingsController;

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
    _bleProvisioningService =
        widget.bleProvisioningService ?? BleProvisioningService();
    _occupancySensorRepository =
        widget.occupancySensorRepository ?? OccupancySensorService();
    _userRepository = widget.userRepository ?? UserService();
    _energyRepository = widget.energyRepository ?? EnergyService();
    _alertRepository = widget.alertRepository ?? AlertService();
    _alertNotifier =
        widget.alertNotifier ??
        (LocalAlertNotifier.isSupported
            ? LocalAlertNotifier()
            : const NoopAlertNotifier());
    _systemSettingsRepository =
        widget.systemSettingsRepository ?? SystemSettingsService();
    _authController.initialize();
    _appSettingsController.initialize();
  }

  @override
  void dispose() {
    _authController.dispose();
    if (_ownsAppSettingsController) {
      _appSettingsController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appSettingsController,
      builder: (context, _) => MaterialApp(
        title: 'RMUTT Save Energy',
        debugShowCheckedModeBanner: false,
        locale: _appSettingsController.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // ธีมที่ผู้ใช้เลือกอยู่ใน theme เสมอ ส่วน darkTheme ใช้เฉพาะตอนเลือก
        // "ตามเครื่อง" แล้วเครื่องอยู่ในโหมดมืด
        theme: AppTheme.forChoice(_appSettingsController.themeChoice),
        darkTheme: AppTheme.dark,
        // ขนาดตัวอักษรที่ผู้ใช้เลือกในแอป คูณกับที่ตั้งไว้ในระบบ Android
        // วางไว้ที่ builder เพื่อให้ครอบทั้ง route และ dialog ทุกใบ
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(
                _appSettingsController.resolvedTextScale(
                  media.textScaler.scale(1),
                ),
              ),
            ),
            child: child,
          );
        },
        themeMode:
            _appSettingsController.themeChoice == AppThemeChoice.system
            ? ThemeMode.system
            : ThemeMode.light,
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
                roomRepository: _roomRepository,
                airConditionerRepository: _airConditionerRepository,
                bleProvisioningService: _bleProvisioningService,
                occupancySensorRepository: _occupancySensorRepository,
                userRepository: _userRepository,
                energyRepository: _energyRepository,
                alertRepository: _alertRepository,
                alertNotifier: _alertNotifier,
                systemSettingsRepository: _systemSettingsRepository,
                authController: _authController,
                onLogout: _authController.logout,
              ),
            };
          },
        ),
      ),
    );
  }
}
