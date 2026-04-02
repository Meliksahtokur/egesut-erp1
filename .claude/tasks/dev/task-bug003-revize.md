# Task-bug003-revize: feature/gwen-bug003-fix merge öncesi düzeltmeler

**Durum:** revize
**Branch:** feature/gwen-bug003-fix
**Tarih:** 2026-03-30

---

## Bağlam

`feature/gwen-bug003-fix` branch'i review edildi. Üretim kodu (JS/HTML) büyük ölçüde doğru, ancak 4 blocker düzeltilmeden main'e merge edilemez.

---

## Yapılacaklar (sırasıyla)

### 1. `.gitignore` düzelt (KRİTİK)

Mevcut `.gitignore` bozuk — şu anda:
- Dosya `\`\`\`` ile başlıyor (Markdown kod bloğu notasyonu, geçersiz)
- `supabase/migrations/*.sql` satırı var → tüm migration SQL'leri git tarafından görünmez olur

**Yapılacak:**
```
1. Dosyanın başındaki ``` satırını sil
2. `supabase/migrations/*.sql` satırını sil
3. Şu satırları ekle (zaten yoksa):
   dbsnapshot_full.sql
   gwen-mcp-servers/
```

### 2. `dbsnapshot_full.sql` tree'den kaldır

```bash
git rm dbsnapshot_full.sql
```

Bu dosya (3863 satır DB dump) version control'e girmemeli.

### 3. `gwen-mcp-servers/` tree'den kaldır

```bash
git rm -r gwen-mcp-servers/
```

Context7, Exa, Supabase, GitHub sunucu kodları bu repoya ait değil.

### 4. `forms.js` — `tohSonuc()` else branch düzelt

`js/forms.js` içindeki `tohSonuc()` fonksiyonunda `else` branch hâlâ direkt `write()` yapıyor:

```js
} else {
  // Diğer durumlar için direkt write (backward compat)
  await write('tohumlama', { ..._curToh, sonuc }, 'PATCH', `id=eq.${_curToh.id}`);
```

**Domain kural #8:** Tohumlama verisi yalnızca RPC üzerinden yazılmalı.

**Yapılacak:** Bu `else` branch'ini kaldır. Pratikte 'Gebe' ve 'Boş' dışında başka bir `sonuc` değeri gelmez; gelse bile hata toast'u göster:

```js
} else {
  toast('⛔ Geçersiz sonuç: ' + sonuc, true);
  return;
}
```

---

## Kabul Kriterleri

- [ ] `.gitignore` geçerli syntax (backtick yok, migrations satırı yok)
- [ ] `dbsnapshot_full.sql` tree'de yok
- [ ] `gwen-mcp-servers/` tree'de yok
- [ ] `tohSonuc()` else branch `write()` içermiyor
- [ ] `node --check js/*.js` hata vermez
- [ ] Branch push edildi, burada `task-bug003-done.md` raporu yazıldı

---

## Notlar

- Üretim kodundaki değişiklikler (RPC migration, selDis fix, 330 gün, stok hareketleri) onaylandı — bunlara dokunma
- `package-lock.json` değişikliği kabul edildi (gwen-mcp dependencies çıkınca kendiliğinden temizlenir)
- Düzeltme tamamlanınca Claude bu branch'i tekrar review edecek
