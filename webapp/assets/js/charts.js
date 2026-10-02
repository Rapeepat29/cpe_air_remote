/**
 * กราฟที่วาดเป็น SVG เอง
 *
 * ไม่ใช้ไลบรารีกราฟเพราะสองเหตุผล: กราฟที่ต้องใช้มีแค่สองแบบ (เส้นพื้นที่กับ
 * แท่ง) และไลบรารีกราฟส่วนใหญ่ต้องดึงจาก CDN ซึ่งเว็บในเครือข่ายมหาวิทยาลัย
 * อาจเข้าไม่ถึง กราฟที่วาดเองเป็น SVG ล้วนจึงทำงานได้แม้ตัดเน็ตนอก
 *
 * ทุกกราฟแสดง "ค่าเป็นตัวเลข" กำกับด้วย ตามที่ขอไว้ในแอปมือถือ เพราะการดู
 * รูปทรงอย่างเดียวบอกไม่ได้ว่าจุดสูงสุดคือกี่หน่วย
 */

import { el } from './dom.js';
import { decimal, energy, energyUnit, scaleReference } from './format.js';

const NS = 'http://www.w3.org/2000/svg';

function node(tag, attrs = {}) {
  const element = document.createElementNS(NS, tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value == null) continue;
    element.setAttribute(key, String(value));
  }
  return element;
}

/**
 * กราฟเส้นพื้นที่พร้อมป้ายค่า
 *
 * @param {{label:string, value:number}[]} points
 * @param {{height:number, labelEvery:number, color:string}} options
 */
export function areaChart(points, options = {}) {
  const {
    height = 200,
    color = '#3ECF8E',
    showLabels = true,
    unitOverride = null,
  } = options;

  const wrapper = el('div', { class: 'spark-wrap' });
  if (!points || points.length === 0) {
    wrapper.appendChild(el('div', { class: 'empty', text: 'ยังไม่มีข้อมูล' }));
    return wrapper;
  }

  const width = 1000;
  const padTop = showLabels ? 26 : 8;
  const padBottom = 4;
  const values = points.map((point) => Number(point.value) || 0);
  const reference = scaleReference(values);
  // ถ้าผู้เรียกบอกหน่วยมาเอง (เช่น W หรือ บาท) ห้ามใช้กติกาแปลงหน่วยของ kWh
  // ไม่งั้น 1,200 W จะถูกเขียนเป็น 1.20 MWh ซึ่งผิดความหมายไปคนละเรื่อง
  const fixedUnit = unitOverride != null;
  const unit = fixedUnit ? unitOverride : energyUnit(reference);
  const labelOf = (value) =>
    fixedUnit
      ? decimal(value, value >= 100 ? 1 : 2)
      : energy(value, { scaleReference: reference, withUnit: false });
  // เพดานแกนตั้งเผื่อไว้ 15% เพื่อให้ป้ายค่าของจุดสูงสุดไม่ชนขอบบน
  const max = Math.max(...values) * 1.15 || 1;
  const innerHeight = height - padTop - padBottom;
  const step = points.length > 1 ? width / (points.length - 1) : 0;

  const x = (index) => (points.length > 1 ? index * step : width / 2);
  const y = (value) => padTop + innerHeight - (value / max) * innerHeight;

  const svg = node('svg', {
    viewBox: `0 0 ${width} ${height}`,
    width: '100%',
    height,
    preserveAspectRatio: 'none',
    class: 'spark-hit',
  });

  const gradientId = `areaFill-${Math.random().toString(36).slice(2, 8)}`;
  const defs = node('defs');
  const gradient = node('linearGradient', {
    id: gradientId,
    x1: 0,
    y1: 0,
    x2: 0,
    y2: 1,
  });
  gradient.appendChild(
    node('stop', { offset: '0%', 'stop-color': color, 'stop-opacity': 0.35 }),
  );
  gradient.appendChild(
    node('stop', { offset: '100%', 'stop-color': color, 'stop-opacity': 0 }),
  );
  defs.appendChild(gradient);
  svg.appendChild(defs);

  const line = points.map((point, index) => `${x(index)},${y(values[index])}`);
  svg.appendChild(
    node('path', {
      d: `M${line.join(' L')} L${x(points.length - 1)},${height} L${x(0)},${height} Z`,
      fill: `url(#${gradientId})`,
    }),
  );
  svg.appendChild(
    node('polyline', {
      points: line.join(' '),
      fill: 'none',
      stroke: color,
      'stroke-width': 2.4,
      'stroke-linecap': 'round',
      'stroke-linejoin': 'round',
      'vector-effect': 'non-scaling-stroke',
    }),
  );

  for (let index = 0; index < points.length; index += 1) {
    svg.appendChild(
      node('circle', {
        cx: x(index),
        cy: y(values[index]),
        r: 3.5,
        fill: color,
        'vector-effect': 'non-scaling-stroke',
      }),
    );
  }

  wrapper.appendChild(svg);

  // ป้ายค่าวาดเป็น HTML ทับบน SVG แทนที่จะเป็น <text> ใน SVG
  // เพราะ SVG ตัวนี้ยืดตามความกว้าง (preserveAspectRatio: none)
  // ถ้าใส่ตัวหนังสือข้างใน ตัวอักษรจะถูกยืดตามไปด้วยจนอ่านไม่ได้
  if (showLabels) {
    const layer = el('div', {
      style: {
        position: 'absolute',
        inset: '0',
        pointerEvents: 'none',
      },
    });
    // ป้ายเยอะเกินจะทับกัน จึงเว้นระยะให้เหลือราว 10 ป้าย
    const stride = Math.max(1, Math.ceil(points.length / 10));
    points.forEach((point, index) => {
      const isEdge = index === 0 || index === points.length - 1;
      const isPeak = values[index] === Math.max(...values);
      if (!isEdge && !isPeak && index % stride !== 0) return;
      layer.appendChild(
        el('div', {
          class: 'mono',
          text: labelOf(values[index]),
          style: {
            position: 'absolute',
            left: `${(x(index) / width) * 100}%`,
            top: `${(y(values[index]) / height) * 100}%`,
            transform: 'translate(-50%, -175%)',
            fontSize: '10.5px',
            color: isPeak ? color : 'var(--text-mid)',
            whiteSpace: 'nowrap',
          },
        }),
      );
    });
    wrapper.style.position = 'relative';
    wrapper.appendChild(layer);
  }

  wrapper.appendChild(
    el(
      'div',
      { class: 'spark-days' },
      points.map((point, index) => {
        const stride = Math.max(1, Math.ceil(points.length / 12));
        const show =
          index === 0 || index === points.length - 1 || index % stride === 0;
        return el('span', { text: show ? point.label : '' });
      }),
    ),
  );

  wrapper.appendChild(
    el('div', {
      class: 'dim',
      style: { fontSize: '10.5px', marginTop: '4px' },
      text: unit ? `หน่วยบนกราฟ: ${unit}` : '',
    }),
  );

  return wrapper;
}

