# =====================================================================
#  AVANTIPACK - Fix de erros do Windows
#  Ideia inspirada no menu "Fix" de outros packs, reescrita sem os bugs
#  deles: tudo mostra o resultado NA TELA, nada desliga/reinicia o PC
#  sem perguntar e tudo vai para o log em logs\.
#  Carregado por avanti.ps1 (dot-source). Sem acentos de proposito.
# =====================================================================

function Restart-Svcs([string[]]$Names, [string]$StartType = '') {
    foreach ($n in $Names) {
        $s = Get-Service -Name $n -ErrorAction SilentlyContinue
        if (-not $s) { continue }
        try {
            if ($StartType) { Set-Service -Name $n -StartupType $StartType -ErrorAction SilentlyContinue }
            Restart-Service -Name $n -Force -ErrorAction Stop
            Write-Ok "Servico $($s.DisplayName) reiniciado."
        } catch {
            try { Start-Service -Name $n -ErrorAction Stop; Write-Ok "Servico $($s.DisplayName) iniciado." }
            catch { Write-Warn "Servico $($s.DisplayName): $($_.Exception.Message)" }
        }
    }
}

function Invoke-Logged([string]$Desc, [scriptblock]$Cmd) {
    Write-Info $Desc
    try { $out = & $Cmd 2>&1 | Out-String; Write-Log $out; return $out } catch { Write-Warn $_.Exception.Message; return '' }
}

function Set-PrivacyAllow([string]$Cap) {
    foreach ($root in 'HKLM:', 'HKCU:') {
        $k = "$root\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$Cap"
        if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
        Set-ItemProperty -Path $k -Name 'Value' -Value 'Allow' -ErrorAction SilentlyContinue
        if (Test-Path "$k\NonPackaged") { Set-ItemProperty -Path "$k\NonPackaged" -Name 'Value' -Value 'Allow' -ErrorAction SilentlyContinue }
    }
}

function Reset-PnpClass([string[]]$Classes, [string]$NameRegex) {
    $devs = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
        ($Classes -contains $_.Class) -or ($NameRegex -and $_.FriendlyName -match $NameRegex) })
    foreach ($d in $devs) {
        try {
            if ($d.Status -ne 'OK') { Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop }
            else {
                Disable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop
                Start-Sleep -Milliseconds 600
                Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop
            }
            Write-Ok "Dispositivo reiniciado: $($d.FriendlyName)"
        } catch { Write-Skip "Nao foi possivel reiniciar: $($d.FriendlyName)" }
    }
    if ($devs.Count -eq 0) { Write-Warn 'Nenhum dispositivo encontrado. Confira o cabo/USB ou o driver no site do fabricante.' }
    return $devs
}

# ---------------------------------------------------------------------
#  Cada reparo
# ---------------------------------------------------------------------
function Fix-Internet {
    Write-Title 'FIX: INTERNET / WI-FI'
    Restart-Svcs @('Dhcp', 'Dnscache', 'NlaSvc', 'netprofm', 'WlanSvc') 'Automatic'
    Clear-DnsClientCache -ErrorAction SilentlyContinue; Write-Ok 'Cache de DNS limpo.'
    $out = Invoke-Logged 'Resetando Winsock...' { netsh winsock reset }
    Write-Note 'Atencao: se voce usa IP FIXO (configurado na mao), anote antes: o reset volta para automatico.'
    $out = Invoke-Logged 'Resetando a pilha TCP/IP...' { netsh int ip reset }
    Write-Ok 'Winsock e TCP/IP resetados.'
    if (Confirm-Step 'Renovar o IP agora? (a internet cai por alguns segundos)') {
        Invoke-Logged 'Renovando IP...' { ipconfig /release; ipconfig /renew } | Out-Null
        Write-Ok 'IP renovado.'
    }
    Write-Warn 'Reinicie o PC para completar o reset de rede.'
    $script:NeedReboot = $true
}

