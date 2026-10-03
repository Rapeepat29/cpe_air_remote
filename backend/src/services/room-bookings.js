import { pool } from '../db.js';
import { publicBooking } from '../utils/room-booking.js';

// อ่านการจองห้องสำหรับระบบปิดแอร์อัตโนมัติและ MQTT
// แยกจาก routes/bookings.js เพื่อไม่ให้ service ต้อง import ตัว route

const SELECT_COLUMNS = `
  id, room_number, title, category, note, repeat_type, days_of_week,
  DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
  DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date,
  start_time, end_time, created_by, updated_by`;

/**
 * การจองของห้องหนึ่งที่ครอบคลุมวันนี้ (ใช้ในระบบปิดแอร์และ MQTT)
 * คืน [] ถ้ายังไม่มีตาราง room_bookings เพื่อให้ระบบเดิมทำงานต่อได้
 */
export async function readTodayBookings(roomNumber, today) {
  try {
    const rows = await pool.query(
      `SELECT ${SELECT_COLUMNS}
         FROM room_bookings
        WHERE room_number = ?
          AND start_date <= ?
          AND end_date >= ?`,
      [roomNumber, today, today],
    );
    return rows.map(publicBooking);
  } catch (error) {
    if (error?.code === 'ER_NO_SUCH_TABLE') return [];
    throw error;
  }
}
