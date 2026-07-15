const { app, BrowserWindow, ipcMain, Menu, Tray, nativeImage, nativeTheme } = require('electron');
const { execFileSync, spawn } = require('node:child_process');
const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');
const { APP_NAME, LOG_PREFIX, quitLabel } = require('./shared/branding');
const versionInfo = require('./shared/version');

/** Opaque fallback when vibrancy is unavailable. */
function windowBackgroundColor() {
  return nativeTheme.shouldUseDarkColors ? '#000000' : '#ffffff';
}

function applyWindowTheme() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  if (process.platform === 'darwin') {
    // Keep vibrancy so the transparent sidebar shows real frosted glass.
    try {
      mainWindow.setVibrancy('sidebar');
      mainWindow.setBackgroundColor('#00000000');
    } catch {
      mainWindow.setBackgroundColor(windowBackgroundColor());
    }
    return;
  }
  mainWindow.setBackgroundColor(windowBackgroundColor());
}

const nativeHost = '127.0.0.1';
const nativePort = 43821;
const defaultNativeApp = '/tmp/MacInputDerived/Build/Products/Debug/MacInput.app';
/** Max time to wait for a graceful native shutdown before force-killing. */
const NATIVE_SHUTDOWN_MS = 2500;

let mainWindow;
let tray;
let pollTimer;
let isQuitting = false;
let isShuttingDown = false;
let nativeShutdownComplete = false;
/** @type {import('node:child_process').ChildProcess | null} */
let nativeHelper = null;
/** Tracked PID of the MacInput --electron-helper process. */
let nativeHelperPid = null;
/** @type {ReturnType<typeof offlineStatus> | null} */
let lastTrayStatus = null;
/** Last menu signature — avoid rebuilding while the user is interacting. */
let lastTrayMenuKey = '';

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function pidAlive(pid) {
  if (!pid || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function forceKillPid(pid, signal = 'SIGTERM') {
  if (!pid || pid <= 0 || pid === process.pid) return false;
  try {
    // Signal 0 is existence check only; real signals should still be attempted
    // even if pidAlive briefly races.
    process.kill(pid, signal);
    return true;
  } catch {
    return false;
  }
}

/**
 * PIDs of native helpers launched with --electron-helper.
 * Uses `ps` (not pgrep -f) so this is reliable inside Electron and on process exit.
 */
function listElectronHelperPids() {
  try {
    const out = execFileSync('/bin/ps', ['-ax', '-o', 'pid=,command='], {
      encoding: 'utf8',
      timeout: 1000
    });
    const pids = [];
    for (const line of out.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      const space = trimmed.indexOf(' ');
      if (space === -1) continue;
      const pid = Number(trimmed.slice(0, space));
      const cmd = trimmed.slice(space + 1);
      if (!Number.isFinite(pid) || pid <= 0 || pid === process.pid) continue;
      // Match helper only — never the standalone menu-bar MacInput without the flag.
      if (cmd.includes('MacInput') && cmd.includes('--electron-helper')) {
        pids.push(pid);
      }
    }
    return pids;
  } catch {
    return [];
  }
}

/** Synchronous hard teardown — safe in signal / process.exit handlers. */
function killElectronHelpersSync() {
  const pids = new Set(listElectronHelperPids());
  if (nativeHelperPid) pids.add(nativeHelperPid);
  for (const pid of pids) {
    forceKillPid(pid, 'SIGTERM');
  }
  // Immediate SIGKILL follow-up so nothing is left spinning.
  for (const pid of pids) {
    forceKillPid(pid, 'SIGKILL');
  }
  if (nativeHelper) {
    try { nativeHelper.kill('SIGKILL'); } catch { /* ignore */ }
  }
  nativeHelper = null;
  nativeHelperPid = null;
}

function killElectronHelpers(exceptPid = null) {
  for (const pid of listElectronHelperPids()) {
    if (exceptPid && pid === exceptPid) continue;
    forceKillPid(pid, 'SIGTERM');
  }
}

async function waitForPidExit(pid, timeoutMs) {
  if (!pid) return true;
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!pidAlive(pid)) return true;
    await sleep(50);
  }
  return !pidAlive(pid);
}

function refreshTrackedHelperPid() {
  const pids = listElectronHelperPids();
  if (pids.length === 0) return;
  // Prefer the most recently started helper.
  nativeHelperPid = pids[pids.length - 1];
}

function resolveNativeAppPath() {
  const packagedNativeApp = path.join(process.resourcesPath, 'native', 'MacInput.app');
  return process.env.MAC_INPUT_NATIVE_APP
    || (app.isPackaged ? packagedNativeApp : defaultNativeApp);
}

