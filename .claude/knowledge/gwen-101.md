# Gwen/Qwen CLI Klavuzu — Orchestrasyon 101

## Gwen Kimdir?

Gwen = Qwen CLI üzerinde çalışan Alibaba'nın Qwen modeli. **Ücretsiz** — ama sadece kendi CLI ortamında çalıştığında. Aider veya başka wrapper'larla ücretli hale gelir.

Güçlü yönleri: kod yazma, dosya düzenleme, SQL.
Zayıf yönleri: bağlam takibi, çok adımlı mimari kararlar, task dosyası bulma.

---

## Ortam

| | Claude | Gwen |
|---|---|---|
| Worktree | `/root/egesut-erp1-main` (main) | `/root/egesut-erp1` (feature branch'ler) |
| Branch | main | `gwen/task-XXX` |
| CLI | claude | qwen |
| Terminal | pseudo (stdin=/dev/null) | `/dev/pts/0` |

---

## Claude Qwen'e Nasıl Erişiyor — Teknik Detay

### Neden tmux?

Claude'un Bash aracı kendi izole shell'inde çalışır — kullanıcının gerçek terminaline erişimi yok (`stdin=/dev/null`). Qwen CLI ise interaktif bir terminal uygulaması, doğrudan çağrılamaz.

**Çözüm:** tmux bir terminal multiplexer. Arka planda sanal terminal pencereleri açar. Claude hem bu pencerelere yazabilir (`send-keys`) hem de içeriğini okuyabilir (`capture-pane`). Böylece Claude sanki o terminalde oturuyormuş gibi Qwen'i yönetebilir.

```
Claude (Bash aracı)
    │
    ├─ tmux send-keys -t gwen "mesaj" Enter   → Qwen'e yazar
    └─ tmux capture-pane -t gwen -p           → Qwen'in ekranını okur
                │
          [gwen tmux session]
                │
            qwen CLI
          (kendi terminali, /root/egesut-erp1 dizininde)
```

---

## tmux ile Orchestrasyon — Adım Adım

### 0. Kurulum (bir kez yapıldı, artık hazır)

```bash
dnf install -y tmux
```

### 1. Session Var mı Kontrol Et

```bash
tmux list-sessions 2>/dev/null
# "gwen: 1 windows" görünürse session açık
# "no server running" görünürse yeniden oluştur
```

### 2. Session Aç ve Qwen Başlat

```bash
# Yeni session oluştur (arka planda, /root/egesut-erp1 dizininde)
tmux new-session -d -s gwen -c /root/egesut-erp1

# Qwen CLI'yi başlat
tmux send-keys -t gwen "qwen" Enter

# Yüklenme beklenir (~8 saniye)
sleep 8

# Ekranı oku — başlangıç menüsü çıkacak:
# "1. Start new chat session"
# "2. Continue previous conversation"
tmux capture-pane -t gwen -p
```

### 3. Session Seç

```bash
tmux send-keys -t gwen "1" Enter   # yeni session
sleep 3
tmux capture-pane -t gwen -p
# "Type your message or @path/to/file" göründüğünde hazır
```

### 4. YOLO Mode Aktive Et

Qwen CLI'de `shift+tab` mode döngüsü: `default → YOLO → plan → default`

YOLO = tüm araç çağrılarını (dosya yazma, shell) izin sormadan kabul eder.

```bash
# shift+tab escape sequence: \e[Z
tmux send-keys -t gwen $'\e[Z' ""
sleep 1
tmux capture-pane -t gwen -p | grep "mode"
# "YOLO mode" görünene kadar tekrarla (2-3 kez gerekebilir)
```

### 5. Görev Gönder

```bash
# KRITIK 1: Önce C-u ile input'u temizle — önceki karakterler birikmiş olabilir
tmux send-keys -t gwen C-u
sleep 1

# KRITIK 2: Mesajı tek seferde gönder, sonra ayrı Enter
tmux send-keys -t gwen "GÖREV METNİ" Enter
sleep 1
tmux send-keys -t gwen "" Enter   # ikinci Enter submit garantisi

# Qwen çalışıyor — bekliyoruz
sleep 20
tmux capture-pane -t gwen -p
```

**Pane input durumu:**
- `* /mesaj` → input var, submit edilmedi → `Enter` gönder
- `>` → Qwen'in cevabı veya geçmiş

### 5b. Skill Çalıştır

```bash
tmux send-keys -t gwen C-u
sleep 1
tmux send-keys -t gwen "/skills SKILL_ADI" Enter
sleep 1
tmux send-keys -t gwen "" Enter
sleep 8
tmux capture-pane -t gwen -p
```

**Mevcut skill'ler:**
| Skill | Amaç |
|---|---|
| `egesut-fullstack` | ERP tohumlama, doğum, hayvan yönetimi |
| `fix-ui` | UI bug sistematik düzeltme |
| `gwen-self-improvement` | Gwen CLI, MCP, agent, skill geliştirme |
| `qc-helper` | Qwen Code kullanım soruları |
| `review` | Kod review — doğruluk, güvenlik, kalite |

### 6. Tamamlanma Tespiti

Qwen bittiğinde prompt'a döner:
```
>   Type your message or @path/to/file
```

Poll ile beklemek:
```bash
for i in $(seq 1 30); do
  tmux capture-pane -t gwen -p | grep -q "Type your message" && break
  sleep 5
done
tmux capture-pane -t gwen -p   # son çıktıyı oku
```

---

## Görev Gönderme Formatı

Gwen'e mesaj yazarken şu formatı kullan — net ve kısa tut:

```
Branch: gwen/task-XXX'e geç (yoksa oluştur).
Görev: [NE YAPACAK - tek paragraf]
Kural: Sadece RPC kullan, direkt REST yazma.
Bitince: commit ve push yap (gwen/task-XXX branch'ine).
```

Uzun task dosyaları okutma — doğrudan mesajda ver.

---

## Sık Karşılaşılan Sorunlar

| Sorun | Çözüm |
|---|---|
| Session yok | `tmux new-session -d -s gwen -c /root/egesut-erp1` |
| Qwen CLI başlangıç ekranında takılı | `tmux send-keys -t gwen "1" Enter` |
| Mesaj gönderilmiyor | Enter'ı ayrı gönder: `tmux send-keys -t gwen "" Enter` |
| Cevap gelmiyor | 20-30 saniye bekle, model yavaş olabilir |
| Remote URL yanlış (SSH) | `git -C /root/egesut-erp1 remote set-url origin https://meliksahtokur:TOKEN@github.com/Meliksahtokur/egesut-erp1.git` |
| Push başarısız (token) | GitHub → Settings → Developer settings → Personal access tokens → yeni token |

---

## Workflow Özeti

```
1. tmux gwen session aç
2. qwen başlat → "1" seç → YOLO aktive et
3. Görevi direkt mesaj olarak gönder
4. Tamamlanma bekle (prompt'a dön)
5. git diff ile çıktıyı incele
6. Onaylarsan: ben main'e merge ederim
7. Reddedersen: revize mesajı gönder, 3'e dön
```

---

## Bilinen Limitler

- Gwen bağlamı uzun tutamıyor — uzun oturumlarda `/compress` kullan veya yeni session aç
- Mimari karar veremez — neyi nasıl yapacağını Claude belirler, Gwen sadece uygular
- Migration'ları direkt DB'ye basabilir, dosya oluşturmayı unutabilir — her migration sonrası `supabase/migrations/` kontrol et
- Aynı anda birden fazla task verme — sıralı çalıştır
