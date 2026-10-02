// หน้าสถานะแบบเบา แยกจาก status.html เพราะ CSP ไม่อนุญาตสคริปต์ในหน้า
const set = (id, state, text) => {
  const el = document.getElementById(id);
  el.className = 'pill ' + state;
  el.innerHTML = '<i class="dot"></i>' + text;
};

async function check() {
  try {
    const res = await fetch('/api/health', { cache: 'no-store' });
    const data = await res.json();
    set('api', data.status === 'ok' ? 'ok' : 'bad',
        data.status === 'ok' ? 'พร้อมใช้งาน' : 'มีปัญหา');
    const up = data.mqtt && data.mqtt.connected;
    set('mqtt', up ? 'ok' : 'bad', up ? 'เชื่อมต่อแล้ว' : 'ไม่เชื่อมต่อ');
    document.getElementById('topic').textContent =
      (data.mqtt && data.mqtt.topicPrefix) ? data.mqtt.topicPrefix + '/#' : '—';
  } catch (error) {
    set('api', 'bad', 'ติดต่อไม่ได้');
    set('mqtt', 'bad', 'ไม่ทราบสถานะ');
  }
  document.getElementById('time').textContent =
    new Date().toLocaleTimeString('th-TH');
}

check();
setInterval(check, 15000);
