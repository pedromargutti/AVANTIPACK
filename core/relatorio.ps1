# =====================================================================
#  AVANTIPACK - relatorio para ajuda
#  Junta num arquivo so: pecas, alertas, ajustes ativos, testes de FPS e
#  os registros (logs). A pessoa manda o ZIP e quem ajuda ve tudo.
#  NAO inclui: nome de usuario, nome do PC, IP, MAC, numeros de serie.
# =====================================================================

function Hide-Pessoal([string]$t) {
    if (-not $t) { return $t }
    foreach ($x in @($env:USERNAME, $env:COMPUTERNAME, $env:USERDOMAIN) | Where-Object { $_ -and $_.Length -ge 3 }) {
        $t = $t -replace [regex]::Escape($x), '<oculto>'
    }
    $t = $t -replace '\b\d{1,3}(\.\d{1,3}){3}\b', '<ip>'
    $t = $t -replace '\b([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b', '<mac>'
    return $t
}

function Mod-Relatorio {
    $script:CurMod = 'relatorio'
    Write-Title 'RELATORIO PARA AJUDA'
    Write-Note 'Cria um arquivo com as informacoes do PC para voce mandar a quem esta te ajudando.'
    Write-Note 'Nao vai nome de usuario, nome do PC, IP, MAC nem numeros de serie.'
    Write-Host ''
    Write-Info 'Coletando informacoes (leva uns segundos)...'
    $hw = Get-Hardware
    $L = New-Object System.Collections.Generic.List[string]
    function Add([string]$s = '') { $L.Add($s) }
    function Sec([string]$s) { Add ''; Add ('=' * 70); Add "  $s"; Add ('=' * 70) }

    Add "AVANTIPACK v$(Get-PackVersion) - relatorio de $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
    Sec 'PECAS'
    Add "Processador : $($hw.CPU) ($($hw.CPU_CORES) nucleos / $($hw.CPU_THREADS) threads)"
    Add "Video       : $($hw.GPU)  [perfil $($hw.GPU_VENDOR)$(if ($hw.GPU_HIBRIDA -eq '1') { ', 2 placas' })]"
    Add "Memoria     : $($hw.RAM_GB) GB $($hw.RAM_TIPO) @ $($hw.RAM_MTS) MT/s - pentes: $($hw.RAM_LAYOUT) GB ($($hw.RAM_SLOTS) encaixes)"
    Add "Disco (C:)  : $($hw.DISK)"
    Add "Sistema     : $($hw.WIN) build $($hw.WIN_BUILD) - $($hw.TIPO)"
    try {
        $bb = Get-CimInstance Win32_BaseBoard -ErrorAction Stop; $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
        Add "Placa-mae   : $($bb.Manufacturer) $($bb.Product) - BIOS $($bios.SMBIOSBIOSVersion) ($(([datetime]$bios.ReleaseDate).ToString('dd/MM/yyyy')))"
    } catch {}
    foreach ($v in @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)) {
        $dd = if ($v.DriverDate) { ([datetime]$v.DriverDate).ToString('dd/MM/yyyy') } else { '?' }
        Add "Driver      : $($v.Name) - versao $($v.DriverVersion) de $dd - $($v.CurrentHorizontalResolution)x$($v.CurrentVerticalResolution) @ $($v.CurrentRefreshRate) Hz"
    }
    foreach ($d in @(Get-PhysicalDisk -ErrorAction SilentlyContinue)) {
        Add ("Disco       : {0} - {1} - {2:N0} GB - saude: {3}" -f $d.FriendlyName, $d.MediaType, ($d.Size / 1GB), $d.HealthStatus)
    }
    foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and $_.Size -gt 0 })) {
        Add ("Unidade {0}: : {1:N0} GB livres de {2:N0} GB" -f $v.DriveLetter, ($v.SizeRemaining / 1GB), ($v.Size / 1GB))
    }
    try { Add ("Energia     : " + (Hide-Pessoal ((& powercfg.exe /getactivescheme) -join ' '))) } catch {}
    foreach ($n in @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up')) {
        Add "Rede        : $($n.InterfaceDescription) - $($n.LinkSpeed)"
    }

    Sec 'ALERTAS'
    $al = @(Get-Alerts $hw)
    if ($al.Count) { foreach ($x in $al) { Add "[!] $x" } } else { Add 'Nenhum alerta.' }

    Sec 'AJUSTES DO AVANTIPACK ATIVOS'
    $bk = @($script:BackupCache)
    Add "$($bk.Count) valor(es) com backup."
    foreach ($g in ($bk | Where-Object { $_.Item } | Group-Object Item | Sort-Object Name)) { Add ("  {0,-4} {1}  ({2} valores)" -f $g.Name, (Get-ItemNome $g.Name), $g.Count) }

    Sec 'TESTES DE FPS'
    if (Test-Path $FpsHist) { foreach ($x in Import-Csv $FpsHist) { Add ("{0}  {1,-20} {2,-22} medio {3,4}  1% low {4,4}  travadas {5}" -f $x.Data, $x.Jogo, $x.Situacao, $x.Media, $x.Low1, $x.Travadas) } }
    else { Add 'Nenhum teste de FPS feito ainda (menu: Teste de FPS).' }

    Sec 'PROGRAMAS QUE ABREM COM O WINDOWS'
    try { foreach ($s in @(Get-CimInstance Win32_StartupCommand -ErrorAction Stop)) { Add ("  {0}" -f $s.Name) } } catch {}

    Sec 'ERROS RECENTES DO SISTEMA (7 dias, criticos)'
    try {
        $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 15 -ErrorAction Stop)
        foreach ($e in $ev) { Add (Hide-Pessoal ("{0}  {1}: {2}" -f $e.TimeCreated.ToString('dd/MM HH:mm'), $e.ProviderName, (($e.Message -split "`n")[0]).Trim())) }
    } catch { Add 'Nenhum (ou sem acesso).' }

    # monta: TXT + logs no ZIP, na Area de Trabalho
    $stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
    $tmp = Join-Path $env:TEMP ("AVANTIPACK_relatorio_$stamp")
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $txt = Join-Path $tmp 'RELATORIO.txt'
    [IO.File]::WriteAllLines($txt, [string[]]$L, (New-Object Text.UTF8Encoding($true)))
    $logs = @(Get-ChildItem $LogDir -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
    foreach ($lg in $logs) {
        $c = Get-Content $lg.FullName -Raw -ErrorAction SilentlyContinue
        Set-Content -Path (Join-Path $tmp $lg.Name) -Value (Hide-Pessoal $c) -Encoding UTF8
    }
    $desk = [Environment]::GetFolderPath('Desktop')
    $zip = Join-Path $desk "AVANTIPACK_relatorio_$stamp.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $zip
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ''
    Write-Caixa @('Relatorio pronto na sua Area de Trabalho:', '', ([IO.Path]::GetFileName($zip)), '', 'Mande esse arquivo para quem esta te ajudando (WhatsApp, Discord...).') 'Green'
    Start-Process explorer.exe "/select,`"$zip`""
}
