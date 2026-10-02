/**
 * ตัวประกอบร่างของเว็บแอป
 *
 * หน้าที่มีสี่อย่าง: ตัดสินว่าล็อกอินหรือยัง, สร้างเมนูและแถบบน,
 * สลับหน้าตามที่อยู่ใน URL (#/overview) และส่งต่อการเปลี่ยนแปลงของสถานะ
 * ไปให้หน้าที่กำลังเปิดอยู่
 *
 * ใช้ hash เป็นตัวบอกหน้า (#/rooms) แทน History API เพราะเว็บนี้เสิร์ฟเป็น
 * ไฟล์ static ถ้าใช้ path จริง ผู้ใช้กด F5 ที่ /rooms แล้ว Caddy จะหา
 * ไฟล์ชื่อ rooms ไม่เจอและตอบ 404 การใช้ hash จึงไม่ต้องตั้ง rewrite เพิ่ม
 */

import { api, getCachedUser, onUnauthorized } from './api.js';
import { mountLoginScreen } from './auth.js';
import { BUILDING, STORAGE } from './config.js';
import { $, el, replace, svg } from './dom.js';
import { thaiFullDate } from './format.js';
import { icons } from './icons.js';
import {
  bootstrap,
  loaders,
  refreshAll,
  resetState,
  startPolling,
  state,
  subscribe,
} from './store.js';
import { toastError, toastInfo } from './ui.js';

import overview from './views/overview.js';
import rooms, { clearDrafts, roomDrawerContent, roomDrawerTitle } from './views/rooms.js';
import energy from './views/energy.js';
import schedule from './views/schedule.js';
import alerts from './views/alerts.js';
import rates from './views/rates.js';
import devices from './views/devices.js';
import users from './views/users.js';
import settings from './views/settings.js';

const VIEWS = [
  { key: 'overview', icon: 'grid', group: 'main', module: overview },
  { key: 'rooms', icon: 'building', group: 'main', module: rooms },
  { key: 'energy', icon: 'chart', group: 'main', module: energy },
  { key: 'schedule', icon: 'calendar', group: 'main', module: schedule },
  { key: 'alerts', icon: 'bell', group: 'main', module: alerts },
  { key: 'rates', icon: 'coin', group: 'main', module: rates },
  { key: 'devices', icon: 'chip', group: 'system', module: devices },
  { key: 'users', icon: 'users', group: 'system', module: users },
  { key: 'settings', icon: 'gear', group: 'system', module: settings },
];

const NAV_LABELS = {
  overview: 'ภาพรวม',
  rooms: 'ห้องและควบคุม',
  energy: 'ข้อมูลไฟฟ้า',
  schedule: 'ตารางเรียน',
  alerts: 'การแจ้งเตือน',
  rates: 'อัตราค่าไฟ',
  devices: 'ห้องและอุปกรณ์',
  users: 'ผู้ใช้งาน',
  settings: 'ตั้งค่า',
};

let current = null;
let currentKey = null;
let drawerRoom = null;
let unsubscribe = null;

const dom = {};

// --------------------------------------------------------------- เริ่มต้น

export function startApp() {
  cacheDom();
  wireShell();

  onUnauthorized((message) => {
    // โทเคนใช้ไม่ได้แล้ว ไม่ว่าจะหมดอายุหรือถูกแอดมินเปลี่ยนสิทธิ์
    // ต้องพากลับไปหน้าเข้าสู่ระบบทันที ไม่ปล่อยให้หน้าจอค้างข้อมูลเก่า
    teardownSession();
    toastInfo(message);
    showLogin();
  });

  const cached = getCachedUser();
  if (cached) {
    state.user = cached;
    enterApp(cached, { verify: true });
  } else {
    showLogin();
  }
}

function cacheDom() {
  dom.app = $('#app');
  dom.sidebar = $('#sidebar');
  dom.navMain = $('#navMain');
  dom.navSystem = $('#navSystem');
  dom.navSystemLabel = $('#navSystemLabel');
  dom.userChip = $('#userChip');
  dom.pageTitle = $('#pageTitle');
  dom.pageSub = $('#pageSub');
  dom.topbarRight = $('#topbarRight');
  dom.viewRoot = $('#viewRoot');
  dom.drawer = $('#drawer');
  dom.drawerOverlay = $('#drawerOverlay');
  dom.menuBtn = $('#menuBtn');
  dom.scrim = $('#scrim');
}

function wireShell() {
  dom.menuBtn.innerHTML = icons.menu(16);
  dom.menuBtn.addEventListener('click', () => {
    dom.sidebar.classList.toggle('open');
    dom.scrim.classList.toggle('open', dom.sidebar.classList.contains('open'));
  });
  dom.scrim.addEventListener('click', () => {
    dom.sidebar.classList.remove('open');
    dom.scrim.classList.remove('open');
  });
  dom.drawerOverlay.addEventListener('click', closeDrawer);
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && drawerRoom) closeDrawer();
  });
  window.addEventListener('hashchange', () => navigate(readHash()));
}

