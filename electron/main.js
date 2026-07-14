const { app, BrowserWindow, ipcMain, Menu, Tray, nativeImage } = require('electron');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');

const nativeHost = '127.0.0.1';
const nativePort = 43821;
const defaultNativeApp = '/tmp/MacInputDerived/Build/Products/Debug/MacInput.app';

let mainWindow;
let tray;
let pollTimer;
let isQuitting = false;
let nativeShutdownComplete = false;

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
  if (!mainWindow || mainWindow.isDestroyed()) return;
  try {
    const status = await requestNative('getStatus');
    updateTray(status);
    mainWindow.webContents.send('native:status', status);
  } catch (error) {
    const status = offlineStatus(error);
    updateTray(status);
    mainWindow.webContents.send('native:status', status);
  }
}

function launchNativeBackend() {
  const packagedNativeApp = path.join(process.resourcesPath, 'native', 'MacInput.app');
  const nativeApp = process.env.MAC_INPUT_NATIVE_APP
    || (app.isPackaged ? packagedNativeApp : defaultNativeApp);
  if (!fs.existsSync(nativeApp)) return;
  const child = spawn('open', ['-n', nativeApp, '--args', '--electron-helper'], {
    detached: true,
    stdio: 'ignore'
  });
  child.unref();
}

function createTray() {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 22 22"><rect x="2" y="5" width="18" height="12" rx="2" fill="none" stroke="#25231f" stroke-width="1.5"/><path d="M5 8h2v2H5zm3 0h2v2H8zm3 0h2v2h-2zm3 0h2v2h-2zM5 12h2v2H5zm3 0h2v2H8zm3 0h5v2h-5z" fill="#25231f"/></svg>`;
  tray = new Tray(nativeImage.createFromDataURL(`data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`));
  tray.setToolTip('Mac Input');
  tray.on('click', () => {
    if (!mainWindow) return;
    if (mainWindow.isVisible()) mainWindow.hide();
    else mainWindow.show();
  });
  updateTray(offlineStatus());
}

function updateTray(status) {
  if (!tray) return;
  const mode = status.routingModeTitle || '关闭';
  const connected = status.status === 'connected';
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: status.statusText || 'Mac Input', enabled: false },
    { label: connected ? `已连接 · ${mode}` : '等待 iPhone 配对', enabled: false },
    { type: 'separator' },
    { label: '显示 Mac Input', click: () => mainWindow?.show() },
    {
      label: status.isAdvertising ? '停止广播' : '开始广播',
      click: () => requestNative(status.isAdvertising ? 'stopAdvertising' : 'startAdvertising')
    },
    { label: '发送测试 A', enabled: Boolean(status.canSendA), click: () => requestNative('sendA') },
    {
      label: '输入模式',
      submenu: [
        { label: '关闭', type: 'radio', checked: status.routingMode === 'off', click: () => requestNative('setRoutingMode', { mode: 'off' }) },
        { label: '镜像输入', type: 'radio', checked: status.routingMode === 'mirror', click: () => requestNative('setRoutingMode', { mode: 'mirror' }) },
        { label: '独占输入', type: 'radio', checked: status.routingMode === 'exclusive', click: () => requestNative('setRoutingMode', { mode: 'exclusive' }) }
      ]
    },
    { type: 'separator' },
    { label: '导出诊断 JSON', click: () => requestNative('exportDiagnostics') },
    { label: '退出 Mac Input', click: () => { isQuitting = true; app.quit(); } }
  ]));
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1180,
    height: 900,
    minWidth: 860,
    minHeight: 680,
    show: false,
    title: 'Mac Input',
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#f6f5f3',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

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

  pollTimer = setInterval(publishStatus, 1000);
  publishStatus();
}

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
  if (process.platform === 'darwin' && app.dock) app.dock.hide();
  launchNativeBackend();
  createTray();
  createWindow();

  app.on('activate', () => {
    if (mainWindow) mainWindow.show();
    else createWindow();
  });
});

app.on('before-quit', (event) => {
  isQuitting = true;
  clearInterval(pollTimer);
  if (nativeShutdownComplete) return;
  event.preventDefault();
  requestNative('shutdown')
    .catch(() => {})
    .finally(() => {
      nativeShutdownComplete = true;
      app.quit();
    });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
