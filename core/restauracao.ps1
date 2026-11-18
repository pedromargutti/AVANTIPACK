# =====================================================================
#  AVANTIPACK - Central de restauracao
#  1) Desfazer tudo   2) Recolocar uma funcao   3) Reinstalar apps
#  4) Religar funcoes do Windows (mesmo se outro pack desligou)
#  5) Voltar pelo ponto de restauracao   6) Desfazer por parte
#  Carregado por avanti.ps1 (dot-source). Sem acentos de proposito.
# =====================================================================

# O que VOLTA a funcionar quando se desfaz cada ajuste (texto para leigo)
$VOLTA = @{
    B1 = 'Telemetria do Windows volta ao padrao'
    B2 = 'Sugestoes e apps que a Microsoft instala sozinha voltam'
    B3 = 'Widgets, Recall, Copilot e destaques da pesquisa voltam'
    B4 = 'GRAVAR CLIPES pela Xbox Game Bar (Win+Alt+G) volta a funcionar'
    B5 = 'Relatorios de erro do Windows voltam'
    B6 = 'Apps removidos (use "Reinstalar apps")'
    B7 = 'Edge/Chrome voltam a rodar no fundo (extensoes e notificacoes com navegador fechado)'
    B8 = 'Servico de biometria volta ao normal'
    B9 = 'Apps da Loja voltam a rodar no fundo (notificacoes do WhatsApp da Loja, etc.)'
    B10 = 'IMPRESSORA volta a funcionar'
    B11 = 'Indexacao da pesquisa (achar arquivos rapido) volta'
    B12 = 'Programas desligados voltam a abrir com o Windows'
    C1 = 'Aceleracao do mouse ("Aumentar precisao do ponteiro") volta'
    C2 = 'Teclado e Teclas de Aderencia (Shift 5x) voltam ao padrao'
    C3 = 'Modo de Jogo volta como era'
    C4 = 'Prioridade multimidia (MMCSS) volta ao padrao'
    C5 = 'Prioridade do programa em primeiro plano volta ao padrao'
    C6 = 'ANIMACOES e TRANSPARENCIA do Windows voltam'
    C7 = 'Otimizacao de jogos em janela volta como era'
    C8 = 'Configuracao antiga do timer (HPET) volta'
    C9 = 'Economia de energia de USB/mouse/teclado/rede volta'
    D1 = 'Plano de energia anterior volta'
    D2 = 'Power Throttling volta (economiza bateria em notebook)'
    E1 = 'Taxa de atualizacao (Hz) anterior do monitor volta'
    E2 = 'Agendamento de GPU (HAGS) volta como era'
    E3 = 'Configuracoes anteriores do painel NVIDIA/AMD voltam'
    E4 = 'MPO volta'
    F1 = 'Envio de pacotes de rede volta ao padrao (Nagle)'
    F2 = 'Economia de energia da placa de rede volta'
    F3 = 'Windows Update volta a compartilhar downloads'
    F4 = 'Ajustes de TCP/RSS voltam como estavam'
    F5 = 'DNS anterior (do provedor/roteador) volta'
    G1 = 'Ajustes de SSD/HD voltam como eram'
    G2 = 'HIBERNACAO e Inicializacao Rapida voltam'
    G3 = 'Compressao de memoria volta'
    G4 = 'Arquivo de paginacao volta como estava'
    H1 = 'Prioridade alta dos jogos e removida'
    H2 = 'Perfis NVIDIA por jogo voltam ao padrao do driver'
    H3 = 'Jogos voltam a deixar o Windows escolher a placa de video'
    I1 = 'INTEGRIDADE DE MEMORIA volta (alguns anti-cheats como Vanguard/FACEIT exigem)'
    I2 = 'Modo de interrupcao da placa de video volta ao padrao'
    I3 = 'Timer resolution global volta ao padrao'
    I4 = 'Otimizacoes de tela cheia (FSO) voltam'
    I5 = 'HYPERVISOR volta: WSL2, Hyper-V, Area Restrita e emuladores Android funcionam de novo'
    FIX = 'Correcoes feitas pelo menu "Consertar um problema"'
}

