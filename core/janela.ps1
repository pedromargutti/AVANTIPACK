# =====================================================================
#  AVANTIPACK - janela do menu
#  Cria o atalho AVANTIPACK.lnk (com a logo) que abre o menu:
#   - como administrador
#   - com fonte Consolas, tamanho certo e centralizado na tela
#   - com as cores certas e sem o "modo de edicao rapida" (que pausa
#     o pack quando a pessoa clica na janela)
#  Uso: powershell -File janela.ps1 [-Desktop]
# =====================================================================
param([switch]$Desktop)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Bat  = Join-Path $PSScriptRoot 'AVANTIPACK.bat'
$Ico  = Join-Path $PSScriptRoot 'avantipack.ico'

# --- tamanho da tela em pixels reais (sem a escala do Windows) ---------
function Get-TelaReal {
    try {
        Add-Type -Namespace AvJanela -Name Dpi -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
'@ -ErrorAction SilentlyContinue
        [void][AvJanela.Dpi]::SetProcessDPIAware()
        Add-Type -AssemblyName System.Windows.Forms
        $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        return @{ W = $wa.Width; H = $wa.Height; X = $wa.X; Y = $wa.Y }
    } catch { return @{ W = 1920; H = 1040; X = 0; Y = 0 } }
}

# --- bloco de propriedades do console (MS-SHLLINK ConsoleDataBlock) ----
function New-ConsoleBlock {
    $t = Get-TelaReal
    # Consolas: e a fonte nitida que o console classico SEMPRE aceita (com a Cascadia
    # ele voltava para a fonte de pixel antiga). Tamanho pela altura da tela.
    $fh = [int][math]::Max(16, [math]::Min(32, [math]::Round($t.H / 46)))   # 1080p -> 22
    $fonte = 'Consolas'
    $fw = [math]::Round($fh * 0.55)
    $cols = 100
    $rows = [math]::Min(46, [math]::Floor(($t.H * 0.88) / $fh))
    $wpx = $cols * $fw + 36
    $hpx = $rows * $fh + 56
    $x = $t.X + [math]::Max(0, [math]::Floor(($t.W - $wpx) / 2))
    $y = $t.Y + [math]::Max(0, [math]::Floor(($t.H - $hpx) / 2))

    $ms = New-Object IO.MemoryStream
    $bw = New-Object IO.BinaryWriter($ms)
    $bw.Write([uint32]0xCC); $bw.Write([uint32]2684354562)
    $bw.Write([uint16]0x07); $bw.Write([uint16]0xF5)          # cores do texto / popup
    $bw.Write([int16]$cols); $bw.Write([int16]9001)            # buffer (rolagem longa)
    $bw.Write([int16]$cols); $bw.Write([int16]$rows)           # janela
    $bw.Write([int16]$x);    $bw.Write([int16]$y)              # posicao
    $bw.Write([uint32]0); $bw.Write([uint32]0)
    $bw.Write([uint32]($fh -shl 16))                           # fonte: altura
    $bw.Write([uint32]0x36); $bw.Write([uint32]400)            # TrueType moderna, normal
    $nome = [Text.Encoding]::Unicode.GetBytes($fonte); $face = New-Object byte[] 64
    [Array]::Copy($nome, $face, $nome.Length); $bw.Write($face)
    $bw.Write([uint32]25)   # cursor
    $bw.Write([uint32]0)    # tela cheia
    $bw.Write([uint32]0)    # QuickEdit desligado (clique nao pausa o pack)
    $bw.Write([uint32]1)    # insert
    $bw.Write([uint32]0)    # usar a posicao acima (centralizado)
    $bw.Write([uint32]50); $bw.Write([uint32]4); $bw.Write([uint32]0)
    # paleta "Campbell" (a mesma do Terminal do Windows) - formato 0x00BBGGRR
    $cores = 0x0C0C0C, 0x0037DA, 0x13A10E, 0x3A96DD, 0xC50F1F, 0x881798, 0xC19C00, 0xCCCCCC,
             0x767676, 0x3B78FF, 0x16C60C, 0x61D6D6, 0xE74856, 0xB4009E, 0xF9F1A5, 0xF2F2F2
    foreach ($c in $cores) { $bw.Write([uint32]((($c -band 0xFF) -shl 16) -bor ($c -band 0xFF00) -bor (($c -shr 16) -band 0xFF))) }
    $bw.Flush()
    $b = $ms.ToArray()
    if ($b.Length -ne 0xCC) { throw "bloco do console com tamanho errado: $($b.Length)" }
    return , $b
}

