/* OpenReader landing page: scroll effects.
   - A thin progress line along the top.
   - Hero depth: as you scroll out of the hero the devices fan apart and lift at different speeds (CSS reads --p).
   - Pinned story: "Offline. Private. Fast." steps with the scroll position while a document frame crossfades.
   - Counters in the proof strip count up once.
   The depth and story effects need a desktop-wide window and are off under prefers-reduced-motion. */
(function () {
  'use strict';

  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var $ = function (s) { return document.querySelector(s); };
  var $$ = function (s) { return [].slice.call(document.querySelectorAll(s)); };
  var clamp = function (v, a, b) { return Math.max(a, Math.min(b, v)); };
  var wide = function () { return window.innerWidth >= 900; };

  var hero = $('.hero'), story = $('#story'), bar = $('.sprog i');
  var ticking = false;

  // Story: three words, one frame per word.
  var words = story ? [].slice.call(story.querySelectorAll('.sw')) : [];
  var shots = story ? [].slice.call(story.querySelectorAll('.story-frame img')) : [];
  var lastWord = -1;

  function storySpan() { return Math.max(1, story.offsetHeight - (window.innerHeight - 72)); }

  function update() {
    ticking = false;
    var y = window.scrollY;

    // progress line
    if (bar) {
      var max = document.documentElement.scrollHeight - window.innerHeight;
      bar.style.transform = 'scaleX(' + (max > 0 ? clamp(y / max, 0, 1) : 0).toFixed(4) + ')';
    }
    if (reduce || !wide()) return;

    // hero depth
    if (hero) hero.style.setProperty('--p', clamp(y / (hero.offsetHeight * 0.85), 0, 1).toFixed(4));

    // pinned story
    if (story) {
      var t = clamp((y - story.offsetTop + 72) / storySpan(), 0, 1);
      var idx = Math.min(words.length - 1, Math.floor(t * words.length));
      if (idx !== lastWord) {
        lastWord = idx;
        words.forEach(function (w, i) { w.classList.toggle('is-on', i === idx); w.classList.toggle('is-past', i < idx); });
        shots.forEach(function (s, i) { s.classList.toggle('is-on', i === idx); });
      }
    }

    // proof counters
    $$('#proof b').forEach(function (b) {
      if (b.getAttribute('data-counted') || b.getBoundingClientRect().top > window.innerHeight * 0.92) return;
      b.setAttribute('data-counted', '1');
      var end = parseInt(b.textContent.replace(/\D/g, ''), 10);
      if (!end) return;
      var t0 = performance.now(), dur = 1200;
      (function step(now) {
        var k = clamp((now - t0) / dur, 0, 1), e = 1 - Math.pow(1 - k, 3);
        b.textContent = Math.round(end * e).toLocaleString('en');
        if (k < 1) requestAnimationFrame(step);
      })(t0);
    });
  }

  function request() { if (!ticking) { ticking = true; requestAnimationFrame(update); } }
  window.addEventListener('scroll', request, { passive: true });
  window.addEventListener('resize', request);
  update();
})();
