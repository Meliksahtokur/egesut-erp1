/**
 * Agent Analyzer - AI Event Listener & Pattern Detector
 * 
 * WebSocket server'a bağlanır, browser event'lerini dinler
 * ve events.jsonl dosyasına yazar (agent okusun diye)
 */

import { WebSocket } from 'ws';

const WS_URL = 'ws://localhost:3002';

console.log('🤖 Agent Analyzer starting...');
console.log(`📡 Connecting to ${WS_URL}...`);

const ws = new WebSocket(`${WS_URL}?type=agent`);

ws.on('open', () => {
  console.log('✅ Connected to telemetry server');
  console.log('🎧 Listening for browser events...\n');
});

ws.on('message', (data) => {
  try {
    const event = JSON.parse(data.toString());
    handleEvent(event);
  } catch (err) {
    console.error('❌ Error parsing event:', err.message);
  }
});

ws.on('close', () => {
  console.log('📴 Disconnected from telemetry server');
});

ws.on('error', (err) => {
  console.error('❌ WebSocket error:', err.message);
});

// === EVENT HANDLER ===
function handleEvent(event) {
  const { type, payload, timestamp, sessionId } = event;
  
  // Format output
  const time = new Date(timestamp).toLocaleTimeString('tr-TR');
  
  switch (type) {
    case 'click':
      console.log(`🖱️  [${time}] Click: ${payload.tagName}${payload.id ? '#' + payload.id : ''}${payload.text ? ` "${payload.text}"` : ''}`);
      break;
      
    case 'submit':
      console.log(`📝 [${time}] Submit: ${payload.action || 'form'} (${payload.method})`);
      break;
      
    case 'fetch':
      console.log(`🌐 [${time}] Fetch: ${payload.method} ${payload.url} → ${payload.status} (${payload.duration}ms)`);
      break;
      
    case 'xhr':
      console.log(`📡 [${time}] XHR: ${payload.method} ${payload.url} → ${payload.status} (${payload.duration}ms)`);
      break;
      
    case 'error':
      console.error(`❌ [${time}] Error: ${payload.message} ${payload.source ? `(${payload.source}:${payload.lineno})` : ''}`);
      break;
      
    case 'unhandledrejection':
      console.error(`⚠️  [${time}] Unhandled Rejection: ${payload.reason}`);
      break;
      
    case 'console_log':
      console.log(`📋 [${time}] Console: ${payload.args.join(' ')}`);
      break;
      
    case 'console_warn':
      console.warn(`⚠️  [${time}] Warning: ${payload.args.join(' ')}`);
      break;
      
    case 'console_error':
      console.error(`❌ [${time}] Console Error: ${payload.args.join(' ')}`);
      break;
      
    default:
      console.log(`[${time}] ${type}:`, payload);
  }
}

// === SESSION SUMMARY ===
// Her 30 saniyede özet çıkar
setInterval(() => {
  console.log('\n--- Session Summary ---');
  console.log(`Active sessions: ${getSessionCount()}`);
  console.log('----------------------\n');
}, 30000);

function getSessionCount() {
  // Track unique sessions (in-memory for now)
  return new Set().size; // Placeholder
}

// === GRACEFUL SHUTDOWN ===
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down agent analyzer...');
  ws.close();
  process.exit(0);
});

console.log('\n✅ Agent Analyzer ready. Waiting for browser events...\n');
