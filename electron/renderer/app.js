const elements = {
  statusPill: document.querySelector('#status-pill'),
  statusText: document.querySelector('#status-text'),
  pageTitle: document.querySelector('#page-title'),
  workspaceHeader: document.querySelector('#workspace-header'),
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
  diagnosticHealthLabel: document.querySelector('#diagnostic-health-label'),
  modeButtons: [...document.querySelectorAll('[data-mode]')],
  navItems: [...document.querySelectorAll('.nav-item[data-view]')],
  views: [...document.querySelectorAll('[data-view-panel]')],
  toast: document.querySelector('#toast'),
  settingTheme: document.querySelector('#setting-theme'),
  settingLanguage: document.querySelector('#setting-language'),
  openDiagnostics: document.querySelector('#open-diagnostics'),
  diagnosticsBack: document.querySelector('#diagnostics-back')
};

const prefs = window.TtpPrefs.load();
const i18n = window.TtpI18n.createI18n(prefs.language);

let latestStatus = { status: 'backendOffline', routingMode: 'off' };
let activeView = 'control';
let toastTimer;

function t(key, vars) {
  return i18n.t(key, vars);
}

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

function applyStaticI18n() {
  document.documentElement.lang = i18n.locale === 'zh-CN' ? 'zh-CN' : 'en';
  document.title = t('appName');

  for (const el of document.querySelectorAll('[data-i18n]')) {
    const key = el.getAttribute('data-i18n');
    if (!key) continue;
    if (el.tagName === 'OPTION') {
      el.textContent = t(key);
    } else {
      el.textContent = t(key);
    }
  }

  for (const el of document.querySelectorAll('[data-i18n-aria]')) {
    const key = el.getAttribute('data-i18n-aria');
    if (key) el.setAttribute('aria-label', t(key));
  }

  // Keep select values after re-labeling options
  if (elements.settingTheme) elements.settingTheme.value = prefs.theme;
  if (elements.settingLanguage) elements.settingLanguage.value = prefs.language;

  elements.pageTitle.textContent = pageTitleFor(activeView);
  render(latestStatus);
}

function pageTitleFor(view) {
  if (view === 'diagnostics') return t('pageDiagnostics');
  if (view === 'settings') return t('pageSettings');
  return t('pageControl');
}

function setView(view) {
  if (!['control', 'diagnostics', 'settings'].includes(view)) return;
  activeView = view;

  // Diagnostics is opened from Settings — keep Settings highlighted in the sidebar.
  for (const item of elements.navItems) {
    const selected = item.dataset.view === view
      || (view === 'diagnostics' && item.dataset.view === 'settings');
    item.classList.toggle('is-active', selected);
    item.setAttribute('aria-selected', String(selected));
  }

  for (const panel of elements.views) {
    const selected = panel.dataset.viewPanel === view;
    panel.classList.toggle('is-active', selected);
    panel.hidden = !selected;
  }

  // Secondary page: title lives in the diagnostics toolbar (with back arrow).
  const isDiagnostics = view === 'diagnostics';
  if (elements.workspaceHeader) {
    elements.workspaceHeader.hidden = isDiagnostics;
  }
  if (!isDiagnostics) {
    elements.pageTitle.textContent = pageTitleFor(view);
  }
}

function routingLabel(mode) {
  if (mode === 'mirror') return t('modeMirror');
  if (mode === 'exclusive') return t('modeExclusive');
  return t('modeOffShort');
}

function sidebarStatusLabel(status) {
  if (status.status === 'backendOffline') return t('statusOffline');
  if (status.routingMode === 'mirror') return t('statusMirroring');
  if (status.routingMode === 'exclusive') return t('statusExclusive');
  if (status.status === 'connected') return t('statusConnected');
  if (status.isAdvertising || status.status === 'advertising') return t('statusAdvertising');
  if (status.status === 'error') return t('statusError');
  return status.statusText || t('statusUnknown');
}