# Apps que o pack remove: nome amigavel + Id da Microsoft Store (quando conhecido)
$APPX_INFO = @{
    'Microsoft.BingWeather'                 = @('Clima (MSN)', '9WZDNCRFJ3Q2')
    'Microsoft.BingNews'                    = @('Noticias (Microsoft Start)', '9WZDNCRFHVFW')
    'Microsoft.MicrosoftSolitaireCollection' = @('Microsoft Solitaire Collection', '9WZDNCRFHWD2')
    'Microsoft.WindowsFeedbackHub'          = @('Hub de Comentarios', '9NBLGGH4R32N')
    'Microsoft.WindowsMaps'                 = @('Mapas', '9WZDNCRDTBVB')
    'Microsoft.Todos'                       = @('Microsoft To Do', '9NBLGGH5R558')
    'Clipchamp.Clipchamp'                   = @('Clipchamp (editor de video)', '9P1J8S7CCWWT')
    'Microsoft.GetHelp'                     = @('Obter Ajuda', '9PKDZBMV1H3T')
    'Microsoft.ZuneVideo'                   = @('Filmes e TV', '9WZDNCRFJ3P2')
    'Microsoft.People'                      = @('Pessoas', '9NBLGGH10PG8')
    'Microsoft.MicrosoftOfficeHub'          = @('Microsoft 365 (Office)', '9WZDNCRD29V9')
    'Microsoft.PowerAutomateDesktop'        = @('Power Automate', '9NFTCH6J7FHV')
    'MSTeams'                               = @('Microsoft Teams', 'XP8BT8DW290MPQ')
    'Microsoft.OutlookForWindows'           = @('Outlook (novo)', '9NRX63209R7B')
    'Microsoft.Getstarted'                  = @('Dicas', '')
}

function Get-AppxNome([string]$pkg) {
    if ($APPX_INFO.ContainsKey($pkg)) { return $APPX_INFO[$pkg][0] }
    return $pkg
}

