/* OpenReader landing page: theme, OS-aware download button, device previews and screenshot tabs. */
(function () {
  'use strict';

  var PLAY = 'https://play.google.com/store/apps/details?id=com.chowdhuryelab.openreader';
  var RELEASES = 'https://github.com/macdipu/OpenReader/releases/latest';
  var OS_NAME = { android: 'Android', windows: 'Windows', macos: 'macOS', linux: 'Linux', ios: 'iOS' };

  var CTA = {
    android: { label: 'Download APK', href: RELEASES, note: 'Also on <a href="' + PLAY + '">Google Play</a>. Allow installs from your browser when asked.' },
    windows: { label: 'Download for Windows', href: RELEASES, note: 'Unsigned build: Windows SmartScreen may ask you to confirm. <a href="#platforms">Other platforms</a>' },
    macos: { label: 'Download for macOS', href: RELEASES, note: 'Unsigned build: on first launch right-click the app and choose Open. <a href="#platforms">Other platforms</a>' },
    linux: { label: 'Download for Linux', href: RELEASES, note: '.deb, .rpm or AppImage. <a href="#platforms">Other platforms</a>' },
    ios: { label: 'iOS: coming soon', href: '#platforms', note: 'There is no iOS app yet. OpenReader runs on Android, Windows, macOS and Linux.' },
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
    if (/iphone|ipad|ipod/.test(ua)) return 'ios';
    if (/win/.test(plat) || /windows/.test(ua)) return 'windows';
    if (/mac/.test(plat) || /macintosh|mac os x/.test(ua)) return 'macos';
    if (/linux|x11|cros/.test(plat + ua)) return 'linux';
    return 'other';
  }

  function initDownload() {
    var os = detect();
    var cta = CTA[os] || CTA.other;
    document.body.classList.add('os-' + os);
    initReleases(os);
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


  // ---- releases from GitHub: latest version, direct downloads, history ----
  var API = 'https://api.github.com/repos/macdipu/OpenReader/releases?per_page=30';
  var OS_FILES = {
    android: [/arm64-v8a.*\.apk$/i, /\.apk$/i],
    windows: [/\.exe$/i, /\.msi$/i, /windows.*\.zip$/i],
    macos: [/\.dmg$/i, /macos.*\.zip$/i],
    linux: [/\.appimage$/i, /\.deb$/i, /\.rpm$/i, /linux.*\.tar\.gz$/i]
  };
  var LINUX_KINDS = [
    { re: /\.deb$/i, label: '.deb', hint: 'Ubuntu, Debian, Linux Mint, Pop!_OS' },
    { re: /\.rpm$/i, label: '.rpm', hint: 'Fedora, RHEL, openSUSE' },
    { re: /\.appimage$/i, label: 'AppImage', hint: 'Any distribution, no install' },
    { re: /linux.*\.tar\.gz$/i, label: '.tar.gz', hint: 'Manual install' }
  ];

  function esc(t) { return String(t).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function fmtDate(iso) { try { return new Date(iso).toLocaleDateString('en', { year: 'numeric', month: 'short', day: 'numeric' }); } catch (e) { return ''; } }
  function fmtSize(n) { return n >= 1048576 ? (n / 1048576).toFixed(1) + ' MB' : Math.max(1, Math.round(n / 1024)) + ' KB'; }
  function fileRow(a) { return '<a href="' + esc(a.browser_download_url) + '"><span>' + esc(a.name) + '</span><em>' + fmtSize(a.size) + '</em></a>'; }

  function loadReleases(cb) {
    try {
      var hit = JSON.parse(sessionStorage.getItem('openreader-releases') || 'null');
      if (hit && Date.now() - hit.t < 600000) return cb(hit.d);
    } catch (e) { /* no storage */ }
    fetch(API, { headers: { Accept: 'application/vnd.github+json' } })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (list) {
        var d = list.filter(function (r) { return !r.draft && !r.prerelease; });
        try { sessionStorage.setItem('openreader-releases', JSON.stringify({ t: Date.now(), d: d })); } catch (e) { /* ignore */ }
        cb(d);
      })
      .catch(function () { /* keep the static page: links go to the releases page */ });
  }

  // Newest release that has a file for this platform (a platform can lag behind the latest tag).
  function find(rels, os, patterns) {
    patterns = patterns || OS_FILES[os];
    for (var i = 0; i < rels.length; i++) {
      for (var p = 0; p < patterns.length; p++) {
        for (var j = 0; j < rels[i].assets.length; j++) {
          if (patterns[p].test(rels[i].assets[j].name)) return { rel: rels[i], asset: rels[i].assets[j] };
        }
      }
    }
    return null;
  }
  function listFor(rel, os) {
    return rel.assets.filter(function (a) { return OS_FILES[os].some(function (re) { return re.test(a.name); }); });
  }

  // Browsers rarely name the Linux distro; Firefox and some Chromium builds do.
  function linuxFamily() {
    var ua = (navigator.userAgent || '').toLowerCase();
    if (/ubuntu|debian|mint|pop!?_?os|elementary|kali|raspbian|zorin/.test(ua)) return 'deb';
    if (/fedora|red hat|rhel|centos|suse|rocky|alma|nobara/.test(ua)) return 'rpm';
    return null;
  }

  function openLinuxPicker(rels) {
    var dlg = $('linux-pick');
    if (!dlg || typeof dlg.showModal !== 'function') return false;
    var latest = find(rels, 'linux');
    if (!latest) return false;
    var rows = LINUX_KINDS.map(function (k) {
      var hit = find([latest.rel], 'linux', [k.re]);
      return hit ? '<a href="' + esc(hit.asset.browser_download_url) + '"><b>' + k.label + '</b><span>' + k.hint + '</span><em>' + fmtSize(hit.asset.size) + '</em></a>' : '';
    }).join('');
    $('linux-pick-body').innerHTML = rows;
    $('linux-pick-ver').textContent = latest.rel.tag_name;
    dlg.showModal();
    return true;
  }

  function initReleases(os) {
    loadReleases(function (rels) {
      if (!rels.length) return;
      var latest = rels[0];

      var cta = $('cta-primary'), label = $('cta-label'), line = $('release-line');
      var extra = '';

      if (os === 'ios') {
        cta.removeAttribute('href'); cta.classList.add('soon'); cta.setAttribute('aria-disabled', 'true');
        label.textContent = 'iOS: coming soon';
      } else if (os === 'linux') {
        var fam = linuxFamily();
        var hit = fam ? find(rels, 'linux', [fam === 'deb' ? /\.deb$/i : /\.rpm$/i]) : null;
        if (hit) {
          cta.href = hit.asset.browser_download_url;
          label.textContent = 'Download ' + (fam === 'deb' ? '.deb' : '.rpm') + ' for Linux';
          extra = ' · <a href="#" data-pick>Other distro?</a>';
        } else {
          label.textContent = 'Download for Linux';
          cta.href = '#linux-pick';
          cta.addEventListener('click', function (e) { if (openLinuxPicker(rels)) e.preventDefault(); });
        }
      } else if (OS_FILES[os]) {
        var f = find(rels, os);
        if (f) {
          cta.href = f.asset.browser_download_url;
          label.textContent = 'Download for ' + OS_NAME[os] + ' (' + (f.asset.name.match(/\.[a-z0-9]+$/i) || [''])[0] + ')';
          if (f.rel !== latest) extra = ' · ' + OS_NAME[os] + ' file is from ' + esc(f.rel.tag_name);
        } else {
          $('cta-note').innerHTML = 'No ' + OS_NAME[os] + ' installer is published yet. <a href="' + latest.html_url + '">See the release</a>.';
        }
      }
      line.innerHTML = 'Latest: <b>' + esc(latest.tag_name) + '</b> · ' + fmtDate(latest.published_at) + extra + ' · <a href="#history">All versions</a>';
      line.hidden = false;
      line.querySelectorAll('[data-pick]').forEach(function (el) { el.addEventListener('click', function (e) { e.preventDefault(); openLinuxPicker(rels); }); });

      // per-platform cards: real files, newest release that has them
      document.querySelectorAll('.platform').forEach(function (card) {
        var key = card.getAttribute('data-os');
        if (!OS_FILES[key]) return;
        var hit = find(rels, key);
        var box = document.createElement('div');
        box.className = 'assets';
        box.innerHTML = hit
          ? '<small>' + esc(hit.rel.tag_name) + ' · ' + fmtDate(hit.rel.published_at) + '</small>' + listFor(hit.rel, key).map(fileRow).join('')
          : '<p>No ' + esc(OS_NAME[key]) + ' file has been published yet.</p>';
        var btn = card.querySelector('.btn');
        card.insertBefore(box, btn);
        if (!hit) return;
        if (key === 'linux') {
          btn.textContent = 'Choose a Linux package';
          btn.setAttribute('href', '#linux-pick');
          btn.addEventListener('click', function (e) { if (openLinuxPicker(rels)) e.preventDefault(); });
        } else {
          var main = find(rels, key);
          btn.href = main.asset.browser_download_url;
          btn.textContent = 'Download ' + (main.asset.name.match(/\.[a-z0-9]+$/i) || [''])[0] + ' for ' + OS_NAME[key];
        }
      });

      // history
      $('history-list').innerHTML = rels.map(function (r, i) {
        return '<details' + (i === 0 ? ' open' : '') + '><summary><b>' + esc(r.tag_name) + '</b>' + (i === 0 ? '<i>Latest</i>' : '') +
          '<span>' + fmtDate(r.published_at) + '</span></summary><div class="files-list">' + r.assets.map(fileRow).join('') +
          '<a class="notes" href="' + esc(r.html_url) + '">Release notes on GitHub →</a></div></details>';
      }).join('');
      $('history').hidden = false;
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
    var items = document.querySelectorAll('.section-head, .lineup, .tile, .platform, .privacy-band, .showcase-grid > *, .split > *, .window, .faq');
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
