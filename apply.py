import subprocess
import sys
import tempfile

patch = sys.stdin.read()

with tempfile.NamedTemporaryFile(delete=False) as f:
    f.write(patch.encode())
    patch_file = f.name

result = subprocess.run(["git", "apply", patch_file])

if result.returncode != 0:
    print("❌ Patch uygulanamadı")
    sys.exit(1)

subprocess.run(["git", "add", "."])
subprocess.run(["git", "commit", "-m", "AI patch"])
subprocess.run(["git", "push"])

print("✅ Patch uygulandı ve push edildi")