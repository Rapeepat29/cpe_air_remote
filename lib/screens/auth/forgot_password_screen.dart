import '../../localization/localized_material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_background.dart';
import '../../widgets/auth/auth_text_field.dart';

enum _ResetStage {
  requestOtp,
  verifyOtp,
  newPassword,
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    required this.repository,
    super.key,
  });

  final AuthRepository repository;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ResetStage _stage = _ResetStage.requestOtp;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _requestId;
  String? _resetToken;

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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
        case _ResetStage.newPassword:
          await widget.repository.resetPassword(
            resetToken: _resetToken!,
            newPassword: _newPasswordController.text,
          );
          await widget.repository.clearRememberedLogin();
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              icon: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 52,
              ),
              title: Text(context.tr('Password changed')),
              content: Text(
                context.tr('You can now sign in with your new password.'),
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.tr('Back to Sign In')),
                ),
              ],
            ),
          );
          if (mounted) {
            Navigator.of(context).pop(true);
          }
          return;
      }
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

  Future<void> _resendOtp() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      _requestId = await widget.repository.requestPasswordReset(
        _identifierController.text,
      );
      _otpController.clear();
      _showMessage('A new OTP has been sent. Please check your email.');
    } on ApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  String get _title {
    return switch (_stage) {
      _ResetStage.requestOtp => 'Forgot Password',
      _ResetStage.verifyOtp => 'Verify OTP',
      _ResetStage.newPassword => 'Create New Password',
    };
  }

  String get _subtitle {
    return switch (_stage) {
      _ResetStage.requestOtp =>
        'Enter the username or email registered in the system',
      _ResetStage.verifyOtp =>
        'Enter the 6-digit code sent to the email on file',
      _ResetStage.newPassword =>
        'Your new password must contain at least 8 characters',
    };
  }

  String get _buttonLabel {
    return switch (_stage) {
      _ResetStage.requestOtp => 'Send OTP',
      _ResetStage.verifyOtp => 'Verify OTP',
      _ResetStage.newPassword => 'Save New Password',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AuthBackground(
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            const EnergyBrand(compact: true),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ResetProgress(stage: _stage),
                  const SizedBox(height: 22),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (_stage) {
                      _ResetStage.requestOtp => _buildIdentifierField(),
                      _ResetStage.verifyOtp => _buildOtpField(),
                      _ResetStage.newPassword => _buildPasswordFields(),
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.primary,
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
                        : Text(
                            _buttonLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  if (_stage == _ResetStage.verifyOtp) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLoading ? null : _resendOtp,
                      child: Text(context.tr('Did not receive it? Resend OTP')),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentifierField() {
    return AuthTextField(
      key: const ValueKey('identifier'),
      controller: _identifierController,
      label: context.tr('Username or Email'),
      icon: Icons.alternate_email_rounded,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Enter your username or email';
        }
        return null;
      },
    );
  }

  Widget _buildOtpField() {
    return AuthTextField(
      key: const ValueKey('otp'),
      controller: _otpController,
      label: context.tr('6-digit OTP'),
      icon: Icons.password_rounded,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onFieldSubmitted: (_) => _submit(),
      validator: (value) {
        if (value == null || !RegExp(r'^\d{6}$').hasMatch(value)) {
          return 'Enter the complete 6-digit OTP';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordFields() {
    return Column(
      key: const ValueKey('new-password'),
      children: [
        AuthTextField(
          controller: _newPasswordController,
          label: context.tr('New Password'),
          icon: Icons.lock_reset_rounded,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          suffixIcon: IconButton(
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
          ),
          validator: (value) {
            if (value == null || value.length < 8) {
              return 'Password must contain at least 8 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        AuthTextField(
          controller: _confirmPasswordController,
          label: context.tr('Confirm New Password'),
          icon: Icons.verified_user_rounded,
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onFieldSubmitted: (_) => _submit(),
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
          ),
          validator: (value) {
            if (value != _newPasswordController.text) {
              return 'The passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _ResetProgress extends StatelessWidget {
  const _ResetProgress({required this.stage});

  final _ResetStage stage;

  @override
  Widget build(BuildContext context) {
    final current = stage.index;
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: List.generate(3, (index) {
        final active = index <= current;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 5,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : colors.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (index != 2) const SizedBox(width: 6),
            ],
          ),
        );
      }),
    );
  }
}
