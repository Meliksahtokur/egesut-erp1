import subprocess, sys, os, tempfile
REPO_DIR = '/root/egesut-erp1'
os.chdir(REPO_DIR)

def do_replace(target, raw):
    blocks = raw.split('---\n')
    with open(target, encoding='utf-8') as f: content = f.read()
    for block in blocks:
        if 'SEARCH:' not in block or 'REPLACE:' not in block: continue
        parts = block.split('SEARCH:', 1)[1].split('REPLACE:', 1)
        s = parts[0].strip('\n')
        r = parts[1].strip('\n')
        if s not in content:
            print(f"HATA: bulunamadi → {target}: {s[:60]}"); return False
        content = content.replace(s, r, 1)
        print(f"OK: {target}")
    with open(target, 'w', encoding='utf-8') as f: f.write(content)
    return True

if len(sys.argv) > 1 and sys.argv[1] == '--replace':
    target = sys.argv[2]
    raw = open(sys.argv[3], encoding='utf-8').read() if len(sys.argv) >= 4 else sys.stdin.read()
    if not do_replace(target, raw): sys.exit(1)
    subprocess.run(["git", "add", target])
    subprocess.run(["git", "commit", "-m", f"AI replace: {target}"])
    push = subprocess.run(["git", "push"], capture_output=True, text=True)
    print("Tamam" if push.returncode == 0 else f"Push hatasi:\n{push.stderr}")
    sys.exit(0)

patch_input = open(sys.argv[1], 'r', encoding='utf-8').read() if len(sys.argv) > 1 else sys.stdin.read()
with tempfile.NamedTemporaryFile(delete=False, suffix='.patch', mode='w', encoding='utf-8') as f:
    f.write(patch_input); patch_file = f.name
dry = subprocess.run(["patch", "-p1", "--dry-run", "-i", patch_file], capture_output=True, text=True)
if dry.returncode != 0:
    print("Patch uygulanamadi:"); print(dry.stderr or dry.stdout); sys.exit(1)
subprocess.run(["patch", "-p1", "-i", patch_file])
subprocess.run(["git", "add", "."])
subprocess.run(["git", "commit", "-m", "AI patch"])
push = subprocess.run(["git", "push"], capture_output=True, text=True)
print("Tamam" if push.returncode == 0 else f"Push hatasi:\n{push.stderr}")
