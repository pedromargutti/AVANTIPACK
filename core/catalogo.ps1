# =====================================================================
#  AVANTIPACK - catalogo de ajustes, modo Automatico/Personalizado
#  e teste de input lag.
#  Para ADICIONAR um ajuste: crie o bloco "if (Want 'XX') { ... }" no
#  modulo (modulos.ps1/gpu.ps1) e uma linha aqui no $CATALOGO.
#  Padrao = $true entra no Automatico. Risco = 'alto' nunca entra.
#  Carregado por avanti.ps1 (dot-source). Sem acentos de proposito.
# =====================================================================

$CATEGORIAS = [ordered]@{
    S = 'Seguranca (backup)'
    B = 'Limpeza e privacidade'
    C = 'Sistema e input lag'
    D = 'Energia e processador'
    E = 'Placa de video e monitor'
    F = 'Internet'
    G = 'SSD/HD e memoria'
    H = 'Jogos'
    I = 'Avancado (com riscos)'
}

# Cond: quando o ajuste faz sentido para o PC ($h = hardware detectado)
$CATALOGO = @(
    @{ Id='S1'; Cat='S'; Padrao=$true;  Nome='Ponto de restauracao + backup do registro'; Desc='Cria um ponto para voltar o Windows inteiro, se precisar.' }

    @{ Id='B1'; Cat='B'; Padrao=$true;  Nome='Telemetria e coleta de dados';            Desc='Menos envio de dados para a Microsoft; desliga 2 servicos e 8 tarefas de coleta.' }
    @{ Id='B2'; Cat='B'; Padrao=$true;  Nome='Anuncios e apps que se instalam sozinhos'; Desc='Tira sugestoes, propaganda, Bing no menu Iniciar e instalacao automatica de apps.' }
    @{ Id='B3'; Cat='B'; Padrao=$true;  Nome='Widgets, Recall, Copilot e destaques';     Desc='Menos processos rodando no fundo.' }
    @{ Id='B4'; Cat='B'; Padrao=$true;  Nome='Gravacao do Xbox em segundo plano';        Desc='Para de gravar o jogo sem parar. A Game Bar continua.' }
    @{ Id='B5'; Cat='B'; Padrao=$true;  Nome='Relatorios de erro';                       Desc='Para de enviar/gerar relatorios depois de travamentos.' }
    @{ Id='B6'; Cat='B'; Padrao=$true;  Nome='Remover apps inuteis pre-instalados';      Desc='Noticias, Clima, Solitaire, Dicas, Clipchamp... (Loja/Xbox/Fotos ficam). Nao entra no Desfazer.' }
    @{ Id='B7'; Cat='B'; Padrao=$true;  Nome='Edge e Chrome nao ficam rodando no fundo'; Desc='Ao fechar o navegador ele fecha de verdade (libera RAM/CPU para o jogo).' }
    @{ Id='B8'; Cat='B'; Padrao=$true;  Nome='Biometria so quando precisar';             Desc='Servico de digital/rosto em manual.'; Cond={ param($h) -not @(Get-PnpDevice -Class Biometric -PresentOnly -ErrorAction SilentlyContinue).Count } }
    @{ Id='B9'; Cat='B'; Padrao=$false; Nome='Bloquear apps da Loja em segundo plano';   Desc='Economiza RAM, mas apps da Loja (ex: WhatsApp) podem parar de notificar.' }
    @{ Id='B10'; Cat='B'; Padrao=$false; Nome='Desligar servico de impressao';           Desc='So aparece se nao houver impressora instalada.'; Cond={ param($h) -not @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'PDF|XPS|OneNote|Fax|Send To|Enviar para|AnyDesk|Root Print' }).Count } }
    @{ Id='B11'; Cat='B'; Padrao=$false; Nome='Desligar indexacao da pesquisa';          Desc='Alivia o HD. A busca de arquivos fica mais lenta.'; Cond={ param($h) $h.DISK -eq 'HDD' } }
    @{ Id='B12'; Cat='B'; Padrao=$false; Nome='Escolher programas que iniciam com o Windows'; Desc='Abre a lista para voce desligar o que nao precisa abrir sozinho.' }

    @{ Id='C1'; Cat='C'; Padrao=$true;  Nome='Mouse sem aceleracao (1:1)';               Desc='A mira anda sempre igual a sua mao.' }
    @{ Id='C2'; Cat='C'; Padrao=$true;  Nome='Teclado mais rapido, sem atalho do Shift 5x'; Desc='Repeticao rapida e sem a janela de Teclas de Aderencia no meio do jogo.' }
    @{ Id='C3'; Cat='C'; Padrao=$true;  Nome='Modo de Jogo do Windows';                  Desc='Prioriza o jogo e segura atualizacoes durante a partida.' }
    @{ Id='C4'; Cat='C'; Padrao=$true;  Nome='Prioridade multimidia para jogos (MMCSS)'; Desc='Mais CPU/GPU/disco para jogos e menos reserva para tarefas de fundo.' }
    @{ Id='C5'; Cat='C'; Padrao=$true;  Nome='Mais forca para o programa na tela';       Desc='Win32PrioritySeparation 0x26: o jogo em primeiro plano recebe mais CPU.' }
    @{ Id='C6'; Cat='C'; Padrao=$true;  Nome='Visual leve';                              Desc='Sem animacoes e transparencia; menus e inicializacao sem atraso.' }
    @{ Id='C7'; Cat='C'; Padrao=$true;  Nome='Jogos em janela com latencia de tela cheia'; Desc='Otimizacao do Windows 11 para jogos DX10/11 em janela sem borda.'; Cond={ param($h) $h.WIN11 -eq '1' } }
    @{ Id='C8'; Cat='C'; Padrao=$true;  Nome='Corrigir timer HPET forcado';              Desc='Remove um tweak antigo que AUMENTA a latencia (so mexe se estiver ligado).' }
    @{ Id='C9'; Cat='C'; Padrao=$true;  Nome='USB, mouse, teclado e rede sem economia';  Desc='Os dispositivos nunca "dormem" para economizar energia.' }

    @{ Id='D1'; Cat='D'; Padrao=$true;  Nome='Plano de energia certo para o processador'; Desc='Desktop: sem core parking e boost agressivo. Ryzen X3D 2 CCDs: Balanceado. Notebook: Melhor desempenho.' }
    @{ Id='D2'; Cat='D'; Padrao=$true;  Nome='Sem limitar programas em segundo plano';   Desc='Power Throttling desligado (Discord/OBS nao perdem forca).'; Cond={ param($h) $h.LAPTOP -ne '1' } }

    @{ Id='E1'; Cat='E'; Padrao=$true;  Nome='Monitor na taxa maxima (Hz)';              Desc='Se o monitor de 144 Hz estiver em 60 Hz, corrige.' }
    @{ Id='E2'; Cat='E'; Padrao=$true;  Nome='Agendamento de GPU por hardware (HAGS)';   Desc='Tira carga do processador; obrigatorio para DLSS Frame Generation.'; Cond={ param($h) @('NVIDIA','AMD','INTEL_ARC') -contains $h.GPU_VENDOR } }
    @{ Id='E3'; Cat='E'; Padrao=$true;  Nome='Configurar o painel NVIDIA/AMD sozinho';   Desc='Baixa latencia, filtragem de textura rapida, cache de shader, energia, V-Sync certo.'; Cond={ param($h) $h.GPU_VENDOR -eq 'NVIDIA' -or $h.GPU_VENDOR -like 'AMD*' } }
    @{ Id='E4'; Cat='E'; Padrao=$false; Nome='Desligar MPO';                             Desc='So para quem tem tela piscando/travando no alt+tab. Tira a otimizacao de janela do Win11.' }

    @{ Id='F1'; Cat='F'; Padrao=$true;  Nome='Pacotes do jogo saem na hora (Nagle off)'; Desc='Ajuda em jogos que usam TCP. Nao atrapalha downloads.' }
    @{ Id='F2'; Cat='F'; Padrao=$true;  Nome='Placa de rede cabeada sem economia';       Desc='Desliga Green Ethernet/EEE, que causam picos de ping. O Wi-Fi nao e alterado.' }
    @{ Id='F3'; Cat='F'; Padrao=$true;  Nome='Windows Update sem usar sua internet';     Desc='Para de enviar atualizacoes para outros PCs pela sua conexao.' }
    @{ Id='F4'; Cat='F'; Padrao=$true;  Nome='Consertar ajustes de rede de outros packs'; Desc='Volta o TCP e o RSS para o padrao se algum pack os desligou (deixa download lento).' }
    @{ Id='F5'; Cat='F'; Padrao=$true;  Nome='DNS mais rapido';                          Desc='Testa DNS atual, Cloudflare, Google e Quad9 e so troca se valer a pena.' }

    @{ Id='G1'; Cat='G'; Padrao=$true;  Nome='SSD/HD com os ajustes certos';             Desc='SSD: TRIM e menos escrita. HD: pre-carregamento e desfragmentacao ligados.' }
    @{ Id='G2'; Cat='G'; Padrao=$true;  Nome='Desligar hibernacao';                      Desc='Libera alguns GB e o PC liga "limpo".'; Cond={ param($h) $h.LAPTOP -ne '1' } }
    @{ Id='G3'; Cat='G'; Padrao=$true;  Nome='Desligar compressao de memoria';           Desc='Com 32 GB ou mais ela so gasta CPU.'; Cond={ param($h) [int]$h.RAM_GB -ge 32 } }
    @{ Id='G4'; Cat='G'; Padrao=$true;  Nome='Arquivo de paginacao ligado';              Desc='Se outro pack desligou, religa (sem ele, jogos fecham sozinhos).' }
    @{ Id='G5'; Cat='G'; Padrao=$true;  Nome='Limpar arquivos temporarios';              Desc='Temporarios, dumps, cache de shader e downloads do Windows Update.' }

    @{ Id='H1'; Cat='H'; Padrao=$true;  Nome='Prioridade alta para os jogos instalados'; Desc='Procura seus jogos (Steam, Epic, Riot...) e da mais CPU a eles quando abrem.' }
    @{ Id='H3'; Cat='H'; Padrao=$true;  Nome='Jogos na placa de video dedicada (notebook)'; Desc='Em PC com 2 placas (integrada + dedicada), obriga cada jogo a usar a dedicada.'; Cond={ param($h) $h.GPU_HIBRIDA -eq '1' } }
    @{ Id='H2'; Cat='H'; Padrao=$true;  Nome='Perfil NVIDIA turbo nos jogos competitivos'; Desc='So nos competitivos instalados (CS2, Valorant, Fortnite...): baixa latencia ULTRA e clock maximo.'; Cond={ param($h) $h.GPU_VENDOR -eq 'NVIDIA' } }

    @{ Id='I1'; Cat='I'; Padrao=$false; Risco='alto'; Nome='Desligar Integridade de memoria (VBS)'; Desc='Mais FPS em CPUs fracas. Menos seguranca; Vanguard/FACEIT podem exigir ligada.' }
    @{ Id='I2'; Cat='I'; Padrao=$false; Risco='alto'; Nome='Modo MSI na placa de video';  Desc='Menos latencia de interrupcao. A maioria das placas atuais ja usa.' }
    @{ Id='I3'; Cat='I'; Padrao=$false; Risco='alto'; Nome='Timer resolution global';     Desc='So serve se voce usar um app de timer resolution.'; Cond={ param($h) $h.WIN11 -eq '1' } }
    @{ Id='I4'; Cat='I'; Padrao=$false; Risco='alto'; Nome='Desligar FSO em todos os jogos'; Desc='Pode ajudar jogos DX9/DX11 antigos; pode atrapalhar alt+tab e HDR.' }
    @{ Id='I5'; Cat='I'; Padrao=$false; Risco='alto'; Nome='Desligar o hypervisor';       Desc='Pode dar FPS extra; quebra WSL2, Hyper-V, Area Restrita e alguns emuladores.' }
)

