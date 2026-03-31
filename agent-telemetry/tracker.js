/**
 * Browser Event Tracker - Client-side Instrumentation
 * 
 * Kullanım: <script src="tracker.js"></script> index.html'e ekle
 * Otomatik olarak telemetry server'ı bulur ve bağlanır
 */

(function() {
  'use strict';
  
  // === CONFIG ===
  // Telemetry server port'unu bul (dene-yanıl)
  const TELEMETRY_PORTS = [3002, 3003, 3004, 3005, 3006]; // Denenecek port'lar
  let WS_URL = null;
  
  // === STATE ===
  let ws = null;
  let lastEventTime = 0;
  let isTracking = false; // Anti-infinite-loop guard
  let eventQueue = [];
  let reconnectAttempts = 0;
  const MAX_RECONNECT_ATTEMPTS = 5;
  
  // === FIND TELEMETRY SERVER ===
  async function findTelemetryServer() {
    for (const port of TELEMETRY_PORTS) {
      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 500);
        
        const response = await fetch(`http://localhost:${port}/.port`, {
          signal: controller.signal
        });
        
        clearTimeout(timeout);
        
        if (response.ok) {
          const telemetryPort = await response.text();
          WS_URL = `ws://localhost:${telemetryPort.trim()}`;
          console.log('✅ Telemetry server found:', WS_URL);
          return true;
        }
      } catch (err) {
        // Port dolu değil veya server yok, devam et
      }
    }
    
    // Fallback: direkt WebSocket dene
    for (const port of TELEMETRY_PORTS) {
      try {
        const testWs = new WebSocket(`ws://localhost:${port}`);
        await new Promise((resolve, reject) => {
          testWs.onopen = () => { testWs.close(); resolve(); };
          testWs.onerror = () => reject();
          setTimeout(reject, 500);
        });
        WS_URL = `ws://localhost:${port}`;
        console.log('✅ Telemetry server found (fallback):', WS_URL);
        return true;
      } catch (err) {
        // Continue
      }
    }
    
    console.warn('⚠️ No telemetry server found, will retry on connect');
    return false;
  }
  
  // === CORE TRANSPORT ===
  async function connect() {
    if (ws && ws.readyState === WebSocket.OPEN) {
      return;
    }
    
    // Find server if not found yet
    if (!WS_URL) {
      const found = await findTelemetryServer();
      if (!found) {
        // Retry later
        setTimeout(connect, 2000);
        return;
      }
    }
    
    try {
      ws = new WebSocket(WS_URL);
      
      ws.onopen = () => {
        console.log('✅ Telemetry connected to', WS_URL);
        reconnectAttempts = 0;
        flushQueue();
      };
      
      ws.onclose = () => {
        console.log('📴 Telemetry disconnected');
        attemptReconnect();
      };
      
      ws.onerror = (err) => {
        console.error('❌ Telemetry WebSocket error:', err.message);
      };
      
      ws.onmessage = (event) => {
        // Ignore messages from server (we only send)
      };
      
    } catch (err) {
      console.error('❌ Failed to connect telemetry:', err.message);
      WS_URL = null; // Reset, retry find
      setTimeout(connect, 2000);
    }
  }
  
  function attemptReconnect() {
    if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
      reconnectAttempts++;
      console.log(`🔄 Reconnecting... (${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})`);
      setTimeout(connect, 1000 * reconnectAttempts);
    } else {
      // Reset and try to find server again
      reconnectAttempts = 0;
      WS_URL = null;
      setTimeout(connect, 2000);
    }
  }
  
  function flushQueue() {
    while (eventQueue.length > 0) {
      const event = eventQueue.shift();
      sendEvent(event.type, event.payload);
    }
  }
  
  function sendEvent(type, payload) {
    // Anti-infinite-loop guard
    if (isTracking) {
      return;
    }
    
    isTracking = true;
    
    try {
      // Throttle check
      const now = Date.now();
      if (now - lastEventTime < 200) { // 200ms throttle
        // Queue high-frequency events
        eventQueue.push({ type, payload });
        return;
      }
      lastEventTime = now;
      
      const event = {
        type,
        payload,
        timestamp: new Date().toISOString(),
        sessionId: getSessionId()
      };
      
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(event));
      } else {
        eventQueue.push({ type, payload: event });
      }
      
    } catch (err) {
      console.error('❌ Failed to send event:', err.message);
    } finally {
      isTracking = false;
    }
  }
  
  function getSessionId() {
    let id = sessionStorage.getItem('telemetry_session_id');
    if (!id) {
      id = 'session-' + Date.now() + '-' + Math.random().toString(36).slice(2, 7);
      sessionStorage.setItem('telemetry_session_id', id);
    }
    return id;
  }
  
  // === EVENT LISTENERS ===
  
  // Click tracking
  document.addEventListener('click', (e) => {
    const target = e.target;
    const tagName = target.tagName;
    const id = target.id || null;
    const className = target.className || null;
    
    // Get text content (truncated)
    let text = target.innerText || target.textContent || '';
    text = text.trim().slice(0, 50);
    if (text.length === 50) text += '...';
    
    // Ignore if no actionable identifiers
    if (!id && !className && tagName === 'DIV') {
      return;
    }
    
    sendEvent('click', {
      tagName,
      id,
      className,
      text: text || null,
      selector: getSelector(target)
    });
  }, true);
  
  // Submit tracking
  document.addEventListener('submit', (e) => {
    const form = e.target;
    sendEvent('submit', {
      action: form.action || null,
      id: form.id || null,
      className: form.className || null,
      method: form.method || 'POST'
    });
  }, true);
  
  // === ADVANCED OBSERVABILITY (Monkey Patches) ===
  
  // Fetch hook
  (function() {
    const originalFetch = window.fetch;
    if (!originalFetch) return;
    
    window.fetch = async function(input, init = {}) {
      const url = typeof input === 'string' ? input : input.url;
      const method = init.method || (typeof input === 'object' ? input.method : 'GET');
      const startTime = performance.now();
      
      // Skip telemetry WS traffic
      if (url.includes('localhost:300') || url.includes('ws://') || url.includes('.port')) {
        return originalFetch.apply(this, arguments);
      }
      
      try {
        const response = await originalFetch.apply(this, arguments);
        const duration = Math.round(performance.now() - startTime);
        
        sendEvent('fetch', {
          url,
          method,
          status: response.status,
          duration
        });
        
        return response;
        
      } catch (err) {
        const duration = Math.round(performance.now() - startTime);
        sendEvent('fetch_error', {
          url,
          method,
          error: err.message,
          duration
        });
        throw err;
      }
    };
  })();
  
  // XHR hook (for legacy/Axios support)
  (function() {
    const originalXHR = window.XMLHttpRequest;
    if (!originalXHR) return;
    
    const originalOpen = originalXHR.prototype.open;
    const originalSend = originalXHR.prototype.send;
    
    originalXHR.prototype.open = function(method, url, ...args) {
      this._telemetry = { method, url, startTime: null };
      return originalOpen.apply(this, [method, url, ...args]);
    };
    
    originalXHR.prototype.send = function(...args) {
      const telemetry = this._telemetry;
      if (telemetry) {
        telemetry.startTime = performance.now();
        
        // Skip telemetry WS traffic
        if (telemetry.url.includes('localhost:300') || telemetry.url.includes('ws://')) {
          return originalSend.apply(this, args);
        }
        
        this.addEventListener('load', () => {
          const duration = Math.round(performance.now() - telemetry.startTime);
          sendEvent('xhr', {
            url: telemetry.url,
            method: telemetry.method,
            status: this.status,
            duration
          });
        });
        
        this.addEventListener('error', () => {
          const duration = Math.round(performance.now() - telemetry.startTime);
          sendEvent('xhr_error', {
            url: telemetry.url,
            method: telemetry.method,
            duration
          });
        });
      }
      
      return originalSend.apply(this, args);
    };
  })();
  
  // Console hook (with anti-infinite-loop guard)
  (function() {
    const originalLog = console.log;
    const originalWarn = console.warn;
    const originalError = console.error;
    
    let isLogging = false;
    
    function wrapLog(original, level) {
      return function(...args) {
        if (isLogging) {
          return original.apply(console, args);
        }
        
        isLogging = true;
        
        try {
          // Skip telemetry logs
          if (args.some(a => String(a).includes('Telemetry'))) {
            return original.apply(console, args);
          }
          
          sendEvent('console_' + level, {
            args: args.map(a => String(a).slice(0, 200))
          });
          
        } catch (err) {
          // Silent fail to prevent loops
        } finally {
          isLogging = false;
        }
        
        return original.apply(console, args);
      };
    }
    
    console.log = wrapLog(originalLog, 'log');
    console.warn = wrapLog(originalWarn, 'warn');
    console.error = wrapLog(originalError, 'error');
  })();
  
  // Error tracking
  window.addEventListener('error', (e) => {
    sendEvent('error', {
      message: e.message,
      source: e.filename || null,
      lineno: e.lineno,
      colno: e.colno,
      error: e.error?.toString() || null
    });
  });
  
  window.addEventListener('unhandledrejection', (e) => {
    sendEvent('unhandledrejection', {
      reason: e.reason?.toString() || 'Unknown promise rejection',
      promise: e.promise?.toString() || null
    });
  });
  
  // === UTILS ===
  function getSelector(el) {
    if (el.id) return '#' + el.id;
    if (el.className && typeof el.className === 'string') {
      return el.tagName.toLowerCase() + '.' + el.className.split(' ').join('.');
    }
    return el.tagName.toLowerCase();
  }
  
  // === INIT ===
  console.log('✅ Browser telemetry initialized');
  
  // Session tracking (test başlangıç/bitiş)
  window.agentTestSession = {
    start: function() {
      const ts = Date.now();
      sessionStorage.setItem('test_start', ts);
      console.log('🎯 Test session started:', new Date(ts).toISOString());
      sendEvent('test_start', { timestamp: new Date(ts).toISOString() });
    },
    end: function() {
      const start = sessionStorage.getItem('test_start');
      const end = Date.now();
      sessionStorage.setItem('test_end', end);
      const duration = end - parseInt(start);
      console.log('🏁 Test session ended:', new Date(end).toISOString(), `Duration: ${duration}ms`);
      sendEvent('test_end', { 
        timestamp: new Date(end).toISOString(),
        startTime: start ? new Date(parseInt(start)).toISOString() : null,
        duration
      });
    },
    getTimestamps: function() {
      const start = sessionStorage.getItem('test_start');
      const end = sessionStorage.getItem('test_end');
      return {
        startTime: start ? new Date(parseInt(start)).toISOString() : null,
        endTime: end ? new Date(parseInt(end)).toISOString() : null
      };
    }
  };
  
  console.log('💡 Usage: window.agentTestSession.start() / end()');
  
})();
