# =====================================================================
#  AVANTIPACK - motor principal
#  Compativel com Windows PowerShell 5.1 (Windows 10/11)
#  Uso: powershell -ExecutionPolicy Bypass -File avanti.ps1 -Module <nome>
#
#  Regra de ouro: TODA alteracao passa por Set-Reg / Set-Svc /
#  Disable-Task / Set-NetAdv / Add-Undo, que gravam o valor ORIGINAL
#  em backup\backup.csv antes de mudar. O modulo "undo" usa esse
#  arquivo para voltar exatamente ao que era.
#  (Arquivo sem acentos de proposito, para nao quebrar no PS 5.1.)
# =====================================================================
param([Parameter(Mandatory = $true)][string]$Module)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

$Root       = Split-Path -Parent $PSScriptRoot
$Dados      = Join-Path $PSScriptRoot 'dados'      # tudo o que e deste PC fica aqui
$BackupDir  = Join-Path $Dados 'backup'
$DataDir    = Join-Path $Dados 'data'
$LogDir     = Join-Path $Dados 'logs'

# Organizacao da v0.7.5: a pasta principal fica so com o AVANTIPACK.exe, o
# LEIA-ME e as pastas. Move os dados antigos e apaga os arquivos que mudaram
# para dentro de core\ (so se a copia nova ja existir).
try {
    foreach ($n in @('backup', 'data', 'logs')) {
        $velho = Join-Path $Root $n; $novo = Join-Path $Dados $n
        if ((Test-Path $velho) -and -not (Test-Path $novo)) {
            New-Item -ItemType Directory -Path $Dados -Force | Out-Null
            Move-Item -LiteralPath $velho -Destination $novo -Force
        } elseif ((Test-Path $velho) -and (Test-Path $novo)) {
            Get-ChildItem -LiteralPath $velho -Force | ForEach-Object {
                $d = Join-Path $novo $_.Name
                if (-not (Test-Path $d)) { Move-Item -LiteralPath $_.FullName -Destination $d -Force }
            }
            if (-not (Get-ChildItem -LiteralPath $velho -Force)) { Remove-Item -LiteralPath $velho -Force }
        }
    }
    foreach ($n in @('VERSION.txt', 'NOVIDADES.md', 'AVANTIPACK.bat')) {
        $velho = Join-Path $Root $n
        if ((Test-Path $velho) -and (Test-Path (Join-Path $PSScriptRoot $n))) { Remove-Item -LiteralPath $velho -Force -ErrorAction SilentlyContinue }
    }
    foreach ($n in @('AVANTIPACK.lnk', 'ABRIR AVANTIPACK.lnk', '.gitignore', '.gitattributes')) {
        $velho = Join-Path $Root $n
        if (Test-Path -LiteralPath $velho) { Remove-Item -LiteralPath $velho -Force -ErrorAction SilentlyContinue }
    }
} catch {}
foreach ($d in @($BackupDir, $DataDir, $LogDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}
$BackupFile = Join-Path $BackupDir 'backup.csv'
$HwFile     = Join-Path $DataDir 'hardware.txt'
$LogFile    = Join-Path $LogDir ('avantipack_' + (Get-Date -Format 'yyyy-MM-dd') + '.log')

$script:CurMod     = $Module
$script:NeedReboot = $false
$script:Applied    = 0

# ---------------------------------------------------------------------
#  Saida / log
# ---------------------------------------------------------------------
function Write-Log([string]$m) {
    try { Add-Content -Path $LogFile -Value ("{0} [{1}] {2}" -f (Get-Date -Format s), $script:CurMod, $m) } catch {}
}
$script:BX = @{ H = [string][char]0x2550; TL = [string][char]0x2554; TR = [string][char]0x2557; BL = [string][char]0x255A; BR = [string][char]0x255D; V = [string][char]0x2551; FULL = [string][char]0x2588; LIGHT = [string][char]0x2591 }
function Write-Title([string]$m) {
    $script:UiUltimoTitulo = $m
    $w = [math]::Max(60, $m.Length + 6)
    $pad = $w - $m.Length - 4
    Write-Host ''
    Write-Host ('  ' + $BX.TL + ($BX.H * ($w - 2)) + $BX.TR) -ForegroundColor DarkCyan
    Write-Host ('  ' + $BX.V + ' ') -ForegroundColor DarkCyan -NoNewline
    Write-Host $m -ForegroundColor White -NoNewline
    Write-Host ((' ' * ($pad + 1)) + $BX.V) -ForegroundColor DarkCyan
    Write-Host ('  ' + $BX.BL + ($BX.H * ($w - 2)) + $BX.BR) -ForegroundColor DarkCyan
    Write-Log "== $m =="
}
# Barra de progresso das etapas: [#####-----] Etapa 3 de 9
function Write-Etapa([int]$n, [int]$total, [string]$nome) {
    $cheio = [math]::Round(20 * $n / $total)
    $barra = ($BX.FULL * $cheio) + ($BX.LIGHT * (20 - $cheio))
    Write-Host ''
    Write-Host ("  ETAPA {0} DE {1}  " -f $n, $total) -ForegroundColor Black -BackgroundColor Cyan -NoNewline
    Write-Host ("  {0}  " -f $barra) -ForegroundColor Cyan -NoNewline
    Write-Host $nome -ForegroundColor White
}
function Write-Caixa([string[]]$linhas, [string]$cor = 'Green') {
    $w = 62
    foreach ($l in $linhas) { if ($l.Length + 4 -gt $w) { $w = $l.Length + 4 } }
    Write-Host ('  ' + $BX.TL + ($BX.H * ($w - 2)) + $BX.TR) -ForegroundColor $cor
    foreach ($l in $linhas) { Write-Host ('  ' + $BX.V + ' ' + $l.PadRight($w - 4) + ' ' + $BX.V) -ForegroundColor $cor }
    Write-Host ('  ' + $BX.BL + ($BX.H * ($w - 2)) + $BX.BR) -ForegroundColor $cor
}
function Write-Info([string]$m) { Write-Host "  [*]  $m" -ForegroundColor Cyan;     Write-Log $m }
function Write-Ok([string]$m)   { Write-Host "  [OK] $m" -ForegroundColor Green;    Write-Log "OK $m" }
$script:Avisos = 0
function Write-Warn([string]$m) { Write-Host "  [!]  $m" -ForegroundColor Yellow;   Write-Log "AVISO $m"; $script:Avisos++ }
function Write-Skip([string]$m) { Write-Host "  [-]  $m" -ForegroundColor DarkGray; Write-Log "PULADO $m" }
function Write-Note([string]$m) { Write-Host "       $m" -ForegroundColor Gray }

# $Auto: resposta usada no modo "Otimizar automaticamente". $null = sempre pergunta.
$script:AutoMode = $false
function Confirm-Step([string]$q, $Auto = $null) {
    if ($script:AutoMode -and $Auto -ne $null) {
        Write-Host ("  [auto] {0} -> {1}" -f $q, $(if ($Auto) { 'Sim' } else { 'Nao' })) -ForegroundColor DarkCyan
        Write-Log "AUTO $q -> $Auto"
        return [bool]$Auto
    }
    return (Select-SimNao $q ($Auto -ne $false))
}

# ---------------------------------------------------------------------
#  Backup / undo
# ---------------------------------------------------------------------
$script:CurItem = ''
$script:BackupCache = New-Object System.Collections.ArrayList
if (Test-Path $BackupFile) {
    $rows = @(Import-Csv -Path $BackupFile)
    $migrar = $rows.Count -gt 0 -and -not ($rows[0].PSObject.Properties.Name -contains 'Item')
    foreach ($r in $rows) {
        if ($migrar) { $r | Add-Member -NotePropertyName Item -NotePropertyValue '' -Force }
        [void]$script:BackupCache.Add($r)
    }
    if ($migrar) { $script:BackupCache | Export-Csv -Path $BackupFile -NoTypeInformation -Encoding UTF8 }
}

function Test-Backed($kind, $path, $name) {
    foreach ($r in $script:BackupCache) {
        if ($r.Kind -eq $kind -and $r.Path -eq $path -and $r.Name -eq $name) { return $true }
    }
    return $false
}

# So grava o valor original UMA vez. Se o modulo rodar 2x, o backup
# continua com o valor de antes do AVANTIPACK.
function Add-Backup($kind, $path, $name, $existed, $valueKind, $value) {
    if (Test-Backed $kind $path $name) { return }
    $o = [pscustomobject]@{
        Date = (Get-Date -Format s); Module = $script:CurMod; Kind = $kind
        Path = [string]$path; Name = [string]$name; Existed = [string]$existed
        ValueKind = [string]$valueKind; Value = [string]$value; Item = [string]$script:CurItem
    }
    [void]$script:BackupCache.Add($o)
    $o | Export-Csv -Path $BackupFile -Append -NoTypeInformation -Encoding UTF8
}

# ---------------------------------------------------------------------
#  Estado: o que cada ajuste DEIXOU no PC (valor alvo). Serve para
#  conferir depois se o ajuste continua aplicado (Windows Update e outros
#  programas as vezes desfazem) e nao refazer o que ja esta certo.
# ---------------------------------------------------------------------
$EstadoFile = Join-Path $DataDir 'estado.csv'
$script:Estado = @{}
$script:JaEstava = 0
if (Test-Path $EstadoFile) { foreach ($r in @(Import-Csv $EstadoFile -ErrorAction SilentlyContinue)) { $script:Estado["$($r.Item)|$($r.Kind)|$($r.Path)|$($r.Name)"] = $r } }
function Add-Estado([string]$Kind, [string]$Path, [string]$Name, [string]$Valor, [string]$Tipo = '') {
    if (-not $script:CurItem) { return }
    $script:Estado["$($script:CurItem)|$Kind|$Path|$Name"] = [pscustomobject]@{ Item = $script:CurItem; Kind = $Kind; Path = $Path; Name = $Name; Valor = $Valor; Tipo = $Tipo; Data = (Get-Date -Format s) }
    $script:EstadoMudou = $true
}
function Save-Estado {
    if (-not $script:EstadoMudou) { return }
    try { @($script:Estado.Values) | Export-Csv -Path $EstadoFile -NoTypeInformation -Encoding UTF8 } catch {}
}
function ConvertTo-ValorTexto($v) {
    if ($v -is [byte[]]) { return 'HEX:' + (($v | ForEach-Object { $_.ToString('X2') }) -join '') }
    if ($v -is [string[]]) { return ($v -join "`n") }
    if ($v -is [int] -or $v -is [long] -or $v -is [uint32]) { return ([long]$v).ToString() }
    return [string]$v
}
function Test-MesmoValor($atual, [string]$alvo, [string]$tipo) {
    if ($null -eq $atual) { return $false }
    $a = ConvertTo-ValorTexto $atual
    if ($tipo -eq 'DWord' -or $tipo -eq 'QWord') {
        $x = 0L; $y = 0L
        if ([long]::TryParse($a, [ref]$x) -and [long]::TryParse($alvo, [ref]$y)) {
            if ($tipo -eq 'DWord') { return ($x -band 0xFFFFFFFFL) -eq ($y -band 0xFFFFFFFFL) }
            return $x -eq $y
        }
    }
    return $a -eq $alvo
}
# Um ajuste do catalogo (B1, C4...) continua aplicado? Confere item por item no PC.
function Test-ItemAplicado([string]$Id) {
    switch ($Id) {
        'S1'  { try { return [bool](@(Get-ComputerRestorePoint -ErrorAction Stop | Where-Object { $_.Description -like 'AVANTIPACK*' -and ([Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime)) -gt (Get-Date).AddHours(-24) }).Count) } catch { return $false } }
        'B12' { return $false }
        'H4'  { return [bool](Get-ScheduledTask -TaskName 'AVANTIPACK Modo Jogo' -ErrorAction SilentlyContinue) }
    }
    $rows = @($script:Estado.Values | Where-Object { $_.Item -eq $Id })
    if ($rows.Count -eq 0) { return $false }
    foreach ($r in $rows) {
        switch ($r.Kind) {
            'REG' {
                $k = Get-Item -LiteralPath $r.Path -ErrorAction SilentlyContinue
                if (-not $k -or -not ($k.GetValueNames() -contains $r.Name)) { return $false }
                if (-not (Test-MesmoValor ($k.GetValue($r.Name, $null, 'DoNotExpandEnvironmentNames')) $r.Valor $r.Tipo)) { return $false }
            }
            'SVC' {
                $s = Get-CimInstance Win32_Service -Filter "Name='$($r.Path)'" -ErrorAction SilentlyContinue
                if ($s -and $s.StartMode -ne $r.Valor) { return $false }
            }
            'TASK' {
                $tk = Get-ScheduledTask -TaskPath $r.Path -TaskName $r.Name -ErrorAction SilentlyContinue
                if ($tk -and [string]$tk.State -ne 'Disabled') { return $false }
            }
            'PLANO' { if ((Get-ActiveScheme) -ne $r.Valor) { return $false } }
            'APPX'  { if (@(Get-AppxPackage -AllUsers -Name $r.Name -ErrorAction SilentlyContinue).Count) { return $false } }
            'NETADV' {
                $pp = Get-NetAdapterAdvancedProperty -Name $r.Path -RegistryKeyword $r.Name -ErrorAction SilentlyContinue
                if ($pp -and ([string]($pp.RegistryValue -join ',')) -ne $r.Valor) { return $false }
            }
        }
    }
    return $true
}

function Set-Reg([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord') {
    try {
        $existed = '0'; $vk = ''; $old = ''
        if (Test-Path -LiteralPath $Path) {
            $key = Get-Item -LiteralPath $Path
            if ($key.GetValueNames() -contains $Name) {
                $existed = '1'
                $vk  = $key.GetValueKind($Name).ToString()
                $raw = $key.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
                if ($raw -is [byte[]]) { $old = 'HEX:' + (($raw | ForEach-Object { $_.ToString('X2') }) -join '') }
                elseif ($raw -is [string[]]) { $old = ($raw -join "`n") }
                else { $old = [string]$raw }
            }
        } else {
            New-Item -Path $Path -Force | Out-Null
        }
        $alvo = ConvertTo-ValorTexto $Value
        Add-Estado 'REG' $Path $Name $alvo $Type
        if ($existed -eq '1' -and (Test-MesmoValor $raw $alvo $Type)) {
            $script:JaEstava++
            Write-Log "JA ESTAVA $Path\$Name = $Value"
            return $true
        }
        Add-Backup 'REG' $Path $Name $existed $vk $old
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        $script:Applied++
        Write-Log "REG $Path\$Name = $Value"
        return $true
    } catch {
        Write-Warn "Falha em $Path\$Name : $($_.Exception.Message)"
        return $false
    }
}

function Set-Svc([string]$Name, [string]$StartType) {
    $svc = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Skip "Servico $Name nao existe neste Windows"; return }
    $modo = switch ($StartType) { 'Automatic' { 'Auto' } default { $StartType } }
    Add-Estado 'SVC' $Name 'StartMode' $modo
    if ($svc.StartMode -eq $modo) { $script:JaEstava++; Write-Log "JA ESTAVA servico $Name = $modo"; return }
    try {
        Add-Backup 'SVC' $Name 'StartMode' '1' '' $svc.StartMode
        if ($StartType -eq 'Disabled') { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue }
        Set-Service -Name $Name -StartupType $StartType -ErrorAction Stop
        $script:Applied++
        Write-Log "SVC $Name -> $StartType"
    } catch { Write-Warn "Nao foi possivel alterar o servico $Name : $($_.Exception.Message)" }
}

function Disable-Task([string]$TaskPath, [string]$TaskName) {
    $t = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $t) { return }
    Add-Estado 'TASK' $TaskPath $TaskName 'Disabled'
    if ([string]$t.State -eq 'Disabled') { $script:JaEstava++; return }
    try {
        Add-Backup 'TASK' $TaskPath $TaskName '1' '' ([string]$t.State)
        Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop | Out-Null
        $script:Applied++
        Write-Log "TASK desativada $TaskPath$TaskName"
    } catch { Write-Warn "Tarefa $TaskName : $($_.Exception.Message)" }
}

