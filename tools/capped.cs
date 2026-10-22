// capped.exe - run a program under a hard memory limit (Windows Job Object).
//   capped <limit_MB> <timeout_s> <program> [args...]
// The child starts suspended, is put in the job, then resumed, so it can never allocate past the cap.
// Over the cap, allocations fail (the program dies); the timeout kills the whole job. Closing capped kills it too.
using System;
using System.Runtime.InteropServices;
using System.Text;

static class Capped {
    [StructLayout(LayoutKind.Sequential)] struct IO_COUNTERS { public ulong a, b, c, d, e, f; }
    [StructLayout(LayoutKind.Sequential)] struct BASIC_LIMIT {
        public long PerProcessUserTimeLimit, PerJobUserTimeLimit; public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize; public uint ActiveProcessLimit;
        public UIntPtr Affinity; public uint PriorityClass, SchedulingClass; }
    [StructLayout(LayoutKind.Sequential)] struct EXT_LIMIT {
        public BASIC_LIMIT Basic; public IO_COUNTERS Io;
        public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] struct STARTUPINFO {
        public int cb; public string r, desk, title; public int x, y, w, h, xc, yc, fill, flags;
        public short show, r2; public IntPtr r3, hin, hout, herr; }
    [StructLayout(LayoutKind.Sequential)] struct PROC_INFO { public IntPtr hProcess, hThread; public int pid, tid; }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateJobObject(IntPtr a, string n);
    [DllImport("kernel32.dll")] static extern bool SetInformationJobObject(IntPtr j, int cls, ref EXT_LIMIT i, int len);
    [DllImport("kernel32.dll")] static extern bool QueryInformationJobObject(IntPtr j, int cls, ref EXT_LIMIT i, int len, IntPtr r);
    [DllImport("kernel32.dll")] static extern bool AssignProcessToJobObject(IntPtr j, IntPtr p);
    [DllImport("kernel32.dll")] static extern bool TerminateJobObject(IntPtr j, uint code);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool CreateProcess(string app, StringBuilder cmd,
        IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string cwd, ref STARTUPINFO si, out PROC_INFO pi);
    [DllImport("kernel32.dll")] static extern uint ResumeThread(IntPtr t);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr h, out uint code);

    static string Quote(string a) { return (a.Length > 0 && a.IndexOfAny(new[] { ' ', '\t', '"' }) < 0) ? a : "\"" + a.Replace("\"", "\\\"") + "\""; }

    static int Main(string[] args) {
        if (args.Length < 3) { Console.Error.WriteLine("usage: capped <limit_MB> <timeout_s> <program> [args...]"); return 2; }
        ulong mb = ulong.Parse(args[0]); uint secs = uint.Parse(args[1]);
        var cmd = new StringBuilder();
        for (int i = 2; i < args.Length; i++) { if (i > 2) cmd.Append(' '); cmd.Append(Quote(args[i])); }
        IntPtr job = CreateJobObject(IntPtr.Zero, null);
        var lim = new EXT_LIMIT();
        lim.Basic.LimitFlags = 0x100 | 0x200 | 0x2000;   // PROCESS_MEMORY | JOB_MEMORY | KILL_ON_JOB_CLOSE
        lim.ProcessMemoryLimit = new UIntPtr(mb << 20); lim.JobMemoryLimit = new UIntPtr(mb << 20);
        if (!SetInformationJobObject(job, 9, ref lim, Marshal.SizeOf(lim))) { Console.Error.WriteLine("capped: cannot set job limit"); return 2; }
        var si = new STARTUPINFO(); si.cb = Marshal.SizeOf(si); PROC_INFO pi;
        if (!CreateProcess(null, cmd, IntPtr.Zero, IntPtr.Zero, true, 0x4 /*SUSPENDED*/, IntPtr.Zero, null, ref si, out pi)) {
            Console.Error.WriteLine("capped: cannot start " + args[2] + " (error " + Marshal.GetLastWin32Error() + ")"); return 2; }
        if (!AssignProcessToJobObject(job, pi.hProcess)) { TerminateJobObject(job, 1); Console.Error.WriteLine("capped: cannot assign job"); return 2; }
        ResumeThread(pi.hThread);
        uint w = WaitForSingleObject(pi.hProcess, secs == 0 ? 0xFFFFFFFF : secs * 1000);
        if (w != 0) { TerminateJobObject(job, 124); Console.Error.WriteLine("capped: TIMEOUT after " + secs + " s, killed"); return 124; }
        uint code; GetExitCodeProcess(pi.hProcess, out code);
        QueryInformationJobObject(job, 9, ref lim, Marshal.SizeOf(lim), IntPtr.Zero);
        ulong peak = lim.PeakProcessMemoryUsed.ToUInt64() >> 20;
        if (peak + 2 >= mb) Console.Error.WriteLine("capped: hit the " + mb + " MB memory cap (peak " + peak + " MB)");
        if (Environment.GetEnvironmentVariable("CAPPED_PEAK") == "1") Console.Error.WriteLine("capped: peak " + peak + " MB");
        return (int)code;
    }
}