function render(status) {
  latestStatus = status || latestStatus;
  status = latestStatus;
  const connected = status.status === 'connected';
  const backendOnline = status.status !== 'backendOffline';

  elements.statusPill.dataset.state = status.routingMode && status.routingMode !== 'off'
    ? 'routing'
    : (status.status || 'backendOffline');
  elements.statusText.textContent = sidebarStatusLabel(status);

  elements.nativeService.textContent = backendOnline ? t('connected') : t('offline');
  elements.bluetoothState.textContent = status.bluetoothState || '—';
  elements.advertisingState.textContent = status.isAdvertising ? t('yes') : t('no');
  elements.hidService.textContent = status.hidServiceAdded ? t('added') : t('notAdded');
  elements.subscription.textContent = status.isSubscribed ? t('yes') : t('no');
  elements.routingMode.textContent = routingLabel(status.routingMode);
  elements.captureState.textContent = status.isCapturing ? t('running') : t('notRunning');
  elements.listenAccess.textContent = status.listenAccess ? t('granted') : t('missing');
  elements.accessibilityAccess.textContent = status.accessibilityAccess ? t('granted') : t('missing');
  elements.queueDepth.textContent = String(status.queueDepth ?? 0);
  elements.capsLock.textContent = status.capsLock ? t('on') : t('off');
  elements.lastReport.textContent = status.lastReportHex || '—';
  elements.diagnosticTime.textContent = new Intl.DateTimeFormat(i18n.dateLocale(), {
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
  if (elements.diagnosticHealthLabel) {
    elements.diagnosticHealthLabel.textContent = healthy ? t('healthOk') : t('healthWarn');
  }

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
  let badge = t('statusDisconnected');

  if (!backendOnline) {
    cardState = 'offline';
    badge = t('statusOffline');
    elements.connectionTitle.textContent = t('connOfflineTitle');
    elements.connectionDetail.textContent = t('connOfflineDetail');
    elements.advertiseButton.textContent = t('connWaitingService');
    elements.advertiseButton.disabled = true;
  } else if (connected) {
    const routing = status.routingMode && status.routingMode !== 'off';
    cardState = routing ? 'routing' : 'connected';
    badge = routing
      ? (status.routingMode === 'exclusive' ? t('statusExclusive') : t('statusMirroring'))
      : t('statusConnected');
    elements.connectionTitle.textContent = routing
      ? t('statusRouting')
      : t('connConnectedTitle');
    elements.connectionDetail.textContent = status.routingMode === 'exclusive'
      ? t('connExclusiveDetail')
      : t('connMirrorDetail');
    elements.advertiseButton.textContent = t('btnStopAdvertise');
    elements.advertiseButton.disabled = false;
  } else if (status.isAdvertising || status.status === 'advertising') {
    cardState = 'advertising';
    badge = t('statusAdvertising');
    elements.connectionTitle.textContent = t('connAdvertisingTitle');
    elements.connectionDetail.textContent = t('connAdvertisingDetail');
    elements.advertiseButton.textContent = t('btnStopAdvertise');
    elements.advertiseButton.disabled = false;
  } else if (status.status === 'error') {
    cardState = 'error';
    badge = t('statusError');
    elements.connectionTitle.textContent = t('connErrorTitle');
    elements.connectionDetail.textContent = status.nativeError || t('connErrorDetail');
    elements.advertiseButton.textContent = t('btnRetry');
    elements.advertiseButton.disabled = false;
  } else {
    cardState = 'idle';
    badge = t('statusDisconnected');
    elements.connectionTitle.textContent = t('connIdleTitle');
    elements.connectionDetail.textContent = t('connIdleDetail');
    elements.advertiseButton.textContent = t('btnStartAdvertise');
    elements.advertiseButton.disabled = false;
  }

  if (elements.connectionCard) elements.connectionCard.dataset.state = cardState;
  if (elements.connectionBadge) elements.connectionBadge.textContent = badge;
}

async function runCommand(command, payload = {}) {
  try {
    const result = await window.macInput.command(command, payload);
    render(result);
    return result;
  } catch (error) {
    showToast(error.message || t('toastFailed'));
    const offline = {
      ...latestStatus,
      status: 'backendOffline',
      statusText: t('toastBackendOffline')
    };
    render(offline);
    return offline;
  }
}

function persistPrefs() {
  window.TtpPrefs.save(prefs);
}

function onThemeChange() {
  prefs.theme = elements.settingTheme.value;
  persistPrefs();
  window.TtpPrefs.applyTheme(prefs.theme);
}

function onLanguageChange() {
  prefs.language = elements.settingLanguage.value;
  persistPrefs();
  i18n.setPreference(prefs.language);
  applyStaticI18n();
}

for (const item of elements.navItems) {
  item.addEventListener('click', () => setView(item.dataset.view));
}
if (elements.openDiagnostics) {
  elements.openDiagnostics.addEventListener('click', () => setView('diagnostics'));
}
if (elements.diagnosticsBack) {
  elements.diagnosticsBack.addEventListener('click', () => setView('settings'));
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
  if (result.exportedPath) showToast(t('toastExported', { path: result.exportedPath }));
});
for (const button of elements.modeButtons) {
  button.addEventListener('click', () => runCommand('setRoutingMode', { mode: button.dataset.mode }));
}

if (elements.settingTheme) {
  elements.settingTheme.value = prefs.theme;
  elements.settingTheme.addEventListener('change', onThemeChange);
}
if (elements.settingLanguage) {
  elements.settingLanguage.value = prefs.language;
  elements.settingLanguage.addEventListener('change', onLanguageChange);
}

// Follow OS theme/language changes when set to system
if (window.matchMedia) {
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    if (prefs.theme === 'system') window.TtpPrefs.applyTheme('system');
  });
}

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

window.TtpPrefs.applyTheme(prefs.theme);
applyStaticI18n();
setView(activeView);
window.macInput.onStatus(render);
window.macInput.getStatus().then(render);