function showLogin() {
  dom.app.hidden = true;
  mountLoginScreen((user) => {
    state.user = user;
    enterApp(user, { verify: false });
  });
}

async function enterApp(user, { verify }) {
  dom.app.hidden = false;
  state.user = user;
  renderNav();
  renderUserChip();

  unsubscribe?.();
  unsubscribe = subscribe(() => {
    renderUserChip();
    renderTopbar();
    renderNavBadges();
    current?.update?.();
    if (drawerRoom) renderDrawer();
  });

  navigate(readHash());

  if (verify) {
    // โทเคนที่เก็บไว้อาจหมดอายุไปแล้วตั้งแต่ปิดแท็บ ตรวจกับเซิร์ฟเวอร์ก่อน
    // ถ้าไม่ผ่าน onUnauthorized จะพากลับไปหน้าเข้าสู่ระบบให้เอง
    try {
      state.user = await api.me();
    } catch {
      return;
    }
  }

  await bootstrap();
  startPolling();
  renderTopbar();
  renderNavBadges();
}

function teardownSession() {
  unsubscribe?.();
  unsubscribe = null;
  current?.destroy?.();
  current = null;
  currentKey = null;
  closeDrawer();
  resetState();
  dom.app.hidden = true;
}

function logout() {
  api.logout();
  teardownSession();
  showLogin();
}

// ------------------------------------------------------------------ เมนู

function visibleViews(group) {
  const isAdmin = state.user?.role === 'admin';
  return VIEWS.filter(
    (view) =>
      view.group === group && (!view.module.adminOnly || isAdmin),
  );
}

function renderNav() {
  const build = (group) =>
    visibleViews(group).map((view) => {
      const button = el('button', {
        class: 'nav-item',
        type: 'button',
        dataset: { view: view.key },
        onclick: () => {
          window.location.hash = `#/${view.key}`;
          dom.sidebar.classList.remove('open');
          dom.scrim.classList.remove('open');
        },
      });
      button.innerHTML = icons[view.icon](16);
      button.appendChild(document.createTextNode(NAV_LABELS[view.key]));
      if (view.key === 'alerts') {
        button.appendChild(el('span', { class: 'nav-badge', hidden: true }));
      }
      return button;
    });

  replace(dom.navMain, build('main'));
  const systemItems = build('system');
  replace(dom.navSystem, systemItems);
  dom.navSystemLabel.hidden = systemItems.length === 0;
  highlightNav();
}

function renderNavBadges() {
  const badge = dom.navSystem
    .querySelector('[data-view="alerts"] .nav-badge')
    ?? dom.navMain.querySelector('[data-view="alerts"] .nav-badge');
  if (!badge) return;
  const open = Number(state.alerts.counts?.open ?? 0);
  badge.hidden = open === 0;
  badge.textContent = String(open);
}

function highlightNav() {
  for (const button of [
    ...dom.navMain.querySelectorAll('.nav-item'),
    ...dom.navSystem.querySelectorAll('.nav-item'),
  ]) {
    button.classList.toggle('active', button.dataset.view === currentKey);
  }
}

function renderUserChip() {
  const user = state.user;
  if (!user) return;
  const name = `${user.firstName} ${user.lastName}`.trim() || user.username;
  const initials =
    `${(user.firstName || user.username || '?').charAt(0)}${
      (user.lastName || '').charAt(0)
    }`.toUpperCase();

  replace(dom.userChip, [
    el('div', { class: 'avatar', text: initials }),
    el('div', { class: 'grow' }, [
      el('div', { class: 'user-name', text: name }),
      el('div', {
        class: 'user-role',
        text: user.role === 'admin' ? 'ผู้ดูแลระบบ' : 'เจ้าหน้าที่',
      }),
    ]),
  ]);
  dom.userChip.onclick = () => {
    window.location.hash = '#/settings';
  };
}

