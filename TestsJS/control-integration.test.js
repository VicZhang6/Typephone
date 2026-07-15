'use strict';

const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const crypto = require('node:crypto');
const net = require('node:net');
const test = require('node:test');

const binary = process.env.MAC_INPUT_TEST_BINARY;

function request(port, body, attempts = 30) {
  return new Promise((resolve, reject) => {
    const tryConnect = (remaining) => {
      const socket = net.createConnection({ host: '127.0.0.1', port });
      let buffer = '';
      socket.setEncoding('utf8');
      socket.once('connect', () => {
        socket.write(`${JSON.stringify(body)}\n`);
      });
      socket.on('data', (chunk) => {
        buffer += chunk;
        const newline = buffer.indexOf('\n');
        if (newline === -1) return;
        socket.end();
        resolve(JSON.parse(buffer.slice(0, newline)));
      });
      socket.once('error', (error) => {
        socket.destroy();
        if (remaining > 0 && error.code === 'ECONNREFUSED') {
          setTimeout(() => tryConnect(remaining - 1), 100);
          return;
        }
        reject(error);
      });
    };
    tryConnect(attempts);
  });
}

function sendOneWay(port, body) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: '127.0.0.1', port });
    socket.once('connect', () => {
      socket.end(`${JSON.stringify(body)}\n`, resolve);
    });
    socket.once('error', reject);
  });
}

function waitForLine(stream) {
  return new Promise((resolve, reject) => {
    let buffer = '';
    stream.setEncoding('utf8');
    stream.on('data', (chunk) => {
      buffer += chunk;
      const newline = buffer.indexOf('\n');
      if (newline !== -1) resolve(buffer.slice(0, newline));
    });
    stream.once('error', reject);
  });
}

function pidExists(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

async function waitForPidExit(pid, attempts = 50) {
  for (let index = 0; index < attempts; index += 1) {
    if (!pidExists(pid)) return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`Process ${pid} did not exit`);
}

test('native helper requires the inherited control token', {
  skip: !binary,
  timeout: 15000
}, async () => {
  const port = crypto.randomInt(49152, 65536);
  const authToken = crypto.randomBytes(32).toString('hex');
  const child = spawn(binary, ['--electron-helper'], {
    detached: false,
    stdio: ['ignore', 'ignore', 'ignore', 'pipe']
  });
  child.stdio[3].end(JSON.stringify({ port, authToken }));

  try {
    const unauthorized = await request(port, { command: 'getStatus' });
    assert.equal(unauthorized.type, 'error');
    assert.equal(unauthorized.message, 'Unauthorized');

    const status = await request(port, { command: 'getStatus', authToken });
    assert.equal(status.type, 'status');

    await sendOneWay(port, { command: 'shutdown', authToken });
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Helper did not exit')), 5000);
      child.once('exit', () => {
        clearTimeout(timer);
        resolve();
      });
    });
  } finally {
    if (child.exitCode === null && child.signalCode === null) {
      child.kill('SIGKILL');
    }
  }
});

test('native helper exits after its Electron parent dies', {
  skip: !binary,
  timeout: 15000
}, async () => {
  const parentScript = `
    const { spawn } = require('node:child_process');
    const crypto = require('node:crypto');
    const port = crypto.randomInt(49152, 65536);
    const authToken = crypto.randomBytes(32).toString('hex');
    const helper = spawn(process.env.MAC_INPUT_TEST_BINARY, ['--electron-helper'], {
      detached: false,
      stdio: ['ignore', 'ignore', 'ignore', 'pipe']
    });
    helper.stdio[3].end(JSON.stringify({ port, authToken }));
    process.stdout.write(JSON.stringify({ pid: helper.pid, port, authToken }) + '\\n');
    setInterval(() => {}, 1000);
  `;
  const parent = spawn(process.execPath, ['-e', parentScript], {
    env: process.env,
    stdio: ['ignore', 'pipe', 'ignore']
  });
  const details = JSON.parse(await waitForLine(parent.stdout));

  try {
    const status = await request(details.port, {
      command: 'getStatus',
      authToken: details.authToken
    });
    assert.equal(status.type, 'status');

    parent.kill('SIGKILL');
    await waitForPidExit(details.pid);
  } finally {
    if (pidExists(details.pid)) process.kill(details.pid, 'SIGKILL');
    if (parent.exitCode === null && parent.signalCode === null) parent.kill('SIGKILL');
  }
});
