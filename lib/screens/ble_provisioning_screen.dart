import '../localization/localized_material.dart';
import '../models/air_conditioner.dart';
import '../models/provisioning.dart';
import '../services/air_conditioner_repository.dart';
import '../services/ble_provisioning_service.dart';
import '../theme/app_theme.dart';
import '../widgets/air_control_badge.dart';

class BleProvisioningScreen extends StatefulWidget {
  const BleProvisioningScreen({
    required this.roomNumber,
    required this.usedAirNumbers,
    required this.repository,
    required this.bleService,
    this.existingAir,
    super.key,
  });

  final String roomNumber;
  final Set<int> usedAirNumbers;
  final AirConditionerRepository repository;
  final BleProvisioningService bleService;
  final AirConditioner? existingAir;

  @override
  State<BleProvisioningScreen> createState() =>
      _BleProvisioningScreenState();
}

class _BleProvisioningScreenState extends State<BleProvisioningScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsKey = GlobalKey();
  final _name = TextEditingController();
  final _wifiSsid = TextEditingController();
  final _wifiPassword = TextEditingController();

  List<BleDeviceCandidate> _devices = const [];
  BleDeviceCandidate? _selectedDevice;
  BleDeviceIdentity? _identity;
  int? _airNumber;
  String _protocol = 'HAIER_AC160';
  TimeOfDay? _dailyOn;
  TimeOfDay? _dailyOff;
  bool _isScanning = false;
  bool _isScanningWifi = false;
  bool _isReadingIdentity = false;
  bool _isProvisioning = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAir;
    _airNumber = existing?.id ?? _availableAirNumbers.firstOrNull;
    if (_airNumber != null) {
      _name.text = existing?.name ?? 'Air $_airNumber';
    }
    if (existing != null) {
      _protocol = existing.protocol;
      _dailyOn = _parseTime(existing.dailyOn);
      _dailyOff = _parseTime(existing.dailyOff);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scan();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _wifiSsid.dispose();
    _wifiPassword.dispose();
    super.dispose();
  }

  List<int> get _availableAirNumbers => widget.existingAir == null ? [
    for (var number = 1; number <= 6; number++)
      if (!widget.usedAirNumbers.contains(number)) number,
  ] : [widget.existingAir!.id];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            widget.existingAir == null
                ? 'Configure ESP32 via Bluetooth'
                : 'Reconfigure ESP32 via Bluetooth',
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _StepHeader(
              number: 1,
              title: context.tr('Find nearby RMUTT ESP32'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _isScanning || _isProvisioning ? null : _scan,
              icon: _isScanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching_rounded),
              label: Text(
                context.tr(_isScanning ? 'Searching...' : 'Search Bluetooth'),
              ),
            ),
            const SizedBox(height: 10),
            if (!_isScanning && _devices.isEmpty)
              _InfoCard(
                icon: Icons.developer_board_rounded,
                text: context.tr(
                  'Turn on the ESP32 in setup mode. Its name must start with RMUTT-AC-.',
                ),
              ),
            // Flutter 3.35 ขึ้นไปให้ RadioGroup ถือค่าที่เลือก แทน groupValue ของแต่ละปุ่ม
            RadioGroup<BleDeviceCandidate>(
              groupValue: _selectedDevice,
              onChanged: (value) {
                if (value == null || _isReadingIdentity || _isProvisioning) {
                  return;
                }
                _selectDevice(value);
              },
              child: Column(
                children: [
                  for (final candidate in _devices)
                    RadioListTile<BleDeviceCandidate>(
                      value: candidate,
                      enabled: !(_isReadingIdentity || _isProvisioning),
                      title: Text(
                        candidate.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        _isReadingIdentity && _selectedDevice == candidate
                            ? context.tr('Connecting and checking ESP32...')
                            : 'RSSI ${candidate.rssi} dBm',
                      ),
                      secondary: const Icon(Icons.memory_rounded),
                    ),
                ],
              ),
            ),
            if (_isReadingIdentity)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              _BleErrorCard(
                message: _errorMessage!,
                onRetry: _selectedDevice == null || _isReadingIdentity
                    ? null
                    : () => _selectDevice(_selectedDevice!),
              ),
            ],
            if (_identity != null) ...[
              Container(
                key: _detailsKey,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_identity!.deviceId}\n'
                            'Firmware ${_identity!.firmwareVersion}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr(
                              _identity!.isWired
                                  ? 'Board type: wired controller (replaces the wall remote)'
                                  : 'Board type: IR remote',
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _StepHeader(
                number: 2,
                title: context.tr('Select room and air conditioner number'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: widget.roomNumber,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: context.tr('Room'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _airNumber,
                      decoration: InputDecoration(
                        labelText: context.tr('Air number'),
                      ),
                      items: _availableAirNumbers
                          .map(
                            (number) => DropdownMenuItem(
                              value: number,
                              child: Text('${context.tr('Unit')} $number'),
                            ),
                          )
                          .toList(),
                      onChanged: widget.existingAir != null
                          ? null
                          : (value) {
                        setState(() {
                          _airNumber = value;
                          _name.text = 'Air $value';
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _name,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: context.tr('Air Conditioner Name'),
                ),
                validator: _required,
              ),
              const SizedBox(height: 4),
              if (_identity!.isWired)
                _WiredBrandField(brand: _wiredBrand(_identity!))
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('protocol-${_identity!.deviceId}'),
                  initialValue: _protocol,
                  decoration: InputDecoration(
                    labelText: context.tr('Air Conditioner Brand / Protocol'),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'SAIJO_DENKI',
                      child: Text('Saijo Denki'),
                    ),
                    DropdownMenuItem(
                      value: 'DAIKIN',
                      child: Text('Daikin'),
                    ),
                    DropdownMenuItem(
                      value: 'MITSUBISHI_AC',
                      child: Text('Mitsubishi Electric'),
                    ),
                    DropdownMenuItem(
                      value: 'PANASONIC_AC',
                      child: Text('Panasonic'),
                    ),
                    DropdownMenuItem(
                      value: 'GREE',
                      child: Text('Gree'),
                    ),
                    DropdownMenuItem(
                      value: 'MIDEA',
                      child: Text('Midea'),
                    ),
                    DropdownMenuItem(
                      value: 'LG',
                      child: Text('LG'),
                    ),
                    DropdownMenuItem(
                      value: 'SAMSUNG_AC',
                      child: Text('Samsung'),
                    ),
                    DropdownMenuItem(
                      value: 'TOSHIBA_AC',
                      child: Text('Toshiba'),
                    ),
                    DropdownMenuItem(
                      value: 'HITACHI_AC',
                      child: Text('Hitachi'),
                    ),
                    DropdownMenuItem(
                      value: 'FUJITSU_AC',
                      child: Text('Fujitsu'),
                    ),
                    DropdownMenuItem(
                      value: 'KELVINATOR',
                      child: Text('Kelvinator'),
                    ),
                    DropdownMenuItem(
                      value: 'SHARP_AC',
                      child: Text('Sharp'),
                    ),
                    DropdownMenuItem(
                      value: 'ELECTRA_AC',
                      child: Text('Electra'),
                    ),
                    DropdownMenuItem(
                      value: 'HAIER_AC160',
                      child: Text('Haier 160-bit'),
                    ),
                    DropdownMenuItem(
                      value: 'HAIER_AC176',
                      child: Text('Haier 176-bit'),
                    ),
                    DropdownMenuItem(
                      value: 'HAIER_AC_YRW02',
                      child: Text('Haier YR-W02'),
                    ),
                    DropdownMenuItem(
                      value: 'HAIER_AC',
                      child: Text('Haier legacy'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _protocol = value!),
                ),
              const SizedBox(height: 20),
              _StepHeader(
                number: 3,
                title: context.tr('Select Wi-Fi and enter its password'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _wifiSsid,
                readOnly: true,
                onTap: _isProvisioning ? null : _scanWifiNetworks,
                decoration: InputDecoration(
                  labelText: context.tr('Wi-Fi name (SSID)'),
                  prefixIcon: const Icon(Icons.wifi_rounded),
                  helperText: context.tr(
                    'Tap to select Wi-Fi detected by this ESP32.',
                  ),
                  suffixIcon: _isScanningWifi
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          key: const Key('scan-wifi-button'),
                          tooltip: context.tr('Scan nearby Wi-Fi'),
                          onPressed: _isProvisioning
                              ? null
                              : _scanWifiNetworks,
                          icon: const Icon(Icons.search_rounded),
                        ),
                ),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _wifiPassword,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.tr('Wi-Fi password'),
                  prefixIcon: const Icon(Icons.password_rounded),
                  helperText: widget.existingAir == null
                      ? null
                      : context.tr(
                          'Leave blank to keep the password already saved on ESP32.',
                        ),
                ),
                validator: _validateWifiPassword,
              ),
              const SizedBox(height: 10),
              _InfoCard(
                icon: Icons.cloud_done_rounded,
                text: context.tr(
                  'MQTT is configured automatically by the server. No MQTT settings are required here.',
                ),
              ),
              const SizedBox(height: 20),
              _StepHeader(
                number: 4,
                title: context.tr('Daily automatic schedule (optional)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(isOn: true),
                      icon: const Icon(Icons.alarm_on_rounded),
                      label: Text(
                        _dailyOn == null
                            ? context.tr('Auto On')
                            : _formatTime(_dailyOn!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(isOn: false),
                      icon: const Icon(Icons.alarm_off_rounded),
                      label: Text(
                        _dailyOff == null
                            ? context.tr('Auto Off')
                            : _formatTime(_dailyOff!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('provision-esp32-button'),
                onPressed: _isProvisioning ? null : _provision,
                icon: _isProvisioning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  context.tr(
                    _isProvisioning
                        ? 'Saving to ESP32...'
                        : 'Save configuration to ESP32',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'The app checks the database for duplicate room/unit and Device ID before writing to ESP32.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _scan() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _devices = const [];
      _selectedDevice = null;
      _identity = null;
    });
    try {
      final devices = await widget.bleService.scan();
      if (!mounted) return;
      BleDeviceCandidate? matchingDevice;
      final expectedName = widget.existingAir?.bleName;
      final expectedDeviceId = widget.existingAir?.deviceId;
      for (final candidate in devices) {
        if ((expectedName != null && candidate.name == expectedName) ||
            (expectedDeviceId != null &&
                candidate.name == 'RMUTT-AC-${expectedDeviceId.substring(6)}')) {
          matchingDevice = candidate;
          break;
        }
      }
      setState(() {
        _devices = devices;
        if (devices.isEmpty) {
          _errorMessage = context.tr('No RMUTT ESP32 was found nearby.');
        }
      });
      if (matchingDevice != null && mounted) {
        await _selectDevice(matchingDevice);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = context.tr('$error'));
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _selectDevice(BleDeviceCandidate candidate) async {
    setState(() {
      _selectedDevice = candidate;
      _identity = null;
      _isReadingIdentity = true;
      _errorMessage = null;
    });
    try {
      final identity = await widget.bleService.readIdentity(candidate);
      if (!mounted) return;
      final expectedDeviceId = widget.existingAir?.deviceId;
      if (expectedDeviceId != null && identity.deviceId != expectedDeviceId) {
        throw BleProvisioningException(
          context.tr(
            'Select the same ESP32 that is already assigned to this air conditioner.',
          ),
        );
      }
      setState(() {
        _identity = identity;
        _applySavedBoardSettings(identity);
        _protocolForBoard(identity);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final detailsContext = _detailsKey.currentContext;
        if (mounted && detailsContext != null) {
          Scrollable.ensureVisible(
            detailsContext,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            alignment: 0.05,
          );
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = context.tr('$error'));
      }
    } finally {
      if (mounted) setState(() => _isReadingIdentity = false);
    }
  }

  Future<void> _scanWifiNetworks() async {
    final candidate = _selectedDevice;
    if (candidate == null || _identity == null) {
      setState(() {
        _errorMessage = context.tr(
          'Select and verify an ESP32 before scanning Wi-Fi.',
        );
      });
      return;
    }

    setState(() {
      _isScanningWifi = true;
      _errorMessage = null;
    });
    try {
      final networks = await widget.bleService.scanWifiNetworks(candidate);
      if (!mounted) return;
      setState(() => _isScanningWifi = false);
      if (networks.isEmpty) {
        setState(() {
          _errorMessage = context.tr(
            'No Wi-Fi network was detected. You can enter the SSID manually.',
          );
        });
        return;
      }

      final selectedSsid = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('Wi-Fi detected by ESP32'),
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          sheetContext,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: networks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final network = networks[index];
                      return ListTile(
                        leading: Icon(
                          network.isSecure
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          network.ssid,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('${network.rssi} dBm'),
                        trailing: const Icon(Icons.wifi_rounded),
                        onTap: () => Navigator.pop(
                          sheetContext,
                          network.ssid,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: Text(
                    context.tr(
                      'Only Wi-Fi detected by this ESP32 can be selected.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (selectedSsid != null && mounted) {
        setState(() {
          _wifiSsid.text = selectedSsid;
          _errorMessage = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = context.tr('$error'));
      }
    } finally {
      if (mounted && _isScanningWifi) {
        setState(() => _isScanningWifi = false);
      }
    }
  }

  Future<void> _provision() async {
    if (!_formKey.currentState!.validate()) return;
    final identity = _identity;
    final candidate = _selectedDevice;
    final airNumber = _airNumber;
    if (identity == null || candidate == null || airNumber == null) {
      setState(() {
        _errorMessage = context.tr(
          'Select and verify an ESP32 before saving.',
        );
      });
      return;
    }

    setState(() {
      _isProvisioning = true;
      _errorMessage = null;
    });
    final request = AirProvisioningRequest(
      identity: identity,
      roomNumber: widget.roomNumber,
      airNumber: airNumber,
      name: _name.text.trim(),
      protocol: _protocol,
      wifiSsid: _wifiSsid.text.trim(),
      wifiPassword: _wifiPassword.text,
      keepWifiPassword: _shouldKeepWifiPassword(identity),
      dailyOn: _timeValue(_dailyOn),
      dailyOff: _timeValue(_dailyOff),
    );
    try {
      final reservation = await widget.repository.reserve(request);
      await widget.bleService.provision(
        candidate,
        request.toBleJson(reservation),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Wi-Fi verified and configuration saved. ESP32 is connecting to MQTT.',
            ),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        final retryHint = context.tr(
          'Correct the Wi-Fi password and press Save again. You do not need to scan for the ESP32 again.',
        );
        setState(() {
          _errorMessage = '${context.tr('$error')}\n$retryHint';
        });
      }
    } finally {
      if (mounted) setState(() => _isProvisioning = false);
    }
  }

  Future<void> _pickTime({required bool isOn}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isOn
          ? (_dailyOn ?? const TimeOfDay(hour: 8, minute: 0))
          : (_dailyOff ?? const TimeOfDay(hour: 17, minute: 0)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isOn) {
        _dailyOn = selected;
      } else {
        _dailyOff = selected;
      }
    });
  }

  String? _required(String? value) {
    return value != null && value.trim().isNotEmpty
        ? null
        : context.tr('This field is required');
  }

  void _applySavedBoardSettings(BleDeviceIdentity identity) {
    if (widget.existingAir == null || !identity.configured) return;

    if (identity.airName.isNotEmpty) _name.text = identity.airName;
    if (identity.airProtocol.isNotEmpty) _protocol = identity.airProtocol;
    if (identity.wifiSsid.isNotEmpty) _wifiSsid.text = identity.wifiSsid;
    _wifiPassword.clear();
    _dailyOn = _parseTime(identity.dailyOn);
    _dailyOff = _parseTime(identity.dailyOff);
  }

  /// บอร์ดสายแอร์ใช้ DAIKIN_WIRED เสมอ (ผู้ใช้ไม่ต้องเลือกยี่ห้อ)
  /// บอร์ด IR ห้ามใช้ DAIKIN_WIRED (เช่น เปลี่ยนบอร์ดสายแอร์ออกแล้วใส่บอร์ด IR แทน)
  void _protocolForBoard(BleDeviceIdentity identity) {
    if (identity.isWired) {
      _protocol = daikinWiredProtocol;
    } else if (_protocol == daikinWiredProtocol) {
      _protocol = 'DAIKIN';
    }
  }

  String _wiredBrand(BleDeviceIdentity identity) {
    return identity.brand.isNotEmpty
        ? identity.brand
        : airBrandOf(daikinWiredProtocol);
  }

  bool _shouldKeepWifiPassword(BleDeviceIdentity identity) {
    return _wifiPassword.text.isEmpty &&
        identity.configured &&
        identity.hasWifiPassword &&
        _wifiSsid.text.trim() == identity.wifiSsid;
  }

  String? _validateWifiPassword(String? value) {
    final password = value ?? '';
    if (password.length >= 8) return null;
    final identity = _identity;
    if (identity != null &&
        _shouldKeepWifiPassword(identity)) {
      return null;
    }
    return context.tr('Enter at least 8 characters');
  }

  String _formatTime(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String? _timeValue(TimeOfDay? value) {
    return value == null ? null : _formatTime(value);
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: Text(
            '$number',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _BleErrorCard extends StatelessWidget {
  const _BleErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('ble-connection-error'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const Key('retry-ble-connection'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.tr('Try connecting again')),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// ช่องยี่ห้อของบอร์ดสายแอร์: แสดงยี่ห้อกับชนิดบอร์ดแบบล็อกไว้ ไม่ให้เลือกยี่ห้อ IR
class _WiredBrandField extends StatelessWidget {
  const _WiredBrandField({required this.brand});

  final String brand;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: context.tr('Air Conditioner Brand / Protocol'),
            suffixIcon: Tooltip(
              message: context.tr('Set by the board'),
              child: const Icon(Icons.lock_outline_rounded),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.cable_rounded, size: 20, color: AppColors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$brand · ${context.tr('Wired (replaces the wall remote)')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.blue.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(
                    'This board plugs into the air-conditioner cable in place of the Daikin wall remote. Available: on/off, 16–30 °C, Cool / Dry / Fan, fan Low / Medium / High / Auto, swing on/off and Sleep.',
                  ),
                  style: TextStyle(fontSize: 13, color: colors.onSurface),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
