const elements = {
  statusPill: document.querySelector('#status-pill'),
  statusText: document.querySelector('#status-text'),
  pageTitle: document.querySelector('#page-title'),
  connectionCard: document.querySelector('#connection-card'),
  connectionTitle: document.querySelector('#connection-title'),
  connectionDetail: document.querySelector('#connection-detail'),
  connectionBadge: document.querySelector('#connection-badge'),
  advertiseButton: document.querySelector('#advertise-button'),
  permissionBanner: document.querySelector('#permission-banner'),
  requestPermissions: document.querySelector('#request-permissions'),
  openInputSettings: document.querySelector('#open-input-settings'),
  openAccessibilitySettings: document.querySelector('#open-accessibility-settings'),
  sendAButton: document.querySelector('#send-a-button'),
  restartButton: document.querySelector('#restart-button'),
  exportButton: document.querySelector('#export-button'),
  nativeService: document.querySelector('#native-service'),
  bluetoothState: document.querySelector('#bluetooth-state'),
  advertisingState: document.querySelector('#advertising-state'),
  hidService: document.querySelector('#hid-service'),
  subscription: document.querySelector('#subscription'),
  routingMode: document.querySelector('#routing-mode'),
  captureState: document.querySelector('#capture-state'),
  listenAccess: document.querySelector('#listen-access'),
  accessibilityAccess: document.querySelector('#accessibility-access'),
  queueDepth: document.querySelector('#queue-depth'),
  capsLock: document.querySelector('#caps-lock'),
  lastReport: document.querySelector('#last-report'),
  diagnosticTime: document.querySelector('#diagnostic-time'),
  diagnosticHealth: document.querySelector('#diagnostic-health'),
  modeButtons: [...document.querySelectorAll('[data-mode]')],
  navItems: [...document.querySelectorAll('.nav-item[data-view]')],
  views: [...document.querySelectorAll('[data-view-panel]')],
  toast: document.querySelector('#toast')
};

const PAGE_TITLES = {
  control: '控制方式',
  diagnostics: '诊断'
};

let latestStatus = { status: 'backendOffline', routingMode: 'off' };
let activeView = 'control';
let toastTimer;

function showToast(message) {
  clearTimeout(toastTimer);
  elements.toast.textContent = message;
  elements.toast.hidden = false;
  toastTimer = setTimeout(() => { elements.toast.hidden = true; }, 4200);
}

function setDiagnosticTone(element, tone) {
  if (!element) return;
  element.dataset.tone = tone;
}

function setView(view) {
  if (!PAGE_TITLES[view]) return;
  activeView = view;

  for (const item of elements.navItems) {
    const selected = item.dataset.view === view;
    item.classList.toggle('is-active', selected);
    item.setAttribute('aria-selected', String(selected));
  }

  for (const panel of elements.views) {
    const selected = panel.dataset.viewPanel === view;
    panel.classList.toggle('is-active', selected);
    panel.hidden = !selected;
  }

  elements.pageTitle.textContent = PAGE_TITLES[view];
}

