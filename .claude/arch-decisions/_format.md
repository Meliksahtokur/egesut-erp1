# Mimari Kararlar

Bu dizin erp-architect tarafından yönetilir.
Tüm execution agent'ları (erp-frontend-dev, erp-db-agent vb.) iş başlamadan önce
ilgili kararı okur ve uygular. **Kararlar bağlayıcıdır, tartışılmaz.**

## Format

```markdown
# ADR-[NNN]: [başlık]
Tarih: [YYYY-MM-DD]
Durum: taslak | onaylandı | geçersiz
Etkilenen: [erp-frontend-dev | erp-db-agent | her ikisi]

## Karar
[Ne yapılacak — 1-3 cümle]

## Bağlam
[Neden bu karar — zorunlu bilgi]

## Contract
[Tam teknik spec: RPC imzası, tablo yapısı, naming convention vb.]

## Yasak
[Bu kararla çelişen şeyler]
```