function Set-NetAdv([string]$Adapter, [string]$Keyword, [string]$Value) {
    $p = Get-NetAdapterAdvancedProperty -Name $Adapter -RegistryKeyword $Keyword -ErrorAction SilentlyContinue
    if (-not $p) { return $false }
    Add-Estado 'NETADV' $Adapter $Keyword $Value
    if (([string]($p.RegistryValue -join ',')) -eq $Value) { $script:JaEstava++; return $true }
    try {
        Add-Backup 'NETADV' $Adapter $Keyword '1' '' ([string]($p.RegistryValue -join ','))
        Set-NetAdapterAdvancedProperty -Name $Adapter -RegistryKeyword $Keyword -RegistryValue $Value -NoRestart -ErrorAction Stop
        $script:Applied++
        Write-Log "NETADV $Adapter $Keyword = $Value"
        return $true
    } catch { Write-Warn "$Adapter / $Keyword : $($_.Exception.Message)"; return $false }
}

# Comando que desfaz algo que nao e registro (powercfg, bcdedit...)
# Kind CMD = roda no cmd.exe ; Kind PS = roda no PowerShell
function Add-Undo([string]$Id, [string]$Command, [string]$Kind = 'CMD') {
    Add-Backup $Kind $Id '' '1' '' $Command
    Add-Estado 'FEITO' $Id '' ''
}