$script:CondCache = @{}
function Test-ItemAplica($item, $hw) {
    if (-not $item.Cond) { return $true }
    if ($script:CondCache.ContainsKey($item.Id)) { return $script:CondCache[$item.Id] }
    $r = $true
    try { $r = [bool](& $item.Cond $hw) } catch { $r = $true }
    $script:CondCache[$item.Id] = $r
    return $r
}

function Get-DefaultSelection($hw) {
    $sel = @{}
    foreach ($it in $CATALOGO) { $sel[$it.Id] = ($it.Padrao -and (Test-ItemAplica $it $hw)) }
    return $sel
}

function Show-Categoria([string]$cat, $sel, $hw) {
    Write-Title ("CATEGORIA: " + $CATEGORIAS[$cat].ToUpper())
    Write-Note 'Marque o que quer aplicar. Amarelo = tem risco (leia a explicacao). Cinza = nao serve para este PC.'
    Write-Host ''
    $its = @($CATALOGO | Where-Object { $_.Cat -eq $cat })
    $itens = foreach ($it in $its) {
        $ap = Test-ItemAplica $it $hw
        $extra = if (-not $ap) { ' (nao se aplica a este PC)' } elseif ($it.Risco -eq 'alto') { ' (RISCO: leia antes)' } else { '' }
        @{ K = $it.Id; T = $it.Nome; D = ($it.Desc + $extra); On = ($ap -and [bool]$sel[$it.Id]); Bloq = (-not $ap)
           C = $(if ($ap -and $it.Risco -eq 'alto') { 'Yellow' } else { $null }) }
    }
    $r = Select-Varios @($itens) -Concluir 'PRONTO, voltar para as categorias'
    if ($null -eq $r) { return }
    foreach ($it in $its) { $sel[$it.Id] = (@($r) -contains $it.Id) }
}

