# =====================================================================
#  AVANTIPACK - menu com setas do teclado
#  Setas CIMA/BAIXO + ENTER, ou digite o numero/letra e ENTER.
#  Devolve a escolha como codigo de saida para o AVANTIPACK.bat:
#    100 + numero da opcao (100 = 0 / sair / voltar)
#    120 = F (teste de FPS)   121 = R (relatorio)   130 = U (atualizar)
#  Leve de proposito: nao carrega o motor (abre na hora).
# =====================================================================
param([string]$Tela = 'principal')
$ErrorActionPreference = 'Stop'

$SETA = [char]0x25BA; $CIMA = [char]0x2191; $BAIXO = [char]0x2193

if ($Tela -eq 'avancado') {
    $itens = @(
        @{ K = '1';  T = 'Ver hardware e alertas' },
        @{ K = '2';  T = 'Checar placa de video e monitor' },
        @{ K = '3';  T = 'Criar ponto de restauracao' },
        @{ K = '4';  T = 'Debloat e privacidade' },
        @{ K = '5';  T = 'Sistema e input lag' },
        @{ K = '6';  T = 'Energia e processador' },
        @{ K = '7';  T = 'Placa de video' },
        @{ K = '8';  T = 'Rede e ping' },
        @{ K = '9';  T = 'Armazenamento e memoria' },
        @{ K = '10'; T = 'Prioridade dos jogos (e placa dedicada no notebook)' },
        @{ K = '11'; T = 'DNS mais rapido' },
        @{ K = '12'; T = 'Ajustes avancados (tem riscos)'; C = 'Yellow' },
        @{ K = '13'; T = 'Tudo do 3 ao 9 com perguntas' },
        @{ K = '14'; T = 'Guia de BIOS' },
        @{ K = '15'; T = 'Programas que iniciam com o Windows' },
        @{ K = '16'; T = 'Teste de input lag' },
        @{ K = '17'; T = 'Diagnostico da internet' },
        @{ K = '18'; T = 'Manutencao semanal automatica' },
        @{ K = '19'; T = 'Perfil NVIDIA nos jogos competitivos' },
        @{ K = '20'; T = 'Atualizar o pack (GitHub)' },
        @{ K = '21'; T = 'Novidades (o que mudou nas versoes)' },
        @{ K = '0';  T = 'Voltar ao menu principal'; C = 'DarkGray' }
    )
} else {
    $itens = @(
        @{ K = '1'; T = 'OTIMIZAR MEU PC'; X = '  <-- comece por aqui'; C = 'Green'
           D = 'Automatico (o pack escolhe tudo) ou Personalizado (voce escolhe).' },
        @{ K = '2'; T = 'VERIFICAR MEU PC'; C = 'Cyan'
           D = 'Pecas, problemas (memoria, monitor em 60 Hz...), input lag e internet.' },
        @{ K = 'F'; T = 'TESTE DE FPS (antes e depois)'; C = 'Cyan'; N = 1
           D = 'Mede FPS e travadinhas jogando, para comparar antes e depois.' },
        @{ K = '3'; T = 'CONSERTAR UM PROBLEMA'; C = 'Cyan'
           D = 'Sem internet, sem som, microfone, camera, Loja, Windows Update...' },
        @{ K = '4'; T = 'PROGRAMAS UTEIS'; C = 'Cyan'
           D = 'Instala sozinho os programas e drivers certos para o seu PC.' },
        @{ K = '5'; T = 'GUIAS PASSO A PASSO'; C = 'Cyan'
           D = 'Painel NVIDIA/AMD com imagens, BIOS, limite de FPS, jogos.' },
        @{ K = '6'; T = 'DESFAZER / RECOLOCAR FUNCOES E APPS'; C = 'Red'
           D = 'Desfaz tudo ou so o que voce escolher (impressora, clipes...).' },
        @{ K = 'R'; T = 'RELATORIO PARA AJUDA'; C = 'Cyan'; N = 1
           D = 'Cria um arquivo com tudo do seu PC para mandar a quem te ajuda.' },
        @{ K = '7'; T = 'Modo avancado (escolher cada ajuste)'; C = 'Gray' },
        @{ K = '8'; T = 'Reiniciar o PC'; C = 'Gray' },
        @{ K = '0'; T = 'Sair'; C = 'Gray' }
    )
}

