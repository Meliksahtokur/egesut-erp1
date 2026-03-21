#!/usr/bin/env python3
import sys, shutil, subprocess
from pathlib import Path

def backup(path):
    shutil.copy2(path, str(path) + ".bak")

def ok(msg):   print(f"OK  {msg}")
def warn(msg): print(f"WARN {msg}")
def die(msg):  print(f"ERR {msg}"); sys.exit(1)

def apply_patch(target, raw):
    blocks = [b for b in raw.split("---\n") if "SEARCH:" in b and "REPLACE:" in b]
    if not blocks:
        die("Geçerli SEARCH/REPLACE bloğu bulunamadı.")
    content = target.read_text(encoding="utf-8")
    working = content
    for i, block in enumerate(blocks, 1):
        after_search = block.split("SEARCH:", 1)[1]
        parts = after_search.split("REPLACE:", 1)
        search_text  = parts[0].lstrip("\n").rstrip("\n")
        replace_text = parts[1].lstrip("\n").rstrip("\n")
        if search_text not in working:
            warn(f"Blok {i}: bulunamadı -> {search_text[:80]!r}")
            return False
        working = working.replace(search_text, replace_text, 1)
        ok(f"Blok {i}: uygulandı")
    backup(target)
    target.write_text(working, encoding="utf-8")
    return True

def git_commit_push(target):
    check = target.parent
    for _ in range(5):
        if (check / ".git").exists(): break
        check = check.parent
    else: return
    subprocess.run(["git", "add", str(target)], cwd=check)
    # node --check
    if target.suffix == '.js':
        r = subprocess.run(["node", "--check", str(target)], capture_output=True, text=True)
        if r.returncode != 0:
            print(f"SYNTAX HATASI - push yapilmadi:\n{r.stderr[:300]}")
            return
    subprocess.run(["git", "commit", "-m", f"patch: {target.name}"], cwd=check)
    push = subprocess.run(["git", "push"], cwd=check, capture_output=True, text=True)
    if push.returncode == 0: ok("git push tamam")
    else: warn(f"push hatasi: {push.stderr.strip()}")

def main():
    args = sys.argv[1:]
    if len(args) < 2: print("Kullanim: patch.py <dosya> <patch|->\n"); sys.exit(0)
    target = Path(args[0])
    if not target.exists(): die(f"Dosya bulunamadi: {target}")
    raw = sys.stdin.read() if args[1] == "-" else Path(args[1]).read_text(encoding="utf-8")
    if not apply_patch(target, raw): die("Patch uygulanamadi.")
    git_commit_push(target)

if __name__ == "__main__":
    main()
