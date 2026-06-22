// AI Asistan — frontend (vanilla, mevcut db/window kalıbı)
const ASISTAN_FN_URL = 'https://zqnexqbdfvbhlxzelzju.supabase.co/functions/v1/ai-agent';
let _asistanThreadId = null;
let _asistanBekliyor = false;
let _asistanAbort = null;

// Gönder butonunu yazma sırasında ⏹ Durdur'a çevir
function _asistanBtnDurum(yaziyor) {
  const btn = document.getElementById('asistan-gonder-btn');
  if (!btn) return;
  btn.textContent = yaziyor ? '⏹' : '➤';
  btn.style.background = yaziyor ? 'var(--red)' : 'var(--green)';
  btn.title = yaziyor ? 'Durdur' : 'Gönder';
}

// Textarea içerikle birlikte büyüsün (max 140px)
function _asistanAutoGrow(inp) {
  inp.style.height = 'auto';
  inp.style.height = Math.min(inp.scrollHeight, 140) + 'px';
}
function _asistanInputReset() {
  const inp = document.getElementById('asistan-input');
  if (inp) { inp.value = ''; inp.style.height = 'auto'; }
}

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
  // Yazma sürerken butona tekrar basmak = DURDUR
  if (_asistanBekliyor) { if (_asistanAbort) _asistanAbort.abort(); return; }
  const inp = document.getElementById('asistan-input');
  const mesaj = (soru || (inp ? inp.value : '') || '').trim();
  if (!mesaj) return;
  _asistanInputReset();
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
  _asistanAbort = new AbortController();
  _asistanBtnDurum(true);
  let acc = '';
  try {
    const resp = await fetch(ASISTAN_FN_URL, {
      method: 'POST',
      headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
      body: JSON.stringify({ mesaj, thread_id: _asistanThreadId }),
      signal: _asistanAbort.signal,
    });
    const tid = resp.headers.get('X-Thread-Id');
    if (tid) _asistanThreadId = tid;
    if (!resp.ok) { cevapDiv.innerHTML = 'Asistana ulaşılamadı (' + resp.status + ').'; return; }

    const reader = resp.body.getReader();
    const dec = new TextDecoder();
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
    // Onay bekleyen plan varsa diff kartını göster
    const meta = await _asistanSonMeta();
    const plan = meta?.plan;
    if (plan && plan.ok && plan.plan_id && Array.isArray(plan.onizleme)) {
      _asistanPlanKarti(box, plan);
    }
    // Uygulanmış plan varsa "Geri Al" kartını göster
    if (meta?.applied?.plan_id) {
      _asistanUndoKarti(box, meta.applied.plan_id);
    }
  } catch (e) {
    if (e && e.name === 'AbortError') {
      // Kullanıcı durdurdu — o ana kadarki kısmî cevabı koru
      const kismi = _asistanStripThink(acc);
      cevapDiv.innerHTML = (kismi ? _asistanEsc(kismi).replace(/\n/g, '<br>') : '')
        + '<div style="margin-top:6px;font-size:.7rem;color:var(--ink3)">⏹ durduruldu</div>';
    } else {
      cevapDiv.innerHTML = 'Bağlantı hatası: ' + _asistanEsc(String(e));
    }
  } finally {
    _asistanBekliyor = false;
    _asistanAbort = null;
    _asistanBtnDurum(false);
  }
}

async function _asistanSonSql() {
  if (!_asistanThreadId) return null;
  const { data } = await window.db.from('agent_messages')
    .select('metadata').eq('thread_id', _asistanThreadId).eq('rol', 'assistant')
    .order('created_at', { ascending: false }).limit(1);
  return data?.[0]?.metadata?.sql || null;
}

async function _asistanSonMeta() {
  if (!_asistanThreadId) return null;
  const { data } = await window.db.from('agent_messages')
    .select('metadata').eq('thread_id', _asistanThreadId).eq('rol', 'assistant')
    .order('created_at', { ascending: false }).limit(1);
  return data?.[0]?.metadata || null;
}

