(function () {
  var root = document.documentElement;
  function store(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }

  var themeBtn = document.getElementById('themeBtn');
  themeBtn.addEventListener('click', function () {
    var dark = root.dataset.theme === 'dark' ||
      (!root.dataset.theme && window.matchMedia('(prefers-color-scheme: dark)').matches);
    root.dataset.theme = dark ? 'light' : 'dark';
    store('guide.theme', root.dataset.theme);
  });

  var sizes = ['', 'large', 'xlarge'];
  document.getElementById('fontBtn').addEventListener('click', function () {
    var i = (sizes.indexOf(root.dataset.font || '') + 1) % sizes.length;
    if (sizes[i]) root.dataset.font = sizes[i]; else delete root.dataset.font;
    store('guide.font', sizes[i]);
  });

  var sidebar = document.getElementById('sidebar');
  document.getElementById('menuBtn').addEventListener('click', function () {
    sidebar.classList.toggle('open');
  });
  document.getElementById('content').addEventListener('click', function () {
    sidebar.classList.remove('open');
  });

  // keep active nav item visible
  var active = document.querySelector('.nav a.active');
  if (active) active.scrollIntoView({ block: 'center' });

  // search across chapter titles and section headings
  var input = document.getElementById('navSearch');
  var results = document.getElementById('searchResults');
  var nav = document.getElementById('nav');
  var inChapter = location.pathname.indexOf('/chapters/') !== -1;
  var prefix = inChapter ? '' : 'chapters/';
  function slug(t) {
    return t.replace(/<[^>]+>/g, '').replace(/[^\w฀-๿\- ]/g, '').trim().toLowerCase().replace(/ /g, '-');
  }
  input.addEventListener('input', function () {
    var q = input.value.trim().toLowerCase();
    results.textContent = '';
    if (!q) { nav.style.display = ''; return; }
    nav.style.display = 'none';
    var count = 0;
    (window.CHAPTERS || []).forEach(function (c) {
      var hits = [];
      if (c.title.toLowerCase().indexOf(q) !== -1) hits.push({ t: c.title, h: '' });
      c.heads.forEach(function (h) { if (h.toLowerCase().indexOf(q) !== -1) hits.push({ t: h, h: '#' + slug(h) }); });
      hits.forEach(function (hit) {
        if (count++ > 40) return;
        var a = document.createElement('a');
        a.href = prefix + c.name + '.html' + hit.h;
        var small = document.createElement('small');
        small.textContent = 'บท ' + c.n + ' · ' + c.title;
        var span = document.createElement('span');
        span.textContent = hit.t;
        a.appendChild(span); a.appendChild(small);
        results.appendChild(a);
      });
    });
    if (!count) { var p = document.createElement('p'); p.textContent = 'ไม่พบหัวข้อที่ตรงกัน ลองกด Ctrl+F ค้นในหน้า'; results.appendChild(p); }
  });

  // highlight current section in TOC
  var tocLinks = Array.prototype.slice.call(document.querySelectorAll('.toc a'));
  if (tocLinks.length && 'IntersectionObserver' in window) {
    var map = {};
    tocLinks.forEach(function (a) { map[a.getAttribute('href').slice(1)] = a; });
    var obs = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting && map[e.target.id]) {
          tocLinks.forEach(function (a) { a.classList.remove('on'); });
          map[e.target.id].classList.add('on');
        }
      });
    }, { rootMargin: '0px 0px -75% 0px' });
    document.querySelectorAll('.content h2[id]').forEach(function (h) { obs.observe(h); });
  }

  // checklist progress remembered per page
  var key = 'guide.check.' + location.pathname;
  var boxes = document.querySelectorAll('li.check input');
  var saved = [];
  try { saved = JSON.parse(localStorage.getItem(key) || '[]'); } catch (e) {}
  boxes.forEach(function (b, i) {
    if (saved[i]) b.checked = true;
    b.addEventListener('change', function () {
      var s = Array.prototype.map.call(boxes, function (x) { return x.checked ? 1 : 0; });
      store(key, JSON.stringify(s));
    });
  });

  var top = document.getElementById('toTop');
  window.addEventListener('scroll', function () {
    top.classList.toggle('show', window.scrollY > 800);
  });
  top.addEventListener('click', function () { window.scrollTo({ top: 0, behavior: 'smooth' }); });
})();
