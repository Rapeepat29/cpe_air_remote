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
 * ชี้เมาส์หรือแตะค้างบนกราฟเพื่อดูค่าจริงของจุดนั้น พร้อมวันเวลา
 * (`tipLabel` บอกได้ว่าจะเขียนหัวป้ายอย่างไร ไม่ส่งมาก็ใช้ป้ายของจุด)
 *
 * สีอ่านจากตัวแปร CSS ผ่าน style ไม่ได้ใส่เป็นแอตทริบิวต์ fill/stroke
 * เพราะแอตทริบิวต์ของ SVG ไม่รู้จัก var(--...) และกราฟต้องเปลี่ยนสีตามธีม
 *
 * @param {{label:string, value:number, tip?:string}[]} points
 * @param {{height:number, color:string, tipLabel:Function}} options
 */
export function areaChart(points, options = {}) {
  const {
    height = 200,
    color = 'var(--accent)',
    showLabels = true,
    unitOverride = null,
    tipLabel = null,
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
  const stopTop = node('stop', { offset: '0%', 'stop-opacity': 0.32 });
  const stopBottom = node('stop', { offset: '100%', 'stop-opacity': 0 });
  stopTop.style.stopColor = color;
  stopBottom.style.stopColor = color;
  gradient.appendChild(stopTop);
  gradient.appendChild(stopBottom);
  defs.appendChild(gradient);
  svg.appendChild(defs);

  const line = points.map((point, index) => `${x(index)},${y(values[index])}`);
  svg.appendChild(
    node('path', {
      d: `M${line.join(' L')} L${x(points.length - 1)},${height} L${x(0)},${height} Z`,
      fill: `url(#${gradientId})`,
    }),
  );
  const polyline = node('polyline', {
    points: line.join(' '),
    fill: 'none',
    'stroke-width': 2.4,
    'stroke-linecap': 'round',
    'stroke-linejoin': 'round',
    'vector-effect': 'non-scaling-stroke',
  });
  polyline.style.stroke = color;
  svg.appendChild(polyline);

  // จุดกลม ๆ วาดเฉพาะตอนมีไม่กี่จุด ถ้าเป็นรายชั่วโมงหลายร้อยจุด
  // วงกลมจะเบียดกันจนกลายเป็นเส้นหนาทึบ อ่านรูปทรงกราฟไม่ออก
  if (points.length <= 60) {
    for (let index = 0; index < points.length; index += 1) {
      const dot = node('circle', {
        cx: x(index),
        cy: y(values[index]),
        r: 3.5,
        'vector-effect': 'non-scaling-stroke',
      });
      dot.style.fill = color;
      svg.appendChild(dot);
    }
  }

  wrapper.appendChild(svg);
  wrapper.style.position = 'relative';

  // ป้ายค่าวาดเป็น HTML ทับบน SVG แทนที่จะเป็น <text> ใน SVG
  // เพราะ SVG ตัวนี้ยืดตามความกว้าง (preserveAspectRatio: none)
  // ถ้าใส่ตัวหนังสือข้างใน ตัวอักษรจะถูกยืดตามไปด้วยจนอ่านไม่ได้
  if (showLabels) {
    // ชั้นป้ายสูงเท่าตัวกราฟพอดี (ไม่ใช่ทั้งกล่องที่รวมป้ายวันที่ด้านล่าง)
    // ตำแหน่งเปอร์เซ็นต์ของป้ายจึงตรงกับจุดบนเส้น
    const layer = el('div', {
      style: {
        position: 'absolute',
        left: '0',
        right: '0',
        top: '0',
        height: `${height}px`,
        pointerEvents: 'none',
      },
    });
    // ป้ายเยอะเกินจะทับกัน จึงเว้นระยะให้เหลือราว 10 ป้าย
    // และไม่เขียนป้ายของจุดที่ค่าเกือบศูนย์ เพราะจะไปทับวันที่ใต้กราฟ
    // (ค่าจริงของทุกจุดยังดูได้จากการชี้เมาส์)
    const stride = Math.max(1, Math.ceil(points.length / 10));
    const peak = Math.max(...values);
    let peakLabelled = false;
    points.forEach((point, index) => {
      const isEdge = index === 0 || index === points.length - 1;
      const isPeak = !peakLabelled && values[index] === peak;
      if (!isEdge && !isPeak && index % stride !== 0) return;
      if (!isPeak && values[index] < peak * 0.08) return;
      if (isPeak) peakLabelled = true;
      layer.appendChild(
        el('div', {
          class: `chart-label${isPeak ? ' peak' : ''}`,
          text: labelOf(values[index]),
          style: {
            left: `${(x(index) / width) * 100}%`,
            top: `${(y(values[index]) / height) * 100}%`,
            // ป้ายของจุดแรก/จุดสุดท้ายชิดขอบในแทนการอยู่กึ่งกลาง ไม่งั้นจะล้นขอบการ์ด
            transform:
              index === 0
                ? 'translate(0, -165%)'
                : index === points.length - 1
                  ? 'translate(-100%, -165%)'
                  : null,
          },
        }),
      );
    });
    wrapper.appendChild(layer);
  }

  // ป้ายแกนนอน: ข้อมูลรายชั่วโมงมีป้ายวันซ้ำกันหลายสิบจุด เขียนเฉพาะจุดที่
  // วันเปลี่ยน ไม่งั้นจะเห็น "09-28 09-28 09-28" เรียงกันจนอ่านไม่ออก
  const maxTicks = 12;
  const stride = Math.max(1, Math.ceil(points.length / maxTicks));
  let lastShown = null;
  wrapper.appendChild(
    el(
      'div',
      { class: 'spark-days', 'aria-hidden': 'true' },
      points.map((point, index) => {
        const due = index === 0 || index % stride === 0;
        const show = due && point.label !== lastShown;
        if (show) lastShown = point.label;
        return el('span', { text: show ? point.label : '' });
      }),
    ),
  );

  wrapper.appendChild(
    el('div', {
      class: 'chart-unit',
      text: unit
        ? `หน่วยบนกราฟ: ${unit} · ชี้หรือแตะที่กราฟเพื่อดูค่าแต่ละจุด`
        : 'ชี้หรือแตะที่กราฟเพื่อดูค่าแต่ละจุด',
    }),
  );

  attachTooltip(wrapper, svg, {
    points,
    values,
    x: (index) => x(index) / width,
    y: (index) => y(values[index]) / height,
    height,
    text: (index) => {
      const point = points[index];
      const head = point.tip ?? (tipLabel ? tipLabel(point, index) : point.label);
      const value = labelOf(values[index]);
      return { head, value: unit ? `${value} ${unit}` : value };
    },
  });

  return wrapper;
}

/**
 * เส้นตั้ง จุด และกล่องค่าที่ตามเมาส์ (หรือนิ้ว) บนกราฟ
 *
 * หาจุดที่ใกล้ที่สุดจากตำแหน่งแนวนอนอย่างเดียว ผู้ใช้จึงไม่ต้องเล็งให้โดนจุด
 * เล็ก ๆ เป๊ะ ๆ ซึ่งบนมือถือแทบทำไม่ได้
 */
function attachTooltip(wrapper, svgNode, { points, x, y, height, text }) {
  if (points.length === 0) return;
  const cursor = el('div', { class: 'chart-cursor', style: { height: `${height}px` } });
  const dot = el('div', { class: 'chart-dot' });
  const tip = el('div', { class: 'spark-tip', role: 'status' }, [
    el('span', { class: 'tip-head' }),
    el('b', { class: 'tip-value' }),
  ]);
  wrapper.append(cursor, dot, tip);

  const show = (clientX) => {
    const box = svgNode.getBoundingClientRect();
    if (box.width === 0) return;
    const ratio = Math.min(1, Math.max(0, (clientX - box.left) / box.width));
    const index =
      points.length > 1 ? Math.round(ratio * (points.length - 1)) : 0;
    const left = x(index) * box.width;
    const top = y(index) * height;
    const content = text(index);
    tip.firstChild.textContent = content.head;
    tip.lastChild.textContent = content.value;
    cursor.style.left = `${left}px`;
    dot.style.left = `${left}px`;
    dot.style.top = `${top}px`;
    // กันกล่องค่าล้นขอบซ้าย-ขวาของการ์ด
    const half = tip.offsetWidth / 2;
    tip.style.left = `${Math.min(box.width - half, Math.max(half, left))}px`;
    tip.style.top = `${Math.max(top, 30)}px`;
    wrapper.classList.add('hovering');
  };
  const hide = () => wrapper.classList.remove('hovering');

  svgNode.addEventListener('pointermove', (event) => show(event.clientX));
  svgNode.addEventListener('pointerdown', (event) => show(event.clientX));
  svgNode.addEventListener('pointerleave', hide);
  svgNode.addEventListener('pointercancel', hide);
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
  // ผสมสีด้วย color-mix ให้เปลี่ยนตามธีมเอง (--heat ของธีมมืดกับสว่างคนละค่า)
  const percent = Math.round(amount * 100);
  return `color-mix(in srgb, var(--heat) ${percent}%, var(--panel-raised))`;
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
