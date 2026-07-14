const elements = {
  statusPill: document.querySelector('#status-pill'),
  statusText: document.querySelector('#status-text'),
  connectionTitle: document.querySelector('#connection-title'),
  connectionDetail: document.querySelector('#connection-detail'),
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
  toast: document.querySelector('#toast')
};

let latestStatus = { status: 'backendOffline', routingMode: 'off' };
let toastTimer;

function showToast(message) {
  clearTimeout(toastTimer);
  elements.toast.textContent = message;
  elements.toast.hidden = false;
  toastTimer = setTimeout(() => { elements.toast.hidden = true; }, 4200);
}

function setDiagnosticTone(element, tone) {
  element.dataset.tone = tone;
}

function render(status) {
  latestStatus = status;
  const connected = status.status === 'connected';
  const backendOnline = status.status !== 'backendOffline';

  elements.statusPill.dataset.state = status.routingMode !== 'off' ? 'routing' : status.status;
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
  const healthy = backendOnline && status.bluetoothState !== 'unknown' && status.status !== 'bluetoothUnavailable' && status.status !== 'error';
  elements.diagnosticHealth.classList.toggle('warning', !healthy);
  elements.diagnosticHealth.lastChild.textContent = healthy ? '运行正常' : '需要检查';
  setDiagnosticTone(elements.bluetoothState, status.bluetoothState === 'poweredOn' ? 'good' : status.bluetoothState === 'unknown' ? 'neutral' : 'warning');
  setDiagnosticTone(elements.advertisingState, status.isAdvertising ? 'good' : 'neutral');
  setDiagnosticTone(elements.hidService, status.hidServiceAdded ? 'good' : 'warning');
  setDiagnosticTone(elements.listenAccess, status.listenAccess ? 'good' : 'warning');
  setDiagnosticTone(elements.accessibilityAccess, status.accessibilityAccess ? 'good' : 'warning');
  setDiagnosticTone(elements.queueDepth, (status.queueDepth ?? 0) === 0 ? 'good' : 'warning');
  elements.sendAButton.disabled = !status.canSendA;
  elements.restartButton.disabled = !backendOnline;
  elements.exportButton.disabled = !backendOnline;
  elements.permissionBanner.hidden = !backendOnline || Boolean(status.canSuppressKeyboard);

  for (const button of elements.modeButtons) {
    const selected = button.dataset.mode === (status.routingMode || 'off');
    button.setAttribute('aria-checked', String(selected));
    button.disabled = !connected && button.dataset.mode !== 'off';
  }

  if (!backendOnline) {
    elements.connectionTitle.textContent = '原生 BLE 服务未启动';
    elements.connectionDetail.textContent = '运行 npm run dev，Electron 会自动启动 Swift helper。';
    elements.advertiseButton.textContent = '等待原生服务';
    elements.advertiseButton.disabled = true;
  } else if (connected) {
    elements.connectionTitle.textContent = status.routingMode === 'off' ? 'iPhone 已连接' : status.statusText;
    elements.connectionDetail.textContent = status.routingMode === 'exclusive'
      ? 'Mac 本地按键已暂停；按 ⌃⌥⌘Esc 可立即退出。'
      : '选择镜像或独占模式后即可转发物理键盘。';
    elements.advertiseButton.textContent = '停止广播';
    elements.advertiseButton.disabled = false;
  } else if (status.isAdvertising || status.status === 'advertising') {
    elements.connectionTitle.textContent = '正在等待 iPhone 配对';
    elements.connectionDetail.textContent = '打开 iPhone 的“设置 → 蓝牙”，选择 Mac Input Keyboard。';
    elements.advertiseButton.textContent = '停止广播';
    elements.advertiseButton.disabled = false;
  } else if (status.status === 'error') {
    elements.connectionTitle.textContent = '蓝牙服务启动失败';
    elements.connectionDetail.textContent = status.nativeError || '请查看诊断信息后重新广播。';
    elements.advertiseButton.textContent = '重新尝试';
    elements.advertiseButton.disabled = false;
  } else {
    elements.connectionTitle.textContent = '蓝牙键盘尚未广播';
    elements.connectionDetail.textContent = '开始广播后，iPhone 才能发现这台 Mac。';
    elements.advertiseButton.textContent = '开始广播';
    elements.advertiseButton.disabled = false;
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

window.macInput.onStatus(render);
window.macInput.getStatus().then(render);