# ---------------------------------------------------------------------
#  Deteccao de hardware
# ---------------------------------------------------------------------
function Get-Hardware {
    $hw = [ordered]@{}

    # --- CPU
    $cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
    $name = (($cpu.Name -replace '\(R\)|\(TM\)|\(tm\)', '') -replace '\s+', ' ').Trim()
    $hw.CPU         = $name
    $hw.CPU_VENDOR  = if ($cpu.Manufacturer -match 'AMD') { 'AMD' } elseif ($cpu.Manufacturer -match 'Intel') { 'INTEL' } else { 'OUTRO' }
    $hw.CPU_CORES   = $cpu.NumberOfCores
    $hw.CPU_THREADS = $cpu.NumberOfLogicalProcessors
    # Ryzen X3D com 2 CCDs: dependem de core parking + Game Bar + driver de chipset
    $hw.CPU_X3D_DUAL = if ($name -match '7950X3D|7900X3D|9950X3D|9900X3D') { '1' } else { '0' }
    # Intel hibrido (P-cores + E-cores)
    $hw.CPU_HIBRIDO  = if ($name -match 'i[3579]-1[234]\d{3}|Core Ultra') { '1' } else { '0' }
    # Intel 13a/14a geracao (instabilidade corrigida via BIOS/microcode)
    $hw.CPU_RPL      = if ($name -match 'i[579]-1[34]\d{3}') { '1' } else { '0' }

    # --- GPU
    $gpus  = @(Get-CimInstance Win32_VideoController | Where-Object {
                 $_.Name -and $_.Name -notmatch 'Basic Display|Remote|Virtual|Parsec|Mirror|Citrix|DisplayLink|Meta' })
    $names = @($gpus | ForEach-Object { (($_.Name -replace '\(R\)|\(TM\)', '') -replace '\s+', ' ').Trim() })
    $hw.GPU = if ($names.Count -gt 0) { $names -join ' + ' } else { 'Nao detectada' }
    if     ($names -match 'NVIDIA')                          { $gv = 'NVIDIA' }
    elseif (@($names | Where-Object { $_ -match 'Radeon.*RX|Radeon Pro|Radeon VII' -and $_ -notmatch 'Vega \d{1,2}( Graphics|$)' }).Count) { $gv = 'AMD' }
    elseif ($names -match 'Arc.*[AB]\d{3}')                   { $gv = 'INTEL_ARC' }
    elseif ($names -match 'AMD|Radeon')                       { $gv = 'AMD_IGPU' }
    elseif ($names -match 'Intel')                            { $gv = 'INTEL_IGPU' }
    else                                                      { $gv = 'OUTRO' }
    $hw.GPU_VENDOR = $gv
    # 2 placas (integrada + dedicada), tipico de notebook gamer: o Windows pode
    # rodar o jogo na integrada. O item H3 manda cada jogo para a dedicada.
    $rxDed = 'NVIDIA|Radeon.*RX|Radeon Pro|Radeon VII|Arc.*[AB]\d{3}'
    $ded = @($names | Where-Object { $_ -match $rxDed -and $_ -notmatch 'Vega \d{1,2}( Graphics|$)' })
    $int = @($names | Where-Object { ($_ -notmatch $rxDed -or $_ -match 'Vega \d{1,2}( Graphics|$)') -and $_ -match 'Intel|AMD|Radeon' })
    $hw.GPU_HIBRIDA = if ($ded.Count -ge 1 -and $int.Count -ge 1) { '1' } else { '0' }

    # --- Notebook ou desktop (pelo tipo de gabinete informado pela placa)
    $laptopTypes = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)
    $ch = @((Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes)
    $isLaptop = $false
    foreach ($c in $ch) { if ($laptopTypes -contains [int]$c) { $isLaptop = $true } }
    if (-not $isLaptop -and ($ch -contains 1 -or $ch -contains 2 -or $ch.Count -eq 0)) {
        if (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) { $isLaptop = $true }
    }
    $hw.LAPTOP = if ($isLaptop) { '1' } else { '0' }
    $hw.TIPO   = if ($isLaptop) { 'Notebook' } else { 'Desktop' }

    # --- RAM
    $cs = Get-CimInstance Win32_ComputerSystem
    $hw.RAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB)
    $mods = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
    $vel = @($mods | ForEach-Object { [int]$_.ConfiguredClockSpeed } | Where-Object { $_ -gt 0 })
    if ($vel.Count -eq 0) { $vel = @($mods | ForEach-Object { [int]$_.Speed } | Where-Object { $_ -gt 0 }) }
    $hw.RAM_MTS = if ($vel.Count) { ($vel | Measure-Object -Minimum).Minimum } else { 0 }
    $mt = if ($mods.Count) { [int]$mods[0].SMBIOSMemoryType } else { 0 }
    if ($mt -eq 0 -and $mods.Count) { $mt = [int]$mods[0].MemoryType }
    $hw.RAM_TIPO = switch ($mt) { 26 { 'DDR4' } 34 { 'DDR5' } 24 { 'DDR3' } 30 { 'LPDDR4' } 35 { 'LPDDR5' } 29 { 'LPDDR3' } default { 'DDR?' } }
    # sem o tipo informado: deduz pela velocidade
    if ($hw.RAM_TIPO -eq 'DDR?' -and [int]$hw.RAM_MTS -gt 0) { $hw.RAM_TIPO = if ([int]$hw.RAM_MTS -ge 4800) { 'DDR5' } elseif ([int]$hw.RAM_MTS -ge 2133) { 'DDR4' } else { 'DDR3' } }
    $hw.RAM_PENTES = $mods.Count
    # tamanho de cada pente (ex: 4+16) e quantos encaixes a placa tem
    $hw.RAM_LAYOUT = (@($mods | ForEach-Object { [math]::Round($_.Capacity / 1GB) }) -join '+')
    $arr = @(Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue | Where-Object { $_.Use -eq 3 -or -not $_.Use })
    $hw.RAM_SLOTS = [int](($arr | Measure-Object -Property MemoryDevices -Sum).Sum)

    # --- Disco do sistema
    $disk = 'DESCONHECIDO'
    try {
        $dn = (Get-Partition -DriveLetter ($env:SystemDrive.TrimEnd(':')) -ErrorAction Stop).DiskNumber
        $pd = Get-PhysicalDisk | Where-Object { [string]$_.DeviceId -eq [string]$dn } | Select-Object -First 1
        $bt = [string]$pd.BusType; $mt2 = [string]$pd.MediaType
        if     ($bt -eq 'NVMe' -or $bt -eq '17') { $disk = 'NVME' }
        elseif ($mt2 -eq 'SSD' -or $mt2 -eq '4') { $disk = 'SSD' }
        elseif ($mt2 -eq 'HDD' -or $mt2 -eq '3') { $disk = 'HDD' }
        if ($disk -eq 'DESCONHECIDO') {
            $dk = Get-Disk -Number $dn -ErrorAction SilentlyContinue
            $mod = [string]$dk.FriendlyName + ' ' + [string]$dk.Model
            if ([string]$dk.BusType -eq 'NVMe' -or $mod -match 'NVMe') { $disk = 'NVME' }
            elseif ($mod -match 'SSD|Solid') { $disk = 'SSD' }
        }
    } catch {}
    $hw.DISK = $disk

    # --- Windows
    $os = Get-CimInstance Win32_OperatingSystem
    $hw.WIN       = ($os.Caption -replace 'Microsoft ', '').Trim()
    $hw.WIN_BUILD = $os.BuildNumber
    $hw.WIN11     = if ([int]$os.BuildNumber -ge 22000) { '1' } else { '0' }
    return $hw
}

