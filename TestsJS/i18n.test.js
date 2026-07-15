'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

require('../electron/shared/branding');
require('../electron/renderer/i18n');

test('pairing instructions interpolate the current advertised device name', () => {
  const english = global.TtpI18n.createI18n('en');
  const chinese = global.TtpI18n.createI18n('zh-CN');

  assert.match(
    english.t('connAdvertisingDetail', { deviceName: 'Vic MacBook' }),
    /Vic MacBook/
  );
  assert.match(
    chinese.t('connAdvertisingDetail', { deviceName: '办公室的 Mac' }),
    /办公室的 Mac/
  );
});

test('software-keyboard fallback is available in both languages', () => {
  const english = global.TtpI18n.createI18n('en');
  const chinese = global.TtpI18n.createI18n('zh-CN');

  assert.match(english.t('toastKeyboardUnavailable'), /pair/i);
  assert.match(chinese.t('toastKeyboardUnavailable'), /重新配对/);
});
