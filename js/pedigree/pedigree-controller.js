// js/pedigree/pedigree-controller.js
// Pedigree sekmesi denetleyicisi (Task 6-7): current focus, lazy load,
// +2 kuşak, stale-response guard (_detOpenId deyimi), farm node tık →
// openDet(farm_animal_id), external node tık → silent detail sheet,
// cached/offline rozeti.
//
// Hesap YOK: RPC projeksiyonu alır, adapter'a çevirir, view'a çizdirir.
//
// Entegrasyon noktaları (B3 dar dokunuş):
//   js/ui.js:openDet           → clear listesine 'tab-pedigree' + pedigreeSetFocus(id, aktifTab)
//   js/utils/handlers.js       → 'tab-pedigree' action → showTab + pedigreeTabActivated()
// W2'nin pedigreeApi'si ile seam: _pedResolvePayload hem {data,error} hem
// doğrudan payload biçimini normalize eder (zarf dönüş şeklini pinlememişti).
'use strict';

// ── Modül durumu (classic script: let globalThis'a çıkmaz — buildless dersi) ──
let _pedFocusId = null;       // açık hayvan kartındaki hayvanlar.id
let _pedFocusNodeId = null;   // "Bu node'u merkez yap" eksenindeki pedigree_nodes.uuid
let _pedAncDepth = 4;         // RPC guard: 0-8 (DB MVP max ancestor 8)
let _pedDescDepth = 1;        // RPC guard: MVP max descendant 3
let _pedReqSeq = 0;           // stale-response guard (openDet _detOpenId deyimi)
let _pedView = null;          // pedigreeViewInit handle {cy, ...}
let _pedRenderedKey = null;   // '<focus>:<anc>:<desc>' — çizilmiş görünüm anahtarı
let _pedPaneBuilt = false;    // #tab-pedigree kabuğu kurulu mu (openDet her açılışta pane'i temizler)
let _pedSurface = 'soyagaci'; // 'soyagaci' | 'genetik'
let _pedLastPayload = null;   // external sheet ebeveyn özeti için son projection

function _pedActiveFocusKey() { return _pedFocusNodeId || _pedFocusId || ''; }
function _pedRenderKey() { return _pedActiveFocusKey() + ':' + _pedAncDepth + ':' + _pedDescDepth; }
// Aktif focus için ÇİZİLİ görünüm var mı (derinlik fark etmez) — plan Rev 3:
// zaten render edilmiş görünüm ekranda kalır; yeni istek başarısızsa eziLMESİN.
function _pedFocusCiziliMi() {
  return !!(_pedView && _pedRenderedKey &&
    _pedRenderedKey.indexOf(_pedActiveFocusKey() + ':') === 0);
}

// ── W2 seam: {data,error} | payload | Promise<...> normalize ────────────────
async function _pedResolvePayload(raw) {
  let p = raw;
  if (p && typeof p.then === 'function') p = await p;
  if (p && typeof p === 'object' && ('data' in p || 'error' in p)) {
    if (p.error) throw new Error((p.error && p.error.message) || 'Pedigree sorgusu başarısız');
    p = p.data;
  }
  if (!p || typeof p !== 'object' || !Array.isArray(p.nodes)) {
    throw new Error('Pedigree verisi beklenen biçimde değil');
  }
  return p;
}

// ── openDet entegrasyonu: focus değişimi (RPC çağırmaz — lazy) ──────────────
// openDet her açılışta tab-pedigree innerHTML'ini temizlediği için kabuk
// her zaman yeniden kurulur; aynı hayvan için de view yok edilir (mount ölü).
function pedigreeSetFocus(animalId, tabActive) {
  const next = animalId ? String(animalId) : null;
  if (next !== _pedFocusId) {
    _pedFocusId = next;
    _pedFocusNodeId = null;      // yeni hayvan kartı: node-merkez eksenini bırak
    _pedAncDepth = 4;
    _pedDescDepth = 1;
    _pedLastPayload = null;
  }
  _pedRenderedKey = null;
  _pedReqSeq++;                  // uçuştaki eski focus yanıtları düşsün
  _pedPaneBuilt = false;
  if (_pedView) { _pedView.destroy(); _pedView = null; }
  if (tabActive) pedigreeTabActivated();
}

// ── Sekme ilk aktive olduğunda tetiklenir (lazy-load) ───────────────────────
function pedigreeTabActivated() {
  if (!g('tab-pedigree')) return;
  pedigreeEnsurePane();
  if (_pedSurface !== 'soyagaci') return;   // Genetik yer tutucusu — P3 veri kaynağı
  if (!_pedActiveFocusKey()) { pedigreeShowEmpty('Hayvan seçilmedi'); return; }
  if (_pedView && _pedRenderedKey === _pedRenderKey()) return;   // aynı görünüm zaten çizili
  pedigreeLoad();
}

