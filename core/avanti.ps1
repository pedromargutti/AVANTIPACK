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
$BackupDir  = Join-Path $Root 'backup'
$DataDir    = Join-Path $Root 'data'
$LogDir     = Join-Path $Root 'logs'
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
    $r = Read-Host "  $q (S/N)"
    return ($r -match '^[sSyY]')
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
    elseif ($names -match 'Radeon.*RX|Radeon Pro|Radeon VII') { $gv = 'AMD' }
    elseif ($names -match 'Arc.*[AB]\d{3}')                   { $gv = 'INTEL_ARC' }
    elseif ($names -match 'AMD|Radeon')                       { $gv = 'AMD_IGPU' }
    elseif ($names -match 'Intel')                            { $gv = 'INTEL_IGPU' }
    else                                                      { $gv = 'OUTRO' }
    $hw.GPU_VENDOR = $gv

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
    $hw.RAM_MTS = if ($mods.Count) { ($mods | Measure-Object -Property ConfiguredClockSpeed -Minimum).Minimum } else { 0 }
    $mt = if ($mods.Count) { [int]$mods[0].SMBIOSMemoryType } else { 0 }
    $hw.RAM_TIPO = switch ($mt) { 26 { 'DDR4' } 34 { 'DDR5' } 24 { 'DDR3' } default { 'DDR?' } }
    $hw.RAM_PENTES = $mods.Count

    # --- Disco do sistema
    $disk = 'DESCONHECIDO'
    try {
        $dn = (Get-Partition -DriveLetter ($env:SystemDrive.TrimEnd(':')) -ErrorAction Stop).DiskNumber
        $pd = Get-PhysicalDisk | Where-Object { [string]$_.DeviceId -eq [string]$dn } | Select-Object -First 1
        $bt = [string]$pd.BusType; $mt2 = [string]$pd.MediaType
        if     ($bt -eq 'NVMe' -or $bt -eq '17') { $disk = 'NVME' }
        elseif ($mt2 -eq 'SSD' -or $mt2 -eq '4') { $disk = 'SSD' }
        elseif ($mt2 -eq 'HDD' -or $mt2 -eq '3') { $disk = 'HDD' }
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
        if ($hw.RAM_TIPO -eq 'DDR4' -and [int]$hw.RAM_MTS -le 2400) {
            $a += "RAM DDR4 rodando a $($hw.RAM_MTS) MT/s: o XMP provavelmente esta DESLIGADO na BIOS. Veja o Guia de BIOS."
        }
        if ($hw.RAM_TIPO -eq 'DDR5' -and [int]$hw.RAM_MTS -le 4800) {
            $a += "RAM DDR5 rodando a $($hw.RAM_MTS) MT/s: o XMP/EXPO provavelmente esta DESLIGADO na BIOS. Veja o Guia de BIOS."
        }
        if ([int]$hw.RAM_PENTES -eq 1) {
            $a += "So 1 pente de RAM: roda em single channel. Dois pentes iguais (dual channel) dao bem mais FPS e menos travadas."
        }
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
    Write-Host ("  Memoria     : {0} GB {1} @ {2} MT/s  ({3} pente(s))" -f $hw.RAM_GB, $hw.RAM_TIPO, $hw.RAM_MTS, $hw.RAM_PENTES)
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
    Write-Ok "Copia do registro salva em backup\reg_$stamp"
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
        'DISPLAY' { [void](Set-MonitorHz $r.Path ([int]$r.Value)) }  # volta a taxa de atualizacao
    }
}

