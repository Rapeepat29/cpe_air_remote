import { ApiError } from '../utils/http.js';

export function requireAdmin(request, response, next) {
  if (request.authUser?.role !== 'admin') {
    throw new ApiError(
      403,
      'เฉพาะผู้ดูแลระบบเท่านั้นที่ทำรายการนี้ได้',
    );
  }

  next();
}