// ── Pane kabuğu (sub-tab'lar + araç satırı + ağaç kutusu) ───────────────────
// Üretilmiş HTML → attribute onclick + this.dataset taşıma (MODAL-ROUTER-01,
// openMWithHayvan deseni). el.onclick ataması kullanılmaz.
function pedigreeEnsurePane() {
  if (_pedPaneBuilt && g('ped-tree-box')) return;
  const pane = g('tab-pedigree');
  if (!pane) return;
  _pedSurface = 'soyagaci';
  const _subBtn = (y, txt, on) => `<button class="tab2${on ? ' on' : ''}" data-y="${y}" onclick="showTab2(this.dataset.y,this);pedigreeSecYuzey(this.dataset.y)">${txt}</button>`;
  pane.innerHTML =
    `<div style="display:flex;align-items:center;gap:6px;margin-bottom:8px;flex-wrap:wrap">
      ${_subBtn('soyagaci', 'Soy Ağacı', true)}
      ${_subBtn('genetik', 'Genetik', false)}
      <span style="flex:1"></span>
      <span id="ped-badge" style="display:none"></span>
      <button id="ped-kusak-btn" onclick="pedigreeKusakArtir()">+2 kuşak</button>
    </div>
    <div id="ped-depth-hint" style="font-size:.68rem;color:var(--ink3);margin-bottom:6px"></div>
    <div id="tab2-soyagaci" class="tab2-pane on">
      <div id="ped-tree-box" style="position:relative;height:340px;border:1px solid var(--card3);border-radius:10px;overflow:hidden;background:var(--card)"></div>
    </div>
    <div id="tab2-genetik" class="tab2-pane">
      <div style="padding:18px;text-align:center;color:var(--ink3);font-size:.8rem;line-height:1.5">
        Genetik metrikleri (inbreeding F, completeness, founder/ırk dağılımı)
        <strong>P3 bandında</strong> geliyor — veri kaynağı <code>pedigree_profile</code> RPC'si.
      </div>
    </div>`;
  _pedPaneBuilt = true;
  pedigreeDepthHintGuncelle();
}

// Alt yüzey seçimi (Genetik yer tutucu; Soy Ağacı'na dönüşte eksik görünümü yükle)
function pedigreeSecYuzey(y) {
  _pedSurface = y === 'genetik' ? 'genetik' : 'soyagaci';
  if (_pedSurface === 'soyagaci') pedigreeTabActivated();
}

function pedigreeDepthHintGuncelle() {
  const el = g('ped-depth-hint');
  if (el) el.textContent = _pedAncDepth + ' kuşak atası · ' + _pedDescDepth + ' kuşak yavru';
}

// ── +2 kuşak (ata yönü; DB MVP max 8 — RPC clamp'e rağmen istemci de sınırlar) ──
function pedigreeKusakArtir() {
  if (_pedAncDepth >= 8) { toast('En fazla 8 kuşak istenebilir'); return; }
  _pedAncDepth = Math.min(8, _pedAncDepth + 2);
  pedigreeDepthHintGuncelle();
  pedigreeLoad();
}

// ── Lazy load + çizim ────────────────────────────────────────────────────────
async function pedigreeLoad() {
  const focusKey = _pedActiveFocusKey();
  if (!focusKey) return;
  if (!globalThis.pedigreeApi || typeof globalThis.pedigreeApi.subgraphForAnimal !== 'function') {
    pedigreeShowError(new Error('Pedigree API yüklenemedi'));
    return;
  }
  const seq = ++_pedReqSeq;
  pedigreeSetBadge('');
  // Aynı focus için çizili görünüm varsa skeleton ile EZME — istek başarısız
  // olursa mevcut ağaç ekranda kalmaya devam eder (plan Rev 3 çevrimdışı davranışı).
  if (!_pedFocusCiziliMi()) pedigreeTreeBoxLoading();
  try {
    let raw;
    if (_pedFocusNodeId) {
      // Node-merkez ekseninde yanlış focus'a sessiz düşme — açık hata ver.
      if (typeof globalThis.pedigreeApi.subgraphForNode !== 'function') {
        throw new Error('pedigreeApi.subgraphForNode bulunamadı');
      }
      raw = globalThis.pedigreeApi.subgraphForNode(_pedFocusNodeId, _pedAncDepth, _pedDescDepth);
    } else {
      raw = globalThis.pedigreeApi.subgraphForAnimal(_pedFocusId, _pedAncDepth, _pedDescDepth);
    }
    const payload = await _pedResolvePayload(raw);
    if (seq !== _pedReqSeq || focusKey !== _pedActiveFocusKey()) return;   // stale guard
    _pedLastPayload = payload;
    pedigreeRenderTree(pedigreeToElements(payload));
    _pedRenderedKey = _pedRenderKey();
    pedigreeSetBadge(pedigreeBadgeKind());
  } catch (e) {
    if (seq !== _pedReqSeq || focusKey !== _pedActiveFocusKey()) return;   // stale guard
    pedigreeShowError(e);
  }
}

