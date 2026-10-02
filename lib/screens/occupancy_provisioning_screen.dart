import '../localization/localized_material.dart';
import '../models/provisioning.dart';
import '../models/room.dart';
import '../services/ble_provisioning_service.dart';
import '../services/occupancy_sensor_repository.dart';
import '../theme/app_theme.dart';

class OccupancyProvisioningScreen extends StatefulWidget {
  const OccupancyProvisioningScreen({
    required this.room,
    required this.repository,
    required this.bleService,
    super.key,
  });

  final Room room;
  final OccupancySensorRepository repository;
  final BleProvisioningService bleService;

  @override
  State<OccupancyProvisioningScreen> createState() =>
      _OccupancyProvisioningScreenState();
}

class _OccupancyProvisioningScreenState
    extends State<OccupancyProvisioningScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wifiSsid = TextEditingController();
  final _wifiPassword = TextEditingController();

  List<BleDeviceCandidate> _devices = const [];
  BleDeviceCandidate? _selectedDevice;
  BleDeviceIdentity? _identity;
  bool _isScanning = false;
  bool _isReadingIdentity = false;
  bool _isScanningWifi = false;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isReconfigure => widget.room.hasOccupancySensor;

  @override
  void initState() {
    super.initState();
    if (_isReconfigure) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scan();
      });
    }
  }

  @override
  void dispose() {
    _wifiSsid.dispose();
    _wifiPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            _isReconfigure
                ? 'Reconfigure room occupancy sensor'
                : 'Add room occupancy sensor',
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _OccStepHeader(
              number: 1,
              title: context.tr('Find nearby RMUTT-OCC ESP32'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _isScanning || _isSaving ? null : _scan,
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
            const SizedBox(height: 8),
            if (!_isScanning && _devices.isEmpty)
              _OccInfoCard(
                icon: Icons.sensors_rounded,
                text: context.tr(
                  'Turn on the occupancy ESP32 in setup mode. Its name must start with RMUTT-OCC-.',
                ),
              ),
            ..._devices.map(
              (candidate) => RadioListTile<BleDeviceCandidate>(
                value: candidate,
                groupValue: _selectedDevice,
                onChanged: _isReadingIdentity || _isSaving
                    ? null
                    : (value) => _selectDevice(value!),
                title: Text(
                  candidate.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('RSSI ${candidate.rssi} dBm'),
                secondary: const Icon(Icons.radar_rounded),
              ),
            ),
            if (_isReadingIdentity)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_errorMessage!),
              ),
            ],
            if (_identity != null) ...[
              const SizedBox(height: 14),
              _OccInfoCard(
                icon: Icons.verified_rounded,
                text: '${_identity!.deviceId}\n'
                    'Firmware ${_identity!.firmwareVersion}',
                color: AppColors.green,
              ),
              const SizedBox(height: 20),
              _OccStepHeader(
                number: 2,
                title: context.tr('Room and detection rule'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: widget.room.number,
                readOnly: true,
                decoration: InputDecoration(labelText: context.tr('Room')),
              ),
              const SizedBox(height: 10),
              _OccInfoCard(
                icon: Icons.rule_rounded,
                text: context.tr(
                  'Occupied when any LD2410 static target gate is greater than 25. Other radar values are not sent to the app.',
                ),
              ),
              const SizedBox(height: 20),
              _OccStepHeader(
                number: 3,
                title: context.tr('Select Wi-Fi and enter its password'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _wifiSsid,
                decoration: InputDecoration(
                  labelText: context.tr('Wi-Fi name (SSID)'),
                  prefixIcon: const Icon(Icons.wifi_rounded),
                  suffixIcon: _isScanningWifi
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: context.tr('Scan nearby Wi-Fi'),
                          onPressed: _isSaving ? null : _scanWifi,
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
                  helperText: _isReconfigure
                      ? context.tr(
                          'Leave blank to keep the password already saved on ESP32.',
                        )
                      : null,
                ),
                validator: _validateWifiPassword,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  context.tr(
                    _isSaving
                        ? 'Saving to ESP32...'
                        : 'Save configuration to ESP32',
                  ),
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
      _devices = const [];
      _selectedDevice = null;
      _identity = null;
      _errorMessage = null;
    });
    try {
      final devices = await widget.bleService.scan(
        namePrefix: 'RMUTT-OCC-',
      );
      if (!mounted) return;
      BleDeviceCandidate? matching;
      final expectedName = widget.room.occupancySensorBleName;
      for (final candidate in devices) {
        if (expectedName != null && candidate.name == expectedName) {
          matching = candidate;
          break;
        }
      }
      setState(() {
        _devices = devices;
        if (devices.isEmpty) {
          _errorMessage = context.tr(
            'No RMUTT-OCC occupancy ESP32 was found nearby.',
          );
        }
      });
      if (matching != null && mounted) await _selectDevice(matching);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = context.tr('$error'));
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
      if (identity.deviceType != 'occupancy') {
        throw const BleProvisioningException(
          'This ESP32 is not occupancy-sensor firmware.',
        );
      }
      final expected = widget.room.occupancySensorDeviceId;
      if (expected != null && identity.deviceId != expected) {
        throw const BleProvisioningException(
          'Select the same occupancy ESP32 already assigned to this room.',
        );
      }
      setState(() {
        _identity = identity;
        if (identity.configured && identity.wifiSsid.isNotEmpty) {
          _wifiSsid.text = identity.wifiSsid;
          _wifiPassword.clear();
        }
      });
    } catch (error) {
      if (mounted) setState(() => _errorMessage = context.tr('$error'));
    } finally {
      if (mounted) setState(() => _isReadingIdentity = false);
    }
  }

  Future<void> _scanWifi() async {
    final candidate = _selectedDevice;
    if (candidate == null || _identity == null) return;
    setState(() {
      _isScanningWifi = true;
      _errorMessage = null;
    });
    try {
      final networks = await widget.bleService.scanWifiNetworks(candidate);
      if (!mounted) return;
      if (networks.isEmpty) {
        setState(() {
          _errorMessage = context.tr(
            'No Wi-Fi network was detected. You can enter the SSID manually.',
          );
        });
        return;
      }
      final selected = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: Text(context.tr('Wi-Fi detected by ESP32')),
          children: networks
              .map(
                (network) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    network.ssid,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        network.isSecure
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(network.ssid)),
                      Text('${network.rssi} dBm'),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );
      if (selected != null && mounted) {
        setState(() => _wifiSsid.text = selected);
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = context.tr('$error'));
    } finally {
      if (mounted) setState(() => _isScanningWifi = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final candidate = _selectedDevice;
    final identity = _identity;
    if (candidate == null || identity == null) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final request = OccupancyProvisioningRequest(
      identity: identity,
      roomNumber: widget.room.number,
      wifiSsid: _wifiSsid.text.trim(),
      wifiPassword: _wifiPassword.text,
      keepWifiPassword: _shouldKeepPassword(identity),
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
              'Occupancy sensor configuration saved. ESP32 is connecting to MQTT.',
            ),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = context.tr('$error'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _shouldKeepPassword(BleDeviceIdentity identity) {
    return _wifiPassword.text.isEmpty &&
        identity.configured &&
        identity.hasWifiPassword &&
        _wifiSsid.text.trim() == identity.wifiSsid;
  }

  String? _required(String? value) {
    return value != null && value.trim().isNotEmpty
        ? null
        : context.tr('This field is required');
  }

  String? _validateWifiPassword(String? value) {
    if ((value ?? '').length >= 8) return null;
    final identity = _identity;
    if (identity != null && _shouldKeepPassword(identity)) return null;
    return context.tr('Enter at least 8 characters');
  }
}

class _OccStepHeader extends StatelessWidget {
  const _OccStepHeader({required this.number, required this.title});

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

class _OccInfoCard extends StatelessWidget {
  const _OccInfoCard({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
