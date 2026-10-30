/* OpenReader landing page: theme, OS-aware download button, device previews and screenshot tabs. */
(function () {
  'use strict';

  var PLAY = 'https://play.google.com/store/apps/details?id=com.chowdhuryelab.openreader';
  var RELEASES = 'https://github.com/macdipu/OpenReader/releases/latest';
  var OS_NAME = { android: 'Android', windows: 'Windows', macos: 'macOS', linux: 'Linux' };

  var CTA = {
    android: { label: 'Get it on Google Play', href: PLAY, note: 'Also available as an APK on <a href="' + RELEASES + '">GitHub Releases</a>.' },
    windows: { label: 'Download for Windows', href: RELEASES, note: 'Unsigned build: Windows SmartScreen may ask you to confirm. <a href="#platforms">Other platforms</a>' },
    macos: { label: 'Download for macOS', href: RELEASES, note: 'Unsigned build: on first launch right-click the app and choose Open. <a href="#platforms">Other platforms</a>' },
    linux: { label: 'Download for Linux', href: RELEASES, note: '.deb, .rpm or AppImage. <a href="#platforms">Other platforms</a>' },
    other: { label: 'Download Free', href: '#platforms', note: '' }
  };

  var $ = function (id) { return document.getElementById(id); };
  var root = document.documentElement;

  // ---- theme -------------------------------------------------------------
  function currentTheme() { return root.getAttribute('data-theme') === 'dark' ? 'dark' : 'light'; }

  function applyTheme(theme, save) {
    root.setAttribute('data-theme', theme);
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', theme === 'dark' ? '#07080f' : '#f4f7ff');
    var btn = $('theme-toggle');
    if (btn) btn.setAttribute('aria-label', theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme');
    if (save) { try { localStorage.setItem('openreader-theme', theme); } catch (e) { /* private mode */ } }
  }

  function initTheme() {
    applyTheme(currentTheme(), false);
    var btn = $('theme-toggle');
    if (btn) btn.addEventListener('click', function () { applyTheme(currentTheme() === 'dark' ? 'light' : 'dark', true); });
    // Follow the system only until the visitor picks a theme themselves.
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    var onChange = function (e) {
      var saved = null;
      try { saved = localStorage.getItem('openreader-theme'); } catch (err) { /* ignore */ }
      if (!saved) applyTheme(e.matches ? 'dark' : 'light', false);
    };
    if (mq.addEventListener) mq.addEventListener('change', onChange);
  }

  // ---- OS-aware download -------------------------------------------------
  function detect() {
    var forced = new URLSearchParams(location.search).get('os');
    if (forced && (OS_NAME[forced] || forced === 'other')) return forced;
    var ua = (navigator.userAgent || '').toLowerCase();
    var plat = ((navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || '').toLowerCase();
    if (/android/.test(ua)) return 'android';
    if (/iphone|ipad|ipod/.test(ua)) return 'other';   // no iOS build
    if (/win/.test(plat) || /windows/.test(ua)) return 'windows';
    if (/mac/.test(plat) || /macintosh|mac os x/.test(ua)) return 'macos';
    if (/linux|x11|cros/.test(plat + ua)) return 'linux';
    return 'other';
  }

  function initDownload() {
    var os = detect();
    var cta = CTA[os] || CTA.other;
    document.body.classList.add('os-' + os);
    $('cta-label').textContent = cta.label;
    $('cta-primary').href = cta.href;
    $('cta-note').innerHTML = cta.note;

    var list = $('platform-list');
    var order = ['android', 'windows', 'macos', 'linux'];
    if (OS_NAME[os]) order = [os].concat(order.filter(function (o) { return o !== os; }));
    list.querySelectorAll('.platform').forEach(function (card) {
      var key = card.getAttribute('data-os');
      card.style.order = String(order.indexOf(key));
      if (key === os) card.classList.add('current');
    });
  }

  // ---- device lineup: click a device to see it larger --------------------
  var DEVICE_TITLE = {
    'windows-desktop': 'Windows desktop',
    'macos-laptop': 'macOS laptop',
    'android-tablet': 'Android tablet',
    'android-foldable': 'Android foldable, unfolded',
    'android-phone': 'Android phone'
  };

  function initDevices() {
    var dlg = $('viewer');
    if (!dlg || typeof dlg.showModal !== 'function') return;   // old browser: the lineup stays a static picture
    var body = $('viewer-body');

    document.querySelectorAll('.dev').forEach(function (dev) {
      dev.addEventListener('click', function () {
        var frame = dev.querySelector('.frame');
        var clone = frame.cloneNode(true);
        clone.querySelectorAll('img').forEach(function (img) { img.removeAttribute('loading'); });
        body.textContent = '';
        body.appendChild(clone);
        $('viewer-title').textContent = DEVICE_TITLE[dev.getAttribute('data-device')] || '';
        dlg.showModal();
      });
    });
    // Click on the backdrop closes it.
    dlg.addEventListener('click', function (e) { if (e.target === dlg) dlg.close(); });
  }

  // ---- screenshot tabs ---------------------------------------------------
  function initShowcase() {
    var img = $('showcase-img');
    var names = { pdf: 'PDF reader', docx: 'Word reader', xlsx: 'Excel reader', 'docx-dark': 'Word reader in night mode' };
    document.querySelectorAll('.tab').forEach(function (tab) {
      tab.addEventListener('click', function () {
        document.querySelectorAll('.tab').forEach(function (t) { t.setAttribute('aria-selected', 'false'); });
        tab.setAttribute('aria-selected', 'true');
        var shot = tab.getAttribute('data-shot');
        img.style.opacity = '0.35';
        img.onload = function () { img.style.opacity = '1'; };
        img.src = 'assets/screens/desktop-' + shot + '.png';
        img.alt = 'OpenReader ' + names[shot] + ' on Windows';
      });
    });
  }

  // ---- reveal on scroll --------------------------------------------------
  function initReveal() {
    var items = document.querySelectorAll('.section-head, .lineup, .card, .platform, .format, .benefit, .privacy-highlight, .split > *, .window, .faq');
    if (!('IntersectionObserver' in window)) return;
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('seen'); io.unobserve(e.target); } });
    }, { threshold: 0.12 });
    items.forEach(function (el) { el.classList.add('in'); io.observe(el); });
  }

  initTheme();
  initDownload();
  initDevices();
  initShowcase();
  initReveal();
})();
