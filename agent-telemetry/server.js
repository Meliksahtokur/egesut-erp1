/**
 * WebSocket Server - Browser Event Relay
 * Port: 3002
 * 
 * Browser'dan gelen event'leri alır, agent-analyzer'a iletir
 */

import { WebSocketServer } from 'ws';

const PORT = 3002;

const wss = new WebSocketServer({ port: PORT });

console.log(`📡 Telemetry WebSocket Server started on ws://localhost:${PORT}`);

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
import { appendFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const LOG_FILE = join(__dirname, 'events.jsonl');

function saveEvent(event) {
  try {
    // Append to JSONL file (one JSON per line)
    appendFileSync(LOG_FILE, JSON.stringify(event) + '\n');
  } catch (err) {
    console.error('❌ Failed to save event:', err.message);
  }
}

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down WebSocket server...');
  wss.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});