# --- coloca o bloco no .lnk e marca "Executar como administrador" ------
function Set-LnkExtras([string]$lnk, [byte[]]$bloco) {
    $b = [IO.File]::ReadAllBytes($lnk)
    $b[0x15] = $b[0x15] -bor 0x20                               # RunAsUser
    # acha o inicio do ExtraData: pula cabecalho, IDList, LinkInfo e strings
    $flags = [BitConverter]::ToUInt32($b, 0x14)
    $p = 0x4C
    if ($flags -band 0x01) { $p += 2 + [BitConverter]::ToUInt16($b, $p) }
    if ($flags -band 0x02) { $p += [BitConverter]::ToUInt32($b, $p) }
    $uni = ($flags -band 0x80) -ne 0
    foreach ($bit in 0x04, 0x08, 0x10, 0x20, 0x40) {
        if ($flags -band $bit) { $n = [BitConverter]::ToUInt16($b, $p); $p += 2 + $(if ($uni) { $n * 2 } else { $n }) }
    }
    # percorre os blocos extras, descartando um ConsoleDataBlock antigo
    $saida = New-Object Collections.Generic.List[byte]
    $saida.AddRange([byte[]]$b[0..($p - 1)])
    while ($p + 4 -le $b.Length) {
        $sz = [BitConverter]::ToUInt32($b, $p)
        if ($sz -lt 4) { break }
        $sig = [BitConverter]::ToUInt32($b, $p + 4)
        if ($sig -ne 2684354562) { $saida.AddRange([byte[]]$b[$p..($p + $sz - 1)]) }
        $p += $sz
    }
    $saida.AddRange($bloco)
    $saida.AddRange([byte[]](0, 0, 0, 0))                       # fim dos blocos
    [IO.File]::WriteAllBytes($lnk, $saida.ToArray())
}

function New-AvantiShortcut([string]$lnk) {
    $sh = New-Object -ComObject WScript.Shell
    $s = $sh.CreateShortcut($lnk)
    $s.TargetPath = Join-Path $env:SystemRoot 'System32\cmd.exe'
    $s.Arguments = '/c ""' + $Bat + '" lnk"'
    $s.WorkingDirectory = $Root
    if (Test-Path $Ico) { $s.IconLocation = "$Ico,0" }
    $s.Description = 'AVANTIPACK - otimizacao do Windows para jogos'
    $s.Save()
    Set-LnkExtras $lnk (New-ConsoleBlock)
}

try {
    foreach ($v in 'AVANTIPACK.lnk', 'ABRIR AVANTIPACK.lnk') { $velho = Join-Path $Root $v; if (Test-Path -LiteralPath $velho) { Remove-Item -LiteralPath $velho -Force -ErrorAction SilentlyContinue } }
    $alvo = Join-Path $PSScriptRoot 'AVANTIPACK.lnk'      # o AVANTIPACK.exe abre este atalho
    New-AvantiShortcut $alvo
    # area de trabalho: cria na primeira vez; depois so atualiza se existir
    # (se a pessoa apagou, nao volta; se mudou a pasta do pack, corrige)
    $dk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AVANTIPACK.lnk'
    if ($Desktop -or (Test-Path $dk)) { try { New-AvantiShortcut $dk } catch {} }
    exit 0
} catch {
    try {
        $ld = Join-Path $PSScriptRoot 'dados\logs'; New-Item -ItemType Directory -Path $ld -Force | Out-Null
        Add-Content -Path (Join-Path $ld 'janela.log') -Value ((Get-Date -Format s) + ' ERRO ao criar o atalho: ' + $_.Exception.Message + ' | ' + $_.InvocationInfo.PositionMessage)
    } catch {}
    exit 1
}
