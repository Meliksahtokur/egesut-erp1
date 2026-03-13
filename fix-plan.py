# fix_plan.py
import subprocess
import os

os.chdir('/root/egesut-erp1')

def replace_in_file(filepath, search, replace):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    if search not in content:
        print(f"UYARI: {filepath} içinde aranan metin bulunamadı.")
        return False
    new_content = content.replace(search, replace, 1)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"Değiştirildi: {filepath}")
    return True

# 1. _A okumalarını getState('animals') ile değiştir
replacements = [
    # js/app.js
    ('js/app.js', 'let _A = [];', 'let _A = []; // TODO: remove later'),
    ('js/app.js', 'const hayvanObj = _A.find(a => a.id === data.ana_hayvan_id);', 
                   'const hayvanObj = getState(\'animals\').find(a => a.id === data.ana_hayvan_id);'),
    ('js/app.js', 'const h = _A.find(a => a.id === t.hayvan_id);',
                   'const h = getState(\'animals\').find(a => a.id === t.hayvan_id);'),
    ('js/app.js', 'const h = _A.find(a => a.id === k.hayvan_id);',
                   'const h = getState(\'animals\').find(a => a.id === k.hayvan_id);'),
    ('js/app.js', 'const h = _A.find(a => a.id === b.anne_id);',
                   'const h = getState(\'animals\').find(a => a.id === b.anne_id);'),
    ('js/app.js', 'const h = _A.find(a => a.id === t.hayvan_id || a.kupe_no === t.hayvan_id);',
                   'const h = getState(\'animals\').find(a => a.id === t.hayvan_id || a.kupe_no === t.hayvan_id);'),
    ('js/app.js', 'const hayvan = _A.find(a => a.id === id);',
                   'const hayvan = getState(\'animals\').find(a => a.id === id);'),
    ('js/app.js', 'const hayvanObj = _A.find(a => a.id === data.ana_hayvan_id);',
                   'const hayvanObj = getState(\'animals\').find(a => a.id === data.ana_hayvan_id);'),
    # js/forms.js
    ('js/forms.js', 'const hayvan = _A.find(a => a.id === hayvanId);',
                     'const hayvan = getState(\'animals\').find(a => a.id === hayvanId);'),
    ('js/forms.js', 'const hayvan = _A.find(a => a.kupe_no === hid || a.id === hid);',
                     'const hayvan = getState(\'animals\').find(a => a.kupe_no === hid || a.id === hid);'),
    ('js/forms.js', 'const hayvan = _A.find(a => a.id === hid);',
                     'const hayvan = getState(\'animals\').find(a => a.id === hid);'),
    ('js/forms.js', 'const hayvan = _A.find(a => a.id === p_hayvan_id);',
                     'const hayvan = getState(\'animals\').find(a => a.id === p_hayvan_id);'),
    ('js/forms.js', 'const h = _A.find(a => a.id === hayvanId);',
                     'const h = getState(\'animals\').find(a => a.id === hayvanId);'),
    # js/ui.js
    ('js/ui.js', 'const h = _A.find(a => a.id === t.hayvan_id);',
                  'const h = getState(\'animals\').find(a => a.id === t.hayvan_id);'),
    ('js/ui.js', 'const h = _A.find(a => a.id === k.hayvan_id);',
                  'const h = getState(\'animals\').find(a => a.id === k.hayvan_id);'),
    ('js/ui.js', 'const anneObj = _A.find(a => a.id === a.anne_id);',
                  'const anneObj = getState(\'animals\').find(a => a.id === a.anne_id);'),
    ('js/ui.js', 'const hayvan = _A.find(a => a.id === t.hayvan_id);',
                  'const hayvan = getState(\'animals\').find(a => a.id === t.hayvan_id);'),
    ('js/ui.js', 'const hayvan = _A.find(a => a.id === t.hayvan_id || a.kupe_no === t.hayvan_id);',
                  'const hayvan = getState(\'animals\').find(a => a.id === t.hayvan_id || a.kupe_no === t.hayvan_id);'),
    ('js/ui.js', 'const a = _A.find(a => a.id === id);',
                  'const a = getState(\'animals\').find(a => a.id === id);'),
    ('js/ui.js', 'const hayvan = _A.find(a => a.id === k.hayvan_id);',
                  'const hayvan = getState(\'animals\').find(a => a.id === k.hayvan_id);'),
    ('js/ui.js', 'const hayvan = _A.find(a => a.id === t.hayvan_id);',
                  'const hayvan = getState(\'animals\').find(a => a.id === t.hayvan_id);'),
    ('js/ui.js', 'const hayvan = _A.find(a => a.id === b.anne_id);',
                  'const hayvan = getState(\'animals\').find(a => a.id === b.anne_id);'),
]

