"""Memory-capped jdBasic runs for the Python test scripts (same caps as tools/jd.sh).

Windows: tools/capped.exe (Job Object). Linux (the CI container): `wine` under xvfb-run, where the container's
--memory limit is the memory cap and `timeout` is the wall-clock cap. $JDBASIC overrides the jdBasic.exe path.
"""
import os, shutil, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAP = os.path.join(ROOT, "tools", "capped.exe")
WINDOWS = os.name == "nt"
JDBASIC = os.environ.get("JDBASIC") or (r"C:\Users\amine\jdbasic-native\jdBasic.exe" if WINDOWS else "/opt/jdbasic/jdBasic.exe")


def _wrap(mem_mb, timeout_s, cmd):
    if WINDOWS:
        return [CAP, str(mem_mb), str(timeout_s)] + cmd
    xvfb = ["xvfb-run", "-a"] if shutil.which("xvfb-run") else []
    return ["timeout", str(timeout_s)] + xvfb + ["wine"] + cmd


def run(src, *args, native=False, mem_mb=1024, timeout_s=600):
    """Run src.jdb interpreted, or compile it with -c and run the .exe; both under a hard memory cap."""
    if native:
        r = subprocess.run(_wrap(4096, 600, [JDBASIC, "-c", src]), capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stdout + r.stderr)
            raise SystemExit(f"compile of {src} failed")
        cmd = [os.path.abspath(src[:-4] + ".exe")]
    else:
        cmd = [JDBASIC, src]
    subprocess.run(_wrap(mem_mb, timeout_s, cmd + list(args)), check=True)
