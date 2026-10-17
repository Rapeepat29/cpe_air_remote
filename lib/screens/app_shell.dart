import '../localization/localized_material.dart';

import '../controllers/app_settings_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/air_conditioner_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/energy_controller.dart';
import '../controllers/schedule_controller.dart';
import '../controllers/room_controller.dart';
import '../controllers/system_settings_controller.dart';
import '../controllers/user_controller.dart';
import '../models/auth_user.dart';
import '../models/room.dart';
import '../models/system_alert.dart';
import '../services/alert_notifier.dart';
import '../services/schedule_repository.dart';
import '../services/system_settings_repository.dart';
import '../services/room_repository.dart';
import '../services/air_conditioner_repository.dart';
import '../services/ble_provisioning_service.dart';
import '../services/alert_repository.dart';
import '../services/energy_repository.dart';
import '../services/occupancy_sensor_repository.dart';
import '../services/user_repository.dart';
import 'analytics_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'room_control_screen.dart';
import 'rooms_screen.dart';
import 'schedule_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.rooms,
    required this.user,
    required this.appSettingsController,
    required this.scheduleRepository,
    required this.roomRepository,
    required this.airConditionerRepository,
    required this.bleProvisioningService,
    required this.occupancySensorRepository,
    required this.userRepository,
    required this.energyRepository,
    required this.alertRepository,
    required this.authController,
    required this.onLogout,
    required this.systemSettingsRepository,
    this.alertNotifier,
    super.key,
  });

  final List<Room> rooms;
  final AuthUser user;
  final AppSettingsController appSettingsController;
  final ScheduleRepository scheduleRepository;
  final RoomRepository roomRepository;
  final AirConditionerRepository airConditionerRepository;
  final BleProvisioningService bleProvisioningService;
  final OccupancySensorRepository occupancySensorRepository;
  final UserRepository userRepository;
  final EnergyRepository energyRepository;
  final AlertRepository alertRepository;
  final AuthController authController;
  final Future<void> Function() onLogout;

  /// ตัวเด้งแจ้งเตือนของเครื่อง เว้นว่างไว้ได้ เช่นในเทสต์หรือบนแพลตฟอร์ม
  /// ที่ยังไม่รองรับ แล้วจะไม่มีอะไรเด้งเลย ส่วนอื่นทำงานตามปกติ
  final AlertNotifier? alertNotifier;
  final SystemSettingsRepository systemSettingsRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late final List<Room> _rooms;
  late final ScheduleController _scheduleController;
  late final RoomController _roomController;
  late final AirConditionerController _airController;
  late final UserController _userController;
  late final EnergyController _energyController;
  late final DashboardController _dashboardController;
  late final SystemSettingsController _systemSettingsController;

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
    // ขอสิทธิ์แจ้งเตือนตั้งแต่เปิดแอป ไม่รอให้มีใบแรก ไม่งั้น iOS จะไม่แสดง
    // แถว "การแจ้งเตือน" ในหน้าตั้งค่า และผู้ใช้ไม่เคยเห็นหน้าต่างขออนุญาต
    widget.alertNotifier?.initialize();
    _initializeRoomsAndAir();
  }

  Future<void> _initializeRoomsAndAir() async {
    await _roomController.initialize();
    await _airController.initialize();
  }

  /// ผู้ใช้เพิ่งสลับสวิตช์ในหน้าตั้งค่า รายการบนหน้าจอต้องเปลี่ยนตามทันที
  void _syncAlertPreferences() {
    _dashboardController.alertPreferences =
        widget.appSettingsController.alertPreferences;
  }

  /// มีใบใหม่เข้ามา เด้งเฉพาะชนิดที่ผู้ใช้เปิดสวิตช์เด้งไว้
  Future<void> _handleNewAlerts(List<SystemAlert> fresh) async {
    final notifier = widget.alertNotifier;
    if (notifier == null) return;

    final wanted = widget.appSettingsController.alertPreferences
        .pushable(fresh);
    if (wanted.isEmpty) return;

    final localizations = AppLocalizations(
      widget.appSettingsController.locale,
    );
    for (final alert in wanted) {
      final text = describeAlert(alert, localizations);
      await notifier.show(
        alert: alert,
        title: text.title,
        body: text.body,
      );
    }
  }

  @override
  void dispose() {
    widget.appSettingsController.removeListener(_syncAlertPreferences);
    _scheduleController.dispose();
    _roomController.dispose();
    _airController.dispose();
    _userController.dispose();
    _energyController.dispose();
    _dashboardController.dispose();
    _systemSettingsController.dispose();
    super.dispose();
  }

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
      AnalyticsScreen(
        rooms: _rooms,
        appSettingsController: widget.appSettingsController,
        dashboardController: _dashboardController,
      ),
      ScheduleScreen(
        rooms: _rooms,
        controller: _scheduleController,
        isAdmin: widget.user.role.toLowerCase() == 'admin',
        onOpenRoom: _openRoom,
        onRoomsChanged: _roomController.reload,
      ),
      RoomsScreen(
        rooms: _rooms,
        controller: _roomController,
        isAdmin: widget.user.role.toLowerCase() == 'admin',
        onOpenRoom: _openRoom,
      ),
      ProfileScreen(
        user: widget.user,
        appSettingsController: widget.appSettingsController,
        userController: _userController,
        energyController: _energyController,
        authController: widget.authController,
        systemSettingsController: _systemSettingsController,
        onLogout: widget.onLogout,
      ),
        ];

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
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.dashboard_rounded),
                      label: context.tr('Home'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: context.tr('Analytics'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: context.tr('Schedule'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.settings_remote_rounded),
                      label: context.tr('Control'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.person_rounded),
                      label: context.tr('Profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
