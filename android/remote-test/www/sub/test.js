// Abre ws://<mismo host>/ws, mide 200 idas y vueltas (ping→eco) y deja el resultado en window.result.
(function () {
  const log = document.getElementById('log');
  const N = 200;
  const rtts = [];
  const ws = new WebSocket('ws://' + location.host + '/ws');
  window.result = null;
  function next() {
    ws.send(JSON.stringify({ t: 'ping', at: performance.now(), i: rtts.length }));
  }
  ws.onopen = function () { log.textContent = 'abierto'; next(); };
  ws.onmessage = function (ev) {
    const m = JSON.parse(ev.data);
    rtts.push(performance.now() - m.at);
    if (rtts.length < N) { next(); return; }
    const s = rtts.slice().sort(function (a, b) { return a - b; });
    window.result = {
      ok: true,
      n: s.length,
      median: s[Math.floor(s.length / 2)],
      p95: s[Math.floor(s.length * 0.95)],
      max: s[s.length - 1],
      cssLoaded: getComputedStyle(document.body).backgroundColor,
    };
    log.textContent = JSON.stringify(window.result);
    ws.close(1000, 'listo');
  };
  ws.onerror = function () { window.result = { ok: false, error: 'ws error' }; };
})();
