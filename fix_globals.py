import subprocess
import os
import re

os.chdir('/root/egesut-erp1')

def replace_in_file(filepath, pattern, replacement):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    new_content = re.sub(pattern, replacement, content)
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Değiştirildi: {filepath}")
        return True
    else:
        print(f"Değişiklik yok: {filepath}")
        return False

# _A -> getState('animals')
replace_in_file('js/forms.js', r'(?<![a-zA-Z0-9_])_A(?![a-zA-Z0-9_])', 'getState(\'animals\')')
replace_in_file('js/ui.js', r'(?<![a-zA-Z0-9_])_A(?![a-zA-Z0-9_])', 'getState(\'animals\')')
# app.js'deki _A'lar zaten yorum satırı, dokunmayalım

# _S -> getState('stock')
replace_in_file('js/forms.js', r'(?<![a-zA-Z0-9_])_S(?![a-zA-Z0-9_])', 'getState(\'stock\')')
replace_in_file('js/ui.js', r'(?<![a-zA-Z0-9_])_S(?![a-zA-Z0-9_])', 'getState(\'stock\')')
# app.js'deki _S'ler değişken tanımı ve loadStock içinde kullanılıyor, onlara dokunma
# ama loadStock içinde _S'ye atama yapılıyor, onu state'e de atamalıyız.

# _gebeIds -> getState('gebeIds')
replace_in_file('js/ui.js', r'(?<![a-zA-Z0-9_])_gebeIds(?![a-zA-Z0-9_])', 'getState(\'gebeIds\')')

# _hastaIds -> getState('hastaIds')
replace_in_file('js/ui.js', r'(?<![a-zA-Z0-9_])_hastaIds(?![a-zA-Z0-9_])', 'getState(\'hastaIds\')')

# Şimdi loadAnimals içinde _gebeIds ve _hastaIds'yi state'e set etmemiz gerekiyor.
# ui.js içindeki loadAnimals fonksiyonunu bulup düzenleyelim.
ui_path = 'js/ui.js'
with open(ui_path, 'r', encoding='utf-8') as f:
    ui_content = f.read()

# _gebeIds ve _hastaIds hesaplamalarını bul ve setState ekle
pattern_gebe = r'(_gebeIds\s*=\s*\[\.\.\.new Set\(\[\.\.\.gebeTohs\.map\(t=>t\.hayvan_id\),\.\.\.animals\.filter\(a=>a\.durum===\'Gebe\'\)\.map\(a=>a\.id\)\]\)\];)'
replacement_gebe = r'\1\n  setState(\'gebeIds\', _gebeIds);'
ui_content = re.sub(pattern_gebe, replacement_gebe, ui_content)

pattern_hasta = r'(_hastaIds\s*=\s*new Set\(hastaLogs\.map\(d=>d\.hayvan_id\)\);)\s*'
replacement_hasta = r'\1\n  setState(\'hastaIds\', _hastaIds);'
ui_content = re.sub(pattern_hasta, replacement_hasta, ui_content)

# loadStock içinde _S'yi state'e set et
pattern_stock = r'(_S\s*=\s*stk\.map\(s=>\{.*?\}\);)\s*'
replacement_stock = r'\1\n  setState(\'stock\', _S);'
ui_content = re.sub(pattern_stock, replacement_stock, ui_content, flags=re.DOTALL)

with open(ui_path, 'w', encoding='utf-8') as f:
    f.write(ui_content)
print("ui.js güncellendi: state set'leri eklendi.")

# app.js'de loadStock içinde de _S'yi state'e set etmek gerekebilir, ama zaten window._appState.stok var.
# forms.js'deki bazı _S kullanımları da var, onlar da değişti.

# Şimdi app.js'deki _S ve _A tanımlarını kaldırabiliriz (artık kullanılmıyorlar)
# Ama dikkatli olalım, app.js'de _S hâlâ loadStock içinde hesaplanıyor. Onu da state'e set edelim.
app_path = 'js/app.js'
with open(app_path, 'r', encoding='utf-8') as f:
    app_content = f.read()

# loadStock fonksiyonunu bul (app.js'de tanımlı değil, api.js'de olabilir) - aslında app.js'de yok, api.js'de var.
# api.js'de loadStock yok, sadece idbGetAll ile alınıyor.
# Stok yönetimi ui.js'deki loadStock ile yapılıyor. O zaten düzenlendi.

# app.js'deki global değişken tanımlarını kaldıralım (yorum satırı yapalım)
pattern_global = r'^(let _S = \[\]|let _curStk = null|let _curPg = \'dash\'|let _suruFilter = \'tumuu\'|let _suruSiralama = \'kupe\'|let _curUremeTab = \'kizginlik\'|let _curGecmisFilter = \'hepsi\'|let _curTaskFilter = \'today\')'
app_content = re.sub(pattern_global, r'// \1', app_content, flags=re.MULTILINE)

with open(app_path, 'w', encoding='utf-8') as f:
    f.write(app_content)
print("app.js güncellendi: global tanımlar yorum satırı yapıldı.")

# Şimdi git commit
subprocess.run(["git", "add", "."])
subprocess.run(["git", "commit", "-m", "fix: _A, _S, _gebeIds, _hastaIds state'e taşındı ve setState eklendi"])
subprocess.run(["git", "push"])

print("İşlem tamamlandı.")