function pedigreeTreeBoxLoading() {
  const box = g('ped-tree-box');
  if (!box) return;
  box.innerHTML = '<div style="padding:16px 0">' + ['80%', '60%', '90%', '50%'].map(w =>
    '<div class="skel" style="height:14px;width:' + w + ';margin:0 16px 12px"></div>').join('') + '</div>';
}

function pedigreeRenderTree(els) {
  const box = g('ped-tree-box');
  if (!box) return;
  if (_pedView) { _pedView.destroy(); _pedView = null; }
  if (!els.nodes.length) { pedigreeShowEmpty('Bu hayvan için pedigree düğümü yok'); return; }
  box.innerHTML = '';
  const mount = document.createElement('div');
  mount.style.cssText = 'width:100%;height:100%';
  box.appendChild(mount);
  try {
    _pedView = pedigreeViewInit(mount, els, {});
    _pedView.onTapNode(pedigreeNodeTiklandi);
  } catch (e) {
    _pedView = null;
    pedigreeShowError(e);
  }
}

function pedigreeShowEmpty(msg) {
  const box = g('ped-tree-box');
  if (box) {
    box.innerHTML = '<div style="padding:24px;text-align:center;color:var(--ink3);font-size:.8rem">' + esc(msg) + '</div>';
  }
}

// ── Hata: plan Rev 3 — zaten çizili görünüm ekranda KALIR; yalnız YENİ
// görünüm isteği açık hata verir (çevrimdışı rozetli). ──────────────────────
function pedigreeShowError(e) {
  const msg = (e && e.message) || 'Bilinmeyen hata';
  const offline = /çevrimdışı|offline/i.test(String(msg));
  if (_pedFocusCiziliMi()) {
    pedigreeSetBadge(offline ? 'offline' : '');
    toast((offline ? 'Çevrimdışı: ' : '') + msg, true);
    return;
  }
  pedigreeSetBadge(offline ? 'offline' : '');
  const box = g('ped-tree-box');
  if (box) {
    box.innerHTML =
      '<div style="padding:24px;text-align:center;font-size:.8rem;color:' + (offline ? 'var(--red2)' : 'var(--ink2)') + '">' +
      '<div style="font-size:1.4rem;margin-bottom:6px">' + (offline ? '📡' : '⚠️') + '</div>' + esc(msg) +
      '<div style="margin-top:10px"><button onclick="pedigreeLoad()" style="font-size:.72rem;font-weight:700;padding:6px 14px;border-radius:8px;border:1px solid var(--card3);background:var(--card2);color:var(--ink);cursor:pointer">Yeniden dene</button></div>' +
      '</div>';
  }
}

// ── cached/offline rozeti ────────────────────────────────────────────────────
// 'cache' sinyali payload.meta.cached ile gelir (W2 seam — set etmiyorsa rozet
// sessiz kalır); ağ kesikse success de 'offline' rozetle gelir.
function pedigreeBadgeKind() {
  const meta = (_pedLastPayload && _pedLastPayload.meta) || {};
  if (meta.cached === true) return 'cache';
  if (typeof navigator !== 'undefined' && navigator.onLine === false) return 'offline';
  return '';
}

function pedigreeSetBadge(kind) {
  const el = g('ped-badge');
  if (!el) return;
  const map = {
    cache: ['Önbellekten', 'background:rgba(201,125,10,.12);color:var(--amber);border:1px solid rgba(201,125,10,.4)'],
    offline: ['Çevrimdışı', 'background:rgba(192,50,26,.1);color:var(--red2);border:1px solid rgba(192,50,26,.35)'],
  };
  const k = map[kind];
  if (!k) { el.style.display = 'none'; el.textContent = ''; return; }
  el.textContent = k[0];
  el.style.cssText = 'display:inline-block;font-size:.62rem;font-weight:700;padding:2px 8px;border-radius:999px;' + k[1];
}