function Save-Hardware($hw) {
    $lines = foreach ($k in $hw.Keys) { "$k=$($hw[$k])" }
    Set-Content -Path $HwFile -Value $lines -Encoding ASCII
}

function Update-StatusFile {
    $n = @($script:BackupCache).Count
    $lines = @()
    if (Test-Path $HwFile) { $lines = @(Get-Content $HwFile | Where-Object { $_ -notmatch '^AJUSTES=' }) }
    $lines = @($lines | Where-Object { $_ -notmatch '^REAPLICAR=' })
    $lines += "AJUSTES=$n"
    try { if (Test-PrecisaReaplicar) { $lines += 'REAPLICAR=1' } } catch {}
    Set-Content -Path $HwFile -Value $lines -Encoding ASCII
}

function Load-HW {
    if (-not (Test-Path $HwFile)) { $h = Get-Hardware; Save-Hardware $h; return $h }
    $h = @{}
    foreach ($l in Get-Content $HwFile) {
        $i = $l.IndexOf('=')
        if ($i -gt 0) { $h[$l.Substring(0, $i)] = $l.Substring($i + 1) }
    }
    return $h
}

function Get-Alerts($hw) {
    $a = @()
    if ($hw.LAPTOP -ne '1') {
        if ($hw.RAM_TIPO -eq 'DDR4' -and [int]$hw.RAM_MTS -gt 0 -and [int]$hw.RAM_MTS -le 2400) {
            $a += "RAM DDR4 rodando a $($hw.RAM_MTS) MT/s: o XMP provavelmente esta DESLIGADO na BIOS. Veja o Guia de BIOS."
        }
        if ($hw.RAM_TIPO -eq 'DDR5' -and [int]$hw.RAM_MTS -gt 0 -and [int]$hw.RAM_MTS -le 4800) {
            $a += "RAM DDR5 rodando a $($hw.RAM_MTS) MT/s: o XMP/EXPO provavelmente esta DESLIGADO na BIOS. Veja o Guia de BIOS."
        }
    }
    # --- dual channel (vale para PC e notebook)
    $integ = ($hw.GPU_VENDOR -like '*IGPU*')
    $extra = if ($integ) { ' Com video integrado isso pesa MUITO: a memoria e a "memoria de video" tambem.' } else { '' }
    $tams = @(([string]$hw.RAM_LAYOUT).Split('+') | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
    if ([int]$hw.RAM_PENTES -eq 1 -and $hw.RAM_TIPO -notlike 'LPDDR*') {
        $livre = if ([int]$hw.RAM_SLOTS -ge 2) { ' Sua placa tem encaixe livre: coloque outro pente IGUAL a este.' } else { '' }
        $a += "So 1 pente de RAM ($($hw.RAM_LAYOUT) GB): roda em SINGLE CHANNEL, com metade da velocidade de memoria.$livre$extra"
    } elseif ($tams.Count -ge 2 -and (@($tams | Select-Object -Unique).Count -gt 1)) {
        $a += "Pentes de RAM de tamanhos diferentes ($($hw.RAM_LAYOUT) GB): so parte da memoria roda em dual channel (modo flex), o resto fica mais lento. O ideal sao 2 pentes iguais.$extra"
    }
    if ([int]$hw.RAM_GB -lt 16) { $a += "Menos de 16 GB de RAM: jogos atuais vao travar por falta de memoria. Upgrade recomendado." }
    if ($hw.DISK -eq 'HDD')     { $a += "Windows instalado em HD mecanico: e a maior causa de travadas. Migrar para SSD/NVMe e prioridade." }
    if ($hw.CPU_RPL -eq '1')    { $a += "Intel 13a/14a geracao: atualize a BIOS (microcode 0x12B ou mais novo) para evitar instabilidade e degradacao." }
    if ($hw.CPU_X3D_DUAL -eq '1') {
        $a += "Ryzen X3D com 2 CCDs: precisa do driver de chipset AMD + Xbox Game Bar + plano Balanceado. O pack respeita isso."
    }
    if ($hw.GPU_VENDOR -eq 'AMD_IGPU' -or $hw.GPU_VENDOR -eq 'INTEL_IGPU') {
        $a += "Apenas video integrado detectado. Se voce TEM placa de video, confira se o monitor esta ligado nela e nao na placa-mae."
    }
    return $a
}

function Show-Hardware($hw) {
    Write-Title 'HARDWARE DETECTADO'
    Write-Host ("  Processador : {0}  ({1} nucleos / {2} threads)" -f $hw.CPU, $hw.CPU_CORES, $hw.CPU_THREADS)
    Write-Host ("  Video       : {0}  [perfil: {1}]" -f $hw.GPU, $hw.GPU_VENDOR)
    Write-Host ("  Memoria     : {0} GB {1} @ {2} MT/s  ({3} pente(s): {4} GB)" -f $hw.RAM_GB, $hw.RAM_TIPO, $hw.RAM_MTS, $hw.RAM_PENTES, $hw.RAM_LAYOUT)
    Write-Host ("  Disco (C:)  : {0}" -f $hw.DISK)
    Write-Host ("  Sistema     : {0}  build {1}  -  {2}" -f $hw.WIN, $hw.WIN_BUILD, $hw.TIPO)
    $al = Get-Alerts $hw
    Write-Host ''
    if ($al.Count -eq 0) { Write-Ok 'Nenhum alerta de hardware.' }
    else { foreach ($x in $al) { Write-Warn $x } }
}

# ---------------------------------------------------------------------
#  MODULO: ponto de restauracao
# ---------------------------------------------------------------------
function Mod-Restore {
    $script:CurMod = 'restore'
    Write-Title 'PONTO DE RESTAURACAO'
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # Permite criar mais de 1 ponto a cada 24h (limite padrao do Windows)
        $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        New-ItemProperty -Path $k -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force | Out-Null
        Write-Info 'Criando ponto de restauracao (pode levar 1 minuto)...'
        Checkpoint-Computer -Description ("AVANTIPACK " + (Get-Date -Format 'dd-MM-yyyy HH:mm')) -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Ok 'Ponto de restauracao criado.'
    } catch {
        Write-Warn "Nao foi possivel criar o ponto: $($_.Exception.Message)"
        Write-Note 'O backup interno do AVANTIPACK (opcao Desfazer) continua funcionando.'
    }
    # Copia extra das chaves mais mexidas (seguranca adicional)
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $regDir = Join-Path $BackupDir "reg_$stamp"
    New-Item -ItemType Directory -Path $regDir -Force | Out-Null
    $keys = @{
        'mmcss.reg'   = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        'priority.reg'= 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl'
        'graphics.reg'= 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
        'mouse.reg'   = 'HKCU\Control Panel\Mouse'
        'tcpip.reg'   = 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    }
    foreach ($f in $keys.Keys) { & reg.exe export $keys[$f] (Join-Path $regDir $f) /y 2>&1 | Out-Null }
    Write-Ok "Copia do registro salva em core\dados\backup\reg_$stamp"
}