function Mod-Undo {
    $script:CurMod = 'undo'
    Write-Title 'DESFAZER OTIMIZACOES'
    if ($script:BackupCache.Count -eq 0) { Write-Skip 'Nada para desfazer: nenhum ajuste foi aplicado ainda.'; return }

    $mods = @($script:BackupCache | Group-Object Module | Sort-Object Name)
    for ($i = 0; $i -lt $mods.Count; $i++) {
        Write-Host ("  [{0}] {1,-16} {2} alteracao(oes)" -f ($i + 1), $mods[$i].Name, $mods[$i].Count)
    }
    Write-Host '  [T] Desfazer TUDO'
    Write-Host ''
    $op = Read-Host '  Escolha (ENTER cancela)'
    if (-not $op) { return }
    if ($op -match '^[tT]$') { $alvo = @($mods | ForEach-Object { $_.Name }) }
    elseif ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $mods.Count) { $alvo = @($mods[[int]$op - 1].Name) }
    else { Write-Warn 'Opcao invalida.'; return }

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
    Write-Note 'Apps removidos no Debloat devem ser reinstalados pela Microsoft Store.'
    $script:NeedReboot = $true
}

function Mod-Guias {
    $hw = Load-HW
    $g = @(
        @('PAINEIS_VISUAL.html',    'GUIA COM IMAGENS: painel NVIDIA / AMD / Intel / Windows'),
        @('CONFIG_DOS_JOGOS.txt',   'Configuracoes recomendadas DENTRO dos jogos (CS2, Valorant, Fortnite...)'),
        @('LISTA_DE_AJUSTES.txt',   'Lista de TODOS os ajustes do pack, por categoria'),
        @('GUIA_BIOS.txt',          'Guia de BIOS (todas as placas)'),
        @('CPU_AMD.txt',            'Processador AMD Ryzen'),
        @('CPU_INTEL.txt',          'Processador Intel'),
        @('GPU_NVIDIA.txt',         'Placa de video NVIDIA'),
        @('GPU_AMD.txt',            'Placa de video AMD Radeon'),
        @('GPU_INTEL.txt',          'Video Intel (Arc e integrado)'),
        @('LIMITE_DE_FPS.txt',      'Limite de FPS, V-Sync, G-Sync/FreeSync'),
        @('O_QUE_NAO_FAZEMOS.txt',  'Mitos e tweaks perigosos que evitamos'),
        @('COMO_EDITAR_O_PACK.txt', 'Para quem mexe no codigo: tirar/colocar ajustes'),
        @('GITHUB_PASSO_A_PASSO.txt', 'Para quem distribui: GitHub e atualizacao automatica')
    )
    Write-Title 'GUIAS'
    for ($i = 0; $i -lt $g.Count; $i++) {
        $rec = ''
        if ($g[$i][0] -eq 'CPU_AMD.txt'    -and $hw.CPU_VENDOR -eq 'AMD')    { $rec = '  <- seu processador' }
        if ($g[$i][0] -eq 'CPU_INTEL.txt'  -and $hw.CPU_VENDOR -eq 'INTEL')  { $rec = '  <- seu processador' }
        if ($g[$i][0] -eq 'GPU_NVIDIA.txt' -and $hw.GPU_VENDOR -eq 'NVIDIA') { $rec = '  <- sua placa de video' }
        if ($g[$i][0] -eq 'GPU_AMD.txt'    -and $hw.GPU_VENDOR -like 'AMD*') { $rec = '  <- sua placa de video' }
        if ($g[$i][0] -eq 'GPU_INTEL.txt'  -and $hw.GPU_VENDOR -like 'INTEL*'){ $rec = '  <- sua placa de video' }
        Write-Host ("  [{0}] {1}{2}" -f ($i + 1), $g[$i][1], $rec)
    }
    Write-Host ''
    $op = Read-Host '  Numero do guia (ENTER volta)'
    if ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $g.Count) {
        $arq = Join-Path $Root ('guias\' + $g[[int]$op - 1][0])
        if ($arq -like '*.html') { Start-Process $arq } else { Start-Process notepad.exe $arq }
    }
}

