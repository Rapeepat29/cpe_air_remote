import '../../localization/localized_material.dart';
import 'package:flutter/services.dart';

import '../../controllers/auth_controller.dart';
import '../../models/admin_contact.dart';
import '../../services/auth_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_background.dart';
import '../../widgets/auth/auth_text_field.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.controller,
    super.key,
  });

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

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

  Future<void> _openForgotPassword() async {
    final passwordWasReset = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          repository: widget.controller.repository,
        ),
      ),
    );

    if (passwordWasReset == true && mounted) {
      _passwordController.clear();
      setState(() => _rememberPassword = false);
    }
  }

  void _openAdminContact() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminContactSheet(
        repository: widget.controller.repository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AuthBackground(
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EnergyBrand(),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E5C38).withValues(alpha: 0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                // CheckboxListTile ข้างล่างวาดพื้นหลังกับเอฟเฟกต์กดลงบน
                // Material ที่ใกล้ที่สุด ถ้าการ์ดใบนี้ไม่มี Material อยู่ข้างใน
                // ตัวการ์ดที่มีสีพื้นจะไปบังเอฟเฟกต์นั้น แล้ว Flutter รุ่นใหม่
                // จะโยน assertion ทิ้งตั้งแต่ตอน build
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.tr('Sign In'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.tr('Enter your username and password'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 23),
                      AuthTextField(
                        controller: _usernameController,
                        label: context.tr('Username'),
                        icon: Icons.person_rounded,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
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
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _rememberPassword,
                        onChanged: _isLoading || _isLoadingRememberedLogin
                            ? null
                            : _setRememberPassword,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.primary,
                        title: Text(
                          context.tr('Remember username'),
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          context.tr('Recommended for personal devices only'),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // ข้อความไทยสองปุ่มนี้รวมกันกว้างเกินการ์ด (ล้น 88px)
                      // Flexible ให้ปุ่มหดได้ และตัดท้ายด้วย ... แทนที่จะล้นขอบ
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: TextButton(
                              onPressed: _isLoading ? null : _openForgotPassword,
                              child: Text(
                                context.tr('Forgot password?'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Flexible(
                            child: TextButton.icon(
                              onPressed: _isLoading ? null : _openAdminContact,
                              icon: const Icon(
                                Icons.support_agent_rounded,
                                size: 19,
                              ),
                              label: Text(
                                context.tr('Contact Admin'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      FilledButton(
                        onPressed: _isLoading ? null : _login,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
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
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    context.tr('Sign In'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.login_rounded, size: 21),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                context.tr('Building 16 · Computer Engineering'),
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminContactSheet extends StatefulWidget {
  const _AdminContactSheet({required this.repository});

  final AuthRepository repository;

  @override
  State<_AdminContactSheet> createState() => _AdminContactSheetState();
}

class _AdminContactSheetState extends State<_AdminContactSheet> {
  late Future<AdminContact> _contactFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _contactFuture = widget.repository.getAdminContact();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 22),
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.green.withValues(alpha: 0.16),
            child: const Icon(
              Icons.support_agent_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            context.tr('Contact Admin'),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<AdminContact>(
            future: _contactFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (snapshot.hasError || snapshot.data == null) {
                return Column(
                  children: [
                    Text(
                      context.tr('Could not load the administrator contact details.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.red),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => setState(_load),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.tr('Try Again')),
                    ),
                  ],
                );
              }

              final contact = snapshot.data!;
              return Column(
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    contact.phone,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: contact.phone.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: contact.phone),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.tr('Phone number copied')),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(context.tr('Copy Phone Number')),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
