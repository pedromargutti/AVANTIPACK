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

function Get-StartupItems {
    $exp = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $fontes = @(
        @{ Reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Apr = "HKCU:\$exp\Run" },
        @{ Reg = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Apr = "HKLM:\$exp\Run" },
        @{ Reg = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Apr = "HKLM:\$exp\Run32" }
    )
    $itens = @()
    foreach ($f in $fontes) {
        $k = Get-Item -Path $f.Reg -ErrorAction SilentlyContinue
        if (-not $k) { continue }
        foreach ($n in $k.GetValueNames()) {
            if (-not $n) { continue }
            $itens += [pscustomobject]@{ Nome = $n; Cmd = [string]$k.GetValue($n); Apr = $f.Apr }
        }
    }
    foreach ($p in @(@("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup", "HKCU:\$exp\StartupFolder"),
                     @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp", "HKLM:\$exp\StartupFolder"))) {
        foreach ($fi in Get-ChildItem $p[0] -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' }) {
            $itens += [pscustomobject]@{ Nome = $fi.Name; Cmd = $fi.FullName; Apr = $p[1] }
        }
    }
    foreach ($i in $itens) {
        $v = $null
        $ak = Get-Item -Path $i.Apr -ErrorAction SilentlyContinue
        if ($ak -and ($ak.GetValueNames() -contains $i.Nome)) { $v = $ak.GetValue($i.Nome) }
        $ligado = $true
        if ($v -is [byte[]] -and $v.Length -gt 0) { $ligado = (($v[0] -band 1) -eq 0) }
        $i | Add-Member -NotePropertyName Ligado -NotePropertyValue $ligado
        $essencial = ($i.Nome + ' ' + $i.Cmd) -match 'SecurityHealth|Windows Defender|RtkAud|Realtek|Nahimic|NVIDIA|NvBackend|AMD|Radeon|igfx|IntelGraphics|Synaptics|ELAN|Logitech|Razer|Corsair|SteelSeries|HyperX|Wooting|ASUS|MSI|Armoury|iCUE|G HUB|Bluetooth'
        $i | Add-Member -NotePropertyName Essencial -NotePropertyValue $essencial
    }
    return $itens
}

function Mod-Inicializacao {
    $script:CurMod = 'inicializacao'
    $script:CurItem = 'B12'
    while ($true) {
        Write-Title 'PROGRAMAS QUE INICIAM COM O WINDOWS'
        Write-Note 'Cada programa aqui abre junto com o Windows e fica rodando enquanto voce joga.'
        Write-Note 'Desligar NAO desinstala: o programa so para de abrir sozinho. Da para religar aqui ou no Desfazer.'
        Write-Note 'MARCADO = abre com o Windows. Desmarque o que nao precisa abrir sozinho.'
        Write-Note 'Os marcados como (manter) sao drivers, seguranca ou perifericos: deixe ligados.'
        Write-Host ''
        $its = @(Get-StartupItems)
        if ($its.Count -eq 0) { Write-Ok 'Nenhum programa na inicializacao.'; return }
        $r = Select-Varios @(for ($i = 0; $i -lt $its.Count; $i++) {
                $x = $its[$i]
                @{ K = "$i"; T = ($x.Nome + $(if ($x.Essencial) { '  (manter)' } else { '' })); On = [bool]$x.Ligado; C = $(if ($x.Essencial) { 'Yellow' } else { $null }) }
             }) -Concluir 'SALVAR' -SemTodos
        if ($null -eq $r) { return }
        $mud = @(for ($i = 0; $i -lt $its.Count; $i++) { if ([bool]$its[$i].Ligado -ne (@($r) -contains "$i")) { $i } })
        if ($mud.Count -eq 0) { Write-Skip 'Nada mudou.'; return }
        foreach ($n in $mud) {
            $x = $its[[int]$n]
            $byte0 = if ($x.Ligado) { 3 } else { 2 }
            $val = [byte[]](@($byte0) + @(0) * 11)
            if (Set-Reg $x.Apr $x.Nome $val 'Binary') {
                if ($x.Ligado) { Write-Ok "$($x.Nome): nao abre mais com o Windows." } else { Write-Ok "$($x.Nome): volta a abrir com o Windows." }
            }
        }
        Write-Host ''
        Read-Host '  ENTER para ver a lista atualizada' | Out-Null
    }
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
    Write-Title 'LIMPEZA E PRIVACIDADE'

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
        Write-Note 'NAO remove: Loja, Xbox/Game Bar, Fotos, Calculadora, Bloco de Notas, Terminal.'
        Write-Note 'Isso NAO entra no Desfazer: para voltar, reinstale pela Microsoft Store.'
    }
    if (Want 'B6' 'Remover esses apps?' $true) {
        Write-Info 'Removendo apps pre-instalados inuteis...'
        $bloat = @('Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSearch', 'Microsoft.GetHelp',
                   'Microsoft.Getstarted', 'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.People',
                   'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps', 'Microsoft.MicrosoftOfficeHub',
                   'Microsoft.549981C3F5F10', 'Microsoft.PowerAutomateDesktop', 'Microsoft.Todos',
                   'Microsoft.ZuneVideo', 'Microsoft.MixedReality.Portal', 'Microsoft.SkypeApp',
                   'Microsoft.Wallet', 'Microsoft.Messaging', 'Microsoft.OutlookForWindows',
                   'Clipchamp.Clipchamp', 'MicrosoftTeams', 'MSTeams', 'MicrosoftCorporationII.MicrosoftFamily',
                   '*CandyCrush*', '*BubbleWitch*', '*Disney*', '*TikTok*', '*Facebook*', '*Instagram*',
                   '*Hulu*', '*king.com*', '*LinkedIn*', '*AmazonVideo*', '*PrimeVideo*')
        foreach ($b in $bloat) {
            foreach ($p in @(Get-AppxPackage -AllUsers -Name $b -ErrorAction SilentlyContinue)) {
                try {
                    Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
                    Add-Backup 'APPX' $p.Name '' '1' '' $p.Name
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
    Write-Title 'SISTEMA E INPUT LAG'

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
function Measure-Ping([string]$Alvo, [int]$N = 15) {
    $p = New-Object System.Net.NetworkInformation.Ping
    $t = New-Object System.Collections.Generic.List[double]; $perda = 0
    for ($i = 0; $i -lt $N; $i++) {
        try { $r = $p.Send($Alvo, 1000); if ($r.Status -eq 'Success') { $t.Add([double]$r.RoundtripTime) } else { $perda++ } }
        catch { $perda++ }
        Start-Sleep -Milliseconds 150
    }
    $med = if ($t.Count) { ($t | Measure-Object -Average).Average } else { 0 }
    $jit = 0
    if ($t.Count -gt 1) { $d = 0; for ($i = 1; $i -lt $t.Count; $i++) { $d += [math]::Abs($t[$i] - $t[$i - 1]) }; $jit = $d / ($t.Count - 1) }
    return [pscustomobject]@{ Alvo = $Alvo; Media = [math]::Round($med, 1); Jitter = [math]::Round($jit, 1); Perda = [math]::Round(100 * $perda / $N) }
}

function Test-Rede {
    Write-Title 'DIAGNOSTICO DA INTERNET'
    $ads = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
    if ($ads.Count -eq 0) { Write-Warn 'Nenhuma conexao ativa.'; return }
    foreach ($a in $ads) {
        $wifi = ($a.MediaType -match '802\.11') -or ($a.InterfaceDescription -match 'Wi-?Fi|Wireless|802\.11|WLAN')
        Write-Host ("  {0}  [{1}]  velocidade do link: {2}" -f $a.Name, $(if ($wifi) { 'Wi-Fi' } else { 'Cabo' }), $a.LinkSpeed) -ForegroundColor White
        if ($wifi) {
            $w = (& netsh.exe wlan show interfaces 2>$null) -join "`n"
            $sinal = [regex]::Match($w, '(\d{1,3})\s*%').Groups[1].Value
            $canal = [regex]::Match($w, '(?im)^\s*(Canal|Channel)\s*:\s*(\d+)').Groups[2].Value
            if ($sinal) {
                if ([int]$sinal -lt 70) { Write-Warn "Sinal do Wi-Fi fraco ($sinal%). Chegue mais perto do roteador ou use cabo." } else { Write-Ok "Sinal do Wi-Fi bom ($sinal%)." }
            }
            if ($canal) {
                if ([int]$canal -le 14) { Write-Warn "Wi-Fi em 2.4 GHz (canal $canal): mais lento e com mais interferencia. Se o roteador tiver, use a rede 5 GHz." }
                else { Write-Ok "Wi-Fi em 5/6 GHz (canal $canal)." }
            }
            Write-Note 'Para jogo competitivo, o cabo sempre ganha do Wi-Fi em ping estavel.'
        } else {
            if ($a.LinkSpeed -match '^100 Mbps|^10 Mbps') {
                Write-Warn 'Cabo conectado a 100 Mbps ou menos: cabo ruim/velho ou porta limitada. Se seu plano passa de 100 mega, troque por cabo CAT5e/CAT6.'
            } else { Write-Ok "Cabo a $($a.LinkSpeed)." }
        }
    }
    $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1).NextHop
    Write-Host ''
    Write-Info 'Medindo ping, variacao (jitter) e perda de pacotes (cerca de 10 segundos)...'
    $res = @()
    if ($gw -and $gw -ne '0.0.0.0') { $res += Measure-Ping $gw }
    $res += Measure-Ping '1.1.1.1'
    $res += Measure-Ping '8.8.8.8'
    foreach ($r in $res) {
        $nome = if ($r.Alvo -eq $gw) { "Roteador ($gw)" } else { "Internet ($($r.Alvo))" }
        $cor = if ($r.Perda -gt 0 -or $r.Jitter -gt 10) { 'Yellow' } else { 'Green' }
        Write-Host ("  {0,-28} ping {1,6} ms   variacao {2,5} ms   perda {3,3}%" -f $nome, $r.Media, $r.Jitter, $r.Perda) -ForegroundColor $cor
    }
    $lan = $res | Where-Object { $_.Alvo -eq $gw } | Select-Object -First 1
    $net = $res | Where-Object { $_.Alvo -ne $gw }
    Write-Host ''
    if ($lan -and ($lan.Perda -gt 0 -or $lan.Jitter -gt 5 -or $lan.Media -gt 10)) {
        Write-Warn 'O problema esta DENTRO da sua casa (PC -> roteador): Wi-Fi fraco, cabo ruim ou roteador sobrecarregado.'
        Write-Note 'Teste: use cabo, reinicie o roteador e veja se alguem esta baixando/assistindo em 4K.'
    } elseif (($net | Where-Object { $_.Perda -gt 0 -or $_.Jitter -gt 15 }).Count -gt 0) {
        Write-Warn 'Sua rede local esta boa, mas a conexao com a internet esta instavel: geralmente e o provedor.'
        Write-Note 'Teste em outro horario. Se continuar, ligue para o provedor com esses numeros.'
    } else {
        Write-Ok 'Conexao estavel: sem perda de pacotes e com pouca variacao.'
    }
    Write-Note 'O ping dentro do jogo depende da distancia ate o servidor: escolha sempre o servidor do Brasil.'
}

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
    if (-not (WantAny @('F1','F2','F3','F4','F5'))) { return }
    $script:CurMod = 'rede'
    Test-Rede
    Write-Title 'AJUSTES DE INTERNET'
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
    if (Want 'F5' 'Testar qual DNS e mais rapido no seu PC agora?' $true) { Mod-DNS }
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
                Get-ChildItem $d -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
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

# ---------------------------------------------------------------------
#  I - AVANCADO (riscos). Nunca entram no modo Automatico.
# ---------------------------------------------------------------------
function Mod-Avancado {
    if (-not (WantAny @('I1','I2','I3','I4','I5'))) { return }
    $script:CurMod = 'avancado'
    $hw = Load-HW
    Write-Title 'AJUSTES AVANCADOS - LEIA CADA AVISO'

    $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
    $hvci = $false
    if ($dg) { $hvci = (@($dg.SecurityServicesRunning) -contains 2) }
    Write-Host '  [I1] Integridade de memoria (HVCI/VBS)' -ForegroundColor White
    Write-Note ("     Status atual: {0}" -f $(if ($hvci) { 'LIGADA' } else { 'desligada' }))
    Write-Note '     Desligar costuma dar FPS a mais em processadores mais fracos.'
    Write-Note '     RISCO: menos protecao contra drivers maliciosos. Alguns anti-cheats (Vanguard/Valorant,'
    Write-Note '     FACEIT) podem EXIGIR que ela fique ligada - se o jogo reclamar, use o Desfazer.'
    if ($hvci -and (Want 'I1' 'Desligar a Integridade de memoria?')) {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 0 | Out-Null
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity' 0 | Out-Null
        Write-Ok 'Integridade de memoria desligada (vale apos reiniciar).'
        $script:NeedReboot = $true
    }
    Write-Host ''

    Write-Host '  [I2] Modo MSI (interrupcoes por mensagem) na placa de video' -ForegroundColor White
    Write-Note '     Reduz a latencia de interrupcao. Placas atuais ja vem assim quase sempre.'
    $gpusPnp = @(Get-PnpDevice -Class Display -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'PCI\*' })
    $pend = @()
    foreach ($g in $gpusPnp) {
        $k = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($g.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        $v = (Get-ItemProperty -LiteralPath $k -Name MSISupported -ErrorAction SilentlyContinue).MSISupported
        if ($v -eq 1) { Write-Ok "$($g.FriendlyName): MSI ja ativo." } else { $pend += @{ Dev = $g; Key = $k } }
    }
    if ($pend.Count -gt 0 -and (Want 'I2' 'Ativar modo MSI na placa de video?')) {
        foreach ($p in $pend) { if (Set-Reg $p.Key 'MSISupported' 1) { Write-Ok "$($p.Dev.FriendlyName): MSI ativado." } }
        $script:NeedReboot = $true
    }
    Write-Host ''

    if ($hw.WIN11 -eq '1') {
        Write-Host '  [I3] Timer resolution global (Windows 11)' -ForegroundColor White
        Write-Note '     So faz diferenca se voce usar um app de timer resolution. Sem app, nao muda nada.'
        if (Want 'I3' 'Permitir timer resolution global?') {
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests' 1 | Out-Null
            Write-Ok 'Timer resolution global permitido.'
            $script:NeedReboot = $true
        }
        Write-Host ''
    }

    Write-Host '  [I4] Desligar "Otimizacoes de tela cheia" (FSO) em todos os jogos' -ForegroundColor White
    Write-Note '     Pode reduzir input lag em jogos DX9/DX11 antigos. Em jogos atuais e no Windows 11'
    Write-Note '     costuma nao mudar nada e pode atrapalhar alt+tab e HDR.'
    if (Want 'I4' 'Desligar FSO global?') {
        Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehaviorMode' 2 | Out-Null
        Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_HonorUserFSEBehaviorMode' 1 | Out-Null
        Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_DXGIHonorFSEWindowsCompatible' 1 | Out-Null
        Write-Ok 'FSO desligado globalmente.'
    }
    Write-Host ''

    $bcdAll = (& bcdedit.exe /enum '{current}' 2>$null) -join "`n"
    $hvAtual = [regex]::Match($bcdAll, 'hypervisorlaunchtype\s+(\w+)').Groups[1].Value
    Write-Host '  [I5] Desligar o hypervisor do Windows (Hyper-V)' -ForegroundColor White
    Write-Note '     Desliga toda a virtualizacao do Windows (inclusive VBS). Pode dar FPS extra.'
    $usa = @()
    foreach ($f in @(@('Microsoft-Windows-Subsystem-Linux', 'WSL'), @('VirtualMachinePlatform', 'WSL2 / emuladores Android'),
                     @('Microsoft-Hyper-V-All', 'Hyper-V'), @('Containers-DisposableClientVM', 'Area Restrita'))) {
        $st = Get-WindowsOptionalFeature -Online -FeatureName $f[0] -ErrorAction SilentlyContinue
        if ($st -and $st.State -eq 'Enabled') { $usa += $f[1] }
    }
    if ($usa.Count -gt 0) { Write-Warn ("     Este PC usa: {0}. Isso PARA de funcionar com o hypervisor desligado." -f ($usa -join ', ')) }
    if ($hvAtual -notmatch '^(Off|Desativado)$' -and (Want 'I5' 'Desligar o hypervisor?')) {
        & bcdedit.exe /set hypervisorlaunchtype off | Out-Null
        Add-Undo 'bcd_hypervisor' 'bcdedit /set hypervisorlaunchtype Auto'
        Write-Ok 'Hypervisor desligado (vale apos reiniciar).'
        $script:NeedReboot = $true
    }
}