function Get-Codigo([string]$k) {
    switch ($k.ToUpper()) { 'F' { 120 } 'R' { 121 } 'U' { 130 } default { 100 + [int]$k } }
}

$larg = [math]::Max(60, [Console]::WindowWidth - 2)
function Write-Linha([string]$txt, [string]$fg = 'Gray', [string]$bg = $null) {
    $t = $txt; if ($t.Length -lt $larg) { $t = $t.PadRight($larg) } else { $t = $t.Substring(0, $larg) }
    if ($bg) { Write-Host $t -ForegroundColor $fg -BackgroundColor $bg } else { Write-Host $t -ForegroundColor $fg }
}

$sel = 0
$digitado = ''
$topo = [Console]::CursorTop
try { [Console]::CursorVisible = $false } catch {}

function Show-Menu {
    [Console]::SetCursorPosition(0, $script:topo)
    for ($i = 0; $i -lt $itens.Count; $i++) {
        $it = $itens[$i]
        $c = if ($it.C) { $it.C } else { 'Cyan' }
        $tag = if ($it.K.Length -eq 1) { "[$($it.K)] " } else { "[$($it.K)]" }
        $novo = if ($it.N) { '  NOVO' } else { '' }
        if ($i -eq $script:sel) {
            Write-Linha ("  $SETA $tag $($it.T)$($it.X)$novo") 'White' 'DarkBlue'
        } else {
            Write-Linha ("    $tag $($it.T)$($it.X)$novo") $c
        }
        if ($it.D) { Write-Linha ("         $($it.D)") 'DarkGray' }
    }
    Write-Linha ''
    $dica = "  $CIMA $BAIXO escolher    ENTER confirmar    ou digite o numero"
    if ($Tela -ne 'avancado') { $dica += ' (F, R)' } else { $dica += '    ESC volta' }
    Write-Linha $dica 'DarkCyan'
    $op = if ($script:digitado) { "  Opcao: $($script:digitado)_" } else { '' }
    Write-Linha $op 'White'
}

try {
    Show-Menu
    while ($true) {
        $k = [Console]::ReadKey($true)
        switch ($k.Key) {
            'UpArrow'   { $sel = ($sel - 1 + $itens.Count) % $itens.Count; $digitado = '' }
            'DownArrow' { $sel = ($sel + 1) % $itens.Count; $digitado = '' }
            'Home'      { $sel = 0; $digitado = '' }
            'End'       { $sel = $itens.Count - 1; $digitado = '' }
            'Escape'    { if ($Tela -eq 'avancado') { exit 100 } ; $digitado = '' }
            'Backspace' { if ($digitado.Length) { $digitado = $digitado.Substring(0, $digitado.Length - 1) } }
            'Enter'     {
                $k2 = if ($digitado) { $digitado } else { $itens[$sel].K }
                if ($k2 -match '^[UuFfRr]$' -and $Tela -eq 'avancado') { $digitado = ''; break }
                if ($k2 -match '^\d+$' -and -not ($itens | Where-Object { $_.K -eq $k2 })) { $digitado = ''; break }
                exit (Get-Codigo $k2)
            }
            default {
                $ch = [string]$k.KeyChar
                if ($ch -match '^\d$') {
                    $digitado = ($digitado + $ch); if ($digitado.Length -gt 2) { $digitado = $ch }
                    for ($i = 0; $i -lt $itens.Count; $i++) { if ($itens[$i].K -eq $digitado) { $sel = $i } }
                } elseif ($ch -match '^[UuFfRr]$' -and $Tela -ne 'avancado') {
                    exit (Get-Codigo $ch)
                }
            }
        }
        Show-Menu
    }
} finally {
    try { [Console]::CursorVisible = $true } catch {}
}