# ---------------------------------------------------------------------
#  MODULO: desfazer
# ---------------------------------------------------------------------
function Restore-Row($r) {
    switch ($r.Kind) {
        'REG' {
            if ($r.Existed -eq '1') {
                $val = $r.Value
                switch ($r.ValueKind) {
                    'DWord'       { $val = [int]$r.Value }
                    'QWord'       { $val = [long]$r.Value }
                    'Binary'      { $h = ($r.Value -replace '^HEX:', ''); $val = [byte[]]@(for ($i = 0; $i -lt $h.Length; $i += 2) { [Convert]::ToByte($h.Substring($i, 2), 16) }) }
                    'MultiString' { $val = [string[]]($r.Value -split "`n") }
                }
                $t = if ($r.ValueKind) { $r.ValueKind } else { 'String' }
                New-ItemProperty -LiteralPath $r.Path -Name $r.Name -Value $val -PropertyType $t -Force | Out-Null
            } else {
                Remove-ItemProperty -LiteralPath $r.Path -Name $r.Name -ErrorAction SilentlyContinue
            }
        }
        'SVC' {
            $map = @{ 'Auto' = 'Automatic'; 'Manual' = 'Manual'; 'Disabled' = 'Disabled' }
            $st = $map[$r.Value]; if (-not $st) { $st = 'Manual' }
            Set-Service -Name $r.Path -StartupType $st -ErrorAction SilentlyContinue
            if ($st -eq 'Automatic') { Start-Service -Name $r.Path -ErrorAction SilentlyContinue }
        }
        'TASK' {
            if ($r.Value -ne 'Disabled') { Enable-ScheduledTask -TaskPath $r.Path -TaskName $r.Name -ErrorAction SilentlyContinue | Out-Null }
        }
        'NETADV' {
            Set-NetAdapterAdvancedProperty -Name $r.Path -RegistryKeyword $r.Name -RegistryValue $r.Value -NoRestart -ErrorAction SilentlyContinue
        }
        'CMD' { & cmd.exe /c $r.Value | Out-Null }
        'PS'  { Invoke-Expression $r.Value | Out-Null }
        'NVIDIA' { Invoke-Expression $r.Value | Out-Null }          # reimporta o perfil global salvo
        'APPX'   { [void](Install-AppxDeVolta $r.Value) }           # reinstala app removido
        'FILE'   { if (Test-Path -LiteralPath $r.Value) { Copy-Item -LiteralPath $r.Value -Destination $r.Path -Force } }   # devolve o arquivo de config original
        'DISPLAY' { [void](Set-MonitorHz $r.Path ([int]$r.Value)) }  # volta a taxa de atualizacao
    }
}

