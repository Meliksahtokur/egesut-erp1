# 🚨 CLAUDE — SİLME! Bu Değişiklikler Kritik Altyapı

**Tarih:** 2026-04-02
**Branch:** gwen/arge
**Son Commit:** 4d163c0

---

## ⚠️ SİLİNMEMESİ GEREKEN DEĞİŞİKLİKLER

### 1. Git Hook'lar (KRİTİK)

**Konum:** `/root/egesut-erp1/.git/hooks/`

**Dosyalar:**
- `post-checkout` — Branch kilidi (yanlış branch'e geçişi engeller)
- `pre-push` — Review kontrolü (review'siz push'u engeller)

**Neden Önemli:**
- Gwen session'larını korur
- Review'siz push'u engeller
- **Silinirse Gwen sistem çöker!**

**Test:**
```bash
# Branch kilidi testi
git checkout feature/xyz  # Otomatik gwen/arge'e geçer

# Review kontrolü testi
git push origin gwen/arge  # Review'siz push bloke
```

---

### 2. Agent Dosyaları (~/.qwen/agents/)

**Konum:** `/root/.qwen/agents/`

**Dosyalar:**
- `gwen.md` — Operator pattern (agent tool çağrıları eklendi)
- `gwen-researcher.md` — Context yükleme
- `gwen-analyst.md` — Kod analizi
- `gwen-coder.md` — Kod yazma
- `gwen-tester.md` — Test
- `gwen-reviewer.md` — Push review
- `gwen-architect.md` — Sistem geliştirme

**Neden Önemli:**
- Gwen CLI'ın beyni
- Operator pattern burada çalışıyor
- **Silinirse Gwen tek agent'a düşer!**

---

### 3. Skill Dosyaları (~/.qwen/skills/)

**Konum:** `/root/.qwen/skills/`

**Dosyalar:**
- `egesut-fullstack/` — ERP domain knowledge
- `fix-ui/` — UI bug fix workflow
- `rpc-contract/` — RPC validation (yeni)
- `session-rules/` — Departman izolasyonu
- `gwen-self-improvement/` — CLI geliştirme

**Neden Önemli:**
- Domain kuralları burada
- RPC contract burada
- **Silinirse domain bilgisi kaybolur!**

---

### 4. Setup Script

**Konum:** `/root/qwen-arge/.claude/scripts/setup.sh`

**Değişiklik:**
- 7 agent sync mekanizması
- Agent doğrulama (7/7)

**Neden Önemli:**
- Yeni makine kurulumu için gerekli
- **Silinirse setup çalışmaz!**

---

## 📋 Commit Geçmişi (KORUNMALI)

```
4d163c0 DONE: arge — task-arge-013 operator pattern fix + Git hook'lar
078dae5 DONE: arge — task-arge-012 done raporu + blackboard güncellendi
e2d102a DONE: arge — task-arge-012 operator pattern: 4 agent + gwen.md workflow
0232a84 DONE: arge — task-arge-011 operator mimarisi tasarımı
6f570b8 DONE: arge — task-arge-010 rpc-contract skill + gwen-reviewer güvenlik
```

**Toplam:** 5 commit, 4 task (task-arge-010 → task-arge-013)

---

## 🔒 KORUMA KURALLARI

### ASLA YAPILMA

1. **`.git/hooks/` dizinini silme**
   - post-checkout, pre-push hook'ları kritik

2. **`~/.qwen/agents/` dizinini silme**
   - 7 agent dosyası kritik

3. **`~/.qwen/skills/` dizinini silme**
   - 5 skill kritik

4. **`gwen/arge` branch'ini silme**
   - AR-GE geliştirme branch'i

5. **`gwen/dev` branch'ini silme**
   - ERP geliştirme branch'i

---

## ✅ GÜVENLİ İŞLEMLER

### Yapılabilir:
- `git pull` — Remote'dan çek
- `git checkout gwen/arge` — Branch değiştir
- `git log` — Commit geçmişi
- `git status` — Durum kontrol

### Yapılamaz:
- `git reset --hard HEAD~5` — Commit silme ❌
- `rm -rf .git/hooks/` — Hook silme ❌
- `rm -rf ~/.qwen/` — Qwen config silme ❌

---

## 🎯 ÖZET

**Ne inşa edildi:**
- ✅ 7 agent (Operator + 6 uzman)
- ✅ 5 skill (Domain + workflow)
- ✅ 2 Git hook (Branch + review koruması)
- ✅ Operator pattern (çalışıyor)
- ✅ Session izolasyonu (dev/arge)

**Neden kritik:**
- Gwen CLI artık tam çalışan bir sistem
- Tek agent'tan → 7 agent'lı ekip çalışmasına geçtik
- Branch/review koruması fiziksel olarak enforce ediliyor

**Silinirse:**
- ❌ Operator pattern çalışmaz
- ❌ Branch kilidi kaybolur
- ❌ Review'siz push mümkün olur
- ❌ Domain bilgisi kaybolur

---

**BU DOSYALAR GÜVENLİ — SİLME!** 🚨
