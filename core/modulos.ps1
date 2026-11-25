# =====================================================================
#  AVANTIPACK - modulos de otimizacao (por categoria)
#  Cada bloco tem um codigo (B1, C4, F2...). O catalogo (catalogo.ps1)
#  decide quais rodam no modo Automatico/Personalizado. No Modo
#  avancado (Selecao = $null) os blocos rodam como antes, perguntando
#  nos itens que tem pergunta.
#  Carregado por avanti.ps1 (dot-source). Sem acentos de proposito.
# =====================================================================

$script:Selecao = $null

# Decide se um bloco roda
function Want([string]$Id, [string]$Pergunta = '', $Padrao = $null) {
    # fora da otimizacao completa: se o ajuste ja esta aplicado e funcionando, pergunta antes de refazer
    if ($script:Selecao -eq $null -and (Test-ItemAplicado $Id)) {
        $nome = ($CATALOGO | Where-Object { $_.Id -eq $Id } | Select-Object -First 1).Nome
        Write-Ok ("Ja aplicado e funcionando: {0}" -f $(if ($nome) { $nome } else { $Id }))
        if (-not (Select-SimNao 'Aplicar de novo mesmo assim?' $false)) { return $false }
    }
    if ($script:Selecao -ne $null) { $ok = [bool]$script:Selecao[$Id] }
    elseif ($Pergunta) { $ok = (Confirm-Step $Pergunta $Padrao) }
    else { $ok = $true }
    if ($ok) { $script:CurItem = $Id }   # tudo que for salvo no backup a partir daqui pertence a este ajuste
    return $ok
}
function WantAny([string[]]$Ids) {
    if ($script:Selecao -eq $null) { return $true }
    foreach ($i in $Ids) { if ($script:Selecao[$i]) { return $true } }
    return $false
}

# ---------------------------------------------------------------------
#  Ajudantes novos
# ---------------------------------------------------------------------
# "Permitir que o computador desligue este dispositivo para economizar energia" = desmarcado
# (mesmo metodo do guia PC-Tuning: classe WMI MSPower_DeviceEnable)
function Disable-DevicePowerSaving($hw) {
    $lista = @(Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable -ErrorAction SilentlyContinue)
    if ($lista.Count -eq 0) { Write-Skip 'Nenhum dispositivo com essa opcao.'; return }
    $n = 0
    foreach ($d in $lista) {
        if (-not $d.Enable) { continue }
        $inst = [string]$d.InstanceName
        # Notebook: so USB/mouse/teclado (rede e outros continuam economizando bateria)
        if ($hw.LAPTOP -eq '1' -and $inst -notmatch '^(USB|HID)\\') { continue }
        if ($inst -notmatch '^(USB|HID|PCI)\\') { continue }
        try {
            Set-CimInstance -InputObject $d -Property @{ Enable = $false } -ErrorAction Stop
            $id = $inst -replace "'", "''"
            Add-Undo ("pm_" + $inst) ("Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable | Where-Object { `$_.InstanceName -eq '$id' } | Set-CimInstance -Property @{ Enable = `$true }") 'PS'
            $n++
        } catch {}
    }
    Write-Ok "$n dispositivo(s) (USB, mouse, teclado, rede) nao desligam mais para economizar energia."
    Write-Note 'Obs: trocar o dispositivo de porta USB pode religar a economia. Rode de novo se trocar.'
    $script:Applied += $n
}

function Set-BrowserBackground {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0 | Out-Null
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0 | Out-Null
    Set-Reg 'HKLM:\SOFTWARE\Policies\Google\Chrome' 'BackgroundModeEnabled' 0 | Out-Null
    Write-Ok 'Edge e Chrome fecham de verdade ao clicar no X (nao ficam gastando RAM/CPU no fundo).'
    Write-Note 'O Edge pode mostrar "gerenciado pela sua organizacao": e so por causa dessa politica.'
}