function Mod-Undo {
    $script:CurMod = 'undo'
    Write-Title 'DESFAZER OTIMIZACOES'
    if ($script:BackupCache.Count -eq 0) { Write-Skip 'Nada para desfazer: nenhum ajuste foi aplicado ainda.'; return }

    $mods = @($script:BackupCache | Group-Object Module | Sort-Object Name)
    $itens = @(for ($i = 0; $i -lt $mods.Count; $i++) { @{ K = $mods[$i].Name; T = ("{0,-16} {1} alteracao(oes)" -f $mods[$i].Name, $mods[$i].Count) } })
    Write-Note 'Marque as partes que voce quer desfazer:'
    Write-Host ''
    $alvo = Select-Varios $itens -Concluir 'DESFAZER o que esta marcado'
    if ($null -eq $alvo -or @($alvo).Count -eq 0) { return }
    $alvo = @($alvo)

    $rows = @($script:BackupCache)
    $ok = 0
    for ($i = $rows.Count - 1; $i -ge 0; $i--) {      # ordem inversa
        $r = $rows[$i]
        if ($alvo -contains $r.Module) {
            try { Restore-Row $r; $ok++ } catch { Write-Warn "Falha ao restaurar $($r.Path)\$($r.Name)" }
        }
    }
    $rest = @($rows | Where-Object { $alvo -notcontains $_.Module })
    if ($rest.Count -gt 0) { $rest | Export-Csv -Path $BackupFile -NoTypeInformation -Encoding UTF8 }
    else { Remove-Item $BackupFile -Force -ErrorAction SilentlyContinue }
    Write-Ok "$ok alteracao(oes) restaurada(s) para o valor original: $($alvo -join ', ')"
    Write-Note 'Apps removidos no Debloat: use Desfazer > Reinstalar apps (pela Microsoft Store).'
    $script:NeedReboot = $true
}

