# =====================================================================
#  AVANTIPACK - catalogo de ajustes do modo Automatico.
#  Para ADICIONAR um ajuste: crie o bloco "if (Want 'XX') { ... }" no
#  modulo (modulos.ps1/gpu.ps1) e uma linha aqui no $CATALOGO.
#  Padrao = $true entra no Automatico. Risco = 'alto' nunca entra.
#  Carregado por avanti.ps1 (dot-source). Sem acentos de proposito.
# =====================================================================

$CATEGORIAS = [ordered]@{
    S = 'Backup e restauracao'
    B = 'Privacidade e segundo plano'
    C = 'Latencia e resposta do sistema'
    D = 'Energia e processador'
    E = 'Video e monitor'
    F = 'Rede'
    G = 'Armazenamento e memoria'
}

# Cond: quando o ajuste faz sentido para o PC ($h = hardware detectado)
$CATALOGO = @(
    @{ Id='S1'; Cat='S'; Padrao=$true;  Nome='Criar ponto de restauracao e copia do registro'; Desc='Cria um ponto para voltar o Windows inteiro, se precisar.' }

    @{ Id='B1'; Cat='B'; Padrao=$true;  Nome='Reduzir telemetria e coleta de dados';            Desc='Menos envio de dados para a Microsoft; desliga 2 servicos e 8 tarefas de coleta.' }
    @{ Id='B2'; Cat='B'; Padrao=$true;  Nome='Desativar anuncios e instalacao automatica de apps'; Desc='Tira sugestoes, propaganda, Bing no menu Iniciar e instalacao automatica de apps.' }
    @{ Id='B3'; Cat='B'; Padrao=$true;  Nome='Desativar Widgets, Recall e Copilot';     Desc='Menos processos rodando no fundo.' }
    @{ Id='B4'; Cat='B'; Padrao=$true;  Nome='Desativar gravacao do Xbox em segundo plano';        Desc='Para de gravar o jogo sem parar. A Game Bar continua.' }
    @{ Id='B5'; Cat='B'; Padrao=$true;  Nome='Desativar relatorios de erro';                       Desc='Para de enviar/gerar relatorios depois de travamentos.' }
    @{ Id='B6'; Cat='B'; Padrao=$true;  Nome='Remover apps pre-instalados desnecessarios';      Desc='Noticias, Clima, Solitaire, Dicas, Clipchamp... (Loja/Xbox/Fotos/Teams/Outlook ficam). Voltam pelo Desfazer > Reinstalar apps.' }
    @{ Id='B7'; Cat='B'; Padrao=$true;  Nome='Impedir Edge e Chrome em segundo plano'; Desc='Ao fechar o navegador ele fecha de verdade (libera RAM/CPU para o jogo).' }
    @{ Id='B8'; Cat='B'; Padrao=$true;  Nome='Iniciar biometria somente quando necessario';             Desc='Servico de digital/rosto em manual.'; Cond={ param($h) -not @(Get-PnpDevice -Class Biometric -PresentOnly -ErrorAction SilentlyContinue).Count } }
    @{ Id='B9'; Cat='B'; Padrao=$false; Nome='Restringir apps da Loja em segundo plano';   Desc='Economiza RAM, mas apps da Loja (ex: WhatsApp) podem parar de notificar.' }
    @{ Id='B10'; Cat='B'; Padrao=$false; Nome='Desativar servico de impressao';           Desc='So aparece se nao houver impressora instalada.'; Cond={ param($h) -not @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'PDF|XPS|OneNote|Fax|Send To|Enviar para|AnyDesk|Root Print' }).Count } }
    @{ Id='B11'; Cat='B'; Padrao=$false; Nome='Desativar indexacao da pesquisa';          Desc='Alivia o HD. A busca de arquivos fica mais lenta.'; Cond={ param($h) $h.DISK -eq 'HDD' } }

    @{ Id='C1'; Cat='C'; Padrao=$true;  Nome='Desativar aceleracao do mouse (1:1)';               Desc='A mira anda sempre igual a sua mao.' }
    @{ Id='C2'; Cat='C'; Padrao=$true;  Nome='Acelerar resposta do teclado'; Desc='Repeticao rapida e sem a janela de Teclas de Aderencia no meio do jogo.' }
    @{ Id='C3'; Cat='C'; Padrao=$true;  Nome='Ativar Modo de Jogo do Windows';                  Desc='Prioriza o jogo e segura atualizacoes durante a partida.' }
    @{ Id='C4'; Cat='C'; Padrao=$true;  Nome='Priorizar jogos no agendador multimidia (MMCSS)'; Desc='Mais CPU/GPU/disco para jogos e menos reserva para tarefas de fundo.' }
    @{ Id='C5'; Cat='C'; Padrao=$true;  Nome='Priorizar o programa em primeiro plano';       Desc='Win32PrioritySeparation 0x26: o jogo em primeiro plano recebe mais CPU.' }
    @{ Id='C6'; Cat='C'; Padrao=$true;  Nome='Reduzir efeitos visuais';                              Desc='Sem animacoes e transparencia; menus e inicializacao sem atraso.' }
    @{ Id='C7'; Cat='C'; Padrao=$true;  Nome='Otimizar jogos em janela'; Desc='Otimizacao do Windows 11 para jogos DX10/11 em janela sem borda.'; Cond={ param($h) $h.WIN11 -eq '1' } }
    @{ Id='C8'; Cat='C'; Padrao=$true;  Nome='Corrigir timer HPET forcado';              Desc='Remove um tweak antigo que AUMENTA a latencia (so mexe se estiver ligado).' }
    @{ Id='C9'; Cat='C'; Padrao=$true;  Nome='Desativar economia de energia de USB e perifericos';  Desc='Os dispositivos nunca "dormem" para economizar energia.' }

    @{ Id='D1'; Cat='D'; Padrao=$true;  Nome='Aplicar plano de energia adequado ao processador'; Desc='Desktop: sem core parking e boost agressivo. Ryzen X3D 2 CCDs: Balanceado. Notebook: Melhor desempenho.' }
    @{ Id='D2'; Cat='D'; Padrao=$true;  Nome='Remover limitacao de energia em segundo plano';   Desc='Power Throttling desligado (Discord/OBS nao perdem forca).'; Cond={ param($h) $h.LAPTOP -ne '1' } }

    @{ Id='E1'; Cat='E'; Padrao=$true;  Nome='Usar a taxa de atualizacao maxima do monitor';              Desc='Se o monitor de 144 Hz estiver em 60 Hz, corrige.' }
    @{ Id='E2'; Cat='E'; Padrao=$true;  Nome='Ativar agendamento de GPU por hardware (HAGS)';   Desc='Tira carga do processador; obrigatorio para DLSS Frame Generation.'; Cond={ param($h) @('NVIDIA','AMD','INTEL_ARC') -contains $h.GPU_VENDOR } }
    @{ Id='E3'; Cat='E'; Padrao=$true;  Nome='Otimizar painel NVIDIA/AMD';   Desc='Baixa latencia, filtragem de textura rapida, cache de shader, energia, V-Sync certo.'; Cond={ param($h) $h.GPU_VENDOR -eq 'NVIDIA' -or $h.GPU_VENDOR -like 'AMD*' } }
    @{ Id='E4'; Cat='E'; Padrao=$false; Nome='Desativar sobreposicao multiplano (MPO)';                             Desc='So para quem tem tela piscando/travando no alt+tab. Tira a otimizacao de janela do Win11.' }

    @{ Id='F1'; Cat='F'; Padrao=$true;  Nome='Desativar algoritmo de Nagle'; Desc='Ajuda em jogos que usam TCP. Nao atrapalha downloads.' }
    @{ Id='F2'; Cat='F'; Padrao=$true;  Nome='Desativar economia de energia da rede cabeada';       Desc='Desliga Green Ethernet/EEE, que causam picos de ping. O Wi-Fi nao e alterado.' }
    @{ Id='F3'; Cat='F'; Padrao=$true;  Nome='Limitar compartilhamento do Windows Update';     Desc='Para de enviar atualizacoes para outros PCs pela sua conexao.' }
    @{ Id='F4'; Cat='F'; Padrao=$true;  Nome='Restaurar padroes de rede alterados'; Desc='Volta o TCP e o RSS para o padrao se algum pack os desligou (deixa download lento).' }

    @{ Id='G1'; Cat='G'; Padrao=$true;  Nome='Ajustar SSD e HD';             Desc='SSD: TRIM e menos escrita. HD: pre-carregamento e desfragmentacao ligados.' }
    @{ Id='G2'; Cat='G'; Padrao=$true;  Nome='Desativar hibernacao';                      Desc='Libera alguns GB e o PC liga "limpo".'; Cond={ param($h) $h.LAPTOP -ne '1' } }
    @{ Id='G3'; Cat='G'; Padrao=$true;  Nome='Desativar compressao de memoria';           Desc='Com 32 GB ou mais ela so gasta CPU.'; Cond={ param($h) [int]$h.RAM_GB -ge 32 } }
    @{ Id='G4'; Cat='G'; Padrao=$true;  Nome='Manter arquivo de paginacao ativo';              Desc='Se outro pack desligou, religa (sem ele, jogos fecham sozinhos).' }
    @{ Id='G5'; Cat='G'; Padrao=$true;  Nome='Limpar arquivos temporarios';              Desc='Temporarios, dumps, cache de shader e downloads do Windows Update.' }


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