# ---------------------------------------------------------------------
#  B - LIMPEZA E PRIVACIDADE
# ---------------------------------------------------------------------
function Mod-Debloat {
    if (-not (WantAny @('B1','B2','B3','B4','B5','B6','B7','B8','B9','B10','B11'))) { return }
    $script:CurMod = 'debloat'
    $hw = Load-HW
    Write-Title 'PRIVACIDADE E SEGUNDO PLANO'

    if (Want 'B1') {
        Write-Info 'Telemetria e coleta de dados...'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0 | Out-Null
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0 | Out-Null
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0 | Out-Null
        Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0 | Out-Null
        Set-Svc 'DiagTrack' 'Disabled'
        Set-Svc 'dmwappushservice' 'Disabled'
        $tasks = @(
            @('\Microsoft\Windows\Application Experience\', 'Microsoft Compatibility Appraiser'),
            @('\Microsoft\Windows\Application Experience\', 'ProgramDataUpdater'),
            @('\Microsoft\Windows\Customer Experience Improvement Program\', 'Consolidator'),
            @('\Microsoft\Windows\Customer Experience Improvement Program\', 'UsbCeip'),
            @('\Microsoft\Windows\Autochk\', 'Proxy'),
            @('\Microsoft\Windows\DiskDiagnostic\', 'Microsoft-Windows-DiskDiagnosticDataCollector'),
            @('\Microsoft\Windows\Feedback\Siuf\', 'DmClient'),
            @('\Microsoft\Windows\Feedback\Siuf\', 'DmClientOnScenarioDownload')
        )
        foreach ($t in $tasks) { Disable-Task $t[0] $t[1] }
        Write-Ok 'Telemetria reduzida.'
    }
    if (Want 'B2') {
        Write-Info 'Anuncios, sugestoes e apps instalados sozinhos...'
        $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        foreach ($n in @('SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled',
                         'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled', 'SubscribedContent-338388Enabled',
                         'SubscribedContent-338389Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled')) {
            Set-Reg $cdm $n 0 | Out-Null
        }
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0 | Out-Null
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1 | Out-Null
        Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1 | Out-Null
        Write-Ok 'Anuncios, apps automaticos e pesquisa Bing no menu Iniciar desativados.'
    }
    if (Want 'B3') {
        Write-Info 'Widgets, Recall, Copilot e destaques da pesquisa...'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0 | Out-Null
        Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1 | Out-Null
        Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1 | Out-Null
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled' 0 | Out-Null
        Write-Ok 'Widgets, Recall, Copilot e destaques da pesquisa desligados.'
    }
    if (Want 'B4') {
        # Desliga a GRAVACAO; a Game Bar continua (Ryzen X3D de 2 CCDs precisa dela)
        Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 | Out-Null
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 | Out-Null
        Write-Ok 'Gravacao em segundo plano do Xbox desligada (a Game Bar continua instalada).'
    }
    if (Want 'B5') {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'Disabled' 1 | Out-Null
        Set-Svc 'WerSvc' 'Disabled'
        Write-Ok 'Envio de relatorios de erro desligado.'
    }
    if (Want 'B7' 'Impedir que Edge e Chrome fiquem rodando no fundo depois de fechados?' $true) { Set-BrowserBackground }

    if (Want 'B8') {
        $bio = @(Get-PnpDevice -Class Biometric -PresentOnly -ErrorAction SilentlyContinue)
        if ($bio.Count -eq 0) { Set-Svc 'WbioSrvc' 'Manual'; Write-Ok 'Sem leitor biometrico: servico de biometria so inicia se precisar.' }
        else { Write-Skip 'Leitor de digital/rosto encontrado: biometria mantida (Windows Hello).' }
    }
    $virt = 'PDF|XPS|OneNote|Fax|Send To|Enviar para|AnyDesk|Root Print'
    $imp = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $virt })
    if ($imp.Count -eq 0) {
        if (Want 'B10' 'Nenhuma impressora instalada. Desligar o servico de impressao?' $false) {
            Set-Svc 'Spooler' 'Disabled'; Write-Ok 'Servico de impressao desligado (Consertar > Impressora religa).'
        }
    } elseif ($script:Selecao -ne $null -and $script:Selecao['B10']) { Write-Skip "Impressora encontrada ($($imp[0].Name)): servico de impressao mantido." }

    if ($hw.DISK -eq 'HDD') {
        if (Want 'B11' 'Windows em HD: desligar a indexacao da pesquisa? (a busca de arquivos fica mais lenta)' $false) {
            Set-Svc 'WSearch' 'Disabled'; Write-Ok 'Indexacao desligada.'
        }
    }
    if (Want 'B9' 'Bloquear apps da Loja em segundo plano? (apps da Loja podem parar de notificar)' $false) {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1 | Out-Null
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BackgroundAppGlobalToggle' 0 | Out-Null
        Write-Ok 'Apps da Loja em segundo plano bloqueados.'
    }

    if ($script:Selecao -eq $null) {
        Write-Host ''
        Write-Note 'Remover apps pre-instalados inuteis (Noticias, Clima, Solitaire, Dicas, Feedback, Mapas, Clipchamp...).'
        Write-Note 'NAO remove: Loja, Xbox/Game Bar, Fotos, Calculadora, Bloco de Notas, Terminal, Teams e Outlook.'
        Write-Note 'Para voltar: Desfazer > Reinstalar apps (pela Microsoft Store).'
    }
    if (Want 'B6' 'Remover esses apps?' $true) {
        Write-Info 'Removendo apps pre-instalados inuteis...'
        $bloat = @('Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSearch', 'Microsoft.GetHelp',
                   'Microsoft.Getstarted', 'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.People',
                   'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps', 'Microsoft.MicrosoftOfficeHub',
                   'Microsoft.549981C3F5F10', 'Microsoft.PowerAutomateDesktop', 'Microsoft.Todos',
                   'Microsoft.ZuneVideo', 'Microsoft.MixedReality.Portal', 'Microsoft.SkypeApp',
                   'Microsoft.Wallet', 'Microsoft.Messaging',
                   'Clipchamp.Clipchamp', 'MicrosoftTeams', 'MicrosoftCorporationII.MicrosoftFamily',
                   '*CandyCrush*', '*BubbleWitch*', '*Disney*', '*TikTok*', '*Facebook*', '*Instagram*',
                   '*Hulu*', '*king.com*', '*LinkedIn*', '*AmazonVideo*', '*PrimeVideo*')
        foreach ($b in $bloat) {
            foreach ($p in @(Get-AppxPackage -AllUsers -Name $b -ErrorAction SilentlyContinue)) {
                try {
                    Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
                    Add-Backup 'APPX' $p.Name '' '1' '' $p.Name
                    Add-Estado 'APPX' '' $p.Name ''
                    Write-Ok "Removido: $($p.Name)"; Write-Log "APPX removido $($p.Name)"
                }
                catch { Write-Skip "Nao removido: $($p.Name)" }
            }
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $b } |
                ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
        }
    }
    $script:NeedReboot = $true
}

# ---------------------------------------------------------------------
#  C - SISTEMA E INPUT LAG
# ---------------------------------------------------------------------
function Mod-Sistema {
    if (-not (WantAny @('C1','C2','C3','C4','C5','C6','C7','C8','C9'))) { return }
    $script:CurMod = 'sistema'
    $hw = Load-HW
    Write-Title 'LATENCIA E RESPOSTA DO SISTEMA'

    if (Want 'C1') {
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed'      '0' 'String' | Out-Null
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String' | Out-Null
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String' | Out-Null
        Write-Ok 'Aceleracao do mouse desligada (movimento 1:1).'
    }
    if (Want 'C2') {
        Set-Reg 'HKCU:\Control Panel\Keyboard' 'KeyboardDelay' '0'  'String' | Out-Null
        Set-Reg 'HKCU:\Control Panel\Keyboard' 'KeyboardSpeed' '31' 'String' | Out-Null
        Set-Reg 'HKCU:\Control Panel\Accessibility\StickyKeys'        'Flags' '506' 'String' | Out-Null
        Set-Reg 'HKCU:\Control Panel\Accessibility\ToggleKeys'        'Flags' '58'  'String' | Out-Null
        Set-Reg 'HKCU:\Control Panel\Accessibility\Keyboard Response' 'Flags' '122' 'String' | Out-Null
        Write-Ok 'Teclado mais rapido e atalhos de acessibilidade (Shift 5x) desligados.'
    }
    if (Want 'C3') {
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1 | Out-Null
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode'   1 | Out-Null
        Write-Ok 'Modo de Jogo ligado.'
    }
    if (Want 'C4') {
        $mm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        Set-Reg $mm 'SystemResponsiveness'    10 | Out-Null
        Set-Reg $mm 'NetworkThrottlingIndex'  0xffffffff | Out-Null
        $g = "$mm\Tasks\Games"
        Set-Reg $g 'GPU Priority'        8 | Out-Null
        Set-Reg $g 'Priority'            6 | Out-Null
        Set-Reg $g 'Scheduling Category' 'High' 'String' | Out-Null
        Set-Reg $g 'SFIO Priority'       'High' 'String' | Out-Null
        Write-Ok 'Agendador multimidia (MMCSS) priorizando jogos.'
    }
    if (Want 'C5') {
        # 0x26 = quantum curto, variavel, boost maximo para o programa em primeiro plano
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 0x26 | Out-Null
        Write-Ok 'Mais forca de CPU para o programa que esta na tela (o jogo).'
    }
    if (Want 'C6') {
        Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String' | Out-Null
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0 | Out-Null
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 | Out-Null
        Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String' | Out-Null
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0 | Out-Null
        Write-Ok 'Visual leve: sem animacoes/transparencia, menus e inicializacao sem atraso.'
    }
    if ($hw.WIN11 -eq '1' -and (Want 'C7')) {
        $dxk = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
        $cur = ''
        if (Test-Path $dxk) { $cur = [string](Get-ItemProperty -Path $dxk -Name 'DirectXUserGlobalSettings' -ErrorAction SilentlyContinue).DirectXUserGlobalSettings }
        if ($cur -notmatch 'SwapEffectUpgradeEnable=1') {
            $new = ($cur -replace 'SwapEffectUpgradeEnable=\d;?', '') + 'SwapEffectUpgradeEnable=1;'
            Set-Reg $dxk 'DirectXUserGlobalSettings' $new 'String' | Out-Null
        }
        Write-Ok 'Jogos DX10/11 em janela sem borda com latencia de tela cheia (Windows 11).'
    }
    if (Want 'C8') {
        $bcd = (& bcdedit.exe /enum '{current}' 2>$null) -join "`n"
        if ($bcd -match 'useplatformclock\s+(Yes|Sim|True)') {
            & bcdedit.exe /deletevalue useplatformclock | Out-Null
            Add-Undo 'bcd_useplatformclock' 'bcdedit /set useplatformclock true'
            Write-Ok 'HPET forcado removido (estava aumentando a latencia).'
        } else { Write-Ok 'Timer do sistema no padrao correto (HPET nao forcado).' }
    }
    if (Want 'C9') { Disable-DevicePowerSaving $hw }
    $script:NeedReboot = $true
    Write-Note 'Mouse e teclado valem depois de reiniciar (ou sair e entrar na conta).'
}

# ---------------------------------------------------------------------
#  D - ENERGIA E PROCESSADOR
# ---------------------------------------------------------------------
$AV_GUID       = 'a7a1e0c0-a0a0-4a7a-9a7a-0000a7a1ba5e'
$ULTIMATE_GUID = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$HIGHPERF_GUID = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$BALANCED_GUID = '381b4222-f694-41f0-9685-ff5bb260df2e'

function Get-ActiveScheme {
    $o = (& powercfg.exe /getactivescheme) -join ' '
    return [regex]::Match($o, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}').Value
}

function Mod-Energia {
    if (-not (WantAny @('D1','D2'))) { return }
    $script:CurMod = 'energia'
    $hw = Load-HW
    Write-Title 'ENERGIA E PROCESSADOR'

    if (Want 'D1') {
        $old = Get-ActiveScheme
        if ($hw.CPU_X3D_DUAL -eq '1') {
            Write-Warn "$($hw.CPU): este processador estaciona o CCD sem 3D V-Cache durante o jogo."
            Write-Note 'Ele PRECISA do plano Balanceado + driver de chipset AMD + Game Bar. Plano maximo ATRAPALHA.'
            if ($old -and $old -ne $BALANCED_GUID) { Add-Undo 'power_restore' "powercfg /setactive $old" }
            & powercfg.exe /setactive $BALANCED_GUID | Out-Null
            Add-Estado 'PLANO' '' '' $BALANCED_GUID
            $svc = Get-Service -Name '*3dvcache*' -ErrorAction SilentlyContinue
            if ($svc) { Write-Ok "Servico do 3D V-Cache encontrado ($($svc.Name))." }
            else { Write-Warn 'Servico AMD 3D V-Cache NAO encontrado: instale o driver de chipset AMD (Programas uteis).' }
            Write-Ok 'Plano Balanceado ativo (correto para este processador).'
        } else {
            $usarMax = $true
            if ($hw.LAPTOP -eq '1') {
                Write-Note 'Notebook: o plano de desempenho maximo gasta mais bateria e aquece mais.'
                $usarMax = Confirm-Step 'Aplicar plano de desempenho maximo mesmo assim?' $false
            }
            if (-not $usarMax) {
                & powercfg.exe /overlaysetactive ded574b5-45a0-4f42-8737-46345c09c238 2>$null | Out-Null
                Add-Undo 'power_overlay' 'powercfg /overlaysetactive 00000000-0000-0000-0000-000000000000'
                Write-Ok 'Modo de energia "Melhor desempenho" ativo (sem trocar o plano do notebook).'
            } else {
                $list = (& powercfg.exe /list) -join ' '
                $criado = $true
                if ($list -notmatch $AV_GUID) {
                    & powercfg.exe -duplicatescheme $ULTIMATE_GUID $AV_GUID 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) { & powercfg.exe -duplicatescheme $HIGHPERF_GUID $AV_GUID 2>&1 | Out-Null }
                    if ($LASTEXITCODE -ne 0) {
                        $criado = $false
                        Write-Warn 'Este Windows nao permite criar plano novo (comum em Modern Standby).'
                        & powercfg.exe /overlaysetactive ded574b5-45a0-4f42-8737-46345c09c238 2>$null | Out-Null
                        Add-Undo 'power_overlay' 'powercfg /overlaysetactive 00000000-0000-0000-0000-000000000000'
                        Write-Ok 'Usado o modo "Melhor desempenho" no lugar.'
                    } else {
                        & powercfg.exe -changename $AV_GUID 'AVANTIPACK Desempenho' 'Plano de energia do AVANTIPACK' | Out-Null
                        Add-Undo 'power_delete' "powercfg /delete $AV_GUID"
                    }
                }
                if ($criado) {
                    if ($old -and $old -ne $AV_GUID) { Add-Undo 'power_restore' "powercfg /setactive $old" }
                    $cfg = @(
                        @('SUB_PROCESSOR', 'CPMINCORES', 100), @('SUB_PROCESSOR', 'PROCTHROTTLEMIN', 100),
                        @('2a737441-1930-4402-8d77-b2bebba308a3', '48e6b7a6-50f5-4782-a5d4-53bb8f07e226', 0),
                        @('SUB_PCIEXPRESS', 'ASPM', 0), @('SUB_DISK', 'DISKIDLE', 0),
                        @('SUB_PROCESSOR', 'PERFBOOSTMODE', 2), @('SUB_PROCESSOR', 'PERFEPP', 0))
                    if ($hw.CPU_HIBRIDO -eq '1') { $cfg += , @('SUB_PROCESSOR', 'PERFEPP1', 0) }
                    foreach ($c in $cfg) { & powercfg.exe /setacvalueindex $AV_GUID $c[0] $c[1] $c[2] 2>$null | Out-Null }
                    & powercfg.exe /setactive $AV_GUID | Out-Null
                    Add-Estado 'PLANO' '' '' $AV_GUID
                    Write-Ok 'Plano "AVANTIPACK Desempenho": sem core parking, boost agressivo, sem economia em USB/PCIe/disco.'
                }
            }
        }
        if ($hw.CPU_VENDOR -eq 'INTEL' -and $hw.CPU_HIBRIDO -eq '1' -and $hw.WIN11 -ne '1') {
            Write-Warn 'Intel hibrido no Windows 10: o Windows 11 distribui melhor P-cores e E-cores.'
        }
        if ($hw.CPU_RPL -eq '1') { Write-Warn 'Intel 13a/14a geracao: confirme a BIOS com microcode 0x12B ou mais novo.' }
    }
    if ($hw.LAPTOP -ne '1' -and (Want 'D2')) {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1 | Out-Null
        Write-Ok 'Power Throttling desligado (Discord, OBS e launchers nao perdem forca em segundo plano).'
    }
}

# ---------------------------------------------------------------------
#  F - INTERNET (com cuidado: nada que possa piorar a conexao)
# ---------------------------------------------------------------------
# Desfaz "estragos" que outros packs fazem na rede, sem inventar valores
function Repair-TcpDefaults {
    $t = Get-NetTCPSetting -SettingName Internet -ErrorAction SilentlyContinue
    if ($t -and [string]$t.AutoTuningLevelLocal -notin @('Normal', '')) {
        $old = ([string]$t.AutoTuningLevelLocal).ToLower()
        & netsh.exe int tcp set global autotuninglevel=normal | Out-Null
        Add-Undo 'tcp_autotuning' "netsh int tcp set global autotuninglevel=$old"
        Write-Ok "Ajuste automatico da janela TCP estava '$old' (download lento). Voltou para o padrao 'normal'."
    } else { Write-Ok 'Janela TCP no padrao correto (autotuning normal).' }
    $g = Get-NetOffloadGlobalSetting -ErrorAction SilentlyContinue
    if ($g -and [string]$g.ReceiveSideScaling -eq 'Disabled') {
        Set-NetOffloadGlobalSetting -ReceiveSideScaling Enabled -ErrorAction SilentlyContinue
        Add-Undo 'tcp_rss' 'Set-NetOffloadGlobalSetting -ReceiveSideScaling Disabled' 'PS'
        Write-Ok 'RSS (dividir a rede entre os nucleos) estava desligado. Religado.'
    }
    foreach ($a in @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.MediaType -eq '802.3' })) {
        $r = Get-NetAdapterRss -Name $a.Name -ErrorAction SilentlyContinue
        if ($r -and -not $r.Enabled) {
            Enable-NetAdapterRss -Name $a.Name -ErrorAction SilentlyContinue
            Add-Undo ("rss_" + $a.Name) ("Disable-NetAdapterRss -Name '" + $a.Name + "'") 'PS'
            Write-Ok "$($a.Name): RSS religado."
        }
    }
}

function Mod-Rede {
    if (-not (WantAny @('F1','F2','F3','F4'))) { return }
    $script:CurMod = 'rede'
    Write-Title 'REDE'
    if (Want 'F4') { Repair-TcpDefaults }
    if (Want 'F1') {
        $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
        $n = 0
        foreach ($if in Get-ChildItem $base -ErrorAction SilentlyContinue) {
            $p = Get-ItemProperty -Path $if.PSPath -ErrorAction SilentlyContinue
            $temIP = ($p.DhcpIPAddress -and $p.DhcpIPAddress -ne '0.0.0.0') -or (($p.IPAddress -join '') -match '\d')
            if ($temIP) {
                Set-Reg "$base\$($if.PSChildName)" 'TcpAckFrequency' 1 | Out-Null
                Set-Reg "$base\$($if.PSChildName)" 'TCPNoDelay'      1 | Out-Null
                $n++
            }
        }
        Write-Ok "Nagle desligado em $n conexao(oes): pacotes do jogo saem na hora."
    }
    if (Want 'F3') {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0 | Out-Null
        Write-Ok 'Windows Update nao usa mais sua internet para mandar atualizacoes a outros PCs.'
    }
    if (Want 'F2') {
        $kws = @('*EEE', 'AdvancedEEE', 'EEELinkAdvertisement', 'EnableGreenEthernet', 'GigaLite', 'PowerSavingMode', 'ULPMode')
        $ads = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.MediaType -eq '802.3' })
        if ($ads.Count -eq 0) { Write-Skip 'Sem placa cabeada conectada (o Wi-Fi nao e alterado de proposito).' }
        foreach ($a in $ads) {
            $c = 0
            foreach ($k in $kws) { if (Set-NetAdv $a.Name $k '0') { $c++ } }
            if ($c -gt 0) { Write-Ok "$($a.InterfaceDescription): $c modo(s) de economia de energia desligado(s)." }
            else { Write-Skip "$($a.InterfaceDescription): ja estava sem economia." }
        }
    }
    $script:NeedReboot = $true
}

