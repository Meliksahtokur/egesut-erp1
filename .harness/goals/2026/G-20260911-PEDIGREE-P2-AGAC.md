---
id: G-20260911-PEDIGREE-P2-AGAC
status: done
owner: root
flow: ss_org
created: 2026-09-11
base_sha: 6e9ed13
branch: idle/pedigree-p2
report: .claude/idle-reports/2026-09-11-pedigree-p2.md
write_manifest:
  - supabase/migrations/            # Task 3 projection RPC migration
  - tests/sql/
  - tests/unit/
  - tests/support/stub-backend.js   # pedigree RPC stub'ları + çağrı sayaçları
  - js/pedigree/                    # api/adapter/style/view/controller
  - vendor/cytoscape.min.js         # Task 5 P2 bandı (pinned)
  - index.html                      # Soy & Genetik sekmesi (+?v= damga TEK ortak değer)
  - js/ui.js                        # B3 dar dokunuş (root 2026-09-11 onayı): tab-pedigree temizlik + lazy-load kancası
  - js/utils/handlers.js            # B3 dar dokunuş (root 2026-09-11 onayı): tab-pedigree handler kaydı
  - .claude/idle-reports/2026-09-11-pedigree-p2.md
  - .claude/reviews/2026-09-11-pedigree-p2-lead-review.md
  - .claude/tasks/2026-09-11-pedigree-p2-*.md
  - .harness/goals/2026/G-20260911-PEDIGREE-P2-AGAC.md
pattern_refs:
  - MODAL-ROUTER-01   # index.html router-managed modal/link deseni (dataset + HTML attribute)
  - TESTING-01        # unit + stub-backend test deseni
pattern_exceptions: []
review_lane: codex_luna_max_bounded
implement_lane: glmf_workers
---

# G-20260911-PEDIGREE-P2-AGAC — Pedigree P2 "Ağaç" package

- **Status:** DONE (2026-09-11 — root merge 40d09d2; lead luna 5/5 kapatıldı, root mekanik 795/1 known-red, SQL 15/15 demo)
- **Date:** 2026-09-11
- **Owner directive (2026-09-11):** "planı faaliyete sok" — P2 starts now,
  same lane (Lead GLM, workers GLMF). PROD deploy of the pending 6 migrations
  is NOT yet approved and is OUT OF SCOPE here; P2 runs on demo DB only.
- **Authority:** plan `.claude/plans/2026-09-10-pedigree-genetics-impl.md`
  (Rev 3.1) — P2 scope is EXACTLY Faz 3-4: Task 3 (projection RPC),
  Task 4 (API wrapper + memory cache), Task 5 P2-band (vendor cytoscape),
  Task 6 (frontend feature boundary), Task 7 (hayvan kartı Soy & Genetik
  sekmesi UI). Task 8+ (semen identity) is P3 — DOKUNMA.

## Lane rules (owner standing, 2026-09-11 — plan Rev 3.1)

1. **Worker subagent review ZORUNLU:** her worker lead'e teslimden önce kendi
   diff'ine builtin subagent review koşturur; bulgu/`bulgu yok` notu teslimin
   parçası. Mekanik kapıları worker kendisi koşar.
2. **Lead luna review ZORUNLU:** lead, tüm worker teslimleri + düzeltmeler
   tamamlandıktan sonra root'a devretmeden önce paket geneline bağımsız
   Codex (luna max) review açar (tek tur; bulgular aynı worker'a döner).
3. **İş yükü workerlarda:** lead orkestrasyon + küçük dokunuşlar; implementasyon
   ve test yazımı worker'larda.

## Acceptance criteria (mechanical)

1. **G3 (Task 3):** `pedigree_subgraph(uuid,integer,integer)` +
   `pedigree_subgraph_for_animal(text,integer,integer)` RPC'leri (grants
   authenticated-only, oluşturan migration'da) + SQL fixture yeşil
   (demo'da P1'in 166 node/59 edge verisi üzerinden focus'lu alt graf;
   depth clamp 0-8; effective_depth yanıtta).
2. **G3b (Task 4):** `js/pedigree/pedigree-api.js` memory cache (modül-scope
   Map, farm-scope key, write sonrası TAM boşaltma) + `tests/unit/pedigree-api.test.js`
   + `pedigree-cache.test.js` yeşil. `js/api.js`'e DB_VER/IDB dokunuşu YOK.
3. **G3c (Task 5):** `vendor/cytoscape.min.js` pinned sürüm + lokal statik
   serverda `window.cytoscape` + `breadthfirst` smoke yeşil; ELK YOK (P4 bandı).
4. **G3d (Task 6-7):** adapter/style/view/controller unit testleri yeşil;
   index.html'de [Soy Ağacı][Genetik] iki sekme (Akrabalık sekmesi YOK —
   Rev 3 hizalaması); external/farm node görsel ayrımı; `?v=` damgası TÜM
   yerel kaynaklarda TEK ortak değer (kısmi bump YASAK — repo dersi);
   stub-backend pedigree RPC stub'ları; mevcut unit suite regresyonsuz
   (known-red gecmis-pipeline hariç).
5. **Demo gate:** lokal sunucuda (8097/8098) hayvan kartından 4-kuşak focal
   tree açılıyor; zaten açılmış görünüm memory cache'ten; ağ kesilmesinde
   yeni görünüm isteği açık hata.
6. **Migration discipline:** replay-safe; farm_id DEFAULT + öncül index;
   grants kendi migration'ında; PROD ERİŞİM YOK (demo serbest).

## DB access rules

Demo DB free (migrations + tests). PROD: NO access — `ss-ask --class cross`
to root. Deploy is owner-gated and NOT approved for this package.

## Review lane — BOUNDED

Lead luna review (yukarıdaki kural 2) tek tur. Root merge gate: bağımsız
root-gate luna (tek tur + en fazla 1 revizyon). Anti-manipulation: zarf
nötr malzeme (diff + UNTRUSTED işaretli yazar özetleri), bulgular filtresiz.

## Stop conditions

PROD erişim ihtiyacı → stop + ss-ask. Plan çelişkisi → ss-ask cross.
`?v=` kısmi bump tuzağı → tespit edilirse worker'a F-bulgu olarak döner.
Pattern sapması (MODAL-ROUTER-01/TESTING-01) → pattern_exceptions kaydı +
lead onayı olmadan merge edilmez.

## Out of scope

Task 8+ (semen identity, P3), ELK/mating (P4), IDB cache (yok — Rev 3),
push (root/owner), deploy (owner), GT regen (root post-deploy).
