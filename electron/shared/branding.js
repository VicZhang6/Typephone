/**
 * Single source of truth for product naming.
 * Used by Electron main (require) and renderer (script tag → globalThis.TtpBranding).
 */
(function (root, factory) {
  const branding = factory();
  if (typeof module === 'object' && module.exports) {
    module.exports = branding;
  }
  root.TtpBranding = branding;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  const APP_NAME = 'Typephone';
  return {
    /** Product display name (window, tray, menus, UI). */
    APP_NAME,
    /** BLE peripheral name shown in iPhone Settings → Bluetooth. */
    APP_KEYBOARD_NAME: `${APP_NAME} Keyboard`,
    /** Console / log prefix. */
    LOG_PREFIX: APP_NAME.toLowerCase(),
    quitLabel(locale) {
      // Keep simple bilingual quit labels without full i18n in main.
      if (locale === 'en') return `Quit ${APP_NAME}`;
      return `退出 ${APP_NAME}`;
    }
  };
});