# ---------------------------------------------------------------------
#  Modulos em arquivos separados
# ---------------------------------------------------------------------
. (Join-Path $PSScriptRoot 'modulos.ps1')
. (Join-Path $PSScriptRoot 'gpu.ps1')
. (Join-Path $PSScriptRoot 'catalogo.ps1')
. (Join-Path $PSScriptRoot 'apps.ps1')
. (Join-Path $PSScriptRoot 'fix.ps1')
. (Join-Path $PSScriptRoot 'games.ps1')
. (Join-Path $PSScriptRoot 'dns.ps1')
. (Join-Path $PSScriptRoot 'restauracao.ps1')
. (Join-Path $PSScriptRoot 'manutencao.ps1')

# ---------------------------------------------------------------------
#  Execucao
# ---------------------------------------------------------------------
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warn 'Execute o AVANTIPACK.bat como administrador.'
    exit 1
}

switch ($Module) {
    'detect-silent' { $h = Get-Hardware; try { Get-StatusExtra $h } catch {}; Save-Hardware $h }
    'checkup'       {
        $h = Get-Hardware; Save-Hardware $h; Show-Hardware $h; [void](Test-GPU $h)
        Test-InputLag
        Write-Host ''
        if (Confirm-Step 'Testar a internet tambem (ping, variacao e perda, ~10 s)?') { Test-Rede }
    }
    'auto'          { Mod-Otimizar }
    'inputlag'      { Test-InputLag }
    'internet'      { Test-Rede }
    'inicializacao' { Mod-Inicializacao }
    'reaplicar'     { Mod-Reaplicar }
    'manutencao'    { Mod-Manutencao }
    'agendar'       { Mod-Agendar }
    'atualizar'     { Mod-Atualizar }
    'perfisjogos'   { Optimize-NvidiaGameProfiles (Load-HW) }
    'configjogos'   { Start-Process notepad.exe (Join-Path $Root 'guias\CONFIG_DOS_JOGOS.txt') }
    'restore'       { Mod-Restore }
    'debloat'       { Mod-Debloat }
    'sistema'       { Mod-Sistema }
    'energia'       { Mod-Energia }
    'gpu'           { Mod-GPU }
    'rede'          { Mod-Rede }
    'armazenamento' { Mod-Armazenamento }
    'avancado'      { Mod-Avancado }
    'undo'          { Mod-Restaurar }
    'undoparte'     { Mod-Undo }
    'apps'          { Mod-Apps }
    'guias'         { Mod-Guias }
    'verificar'     { [void](Test-GPU (Load-HW)) }
    'fix'           { Mod-Fix }
    'jogos'         { Mod-Jogos }
    'dns'           { Mod-DNS }
    'visual'        { Start-Process (Join-Path $Root 'guias\PAINEIS_VISUAL.html') }
    'recomendado'   {
        Write-Title 'PACOTE RECOMENDADO'
        Write-Note 'Vai rodar em ordem: ponto de restauracao, debloat, sistema, energia, video, rede, armazenamento.'
        Write-Note 'Algumas etapas fazem perguntas. O modulo Avancado NAO esta incluido.'
        if (Confirm-Step 'Comecar?') {
            Mod-Restore; Mod-Debloat; Mod-Sistema; Mod-Energia; Mod-GPU; Mod-Rede; Mod-Armazenamento
            Write-Title 'CONCLUIDO'
            Show-Hardware (Load-HW)
        }
    }
    default { Write-Warn "Modulo desconhecido: $Module" }
}

try { Update-StatusFile } catch {}
if ($Module -notin @('detect-silent', 'detect', 'apps', 'guias', 'visual', 'fix', 'internet', 'manutencao', 'atualizar', 'configjogos')) {
    Write-Host ''
    if ($script:Applied -gt 0) { Write-Ok "$($script:Applied) ajuste(s) aplicado(s). Backup salvo em backup\backup.csv" }
    if ($script:NeedReboot)    { Write-Warn 'Reinicie o PC para tudo entrar em vigor (opcao 8 do menu).' }
}