function resolveNativeBinary(nativeApp) {
  return path.join(nativeApp, 'Contents', 'MacOS', 'MacInput');
}

function requestNative(command, payload = {}) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: nativeHost, port: nativePort });
    let buffer = '';
    const timeout = setTimeout(() => {
      socket.destroy();
      reject(new Error('Native service timed out'));
    }, 1500);

    socket.setEncoding('utf8');
    socket.once('connect', () => {
      socket.write(`${JSON.stringify({ command, ...payload })}\n`);
    });
    socket.on('data', (chunk) => {
      buffer += chunk;
      const newline = buffer.indexOf('\n');
      if (newline === -1) return;

      clearTimeout(timeout);
      socket.end();
      try {
        resolve(JSON.parse(buffer.slice(0, newline)));
      } catch (error) {
        reject(error);
      }
    });
    socket.once('error', (error) => {
      clearTimeout(timeout);
      reject(error);
    });
  });
}

function offlineStatus(error) {
  return {
    type: 'status',
    status: 'backendOffline',
    statusText: '原生 BLE 服务未启动',
    isAdvertising: false,
    isSubscribed: false,
    canSendA: false,
    lastReportHex: '',
    capsLock: false,
    routingMode: 'off',
    routingModeTitle: '关闭',
    error: error?.message || ''
  };
}

async function publishStatus() {
  let status;
  try {
    status = await requestNative('getStatus');
  } catch (error) {
    status = offlineStatus(error);
  }
  updateTray(status);
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('native:status', status);
  }
}

function launchNativeBackend() {
  // Drop orphans from previous sessions so they cannot pile up on CPU/RAM/port 43821.
  killElectronHelpersSync();

  const nativeApp = resolveNativeAppPath();
  const binary = resolveNativeBinary(nativeApp);
  if (!fs.existsSync(binary)) {
    console.warn(`[${LOG_PREFIX}] Native helper not found: ${binary}`);
    return;
  }

  // Spawn the binary directly (not `open -n`) so we own the PID and can kill it on quit.
  const child = spawn(binary, ['--electron-helper'], {
    detached: true,
    stdio: 'ignore'
  });
  nativeHelper = child;
  nativeHelperPid = child.pid || null;
  // Debug stub executors may re-exec; re-resolve the real helper PID shortly after launch.
  setTimeout(refreshTrackedHelperPid, 300);
  setTimeout(refreshTrackedHelperPid, 1000);
  child.once('exit', (code, signal) => {
    // Only clear tracking if no other helper is still alive (stub may exit early).
    if (nativeHelper === child) {
      nativeHelper = null;
    }
    refreshTrackedHelperPid();
    if (!listElectronHelperPids().length) {
      nativeHelperPid = null;
    }
    if (code || signal) {
      console.warn(`[${LOG_PREFIX}] Native helper exited code=${code} signal=${signal}`);
    }
  });
  child.once('error', (error) => {
    console.warn(`[${LOG_PREFIX}] Failed to launch native helper:`, error.message);
    if (nativeHelper === child) {
      nativeHelper = null;
      nativeHelperPid = null;
    }
  });
  // Keep the child referenced until quit so we can signal it; do not unref.
}

/**
 * Graceful native teardown, then hard kill if anything remains.
 * Safe to call multiple times.
 */
async function stopNativeBackend() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = undefined;
  }

  refreshTrackedHelperPid();

  // Ask helper to clean BLE / event taps and exit.
  try {
    await requestNative('shutdown');
  } catch {
    // Offline or already gone — fall through to force-kill.
  }

  const trackedPids = new Set(listElectronHelperPids());
  if (nativeHelperPid) trackedPids.add(nativeHelperPid);

  for (const pid of trackedPids) {
    const exited = await waitForPidExit(pid, NATIVE_SHUTDOWN_MS);
    if (!exited) {
      forceKillPid(pid, 'SIGTERM');
      if (!(await waitForPidExit(pid, 600))) {
        forceKillPid(pid, 'SIGKILL');
      }
    }
  }

  // Final sweep — never leave helpers behind.
  killElectronHelpersSync();
}

function destroyUiShell() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = undefined;
  }
  if (tray) {
    try { tray.destroy(); } catch { /* ignore */ }
    tray = undefined;
  }
  if (mainWindow && !mainWindow.isDestroyed()) {
    try {
      mainWindow.removeAllListeners('close');
      mainWindow.destroy();
    } catch { /* ignore */ }
  }
  mainWindow = undefined;
}

