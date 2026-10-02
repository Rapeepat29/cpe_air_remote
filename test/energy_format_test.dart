import 'package:cpe_air_remote/utils/number_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatEnergy เลือกหน่วยตามขนาดของค่า', () {
    test('ค่าน้อยระดับที่ชาร์จมือถือกลายเป็น Wh ไม่ใช่ 0.0 kWh', () {
      final result = formatEnergy(0.005);

      expect(result.unit, 'Wh');
      expect(result.value, '5.00');
      expect(result.text, '5.00 Wh');
    });

    test('ค่าระดับแอร์ยังเป็น kWh ตามเดิม', () {
      expect(formatEnergy(12.5).text, '12.5 kWh');
      expect(formatEnergy(1).text, '1.00 kWh');
      expect(formatEnergy(999).text, '999 kWh');
    });

    test('ค่าระดับทั้งอาคารเลื่อนขึ้นเป็น MWh', () {
      expect(formatEnergy(1000).text, '1.00 MWh');
      expect(formatEnergy(2400).text, '2.40 MWh');
    });

    test('ยังไม่มีข้อมูลเลยแสดง 0.0 kWh ตามที่หน้าจออื่นใช้กันอยู่', () {
      final result = formatEnergy(0);

      expect(result.unit, 'kWh');
      expect(result.text, '0.0 kWh');
    });

    test('ทศนิยมลดลงเมื่อตัวเลขใหญ่ขึ้น จะได้ไม่รกจอ', () {
      expect(formatEnergy(0.0004).text, '0.400 Wh');
      expect(formatEnergy(0.005).text, '5.00 Wh');
      expect(formatEnergy(0.0125).text, '12.5 Wh');
      expect(formatEnergy(0.42).text, '420 Wh');
    });

    test('คั่นหลักพันให้ด้วย', () {
      expect(formatEnergy(15230.7).text, '15.2 MWh');
      expect(formatEnergy(0.5, scaleReference: 0.5).value, '500');
    });
  });

  group('scaleReference ทำให้ทั้งชุดใช้หน่วยเดียวกัน', () {
    test('ทุกจุดบนกราฟอ้างค่าสูงสุดของชุด จึงเทียบกันได้ตรง ๆ', () {
      const series = [0.0, 0.0, 0.0, 0.005];
      final reference = energyScaleReference(series);

      final texts = series
          .map((value) => formatEnergy(value, scaleReference: reference).text)
          .toList();

      expect(texts, ['0.00 Wh', '0.00 Wh', '0.00 Wh', '5.00 Wh']);
    });

    test('ถ้าปล่อยให้แต่ละค่าเลือกหน่วยเอง ค่าน้อยจะดูใหญ่กว่าค่ามาก', () {
      // 900 Wh น้อยกว่า 1.2 kWh แต่ตัวเลข 900 ดูใหญ่กว่า 1.2
      // การบังคับหน่วยร่วมคือสิ่งที่กันความเข้าใจผิดนี้
      final reference = energyScaleReference([0.9, 1.2]);

      expect(formatEnergy(0.9, scaleReference: reference).text, '0.90 kWh');
      expect(formatEnergy(1.2, scaleReference: reference).text, '1.20 kWh');
      expect(formatEnergy(0.9).text, '900 Wh');
    });

    test('ชุดที่ทุกค่าเป็นศูนย์ไม่ทำให้พัง', () {
      final reference = energyScaleReference([0.0, 0.0]);

      expect(reference, 0);
      expect(formatEnergy(0, scaleReference: reference).text, '0.0 kWh');
    });

    test('ชุดว่างคืนศูนย์', () {
      expect(energyScaleReference(const <double>[]), 0);
    });
  });
}
