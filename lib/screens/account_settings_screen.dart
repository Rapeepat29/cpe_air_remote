import '../localization/localized_material.dart';

import '../controllers/auth_controller.dart';
import '../models/auth_user.dart';
import '../theme/app_theme.dart';
import '../widgets/section_title.dart';

/// หน้า `ตั้งค่าบัญชีผู้ใช้`
///
/// เจ้าของบัญชีแก้ชื่อ อีเมล เบอร์โทร และเปลี่ยนรหัสผ่านเองได้
/// ส่วนสิทธิ์ (admin/staff) กับสถานะบัญชี ยังต้องให้ผู้ดูแลระบบเป็นคนแก้เท่านั้น
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    required this.controller,
    required this.user,
    super.key,
  });

  final AuthController controller;
  final AuthUser user;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  final _currentPassword = TextEditingController();
  final _emailChangePassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void initState() {
    super.initState();
    final user = widget.controller.user ?? widget.user;
    _firstName = TextEditingController(text: user.firstName);
    _lastName = TextEditingController(text: user.lastName);
    _email = TextEditingController(text: user.email);
    _phone = TextEditingController(text: user.phone);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _currentPassword.dispose();
    _emailChangePassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.red : AppColors.green,
        ),
      );
  }

  /// ถามรหัสผ่านปัจจุบันก่อนเปลี่ยนอีเมล คืน null ถ้าผู้ใช้กดยกเลิก
  ///
  /// OTP ลืมรหัสผ่านถูกส่งไปที่อีเมลนี้ ถ้าเปลี่ยนได้โดยไม่ยืนยัน คนที่หยิบ
  /// เครื่องที่ล็อกอินค้างไว้ไปได้จะเปลี่ยนเป็นอีเมลตัวเองแล้วยึดบัญชีได้
  Future<String?> _askPasswordForEmailChange() async {
    _emailChangePassword.clear();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Confirm your password')),
        content: TextField(
          key: const Key('account-email-change-password'),
          controller: _emailChangePassword,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.tr('Current password'),
            helperText: context.tr(
              'Changing the email requires your current password.',
            ),
            helperMaxLines: 3,
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_emailChangePassword.text),
            child: Text(context.tr('Confirm')),
          ),
        ],
      ),
    );
    if (password == null || password.isEmpty) return null;
    return password;
  }

  Future<void> _saveProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;
    final user = widget.controller.user ?? widget.user;
    final email = _email.text.trim();
    String? currentPassword;
    if (email.toLowerCase() != user.email.trim().toLowerCase()) {
      currentPassword = await _askPasswordForEmailChange();
      if (currentPassword == null || !mounted) return;
    }
    setState(() => _savingProfile = true);
    try {
      await widget.controller.updateProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: email,
        phone: _phone.text.trim(),
        currentPassword: currentPassword,
      );
      // ผู้ใช้อาจกดออกจากหน้าไปแล้วระหว่างรอบันทึก ห้ามแตะ context ต่อ
      if (!mounted) return;
      _notify(context.tr('Your account details were saved.'));
    } catch (error) {
      _notify(
        error.toString().replaceFirst('ApiException: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Change the password?')),
        content: Text(
          context.tr(
            'Every device signed in with this account will be signed out, '
            'including this one.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Change password')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _savingPassword = true);
    try {
      await widget.controller.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      // เปลี่ยนสำเร็จแล้วจะถูกพากลับไปหน้าเข้าสู่ระบบเองโดยตัวควบคุม
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      _notify(
        error.toString().replaceFirst('ApiException: ', ''),
        isError: true,
      );
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = widget.controller.user ?? widget.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Account Settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          _IdentityCard(user: user),
          const SizedBox(height: 20),
          SectionTitle(title: context.tr('Personal details')),
          const SizedBox(height: 10),
          Form(
            key: _profileFormKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        key: const Key('account-first-name'),
                        controller: _firstName,
                        label: context.tr('First name'),
                        icon: Icons.badge_outlined,
                        validator: (value) =>
                            (value ?? '').trim().isEmpty
                            ? context.tr('Please enter the first name.')
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Field(
                        key: const Key('account-last-name'),
                        controller: _lastName,
                        label: context.tr('Last name'),
                        icon: Icons.badge_outlined,
                        validator: (value) =>
                            (value ?? '').trim().isEmpty
                            ? context.tr('Please enter the last name.')
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(
                  key: const Key('account-email'),
                  controller: _email,
                  label: context.tr('Email'),
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    final pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
                    return pattern.hasMatch(text)
                        ? null
                        : context.tr('Please enter a valid email address.');
                  },
                ),
                const SizedBox(height: 12),
                _Field(
                  key: const Key('account-phone'),
                  controller: _phone,
                  label: context.tr('Phone number'),
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    return RegExp(r'^[0-9+()\- ]{6,30}$').hasMatch(text)
                        ? null
                        : context.tr('The phone number format is invalid.');
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Admins reach you at this number and email, and password '
                    'resets are sent to this email.',
                  ),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('account-save-profile'),
                    onPressed: _savingProfile ? null : _saveProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    icon: _savingProfile
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(context.tr('Save changes')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SectionTitle(title: context.tr('Change password')),
          const SizedBox(height: 10),
          Form(
            key: _passwordFormKey,
            child: Column(
              children: [
                _Field(
                  key: const Key('account-current-password'),
                  controller: _currentPassword,
                  label: context.tr('Current password'),
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureCurrent,
                  onToggleObscure: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                  validator: (value) => (value ?? '').isEmpty
                      ? context.tr('Please enter the current password.')
                      : null,
                ),
                const SizedBox(height: 12),
                _Field(
                  key: const Key('account-new-password'),
                  controller: _newPassword,
                  label: context.tr('New password'),
                  icon: Icons.lock_reset_rounded,
                  obscure: _obscureNew,
                  onToggleObscure: () =>
                      setState(() => _obscureNew = !_obscureNew),
                  validator: (value) {
                    final text = value ?? '';
                    if (text.length < 8) {
                      return context.tr(
                        'Password must contain at least 8 characters.',
                      );
                    }
                    if (text == _currentPassword.text) {
                      return context.tr(
                        'The new password must differ from the current one.',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _Field(
                  key: const Key('account-confirm-password'),
                  controller: _confirmPassword,
                  label: context.tr('Confirm the new password'),
                  icon: Icons.lock_reset_rounded,
                  obscure: _obscureNew,
                  validator: (value) => (value ?? '') == _newPassword.text
                      ? null
                      : context.tr('The passwords do not match.'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('account-change-password'),
                    onPressed: _savingPassword ? null : _changePassword,
                    icon: _savingPassword
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.key_rounded, size: 18),
                    label: Text(context.tr('Change password')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.primaryContainer,
            child: Icon(
              Icons.person_rounded,
              color: colors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr(
                    'Username and permission are set by an administrator.',
                  ),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              context.tr(user.roleLabel),
              style: const TextStyle(
                color: AppColors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.onToggleObscure,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final VoidCallback? onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        prefixIcon: Icon(icon, size: 19),
        border: const OutlineInputBorder(),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 19,
                ),
              ),
      ),
    );
  }
}