function Fix-Audio {
    Write-Title 'FIX: AUDIO'
    Restart-Svcs @('AudioEndpointBuilder', 'Audiosrv') 'Automatic'
    [void](Reset-PnpClass @('AudioEndpoint', 'MEDIA') '')
    Write-Note 'Abrindo Configuracoes > Som: confira se a SAIDA certa esta selecionada e o volume.'
    Start-Process 'ms-settings:sound'
}

function Fix-Microfone {
    Write-Title 'FIX: MICROFONE'
    Set-PrivacyAllow 'microphone'
    foreach ($r in 'HKLM:', 'HKCU:') { Remove-ItemProperty -Path "$r\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name 'LetAppsAccessMicrophone' -ErrorAction SilentlyContinue }
    Write-Ok 'Permissao de microfone liberada para apps e programas.'
    Write-Note 'Feche Discord/OBS/Teams antes, eles podem "prender" o microfone.'
    Restart-Svcs @('AudioEndpointBuilder', 'Audiosrv') 'Automatic'
    [void](Reset-PnpClass @('AudioEndpoint') 'microphone|microfone|headset')
    Write-Note 'Abrindo Configuracoes > Som: em ENTRADA, escolha o microfone certo e veja se o volume nao esta em 0.'
    Start-Process 'ms-settings:sound'
}

function Fix-Camera {
    Write-Title 'FIX: CAMERA / WEBCAM'
    Set-PrivacyAllow 'webcam'
    foreach ($r in 'HKLM:', 'HKCU:') {
        Remove-ItemProperty -Path "$r\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name 'LetAppsAccessCamera' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "$r\SOFTWARE\Policies\Microsoft\Camera" -Name 'AllowCamera' -ErrorAction SilentlyContinue
    }
    Write-Ok 'Permissao de camera liberada e bloqueios por politica removidos.'
    Write-Note 'Feche Discord/OBS/Teams/Zoom antes, eles podem "prender" a camera.'
    Restart-Svcs @('FrameServer', 'FrameServerMonitor') ''
    [void](Reset-PnpClass @('Camera', 'Image') 'camera|webcam|usb video')
    Write-Note 'Teste em Configuracoes > Bluetooth e dispositivos > Cameras.'
}

function Fix-Bluetooth {
    Write-Title 'FIX: BLUETOOTH'
    Restart-Svcs @('bthserv', 'BTAGService', 'BthAvctpSvc') 'Automatic'
    [void](Reset-PnpClass @('Bluetooth') '')
    Write-Note 'Se o fone/controle ainda nao conectar: remova o dispositivo em Configuracoes e pareie de novo.'
}

function Fix-Store {
    Write-Title 'FIX: MICROSOFT STORE'
    Restart-Svcs @('BITS', 'wuauserv', 'InstallService') ''
    $st = Get-AppxPackage -AllUsers -Name 'Microsoft.WindowsStore' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($st) {
        try {
            Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $st.InstallLocation 'AppxManifest.xml') -ErrorAction Stop
            Write-Ok 'Microsoft Store registrada novamente.'
        } catch { Write-Warn "Re-registro: $($_.Exception.Message)" }
        Write-Info 'Limpando o cache da Loja (wsreset)... a Loja vai abrir sozinha no final.'
        Start-Process wsreset.exe -Wait
        Write-Ok 'Cache da Loja limpo.'
    } else {
        Write-Warn 'A Microsoft Store NAO esta instalada (algum pack/debloat removeu).'
        if ((Get-Command winget.exe -ErrorAction SilentlyContinue) -and (Confirm-Step 'Tentar reinstalar a Loja pelo winget?')) {
            & winget.exe install --id 9WZDNCRFJBMP --source msstore --accept-package-agreements --accept-source-agreements 2>&1 | Out-String | Write-Log
            Write-Note 'Se nao funcionar: rode "wsreset -i" no Prompt como administrador e aguarde alguns minutos.'
        } else {
            Write-Note 'Para reinstalar: abra o Prompt como administrador e rode: wsreset -i  (aguarde alguns minutos).'
        }
    }
}

