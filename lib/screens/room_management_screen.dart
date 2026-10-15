import 'package:flutter/services.dart';

import '../localization/localized_material.dart';

import '../controllers/room_controller.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';

class RoomManagementScreen extends StatelessWidget {
  const RoomManagementScreen({
    required this.controller,
    super.key,
  });

  final RoomController controller;

  Future<void> _openEditor(
    BuildContext context, [
    Room? room,
  ]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _RoomEditorSheet(
        controller: controller,
        room: room,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${context.tr('Delete Room')} ${room.number}?'),
        content: Text(
          room.displayedAirCount > 0 || room.scheduleCount > 0
              ? 'This room still has ${room.displayedAirCount} air '
                    'conditioner(s) and ${room.scheduleCount} schedule(s). '
                    'Remove linked data before deleting the room.'
              : 'The room will be removed from the app and future timetable '
                    'imports.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            key: Key('confirm-delete-room-${room.number}'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: room.displayedAirCount > 0 || room.scheduleCount > 0
                ? null
                : () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await controller.deleteRoom(room.number);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('Room')} ${room.number} ${context.tr('deleted.')}')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(error.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('Manage Rooms'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            key: const Key('add-room-button'),
            tooltip: context.tr('Add Room'),
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isLoading && !controller.hasLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: controller.reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text(
                  context.tr('Add standard or special rooms such as CL503. Use floor 0 to place a room in the Special group.'),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.tr(controller.errorMessage!),
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                ...controller.rooms.map(
                  (room) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ManagedRoomCard(
                      room: room,
                      onEdit: () => _openEditor(context, room),
                      onDelete: () => _confirmDelete(context, room),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-room-fab'),
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_home_work_rounded),
        label: Text(context.tr('Add Room')),
      ),
    );
  }
}

class _ManagedRoomCard extends StatelessWidget {
  const _ManagedRoomCard({
    required this.room,
    required this.onEdit,
    required this.onDelete,
  });

  final Room room;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final groupLabel = room.floor == 0 ? 'Special' : '${context.tr('Floor')} ${room.floor}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 5, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.meeting_room_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('Room')} ${room.number}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$groupLabel · ${room.type}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${room.displayedAirCount} air conditioner(s) · '
                  '${room.scheduleCount} schedule(s)',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('edit-room-${room.number}'),
            tooltip: context.tr('Edit'),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            key: Key('delete-room-${room.number}'),
            tooltip: context.tr('Delete'),
            color: colors.error,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _RoomEditorSheet extends StatefulWidget {
  const _RoomEditorSheet({
    required this.controller,
    this.room,
  });

  final RoomController controller;
  final Room? room;

  @override
  State<_RoomEditorSheet> createState() => _RoomEditorSheetState();
}

class _RoomEditorSheetState extends State<_RoomEditorSheet> {
  late final TextEditingController _numberController;
  late final TextEditingController _floorController;
  late final TextEditingController _indexController;
  late final TextEditingController _typeController;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.room != null;

  @override
  void initState() {
    super.initState();
    final room = widget.room;
    _numberController = TextEditingController(text: room?.number ?? '');
    _floorController = TextEditingController(
      text: (room?.floor ?? 0).toString(),
    );
    _indexController = TextEditingController(
      text: (room?.roomIndex ?? 0).toString(),
    );
    _typeController = TextEditingController(
      text: room?.type ?? 'Classroom',
    );
  }

  @override
  void dispose() {
    _numberController.dispose();
    _floorController.dispose();
    _indexController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final number = _numberController.text.trim().toUpperCase();
    final floor = int.tryParse(_floorController.text.trim());
    final index = int.tryParse(_indexController.text.trim());
    final type = _typeController.text.trim();

    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{1,19}$').hasMatch(number)) {
      setState(
        () => _errorMessage =
            'Room code must be 2–20 characters using A–Z, 0–9, _ or -.',
      );
      return;
    }
    if (floor == null || floor < 0 || floor > 99) {
      setState(
        () => _errorMessage =
            'Floor must be 0–99. Use 0 for a special room.',
      );
      return;
    }
    if (index == null || index < 0 || index > 9999) {
      setState(() => _errorMessage = 'Room order must be 0–9999.');
      return;
    }
    if (type.isEmpty || type.length > 100) {
      setState(
        () => _errorMessage =
            'Room type or name must be 1–100 characters.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final room = Room(
      number: number,
      floor: floor,
      roomIndex: index,
      type: type,
      airConditioners: widget.room?.airConditioners ?? [],
      isOccupied: widget.room?.isOccupied ?? false,
      isOnline: widget.room?.isOnline ?? true,
      registeredAirCount: widget.room?.registeredAirCount ?? 0,
      scheduleCount: widget.room?.scheduleCount ?? 0,
    );
    try {
      if (_isEditing) {
        await widget.controller.updateRoom(room);
      } else {
        await widget.controller.createRoom(room);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = context.tr(error.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _isEditing ? 'Edit Room' : 'Add Room',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('room-number-field'),
              controller: _numberController,
              enabled: !_isEditing,
              autofocus: !_isEditing,
              maxLength: 10,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
              ],
              decoration: InputDecoration(
                labelText: context.tr('Room code'),
                hintText: context.tr('e.g. 16203 or CL503'),
                prefixIcon: const Icon(Icons.tag_rounded),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('room-floor-field'),
                    controller: _floorController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: context.tr('Floor'),
                      helperText: context.tr('0 = Special'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('room-index-field'),
                    controller: _indexController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: context.tr('Display order'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('room-type-field'),
              controller: _typeController,
              maxLength: 50,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: context.tr('Room type or name'),
                hintText: context.tr('e.g. Computer Laboratory'),
                prefixIcon: const Icon(Icons.domain_rounded),
              ),
              onSubmitted: (_) => _save(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('save-room-button'),
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isEditing ? 'Save Changes' : 'Add Room'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
