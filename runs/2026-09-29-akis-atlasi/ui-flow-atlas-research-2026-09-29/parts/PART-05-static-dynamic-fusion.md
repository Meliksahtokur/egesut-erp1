# PART-05 — Statik + dinamik graph birleştirme

## Mevcut GitNexus avantajı

Projede zaten call graph/route_map/trace/impact üreten GitNexus var. Bu büyük avantaj: yeni bir full static analyzer yazmak yerine runtime evidence node'larını GitNexus node'larına bağlamak yeterli.

## Join anahtarları

### UI → JS

Runtime:
- locator / DOM path / ARIA role+name
- event type
- screenshot state id

Static:
- `onclick="foo(...)"`
- `addEventListener('click', foo)`
- delegated handler pattern

Join:
- explicit handler adı varsa direct
- yoksa element signature + source instrumentation

### JS → Supabase RPC

Vanilla JS için yüksek değerli literal pattern:

```js
supabase.rpc('fn_name', payload)
```

Statik graph'ta `fn_name` node'u oluştur. Runtime HAR `/rest/v1/rpc/fn_name` ile aynı canonical ID'ye bağlanır.

Eğer RPC adı dinamik üretiliyorsa runtime edge CONFIRMED, static edge PARTIAL olsun.

### Runtime → source coverage

Playwright 1.64-next tracing API'de Istanbul instrument edilmiş uygulama kodu için coverage kaydı desteği görünür. [S36]

Bu özellik prod build'i değiştirmeden demo/instrumented build'de kullanılabilir. Flow testinin gerçekten hangi JS satırlarını çalıştırdığı, GitNexus call graph ile cross-check için güçlü kanıt olur.

## Unified graph schema

```json
{
  "node": {
    "id": "rpc.save_insemination",
    "kind": "rpc",
    "labels": ["reproduction"],
    "static_refs": ["ui.js:4312"],
    "runtime_refs": ["run-44:req-84"],
    "db_refs": ["public.save_insemination(…)"],
    "confidence": "confirmed-runtime+static"
  }
}
```

Edge confidence örneği:
- `confirmed-runtime`: gerçek run'da görüldü
- `confirmed-static`: source/catalog doğrulandı
- `confirmed-both`
- `inferred`: isim/heuristic eşleşmesi
- `unverified`

## Çelişki tespiti

Atlasın en değerli işi “aynı fikir iki farklı yerde üretilebiliyor” uyarısıdır.

Örnek query:

```text
find producers where output_kind='task'
  and task_type='pregnancy_check'
  group by producer
```

Beklenen sonuç:
- RPC producer +21d
- RPC producer +35d
- cron producer +40d

Eğer dokumentasyon “yalnız +40d cron” diyorsa graph otomatik conflict çıkarır.

## Neden full OpenTelemetry'yi ilk adım yapmıyoruz?

Browser instrumentation ile frontend→backend trace context geçirmek mümkün; OpenTelemetry demo dokümanı browser fetch instrumentation örneği gösteriyor. [S37]

Ama sizin problem için:
- Supabase hosted API/DB zincirine trace context'i uçtan uca taşımak ek iş,
- demo-only Playwright trace zaten action/network korelasyonunu veriyor,
- APM/telemetry katmanı üretim monitoring kapsamına kayabilir.

OTel sadece daha sonra “backend latency / distributed trace” ihtiyacı doğarsa eklenmeli.
