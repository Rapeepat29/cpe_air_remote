import 'package:flutter/services.dart';

import '../localization/localized_material.dart';

import '../controllers/user_controller.dart';
import '../models/managed_user.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/status_pill.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({
    required this.controller,
    super.key,
  });

  final UserController controller;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String? _busyUsername;

  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr(message))));
  }

  Future<void> _runGuarded(
    ManagedUser user,
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _busyUsername = user.username);
    try {
      await action();
      _showMessage(successMessage);
    } catch (error) {
      _showMessage(error.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _busyUsername = null);
    }
  }

  Future<void> _changeRole(ManagedUser user, String role) async {
    final roleName = role == 'admin' ? 'Administrator' : 'Staff';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Change permission?')),
        content: Text(
          '${user.displayName} '
          '${dialogContext.tr('will be changed to')} '
          '${dialogContext.tr(roleName)}. '
          '${dialogContext.tr('They will be signed out and must sign in '
              'again.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            key: Key('confirm-role-${user.username}'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('Confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runGuarded(
      user,
      () => widget.controller.changeRole(user, role),
      'Permission updated.',
    );
  }

  Future<void> _toggleActive(ManagedUser user, bool isActive) async {
    await _runGuarded(
      user,
      () => widget.controller.setActive(user, isActive),
      isActive ? 'Account enabled.' : 'Account suspended.',
    );
  }

  Future<void> _confirmDelete(ManagedUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Delete User')),
        content: Text(
          '${dialogContext.tr('This permanently removes the account')} '
          '"${user.username}". '
          '${dialogContext.tr('Suspending the account keeps its history '
              'instead.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            key: Key('confirm-delete-user-${user.username}'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runGuarded(
      user,
      () => widget.controller.deleteUser(user),
      'User deleted.',
    );
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => _CreateUserSheet(
        controller: widget.controller,
      ),
    );
    if (created == true) {
      _showMessage('User created.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = widget.controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('Manage User Permissions'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            key: const Key('reload-users-button'),
            tooltip: context.tr('Refresh'),
            onPressed: controller.reload,
            icon: const Icon(Icons.refresh_rounded),
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
                  context.tr('Administrators manage rooms, schedules, devices and user permissions. Staff can view rooms and control air conditioners only.'),
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
                if (controller.hasLoaded && controller.users.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        context.tr('No user accounts found.'),
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ),
                ...controller.users.map(
                  (user) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _UserCard(
                      user: user,
                      isSelf: controller.isSelf(user),
                      isBusy: _busyUsername == user.username,
                      onRoleChanged: (role) => _changeRole(user, role),
                      onActiveChanged: (value) => _toggleActive(user, value),
                      onDelete: () => _confirmDelete(user),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-user-fab'),
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(context.tr('Add User')),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.isBusy,
    required this.onRoleChanged,
    required this.onActiveChanged,
    required this.onDelete,
  });

  final ManagedUser user;
  final bool isSelf;
  final bool isBusy;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = user.isAdmin ? AppColors.primary : AppColors.blue;
    final canEdit = !isSelf && !isBusy;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: user.isActive ? colors.outlineVariant : AppColors.red,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  user.initials,
                  style: TextStyle(
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          StatusPill(
                            label: context.tr('You'),
                            color: AppColors.orange,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username} · ${user.email}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _lastLoginLabel(context),
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  key: Key('delete-user-${user.username}'),
                  tooltip: context.tr('Delete User'),
                  color: colors.error,
                  onPressed: canEdit ? onDelete : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  key: Key('role-selector-${user.username}'),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  segments: [
                    ButtonSegment(
                      value: 'admin',
                      label: Text(context.tr('Administrator')),
                      icon: const Icon(Icons.shield_rounded, size: 15),
                    ),
                    ButtonSegment(
                      value: 'staff',
                      label: Text(context.tr('Staff')),
                      icon: const Icon(Icons.person_rounded, size: 15),
                    ),
                  ],
                  selected: {user.role},
                  onSelectionChanged: canEdit
                      ? (values) => onRoleChanged(values.first)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    key: Key('active-switch-${user.username}'),
                    value: user.isActive,
                    onChanged: canEdit ? onActiveChanged : null,
                  ),
                  Text(
                    user.isActive ? 'Active' : 'Suspended',
                    style: TextStyle(
                      color: user.isActive
                          ? AppColors.green
                          : AppColors.red,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _lastLoginLabel(BuildContext context) {
    final lastLogin = user.lastLoginAt;
    if (lastLogin == null) {
      return context.tr('Never signed in');
    }
    return '${context.tr('Last sign-in')} '
        '${formatDisplayDateTime(lastLogin, AppLocalizations.of(context).isThai)}';
  }
}

class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet({required this.controller});

  final UserController controller;

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String _role = 'staff';
  bool _isSaving = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();

    if (username.length < 3) {
      setState(
        () => _errorMessage = 'Username must contain at least 3 characters.',
      );
      return;
    }
    if (password.length < 8) {
      setState(
        () => _errorMessage = 'Password must contain at least 8 characters.',
      );
      return;
    }
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(
        () => _errorMessage = 'Please enter the first and last name.',
      );
      return;
    }
    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.controller.createUser(
        username: username,
        password: password,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: _phoneController.text.trim(),
        role: _role,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.toString().replaceFirst('ApiException: ', '');
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
              context.tr('Add User'),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('The account can sign in immediately with this password.'),
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('new-username-field'),
              controller: _usernameController,
              autofocus: true,
              maxLength: 100,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._-]')),
              ],
              decoration: InputDecoration(
                labelText: context.tr('Username'),
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            TextField(
              key: const Key('new-password-field'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              maxLength: 72,
              decoration: InputDecoration(
                labelText: context.tr('Password'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('new-first-name-field'),
                    controller: _firstNameController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: context.tr('First name'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('new-last-name-field'),
                    controller: _lastNameController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: context.tr('Last name'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('new-email-field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              maxLength: 190,
              decoration: InputDecoration(
                labelText: context.tr('Email'),
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
            ),
            TextField(
              key: const Key('new-phone-field'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 30,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\- ]')),
              ],
              decoration: InputDecoration(
                labelText: context.tr('Phone'),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('Role'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              key: const Key('new-role-selector'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: 'staff',
                  label: Text(context.tr('Staff')),
                  icon: const Icon(Icons.person_rounded, size: 16),
                ),
                ButtonSegment(
                  value: 'admin',
                  label: Text(context.tr('Administrator')),
                  icon: const Icon(Icons.shield_rounded, size: 16),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (values) =>
                  setState(() => _role = values.first),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.tr(_errorMessage!),
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('save-user-button'),
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
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(context.tr('Create Account')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
