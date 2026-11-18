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
        @{ K = '1';  T = 'Ver hardware e alertas'; G = 'VERIFICAR' },
        @{ K = '2';  T = 'Checar placa de video e monitor' },
        @{ K = '16'; T = 'Teste de input lag' },
        @{ K = '17'; T = 'Diagnostico da internet' },
        @{ K = '3';  T = 'Criar ponto de restauracao'; G = 'AJUSTES POR PARTE' },
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
        @{ K = '15'; T = 'Programas que iniciam com o Windows'; G = 'FERRAMENTAS' },
        @{ K = '19'; T = 'Perfil NVIDIA nos jogos competitivos' },
        @{ K = '14'; T = 'Guia de BIOS' },
        @{ K = '18'; T = 'Manutencao semanal automatica' },
        @{ K = '20'; T = 'Atualizar o pack (GitHub)' },
        @{ K = '21'; T = 'Novidades (o que mudou nas versoes)' },
        @{ K = '0';  T = 'Voltar ao menu principal'; C = 'Gray'; G = ' ' }
    )
} else {
    $itens = @(
        @{ K = '1'; T = 'OTIMIZAR MEU PC'; X = '   <-- comece por aqui'; C = 'Green'; G = 'OTIMIZAR E TESTAR'
           D = 'Automatico (o pack escolhe tudo que e seguro para o seu PC) ou Personalizado (voce escolhe cada ajuste).' },
        @{ K = '2'; T = 'VERIFICAR MEU PC'; C = 'Cyan'
           D = 'Mostra suas pecas e problemas (memoria, monitor em 60 Hz, driver velho), testa input lag e internet.' },
        @{ K = 'F'; T = 'TESTE DE FPS  (antes e depois)'; C = 'Cyan'; N = 1
           D = 'Mede o FPS e as travadinhas enquanto voce joga, para comparar antes e depois de otimizar.' },
        @{ K = '3'; T = 'CONSERTAR UM PROBLEMA'; C = 'Cyan'; G = 'PROBLEMAS E PROGRAMAS'
           D = 'Sem internet, sem som, microfone, camera, Loja, Windows Update, impressora...' },
        @{ K = '4'; T = 'PROGRAMAS UTEIS'; C = 'Cyan'
           D = 'Instala sozinho os programas e drivers certos para o seu PC, cada um na sua pasta.' },
        @{ K = '5'; T = 'GUIAS PASSO A PASSO'; C = 'Cyan'
           D = 'Painel NVIDIA/AMD com imagens, BIOS, limite de FPS e as configuracoes dentro dos jogos.' },
        @{ K = '6'; T = 'DESFAZER / RECOLOCAR FUNCOES E APPS'; C = 'Red'; G = 'DESFAZER E AJUDA'
           D = 'Desfaz tudo ou so o que voce escolher (impressora, gravar clipes, apps removidos...).' },
        @{ K = 'R'; T = 'RELATORIO PARA AJUDA'; C = 'Cyan'; N = 1
           D = 'Cria um arquivo com tudo do seu PC para mandar a quem esta te ajudando.' },
        @{ K = '7'; T = 'Modo avancado'; C = 'Gray'; G = 'OUTROS'
           D = 'Cada ajuste separado, com explicacao antes. Para quem ja entende.' },
        @{ K = '8'; T = 'Reiniciar o PC'; C = 'Gray'; D = 'Reinicia o computador para os ajustes comecarem a valer.' },
        @{ K = '0'; T = 'Sair'; C = 'Gray'; D = 'Fecha o AVANTIPACK.' }
    )
}

function Get-Codigo([string]$k) {
    switch ($k.ToUpper()) { 'F' { 120 } 'R' { 121 } 'U' { 130 } default { 100 + [int]$k } }
}

# conteudo com 84 colunas, centralizado quando a janela e mais larga
$larg = 82   # largura do conteudo
$pad = ''
try { $n = [math]::Floor(([Console]::WindowWidth - 84) / 2); if ($n -gt 0) { $pad = ' ' * $n } } catch {}
function Write-Linha([string]$txt, [string]$fg = 'Gray', [string]$bg = $null) {
    $t = $txt; if ($t.Length -lt $larg) { $t = $t.PadRight($larg) } else { $t = $t.Substring(0, $larg) }
    if ($pad) { Write-Host $pad -NoNewline }
    if ($bg) { Write-Host $t -ForegroundColor $fg -BackgroundColor $bg } else { Write-Host $t -ForegroundColor $fg }
}

$sel = 0
$digitado = ''
$topo = [Console]::CursorTop
try { [Console]::CursorVisible = $false } catch {}

$BH = [char]0x2500; $BV = [char]0x2502
$BTL = [char]0x250C; $BTR = [char]0x2510; $BBL = [char]0x2514; $BBR = [char]0x2518
$temDesc = @($itens | Where-Object { $_.D }).Count -gt 0

function Split-Texto([string]$t, [int]$w) {
    $out = @(); $l = ''
    foreach ($p in $t.Split(' ')) {
        if (($l + ' ' + $p).Trim().Length -gt $w) { $out += $l.Trim(); $l = $p } else { $l = ($l + ' ' + $p) }
    }
    if ($l.Trim()) { $out += $l.Trim() }
    return $out
}

function Show-Menu {
    [Console]::SetCursorPosition(0, $script:topo)
    for ($i = 0; $i -lt $itens.Count; $i++) {
        $it = $itens[$i]
        if ($it.G) {
            if ($i -gt 0) { Write-Linha '' }
            if ($it.G.Trim()) { Write-Linha ("   " + $it.G) 'DarkCyan' }
        }
        $c = if ($it.C) { $it.C } else { 'Cyan' }
        $tag = ('[' + $it.K + ']').PadRight(5)
        $novo = if ($it.N) { '   NOVO' } else { '' }
        if ($i -eq $script:sel) {
            Write-Linha ("   $SETA $tag $($it.T)$($it.X)$novo").PadRight(72) 'White' 'DarkBlue'
        } else {
            Write-Linha ("     $tag $($it.T)$($it.X)$novo") $c
        }
    }
    Write-Linha ''
    if ($temDesc) {
        $d = [string]$itens[$script:sel].D
        $ls = @(Split-Texto $d 72)
        while ($ls.Count -lt 2) { $ls += '' }
        Write-Linha ("  $BTL" + ([string]$BH * 76) + $BTR) 'DarkGray'
        foreach ($x in $ls[0..1]) { Write-Linha ("  $BV " + $x.PadRight(74) + " $BV") 'White' }
        Write-Linha ("  $BBL" + ([string]$BH * 76) + $BBR) 'DarkGray'
    }
    $dica = "  $CIMA $BAIXO escolher     ENTER confirmar     ou digite o numero"
    if ($Tela -ne 'avancado') { $dica += ' (F, R)' } else { $dica += '     ESC volta' }
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