function renderTopbar() {
  const mqtt = state.health?.mqtt;
  const totals = state.live.totals;

  const pills = [
    el(
      'div',
      {
        class: `pill ${mqtt?.connected ? 'live' : 'bad'}`,
        title: mqtt?.connected
          ? 'Backend เชื่อมต่อ MQTT Broker อยู่'
          : 'Backend ยังไม่เชื่อมต่อ MQTT — สั่งงานบอร์ดไม่ได้',
      },
      [
        el('span', { class: 'dot' }),
        mqtt?.connected ? 'MQTT เชื่อมต่อ' : 'MQTT ไม่เชื่อมต่อ',
      ],
    ),
    totals
      ? el('div', {
          class: 'pill',
          text: `${totals.online} / ${totals.devices} ESP32 ออนไลน์`,
        })
      : null,
    !state.settings.autoOffEnabled
      ? el('div', {
          class: 'pill bad',
          title: 'สวิตช์รวมของระบบปิดแอร์อัตโนมัติถูกปิดไว้',
          text: 'ปิดอัตโนมัติ: ปิดอยู่',
        })
      : null,
    el(
      'button',
      {
        class: 'btn btn-sm',
        type: 'button',
        title: 'ดึงข้อมูลใหม่ทันที',
        onclick: async (event) => {
          const button = event.currentTarget;
          button.disabled = true;
          await refreshAll();
          button.disabled = false;
        },
      },
      [svg(icons.refresh(14))],
    ),
  ];

  replace(dom.topbarRight, pills);
}

// ------------------------------------------------------------ สลับหน้าจอ

function readHash() {
  const raw = String(window.location.hash || '').replace(/^#\/?/, '');
  const key = raw.split('?')[0];
  if (VIEWS.some((view) => view.key === key)) return key;
  try {
    const saved = window.localStorage.getItem(STORAGE.lastView);
    if (saved && VIEWS.some((view) => view.key === saved)) return saved;
  } catch {
    // อ่าน localStorage ไม่ได้ก็ไม่เป็นไร ใช้หน้าเริ่มต้น
  }
  return 'overview';
}

async function navigate(key) {
  const view = VIEWS.find((item) => item.key === key);
  if (!view) return;

  if (view.module.adminOnly && state.user?.role !== 'admin') {
    toastError('หน้านี้สำหรับผู้ดูแลระบบเท่านั้น');
    window.location.hash = '#/overview';
    return;
  }

  if (currentKey === key) return;
  current?.destroy?.();
  currentKey = key;

  try {
    window.localStorage.setItem(STORAGE.lastView, key);
  } catch {
    // ไม่จำหน้าล่าสุดก็ยังใช้งานได้ปกติ
  }

  dom.pageTitle.textContent = view.module.title;
  dom.pageSub.textContent = `${BUILDING.name} · ${view.module.subtitle}`;
  highlightNav();
  replace(dom.viewRoot, []);
  window.scrollTo({ top: 0 });

  current = (await view.module.mount(dom.viewRoot, context)) ?? null;
}

// ------------------------------------------------------------- ลิ้นชักห้อง

const context = {
  openRoom(roomNumber) {
    drawerRoom = roomNumber;
    clearDrafts();
    renderDrawer();
    dom.drawer.classList.add('open');
    dom.drawerOverlay.classList.add('open');
  },
  refreshDrawer() {
    if (drawerRoom) renderDrawer();
  },
  logout,
};

function closeDrawer() {
  drawerRoom = null;
  clearDrafts();
  dom.drawer.classList.remove('open');
  dom.drawerOverlay.classList.remove('open');
}

function renderDrawer() {
  if (!drawerRoom) return;
  // จำตำแหน่งเลื่อนไว้ เพราะลิ้นชักถูกวาดใหม่ทุกครั้งที่ข้อมูลสดเข้ามา
  // ถ้าไม่จำ หน้าจะกระโดดกลับไปบนสุดทุก 10 วินาทีระหว่างที่คนกำลังตั้งค่า
  const scrollTop = dom.drawer.scrollTop;
  const head = roomDrawerTitle(drawerRoom);

  const closeButton = el('button', {
    class: 'icon-btn',
    type: 'button',
    title: 'ปิด',
    'aria-label': 'ปิด',
    onclick: closeDrawer,
  });
  closeButton.innerHTML = icons.close(14);

  replace(dom.drawer, [
    el('div', { class: 'drawer-head' }, [
      el('div', {}, [
        el('div', { class: 'drawer-title', text: head.title }),
        el('div', { class: 'drawer-sub', text: head.subtitle }),
      ]),
      closeButton,
    ]),
    roomDrawerContent(drawerRoom, context),
  ]);

  dom.drawer.scrollTop = scrollTop;
}

// --------------------------------------------------------- ข้อมูลประกอบ

/** ใส่วันที่ไทยไว้ในแถบบนตอนเริ่ม แล้วอัปเดตทุกนาที */
export function startClock() {
  const node = $('#todayLine');
  if (!node) return;
  const paint = () => {
    node.textContent = thaiFullDate(new Date());
  };
  paint();
  window.setInterval(paint, 60000);
}

/** เผื่อกรณีข้อมูลตั้งค่าโหลดไม่ทันตอนเข้าแอปครั้งแรก */
export const reloadSettings = () => loaders.settings();
