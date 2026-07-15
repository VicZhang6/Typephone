/**
 * Runtime version helpers.
 * Prefer generated stamp (version-stamp.js); fall back to package.json / defaults.
 *
 * Main: require('./shared/version')
 * Renderer: <script src="../shared/version-stamp.js"> then this file optional;
 *           settings reads via IPC app:get-version.
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  root.TtpVersionInfo = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  function loadStamp() {
    if (typeof require === 'function') {
      try {
        // eslint-disable-next-line import/no-unresolved, global-require
        return require('./version-stamp');
      } catch {
        /* stamp not generated yet */
      }
      try {
        // eslint-disable-next-line global-require
        const pkg = require('../../package.json');
        const versionName = String(pkg.version || '0.0.0');
        const buildNumber = Number(
          (pkg.build && pkg.build.buildVersion) || 1
        ) || 1;
        return {
          versionName,
          buildNumber,
          gitCommit: 'unknown',
          builtAt: null,
          channel: 'dev',
          display: `Version ${versionName} (Build ${buildNumber})`
        };
      } catch {
        /* ignore */
      }
    }
    if (typeof globalThis !== 'undefined' && globalThis.TtpVersion) {
      return globalThis.TtpVersion;
    }
    return {
      versionName: '0.0.0',
      buildNumber: 0,
      gitCommit: 'unknown',
      builtAt: null,
      channel: 'dev',
      display: 'Version 0.0.0 (Build 0)'
    };
  }

  const stamp = loadStamp();

  return {
    versionName: stamp.versionName,
    buildNumber: stamp.buildNumber,
    gitCommit: stamp.gitCommit || 'unknown',
    builtAt: stamp.builtAt || null,
    channel: stamp.channel || 'dev',
    display:
      stamp.display
      || `Version ${stamp.versionName} (Build ${stamp.buildNumber})`,
    /** Full object for IPC / diagnostics */
    toJSON() {
      return {
        versionName: this.versionName,
        buildNumber: this.buildNumber,
        gitCommit: this.gitCommit,
        builtAt: this.builtAt,
        channel: this.channel,
        display: this.display
      };
    }
  };
});