function render(status) {
  latestStatus = status;
  const connected = status.status === 'connected';
  const backendOnline = status.status !== 'backendOffline';

  elements.statusPill.dataset.state = status.routingMode !== 'off'
    ? 'routing'
    : (status.status || 'backendOffline');
  elements.statusText.textContent = status.statusText || '状态未知';

  elements.nativeService.textContent = backendOnline ? '已连接' : '离线';
  elements.bluetoothState.textContent = status.bluetoothState || '—';
  elements.advertisingState.textContent = status.isAdvertising ? '是' : '否';
  elements.hidService.textContent = status.hidServiceAdded ? '已添加' : '未添加';
  elements.subscription.textContent = status.isSubscribed ? '是' : '否';
  elements.routingMode.textContent = status.routingModeTitle || '关闭';
  elements.captureState.textContent = status.isCapturing ? '运行中' : '未运行';
  elements.listenAccess.textContent = status.listenAccess ? '已授予' : '缺失';
  elements.accessibilityAccess.textContent = status.accessibilityAccess ? '已授予' : '缺失';
  elements.queueDepth.textContent = String(status.queueDepth ?? 0);
  elements.capsLock.textContent = status.capsLock ? '开' : '关';
  elements.lastReport.textContent = status.lastReportHex || '—';
  elements.diagnosticTime.textContent = new Intl.DateTimeFormat('zh-CN', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  }).format(new Date());

  const healthy = backendOnline
    && status.bluetoothState !== 'unknown'
    && status.status !== 'bluetoothUnavailable'
    && status.status !== 'error';
  elements.diagnosticHealth.classList.toggle('warning', !healthy);
  // Text node after the <i> indicator
  const healthLabel = elements.diagnosticHealth.childNodes[elements.diagnosticHealth.childNodes.length - 1];
  if (healthLabel) healthLabel.textContent = healthy ? '运行正常' : '需要检查';

  // Restrained tones: ink for primary values, muted for inactive — no per-row rainbow.
  setDiagnosticTone(elements.bluetoothState, status.bluetoothState === 'poweredOn' ? 'good' : 'neutral');
  setDiagnosticTone(elements.advertisingState, status.isAdvertising ? 'good' : 'neutral');
  setDiagnosticTone(elements.hidService, status.hidServiceAdded ? 'good' : 'neutral');
  setDiagnosticTone(elements.listenAccess, status.listenAccess ? 'good' : 'neutral');
  setDiagnosticTone(elements.accessibilityAccess, status.accessibilityAccess ? 'good' : 'neutral');
  setDiagnosticTone(elements.queueDepth, 'good');
  setDiagnosticTone(elements.nativeService, backendOnline ? 'good' : 'neutral');
  setDiagnosticTone(elements.subscription, status.isSubscribed ? 'good' : 'neutral');
  setDiagnosticTone(elements.captureState, status.isCapturing ? 'good' : 'neutral');
  setDiagnosticTone(elements.routingMode, status.routingMode && status.routingMode !== 'off' ? 'good' : 'neutral');
  setDiagnosticTone(elements.capsLock, status.capsLock ? 'good' : 'neutral');

  elements.sendAButton.disabled = !status.canSendA;
  elements.restartButton.disabled = !backendOnline;
  elements.exportButton.disabled = !backendOnline;
  elements.permissionBanner.hidden = !backendOnline || Boolean(status.canSuppressKeyboard);

  for (const button of elements.modeButtons) {
    const selected = button.dataset.mode === (status.routingMode || 'off');
    button.setAttribute('aria-checked', String(selected));
    button.disabled = !connected && button.dataset.mode !== 'off';
  }

  let cardState = 'idle';
  let badge = '未连接';

  if (!backendOnline) {
    cardState = 'offline';
    badge = '离线';
    elements.connectionTitle.textContent = '原生服务未启动';
    elements.connectionDetail.textContent = '运行 npm run dev 启动 Swift helper。';
    elements.advertiseButton.textContent = '等待服务';
    elements.advertiseButton.disabled = true;
  } else if (connected) {
    const routing = status.routingMode && status.routingMode !== 'off';
    cardState = routing ? 'routing' : 'connected';
    badge = routing
      ? (status.routingMode === 'exclusive' ? '独占中' : '镜像中')
      : '已连接';
    elements.connectionTitle.textContent = routing
      ? (status.statusText || '正在转发输入')
      : 'iPhone 已连接';
    elements.connectionDetail.textContent = status.routingMode === 'exclusive'
      ? 'Mac 本地按键已暂停 · ⌃⌥⌘Esc 紧急退出'
      : '选择镜像或独占模式后即可转发物理键盘';
    elements.advertiseButton.textContent = '停止广播';
    elements.advertiseButton.disabled = false;
  } else if (status.isAdvertising || status.status === 'advertising') {
    cardState = 'advertising';
    badge = '广播中';
    elements.connectionTitle.textContent = '等待 iPhone 配对';
    elements.connectionDetail.textContent = '在 iPhone「设置 → 蓝牙」中选择 Mac Input Keyboard';
    elements.advertiseButton.textContent = '停止广播';
    elements.advertiseButton.disabled = false;
  } else if (status.status === 'error') {
    cardState = 'error';
    badge = '异常';
    elements.connectionTitle.textContent = '蓝牙服务启动失败';
    elements.connectionDetail.textContent = status.nativeError || '请到「诊断」页查看详情后重试';
    elements.advertiseButton.textContent = '重新尝试';
    elements.advertiseButton.disabled = false;
  } else {
    cardState = 'idle';
    badge = '未连接';
    elements.connectionTitle.textContent = '尚未开始广播';
    elements.connectionDetail.textContent = '开始广播后，iPhone 才能发现这台 Mac';
    elements.advertiseButton.textContent = '开始广播';
    elements.advertiseButton.disabled = false;
  }

  if (elements.connectionCard) {
    elements.connectionCard.dataset.state = cardState;
  }
  if (elements.connectionBadge) {
    elements.connectionBadge.textContent = badge;
  }
}

async function runCommand(command, payload = {}) {
  try {
    const result = await window.macInput.command(command, payload);
    render(result);
    return result;
  } catch (error) {
    showToast(error.message || '操作失败');
    const offline = {
      ...latestStatus,
      status: 'backendOffline',
      statusText: '原生 BLE 服务未启动'
    };
    render(offline);
    return offline;
  }
}

for (const item of elements.navItems) {
  item.addEventListener('click', () => setView(item.dataset.view));
}

elements.advertiseButton.addEventListener('click', () => {
  runCommand(latestStatus.isAdvertising ? 'stopAdvertising' : 'startAdvertising');
});
elements.sendAButton.addEventListener('click', () => runCommand('sendA'));
elements.restartButton.addEventListener('click', () => runCommand('restart'));
elements.requestPermissions.addEventListener('click', () => runCommand('requestPermissions'));
elements.openInputSettings.addEventListener('click', () => runCommand('openInputMonitoringSettings'));
elements.openAccessibilitySettings.addEventListener('click', () => runCommand('openAccessibilitySettings'));
elements.exportButton.addEventListener('click', async () => {
  const result = await runCommand('exportDiagnostics');
  if (result.exportedPath) showToast(`诊断已保存：${result.exportedPath}`);
});
for (const button of elements.modeButtons) {
  button.addEventListener('click', () => runCommand('setRoutingMode', { mode: button.dataset.mode }));
}

/** Highlight floating scrollbar while the user is actively scrolling. */
function bindScrollChrome(el) {
  if (!el) return;
  let timer;
  el.addEventListener('scroll', () => {
    el.classList.add('is-scrolling');
    clearTimeout(timer);
    timer = setTimeout(() => el.classList.remove('is-scrolling'), 700);
  }, { passive: true });
}
bindScrollChrome(document.querySelector('.workspace'));
bindScrollChrome(document.querySelector('.sidebar'));

setView(activeView);
window.macInput.onStatus(render);
window.macInput.getStatus().then(render);
