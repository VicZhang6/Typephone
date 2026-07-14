const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('macInput', {
  getStatus: () => ipcRenderer.invoke('native:get-status'),
  command: (command, payload = {}) => ipcRenderer.invoke('native:command', command, payload),
  hideWindow: () => ipcRenderer.send('window:hide'),
  onStatus: (listener) => {
    const handler = (_event, status) => listener(status);
    ipcRenderer.on('native:status', handler);
    return () => ipcRenderer.removeListener('native:status', handler);
  }
});