# ---------------------------------------------------------------------
#  G - ARMAZENAMENTO E MEMORIA
# ---------------------------------------------------------------------
function Mod-Armazenamento {
    if (-not (WantAny @('G1','G2','G3','G4','G5'))) { return }
    $script:CurMod = 'armazenamento'
    $hw = Load-HW
    Write-Title 'ARMAZENAMENTO E MEMORIA'

    if (Want 'G1') {
        if ($hw.DISK -eq 'NVME' -or $hw.DISK -eq 'SSD') {
            & fsutil.exe behavior set DisableDeleteNotify 0 | Out-Null
            Write-Ok 'TRIM do SSD ligado.'
            $q = (& fsutil.exe behavior query disablelastaccess) -join ' '
            $m = [regex]::Match($q, '=\s*(\d+)')
            if ($m.Success -and $m.Groups[1].Value -ne '1') {
                & fsutil.exe behavior set disablelastaccess 1 | Out-Null
                Add-Undo 'fs_lastaccess' ("fsutil behavior set disablelastaccess " + $m.Groups[1].Value)
                Write-Ok 'Windows parou de gravar "ultimo acesso" a cada arquivo lido.'
            }
            $t = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Defrag\' -TaskName 'ScheduledDefrag' -ErrorAction SilentlyContinue
            if ($t -and $t.State -eq 'Disabled') { Enable-ScheduledTask -InputObject $t | Out-Null; Write-Ok 'Otimizacao semanal do SSD religada.' }
        } elseif ($hw.DISK -eq 'HDD') {
            Write-Warn 'Windows em HD: o maior ganho e trocar por SSD. Ate la:'
            $sm = Get-CimInstance Win32_Service -Filter "Name='SysMain'" -ErrorAction SilentlyContinue
            if ($sm -and $sm.StartMode -ne 'Auto') { Set-Svc 'SysMain' 'Automatic'; Start-Service SysMain -ErrorAction SilentlyContinue }
            Write-Ok 'SysMain (pre-carregamento) ligado - ele acelera o HD.'
            $t = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Defrag\' -TaskName 'ScheduledDefrag' -ErrorAction SilentlyContinue
            if ($t -and $t.State -eq 'Disabled') { Enable-ScheduledTask -InputObject $t | Out-Null }
            Write-Ok 'Desfragmentacao automatica ligada.'
        }
        $hdds = @(Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { [string]$_.MediaType -eq 'HDD' -or [string]$_.MediaType -eq '3' })
        if ($hdds.Count -gt 0 -and $hw.DISK -ne 'HDD') { Write-Note 'Este PC tem HD mecanico: instale os jogos no SSD/NVMe e use o HD so para arquivos.' }
    }
    if ($hw.LAPTOP -ne '1' -and (Want 'G2')) {
        $hib = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -ErrorAction SilentlyContinue).HibernateEnabled
        if ($hib -ne 0) {
            & powercfg.exe /hibernate off | Out-Null
            Add-Undo 'hibernate' 'powercfg /hibernate on'
            Write-Ok 'Hibernacao e Inicializacao Rapida desligadas (libera espaco e o PC liga "limpo").'
        } else { Write-Skip 'Hibernacao ja estava desligada.' }
    }
    if ([int]$hw.RAM_GB -ge 32 -and (Want 'G3')) {
        $mm = Get-MMAgent -ErrorAction SilentlyContinue
        if ($mm -and $mm.MemoryCompression) {
            Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
            Add-Undo 'memcompression' 'Enable-MMAgent -MemoryCompression' 'PS'
            Write-Ok 'Compressao de memoria desligada (com 32 GB+ ela so gasta CPU).'
        }
    }
    if ([int]$hw.RAM_GB -le 8) { Write-Warn "So $($hw.RAM_GB) GB de RAM: feche navegador/Discord antes de jogar e use texturas no medio/baixo." }
    if (Want 'G4') {
        $cs = Get-CimInstance Win32_ComputerSystem
        $pf = @(Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue)
        if (-not $cs.AutomaticManagedPagefile -and $pf.Count -eq 0) {
            Write-Warn 'Arquivo de paginacao estava DESATIVADO (causa jogo fechando sozinho).'
            Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $true }
            Add-Undo 'pagefile' '$cs = Get-CimInstance Win32_ComputerSystem; Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $false }' 'PS'
            Write-Ok 'Arquivo de paginacao voltou para automatico.'
        } else { Write-Ok 'Arquivo de paginacao ativo (correto, mesmo com muita RAM).' }
    }
    if (Want 'G5' 'Limpar arquivos temporarios agora?' $true) {
        $alvos = @($env:TEMP, "$env:SystemRoot\Temp", "$env:LOCALAPPDATA\CrashDumps",
                   "$env:LOCALAPPDATA\NVIDIA\DXCache", "$env:LOCALAPPDATA\AMD\DxCache")
        $antes = 0
        foreach ($d in $alvos) {
            if (Test-Path $d) {
                $antes += (Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                Get-ChildItem $d -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike 'avp_*' } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Stop-Service -Name wuauserv, bits -Force -ErrorAction SilentlyContinue
        $sd = "$env:SystemRoot\SoftwareDistribution\Download"
        if (Test-Path $sd) {
            $antes += (Get-ChildItem $sd -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            Get-ChildItem $sd -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        Start-Service -Name wuauserv, bits -ErrorAction SilentlyContinue
        try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop } catch {}
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        if (Confirm-Step 'Esvaziar a Lixeira tambem?' $false) { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Ok 'Lixeira esvaziada.' }
        Write-Ok ("Limpeza feita (~{0:N0} MB). Arquivos em uso ficam." -f ($antes / 1MB))
        Write-Note 'O cache de shader e recriado: o primeiro minuto de cada jogo pode engasgar 1 vez.'
    }
    $script:NeedReboot = $true
}
