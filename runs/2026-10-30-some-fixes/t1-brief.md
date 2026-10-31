# t1 — Erkek doğum kaydı / ölmüş hayvan küpesi teşhisi
job_id: j-20261030T181742Z-663858
## Plan maddesi
Sahip şikayeti: "erkek doğum kaydı yapılamıyor, ölmüş hayvanların küpe numaraları kullanılamıyor. hayvanın biri doğum yaptı, hâlâ kaydı girilmedi." Kök nedeni kanıtla bul. FIX YAZMA.
Beklenen kural: .harness/references/domain-rules.md §1 Küpe Numara Planı (K1 recycle, K3 çift katman, erkek 500-599 zorunlu, K6 öneri) — önce oku.
İncele (hepsi):
1. Canlı prod (yalnız SELECT): `dogum_kaydet` tüm overload gövdeleri (`pg_get_functiondef`), `kupe_musait_mi`, `hayvanlar` üzerindeki unique index/constraint'ler (`hayvanlar_kupe_no_key` partial mı, başka unique var mı), hayvanlar + dogum trigger'ları (buzağı INSERT yolunda küpe/durum kontrolü yapan her şey), `hayvan_ekle` overload'ları.
2. Veri: 500-599 aralığında tüm hayvanlar (kupe_no, durum, cinsiyet, grup); aktif olanlar hangileri, boş kaç numara var; çıkmış hayvan küpesiyle çakışma senaryosu. Son 60 gün doğum kayıtları; Gebe olup tahmini doğumu geçmiş anneler (kayıt bekleyen aday hayvan).
3. Frontend: `submitBirth` (js/forms.js), `bosKupeOner` (js/config.js), küpe kontrolünün lokal state'te çıkmış hayvanları sayıp saymadığı, `b-kupe` doğrulaması, offline kuyruk yolu. Kod keşfi: atlas_query → gövde Read.
4. Git: main ile worktree aynı mı; canlı RPC gövdesi son migration ile aynı mı (drift). Son ilgili migration'lar (ör. 2026-10 dönemi) küpe kuralını regress etmiş mi.
5. Demo DB ya da BEGIN…ROLLBACK ile DENEME YAPMA prod'da; prod'da yan etkili hiçbir şey koşma. Mümkünse hatayı salt-okuma mantıkla (gövde+veri izleme) ya da demo'da yeniden üret (demo_reader/yöntem için memory: demo-db-tablo-haritasi). Demo'ya da yazma gerekiyorsa yapma, raporda söyle.
Canlı sorgu yöntemi: `cd ~/egesut-erp1; set -a; source ./.env; set +a; curl -sS -X POST "https://api.supabase.com/v1/projects/${SB_PROJECT_REF:-zqnexqbdfvbhlxzelzju}/database/query" -H "Authorization: Bearer ${SB_MGMT_TOKEN}" -H "Content-Type: application/json" --data-binary @<json dosya>`. urllib kullanma, token'ı yazdırma. Geçici dosya: $HOME/tmp.
Rapor: kök neden(ler) (dosya:satır / canlı sorgu kanıtı, CONFIRMED/OBSERVED/INFERRED etiketli), kullanıcının gördüğü hata metni büyük olasılıkla ne, minimal fix önerisi (migration mı JS mi, satır düzeyi), o hayvanın doğumunu şu an girebilmek için geçici yol var mı.
## Model
opus
## Yazılabilir dosyalar
runs/2026-10-30-some-fixes/t1-report.md
## Review: T1
