import '../models/admin_contact.dart';
import '../models/auth_user.dart';
import '../models/remembered_login.dart';

abstract interface class AuthRepository {
  Future<AuthUser?> restoreSession();

  Future<RememberedLogin?> loadRememberedLogin();

  Future<void> saveRememberedLogin({
    required String username,
    required String password,
  });

  Future<void> clearRememberedLogin();

  Future<AuthUser> login({
    required String username,
    required String password,
  });

  Future<void> logout();

  Future<String> requestPasswordReset(String identifier);

  Future<String> verifyPasswordResetOtp({
    required String requestId,
    required String otp,
  });

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  });

  /// แก้ข้อมูลบัญชีของตัวเอง คืนข้อมูลผู้ใช้ชุดใหม่
  Future<AuthUser> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  });

  /// เปลี่ยนรหัสผ่านโดยยืนยันด้วยรหัสเดิม
  /// สำเร็จแล้ว Token เดิมจะใช้ไม่ได้ ต้องเข้าสู่ระบบใหม่
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<AdminContact> getAdminContact();
}
