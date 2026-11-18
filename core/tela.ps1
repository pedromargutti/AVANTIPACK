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
# registro do que aconteceu (para descobrir por que a fonte nao troca em algum PC)
$logDir = Join-Path $PSScriptRoot 'dados\logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir 'tela.log'
function Log([string]$m) { try { Add-Content -Path $log -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $m) } catch {} }
Log ('---- inicio | PS ' + $PSVersionTable.PSVersion + ' | modo de linguagem: ' + $ExecutionContext.SessionState.LanguageMode)
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
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool GetCurrentConsoleFontEx(IntPtr h, bool max, ref FONTE f);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr z, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);

    // devolve "" se deu certo, ou o codigo de erro do Windows
    public static string Fonte(string nome, short altura) {
        IntPtr o = CreateFileW("CONOUT$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        if (o == new IntPtr(-1)) { return "CONOUT falhou, erro " + Marshal.GetLastWin32Error(); }
        FONTE f = new FONTE();
        f.cbSize = (uint)Marshal.SizeOf(f); f.X = 0; f.Y = altura;
        f.FontFamily = 0x36; f.FontWeight = 400; f.FaceName = nome;
        if (!SetCurrentConsoleFontEx(o, false, ref f)) { return "SetCurrentConsoleFontEx falhou, erro " + Marshal.GetLastWin32Error(); }
        return "";
    }
    public static string FonteAtual() {
        IntPtr o = CreateFileW("CONOUT$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        FONTE f = new FONTE(); f.cbSize = (uint)Marshal.SizeOf(f);
        if (!GetCurrentConsoleFontEx(o, false, ref f)) { return "? (erro " + Marshal.GetLastWin32Error() + ")"; }
        return f.FaceName + " " + f.X + "x" + f.Y + " familia " + f.FontFamily;
    }
    public static void SemEdicaoRapida() {
        IntPtr i = CreateFileW("CONIN$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        uint m; if (GetConsoleMode(i, out m)) { SetConsoleMode(i, (m | 0x80) & ~(uint)0x40); }
    }
}
'@
} catch { Log ('Add-Type falhou: ' + $_.Exception.Message); exit 0 }
Log 'Add-Type ok'

try { [void][AvTela]::SetProcessDPIAware() } catch {}
$h = [AvTela]::GetConsoleWindow()
if ($h -eq [IntPtr]::Zero) { Log 'sem janela de console (Terminal do Windows?)'; exit 0 }
Log ('fonte antes: ' + [AvTela]::FonteAtual())

# tamanho da tela (pixels reais)
try {
    Add-Type -AssemblyName System.Windows.Forms
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
} catch { exit 0 }

# fonte: ~ 1/46 da altura da tela  (1080p -> 22, 768p -> 16, 1440p -> 30)
$alt = [int][math]::Max(16, [math]::Min(32, [math]::Round($wa.Height / 46)))
try {
    $e = [AvTela]::Fonte('Consolas', [int16]$alt)
    if ($e) { Log ("trocar fonte: $e") } else { Log "trocar fonte: ok (Consolas $alt)" }
} catch { Log ('trocar fonte: ' + $_.Exception.Message) }
Log ('fonte depois: ' + [AvTela]::FonteAtual())
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
    Log "janela: $cols x $lin (tela $($wa.Width)x$($wa.Height))"
} catch { Log ('tamanho da janela: ' + $_.Exception.Message) }

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
