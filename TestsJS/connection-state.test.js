'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { isPhoneConnected } = require('../electron/shared/connection-state');

test('active Central subscription wins over stale advertising state', () => {
  assert.equal(isPhoneConnected({
    status: 'advertising',
    isAdvertising: true,
    isConnected: true,
    isSubscribed: false
  }), true);
});

test('legacy input subscription still reports connected', () => {
  assert.equal(isPhoneConnected({ status: 'advertising', isSubscribed: true }), true);
});

test('advertising alone is not connected', () => {
  assert.equal(isPhoneConnected({ status: 'advertising', isAdvertising: true }), false);
});
