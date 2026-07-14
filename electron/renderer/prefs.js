/**
 * Persist UI preferences (theme + language). Defaults follow the system.
 */
(function (global) {
  const KEY = 'ttp.prefs.v1';

  function load() {
    try {
      const raw = localStorage.getItem(KEY);
      if (!raw) return { theme: 'system', language: 'system' };
      const parsed = JSON.parse(raw);
      return {
        theme: ['system', 'light', 'dark'].includes(parsed.theme) ? parsed.theme : 'system',
        language: ['system', 'zh-CN', 'en'].includes(parsed.language) ? parsed.language : 'system'
      };
    } catch {
      return { theme: 'system', language: 'system' };
    }
  }

  function save(prefs) {
    localStorage.setItem(KEY, JSON.stringify(prefs));
  }

  function applyTheme(theme) {
    const root = document.documentElement;
    if (theme === 'light' || theme === 'dark') {
      root.dataset.theme = theme;
    } else {
      delete root.dataset.theme;
    }
    if (window.macInput?.setThemeSource) {
      window.macInput.setThemeSource(theme === 'light' || theme === 'dark' ? theme : 'system');
    }
  }

  global.TtpPrefs = { load, save, applyTheme };
})(typeof window !== 'undefined' ? window : globalThis);
