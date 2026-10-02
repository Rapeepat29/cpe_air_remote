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
import { uiIcons } from './icons-ui.js';
import { onPrefsChange, prefs, toggleTheme } from './prefs.js';
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

/**
 * หน้าที่อยู่บนแถบเมนูล่างของมือถือ เลือกจากที่คนดูแลอาคารเปิดบ่อยที่สุด
 * หน้าอื่นเข้าจากปุ่ม "เมนู" ช่องสุดท้าย ซึ่งเปิดแถบข้างแบบเต็มขึ้นมา
 */
const BOTTOM_NAV = ['overview', 'rooms', 'energy', 'alerts'];

const SHORT_LABELS = {
  overview: 'ภาพรวม',
  rooms: 'ห้อง',
  energy: 'ข้อมูลไฟ',
  alerts: 'แจ้งเตือน',
};

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
  dom.bottomNav = buildBottomNav();
}

/**
 * แถบเมนูล่างสร้างจาก JavaScript ไม่ได้เขียนไว้ใน index.html
 * เพราะถ้าเบราว์เซอร์ยังถือ app.js ตัวเก่าในแคช จะได้ไม่มีแถบว่าง ๆ โผล่มา
 */
function buildBottomNav() {
  const nav = el('nav', { class: 'bottom-nav', 'aria-label': 'เมนูด่วน' });
  dom.app.appendChild(nav);
  dom.app.classList.add('has-bottom-nav');
  return nav;
}

function openSidebar() {
  dom.sidebar.classList.add('open');
  dom.scrim.classList.add('open');
}

function closeSidebar() {
  dom.sidebar.classList.remove('open');
  dom.scrim.classList.remove('open');
}

function wireShell() {
  dom.menuBtn.innerHTML = icons.menu(18);
  dom.menuBtn.addEventListener('click', () => {
    if (dom.sidebar.classList.contains('open')) closeSidebar();
    else openSidebar();
  });
  dom.scrim.addEventListener('click', closeSidebar);
  dom.drawerOverlay.addEventListener('click', closeDrawer);
  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    if (drawerRoom) closeDrawer();
    else closeSidebar();
  });
  window.addEventListener('hashchange', () => navigate(readHash()));
  // ปุ่มสลับธีมบนแถบบนต้องเปลี่ยนไอคอนตามเมื่อไปเปลี่ยนจากหน้าตั้งค่า
  onPrefsChange(() => {
    if (state.user) renderTopbar();
  });
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
          closeSidebar();
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
  renderBottomNav();
  highlightNav();
}

function renderBottomNav() {
  const item = (key, iconMarkup, label, onclick) => {
    const button = el(
      'button',
      {
        class: 'bottom-nav-item',
        type: 'button',
        dataset: { view: key },
        onclick,
      },
      [el('span', { class: 'bn-icon', html: iconMarkup }), el('span', { text: label })],
    );
    if (key === 'alerts') {
      button.appendChild(el('span', { class: 'nav-badge', hidden: true }));
    }
    return button;
  };

  replace(dom.bottomNav, [
    ...BOTTOM_NAV.map((key) => {
      const view = VIEWS.find((entry) => entry.key === key);
      return item(key, icons[view.icon](20), SHORT_LABELS[key], () => {
        window.location.hash = `#/${key}`;
        closeSidebar();
      });
    }),
    item('more', uiIcons.more(20), 'เมนู', () => {
      if (dom.sidebar.classList.contains('open')) closeSidebar();
      else openSidebar();
    }),
  ]);
}

function renderNavBadges() {
  const open = Number(state.alerts.counts?.open ?? 0);
  const badges = [
    dom.navSystem.querySelector('[data-view="alerts"] .nav-badge'),
    dom.navMain.querySelector('[data-view="alerts"] .nav-badge'),
    dom.bottomNav?.querySelector('[data-view="alerts"] .nav-badge'),
  ];
  for (const badge of badges) {
    if (!badge) continue;
    badge.hidden = open === 0;
    badge.textContent = open > 99 ? '99+' : String(open);
  }
}

function highlightNav() {
  for (const button of [
    ...dom.navMain.querySelectorAll('.nav-item'),
    ...dom.navSystem.querySelectorAll('.nav-item'),
  ]) {
    const active = button.dataset.view === currentKey;
    button.classList.toggle('active', active);
    if (active) button.setAttribute('aria-current', 'page');
    else button.removeAttribute('aria-current');
  }
  // หน้าที่ไม่มีบนแถบล่าง ให้ปุ่ม "เมนู" สว่างแทน คนจะได้รู้ว่าอยู่ในเมนูนั้น
  const onBar = BOTTOM_NAV.includes(currentKey);
  for (const button of dom.bottomNav?.querySelectorAll('.bottom-nav-item') ?? []) {
    const key = button.dataset.view;
    button.classList.toggle(
      'active',
      key === currentKey || (key === 'more' && !onBar && currentKey != null),
    );
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
        class: 'icon-btn',
        type: 'button',
        title: 'ดึงข้อมูลใหม่ทันที',
        'aria-label': 'ดึงข้อมูลใหม่ทันที',
        onclick: async (event) => {
          const button = event.currentTarget;
          button.disabled = true;
          await refreshAll();
          button.disabled = false;
        },
      },
      [svg(icons.refresh(15))],
    ),
    el(
      'button',
      {
        class: 'icon-btn',
        type: 'button',
        title: prefs.theme === 'light' ? 'เปลี่ยนเป็นธีมมืด' : 'เปลี่ยนเป็นธีมสว่าง',
        'aria-label': prefs.theme === 'light' ? 'เปลี่ยนเป็นธีมมืด' : 'เปลี่ยนเป็นธีมสว่าง',
        onclick: toggleTheme,
      },
      [svg(prefs.theme === 'light' ? uiIcons.moon(16) : uiIcons.sun(16))],
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

  // เปลี่ยนหน้าแล้วต้องปิดลิ้นชักรีโมตและเมนูที่เปิดค้าง ไม่งั้นฉากทึบ
  // ของลิ้นชักจะบังหน้าใหม่ทั้งหน้า (เกิดตอนกดย้อนกลับในเบราว์เซอร์)
  if (drawerRoom) closeDrawer();
  closeSidebar();

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
  document.title = `${view.module.title} · RMUTT Save Energy`;
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
    title: 'ปิด (Esc)',
    'aria-label': 'ปิด',
    onclick: closeDrawer,
  });
  closeButton.innerHTML = icons.close(16);

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
