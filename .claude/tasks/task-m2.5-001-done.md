# Task-M2.5-001 Done

## Yapılan İşlemler

1. **Migration dosyası oluşturuldu:** `supabase/migrations/20260403000001_fix_tohumlama_sonuc_bos_ambiguity.sql`
   - Eski tek parametreli `tohumlama_sonuc_bos(text)` fonksiyonu DROP edildi
   - Yeni iki parametreli imza (`p_tohumlama_id text, p_notlar text DEFAULT NULL`) kaldı

2. **Deploy workflow güncellendi:** `.github/workflows/deploy.yml`
   - `fix/*` branch'leri eklendi

3. **Deployment:**
   - fix/tech-debt branch'ten main'e push edildi
   - GitHub Actions otomatik tetiklendi ve migration uygulandı

## Doğrulama Sonucu

```bash
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/rpc/tohumlama_sonuc_bos" \
  -X POST -d '{"p_tohumlama_id": "test-id"}'
```

**Sonuç:** `{"ok": false, "error": "Tohumlama bulunamadı"}`

- ✅ Hata kodu PGRST203 (ambiguity) GİTMİ
- ✅ Fonksiyon çalışıyor (mevcut olmayan ID için beklenen hata)
- ✅ Artık tek imza var: `tohumlama_sonuc_bos(p_tohumlama_id, p_notlar)`

## Commit

```
fix: tohumlama_sonuc_bos duplicate imza temizlendi
chore: deploy workflow fix branch'leri desteklesin
```