function Mod-Escolher($hw) {
    $sel = Get-DefaultSelection $hw
    $ultimo = 0
    while ($true) {
        Write-Title 'PERSONALIZADO: ESCOLHA O QUE APLICAR'
        Write-Note 'Ja vem marcado o mesmo que o modo Automatico. Entre numa categoria para marcar ou tirar itens.'
        Write-Host ''
        $k = 1; $mapa = @{}; $op = @()
        foreach ($c in $CATEGORIAS.Keys) {
            $its = @($CATALOGO | Where-Object { $_.Cat -eq $c -and (Test-ItemAplica $_ $hw) })
            $on = @($its | Where-Object { $sel[$_.Id] }).Count
            $op += @{ K = "$k"; T = ("{0,-32} {1,2} de {2,2} marcados" -f $CATEGORIAS[$c], $on, $its.Count); C = $(if ($c -eq 'I') { 'Yellow' } else { 'White' }) }
            $mapa["$k"] = $c; $k++
        }
        $op += @{ K = 'A'; T = 'APLICAR o que esta marcado'; C = 'Green' }
        $op += @{ K = 'P'; T = 'Voltar ao padrao recomendado'; C = 'Gray' }
        $r = Select-Opcao $op -Voltar 'Cancelar' -Inicio $ultimo
        if ($r -eq '0') { return $null }
        if ($r -eq 'A') { return $sel }
        if ($r -eq 'P') { $sel = Get-DefaultSelection $hw; continue }
        if ($mapa.ContainsKey($r)) { $ultimo = [int]$r - 1; Show-Categoria $mapa[$r] $sel $hw }
    }
}