function Fix-WindowsUpdate {
    Write-Title 'FIX: WINDOWS UPDATE'
    $svcs = @('wuauserv', 'bits', 'cryptsvc', 'msiserver')
    foreach ($s in $svcs) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    foreach ($p in @("$env:SystemRoot\SoftwareDistribution", "$env:SystemRoot\System32\catroot2")) {
        if (Test-Path $p) {
            try { Rename-Item -Path $p -NewName ((Split-Path $p -Leaf) + ".avanti_$stamp") -ErrorAction Stop; Write-Ok "Pasta $(Split-Path $p -Leaf) renomeada (o Windows cria outra limpa)." }
            catch { Write-Warn "Nao deu para renomear $(Split-Path $p -Leaf): $($_.Exception.Message)" }
        }
    }
    foreach ($s in $svcs) { Start-Service -Name $s -ErrorAction SilentlyContinue }
    Write-Ok 'Servicos do Windows Update reiniciados.'
    Write-Note 'Agora va em Configuracoes > Windows Update > Verificar atualizacoes.'
    Write-Note "As pastas antigas (*.avanti_$stamp) podem ser apagadas depois que o Update funcionar."
}

function Fix-ArquivosSistema {
    Write-Title 'FIX: ARQUIVOS CORROMPIDOS DO WINDOWS (DISM + SFC)'
    Write-Note 'Isso leva de 10 a 30 minutos. Nao feche a janela.'
    Write-Info 'DISM: reparando a imagem do Windows...'
    & DISM.exe /Online /Cleanup-Image /RestoreHealth
    Write-Info 'SFC: verificando arquivos protegidos...'
    & sfc.exe /scannow
    Write-Ok 'Verificacao concluida. Leia a ultima mensagem acima para ver se algo foi reparado.'
}

function Fix-Disco {
    Write-Title 'FIX: ERRO DE DISCO'
    Write-Info "Verificando o disco $env:SystemDrive sem desligar nada (chkdsk /scan)..."
    & chkdsk.exe $env:SystemDrive /scan
    Write-Host ''
    if (Confirm-Step 'Agendar reparo completo no proximo reinicio? (pode levar bastante tempo em HD)') {
        # Marca o volume como "sujo": o Windows roda o chkdsk sozinho no proximo boot (independe do idioma)
        & fsutil.exe dirty set $env:SystemDrive | Out-Null
        Write-Ok 'Reparo agendado para o proximo reinicio.'
    }
    Write-Note 'Veja tambem a saude do SSD/HD no CrystalDiskInfo (menu "Programas uteis" (opcao 4)).'
}

function Fix-Explorer {
    Write-Title 'FIX: MENU INICIAR / BARRA DE TAREFAS / EXPLORER'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    Write-Ok 'Explorer reiniciado.'
    Restart-Svcs @('WSearch') ''
}

function Fix-Icones {
    Write-Title 'FIX: ICONES E MINIATURAS'
    Write-Note 'A area de trabalho vai sumir por alguns segundos.'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
    Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'iconcache_*.db' -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Ok 'Cache de icones e miniaturas recriado.'
}

function Fix-Impressora {
    Write-Title 'FIX: IMPRESSORA'
    Set-Service -Name Spooler -StartupType Automatic -ErrorAction SilentlyContinue
    Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
    if (Confirm-Step 'Limpar a fila de impressao (apaga trabalhos pendentes)?') {
        Get-ChildItem "$env:SystemRoot\System32\spool\PRINTERS" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Ok 'Fila limpa.'
    }
    Start-Service -Name Spooler -ErrorAction SilentlyContinue
    Write-Ok 'Servico de impressao reativado.'
    Start-Process control.exe 'printers'
}