// ── Node tık yönlendirme ─────────────────────────────────────────────────────
function pedigreeNodeTiklandi(node) {
  let d;
  try { d = node.data(); } catch (err) { return; }
  if (!d) return;
  if (d.kind === 'farm_animal' && d.farm_animal_id) { openDet(d.farm_animal_id); return; }
  pedigreeExternalSheet(d);   // external VE farm_animal_id'siz farm düğümü → bilgi sheet'i
}

// ── External detail sheet — non-router silent sheet (MODAL-ROUTER-01'de
// ayrıcalıklı yüzey: doğrudan DOM'dan kalkar, history girişi tutmaz) ─────────
function pedigreeExternalSheet(d) {
  pedigreeExtSheetKaldir();
  const parents = _pedEbeveynOzet(d.id);
  const satir = (k, val) => '<div style="display:flex;justify-content:space-between;gap:10px;padding:6px 0;border-bottom:1px solid var(--card3);font-size:.78rem">' +
    '<span style="color:var(--ink3)">' + k + '</span><span style="font-weight:600;color:var(--ink);text-align:right">' + esc(val || '—') + '</span></div>';
  const ov = document.createElement('div');
  ov.id = 'ped-ext-sheet';
  ov.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.45);display:flex;align-items:flex-end;justify-content:center;z-index:9999';
  ov.innerHTML =
    '<div style="background:var(--card);width:100%;max-width:480px;border-radius:16px 16px 0 0;padding:16px 16px 22px;max-height:70dvh;overflow:auto">' +
    '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">' +
    '<strong style="font-size:.95rem;color:var(--ink)">' + esc(d.label || 'Dış kaynak düğüm') + '</strong>' +
    '<button data-ped-sheet-close="1" onclick="pedigreeExtSheetKaldir()" style="border:none;background:var(--card2);border-radius:8px;width:28px;height:28px;font-size:.9rem;cursor:pointer;color:var(--ink2)">✕</button></div>' +
    '<div style="font-size:.66rem;font-weight:700;color:var(--ink3);letter-spacing:.08em;text-transform:uppercase;margin-bottom:6px">Çiftlik dışı kaynak</div>' +
    satir('Cinsiyet', d.sex) + satir('Irk', d.breed) + satir('Doğum', d.birth_date ? fmtTarih(d.birth_date) : '') +
    satir('Ebeveynler', parents.map(p => (p.role === 'dam' ? 'Anne: ' : p.role === 'sire' ? 'Baba: ' : '') + p.label).join(' · ')) +
    '<button data-ped-merkez-id="' + escAttr(d.id || '') + '" onclick="pedigreeMerkezYap(this.dataset.pedMerkezId)" style="margin-top:12px;width:100%;font-size:.78rem;font-weight:700;padding:9px;border-radius:10px;border:none;background:var(--green);color:#fff;cursor:pointer">Bu node\'u merkez yap</button>' +
    '</div>';
  // Backdrop tık → doğrudan DOM'dan kalkma (history yok) — silent sheet izinli
  // tek onclick ataması: modal.md "Self-dismissing non-router sheets ... sanctioned".
  ov.onclick = function (e) { if (e.target === ov) pedigreeExtSheetKaldir(); };
  document.body.appendChild(ov);
}

function pedigreeExtSheetKaldir() {
  const ov = document.getElementById('ped-ext-sheet');
  if (ov && ov.parentNode) ov.parentNode.removeChild(ov);
}

// Son projection'dan düğümün ebeveyn özeti (çeviri — hesap yok)
function _pedEbeveynOzet(nodeId) {
  const p = _pedLastPayload;
  if (!p || !Array.isArray(p.edges) || !Array.isArray(p.nodes) || !nodeId) return [];
  const byId = {};
  p.nodes.forEach(n => { if (n && n.id) byId[String(n.id)] = n; });
  return p.edges
    .filter(e => e && e.target === nodeId && e.source && byId[String(e.source)])
    .map(e => ({ role: e.role ? String(e.role) : '', label: String(byId[String(e.source)].label || e.source) }));
}

// ── "Bu node'u merkez yap": fokus node uuid eksenine geç (subgraphForNode) ──
function pedigreeMerkezYap(nodeId) {
  if (!nodeId) return;
  pedigreeExtSheetKaldir();
  _pedFocusNodeId = String(nodeId);
  _pedRenderedKey = null;
  _pedAncDepth = 4;
  _pedDescDepth = 1;
  _pedLastPayload = null;
  pedigreeDepthHintGuncelle();
  if (_pedSurface !== 'soyagaci') {
    const btn = document.querySelector('#tab-pedigree .tab2[data-y="soyagaci"]');
    if (btn) { showTab2('soyagaci', btn); }
    _pedSurface = 'soyagaci';
  }
  pedigreeLoad();
}
