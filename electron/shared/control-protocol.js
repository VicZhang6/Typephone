'use strict';

function buildControlRequest(command, payload, authToken) {
  const safePayload = payload && typeof payload === 'object' && !Array.isArray(payload)
    ? payload
    : {};
  // Trusted fields are assigned last so renderer payloads cannot override them.
  return { ...safePayload, command, authToken };
}

module.exports = { buildControlRequest };
