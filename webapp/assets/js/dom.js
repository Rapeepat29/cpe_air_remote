/**
 * ตัวช่วยเล็ก ๆ สำหรับสร้างและจัดการ DOM
 *
 * ตั้งใจไม่ใช้เฟรมเวิร์ก เพราะเว็บนี้ต้องวางบน Caddy เป็นไฟล์ static ตรง ๆ
 * ไม่มีขั้นตอน build ให้ต้องดูแล แต่ก็ไม่อยากเขียน innerHTML ด้วยสตริงดิบ
 * ทุกที่ เพราะข้อมูลจากฐานข้อมูล (ชื่อวิชา ชื่ออาจารย์) อาจมีอักขระ HTML ปนมา
 */

/** สร้างอิลิเมนต์พร้อมคุณสมบัติและลูก */
export function el(tag, props = {}, children = []) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (value == null || value === false) continue;
    if (key === 'class') {
      node.className = value;
    } else if (key === 'text') {
      node.textContent = String(value);
    } else if (key === 'html') {
      node.innerHTML = value;
    } else if (key === 'dataset') {
      Object.assign(node.dataset, value);
    } else if (key === 'style' && typeof value === 'object') {
      Object.assign(node.style, value);
    } else if (key.startsWith('on') && typeof value === 'function') {
      node.addEventListener(key.slice(2).toLowerCase(), value);
    } else if (value === true) {
      node.setAttribute(key, '');
    } else {
      node.setAttribute(key, String(value));
    }
  }
  append(node, children);
  return node;
}

/** ใส่ลูกเข้าไปในโหนด รับได้ทั้งข้อความ อิลิเมนต์ และอาเรย์ซ้อน */
export function append(node, children) {
  const list = Array.isArray(children) ? children : [children];
  for (const child of list) {
    if (child == null || child === false) continue;
    if (Array.isArray(child)) {
      append(node, child);
    } else if (child instanceof Node) {
      node.appendChild(child);
    } else {
      node.appendChild(document.createTextNode(String(child)));
    }
  }
  return node;
}

/** ล้างลูกทั้งหมดแล้วใส่ชุดใหม่ */
export function replace(node, children) {
  if (!node) return node;
  node.textContent = '';
  return append(node, children);
}

export function $(selector, scope = document) {
  return scope.querySelector(selector);
}

export function $$(selector, scope = document) {
  return [...scope.querySelectorAll(selector)];
}

/** อิลิเมนต์ SVG จากสตริง (ใช้กับไอคอนที่เราเขียนเอง ไม่ใช่ข้อมูลผู้ใช้) */
export function svg(markup) {
  const wrapper = document.createElement('span');
  wrapper.innerHTML = markup.trim();
  wrapper.style.display = 'inline-flex';
  return wrapper.firstElementChild ?? wrapper;
}

/** กล่องข้อความว่าง */
export function emptyState(text) {
  return el('div', { class: 'empty', text });
}

/** แถบโครงกระดูกตอนกำลังโหลด */
export function skeleton(height = 16, width = '100%') {
  return el('div', {
    class: 'skeleton',
    style: { height: `${height}px`, width },
  });
}

/** ปุ่มเปิด/ปิด */
export function toggle(on, { disabled = false, onclick = null, title = '' }) {
  return el('button', {
    class: `switch${on ? ' on' : ''}`,
    type: 'button',
    disabled,
    title,
    'aria-pressed': on ? 'true' : 'false',
    onclick,
  });
}
