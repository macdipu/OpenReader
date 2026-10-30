/* OpenReader landing page: OS-aware hero, download buttons and previews. */
(function () {
  'use strict';

  var PLAY = 'https://play.google.com/store/apps/details?id=com.chowdhuryelab.openreader';
  var RELEASES = 'https://github.com/macdipu/OpenDocs/releases/latest';

  // Screenshot prefix per platform. Windows images are the "desktop-*" set;
  // add macos-*.png / linux-*.png to assets/screens/ (see docs/TODO.md) and they are
  // picked up automatically. Until then the Windows shot is used, with a note.
  var SHOT_PREFIX = { windows: 'desktop', macos: 'macos', linux: 'linux' };
  var FALLBACK_PREFIX = 'desktop';
  var OS_NAME = { android: 'Android', windows: 'Windows', macos: 'macOS', linux: 'Linux' };

  var CTA = {
    android: { label: 'Get it on Google Play', sub: 'Free · Android phones & tablets', href: PLAY,
      secondary: { text: 'Desktop downloads', href: '#platforms' }, note: '' },
    windows: { label: 'Download for Windows', sub: 'Windows 10 or later · 64-bit', href: RELEASES,
      secondary: { text: 'Get it for Android', href: PLAY },
      note: 'Unsigned build: Windows SmartScreen may ask you to confirm. <a href="#platforms">Other platforms</a>' },
    macos: { label: 'Download for macOS', sub: 'macOS 12 or later', href: RELEASES,
      secondary: { text: 'Get it for Android', href: PLAY },
      note: 'Unsigned build: on first launch right-click the app and choose Open. <a href="#platforms">Other platforms</a>' },
    linux: { label: 'Download for Linux', sub: 'x64 · .deb, .rpm, AppImage', href: RELEASES,
      secondary: { text: 'Get it for Android', href: PLAY },
      note: 'Pick the .deb, .rpm or AppImage for your distribution. <a href="#platforms">Other platforms</a>' },
    other: { label: 'Download OpenReader', sub: 'Android, Windows, macOS & Linux', href: '#platforms',
      secondary: { text: 'Get it on Google Play', href: PLAY }, note: '' }
  };

  function detect() {
    var forced = new URLSearchParams(location.search).get('os');
    if (forced && OS_NAME[forced]) return forced;
    var ua = (navigator.userAgent || '').toLowerCase();
    var plat = ((navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || '').toLowerCase();
    if (/android/.test(ua)) return 'android';
    if (/iphone|ipad|ipod/.test(ua)) return 'other';
    if (/win/.test(plat) || /windows/.test(ua)) return 'windows';
    if (/mac/.test(plat) || /macintosh|mac os x/.test(ua)) return 'macos';
    if (/linux|x11|cros/.test(plat + ua)) return 'linux';
    return 'other';
  }

  var $ = function (id) { return document.getElementById(id); };
  var os = detect();
  var shot = 'pdf';
  var previewOs = os;          // platform the previews are showing
  var usedFallback = false;

  function setText(id, value) { var el = $(id); if (el) el.textContent = value; }

  function applyHero() {
    var cta = CTA[os] || CTA.other;
    document.body.classList.add('os-' + os);
    setText('cta-label', cta.label);
    setText('cta-sub', cta.sub);
    $('cta-primary').href = cta.href;
    $('cta-secondary').textContent = cta.secondary.text;
    $('cta-secondary').href = cta.secondary.href;
    $('cta-note').innerHTML = cta.note;
    var nav = $('nav-cta');
    nav.href = cta.href;
    nav.textContent = os === 'android' ? 'Get the app' : (os === 'other' ? 'Download' : 'Download');
  }

  function applyPlatforms() {
    var list = $('platform-list');
    var cards = Array.prototype.slice.call(list.querySelectorAll('.platform'));
    var order = ['android', 'windows', 'macos', 'linux'];
    if (OS_NAME[os]) order = [os].concat(order.filter(function (o) { return o !== os; }));
    cards.forEach(function (card) {
      var key = card.getAttribute('data-os');
      card.style.order = String(order.indexOf(key));
      if (key === os) card.classList.add('current');
    });
    list.style.display = 'grid';
  }

  // ---- screenshots -------------------------------------------------------
  function src(prefix, name) { return 'assets/screens/' + prefix + '-' + name + '.png'; }

  function loadImage(img, prefix, name, noteEl, platformName) {
    img.onerror = function () {
      img.onerror = null;
      img.src = src(FALLBACK_PREFIX, name);
      usedFallback = true;
      if (noteEl) noteEl.textContent = 'Preview from the Windows build — ' + platformName + ' screenshot coming soon.';
    };
    if (noteEl) noteEl.textContent = '';
    img.src = src(prefix, name);
  }

  function showcasePlatform() {
    // Android has phone shots only on the hero; the showcase always shows a desktop reader.
    return previewOs === 'android' ? 'windows' : previewOs;
  }

  function renderShowcase() {
    var img = $('showcase-img');
    var plat = showcasePlatform();
    var prefix = SHOT_PREFIX[plat] || FALLBACK_PREFIX;
    img.style.opacity = '0.4';
    img.onload = function () { img.style.opacity = '1'; };
    loadImage(img, prefix, shot, $('showcase-note'), OS_NAME[plat] || 'desktop');

    var android = previewOs === 'android';
    setText('showcase-kicker', android ? 'Also on desktop' : 'Preview');
    setText('showcase-title', android ? 'The same reader on your computer.' : 'A reader that stays out of the way.');
    setText('showcase-lead', android
      ? 'Take your reading to Windows, macOS and Linux with the same clean, private reader.'
      : 'Clean typography, fast scrolling and a night mode for every reader.');
    document.querySelectorAll('.os-switch button').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.getAttribute('data-os') === previewOs));
    });
  }

  function applyHeroStage() {
    var img = $('hero-desktop');
    var plat = os === 'android' || os === 'other' ? 'windows' : os;
    var prefix = SHOT_PREFIX[plat] || FALLBACK_PREFIX;
    loadImage(img, prefix, 'pdf', $('hero-note'), OS_NAME[plat] || 'desktop');
  }

  function bind() {
    document.querySelectorAll('.tab').forEach(function (tab) {
      tab.addEventListener('click', function () {
        document.querySelectorAll('.tab').forEach(function (t) { t.setAttribute('aria-selected', 'false'); });
        tab.setAttribute('aria-selected', 'true');
        shot = tab.getAttribute('data-shot');
        renderShowcase();
      });
    });
    document.querySelectorAll('.os-switch button').forEach(function (b) {
      b.addEventListener('click', function () { previewOs = b.getAttribute('data-os'); renderShowcase(); });
    });
  }

  applyHero();
  applyPlatforms();
  applyHeroStage();
  bind();
  renderShowcase();
})();