/**
 * แถบอันดับแนวนอน ใช้กับ 5 ห้องที่ใช้ไฟมากที่สุด
 *
 * @param {{label:string, sub:string, value:number}[]} items
 */
export function rankBars(items, iconMarkup) {
  const max = Math.max(...items.map((item) => Number(item.value) || 0), 0.0001);
  const reference = scaleReference(items.map((item) => item.value));

  return items.map((item, index) => {
    const icon = el('div', { class: 'rank-icon' });
    icon.innerHTML = iconMarkup;
    return el('div', { class: 'rank-item' }, [
      el('div', { class: 'rank-num', text: String(index + 1) }),
      icon,
      el('div', { class: 'grow' }, [
        el('div', { class: 'rank-name', text: item.label }),
        el('div', { class: 'rank-sub', text: item.sub }),
      ]),
      el('div', {}, [
        el('div', {
          class: 'rank-val',
          text: energy(item.value, { scaleReference: reference }),
        }),
        el('div', { class: 'rank-bar-track' }, [
          el('div', {
            class: 'rank-bar-fill',
            style: {
              width: `${Math.max(3, ((Number(item.value) || 0) / max) * 100)}%`,
            },
          }),
        ]),
      ]),
    ]);
  });
}

/**
 * สีพื้นของช่องห้องใน Building Pulse
 *
 * ไล่จากสีพื้นหลังไปหาสีเน้น ตามสัดส่วนของค่าไฟเทียบกับห้องที่ใช้มากที่สุด
 * ใช้รากที่สองเพื่อให้ห้องที่ใช้ไฟน้อยยังพอมองเห็นความต่าง ถ้าไล่เป็นเส้นตรง
 * ห้องที่ใช้ 5 kWh กับ 0 kWh จะดูดำเหมือนกันหมดเมื่อมีห้องหนึ่งใช้ 90 kWh
 */
export function heatColor(value, max) {
  const amount = max > 0 ? Math.sqrt(Math.max(0, value) / max) : 0;
  const from = [18, 36, 23];
  const to = [62, 140, 92];
  const mix = from.map((start, index) =>
    Math.round(start + (to[index] - start) * amount),
  );
  return `rgb(${mix[0]}, ${mix[1]}, ${mix[2]})`;
}

/** ตัวเลขพร้อมหน่วยสำหรับกล่องค่าไฟเล็ก ๆ */
export function metricBox(value, unitText, label, digits = 1) {
  return el('div', { class: 'metric-box' }, [
    el('div', {
      class: 'metric-val',
      text: value == null ? '—' : `${decimal(value, digits)} ${unitText}`,
    }),
    el('div', { class: 'metric-label', text: label }),
  ]);
}
