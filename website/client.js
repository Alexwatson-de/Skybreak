/* Public configuration only. Authentication tickets stay in the Godot client/sessionStorage. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const config = window.GODOT_CONFIG;
  const params = new URLSearchParams(location.search);
  window.Skybreak = {
    update(report) {
      const playing = ['match', 'results'].includes(report.phase);
      const status = playing ? `${report.status} · ${report.ping_ms} ms` : report.lobby_status !== 'OFFLINE' ? report.lobby_status : 'Ready to play';
      $('connection-summary').textContent = status;
      $('connection-light').classList.toggle('online', report.status.startsWith('CONNECTED') || report.lobby_status.startsWith('CONNECTED'));
      $('live-metrics').textContent = JSON.stringify(report, null, 2);
    }
  };
  $('fullscreen').addEventListener('click', () => {
    const action = document.fullscreenElement ? document.exitFullscreen() : $('stage').requestFullscreen();
    action?.catch(() => { $('connection-summary').textContent = 'Fullscreen unavailable in this browser'; });
  });
  $('diagnostics-toggle').addEventListener('click', () => {
    $('diagnostics').hidden = !$('diagnostics').hidden;
    $('diagnostics-toggle').setAttribute('aria-expanded', String(!$('diagnostics').hidden));
  });
  $('retry').addEventListener('click', () => location.reload());
  $('canvas').addEventListener('contextmenu', e => e.preventDefault());
  function failure(error) {
    console.error(error);
    $('load-message').textContent = `${error.message || error}. Please reload, or try a current desktop browser with WebGL 2 enabled.`;
    $('load-progress').hidden = true;
    $('retry').hidden = false;
    $('connection-summary').textContent = 'Unable to load the game';
  }
  async function start() {
    const response = await fetch('lobby.json', { cache: 'no-store' });
    if (!response.ok) throw new Error('The game configuration could not be loaded');
    const publicConfig = await response.json();
    const lobby = new URL(publicConfig.lobbyUrl);
    if (!['http:', 'https:'].includes(lobby.protocol)) throw new Error('Invalid game server configuration');
    if (location.protocol === 'https:' && lobby.protocol !== 'https:') throw new Error('Online play needs an HTTPS game server');
    const args = ['--', `--lobby=${lobby.origin}`];
    const code = params.get('room')?.toUpperCase();
    if (code && /^[A-Z2-9]{6}$/.test(code)) args.push(`--online=${lobby.origin}`, `--room=${code}`);
    for (const key of ['screen', 'map', 'mode']) if (params.has(key)) args.push(`--${key}=${params.get(key)}`);
    // Explicit local QA mode; not accepted by production exports.
    if (publicConfig.development) {
      for (const key of ['online', 'name', 'duration', 'drop-at', 'drop-lobby-at']) if (params.has(key)) args.push(`--${key}=${params.get(key)}`);
      for (const key of ['auto', 'demo', 'create', 'adversarial']) if (params.has(key)) args.push(`--${key}`);
    }
    config.args = args;
    config.canvasResizePolicy = 0;
    const canvas = $('canvas');
    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      const ratio = Math.min(devicePixelRatio || 1, 1.5);
      canvas.width = Math.round(rect.width * ratio);
      canvas.height = Math.round(rect.height * ratio);
    };
    resize();
    new ResizeObserver(resize).observe($('stage'));
    config.ensureCrossOriginIsolationHeaders = false;
    const missing = Engine.getMissingFeatures({ threads: false });
    if (missing.length) throw new Error(`Missing browser features: ${missing.join(', ')}`);
    $('server-message').textContent = 'Free multiplayer hosting may take about a minute to wake after inactivity. Refreshing a tab can resume its match while its server slot is still available.';
    const engine = new Engine(config);
    await engine.startGame({ onProgress(current, total) {
      if (total > 0) { $('load-progress').max = total; $('load-progress').value = current; }
      $('load-message').textContent = total > 0 ? `Loading game assets · ${Math.round(current / total * 100)}%` : 'Starting the game…';
    } });
    $('loader').hidden = true;
    $('connection-summary').textContent = 'Ready to play';
    $('canvas').focus();
  }
  start().catch(failure);
})();
