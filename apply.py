import subprocess
import sys
import os
import tempfile

REPO_DIR = '/root/egesut-erp1'
os.chdir(REPO_DIR)

# ── SEARCH/REPLACE modu ──────────────────────────────────────────────────────
# Kullanim: python3 apply.py --replace <dosya> /tmp/r.txt
# Dosya formati:
# SEARCH:
# eski metin
# REPLACE:
# yeni metin

if len(sys.argv) > 1 and sys.argv[1] == '--replace':
    if len(sys.argv) < 3:
        print("Kullanim: python3 apply.py --replace <dosya> [/tmp/r.txt]")
        sys.exit(1)
    target = sys.argv[2]
    if len(sys.argv) >= 4:
        raw = open(sys.argv[3], encoding='utf-8').read()
    else:
        print("SEARCH/REPLACE icerik girin, CTRL+D ile bitirin:")
        raw = sys.stdin.read()

    if 'SEARCH:' not in raw or 'REPLACE:' not in raw:
        print("Hata: SEARCH: ve REPLACE: bloklari bulunamadi")
        sys.exit(1)

    parts = raw.split('SEARCH:', 1)[1].split('REPLACE:', 1)
    search_text  = parts[0].strip('\n')
    replace_text = parts[1].strip('\n')

    with open(target, encoding='utf-8') as f:
        content = f.read()

    if search_text not in content:
        print("Hata: SEARCH metni dosyada bulunamadi")
        print("--- ARANAN ---")
        print(repr(search_text[:300]))
        sys.exit(1)

    content = content.replace(search_text, replace_text, 1)
    with open(target, 'w', encoding='utf-8') as f:
        f.write(content)

    subprocess.run(["git", "add", target])
    subprocess.run(["git", "commit", "-m", f"AI replace: {target}"])
    push = subprocess.run(["git", "push"], capture_output=True, text=True)
    print("Tamam" if push.returncode == 0 else f"Push hatasi:\n{push.stderr}")
    sys.exit(0)

# ── PATCH modu (patch -p1) ───────────────────────────────────────────────────
if len(sys.argv) > 1:
    patch_input = open(sys.argv[1], 'r', encoding='utf-8').read()
else:
    print("Patch girin, CTRL+D ile bitirin:")
    patch_input = sys.stdin.read()

with tempfile.NamedTemporaryFile(delete=False, suffix='.patch', mode='w', encoding='utf-8') as f:
    f.write(patch_input)
    patch_file = f.name

dry_run = subprocess.run(["patch", "-p1", "--dry-run", "-i", patch_file], capture_output=True, text=True)
if dry_run.returncode != 0:
    print("Patch uygulanamadi (dry-run):")
    print(dry_run.stderr or dry_run.stdout)
    sys.exit(1)

subprocess.run(["patch", "-p1", "-i", patch_file])
subprocess.run(["git", "add", "."])
subprocess.run(["git", "commit", "-m", "AI patch"])
push = subprocess.run(["git", "push"], capture_output=True, text=True)
print("Tamam" if push.returncode == 0 else f"Push hatasi:\n{push.stderr}")
