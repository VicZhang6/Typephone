'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { buildControlRequest } = require('../electron/shared/control-protocol');

test('trusted command and token cannot be overwritten by payload', () => {
  const request = buildControlRequest(
    'sendA',
    { command: 'shutdown', authToken: 'attacker', mode: 'mirror' },
    'trusted-token'
  );

  assert.deepEqual(request, {
    command: 'sendA',
    authToken: 'trusted-token',
    mode: 'mirror'
  });
});

test('non-object payload is ignored', () => {
  assert.deepEqual(buildControlRequest('getStatus', null, 'token'), {
    command: 'getStatus',
    authToken: 'token'
  });
});