function Show-Resumo($sel) {
    foreach ($c in $CATEGORIAS.Keys) {
        $its = @($CATALOGO | Where-Object { $_.Cat -eq $c -and $sel[$_.Id] })
        if ($its.Count -eq 0) { continue }
        Write-Host ("  {0}:" -f $CATEGORIAS[$c]) -ForegroundColor White
        foreach ($it in $its) { Write-Host ("     + {0}" -f $it.Nome) -ForegroundColor Gray }
    }
}

# Roda a selecao na ordem certa
function Invoke-Selecao($sel) {
    $script:Selecao = $sel
    $script:AutoMode = $true
    $etapas = @(
        @{ N = 'Backup e ponto de restauracao'; Ok = $sel['S1'];                          F = { Mod-Restore } },
        @{ N = 'Limpeza e privacidade';         Ok = (WantAny @('B1','B2','B3','B4','B5','B6','B7','B8','B9','B10','B11')); F = { Mod-Debloat } },
        @{ N = 'Programas da inicializacao';    Ok = $sel['B12'];                         F = { $script:AutoMode = $false; Mod-Inicializacao; $script:AutoMode = $true } },
        @{ N = 'Sistema e input lag';           Ok = (WantAny @('C1','C2','C3','C4','C5','C6','C7','C8','C9')); F = { Mod-Sistema } },
        @{ N = 'Energia e processador';         Ok = (WantAny @('D1','D2'));              F = { Mod-Energia } },
        @{ N = 'Placa de video e monitor';      Ok = (WantAny @('E1','E2','E3','E4'));    F = { Mod-GPU } },
        @{ N = 'Internet';                      Ok = (WantAny @('F1','F2','F3','F4','F5')); F = { Mod-Rede } },
        @{ N = 'SSD/HD e memoria';              Ok = (WantAny @('G1','G2','G3','G4','G5')); F = { Mod-Armazenamento } },
        @{ N = 'Jogos instalados';              Ok = ($sel['H1'] -or $sel['H2'] -or $sel['H3']); F = { if ($sel['H1']) { Invoke-AutoGames }; if ($sel['H3']) { Invoke-GpuDedicada }; if ($sel['H2']) { Optimize-NvidiaGameProfiles (Load-HW) } } },
        @{ N = 'Ajustes avancados';             Ok = (WantAny @('I1','I2','I3','I4','I5')); F = { Mod-Avancado } }
    )
    $ativas = @($etapas | Where-Object { $_.Ok })
    try {
        for ($i = 0; $i -lt $ativas.Count; $i++) {
            Write-Etapa ($i + 1) $ativas.Count $ativas[$i].N
            & $ativas[$i].F
        }
    } finally {
        $script:Selecao = $null
        $script:AutoMode = $false
    }
}