function trayIcon() {
  // Base name `trayTemplate.png` + sibling `trayTemplate@2x.png` for Retina.
  // Filename ending in "Template" also helps macOS treat it as a template image.
  const file = path.join(__dirname, 'assets', 'trayTemplate.png');
  if (fs.existsSync(file)) {
    const image = nativeImage.createFromPath(file);
    if (!image.isEmpty()) {
      // Adapt to light/dark menu bar automatically on macOS.
      image.setTemplateImage(true);
      return image;
    }
  }
  // Minimal 16×16 black square if assets are missing
  const png = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAFUlEQVQ4T2NkYGD4z0ABYBw1gGE0DAB9+wX9k8sL2wAAAABJRU5ErkJggg==',
    'base64'
  );
  const fallback = nativeImage.createFromBuffer(png);
  fallback.setTemplateImage(true);
  return fallback;
}

function toggleMainWindow() {
  if (!mainWindow || mainWindow.isDestroyed()) {
    createWindow();
    return;
  }
  if (mainWindow.isVisible()) {
    mainWindow.hide();
  } else {
    mainWindow.show();
    mainWindow.focus();
  }
}

function showMainWindow() {
  if (!mainWindow || mainWindow.isDestroyed()) {
    createWindow();
    return;
  }
  mainWindow.show();
  mainWindow.focus();
}

function buildTrayMenu(status) {
  const mode = status.routingMode || 'off';
  const modeTitle = status.routingModeTitle || '关闭';
  const connected = status.status === 'connected' || status.isSubscribed;
  const line2 = connected
    ? `已连接 · ${modeTitle}`
    : (status.isAdvertising ? '等待 iPhone 配对' : '未在等待配对');

  return Menu.buildFromTemplate([
    { label: APP_NAME, enabled: false },
    { label: status.statusText || line2, enabled: false },
    { type: 'separator' },
    { label: '显示窗口', click: () => showMainWindow() },
    {
      label: status.isAdvertising ? '停止等待配对' : '开始等待配对',
      click: async () => {
        try {
          await requestNative(status.isAdvertising ? 'stopAdvertising' : 'startAdvertising');
        } catch (_) { /* offline */ }
        publishStatus();
      }
    },
    { type: 'separator' },
    { label: '输入模式', enabled: false },
    {
      label: '关闭',
      type: 'radio',
      checked: mode === 'off',
      click: async () => {
        try { await requestNative('setRoutingMode', { mode: 'off' }); } catch (_) {}
        publishStatus();
      }
    },
    {
      label: '镜像输入',
      type: 'radio',
      checked: mode === 'mirror',
      click: async () => {
        try { await requestNative('setRoutingMode', { mode: 'mirror' }); } catch (_) {}
        publishStatus();
      }
    },
    {
      label: '独占输入',
      type: 'radio',
      checked: mode === 'exclusive',
      click: async () => {
        try { await requestNative('setRoutingMode', { mode: 'exclusive' }); } catch (_) {}
        publishStatus();
      }
    },
    { type: 'separator' },
    {
      label: quitLabel('zh-CN'),
      click: () => {
        isQuitting = true;
        app.quit();
      }
    }
  ]);
}

function trayMenuKey(status) {
  return [
    status.status,
    status.statusText,
    status.isAdvertising,
    status.isSubscribed,
    status.routingMode,
    status.routingModeTitle
  ].join('|');
}

function popupTrayMenu(bounds) {
  if (!tray) return;
  const status = lastTrayStatus || offlineStatus();
  const menu = buildTrayMenu(status);
  // Keep context menu in sync so platform click behavior is consistent.
  tray.setContextMenu(menu);
  if (bounds) {
    tray.popUpContextMenu(menu, bounds);
  } else {
    tray.popUpContextMenu(menu);
  }
}

function createTray() {
  tray = new Tray(trayIcon());
  tray.setToolTip(APP_NAME);
  tray.setIgnoreDoubleClickEvents(true);

  // Click (left or right) opens the status menu — not the main window.
  tray.on('click', (_event, bounds) => popupTrayMenu(bounds));
  tray.on('right-click', (_event, bounds) => popupTrayMenu(bounds));

  updateTray(offlineStatus());
}

function updateTray(status) {
  if (!tray) return;
  lastTrayStatus = status;
  const modeTitle = status.routingModeTitle || '关闭';
  const tip = status.statusText
    ? `${APP_NAME} · ${status.statusText} · ${modeTitle}`
    : APP_NAME;
  tray.setToolTip(tip);

  const key = trayMenuKey(status);
  if (key === lastTrayMenuKey) return;
  lastTrayMenuKey = key;

  // Refresh menu contents (mode radio, advertise label, etc.).
  tray.setContextMenu(buildTrayMenu(status));
}

