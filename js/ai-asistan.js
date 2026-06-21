// AI Asistan — frontend (vanilla, mevcut db/window kalıbı)
const ASISTAN_FN_URL = 'https://zqnexqbdfvbhlxzelzju.supabase.co/functions/v1/ai-agent';
let _asistanThreadId = null;
let _asistanBekliyor = false;

async function _asistanToken() {
  const { data } = await window.db.auth.getSession();
  return data?.session?.access_token || null;
}

function _asistanEsc(s) {
  return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// MiniMax-M3 <think> bloklarını canlı akışta gizle (tamamlanmış + açık kalmış)
function _asistanStripThink(s) {
  let t = (s || '').replace(/<think>[\s\S]*?<\/think>/g, ''); // eşli blok
  t = t.replace(/<think>[\s\S]*$/, '');                       // kapanmamış blok → sonuna kadar gizle
  t = t.replace(/<\/?think>/g, '');                           // öksüz açılış/kapanış etiketi
  return t.trim();
}

// assistant cevabını 3 katman + katlanır SQL ile render et
function _asistanCevapHtml(text, sql) {
  let html = _asistanEsc(_asistanStripThink(text)).replace(/\n/g, '<br>');
  if (sql) {
    html += `<details style="margin-top:8px"><summary style="cursor:pointer;color:var(--ink3);font-size:.75rem">▸ Çalıştırılan SQL</summary>
      <pre style="white-space:pre-wrap;background:var(--bg2);padding:8px;border-radius:8px;font-size:.7rem;margin-top:4px">${_asistanEsc(sql)}</pre></details>`;
  }
  return html;
}

function _asistanBalon(rol, html) {
  const sag = rol === 'user';
  const div = document.createElement('div');
  div.style.cssText = `max-width:85%;align-self:${sag ? 'flex-end' : 'flex-start'};background:${sag ? 'var(--green)' : 'var(--card)'};color:${sag ? '#fff' : 'var(--ink)'};padding:10px 14px;border-radius:14px;font-size:.85rem;line-height:1.4;word-break:break-word`;
  div.innerHTML = html;
  return div;
}

async function asistanGonder(soru) {
  if (_asistanBekliyor) return;
  const inp = document.getElementById('asistan-input');
  const mesaj = (soru || (inp ? inp.value : '') || '').trim();
  if (!mesaj) return;
  if (inp) inp.value = '';
  const bos = document.getElementById('asistan-bos');
  if (bos) bos.style.display = 'none';

  const box = document.getElementById('asistan-mesajlar');
  box.appendChild(_asistanBalon('user', _asistanEsc(mesaj)));
  const cevapDiv = _asistanBalon('assistant', '<span style="color:var(--ink3)">···</span>');
  box.appendChild(cevapDiv);
  cevapDiv.scrollIntoView({ behavior: 'smooth' });

  const token = await _asistanToken();
  if (!token) { cevapDiv.innerHTML = 'Oturum gerekli — lütfen tekrar giriş yapın.'; return; }

  _asistanBekliyor = true;
  try {
    const resp = await fetch(ASISTAN_FN_URL, {
      method: 'POST',
      headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
      body: JSON.stringify({ mesaj, thread_id: _asistanThreadId }),
    });
    const tid = resp.headers.get('X-Thread-Id');
    if (tid) _asistanThreadId = tid;
    if (!resp.ok) { cevapDiv.innerHTML = 'Asistana ulaşılamadı (' + resp.status + ').'; return; }

    const reader = resp.body.getReader();
    const dec = new TextDecoder();
    let acc = '';
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      acc += dec.decode(value, { stream: true });
      const goster = _asistanStripThink(acc);
      cevapDiv.innerHTML = goster
        ? _asistanEsc(goster).replace(/\n/g, '<br>')
        : '<span style="color:var(--ink3)">🤔 düşünüyor…</span>';
      cevapDiv.scrollIntoView({ behavior: 'smooth' });
    }
    // Stream bitti — SQL metadata'sını DB'den çek ve katlanır panel ekle
    cevapDiv.innerHTML = _asistanCevapHtml(acc, await _asistanSonSql());
  } catch (e) {
    cevapDiv.innerHTML = 'Bağlantı hatası: ' + _asistanEsc(String(e));
  } finally {
    _asistanBekliyor = false;
  }
}

