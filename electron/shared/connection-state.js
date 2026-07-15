/** Shared connection-state rules for the Electron window and status menu. */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.TtpConnectionState = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  function isPhoneConnected(status = {}) {
    return status.status === 'connected'
      || Boolean(status.isConnected)
      || Boolean(status.isSubscribed);
  }

  return { isPhoneConnected };
});