function Show-Resumo($sel) {
    foreach ($c in $CATEGORIAS.Keys) {
        $its = @($CATALOGO | Where-Object { $_.Cat -eq $c -and $sel[$_.Id] })
        if ($its.Count -eq 0) { continue }
        Write-Host ("  {0}:" -f $CATEGORIAS[$c]) -ForegroundColor White
        foreach ($it in $its) { Write-Host ("     + {0}" -f $it.Nome) -ForegroundColor Gray }
    }
}

# Roda a selecao na ordem certa
# Antes de aplicar: confere no PC o que ja esta aplicado e funcionando.
# Ja aplicado -> pergunta se quer refazer (padrao: nao). Desfeito pelo Windows -> aplica de novo.
function Select-SoPendentes($sel) {
    $ids = @($sel.Keys | Where-Object { $sel[$_] -and $_ -ne 'B12' })
    if ($ids.Count -eq 0) { return $sel }
    Write-Title 'CONFERINDO O QUE JA ESTA APLICADO'
    Write-Info 'Verificando cada ajuste no seu PC...'
    $ja = @($ids | Where-Object { Test-ItemAplicado $_ })
    if ($ja.Count -eq 0) { Write-Ok 'Nenhum ajuste aplicado ainda: tudo sera aplicado agora.'; return $sel }
    foreach ($i in $ja) {
        $n = ($CATALOGO | Where-Object { $_.Id -eq $i } | Select-Object -First 1).Nome
        Write-Host ("  [OK] {0}" -f $n) -ForegroundColor Green
    }
    $pend = $ids.Count - $ja.Count
    Write-Host ''
    if ($pend -gt 0) { Write-Note ("{0} ajuste(s) ainda nao aplicado(s), ou desfeito(s) pelo Windows, serao aplicados agora." -f $pend) }
    $script:AutoMode = $false
    $refazer = Select-SimNao ("{0} ajuste(s) ja estao aplicados e funcionando. Aplicar de novo mesmo assim?" -f $ja.Count) $false
    $novo = @{}; foreach ($k in $sel.Keys) { $novo[$k] = $sel[$k] }
    if (-not $refazer) { foreach ($i in $ja) { $novo[$i] = $false }; $script:JaAplicados = $ja.Count }
    return $novo
}

