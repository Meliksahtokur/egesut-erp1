# Task-arge-007: Araç Altyapısı — gh CLI + MCP Token Güncelleme

**Durum:** bekliyor
**Branch:** gwen/arge
**Session:** arge

---

## Bağlam

Şu an GitHub işlemleri (PR, issue, push) her iki sistemde bloke:
- Claude: `github` ve `supabase` MCP'leri PLACEHOLDER token ile kurulu → çalışmıyor
- Gwen: `gh` CLI yok → GitHub işlemi yapamıyor

Bu task'ta hem Claude hem Gwen için araç altyapısı tamamlanacak.

---

## Görev 1: Claude MCP Token'larını Güncelle

**Hangi agent:** `gwen-architect` — config dosyası düzenleme işi

**Dosya:** `/root/.claude.json`

Mevcut `mcpServers` bölümünü şu şekilde güncelle:

```json
"mcpServers": {
  "github": {
    "command": "mcp-server-github",
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "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"
    }
  },
  "supabase": {
    "command": "mcp-server-supabase",
    "args": [
      "--access-token",
      "sbp_8d52cb7f589f54575d9599fe0edfa126666a32f1"
    ]
  },
  "context7": {
    "command": "context7-mcp",
    "env": {}
  }
}
```

**Doğrulama:** Dosyayı düzenledikten sonra JSON geçerliliğini kontrol et:
```bash
python3 -m json.tool /root/.claude.json > /dev/null && echo "JSON OK"
```

---

## Görev 2: gh CLI Kur

**Hangi agent:** Önce `general-purpose` ile araştır, sonra `gwen-architect` ile uygula

### Adım 1 — Mevcut paket yöneticisini tespit et
```bash
command -v apt-get && echo "apt" || command -v dnf && echo "dnf" || command -v pacman && echo "pacman"
```

### Adım 2 — Kur

**apt varsa:**
```bash
apt-get install -y gh
```

**dnf varsa:**
```bash
dnf install -y gh
```

**Hiçbiri yoksa — binary indir:**
```bash
# ARM64 (Termux/Android)
curl -L https://github.com/cli/cli/releases/latest/download/gh_linux_arm64.tar.gz -o /tmp/gh.tar.gz
tar -xzf /tmp/gh.tar.gz -C /tmp
mv /tmp/gh_*/bin/gh /usr/local/bin/gh
chmod +x /usr/local/bin/gh
```

**aarch64 mı kontrol et:**
```bash
uname -m
```

### Adım 3 — gh CLI token ile yapılandır
```bash
echo "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" | gh auth login --with-token
gh auth status
```

---

## Görev 3: Doğrulama

**Hangi agent:** `gwen-architect` — sonuçları doğrula ve raporla

```bash
# 1. gh CLI çalışıyor mu?
gh --version
gh auth status

# 2. Supabase CLI çalışıyor mu?
supabase --version

# 3. Claude MCP JSON geçerli mi?
python3 -m json.tool /root/.claude.json > /dev/null && echo "Claude MCP JSON OK"

# 4. node, git temel araçlar
node --version && git --version
```

---

## Görev 4: .agents/setup.sh Güncelle

`/root/egesut-erp1/.agents/setup.sh` varsa şu bölümü ekle:

```bash
# gh CLI kurulum kontrolü
if ! command -v gh &>/dev/null; then
  echo "⚠️  gh CLI bulunamadı — elle kur: https://cli.github.com"
else
  echo "✅ gh CLI mevcut"
fi

# Claude MCP token kontrolü
if grep -q "PLACEHOLDER" /root/.claude.json 2>/dev/null; then
  echo "⚠️  Claude MCP token'ları PLACEHOLDER — task-arge-007'ye bak"
else
  echo "✅ Claude MCP token'ları yapılandırılmış"
fi
```

---

## Agent Kullanım Rehberi

```
1. gwen-architect başlatır
2. Görev 1 (MCP config): gwen-architect doğrudan yapar
3. Görev 2 (gh CLI kurulum):
   - Önce general-purpose ile paket yöneticisini araştır (uname, command -v)
   - Kurulum adımını gwen-architect uygular
4. Görev 3 (doğrulama): gwen-architect kontrol eder
5. Görev 4 (setup.sh): gwen-architect günceller
```

**Önemli:**
- `/root/.claude.json` Claude'un global config dosyası — sadece `mcpServers` bölümünü değiştir, başka hiçbir şeye dokunma
- `gh auth login` interaktif olmayabilir → `--with-token` flag'i kullan (yukarıda gösterildi)
- js/ dosyalarına dokunma
- Değişiklikler repo dışı (`/root/.claude.json`, gh config) — commit'e eklenecek bir şey yok, setup.sh değişikliği commit edilir

---

## Kabul Kriterleri

- [ ] `gh --version` çalışıyor
- [ ] `gh auth status` → authenticated
- [ ] `/root/.claude.json` JSON geçerli, PLACEHOLDER yok
- [ ] `supabase --version` çalışıyor (zaten var, sadece doğrula)
- [ ] `.agents/setup.sh` kurulum kontrol bölümü güncellendi
- [ ] Tamamlanınca `task-arge-007-done.md` yaz