async function _asistanSonSql() {
  if (!_asistanThreadId) return null;
  const { data } = await window.db.from('agent_messages')
    .select('metadata').eq('thread_id', _asistanThreadId).eq('rol', 'assistant')
    .order('created_at', { ascending: false }).limit(1);
  return data?.[0]?.metadata?.sql || null;
}

function asistanYeniSohbet() {
  _asistanThreadId = null;
  document.getElementById('asistan-mesajlar').innerHTML = '';
  const bos = document.getElementById('asistan-bos');
  if (bos) bos.style.display = '';
}

function asistanInit() {
  if (!_asistanThreadId) asistanYeniSohbet();
  const inp = document.getElementById('asistan-input');
  if (inp) setTimeout(() => inp.focus(), 100);
}

async function asistanGecmisAc() {
  const list = document.getElementById('asistan-thread-list');
  list.innerHTML = 'Yükleniyor...';
  document.getElementById('asistan-drawer').style.display = 'flex';
  const { data } = await window.db.from('agent_threads')
    .select('id, baslik, updated_at').order('updated_at', { ascending: false }).limit(100);
  if (!data || !data.length) { list.innerHTML = '<div style="color:var(--ink3)">Henüz konuşma yok.</div>'; return; }
  list.innerHTML = '';
  data.forEach(t => {
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;align-items:center;justify-content:space-between;gap:8px;padding:8px;border-radius:8px;background:var(--card)';
    row.innerHTML = `<span style="flex:1;cursor:pointer;font-size:.82rem;color:var(--ink)" data-action="asistan-thread-ac" data-tid="${t.id}">💬 ${_asistanEsc(t.baslik)}</span>
      <button class="btn" data-action="asistan-thread-sil" data-tid="${t.id}" style="padding:3px 8px;width:auto;color:var(--red);background:none">🗑</button>`;
    list.appendChild(row);
  });
}

function asistanDrawerKapat() {
  document.getElementById('asistan-drawer').style.display = 'none';
}

async function asistanThreadAc(tid) {
  _asistanThreadId = tid;
  asistanDrawerKapat();
  const box = document.getElementById('asistan-mesajlar');
  box.innerHTML = '';
  const bos = document.getElementById('asistan-bos');
  if (bos) bos.style.display = 'none';
  const { data } = await window.db.from('agent_messages')
    .select('rol, icerik, metadata').eq('thread_id', tid).order('created_at', { ascending: true });
  (data || []).forEach(m => {
    const html = m.rol === 'assistant' ? _asistanCevapHtml(m.icerik, m.metadata?.sql) : _asistanEsc(m.icerik);
    box.appendChild(_asistanBalon(m.rol, html));
  });
}

async function asistanThreadSil(tid) {
  await window.db.from('agent_threads').delete().eq('id', tid);
  if (_asistanThreadId === tid) asistanYeniSohbet();
  asistanGecmisAc();
}

async function asistanTumunuSil() {
  if (!confirm('Tüm sohbet geçmişi silinecek. Emin misiniz?')) return;
  const { data } = await window.db.from('agent_threads').select('id');
  for (const t of (data || [])) await window.db.from('agent_threads').delete().eq('id', t.id);
  asistanYeniSohbet();
  asistanDrawerKapat();
}

window.asistanGonder = asistanGonder;
window.asistanYeniSohbet = asistanYeniSohbet;
window.asistanInit = asistanInit;
window.asistanGecmisAc = asistanGecmisAc;
window.asistanDrawerKapat = asistanDrawerKapat;
window.asistanThreadAc = asistanThreadAc;
window.asistanThreadSil = asistanThreadSil;
window.asistanTumunuSil = asistanTumunuSil;
