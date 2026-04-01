/**
 * WebSocket Server - Browser Event Relay
 * Dinamik port kullanır (çakışma önleme)
 */

import { WebSocketServer } from 'ws';
import { appendFileSync, existsSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT_FILE = join(__dirname, '.port');
const LOG_FILE = join(__dirname, 'events.jsonl');

// Port bul (çakışma önleme)
async function findAvailablePort(startPort = 3002) {
  for (let port = startPort; port < startPort + 100; port++) {
    try {
      const { createServer } = await import('node:http');
      await new Promise((resolve, reject) => {
        const server = createServer();
        server.on('error', reject);
        server.listen(port, () => {
          server.close(() => resolve(port));
        });
      });
      return port;
    } catch (err) {
      if (err.code !== 'EADDRINUSE') throw err;
      // Port dolu, devam et
    }
  }
  throw new Error('No available port found');
}

// Start server
const PORT = await findAvailablePort(3002);
const wss = new WebSocketServer({ port: PORT });

console.log(`📡 Telemetry WebSocket Server started on ws://localhost:${PORT}`);
console.log(`🌐 Browser UI: http://localhost:${PORT}/test`);

// Save port for clients
writeFileSync(PORT_FILE, String(PORT));

// Connected clients
const browsers = new Set();
const agents = new Set();

wss.on('connection', (ws, req) => {
  const clientId = `client-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
  
  // Check if this is an agent or browser connection
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const isAgent = url.searchParams.get('type') === 'agent';
  
  if (isAgent) {
    agents.add(ws);
    console.log(`🤖 Agent connected: ${clientId}`);
  } else {
    browsers.add(ws);
    console.log(`🎯 Browser connected: ${clientId}`);
  }
  
  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data.toString());
      const timestamp = new Date().toISOString();
      
      // Add server timestamp if not present
      if (!message.serverTime) {
        message.serverTime = timestamp;
      }
      
      // Log event
      console.log(`📩 [${message.type}]`, JSON.stringify(message.payload, null, 2));
      
      // Broadcast to all agents
      agents.forEach((agent) => {
        if (agent.readyState === 1) {
          agent.send(JSON.stringify(message));
        }
      });
      
      // Also save to file for persistence
      saveEvent(message);
      
    } catch (err) {
      console.error('❌ Error parsing message:', err.message);
    }
  });
  
  ws.on('close', () => {
    browsers.delete(ws);
    agents.delete(ws);
    console.log(`📴 Client disconnected: ${clientId}`);
  });
  
  ws.on('error', (err) => {
    console.error('❌ WebSocket error:', err.message);
  });
});

// Save events to file for agent to read
function saveEvent(event) {
  try {
    // Append to JSONL file (one JSON per line)
    appendFileSync(LOG_FILE, JSON.stringify(event) + '\n');
  } catch (err) {
    console.error('❌ Failed to save event:', err.message);
  }
}

// HTTP server for browser UI
import { createServer } from 'node:http';
import { readFileSync } from 'fs';

const httpServer = createServer((req, res) => {
  if (req.url === '/test' || req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(getTestUI(PORT));
  } else if (req.url === '/events') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    try {
      const events = existsSync(LOG_FILE) 
        ? readFileSync(LOG_FILE, 'utf-8').trim().split('\n').map(l => JSON.parse(l))
        : [];
      res.end(JSON.stringify({ events: events.slice(-50) })); // Son 50 event
    } catch {
      res.end(JSON.stringify({ events: [] }));
    }
  } else {
    res.writeHead(404);
    res.end('Not Found');
  }
});

httpServer.listen(PORT + 10000, () => {
  console.log(`📄 Test UI: http://localhost:${PORT + 10000}/test`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down WebSocket server...');
  wss.close(() => {
    httpServer.close(() => {
      console.log('✅ Server closed');
      process.exit(0);
    });
  });
});

// UI HTML
function getTestUI(port) {
  return `<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Agent Telemetry Test</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:system-ui,sans-serif;background:#1a1a2e;color:#eee;padding:20px;max-width:1200px;margin:0 auto}
h1{color:#4ecca3;margin-bottom:10px}
.status{display:flex;gap:20px;margin-bottom:20px}
.status-item{background:#2a2a3e;padding:15px 20px;border-radius:8px;border-left:4px solid #4ecca3}
.status-item.error{border-color:#e74c5c}
.btn{background:#4ecca3;color:#1a1a2e;border:none;padding:12px 24px;border-radius:6px;font-weight:600;cursor:pointer;margin:5px}
.btn:hover{background:#45b393}
.btn.danger{background:#e74c5c;color:#fff}
.btn.danger:hover{background:#c0392b}
.events{background:#2a2a3e;border-radius:8px;padding:20px;margin-top:20px;max-height:500px;overflow-y:auto}
.event{background:#1a1a2e;padding:12px;border-radius:6px;margin-bottom:10px;border-left:3px solid #4ecca3}
.event.error{border-color:#e74c5c}
.event.submit{border-color:#f39c12}
.event.fetch{border-color:#3498db}
.event-type{font-weight:700;color:#4ecca3;text-transform:uppercase;font-size:0.85rem}
.event-time{color:#888;font-size:0.85rem}
.event-payload{color:#bbb;margin-top:8px;font-family:monospace;font-size:0.9rem;white-space:pre-wrap;word-break:break-word}
.test-section{background:#2a2a3e;border-radius:8px;padding:20px;margin:20px 0}
.test-section h2{color:#4ecca3;margin-bottom:15px}
</style>
</head>
<body>
<h1>🎯 Agent Telemetry Test</h1>

<div class="status">
  <div class="status-item" id="ws-status">
    <strong>WebSocket:</strong> <span id="ws-state">Bağlanıyor...</span>
  </div>
  <div class="status-item">
    <strong>Port:</strong> <span id="port-display">${port}</span>
  </div>
  <div class="status-item">
    <strong>Events:</strong> <span id="event-count">0</span>
  </div>
</div>

<div class="test-section">
  <h2>🧪 Test Butonları</h2>
  <button class="btn" onclick="testClick()">🖱️ Click Test</button>
  <button class="btn" onclick="testSubmit()">📝 Submit Test</button>
  <button class="btn" onclick="testFetch()">🌐 Fetch Test</button>
  <button class="btn" onclick="testError()">❌ Error Test</button>
  <button class="btn" onclick="testConsole()">📋 Console Test</button>
  <button class="btn danger" onclick="clearEvents()">🗑️ Temizle</button>
</div>

<form id="test-form" style="margin:15px 0;padding:15px;background:#1a1a2e;border-radius:8px">
  <input type="text" id="test-input" placeholder="Test input..." style="padding:10px;border-radius:6px;border:1px solid #444;background:#2a2a3e;color:#eee;width:300px;margin-right:10px">
  <button type="submit" class="btn">Form Submit</button>
</form>

<div class="events" id="events-container">
  <h2 style="color:#4ecca3;margin-bottom:15px">📊 Son Event'ler</h2>
  <div id="events-list"></div>
</div>

<script>
const WS_PORT = ${port};
let ws = null;
let eventCount = 0;

function connect() {
  ws = new WebSocket('ws://localhost:' + WS_PORT);
  
  ws.onopen = () => {
    document.getElementById('ws-state').textContent = '✅ Bağlı';
    document.getElementById('ws-state').style.color = '#4ecca3';
  };
  
  ws.onclose = () => {
    document.getElementById('ws-state').textContent = '❌ Bağlantı koptu';
    document.getElementById('ws-state').style.color = '#e74c5c';
    setTimeout(connect, 2000);
  };
  
  ws.onerror = () => {
    document.getElementById('ws-state').textContent = '❌ Hata';
    document.getElementById('ws-state').style.color = '#e74c5c';
  };
  
  ws.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data);
      addEvent(data);
    } catch (err) {
      console.error('Invalid event:', err);
    }
  };
}

function addEvent(data) {
  eventCount++;
  document.getElementById('event-count').textContent = eventCount;
  
  const container = document.getElementById('events-list');
  const eventDiv = document.createElement('div');
  eventDiv.className = 'event ' + data.type;
  
  const time = new Date(data.timestamp).toLocaleTimeString('tr-TR');
  eventDiv.innerHTML = \`
    <div class="event-type">\${data.type} <span class="event-time">\${time}</span></div>
    <div class="event-payload">\${JSON.stringify(data.payload, null, 2)}</div>
  \`;
  
  container.insertBefore(eventDiv, container.firstChild);
  
  // Keep only last 100 events
  while (container.children.length > 100) {
    container.removeChild(container.lastChild);
  }
}

// Test functions
function testClick() {
  console.log('🖱️ Click test button clicked!');
}

function testSubmit() {
  document.getElementById('test-form').requestSubmit();
}

function testFetch() {
  fetch('https://jsonplaceholder.typicode.com/posts/1')
    .then(r => r.json())
    .then(d => console.log('Fetch result:', d))
    .catch(e => console.error('Fetch error:', e));
}

function testError() {
  throw new Error('Test hatası - ' + Date.now());
}

function testConsole() {
  console.log('📋 Test log:', Date.now());
  console.warn('⚠️ Test warning:', Date.now());
  console.error('❌ Test error:', Date.now());
}

function clearEvents() {
  document.getElementById('events-list').innerHTML = '';
  eventCount = 0;
  document.getElementById('event-count').textContent = '0';
}

// Form submit handler
document.getElementById('test-form').addEventListener('submit', (e) => {
  e.preventDefault();
  const value = document.getElementById('test-input').value;
  console.log('📝 Form submitted with:', value);
  document.getElementById('test-input').value = '';
});

// Connect on load
connect();
</script>
</body>
</html>`;
}