function Fix-Xbox {
    Write-Title 'FIX: XBOX / GAME PASS / GAME BAR'
    foreach ($s in 'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc', 'GamingServices', 'GamingServicesNet') {
        Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue
    }
    Restart-Svcs @('XblAuthManager', 'XboxNetApiSvc', 'GamingServices') ''
    $pk = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.Xbox*' -or $_.Name -like 'Microsoft.GamingApp' -or $_.Name -like 'Microsoft.GamingServices' })
    foreach ($p in $pk) {
        try { Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $p.InstallLocation 'AppxManifest.xml') -ErrorAction Stop; Write-Ok "Registrado: $($p.Name)" } catch {}
    }
    if (-not ($pk | Where-Object { $_.Name -eq 'Microsoft.XboxGamingOverlay' })) {
        Write-Warn 'A Xbox Game Bar nao esta instalada.'
        Write-Note 'Reinstale pela Microsoft Store (procure "Xbox Game Bar"). Ryzen X3D de 2 CCDs PRECISA dela.'
    }
    if (-not ($pk | Where-Object { $_.Name -eq 'Microsoft.GamingServices' })) {
        Write-Note 'Game Pass sem "Gaming Services": abra o app Xbox, ele oferece instalar.'
    }
}

function Fix-Search {
    Write-Title 'FIX: PESQUISA DO WINDOWS'
    Set-Service -Name WSearch -StartupType Automatic -ErrorAction SilentlyContinue
    Restart-Svcs @('WSearch') ''
    Write-Note 'Se a pesquisa ainda nao achar arquivos: Opcoes de Indexacao > Avancado > Recriar.'
    Start-Process control.exe 'srchadmin.dll'
}

function Fix-Installer {
    Write-Title 'FIX: WINDOWS INSTALLER (.msi nao instala)'
    Set-Service -Name msiserver -StartupType Manual -ErrorAction SilentlyContinue
    Stop-Service -Name msiserver -Force -ErrorAction SilentlyContinue
    & "$env:SystemRoot\System32\msiexec.exe" /unregister; & "$env:SystemRoot\System32\msiexec.exe" /regserver
    if (Test-Path "$env:SystemRoot\SysWOW64\msiexec.exe") { & "$env:SystemRoot\SysWOW64\msiexec.exe" /unregister; & "$env:SystemRoot\SysWOW64\msiexec.exe" /regserver }
    Write-Ok 'Windows Installer registrado novamente.'
}

function Fix-TelaPreta {
    Write-Title 'FIX: TELA PRETA / TRAVOU A IMAGEM'
    Write-Note 'Atalho que reinicia o driver de video sem fechar nada: Windows + Ctrl + Shift + B'
    Write-Note '(a tela pisca e da um bip - e normal).'
    Fix-Explorer
    Write-Note 'Se a tela preta acontece no jogo: reinstale o driver com o DDU (menu "Programas uteis" (opcao 4)) e confira'
    Write-Note 'temperaturas no HWiNFO. Overclock/undervolt instavel tambem causa isso.'
}

function Fix-Diagnostico {
    Write-Title 'DIAGNOSTICO: O QUE ESTA PESANDO NO PC'
    Write-Host '  Top 10 por uso de CPU (agora):' -ForegroundColor White
    try {
        $cores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
        Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
            Where-Object { $_.Name -notin '_Total', 'Idle' } | Sort-Object PercentProcessorTime -Descending | Select-Object -First 10 |
            ForEach-Object { Write-Host ("    {0,-36} {1,6:N1}%" -f $_.Name, ($_.PercentProcessorTime / $cores)) }
    } catch { Write-Skip 'Contadores de CPU indisponiveis.' }
    Write-Host ''
    Write-Host '  Top 10 por uso de RAM:' -ForegroundColor White
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 |
        ForEach-Object { Write-Host ("    {0,-36} {1,7:N0} MB" -f $_.ProcessName, ($_.WorkingSet64 / 1MB)) }
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host ''
    Write-Note ("RAM em uso: {0:N1} de {1:N1} GB" -f (($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB), ($os.TotalVisibleMemorySize / 1MB))
    Write-Host '  Discos:' -ForegroundColor White
    Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ("    {0,-36} {1,-5} saude: {2}" -f $_.FriendlyName, $_.MediaType, $_.HealthStatus) }
    Write-Host ''
    Write-Note 'Nenhum processo foi fechado. Use o Gerenciador de Tarefas (Ctrl+Shift+Esc) para encerrar o que nao precisa.'
    Write-Note 'Programas que iniciam com o Windows: Autoruns (menu "Programas uteis" (opcao 4)).'
}