function Mod-Otimizar {
    $hw = Load-HW
    Write-Title 'OTIMIZAR MEU PC'
    Write-Host '  Como voce quer fazer?' -ForegroundColor White
    Write-Host ''
    $ult = Get-UltimaSelecao
    $op = @(
        @{ K = '1'; T = 'AUTOMATICO (recomendado)'; C = 'Green'; D = 'O pack escolhe tudo que e seguro e serve para ESTE PC.' },
        @{ K = '2'; T = 'PERSONALIZADO'; D = 'Voce ve cada ajuste por categoria e marca ou desmarca o que quiser.' }
    )
    if ($ult) {
        $dr = if (Test-PrecisaReaplicar) { 'O Windows foi atualizado: recomendado reaplicar.' } else { 'Use depois de atualizacoes grandes do Windows.' }
        $op += @{ K = '3'; T = 'REAPLICAR o que eu escolhi da ultima vez'; C = 'Yellow'; D = $dr }
    }
    $ini = if ($ult -and (Test-PrecisaReaplicar)) { 2 } else { 0 }
    $r = Select-Opcao $op -Inicio $ini
    switch ($r) {
        '1' { $sel = Get-DefaultSelection $hw }
        '2' { $sel = Mod-Escolher $hw; if (-not $sel) { return } }
        '3' { if ($ult) { Mod-Reaplicar }; return }
        default { return }
    }
    Write-Title 'VAI SER APLICADO'
    Show-Resumo $sel
    Write-Host ''
    Write-Note 'Tudo (menos os apps removidos) volta ao original pela opcao 6 (Desfazer).'
    if ($hw.GPU_VENDOR -eq 'NVIDIA' -and $sel['E3']) { Write-Note 'Vai aparecer UMA pergunta: se o seu monitor tem G-SYNC/FreeSync.' }
    Write-Note 'Leva de 2 a 5 minutos. Nao feche esta janela.'
    if (-not (Confirm-Step 'Pode comecar?')) { return }
    $script:Applied = 0; $script:Avisos = 0
    Invoke-Selecao $sel
    Save-UltimaSelecao $sel
    $avisosRun = $script:Avisos
    Write-Title 'RESULTADO'
    Show-Hardware (Load-HW)
    Write-Host ''
    Write-Caixa @(
        'OTIMIZACAO CONCLUIDA!',
        '',
        ("Ajustes aplicados ......... {0}" -f $script:Applied),
        ("Avisos para voce ver ...... {0}" -f $avisosRun),
        '',
        'Tudo pode ser desfeito pela opcao 6 do menu.',
        'Alertas de BIOS (XMP etc.): veja a opcao 5, Guias.'
    ) 'Green'
    Write-Host ''
    Write-Host '  REINICIE O PC para tudo comecar a valer.' -ForegroundColor Black -BackgroundColor Yellow
    if (Confirm-Step 'Reiniciar agora?') { & shutdown.exe /r /t 10 /c 'AVANTIPACK: reiniciando para aplicar as otimizacoes'; Write-Ok 'O PC vai reiniciar em 10 segundos.' }
    $script:NeedReboot = $false
}

