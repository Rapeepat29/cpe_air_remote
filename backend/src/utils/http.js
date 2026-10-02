export class ApiError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.name = 'ApiError';
    this.statusCode = statusCode;
  }
}

export function asyncHandler(handler) {
  return (request, response, next) => {
    Promise.resolve(handler(request, response, next)).catch(next);
  };
}

export function notFoundHandler(request, response) {
  response.status(404).json({ message: 'ไม่พบ API ที่เรียกใช้งาน' });
}

export function errorHandler(error, request, response, next) {
  if (response.headersSent) {
    next(error);
    return;
  }

  if (error instanceof ApiError) {
    response.status(error.statusCode).json({ message: error.message });
    return;
  }

  if (error?.type === 'entity.too.large') {
    response.status(413).json({
      message: 'ไฟล์หรือข้อมูลที่ส่งมามีขนาดใหญ่เกินไป',
    });
    return;
  }

  console.error(error);
  response.status(500).json({
    message: 'เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์',
  });
}