// Onay bekleyen plan için diff kartı (numaralı + güvence + Onayla/Vazgeç)
function _asistanPlanKarti(box, plan) {
  const div = document.createElement('div');
  div.className = 'asistan-plan-karti';
  div.style.cssText = 'align-self:flex-start;max-width:92%;background:var(--card);border:1px solid var(--green);border-radius:14px;padding:13px 15px;font-size:.83rem';
  const satirlar = plan.onizleme.map((s, i) =>
    `<div style="display:flex;gap:8px;padding:4px 0;border-bottom:1px solid var(--line,rgba(128,128,128,.15))">
       <span style="color:var(--green);font-weight:700;min-width:18px">${i + 1}.</span>
       <span style="flex:1">${_asistanEsc(s)}</span></div>`).join('');
  div.innerHTML = `<div style="font-weight:700;margin-bottom:8px">📋 Onayına sunulan işlemler</div>
    <div style="color:var(--ink);line-height:1.45">${satirlar}</div>
    <div style="color:var(--ink3);font-size:.72rem;margin-top:8px">🔒 Onaylamadan hiçbir şey kaydedilmez. Uyguladıktan sonra geri alabilirsin.</div>
    <div style="display:flex;gap:8px;margin-top:10px">
      <button class="btn" data-action="asistan-plan-onayla" data-pid="${plan.plan_id}"
        style="background:var(--green);color:#fff;padding:8px 16px;width:auto">✓ Onayla ve Uygula</button>
      <button class="btn" data-action="asistan-plan-vazgec" data-pid="${plan.plan_id}"
        style="background:none;color:var(--red);padding:8px 16px;width:auto">✗ Vazgeç</button>
    </div>`;
  box.appendChild(div);
  div.scrollIntoView({ behavior: 'smooth' });
}

// Uygulanmış plan için "Geri Al" kartı
function _asistanUndoKarti(box, planId) {
  const div = document.createElement('div');
  div.className = 'asistan-undo-karti';
  div.style.cssText = 'align-self:flex-start;max-width:92%;background:var(--card);border:1px dashed var(--ink3);border-radius:14px;padding:10px 14px;font-size:.8rem;display:flex;align-items:center;gap:10px';
  div.innerHTML = `<span style="flex:1;color:var(--ink3)">✅ Uygulandı. Yanlış olduysa geri alabilirsin.</span>
    <button class="btn" data-action="asistan-plan-geri-al" data-pid="${planId}"
      style="background:none;color:var(--red);border:1px solid var(--red);padding:6px 12px;width:auto">↩ Geri Al</button>`;
  box.appendChild(div);
  div.scrollIntoView({ behavior: 'smooth' });
}

function asistanPlanOnayla(pid, el) {
  if (el) el.closest('.asistan-plan-karti')?.querySelectorAll('button').forEach(b => b.disabled = true);
  window.asistanGonder('Onaylıyorum, planı uygula. (plan_id: ' + pid + ')');
}
function asistanPlanVazgec(pid, el) {
  if (el) el.closest('.asistan-plan-karti')?.remove();
  window.asistanGonder('Vazgeçtim, bu planı uygulama.');
}

// Geri al — LLM'e gitmeden doğrudan RPC (hızlı + güvenli)
async function asistanPlanGeriAl(pid, el) {
  const kart = el ? el.closest('.asistan-undo-karti') : null;
  if (el) { el.disabled = true; el.textContent = '↩ Geri alınıyor…'; }
  try {
    const { data, error } = await window.db.rpc('asistan_plan_geri_al', { p_plan_id: pid });
    const box = document.getElementById('asistan-mesajlar');
    let mesaj;
    if (error || !data?.ok) {
      mesaj = '⚠️ Geri alınamadı: ' + _asistanEsc(error?.message || data?.mesaj || 'bilinmeyen hata');
    } else if (data.kismi) {
      mesaj = `↩ ${data.geri_alinan} işlem geri alındı. Geri alınamayanlar: ${_asistanEsc((data.atlanan || []).join(', '))}. Bunları uygulamadan manuel düzeltmen gerekebilir.`;
    } else {
      mesaj = `↩ Tüm işlemler geri alındı (${data.geri_alinan}).`;
    }
    if (kart) kart.remove();
    box.appendChild(_asistanBalon('assistant', mesaj));
    box.lastChild.scrollIntoView({ behavior: 'smooth' });
  } catch (e) {
    if (el) { el.disabled = false; el.textContent = '↩ Geri Al'; }
    alert('Geri alma hatası: ' + e);
  }
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
  if (inp) {
    if (!inp._growBound) { inp.addEventListener('input', () => _asistanAutoGrow(inp)); inp._growBound = true; }
    setTimeout(() => inp.focus(), 100);
  }
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
window.asistanPlanOnayla = asistanPlanOnayla;
window.asistanPlanVazgec = asistanPlanVazgec;
window.asistanPlanGeriAl = asistanPlanGeriAl;
window.asistanYeniSohbet = asistanYeniSohbet;
window.asistanInit = asistanInit;
window.asistanGecmisAc = asistanGecmisAc;
window.asistanDrawerKapat = asistanDrawerKapat;
window.asistanThreadAc = asistanThreadAc;
window.asistanThreadSil = asistanThreadSil;
window.asistanTumunuSil = asistanTumunuSil;
