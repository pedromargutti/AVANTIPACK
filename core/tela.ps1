# =====================================================================
#  AVANTIPACK - arruma a janela do console DEPOIS que ela abre
#  (nao depende do atalho: funciona mesmo abrindo pelo .bat ou como admin)
#   - fonte Consolas grande e nitida
#   - tamanho da janela de acordo com a tela
#   - janela no meio da tela
#   - desliga a "edicao rapida" (clicar na janela pausava o pack)
#  No Terminal do Windows nada disso se aplica (ele tem a fonte dele).
# =====================================================================
$ErrorActionPreference = 'SilentlyContinue'
try {
    Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AvTela {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct FONTE {
        public uint cbSize; public uint nFont; public short X; public short Y;
        public int FontFamily; public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string FaceName;
    }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr CreateFileW(string n, uint a, uint s, IntPtr sec, uint c, uint f, IntPtr t);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool SetCurrentConsoleFontEx(IntPtr h, bool max, ref FONTE f);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr z, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);

    public static bool Fonte(string nome, short altura) {
        IntPtr o = CreateFileW("CONOUT$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        FONTE f = new FONTE();
        f.cbSize = (uint)Marshal.SizeOf(f); f.X = 0; f.Y = altura;
        f.FontFamily = 0x36; f.FontWeight = 400; f.FaceName = nome;
        return SetCurrentConsoleFontEx(o, false, ref f);
    }
    public static void SemEdicaoRapida() {
        IntPtr i = CreateFileW("CONIN$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        uint m; if (GetConsoleMode(i, out m)) { SetConsoleMode(i, (m | 0x80) & ~(uint)0x40); }
    }
}
'@
} catch { exit 0 }

try { [void][AvTela]::SetProcessDPIAware() } catch {}
$h = [AvTela]::GetConsoleWindow()
if ($h -eq [IntPtr]::Zero) { exit 0 }

# tamanho da tela (pixels reais)
try {
    Add-Type -AssemblyName System.Windows.Forms
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
} catch { exit 0 }

# fonte: ~ 1/46 da altura da tela  (1080p -> 22, 768p -> 16, 1440p -> 30)
$alt = [int][math]::Max(16, [math]::Min(32, [math]::Round($wa.Height / 46)))
try { [void][AvTela]::Fonte('Consolas', [int16]$alt) } catch {}
try { [AvTela]::SemEdicaoRapida() } catch {}

# janela: 100 colunas, altura que cabe na tela (com rolagem longa)
try {
    $cols = 100
    $maxLin = [Console]::LargestWindowHeight
    $lin = [math]::Max(25, [math]::Min($maxLin - 2, 46))
    $maxCol = [Console]::LargestWindowWidth
    if ($cols -gt $maxCol) { $cols = $maxCol }
    if ([Console]::BufferWidth -lt $cols) { [Console]::BufferWidth = $cols }
    [Console]::SetWindowSize(1, 1)
    [Console]::SetBufferSize($cols, 9000)
    [Console]::SetWindowSize($cols, $lin)
} catch {}

# no meio da tela
try {
    Start-Sleep -Milliseconds 80
    $r = New-Object AvTela+RECT
    if ([AvTela]::GetWindowRect($h, [ref]$r)) {
        $w = $r.R - $r.L; $hh = $r.B - $r.T
        $x = $wa.X + [math]::Max(0, [int](($wa.Width - $w) / 2))
        $y = $wa.Y + [math]::Max(0, [int](($wa.Height - $hh) / 2))
        [void][AvTela]::SetWindowPos($h, [IntPtr]::Zero, $x, $y, 0, 0, 0x0001 -bor 0x0004)
    }
} catch {}
exit 0