function createWindow() {
  /** @type {Electron.BrowserWindowConstructorOptions} */
  const options = {
    width: 1180,
    height: 900,
    minWidth: 860,
    minHeight: 680,
    show: false,
    title: APP_NAME,
    titleBarStyle: 'hiddenInset',
    // Allow CSS -webkit-app-region: drag on the custom title strip.
    trafficLightPosition: { x: 16, y: 18 },
    backgroundColor: windowBackgroundColor(),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  };

  // macOS: native frosted material so a transparent sidebar actually looks like glass.
  // CSS backdrop-filter alone fails when the sidebar sits in a solid grid column.
  if (process.platform === 'darwin') {
    options.transparent = true;
    options.backgroundColor = '#00000000';
    options.vibrancy = 'sidebar';
    options.visualEffectState = 'followWindow';
  } else if (process.platform === 'win32') {
    options.backgroundMaterial = 'acrylic';
  }

  mainWindow = new BrowserWindow(options);

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  mainWindow.once('ready-to-show', () => mainWindow.show());
  mainWindow.on('close', (event) => {
    if (!isQuitting) {
      event.preventDefault();
      mainWindow.hide();
    }
  });
  mainWindow.on('closed', () => {
    mainWindow = undefined;
  });
}

ipcMain.handle('app:set-theme-source', (_event, source) => {
  const allowed = new Set(['system', 'light', 'dark']);
  nativeTheme.themeSource = allowed.has(source) ? source : 'system';
  applyWindowTheme();
  return nativeTheme.themeSource;
});

ipcMain.handle('app:get-version', () => versionInfo.toJSON());

ipcMain.handle('native:get-status', async () => {
  try {
    return await requestNative('getStatus');
  } catch (error) {
    return offlineStatus(error);
  }
});

ipcMain.handle('native:command', async (_event, command, payload = {}) => {
  const allowed = new Set([
    'startAdvertising',
    'stopAdvertising',
    'toggleAdvertising',
    'sendA',
    'restart',
    'setRoutingMode',
    'requestPermissions',
    'openAccessibilitySettings',
    'openInputMonitoringSettings',
    'exportDiagnostics'
  ]);
  if (!allowed.has(command)) throw new Error('Unsupported native command');
  return requestNative(command, payload);
});

ipcMain.on('window:hide', () => mainWindow?.hide());

app.whenReady().then(() => {
  // Keep Dock icon visible for the Electron control app.
  // The native Swift helper remains LSUIElement (agent) and stays out of Dock.
  if (process.platform === 'darwin' && app.dock) app.dock.show();
  // Follow macOS / system appearance (light white / dark).
  nativeTheme.themeSource = 'system';
  nativeTheme.on('updated', applyWindowTheme);
  launchNativeBackend();
  createTray();
  createWindow();
  pollTimer = setInterval(publishStatus, 1000);
  publishStatus();

  app.on('activate', () => {
    if (isQuitting) return;
    if (mainWindow) mainWindow.show();
    else createWindow();
  });
});

app.on('before-quit', (event) => {
  isQuitting = true;
  if (nativeShutdownComplete) return;
  // Hold quit until native helper + timers + tray are fully torn down.
  event.preventDefault();
  if (isShuttingDown) return;
  isShuttingDown = true;

  Promise.race([
    stopNativeBackend(),
    sleep(NATIVE_SHUTDOWN_MS + 1500)
  ])
    .catch(() => {})
    .finally(() => {
      destroyUiShell();
      killElectronHelpersSync();
      nativeShutdownComplete = true;
      app.quit();
    });
});

// Last-chance cleanup if the process is still around (e.g. crash path).
app.on('will-quit', () => {
  isQuitting = true;
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = undefined;
  }
  killElectronHelpersSync();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

// Signals: Electron may tear down the event loop before async before-quit finishes.
// Always reap the helper synchronously first.
function handleProcessSignal(signal) {
  if (isQuitting && nativeShutdownComplete) return;
  isQuitting = true;
  console.warn(`[${LOG_PREFIX}] Received ${signal}, stopping native helper…`);
  killElectronHelpersSync();
  destroyUiShell();
  nativeShutdownComplete = true;
  // app.quit is async-safe; if app is not ready, fall back to exit.
  try {
    app.quit();
  } catch {
    process.exit(0);
  }
  // Absolute fallback so we never hang as a zombie parent.
  setTimeout(() => process.exit(0), 500).unref?.();
}

process.on('SIGINT', () => handleProcessSignal('SIGINT'));
process.on('SIGTERM', () => handleProcessSignal('SIGTERM'));

// If the main process is terminated abruptly, try to reap the helper.
process.on('exit', () => {
  killElectronHelpersSync();
});