# ---------------------------------------------------------------------
#  TESTE DE INPUT LAG (checklist competitivo)
# ---------------------------------------------------------------------
function Get-TimerResolutionMs {
    if (-not ('AvTimer' -as [type])) {
        Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class AvTimer { [DllImport("ntdll.dll")] public static extern int NtQueryTimerResolution(out uint min, out uint max, out uint cur); }'
    }
    $a = 0; $b = 0; $c = 0
    [void][AvTimer]::NtQueryTimerResolution([ref]$a, [ref]$b, [ref]$c)
    return [math]::Round($c / 10000.0, 3)
}

function Get-PowerIndex([string]$Sub, [string]$Setting) {
    $o = & powercfg.exe /query SCHEME_CURRENT $Sub $Setting 2>$null
    $m = [regex]::Matches(($o -join "`n"), ':\s*0x([0-9a-fA-F]{8})')
    if ($m.Count -ge 2) { return [Convert]::ToInt32($m[$m.Count - 2].Groups[1].Value, 16) }
    return $null
}

function Test-InputLag {
    $hw = Load-HW
    Write-Title 'TESTE DE INPUT LAG (CHECKLIST COMPETITIVO)'
    $res = @()
    function Add-R($nome, $ok, $fix, $info) { $script:__r += , [pscustomobject]@{ Nome = $nome; Ok = $ok; Fix = $fix; Info = $info } }
    $script:__r = @()

    try {
        $mons = @(Get-Monitors)
        $ruim = @($mons | Where-Object { $_.HzMax -gt ($_.HzAtual + 1) })
        Add-R 'Monitor na taxa de atualizacao maxima' ($ruim.Count -eq 0) 'E1' ($(if ($ruim) { "$($ruim[0].HzAtual) Hz, suporta $($ruim[0].HzMax) Hz" } else { (($mons | ForEach-Object { "$($_.HzAtual) Hz" }) -join ', ') }))
    } catch {}
    $ms = (Get-ItemProperty 'HKCU:\Control Panel\Mouse' -ErrorAction SilentlyContinue).MouseSpeed
    Add-R 'Mouse sem aceleracao' ($ms -eq '0') 'C1' ''
    $gm = (Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -ErrorAction SilentlyContinue).AutoGameModeEnabled
    Add-R 'Modo de Jogo ligado' ($gm -ne 0) 'C3' ''
    $dvr = (Get-ItemProperty 'HKCU:\System\GameConfigStore' -ErrorAction SilentlyContinue).GameDVR_Enabled
    Add-R 'Sem gravacao em segundo plano' ($dvr -eq 0) 'B4' ''
    if (@('NVIDIA', 'AMD', 'INTEL_ARC') -contains $hw.GPU_VENDOR) {
        $hags = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -ErrorAction SilentlyContinue).HwSchMode
        Add-R 'Agendamento de GPU por hardware (HAGS)' ($hags -eq 2) 'E2' ''
    }
    if ($hw.WIN11 -eq '1') {
        $dx = [string](Get-ItemProperty 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
        Add-R 'Jogos em janela com latencia de tela cheia' ($dx -match 'SwapEffectUpgradeEnable=1') 'C7' ''
    }
    $mm = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -ErrorAction SilentlyContinue
    $gp = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' -ErrorAction SilentlyContinue
    Add-R 'Prioridade multimidia para jogos (MMCSS)' (($mm.SystemResponsiveness -le 10) -and ($gp.Priority -eq 6)) 'C4' ''
    $wps = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' -ErrorAction SilentlyContinue).Win32PrioritySeparation
    Add-R 'Mais CPU para o programa na tela' ($wps -eq 0x26) 'C5' ''
    $act = Get-ActiveScheme
    $planoOk = if ($hw.CPU_X3D_DUAL -eq '1') { $act -eq $BALANCED_GUID } elseif ($hw.LAPTOP -eq '1') { $true } else { @($AV_GUID, $ULTIMATE_GUID, $HIGHPERF_GUID) -contains $act }
    Add-R 'Plano de energia certo para o processador' $planoOk 'D1' ''
    $usb = Get-PowerIndex '2a737441-1930-4402-8d77-b2bebba308a3' '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
    if ($usb -ne $null) { Add-R 'USB sem suspensao seletiva (plano)' ($usb -eq 0) 'D1' '' }
    $pm = @(Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable -ErrorAction SilentlyContinue | Where-Object { $_.Enable -and $_.InstanceName -match '^(USB|HID)\\' })
    Add-R 'Mouse/teclado/USB sem economia de energia' ($pm.Count -eq 0) 'C9' ($(if ($pm.Count) { "$($pm.Count) dispositivo(s) ainda economizando" } else { '' }))
    $bcd = (& bcdedit.exe /enum '{current}' 2>$null) -join "`n"
    Add-R 'Timer HPET nao forcado' (-not ($bcd -match 'useplatformclock\s+(Yes|Sim|True)')) 'C8' ''
    $edge = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -ErrorAction SilentlyContinue).BackgroundModeEnabled
    Add-R 'Navegador nao fica rodando no fundo' ($edge -eq 0) 'B7' ''
    $ads = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
    $nagle = $true
    foreach ($a in $ads) {
        $v = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($a.InterfaceGuid)" -ErrorAction SilentlyContinue).TcpAckFrequency
        if ($v -ne 1) { $nagle = $false }
    }
    if ($ads.Count) { Add-R 'Pacotes de rede saem na hora (Nagle off)' $nagle 'F1' '' }
    $wifi = @($ads | Where-Object { $_.MediaType -match '802\.11' -or $_.InterfaceDescription -match 'Wi-?Fi|Wireless|WLAN' })
    if ($ads.Count) { Add-R 'Internet no cabo (nao Wi-Fi)' ($wifi.Count -eq 0 -or $wifi.Count -lt $ads.Count) '' ($(if ($wifi.Count -eq $ads.Count) { 'Wi-Fi tem ping menos estavel; use cabo se puder' } else { '' })) }
    $al = @(Get-Alerts $hw | Where-Object { $_ -match 'XMP|EXPO|single channel|pente' })
    Add-R 'Memoria RAM na velocidade certa (XMP/EXPO, dual channel)' ($al.Count -eq 0) '' ($(if ($al) { 'ver Guia de BIOS (opcao 5)' } else { '' }))

    # Informativos
    $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
    $hvci = $dg -and (@($dg.SecurityServicesRunning) -contains 2)
    $tr = $null; try { $tr = Get-TimerResolutionMs } catch {}

    $ok = 0
    foreach ($r in $script:__r) {
        if ($r.Ok) { $ok++; Write-Host ("  [OK] {0}" -f $r.Nome) -ForegroundColor Green }
        else { Write-Host ("  [!]  {0}" -f $r.Nome) -ForegroundColor Yellow }
        if ($r.Info) { Write-Host ("       {0}" -f $r.Info) -ForegroundColor DarkGray }
    }
    Write-Host ''
    Write-Host ("  [i]  Integridade de memoria: {0}" -f $(if ($hvci) { 'LIGADA (custa alguns % de FPS; desligar e opcional no Avancado, com riscos)' } else { 'desligada' })) -ForegroundColor Gray
    if ($tr) { Write-Host ("  [i]  Timer do sistema agora: {0} ms (os jogos pedem o que precisam sozinhos)" -f $tr) -ForegroundColor Gray }
    Write-Host '  [i]  O que nenhum script mede: polling do mouse (use 1000 Hz+), Reflex/Anti-Lag no jogo e limite de FPS.' -ForegroundColor Gray
    Write-Host ''
    $total = $script:__r.Count
    $cor = if ($ok -eq $total) { 'Green' } elseif ($ok -ge $total - 3) { 'Yellow' } else { 'Red' }
    Write-Host ("  PONTUACAO: {0} de {1}" -f $ok, $total) -ForegroundColor $cor
    $fixes = @($script:__r | Where-Object { -not $_.Ok -and $_.Fix } | ForEach-Object { $_.Fix } | Sort-Object -Unique)
    if ($fixes.Count -gt 0) {
        Write-Host ''
        if (Confirm-Step 'Corrigir agora os itens com [!] que o pack consegue resolver?') {
            $sel = @{}; foreach ($f in $fixes) { $sel[$f] = $true }
            Invoke-Selecao $sel
            Write-Host ''
            Write-Note 'Reinicie o PC e rode este teste de novo para ver a nova pontuacao.'
            $script:NeedReboot = $true
        }
    }
}
