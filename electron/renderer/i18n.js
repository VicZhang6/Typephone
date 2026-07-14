/**
 * UI strings (zh-CN / en).
 * Language preference: system | zh-CN | en
 * Product name comes from shared branding (single source of truth).
 */
(function (global) {
  const brand = global.TtpBranding || { APP_NAME: 'Typephone', APP_KEYBOARD_NAME: 'Typephone Keyboard' };
  const APP_NAME = brand.APP_NAME;
  const APP_KEYBOARD_NAME = brand.APP_KEYBOARD_NAME;

  const catalogs = {
    'zh-CN': {
      appName: APP_NAME,
      navControl: '控制方式',
      navDiagnostics: '诊断',
      navSettings: '设置',
      pageControl: '控制方式',
      pageDiagnostics: '诊断',
      pageSettings: '设置',

      statusConnecting: '正在连接原生服务',
      statusUnknown: '状态未知',
      statusOffline: '离线',
      statusConnected: '已连接',
      statusAdvertising: '等待配对',
      statusError: '异常',
      statusDisconnected: '未连接',
      statusMirroring: '镜像中',
      statusExclusive: '独占中',
      statusRouting: '正在转发输入',

      connOfflineTitle: '原生服务未启动',
      connOfflineDetail: '运行 npm run dev 启动 Swift helper。',
      connWaitingService: '等待服务',
      connConnectedTitle: 'iPhone 已连接',
      connExclusiveDetail: 'Mac 本地按键已暂停 · ⌃⌥⌘Esc 紧急退出',
      connMirrorDetail: '选择镜像或独占模式后即可转发物理键盘',
      connAdvertisingTitle: '等待 iPhone 配对',
      connAdvertisingDetail: `在 iPhone「设置 → 蓝牙」中选择 ${APP_KEYBOARD_NAME}`,
      connErrorTitle: '蓝牙服务启动失败',
      connErrorDetail: '请到「诊断」页查看详情后重试',
      connIdleTitle: '尚未开始等待配对',
      connIdleDetail: '开始等待后，iPhone 才能发现这台 Mac',
      btnStartAdvertise: '开始等待配对',
      btnStopAdvertise: '停止等待配对',
      btnRetry: '重新尝试',

      permEyebrow: '需要系统权限',
      permTitle: '允许键盘捕获与独占输入',
      permBody: '镜像模式需要「输入监控」，独占模式还需要「辅助功能」。授权后请返回这里重试。',
      btnRequestPermissions: '请求权限',
      btnOpenInputSettings: '输入监控设置',
      btnOpenAccessibility: '辅助功能设置',

      modeOff: '关闭',
      modeOffDetail: '按键只留在 Mac',
      modeMirror: '镜像输入',
      modeMirrorDetail: 'Mac 和 iPhone 同时接收',
      modeExclusive: '独占输入',
      modeExclusiveDetail: '按键只发送到 iPhone',
      modeGroupLabel: '输入模式',
      emergencyNote: '紧急快捷键始终退出独占模式并释放所有按键。',

      testHint: 'iPhone 连接并打开输入框后，发送 A down → A up。',
      btnSendA: '发送 “a” 到 iPhone',

      helpTitle: '遇到问题？',
      helpHint: '展开故障排查步骤',
      help1: `在 iPhone「设置 → 蓝牙」中忽略旧的 ${APP_KEYBOARD_NAME}`,
      help2: '在诊断页点击「重新等待配对」，等待设备重新出现',
      help3: '配对成功后，在 iPhone 备忘录中试打字',
      help4: '若仍失败，到「诊断」页导出诊断 JSON',

      btnRestart: '重新等待配对',
      btnExport: '导出诊断 JSON',
      lastUpdated: '最近更新',
      healthOk: '运行正常',
      healthWarn: '需要检查',

      diagBluetooth: 'Bluetooth',
      diagAdvertising: '等待配对',
      diagHid: 'HID Service',
      diagRouting: '输入模式',
      diagListen: '输入监控',
      diagAccessibility: '辅助功能',
      diagQueue: '发送队列',
      diagNative: '原生服务',
      diagSubscription: 'iPhone 订阅',
      diagEventTap: 'Event Tap',
      diagCaps: 'Caps Lock',
      diagReport: '最近报告',

      yes: '是',
      no: '否',
      on: '开',
      off: '关',
      granted: '已授予',
      missing: '缺失',
      added: '已添加',
      notAdded: '未添加',
      connected: '已连接',
      offline: '离线',
      checking: '检查中',
      running: '运行中',
      notRunning: '未运行',
      modeOffShort: '关闭',

      settingsTheme: '主题',
      settingsLanguage: '语言',
      settingsDiagnostics: '诊断',
      settingsOpenDiagnostics: '打开',
      backToSettings: '返回设置',
      themeSystem: '跟随系统',
      themeLight: '浅色',
      themeDark: '深色',
      langSystem: '跟随系统',
      langZh: '简体中文',
      langEn: 'English',
      settingsHint: '主题与语言默认跟随系统，可在此覆盖。',

      toastFailed: '操作失败',
      toastExported: '诊断已保存：{path}',
      toastBackendOffline: '原生 BLE 服务未启动'
    },
    en: {
      appName: APP_NAME,
      navControl: 'Control',
      navDiagnostics: 'Diagnostics',
      navSettings: 'Settings',
      pageControl: 'Control',
      pageDiagnostics: 'Diagnostics',
      pageSettings: 'Settings',

      statusConnecting: 'Connecting to native service…',
      statusUnknown: 'Unknown status',
      statusOffline: 'Offline',
      statusConnected: 'Connected',
      statusAdvertising: 'Advertising',
      statusError: 'Error',
      statusDisconnected: 'Disconnected',
      statusMirroring: 'Mirroring',
      statusExclusive: 'Exclusive',
      statusRouting: 'Forwarding input',

      connOfflineTitle: 'Native service not running',
      connOfflineDetail: 'Run npm run dev to start the Swift helper.',
      connWaitingService: 'Waiting…',
      connConnectedTitle: 'iPhone connected',
      connExclusiveDetail: 'Mac keys paused · ⌃⌥⌘Esc emergency exit',
      connMirrorDetail: 'Pick Mirror or Exclusive to forward the keyboard',
      connAdvertisingTitle: 'Waiting for iPhone',
      connAdvertisingDetail: `On iPhone, open Settings → Bluetooth and choose ${APP_KEYBOARD_NAME}`,
      connErrorTitle: 'Bluetooth failed to start',
      connErrorDetail: 'Check Diagnostics, then try again',
      connIdleTitle: 'Not advertising yet',
      connIdleDetail: 'Start advertising so your iPhone can discover this Mac',
      btnStartAdvertise: 'Start advertising',
      btnStopAdvertise: 'Stop advertising',
      btnRetry: 'Try again',

      permEyebrow: 'Permissions required',
      permTitle: 'Allow keyboard capture & exclusive input',
      permBody: 'Mirror needs Input Monitoring; Exclusive also needs Accessibility. Return here after granting access.',
      btnRequestPermissions: 'Request permissions',
      btnOpenInputSettings: 'Input Monitoring settings',
      btnOpenAccessibility: 'Accessibility settings',

      modeOff: 'Off',
      modeOffDetail: 'Keys stay on the Mac only',
      modeMirror: 'Mirror',
      modeMirrorDetail: 'Mac and iPhone both receive keys',
      modeExclusive: 'Exclusive',
      modeExclusiveDetail: 'Keys go to iPhone only',
      modeGroupLabel: 'Input mode',
      emergencyNote: 'Emergency shortcut always exits exclusive mode and releases keys.',

      testHint: 'With iPhone connected and a text field focused, send A down → A up.',
      btnSendA: 'Send “a” to iPhone',

      helpTitle: 'Having trouble?',
      helpHint: 'Expand troubleshooting steps',
      help1: `Forget the old ${APP_KEYBOARD_NAME} in iPhone Settings → Bluetooth`,
      help2: 'In Diagnostics, tap Restart waiting, then wait for the device',
      help3: 'After pairing, open Notes on iPhone and try typing',
      help4: 'If it still fails, export diagnostics JSON from Diagnostics',

      btnRestart: 'Restart advertising',
      btnExport: 'Export diagnostics JSON',
      lastUpdated: 'Updated',
      healthOk: 'Healthy',
      healthWarn: 'Needs attention',

      diagBluetooth: 'Bluetooth',
      diagAdvertising: 'Advertising',
      diagHid: 'HID Service',
      diagRouting: 'Input mode',
      diagListen: 'Input Monitoring',
      diagAccessibility: 'Accessibility',
      diagQueue: 'Send queue',
      diagNative: 'Native service',
      diagSubscription: 'iPhone subscription',
      diagEventTap: 'Event Tap',
      diagCaps: 'Caps Lock',
      diagReport: 'Last report',

      yes: 'Yes',
      no: 'No',
      on: 'On',
      off: 'Off',
      granted: 'Granted',
      missing: 'Missing',
      added: 'Added',
      notAdded: 'Not added',
      connected: 'Connected',
      offline: 'Offline',
      checking: 'Checking…',
      running: 'Running',
      notRunning: 'Not running',
      modeOffShort: 'Off',

      settingsTheme: 'Theme',
      settingsLanguage: 'Language',
      settingsDiagnostics: 'Diagnostics',
      settingsOpenDiagnostics: 'Open',
      backToSettings: 'Back to Settings',
      themeSystem: 'System',
      themeLight: 'Light',
      themeDark: 'Dark',
      langSystem: 'System',
      langZh: '简体中文',
      langEn: 'English',
      settingsHint: 'Theme and language follow the system by default. Override them here.',

      toastFailed: 'Something went wrong',
      toastExported: 'Diagnostics saved: {path}',
      toastBackendOffline: 'Native BLE service is offline'
    }
  };

  function resolveLocale(pref) {
    if (pref === 'zh-CN' || pref === 'en') return pref;
    const nav = (typeof navigator !== 'undefined' && navigator.language) || 'en';
    return nav.toLowerCase().startsWith('zh') ? 'zh-CN' : 'en';
  }

  function createI18n(pref = 'system') {
    let preference = pref || 'system';
    let locale = resolveLocale(preference);

    return {
      get preference() { return preference; },
      get locale() { return locale; },
      setPreference(next) {
        preference = next || 'system';
        locale = resolveLocale(preference);
        return locale;
      },
      t(key, vars) {
        const table = catalogs[locale] || catalogs.en;
        let text = table[key] ?? catalogs.en[key] ?? key;
        if (vars) {
          for (const [k, v] of Object.entries(vars)) {
            text = text.replace(new RegExp(`\\{${k}\\}`, 'g'), String(v));
          }
        }
        return text;
      },
      dateLocale() {
        return locale === 'zh-CN' ? 'zh-CN' : 'en-US';
      }
    };
  }

  global.TtpI18n = { catalogs, resolveLocale, createI18n };
})(typeof window !== 'undefined' ? window : globalThis);
