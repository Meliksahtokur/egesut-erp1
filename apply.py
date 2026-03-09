import subprocess
import sys
import os

os.chdir('/home/egesut-erp1')

patch = sys.stdin.read()

with open("/tmp/patch.diff", "w") as f:
    f.write(patch)

result = subprocess.run(["git", "apply", "/tmp/patch.diff"], capture_output=True, text=True)

if result.returncode == 0:
    subprocess.run(["git", "add", "."])
    subprocess.run(["git", "commit", "-m", "AI patch"])
    push = subprocess.run(["git", "push"], capture_output=True, text=True)
    if push.returncode == 0:
        print("✅ Push tamam")
    else:
        print("❌ Push hata:", push.stderr)
else:
    print("❌ Patch hata:", result.stderr)