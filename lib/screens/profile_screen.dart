import '../localization/localized_material.dart';

import '../controllers/app_settings_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/system_settings_controller.dart';
import '../controllers/energy_controller.dart';
import '../controllers/user_controller.dart';
import '../models/auth_user.dart';
import '../theme/app_theme.dart';
import '../widgets/section_title.dart';
import '../widgets/status_pill.dart';
import 'account_settings_screen.dart';
import 'application_settings_screen.dart';
import 'electricity_rate_screen.dart';
import 'energy_database_screen.dart';
import 'user_management_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.user,
    required this.appSettingsController,
    required this.userController,
    required this.energyController,
    required this.authController,
    required this.systemSettingsController,
    required this.onLogout,
    super.key,
  });

  final AuthUser user;
  final AppSettingsController appSettingsController;
  final UserController userController;
  final EnergyController energyController;
  final AuthController authController;
  final SystemSettingsController systemSettingsController;
  final Future<void> Function() onLogout;

  bool get _isAdmin => user.role.toLowerCase() == 'admin';

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Log out?')),
        content: Text(context.tr('You will need to sign in again next time.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: Text(context.tr('Log out')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                Text(
                  context.tr('User Profile'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 22),
                const CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 37,
                    backgroundColor: Color(0xFFE7EDF2),
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  user.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '@${user.username} · ${user.email}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                StatusPill(
                  label: '★ ${user.roleLabel}',
                  color: Colors.white,
                  backgroundColor: AppColors.orange,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                SectionTitle(
                  title: context.tr('System Management'),
                ),
                const SizedBox(height: 11),
                if (_isAdmin) ...[
                  _ProfileTile(
                    key: const Key('manage-users-tile'),
                    icon: Icons.manage_accounts_rounded,
                    iconColor: AppColors.blue,
                    title: context.tr('Manage User Permissions'),
                    subtitle: context.tr('Assign Admin and Staff access'),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => UserManagementScreen(
                          controller: userController,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _ProfileTile(
                  key: const Key('energy-database-tile'),
                  icon: Icons.cloud_sync_rounded,
                  iconColor: AppColors.green,
                  title: context.tr('Database'),
                  subtitle: context.tr(
                    'Live readings and hourly Excel export',
                  ),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => EnergyDatabaseScreen(
                        controller: energyController,
                        appSettingsController: appSettingsController,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle(
                  title: context.tr('Account & Settings'),
                ),
                const SizedBox(height: 11),
                _ProfileTile(
                  key: const Key('account-settings-tile'),
                  icon: Icons.manage_accounts_outlined,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: context.tr('Account Settings'),
                  subtitle: context.tr(
                    'Name, email, phone number and password',
                  ),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => AccountSettingsScreen(
                        controller: authController,
                        user: user,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.calculate_rounded,
                  iconColor: AppColors.orange,
                  title: context.tr('Electricity Rate'),
                  subtitle: context.tr('Set the rate per kWh for cost estimates'),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ElectricityRateScreen(
                        controller: appSettingsController,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.settings_rounded,
                  iconColor: const Color(0xFF777777),
                  title: context.tr('Application Settings'),
                  subtitle: context.tr('Language and appearance'),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ApplicationSettingsScreen(
                        controller: appSettingsController,
                        systemSettingsController: systemSettingsController,
                        isAdmin: user.role.toLowerCase() == 'admin',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.logout_rounded,
                  iconColor: AppColors.red,
                  title: context.tr('Log Out'),
                  subtitle: context.tr('Remove the saved session from this device'),
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
