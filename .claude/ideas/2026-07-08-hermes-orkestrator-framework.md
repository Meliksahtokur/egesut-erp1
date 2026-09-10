# Hermes / Orkestratör Framework — MCP + Daemon Katmanı

**Tarih:** 2026-07-08
**Durum:** Fikir / istişare notu — implemente edilmedi. Elimizdeki iş (ADR-008 Codex entegrasyonu,
kota-tükenme fix'i) bittikten sonra değerlendirilecek, acele yok.
**İlişkili:** `tools-bank/docs/plans/2026-07-07-global-agent-control-roadmap.md` (bu roadmap'in
Faz 2/3'ü zaten bu fikrin bir alt kümesi — bkz. aşağıdaki "Nereye oturuyor" bölümü),
`egesut-erp1/CLAUDE.md`, `egesut-erp1/AGENTS.md`, [[project_codex_app_server_bridge]],
[[project_goose_acp_bridge]].

---

## Bu doküman neyi kapsar

Kullanıcının kendi kelimeleriyle: mevcut dosya-tabanlı mailbox/bridge sistemi (goose/omp/pi/codex
teammate'leri) çalışıyor ama "dış process / yamalı yapı" hissi veriyor. Öneri: bunu **Hermes**
(veya kendi yazacağımız bir Orkestratör Framework) ile sarmalayıp gerçekten "native" hissettirmek
— MCP arkasına gizlenmiş fonksiyon çağrıları, dosya-polling yerine Unix socket/named pipe üzerinden
konuşan kalıcı daemon süreçler, ve blackboard'ı model tarafından elle okunan bir dosya yerine
arka planda otomatik güncellenen "sessiz event bus" hâline getirmek.

## Kullanıcının orijinal önerisi (2026-07-08, birebir)

> Altyapıdaki IPC (prosesler arası iletişim), dosya bazlı mesaj kutuları ve blackboard gibi zor
> kısmı zaten çözdüysen, hissettiğin o "dış process / yamalı yapı" havası aslında sadece bir
> Soyutlama (Abstraction) ve Protokol eksikliğidir.
>
> Hermes veya yazacağın bir Orkestratör Framework'ünü bu yapının üzerine tam olarak bu eğreti
> hissi yok etmek için giydirebilirsin.
>
> **O "Dış Process" Havası Neden Oluşuyor?**
> Şu anki yapında ana model (Claude/Codex), alt agent'ı çalıştırırken muhtemelen şöyle bir
> zihinsel model izliyor: (1) Shell komutu çalıştır (`python bridge.py --agent goose ...`),
> (2) Bekle / Dosyaya bak (`message_box/inbox.json`), (3) Çıktıyı oku ve yorumla. Bu akış modeli
> "işletim sistemi düzeyinde komut koşturan bir kullanıcı" gibi davrandırır. Yerel (native)
> hissettirmemesinin sebebi, araçların birer fonksiyon/servis değil, dışarıdan çağrılan yabancı
> komutlar gibi görünmesidir.
>
> **Hermes / Custom Framework ile "Native" Hissiyat Nasıl Sağlanır?**
>
> 1. **Dosya/Bridge Script'lerini MCP arkasına gizlemek** — ana modelin Bash komutu satırı
>    yazarak script tetiklemesi yerine, arkadaki tüm o `python bridge`, `blackboard` ve
>    `message box` mekanizmasını tek bir MCP Server / Tool Set olarak paketlemek. Eski hâli:
>    model `exec("python call_goose.py --task ...")` çalıştırır. Native hâli: model doğrudan
>    `delegate_task(agent="goose", context=...)` fonksiyonunu çağırır. Arkada dosya mı
>    yazılmış, socket mi açılmış ana model bunu hiç görmez.
> 2. **Dosya polling yerine Unix Sockets / Named Pipes (Daemon mimarisi)** — dosya tabanlı
>    `message_box` yapıları disk I/O ve polling gerektirdiği için her zaman bir gecikme/yapaylık
>    hissi verir. Alt agent'ları her görevde sıfırdan başlatmak yerine arkada uykuda bekleyen
>    daemon süreçler olarak tutup Hermes'in bunlarla Unix Domain Socket / FIFO üzerinden
>    haberleşmesi.
> 3. **Blackboard'u "sessiz event bus" yapmak** — blackboard'un model tarafından sürekli
>    oku/yaz komutlarıyla manuel yönetilmesi context'i kirletir. Framework katmanı alt
>    agent'ların ürettiği çıktıları arkada otomatik olarak blackboard'a (SQLite/Redis/
>    in-memory) işler; ana model sadece ihtiyaç duyduğunda hazır bir "sistem hafızası" görür.
>
> Mevcut Python bridge ve blackboard sistemi "motor kısmı" olarak zaten sağlam duruyor. Hermes/
> Framework katmanı bu motorun üzerindeki "kaporta ve direksiyon" olacak. MCP arabirimleri ve
> daemon süreçler üzerine kurgulanırsa ana agent başka bir CLI çalıştırmadığını, doğrudan kendi
> hafızasının/yeteneklerinin bir uzantısını kullandığını hissedecek.

## Claude'un değerlendirmesi (aynı oturum, birebir)

Yön olarak doğru ve zaten büyük ölçüde planlı (`global-agent-control-roadmap.md`), ama önceliği
"native hissi" değil "4 bridge'in ortak kodunu tekilleştirme" olarak kurgulamak gerekir:

- **Bu oturumda ampirik olarak gözlemlenen gerçek darboğazlar** dosya I/O gecikmesi veya
  output-parsing DEĞİLDİ — stale ACP session (404), koşulsuz commit bug'ı, bir worker'ın kendi
  bash tool-use'unda regex hang'i, ve Codex'in context'ine giren dev boyutlu çıktılar (kota
  tükenmesi, bkz. [[project_codex_app_server_bridge]]). Küçük JSON dosyalarının lokal NVMe'de
  okunması hiçbir zaman ölçülebilir bir gecikme kaynağı olmadı.
- "Yamalı" hissinin asıl kaynağı: aynı fix'in (erken-ack, lease, heartbeat, token-disiplin hook'u)
  4 ayrı teammate script'inde (goose/omp/pi/codex) bağımsız yazılması/unutulması riski — bu tam
  olarak roadmap'in "Kritik risk #5" maddesi (`mailbox_lib.py` paylaşımlı modül önerisi).
- **Önerilen sıralama:**
  1. Önce ucuz/yüksek getirili **MCP wrapper** — `delegate_task(agent, task)` gibi TEK bir tool,
     yeni daemon gerektirmeden "exec bash script" hissini kırar.
  2. Socket/daemon (gerçek Hermes) — ayrı bir proje değil, `global-agent-control-roadmap.md`'nin
     bir sonraki fazı olarak: asıl katma değeri "native hissi" değil, lease/heartbeat/enforcement
     mantığını 4 script yerine TEK yerde çözmek (DRY). Socket/daemon o zaman doğal bir yan ürün
     olur, hedef değil.
  3. Dosya-mailbox'ı socket'e taşımak en son sırada — kanıtlanmış bir ihtiyaç yok, "çözüm arayan
     problem" riski taşıyor.

## Nereye oturuyor (mevcut planla ilişki)

`global-agent-control-roadmap.md`'nin Faz 2 (Minimal Envelope) ve Faz 3 (Heartbeat/Registry) adımları
zaten bu fikrin altyapısal ön koşulu. Hermes'i ayrı bir yeni plan olarak açmak yerine, o roadmap
olgunlaştıkça (özellikle Faz 3 registry + paylaşımlı `mailbox_lib.py` netleştikten sonra) bir
"Faz 7: MCP delegate_task wrapper" ve isteğe bağlı "Faz 8: Hermes supervisor daemon" olarak
eklenmesi önerilir.
