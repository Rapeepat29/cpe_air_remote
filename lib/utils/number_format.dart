String formatDecimal(double value, {int decimalPlaces = 2}) {
  final parts = value.toStringAsFixed(decimalPlaces).split('.');
  final digits = parts.first;
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    final digitsRemaining = digits.length - index;
    buffer.write(digits[index]);
    if (digitsRemaining > 1 && digitsRemaining % 3 == 1) {
      buffer.write(',');
    }
  }

  if (decimalPlaces == 0) {
    return buffer.toString();
  }
  return '$buffer.${parts.last}';
}

/// ค่าพลังงานที่จัดหน่วยแล้ว พร้อมนำไปแสดงผล
class EnergyDisplay {
  const EnergyDisplay({
    required this.value,
    required this.unit,
    required this.decimalPlaces,
  });

  /// ตัวเลขที่คั่นหลักพันแล้ว เช่น `5.00` หรือ `1,240.5`
  final String value;

  /// หน่วยที่เลือกให้ เช่น `Wh`, `kWh`, `MWh`
  final String unit;

  /// จำนวนทศนิยมที่ใช้จริง เผื่อผู้เรียกอยากจัดคอลัมน์ให้ตรงกัน
  final int decimalPlaces;

  /// ข้อความเต็มพร้อมหน่วย เช่น `5.00 Wh`
  String get text => '$value $unit';

  @override
  String toString() => text;
}

int _energyDecimalPlaces(double scaledValue) {
  final size = scaledValue.abs();
  if (size >= 100) return 0;
  if (size >= 10) return 1;
  if (size >= 1) return 2;
  return 3;
}

/// จัดหน่วยพลังงานให้อ่านง่ายโดยอัตโนมัติ
///
/// ค่าที่วัดได้จริงในโปรเจกต์นี้กว้างมาก ตั้งแต่ที่ชาร์จมือถือระดับ 0.005 kWh
/// ไปจนถึงแอร์ทั้งอาคารระดับหลักพัน kWh ถ้าตรึงหน่วยไว้ที่ kWh อย่างเดียว
/// ค่าฝั่งน้อยจะถูกปัดเหลือ `0.0` จนอ่านอะไรไม่ได้เลย ฟังก์ชันนี้จึงเลื่อน
/// หน่วยตามขนาดของค่า
///
/// ```text
/// 0.005 kWh -> 5.00 Wh
/// 0.42  kWh -> 420.00 Wh   (เพราะ 420 >= 100 จึงเหลือ 420 Wh)
/// 12.5  kWh -> 12.5 kWh
/// 2400  kWh -> 2.40 MWh
/// ```
///
/// [scaleReference] ใช้ตอนที่หลายค่าต้องอยู่หน่วยเดียวกัน เช่นทุกจุดบนกราฟ
/// เส้นเดียวกัน ให้ส่งค่าที่มากที่สุดของชุดเข้ามา ทุกจุดจะได้หน่วยและจำนวน
/// ทศนิยมชุดเดียวกัน เปรียบเทียบกันได้ตรง ๆ ถ้าไม่ส่งมา จะคิดจากค่าตัวเอง
EnergyDisplay formatEnergy(double kwh, {double? scaleReference}) {
  final reference = (scaleReference ?? kwh).abs();

  // ยังไม่มีข้อมูลเลย แสดง kWh ทศนิยมเดียวตามที่หน้าจออื่นใช้กันอยู่
  if (reference == 0) {
    return EnergyDisplay(
      value: formatDecimal(kwh, decimalPlaces: 1),
      unit: 'kWh',
      decimalPlaces: 1,
    );
  }

  final String unit;
  final double scaled;
  final double scaledReference;

  if (reference >= 1000) {
    unit = 'MWh';
    scaled = kwh / 1000;
    scaledReference = reference / 1000;
  } else if (reference >= 1) {
    unit = 'kWh';
    scaled = kwh;
    scaledReference = reference;
  } else {
    unit = 'Wh';
    scaled = kwh * 1000;
    scaledReference = reference * 1000;
  }

  final decimalPlaces = _energyDecimalPlaces(scaledReference);
  return EnergyDisplay(
    value: formatDecimal(scaled, decimalPlaces: decimalPlaces),
    unit: unit,
    decimalPlaces: decimalPlaces,
  );
}

/// หน่วยและจำนวนทศนิยมร่วมของทั้งชุด คิดจากค่าที่มากที่สุด
///
/// ใช้กับกราฟและตาราง ที่ทุกแถวต้องอ่านเทียบกันได้
double energyScaleReference(Iterable<double> values) {
  var largest = 0.0;
  for (final value in values) {
    final size = value.abs();
    if (size > largest) largest = size;
  }
  return largest;
}