function Install-AppxDeVolta([string]$pkg) {
    $nome = Get-AppxNome $pkg
    $id = if ($APPX_INFO.ContainsKey($pkg)) { $APPX_INFO[$pkg][1] } else { '' }
    if ($id -and (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-Info "Reinstalando $nome pela Microsoft Store..."
        & winget.exe install --id $id --source msstore --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-String | Write-Log
        if (Get-AppxPackage -Name $pkg -ErrorAction SilentlyContinue) { Write-Ok "$nome reinstalado."; return $true }
    }
    if ($id) { Start-Process "ms-windows-store://pdp/?ProductId=$id" }
    else { Start-Process ("ms-windows-store://search/?query=" + [uri]::EscapeDataString($nome)) }
    Write-Note "Abri a pagina de '$nome' na Microsoft Store: clique em Obter/Instalar."
    return $true
}

# Restaura as linhas do backup que passam no filtro e tira elas do backup
function Invoke-RestoreRows([scriptblock]$Filtro, [switch]$SemApps) {
    $rows = @($script:BackupCache)
    $ok = 0
    for ($i = $rows.Count - 1; $i -ge 0; $i--) {
        $r = $rows[$i]
        if (-not (& $Filtro $r)) { continue }
        if ($r.Kind -eq 'APPX' -and $SemApps) { continue }
        try {
            if ($r.Kind -eq 'APPX') { [void](Install-AppxDeVolta $r.Value) } else { Restore-Row $r }
            $ok++
            $r | Add-Member -NotePropertyName __feito -NotePropertyValue $true -Force
        } catch { Write-Warn "Falha ao restaurar $($r.Path)\$($r.Name)" }
    }
    $resto = @($rows | Where-Object { -not $_.__feito })
    $script:BackupCache = New-Object System.Collections.ArrayList
    foreach ($r in $resto) { [void]$script:BackupCache.Add($r) }
    if ($resto.Count -gt 0) { $resto | Select-Object Date, Module, Kind, Path, Name, Existed, ValueKind, Value, Item | Export-Csv -Path $BackupFile -NoTypeInformation -Encoding UTF8 }
    else { Remove-Item $BackupFile -Force -ErrorAction SilentlyContinue }
    $script:NeedReboot = $true
    return $ok
}

# Esquece linhas do backup sem restaurar (ex: o usuario religou a funcao na mao)
function Remove-BackupRows([scriptblock]$Filtro) {
    $resto = @($script:BackupCache | Where-Object { -not (& $Filtro $_) })
    if ($resto.Count -eq $script:BackupCache.Count) { return }
    $script:BackupCache = New-Object System.Collections.ArrayList
    foreach ($r in $resto) { [void]$script:BackupCache.Add($r) }
    if ($resto.Count -gt 0) { $resto | Select-Object Date, Module, Kind, Path, Name, Existed, ValueKind, Value, Item | Export-Csv -Path $BackupFile -NoTypeInformation -Encoding UTF8 }
    else { Remove-Item $BackupFile -Force -ErrorAction SilentlyContinue }
}

function Get-ItemNome([string]$id) {
    $it = $CATALOGO | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    if ($it) { return $it.Nome }
    if ($id -eq 'FIX') { return 'Correcoes do menu Consertar' }
    return $id
}

# ---------------------------------------------------------------------
#  Religar funcoes do Windows (independe do backup)
# ---------------------------------------------------------------------
function Get-FuncoesWindows {
    return @(
        @{ Nome = 'Impressora (servico de impressao)';         Acao = { Fix-Impressora };                                   Svc = 'Spooler' },
        @{ Nome = 'Windows Hello / leitor de digital ou rosto'; Acao = { Set-Service WbioSrvc -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service WbioSrvc -ErrorAction SilentlyContinue; Write-Ok 'Biometria ligada.' }; Svc = 'WbioSrvc' },
        @{ Nome = 'Pesquisa do Windows (achar arquivos)';      Acao = { Fix-Search };                                       Svc = 'WSearch' },
        @{ Nome = 'Xbox, Game Pass e Game Bar';                Acao = { Fix-Xbox };                                         Svc = '' },
        @{ Nome = 'Microsoft Store';                           Acao = { Fix-Store };                                        Svc = '' },
        @{ Nome = 'Bluetooth';                                 Acao = { Fix-Bluetooth };                                    Svc = '' },
        @{ Nome = 'Hibernacao e Inicializacao Rapida';         Acao = { & powercfg.exe /hibernate on; Write-Ok 'Hibernacao ligada.' }; Svc = '' },
        @{ Nome = 'Relatorios de erro do Windows';             Acao = { Set-Service WerSvc -StartupType Manual -ErrorAction SilentlyContinue; Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name Disabled -ErrorAction SilentlyContinue; Write-Ok 'Relatorios de erro ligados.' }; Svc = 'WerSvc' },
        @{ Nome = 'Apps da Loja em segundo plano (notificacoes)'; Acao = { Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name GlobalUserDisabled -Value 0 -ErrorAction SilentlyContinue; Write-Ok 'Apps em segundo plano liberados.' }; Svc = '' },
        @{ Nome = 'WSL2, Hyper-V e emuladores Android (hypervisor)'; Acao = { & bcdedit.exe /set hypervisorlaunchtype auto | Out-Null; Write-Ok 'Hypervisor ligado (vale apos reiniciar).' }; Svc = '' },
        @{ Nome = 'Integridade de memoria (Vanguard/FACEIT pedem)'; Acao = {
                New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Force | Out-Null
                Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name Enabled -Value 1 -Type DWord
                & bcdedit.exe /set hypervisorlaunchtype auto | Out-Null
                Write-Ok 'Integridade de memoria ligada (vale apos reiniciar).' }; Svc = '' }
    )
}

function Mod-ReligarFuncoes {
    $script:CurMod = 'restaurar'
    $f = Get-FuncoesWindows
    Write-Title 'RELIGAR FUNCOES DO WINDOWS'
    Write-Note 'Use se alguma coisa parou de funcionar (por este pack ou por OUTRO pack que voce usou antes).'
    Write-Host ''
    for ($i = 0; $i -lt $f.Count; $i++) { Write-Host ("  [{0,2}] {1}" -f ($i + 1), $f[$i].Nome) }
    Write-Host ''
    $op = Read-Host '  Numeros separados por virgula (ENTER volta)'
    if (-not $op) { return }
    foreach ($n in $op.Split(',')) {
        $n = $n.Trim()
        if ($n -notmatch '^\d+$' -or [int]$n -lt 1 -or [int]$n -gt $f.Count) { continue }
        $x = $f[[int]$n - 1]
        Write-Info $x.Nome
        & $x.Acao
        # se o backup guardava esse servico como "desligado" (por outro pack), esquece para o Desfazer nao desligar de novo
        if ($x.Svc) { Remove-BackupRows { param($r) $r.Kind -eq 'SVC' -and $r.Path -eq $x.Svc }.GetNewClosure() }
    }
    $script:NeedReboot = $true
}

# ---------------------------------------------------------------------
#  Menu principal da restauracao
# ---------------------------------------------------------------------
function Mod-Restaurar {
    $script:CurMod = 'restaurar'
    while ($true) {
        Write-Title 'DESFAZER E RESTAURAR'
        $n = @($script:BackupCache).Count
        $apps = @($script:BackupCache | Where-Object { $_.Kind -eq 'APPX' })
        if ($n -gt 0) { Write-Note "O pack tem $n ajuste(s) guardado(s) que podem ser desfeitos ($($apps.Count) app(s) removido(s))." }
        else { Write-Note 'Nenhum ajuste do pack ativo neste PC.' }
        Write-Host ''
        Write-Host '  [1] DESFAZER TUDO' -ForegroundColor Red
        Write-Note '    Volta cada ajuste ao valor exato que este PC tinha antes do AVANTIPACK.'
        Write-Host '  [2] RECOLOCAR UMA FUNCAO QUE VOCE USA' -ForegroundColor Cyan
        Write-Note '    Escolhe so o que voltar (ex: impressora, gravar clipes, transparencia, hibernacao).'
        Write-Host '  [3] REINSTALAR APPS QUE O PACK REMOVEU' -ForegroundColor Cyan
        Write-Host '  [4] RELIGAR FUNCOES DO WINDOWS' -ForegroundColor Cyan
        Write-Note '    Impressora, Windows Hello, Store, Xbox, Bluetooth, WSL... mesmo se outro pack desligou.'
        Write-Host '  [5] Voltar o Windows inteiro pelo ponto de restauracao'
        Write-Host '  [6] Desfazer por parte do pack (avancado)'
        Write-Host '  [0] Voltar'
        Write-Host ''
        $op = Read-Host '  Escolha'
        switch ($op) {
            '1' {
                if ($n -eq 0) { Write-Skip 'Nada para desfazer.'; break }
                $semApps = $true
                if ($apps.Count -gt 0) { $semApps = -not (Confirm-Step "Reinstalar tambem os $($apps.Count) app(s) removido(s)?") }
                if (-not (Confirm-Step 'Desfazer TUDO que o AVANTIPACK fez neste PC?')) { break }
                $q = Invoke-RestoreRows { param($r) $true } -SemApps:$semApps
                Write-Caixa @("$q ajuste(s) voltaram ao original.", 'Reinicie o PC para concluir (opcao 8 do menu).') 'Green'
            }
            '2' {
                $itens = @($script:BackupCache | Where-Object { $_.Item -and $_.Kind -ne 'APPX' } | Group-Object Item | Sort-Object Name)
                if ($itens.Count -eq 0) { Write-Skip 'Nada para recolocar (ou os ajustes foram feitos por uma versao antiga do pack: use a opcao 6).'; break }
                Write-Host ''
                for ($i = 0; $i -lt $itens.Count; $i++) {
                    $id = $itens[$i].Name
                    $txt = if ($VOLTA.ContainsKey($id)) { $VOLTA[$id] } else { Get-ItemNome $id }
                    Write-Host ("  [{0,2}] {1}" -f ($i + 1), $txt) -ForegroundColor White
                    Write-Host ("        ajuste {0}: {1}" -f $id, (Get-ItemNome $id)) -ForegroundColor DarkGray
                }
                Write-Host ''
                $sel = Read-Host '  Numeros do que voce quer de volta (ex: 1,4)  |  ENTER volta'
                if (-not $sel) { break }
                $ids = @()
                foreach ($x in $sel.Split(',')) { $x = $x.Trim(); if ($x -match '^\d+$' -and [int]$x -ge 1 -and [int]$x -le $itens.Count) { $ids += $itens[[int]$x - 1].Name } }
                if ($ids.Count -eq 0) { break }
                $q = Invoke-RestoreRows { param($r) $ids -contains $r.Item -and $r.Kind -ne 'APPX' }.GetNewClosure()
                foreach ($id in $ids) { Write-Ok $(if ($VOLTA.ContainsKey($id)) { $VOLTA[$id] } else { Get-ItemNome $id }) }
                Write-Note "$q valor(es) restaurado(s). Algumas coisas so voltam depois de reiniciar."
            }
            '3' {
                if ($apps.Count -eq 0) { Write-Skip 'O pack nao removeu nenhum app (ou foi uma versao antiga: reinstale pela Microsoft Store).'; break }
                for ($i = 0; $i -lt $apps.Count; $i++) { Write-Host ("  [{0,2}] {1}" -f ($i + 1), (Get-AppxNome $apps[$i].Value)) }
                Write-Host ''
                $sel = Read-Host '  Numeros dos apps (ex: 1,3)  |  T = todos  |  ENTER volta'
                if (-not $sel) { break }
                $nomes = if ($sel -match '^[tT]$') { @($apps | ForEach-Object { $_.Value }) } else {
                    @($sel.Split(',') | ForEach-Object { $x = $_.Trim(); if ($x -match '^\d+$' -and [int]$x -ge 1 -and [int]$x -le $apps.Count) { $apps[[int]$x - 1].Value } }) }
                [void](Invoke-RestoreRows { param($r) $r.Kind -eq 'APPX' -and $nomes -contains $r.Value }.GetNewClosure())
            }
            '4' { Mod-ReligarFuncoes }
            '5' {
                Write-Note 'Vai abrir a Restauracao do Sistema do Windows. Escolha o ponto "AVANTIPACK" com a data.'
                Write-Note 'Isso volta TUDO do Windows para aquele dia (programas instalados depois podem sumir).'
                if (Confirm-Step 'Abrir agora?') { Start-Process rstrui.exe }
            }
            '6' { Mod-Undo }
            default { return }
        }
        Write-Host ''
        Read-Host '  ENTER para continuar' | Out-Null
    }
}
