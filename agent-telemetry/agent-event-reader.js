/**
 * Agent Event Reader - Incremental Log Okuma + DB Telemetry
 * 
 * Her seferinde SADECE YENİ event'leri okur
 * Browser + DB event'lerini birleştirir
 * Context'i doldurmaz, özet çıkarır
 */

import { readFileSync, existsSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const LOG_FILE = join(__dirname, 'events.jsonl');
const STATE_FILE = join(__dirname, '.agent-state.json');

// Agent state (hangi satırda kaldık)
function loadState() {
  if (existsSync(STATE_FILE)) {
    return JSON.parse(readFileSync(STATE_FILE, 'utf-8'));
  }
  return { lastLine: 0, lastSession: null, lastReadTime: null, testStart: null, testEnd: null };
}

function saveState(state) {
  writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

// Son N satırı oku (tersine)
function readLastNLines(filePath, n = 50) {
  if (!existsSync(filePath)) {
    return [];
  }
  
  const content = readFileSync(filePath, 'utf-8').trim();
  if (!content) return [];
  
  const lines = content.split('\n');
  return lines.slice(-n);
}

// Event'leri parse et
function parseEvents(lines) {
  return lines.map(line => {
    try {
      return JSON.parse(line);
    } catch (err) {
      return null;
    }
  }).filter(Boolean);
}

// Yeni event'leri bul (son okumadan beri)
function getNewEvents(state) {
  const lines = readLastNLines(LOG_FILE, 200); // Son 200 event
  const events = parseEvents(lines);
  
  // Eğer daha önce okumadıysa, son 10 event'i dön
  if (state.lastLine === 0) {
    return events.slice(-10);
  }
  
  // Yeni event'leri filtrele (timestamp bazlı)
  const newEvents = events.filter(e => {
    return e.serverTime > state.lastReadTime;
  });
  
  return newEvents;
}

// Event'leri özetle (context-friendly)
function summarizeEvents(events) {
  if (!events.length) {
    return {
      summary: 'Yeni aktivite yok',
      actions: [],
      apiCalls: [],
      errors: [],
      context: ''
    };
  }
  
  const actions = [];
  const apiCalls = [];
  const errors = [];
  
  events.forEach(e => {
    const time = new Date(e.timestamp).toLocaleTimeString('tr-TR');
    
    switch (e.type) {
      case 'click':
        actions.push({
          type: 'click',
          time,
          target: e.payload.text || e.payload.id || e.payload.tagName,
          selector: e.payload.selector
        });
        break;
        
      case 'submit':
        actions.push({
          type: 'submit',
          time,
          form: e.payload.id || e.payload.action
        });
        break;
        
      case 'fetch':
      case 'xhr':
        if (e.payload.status >= 400) {
          errors.push({
            type: e.type,
            time,
            url: e.payload.url,
            status: e.payload.status,
            error: `${e.payload.status} ${e.payload.method}`
          });
        } else {
          apiCalls.push({
            type: e.type,
            time,
            method: e.payload.method,
            url: shortenUrl(e.payload.url),
            status: e.payload.status,
            duration: e.payload.duration
          });
        }
        break;
        
      case 'error':
      case 'unhandledrejection':
        errors.push({
          type: e.type,
          time,
          message: e.payload.message || e.payload.reason
        });
        break;
    }
  });
  
  // Özet çıkar
  const summary = generateSummary(actions, apiCalls, errors);
  
  // Context string'i (kısa, öz)
  const context = buildContext(actions, apiCalls, errors);
  
  return { summary, actions, apiCalls, errors, context };
}

// URL kısalt (context tasarrufu)
function shortenUrl(url) {
  // Supabase URL'lerini kısalt
  if (url.includes('supabase.co/rest/v1/')) {
    const match = url.match(/rest\/v1\/([^?]+)/);
    if (match) return `rpc/${match[1]}`;
  }
  // Domain'i kaldır
  try {
    const u = new URL(url);
    return u.pathname + u.search;
  } catch {
    return url;
  }
}

// Özet metin oluştur
function generateSummary(actions, apiCalls, errors) {
  const parts = [];
  
  if (actions.length) {
    const lastAction = actions[actions.length - 1];
    parts.push(`Son işlem: ${lastAction.type} "${lastAction.target || lastAction.form}"`);
  }
  
  if (apiCalls.length) {
    const failed = apiCalls.filter(a => a.status >= 400).length;
    if (failed > 0) {
      parts.push(`${failed} API hatası`);
    } else {
      parts.push(`${apiCalls.length} API çağrı başarılı`);
    }
  }
  
  if (errors.length) {
    parts.push(`${errors.length} hata`);
  }
  
  return parts.join(' • ') || 'Aktivite yok';
}

// Context string'i build et (agent'ın anlayacağı dil)
function buildContext(actions, apiCalls, errors) {
  const lines = [];
  
  // Son 5 action
  if (actions.length) {
    lines.push('\n📋 Son İşlemler:');
    actions.slice(-5).forEach(a => {
      lines.push(`  [${a.time}] ${a.type.toUpperCase()} ${a.target || a.form}`);
    });
  }
  
  // Son 3 API çağrı
  if (apiCalls.length) {
    lines.push('\n🌐 API Çağrıları:');
    apiCalls.slice(-3).forEach(a => {
      lines.push(`  [${a.time}] ${a.method} ${a.url} → ${a.status} (${a.duration}ms)`);
    });
  }
  
  // Hatalar
  if (errors.length) {
    lines.push('\n❌ Hatalar:');
    errors.forEach(e => {
      lines.push(`  [${e.time}] ${e.type}: ${e.message || e.error}`);
    });
  }
  
  return lines.join('\n') || '\n📊 Yeni aktivite yok';
}

// Ana fonksiyon: Agent bunu çağırır
export function readAgentEvents(options = {}) {
  const state = loadState();
  
  // Eğer test session varsa, o session'ı oku
  if (options.testSession || state.testStart) {
    const startTime = options.testSession?.startTime || state.testStart;
    const endTime = options.testSession?.endTime || state.testEnd || new Date().toISOString();
    
    if (startTime) {
      // DB telemetry çağrısı için state hazırla
      return {
        hasNew: true,
        isDbTelemetry: true,
        testSession: { startTime, endTime },
        summary: `Test session: ${new Date(startTime).toLocaleTimeString('tr-TR')} - ${new Date(endTime).toLocaleTimeString('tr-TR')}`,
        context: `📊 DB Telemetry için MCP çağır:\n  get_db_telemetry("${startTime}", "${endTime}")\n  verify_transaction_integrity("ISLEM_TIP", "ref_id")`,
        raw: []
      };
    }
  }
  
  const newEvents = getNewEvents(state);
  
  if (!newEvents.length) {
    return {
      hasNew: false,
      summary: 'Yeni aktivite yok',
      context: '',
      raw: []
    };
  }
  
  const result = summarizeEvents(newEvents);
  
  // State güncelle
  state.lastReadTime = new Date().toISOString();
  state.lastLine = newEvents.length;
  state.lastSession = newEvents[0]?.sessionId || null;
  
  // Test session bilgisi varsa kaydet
  const testStartEvent = newEvents.find(e => e.type === 'test_start');
  const testEndEvent = newEvents.find(e => e.type === 'test_end');
  
  if (testStartEvent) {
    state.testStart = testStartEvent.payload.timestamp;
  }
  if (testEndEvent) {
    state.testEnd = testEndEvent.payload.timestamp || new Date().toISOString();
  }
  
  saveState(state);
  
  return {
    hasNew: true,
    summary: result.summary,
    context: result.context,
    actions: result.actions,
    apiCalls: result.apiCalls,
    errors: result.errors,
    raw: newEvents,
    count: newEvents.length
  };
}

// CLI mode (test için)
if (process.argv[1]?.includes('agent-event-reader')) {
  const result = readAgentEvents();
  
  console.log('\n=== AGENT EVENT READER ===\n');
  console.log('Yeni event var mı:', result.hasNew);
  console.log('Event sayısı:', result.count || 0);
  console.log('\n📊 ÖZET:');
  console.log(result.summary);
  console.log('\n📝 CONTEXT:');
  console.log(result.context);
  console.log('\n========================\n');
}