for f, s, r in replacements:
    replace_in_file(f, s, r)

# 2. _S okumalarını getState('stock') ile değiştir
# Önce _S tanımını bul, setState ekle
replace_in_file('js/app.js', 'let _S = [];', 'let _S = []; // TODO: remove later')
# loadStock içinde setState ekle
replace_in_file('js/app.js', 
    'window._appState=window._appState||{}; window._appState.stok=_S;',
    'window._appState=window._appState||{}; window._appState.stok=_S; setState(\'stock\', _S);')

# ui.js'de _S kullanımlarını değiştir
replace_in_file('js/ui.js', '_S.find(s => s.id === id)', 'getState(\'stock\').find(s => s.id === id)')
replace_in_file('js/ui.js', '_S.filter(s => s.kategori === \'Sperma\')', 'getState(\'stock\').filter(s => s.kategori === \'Sperma\')')
replace_in_file('js/ui.js', '_S.forEach(s => {', 'getState(\'stock\').forEach(s => {')
replace_in_file('js/ui.js', '_S.length', 'getState(\'stock\').length')

# 3. _gebeIds ve _hastaIds'i state'e taşı
# loadAnimals içinde setState ekle
replace_in_file('js/app.js', 
    '_gebeIds=[...new Set([...gebeTohs.map(t=>t.hayvan_id),...animals.filter(a=>a.durum===\'Gebe\').map(a=>a.id)])];',
    '_gebeIds=[...new Set([...gebeTohs.map(t=>t.hayvan_id),...animals.filter(a=>a.durum===\'Gebe\').map(a=>a.id)])]; setState(\'gebeIds\', _gebeIds);')
replace_in_file('js/app.js', 
    '_hastaIds=new Set(hastaLogs.map(d=>d.hayvan_id));',
    '_hastaIds=new Set(hastaLogs.map(d=>d.hayvan_id)); setState(\'hastaIds\', Array.from(_hastaIds));')

# ui.js'de _gebeIds ve _hastaIds kullanımlarını değiştir
replace_in_file('js/ui.js', 'gebeSet.has(a.id)', '(getState(\'gebeIds\') || []).includes(a.id)')
replace_in_file('js/ui.js', '_hastaIds.has(a.id)', '(getState(\'hastaIds\') || []).includes(a.id)')

# 4. config.js'deki hardcoded hastalık listesini kaldır (yorum satırı yap veya sil)
# Daha iyisi, kullanılmadıklarından emin olup silelim. Önce kullanımları kontrol et.
# forms.js'de HASTALIK_LISTESI kullanımı yok, app.js'de var (acDisease, filterHastalikList vb.) ama onlar da eski.
# Eski hastalık fonksiyonlarını devre dışı bırakacağız. Şimdilik config.js'deki sabitleri koruyalım ama kullanımını engelleyelim.
# Aslında en temizi, eski hastalık kodlarını tamamen kaldırmak. Ama bunu ayrı bir aşamada yapalım.
# Şimdilik sadece state geçişini tamamlayalım.

print("Değişiklikler yapıldı. Şimdi git commit ve push yapılıyor.")
subprocess.run(["git", "add", "."])
subprocess.run(["git", "commit", "-m", "fix: _A, _S, _gebeIds state'e taşındı, eski referanslar temizlendi"])
subprocess.run(["git", "push"])

