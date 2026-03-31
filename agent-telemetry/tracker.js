/**
 * Browser Event Tracker - Client-side Instrumentation
 * 
 * Kullanım: <script src="tracker.js"></script> index.html'e ekle
 * 
 * Track edilen event'ler:
 * - click, submit, fetch, xhr, error, console_log
 */

(function() {
  'use strict';
  
  // === CONFIG ===
  const WS_URL = 'ws://localhost:3002';
  const THROTTLE_MS = 200;
  const MAX_TEXT_LENGTH = 50;
  
  // === STATE ===
  let ws = null;
  let lastEventTime = 0;
  let isTracking = false; // Anti-infinite-loop guard
  let eventQueue = [];
  let reconnectAttempts = 0;
  const MAX_RECONNECT_ATTEMPTS = 5;
  
  // === CORE TRANSPORT ===
  function connect() {
    if (ws && ws.readyState === WebSocket.OPEN) {
      return;
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
    }
  }
  
  function attemptReconnect() {
    if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
      reconnectAttempts++;
      console.log(`🔄 Reconnecting... (${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})`);
      setTimeout(connect, 1000 * reconnectAttempts);
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
      if (now - lastEventTime < THROTTLE_MS) {
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
    text = text.trim().slice(0, MAX_TEXT_LENGTH);
    if (text.length === MAX_TEXT_LENGTH) text += '...';
    
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
      if (url.includes('localhost:3002') || url.includes('ws://')) {
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
        if (telemetry.url.includes('localhost:3002') || telemetry.url.includes('ws://')) {
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
  connect();
  console.log('✅ Browser telemetry initialized');
  
})();
