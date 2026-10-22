"""Memory-capped jdBasic runs for the Python test scripts (same caps as tools/jd.sh)."""
import os, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAP = os.path.join(ROOT, "tools", "capped.exe")
JDBASIC = r"C:\Users\amine\jdbasic-native\jdBasic.exe"


def run(src, *args, native=False, mem_mb=1024, timeout_s=600):
    """Run src.jdb interpreted, or compile it with -c and run the .exe; both under a hard memory cap."""
    if native:
        r = subprocess.run([CAP, "4096", "600", JDBASIC, "-c", src], capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stdout + r.stderr)
            raise SystemExit(f"compile of {src} failed")
        cmd = [os.path.abspath(src[:-4] + ".exe")]
    else:
        cmd = [JDBASIC, src]
    subprocess.run([CAP, str(mem_mb), str(timeout_s)] + cmd + list(args), check=True)