# Manual ilustrado (guias\MANUAL.html). Abre uma copia com as pecas deste PC marcadas.
function Open-Manual([string]$Cap = '') {
    $src = Join-Path $Root 'guias\MANUAL.html'
    if (-not (Test-Path $src)) { Write-Warn 'Manual nao encontrado em guias\MANUAL.html. Baixe o pack de novo.'; return }
    $pc = ''
    try {
        $hw = Load-HW
        $ram = ("{0} GB {1} {2}" -f $hw.RAM_GB, $hw.RAM_TIPO, $(if ([int]("0" + $hw.RAM_MTS) -gt 0) { $hw.RAM_MTS } else { '' })).Trim()
        $o = [ordered]@{ cpu = [string]$hw.CPU_VENDOR; cpuNome = [string]$hw.CPU; gpu = [string]$hw.GPU_VENDOR; gpuNome = [string]$hw.GPU; ram = $ram; win = [string]$hw.WIN }
        $pc = 'window.PC=' + (($o | ConvertTo-Json -Compress) -replace '<', '\u003c') + ';'
    } catch {}
    $Cap = $Cap -replace '[^a-z0-9/\-]', ''
    $html = [IO.File]::ReadAllText($src)
    $html = $html.Replace('/*AVANTI_PC*/', ($pc + "window.INICIO='$Cap';"))
    $dst = $src
    try {
        $dir = Join-Path $env:LOCALAPPDATA 'AVANTIPACK'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $dst = Join-Path $dir 'Manual AVANTIPACK.html'
        [IO.File]::WriteAllText($dst, $html, (New-Object Text.UTF8Encoding($true)))
    } catch { $dst = $src }
    # pelo Explorer o navegador abre como usuario normal (nao como administrador)
    Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList ('"' + $dst + '"')
    Write-Ok 'Manual aberto no navegador.'
    Write-Note ('Tambem fica em: ' + $src)
}
function Get-CapGpu {
    $v = [string](Load-HW).GPU_VENDOR
    if ($v -like 'AMD*') { return 'amd' } elseif ($v -like 'INTEL*') { return 'intel' } else { return 'nvidia' }
}

