/* OpenReader landing page: theme, OS-aware download button, device previews and screenshot tabs. */
(function () {
  'use strict';

  var PLAY = 'https://play.google.com/store/apps/details?id=com.chowdhuryelab.openreader';
  var RELEASES = 'https://github.com/macdipu/OpenReader/releases/latest';
  var OS_NAME = { android: 'Android', windows: 'Windows', macos: 'macOS', linux: 'Linux', ios: 'iOS' };

  var CTA = {
    android: { label: 'Get it on Google Play', href: PLAY, note: '' },
    windows: { label: 'Download for Windows', href: RELEASES, note: '' },
    macos: { label: 'Download for macOS', href: RELEASES, note: '' },
    linux: { label: 'Download for Linux', href: RELEASES, note: '' },
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
  var REPO_API = 'https://api.github.com/repos/macdipu/OpenReader';
  var RELEASES_PAGE = 'https://github.com/macdipu/OpenReader/releases';
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
  var FRIENDLY = [
    [/\.exe$/i, 'Installer (.exe), Windows 64-bit'],
    [/\.msi$/i, 'Installer (.msi), Windows'],
    [/windows.*\.zip$/i, 'ZIP, Windows portable'],
    [/\.dmg$/i, 'DMG, macOS'],
    [/macos.*\.zip$/i, 'ZIP, macOS'],
    [/arm64-v8a.*\.apk$/i, 'APK, arm64 (most phones)'],
    [/armeabi-v7a.*\.apk$/i, 'APK, armeabi-v7a (older phones)'],
    [/\.apk$/i, 'APK, Android'],
    [/\.aab$/i, 'AAB, Play Store bundle'],
    [/\.deb$/i, '.deb, Ubuntu / Debian / Mint (x64)'],
    [/\.rpm$/i, '.rpm, Fedora / RHEL / openSUSE'],
    [/\.appimage$/i, 'AppImage, any distro'],
    [/\.tar\.gz$/i, '.tar.gz, manual install']
  ];

  function esc(t) { return String(t).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function fmtDate(iso) { try { return new Date(iso).toLocaleDateString('en', { year: 'numeric', month: 'short', day: 'numeric' }); } catch (e) { return ''; } }
  function fmtSize(n) { return n >= 1048576 ? (n / 1048576).toFixed(1) + ' MB' : Math.max(1, Math.round(n / 1024)) + ' KB'; }
  function friendly(name) { for (var i = 0; i < FRIENDLY.length; i++) { if (FRIENDLY[i][0].test(name)) return FRIENDLY[i][1]; } return name; }
  // GitHub reports "sha256:<hex>" for each asset; show it only when it is really there.
  function sumOf(a) { return a.digest && /^sha256:[0-9a-f]{64}$/i.test(a.digest) ? a.digest.slice(7) : ''; }
  function fileRow(a) {
    var sum = sumOf(a);
    return '<div class="frow"><a class="dl" href="' + esc(a.browser_download_url) + '"><span class="fl"><b>' + esc(friendly(a.name)) + '</b><small>' + esc(a.name) + '</small>' +
      (sum ? '<small>SHA-256 ' + sum.slice(0, 16) + '…</small>' : '') + '</span><em>' + fmtSize(a.size) + '</em></a>' +
      (sum ? '<button class="sumbtn" type="button" data-sum="' + sum + '" title="SHA-256 ' + sum + '" aria-label="Copy hash: SHA-256 checksum of ' + esc(a.name) + '">Copy hash</button>' : '') + '</div>';
  }

  function loadJson(url, key, ttl, cb, filter) {
    try {
      var hit = JSON.parse(sessionStorage.getItem(key) || 'null');
      if (hit && Date.now() - hit.t < ttl) return cb(hit.d);
    } catch (e) { /* no storage */ }
    fetch(url, { headers: { Accept: 'application/vnd.github+json' } })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (data) {
        var d = filter ? filter(data) : data;
        try { sessionStorage.setItem(key, JSON.stringify({ t: Date.now(), d: d })); } catch (e) { /* ignore */ }
        cb(d);
      })
      .catch(function () { /* offline or rate limited: the static page stays as it is */ });
  }
  function loadReleases(cb) {
    loadJson(API, 'openreader-releases', 600000, cb, function (list) { return list.filter(function (r) { return !r.draft && !r.prerelease; }); });
  }

  // Newest release that has a file for this platform (a platform can lag behind the latest tag).
  function find(rels, os, patterns) {
    patterns = patterns || OS_FILES[os];
    for (var i = 0; i < rels.length; i++) {
      for (var p = 0; p < patterns.length; p++) {
        for (var k = 0; k < rels[i].assets.length; k++) {
          if (patterns[p].test(rels[i].assets[k].name)) return { rel: rels[i], asset: rels[i].assets[k] };
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
    $('linux-pick-body').innerHTML = LINUX_KINDS.map(function (k) {
      var hit = find([latest.rel], 'linux', [k.re]);
      return hit ? '<a href="' + esc(hit.asset.browser_download_url) + '"><b>' + k.label + '</b><span>' + k.hint + '</span><em>' + fmtSize(hit.asset.size) + '</em></a>' : '';
    }).join('');
    $('linux-pick-ver').textContent = latest.rel.tag_name;
    dlg.showModal();
    return true;
  }

  function initReleases(os) {
    loadReleases(function (rels) {
      if (!rels.length) return;
      var latest = rels[0];
      var cta = $('cta-primary'), label = $('cta-label'), line = $('release-line'), note = $('cta-note');
      var extra = '';

      // No file for this platform: say so instead of a download button that leads nowhere.
      function missing() {
        cta.href = RELEASES_PAGE;
        label.textContent = 'View releases on GitHub';
        var others = ['android', 'macos', 'windows', 'linux'].filter(function (k) { return k !== os && find(rels, k); });
        note.innerHTML = OS_NAME[os] + ' downloads are not published yet.' + (others.length
          ? ' Available now: ' + others.map(function (k) { return '<a href="#platforms">' + OS_NAME[k] + '</a>'; }).join(', ') + '.' : '');
      }

      if (os === 'ios') {
        cta.removeAttribute('href'); cta.classList.add('soon'); cta.setAttribute('aria-disabled', 'true');
        label.textContent = 'iOS: coming soon';
      } else if (os === 'linux') {
        var fam = linuxFamily();
        var any = find(rels, 'linux');
        var hit = fam ? find(rels, 'linux', [fam === 'deb' ? /\.deb$/i : /\.rpm$/i]) : null;
        if (!any) {
          missing();
        } else if (hit) {
          cta.href = hit.asset.browser_download_url;
          label.textContent = 'Download ' + (fam === 'deb' ? '.deb' : '.rpm') + ' for Linux';
          extra = ' (<a href="#" data-pick>other distro?</a>)';
        } else {
          label.textContent = 'Download for Linux';
          cta.href = '#linux-pick';
          cta.addEventListener('click', function (e) { if (openLinuxPicker(rels)) e.preventDefault(); });
        }
      } else if (os === 'android') {
        var apk = find(rels, 'android');
        if (apk) note.innerHTML = 'Or <a href="' + esc(apk.asset.browser_download_url) + '">download the APK</a> (' + esc(friendly(apk.asset.name).replace('APK, ', '')) + ', ' + fmtSize(apk.asset.size) + '). Allow installs from your browser when asked.';
      } else if (OS_FILES[os]) {
        var f = find(rels, os);
        if (!f) {
          missing();
        } else {
          cta.href = f.asset.browser_download_url;
          label.textContent = 'Download for ' + OS_NAME[os] + ' (' + (f.asset.name.match(/\.[a-z0-9]+$/i) || [''])[0] + ')';
          if (f.rel !== latest) extra = '; the ' + OS_NAME[os] + ' file is from ' + esc(f.rel.tag_name);
          if (os === 'windows') note.innerHTML = 'Unsigned build: SmartScreen may ask you to confirm. <a href="#win-why" data-open="win-why">Why this warning?</a>';
          if (os === 'macos') note.textContent = 'Unsigned build: on first launch right-click the app and choose Open.';
        }
      }
      line.innerHTML = 'Latest version <b>' + esc(latest.tag_name) + '</b>, released ' + fmtDate(latest.published_at) + extra + '. <a href="#history">See all versions</a>';
      line.hidden = false;
      line.querySelectorAll('[data-pick]').forEach(function (el) { el.addEventListener('click', function (e) { e.preventDefault(); openLinuxPicker(rels); }); });

      // availability badge under each device in the lineup
      document.querySelectorAll('.badge[data-for]').forEach(function (b) {
        var ok = b.getAttribute('data-for') === 'android' || !!find(rels, b.getAttribute('data-for'));
        b.textContent = ok ? 'Available' : 'Coming soon';
        b.className = 'badge ' + (ok ? 'ok' : 'soon');
        b.hidden = false;
      });

      // per-platform cards: real files, newest release that has them
      document.querySelectorAll('.platform').forEach(function (card) {
        var key = card.getAttribute('data-os');
        if (!OS_FILES[key]) return;
        var hit = find(rels, key);
        var btn = card.querySelector('.btn');
        var box = document.createElement('div');
        box.className = 'assets';
        var files = hit ? listFor(hit.rel, key) : [];
        box.innerHTML = hit
          ? '<small>' + esc(hit.rel.tag_name) + ', ' + fmtDate(hit.rel.published_at) + '</small>' + files.map(fileRow).join('')
          : '<p>No ' + esc(OS_NAME[key]) + ' file has been published yet.</p>';
        card.insertBefore(box, card.querySelector('details.cli') || btn);

        if (key === 'android') {   // Google Play is the main button; the APK is the fallback line
          if (hit) {
            var alt = document.createElement('p');
            alt.className = 'alt';
            alt.innerHTML = 'Or download the <a href="' + esc(hit.asset.browser_download_url) + '">APK</a> directly';
            btn.insertAdjacentElement('afterend', alt);
          }
          return;
        }
        if (!hit) {   // nothing to download: a plain link to the releases page, not a primary button
          btn.href = RELEASES_PAGE; btn.textContent = 'View releases on GitHub';
          btn.classList.remove('primary'); btn.classList.add('ghost');
          return;
        }
        card.querySelectorAll('.when-asset').forEach(function (el) { el.hidden = false; });
        card.querySelectorAll('[data-fill="win-name"]').forEach(function (el) { el.textContent = hit.asset.name; });
        if (files.some(sumOf)) card.querySelectorAll('[data-sum-note]').forEach(function (el) { el.hidden = false; });
        if (key === 'linux') {
          btn.textContent = 'Choose a Linux package';
          btn.setAttribute('href', '#linux-pick');
          btn.addEventListener('click', function (e) { if (openLinuxPicker(rels)) e.preventDefault(); });
        } else {
          btn.href = hit.asset.browser_download_url;
          btn.textContent = 'Download ' + (hit.asset.name.match(/\.[a-z0-9]+$/i) || [''])[0] + ' for ' + OS_NAME[key];
        }
      });

      // history: collapsed list, latest release open once expanded
      $('history-list').innerHTML = rels.map(function (r, i) {
        return '<details' + (i === 0 ? ' open' : '') + '><summary><b>' + esc(r.tag_name) + '</b>' + (i === 0 ? '<i>Latest</i>' : '') +
          '<span>' + fmtDate(r.published_at) + ', ' + r.assets.length + ' files</span></summary><div class="files-list">' + r.assets.map(fileRow).join('') +
          '<a class="notes" href="' + esc(r.html_url) + '">Read the release notes on GitHub</a></div></details>';
      }).join('');
      $('history-count').textContent = '(' + rels.length + ')';
      $('history').hidden = false;
      document.querySelectorAll('a[href="#history"]').forEach(function (a) { a.addEventListener('click', function () { $('history').open = true; }); });

      initProof(rels);
    });
  }

  // Stars and download counts come straight from the GitHub API; items that are zero or missing are left out.
  function initProof(rels) {
    var box = $('proof');
    if (!box) return;
    function sum(list) { return list.reduce(function (n, r) { return n + r.assets.reduce(function (m, a) { return m + (a.download_count || 0); }, 0); }, 0); }
    loadJson(REPO_API, 'openreader-repo', 600000, function (repo) {
      var items = [];
      if (repo && repo.stargazers_count > 0) items.push([repo.stargazers_count, 'GitHub stars']);
      var latest = sum(rels.slice(0, 1)), total = sum(rels);
      if (latest > 0) items.push([latest, 'downloads of ' + rels[0].tag_name]);
      if (total > latest) items.push([total, 'downloads across all releases']);
      if (!items.length) return;
      box.innerHTML = items.map(function (it) { return '<li><b>' + it[0].toLocaleString('en') + '</b> ' + it[1] + '</li>'; }).join('');
      box.hidden = false;
    });
  }

  // Copy buttons (install commands and checksums) and "Why this warning?" links.
  function initActions() {
    document.addEventListener('click', function (e) {
      var t = e.target.closest ? e.target.closest('[data-copy],[data-sum],[data-open]') : null;
      if (!t) return;
      if (t.hasAttribute('data-open')) {
        var el = $(t.getAttribute('data-open'));
        if (el) { el.open = true; }
        return;
      }
      var text = t.hasAttribute('data-sum') ? t.getAttribute('data-sum') : ($(t.getAttribute('data-copy')) || {}).textContent;
      if (!text) return;
      var done = function () { var old = t.textContent; t.textContent = 'Copied'; setTimeout(function () { t.textContent = old; }, 1500); };
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, function () { /* blocked */ });
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
      dev.querySelector('.devbtn').addEventListener('click', function () {
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

  // ---- screenshot showcase: tabs, arrows, gentle autoplay, lightbox ----------
  var SHOTS = {
    pdf: { file: 'Quarterly Report.pdf', desc: 'Continuous scroll, page thumbnails, zoom and jump to page.', alt: 'PDF reader' },
    docx: { file: 'Project Brief.docx', desc: 'Headings, lists, tables and images from .docx files.', alt: 'Word reader' },
    xlsx: { file: 'Sales 2026.xlsx', desc: 'Workbooks as scrollable tables, one tab per sheet.', alt: 'Excel reader' },
    'docx-dark': { file: 'Project Brief.docx', desc: 'Night mode: flip any document to a dark theme with one tap.', alt: 'Word reader in night mode' }
  };
  var DWELL = 6000;

  function initShowcase() {
    var img = $('showcase-img'), bar = $('shot-progress');
    var tabs = [].slice.call(document.querySelectorAll('.chips .tab'));
    if (!img || !tabs.length) return;
    var idx = 0, timer = null, auto = true, visible = false;
    var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    function runBar() {
      bar.classList.remove('run'); void bar.offsetWidth;
      if (auto && visible && !reduce) { bar.style.setProperty('--dur', DWELL + 'ms'); bar.classList.add('run'); }
    }
    function show(i) {
      idx = (i + tabs.length) % tabs.length;
      var key = tabs[idx].getAttribute('data-shot'), d = SHOTS[key];
      tabs.forEach(function (t, k) { t.setAttribute('aria-selected', k === idx ? 'true' : 'false'); t.tabIndex = k === idx ? 0 : -1; });
      img.style.opacity = '0.25';
      img.onload = function () { img.style.opacity = '1'; };
      img.src = 'assets/screens/desktop-' + key + '.png';
      img.alt = 'OpenReader ' + d.alt + ' on Windows';
      $('shot-title').textContent = d.file;
      $('shot-desc').textContent = d.desc;
      runBar();
      schedule();
    }
    function schedule() {
      clearTimeout(timer);
      if (auto && visible && !reduce) timer = setTimeout(function () { show(idx + 1); }, DWELL);
    }
    function take(i) { auto = false; show(i); }   // the visitor took over: stop cycling

    tabs.forEach(function (t, i) { t.addEventListener('click', function () { take(i); }); });
    $('shot-prev').addEventListener('click', function () { take(idx - 1); });
    $('shot-next').addEventListener('click', function () { take(idx + 1); });
    // Arrow keys move between tabs, as in a native tab list.
    $('panel').parentNode.querySelector('.chips').addEventListener('keydown', function (e) {
      var to = { ArrowRight: idx + 1, ArrowLeft: idx - 1, Home: 0, End: tabs.length - 1 }[e.key];
      if (to === undefined) return;
      e.preventDefault(); take(to); tabs[idx].focus();
    });
    tabs.forEach(function (t, k) { t.tabIndex = k === 0 ? 0 : -1; });

    var panel = $('panel');
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (es) { visible = es[0].isIntersecting; runBar(); schedule(); }, { threshold: 0.4 }).observe(panel);
    }

    // Click the screenshot to see it full size.
    var box = $('lightbox');
    if (box && typeof box.showModal === 'function') {
      $('zoom').addEventListener('click', function () {
        $('lightbox-img').src = img.src; $('lightbox-img').alt = img.alt;
        box.showModal();
      });
      box.addEventListener('click', function (e) { if (e.target === box) box.close(); });
    }
  }

  // ---- reveal on scroll --------------------------------------------------
  function initReveal() {
    var items = document.querySelectorAll('.section-head, .lineup, .tile, .platform, .privacy-band, .showcase-grid > *, .split > *, .window, .faq');
    if (!('IntersectionObserver' in window)) return;
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('seen'); io.unobserve(e.target); } });
    }, { threshold: 0.01, rootMargin: '0px 0px -10% 0px' });
    items.forEach(function (el) { el.classList.add('in'); io.observe(el); });
  }

  // ---- header: shadow after scroll, highlight the section in view ----------
  function initHeader() {
    var hdr = document.querySelector('header.site'), top = $('to-top'), hero = document.querySelector('.hero');
    if (top) top.addEventListener('click', function () { window.scrollTo({ top: 0 }); });
    var links = [].slice.call(document.querySelectorAll('nav.site a[href^="#"]'));
    var map = links.map(function (a) { return { a: a, el: document.querySelector(a.getAttribute('href')) }; }).filter(function (m) { return m.el; });
    function onScroll() {
      hdr.classList.toggle('scrolled', window.scrollY > 8);
      if (top) top.hidden = window.scrollY < hero.offsetHeight * 0.9;
      var y = window.scrollY + 140, cur = map[0];
      map.forEach(function (m) { if (m.el.offsetTop <= y) cur = m; });
      map.forEach(function (m) { m.a.classList.toggle('active', m === cur); });
    }
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  initHeader();
  initActions();
  initTheme();
  initDownload();
  initDevices();
  initShowcase();
})();