function Fix-AltTab24H2 {
    Write-Title 'FIX: DISCORD/NAVEGADOR TRAVANDO OU PISCANDO NO ALT+TAB (WINDOWS 11 24H2)'
    Write-Note 'No Windows 11 24H2, apps como Discord, Chrome e VS Code podem congelar a imagem ao voltar do jogo.'
    Write-Note 'A correcao conhecida e um ajuste do DWM (OverlayMinFPS = 0). Volta pelo Desfazer > fix.'
    if ($hw = Load-HW) { if ($hw.WIN11 -ne '1') { Write-Skip 'Este PC nao e Windows 11: nao se aplica.'; return } }
    if (Confirm-Step 'Aplicar a correcao?') {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayMinFPS' 0 | Out-Null
        Write-Ok 'Correcao aplicada. Reinicie o PC.'
        Write-Note 'Se voce desligou o MPO antes e o problema continuar, desfaca o MPO (Desfazer > gpu).'
        $script:NeedReboot = $true
    }
}

function Fix-DNSRapido {
    Write-Title 'FIX: DNS / SITES NAO ABREM'
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Ok 'Cache de DNS limpo.'
    foreach ($d in 'google.com', 'microsoft.com') {
        try { $r = Resolve-DnsName $d -DnsOnly -ErrorAction Stop | Where-Object { $_.IPAddress } | Select-Object -First 1; Write-Ok "$d -> $($r.IPAddress)" }
        catch { Write-Warn "$d nao resolveu: $($_.Exception.Message)" }
    }
    Write-Note 'Se nao resolveu: reinicie o roteador. No AVANTIPACK Pro, o DNS mais rapido troca sozinho.'
}

# ---------------------------------------------------------------------
#  Menu
# ---------------------------------------------------------------------
function Mod-Fix {
    $script:CurMod = 'fix'
    $script:CurItem = 'FIX'
    $itens = @(
        @('Internet / Wi-Fi sem conexao',             { Fix-Internet }),
        @('Sem audio',                                { Fix-Audio }),
        @('Microfone nao funciona',                   { Fix-Microfone }),
        @('Camera / webcam nao funciona',             { Fix-Camera }),
        @('Bluetooth',                                { Fix-Bluetooth }),
        @('Microsoft Store nao abre / nao baixa',     { Fix-Store }),
        @('Windows Update com erro',                  { Fix-WindowsUpdate }),
        @('Arquivos do Windows corrompidos (DISM+SFC)', { Fix-ArquivosSistema }),
        @('Erro de disco (chkdsk)',                   { Fix-Disco }),
        @('Menu Iniciar / barra de tarefas travada',  { Fix-Explorer }),
        @('Icones e miniaturas errados',              { Fix-Icones }),
        @('Impressora',                               { Fix-Impressora }),
        @('Xbox / Game Pass / Game Bar',              { Fix-Xbox }),
        @('Pesquisa do Windows nao acha nada',        { Fix-Search }),
        @('Instalador .msi com erro',                 { Fix-Installer }),
        @('Tela preta / imagem travada',              { Fix-TelaPreta }),
        @('Diagnostico: o que esta pesando (CPU/RAM/disco)', { Fix-Diagnostico }),
        @('Sites nao abrem (DNS)',                    { Fix-DNSRapido }),
        @('Discord/navegador travando no alt+tab (Win11 24H2)', { Fix-AltTab24H2 })
    )
    while ($true) {
        Write-Title 'FIX DE ERROS DO WINDOWS'
        Write-Note 'Escolha o problema que voce tem:'
        Write-Host ''
        $op = Select-Opcao @(for ($i = 0; $i -lt $itens.Count; $i++) { @{ K = "$($i + 1)"; T = $itens[$i][0] } }) -Inicio $(if ($op -match '^\d+$') { [int]$op - 1 } else { 0 })
        if ($op -eq '0' -or $op -notmatch '^\d+$' -or [int]$op -gt $itens.Count) { return }
        Write-Log "FIX escolhido: $($itens[[int]$op - 1][0])"
        & $itens[[int]$op - 1][1]
        Write-Host ''
        Read-Host '  ENTER para voltar a lista de fixes' | Out-Null
    }
}