function Invoke-Selecao($sel) {
    $sel = Select-SoPendentes $sel
    $script:Selecao = $sel
    $script:AutoMode = $true
    $etapas = @(
        @{ N = 'Backup e ponto de restauracao'; Ok = $sel['S1'];                          F = { Mod-Restore } },
        @{ N = 'Privacidade e segundo plano';         Ok = (WantAny @('B1','B2','B3','B4','B5','B6','B7','B8','B9','B10','B11')); F = { Mod-Debloat } },
        @{ N = 'Latencia e resposta do sistema';           Ok = (WantAny @('C1','C2','C3','C4','C5','C6','C7','C8','C9')); F = { Mod-Sistema } },
        @{ N = 'Energia e processador';         Ok = (WantAny @('D1','D2'));              F = { Mod-Energia } },
        @{ N = 'Video e monitor';      Ok = (WantAny @('E1','E2','E3','E4'));    F = { Mod-GPU } },
        @{ N = 'Rede';                      Ok = (WantAny @('F1','F2','F3','F4')); F = { Mod-Rede } },
        @{ N = 'Armazenamento e memoria';              Ok = (WantAny @('G1','G2','G3','G4','G5')); F = { Mod-Armazenamento } }
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
        @{ K = '2'; T = 'PERSONALIZADO  (so no AVANTIPACK Pro)'; C = 'DarkGray'; D = 'No Pro voce escolhe cada ajuste por categoria, com explicacao.' }
    )
    if ($ult) {
        $dr = if (Test-PrecisaReaplicar) { 'O Windows foi atualizado: recomendado reaplicar.' } else { 'Use depois de atualizacoes grandes do Windows.' }
        $op += @{ K = '3'; T = 'REAPLICAR o que eu escolhi da ultima vez'; C = 'Yellow'; D = $dr }
    }
    $ini = if ($ult -and (Test-PrecisaReaplicar)) { 2 } else { 0 }
    $r = Select-Opcao $op -Inicio $ini
    switch ($r) {
        '1' { $sel = Get-DefaultSelection $hw }
        '2' { Show-SoPro; return }
        '3' { if ($ult) { Mod-Reaplicar }; return }
        default { return }
    }
    Write-Title 'VAI SER APLICADO'
    Show-Resumo $sel
    Write-Host ''
    Write-Note 'Tudo volta ao original pela opcao 6 (Desfazer); apps removidos voltam pela Loja.'
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
        ("Ja estavam certos ......... {0}" -f ($script:JaEstava + [int]$script:JaAplicados)),
        ("Avisos para voce ver ...... {0}" -f $avisosRun),
        '',
        'Tudo pode ser desfeito pela opcao 6 do menu.',
        'Alertas de BIOS (XMP etc.): veja a opcao 5, Guias.'
    ) 'Green'
    Write-Host ''
    if ($script:Applied -gt 0) { Write-Host '  REINICIE O PC para tudo comecar a valer.' -ForegroundColor Black -BackgroundColor Yellow }
    if ($script:Applied -gt 0 -and (Confirm-Step 'Reiniciar agora?')) { & shutdown.exe /r /t 10 /c 'AVANTIPACK: reiniciando para aplicar as otimizacoes'; Write-Ok 'O PC vai reiniciar em 10 segundos.' }
    $script:NeedReboot = $false
}
