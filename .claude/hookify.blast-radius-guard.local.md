---
name: blast-radius-guard
enabled: false
event: file
action: block
conditions:
  - field: file_path
    operator: regex_match
    pattern: js/(ui|api|forms|app|state)\.js$
  - field: new_string
    operator: regex_match
    pattern: .+
---

🎯 **Blast radius kontrolü — editlemeden önce çalıştır:**

```js
gitnexus_impact({target: "DEĞİŞTİRECEĞİN_FONKSİYON", direction: "upstream"})
```

Sonuç HIGH veya CRITICAL ise → editlemeden önce kullanıcıya bildir ve onay al.

**Neden:** Bu 5 JS dosyası birbirini çağırıyor. Bir fonksiyonu değiştirmek
onlarca yere etkisi olabilir. geçmiş: `overrideOc` yanlış yerleştirildi,
`isSonToh` sort tiebreaker atlandı, `openDet` global ezme hatası — hepsi
blast radius analizi yapılmadan yapılan değişiklikler yüzünden.

**Kısayol:** Fonksiyon adını bilmiyorsan önce semantic_search veya gitnexus_query ile bul.