function Mod-Guias { Open-Manual }

# ---------------------------------------------------------------------
#  Modulos em arquivos separados
# ---------------------------------------------------------------------
. (Join-Path $PSScriptRoot 'ui.ps1')
. (Join-Path $PSScriptRoot 'modulos.ps1')
. (Join-Path $PSScriptRoot 'gpu.ps1')
. (Join-Path $PSScriptRoot 'catalogo.ps1')
. (Join-Path $PSScriptRoot 'apps.ps1')
. (Join-Path $PSScriptRoot 'fix.ps1')
. (Join-Path $PSScriptRoot 'restauracao.ps1')
. (Join-Path $PSScriptRoot 'manutencao.ps1')
. (Join-Path $PSScriptRoot 'pro.ps1')
. (Join-Path $PSScriptRoot 'extras.ps1')
. (Join-Path $PSScriptRoot 'app.ps1')          # por ultimo: dentro do app AVANTIPACK, troca o console pelas telas do app

# ---------------------------------------------------------------------
#  Execucao
# ---------------------------------------------------------------------
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warn 'Abra o AVANTIPACK pelo AVANTIPACK.exe (ele pede permissao de administrador).'
    exit 1
}

if (Test-SoPro $Module) { Show-SoPro; $Module = '__pro' }
switch ($Module) {
    '__pro'         { }
    'novidades-auto' { Mod-Novidades -Auto }
    'novidades'     { Mod-Novidades }
    'detect'        { $h = Get-Hardware; try { Get-StatusExtra $h } catch {}; Save-Hardware $h; Show-Hardware $h }
    'detect-silent' { $h = Get-Hardware; try { Get-StatusExtra $h } catch {}; Save-Hardware $h }
    'checkup'       {
        $h = Get-Hardware; Save-Hardware $h; Show-Hardware $h; [void](Test-GPU $h)
        Write-Host ''
        Mod-Nota -SemTitulo
    }
    'auto'          { Mod-Otimizar }
    'reaplicar'     { Mod-Reaplicar }
    'atualizar'     { Mod-Atualizar }
    'configjogos'   { Open-Manual 'jogos' }
    'bios'          { Open-Manual 'bios' }
    'restore'       { Mod-Restore }
    'undo'          { Mod-Restaurar }
    'undoparte'     { Mod-Undo }
    'apps'          { Mod-Apps }
    'guias'         { Mod-Guias }
    'verificar'     { [void](Test-GPU (Load-HW)) }
    'fix'           { Mod-Fix }
    'visual'        { Open-Manual (Get-CapGpu) }
    'nota'          { Mod-Nota }
    'limpeza'       { Mod-Limpeza }
    'shaders'       { Mod-Shaders }
    'prejogo'       { Mod-PreJogo }
    'manutencao'    { }
    default { Write-Warn "Modulo desconhecido: $Module" }
}

try { Update-StatusFile } catch {}
try { Save-Estado } catch {}
if ($Module -notin @('__pro', 'novidades-auto', 'novidades', 'detect-silent', 'detect', 'apps', 'guias', 'bios', 'visual', 'fix', 'manutencao', 'atualizar', 'configjogos', 'nota', 'prejogo', 'shaders')) {
    Write-Host ''
    if ($script:Applied -gt 0) { Write-Ok "$($script:Applied) ajuste(s) aplicado(s). Backup salvo em core\dados\backup" }
    if ($script:NeedReboot)    { Write-Warn 'Reinicie o PC para tudo entrar em vigor (opcao 8 do menu).' }
}
