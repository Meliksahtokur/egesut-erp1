import subprocess
import sys
import os
import tempfile

REPO_DIR = '/home/egesut-erp1'
os.chdir(REPO_DIR)

if len(sys.argv) > 1:
    patch_input = open(sys.argv[1], 'r').read()
else:
    print("Patch girin, CTRL+D ile bitirin:")
    patch_input = sys.stdin.read()

with tempfile.NamedTemporaryFile(delete=False, suffix='.patch') as f:
    f.write(patch_input.encode())
    patch_file = f.name

dry_run = subprocess.run(["git", "apply", "--check", patch_file], capture_output=True, text=True)
if dry_run.returncode != 0:
    print("Patch uygulanamadi:")
    print(dry_run.stderr)
    sys.exit(1)

apply_result = subprocess.run(["git", "apply", patch_file], capture_output=True, text=True)
if apply_result.returncode != 0:
    print("Patch uygulanamadi:")
    print(apply_result.stderr)
    sys.exit(1)

subprocess.run(["git", "add", "."])
subprocess.run(["git", "commit", "-m", "AI patch"])
push_result = subprocess.run(["git", "push"], capture_output=True, text=True)

if push_result.returncode == 0:
    print("Tamam")
else:
    print("Push hatasi:")
    print(push_result.stderr)
