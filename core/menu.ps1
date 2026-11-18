# =====================================================================
#  AVANTIPACK - menu com setas do teclado (desenha a TELA INTEIRA)
#  - Setas CIMA/BAIXO + ENTER, ou digite o numero/letra e ENTER.
#  - Sempre cabe na janela: se a janela for baixa, usa um cabecalho
#    menor; se mudar o tamanho (tela cheia / restaurar), redesenha.
#  Devolve a escolha como codigo de saida para o AVANTIPACK.bat:
#    100 + numero da opcao (100 = 0 / sair / voltar)
#    120 = F (teste de FPS)   121 = R (relatorio)   130 = U (atualizar)
#  Leve de proposito: nao carrega o motor (abre na hora).
# =====================================================================
param([string]$Tela = 'principal')
$ErrorActionPreference = 'Stop'

$SETA = [char]0x25BA; $CIMA = [char]0x2191; $BAIXO = [char]0x2193; $BLOCO = [char]0x2588
$BH = [char]0x2500; $BV = [char]0x2502
$BTL = [char]0x250C; $BTR = [char]0x2510; $BBL = [char]0x2514; $BBR = [char]0x2518

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

# ---------------- dados do cabecalho ----------------
$hw = @{}
try {
    foreach ($l in Get-Content (Join-Path $PSScriptRoot 'dados\data\hardware.txt') -ErrorAction Stop) {
        $i = $l.IndexOf('='); if ($i -gt 0) { $hw[$l.Substring(0, $i)] = $l.Substring($i + 1) }
    }
} catch {}
$ver = try { (Get-Content (Join-Path $PSScriptRoot 'VERSION.txt') -TotalCount 1).Trim() } catch { '' }
$BANNER = @(
    ' ###   #   #   ###   #   #  #####  ###  ####    ###    ####  #   #',
    '#   #  #   #  #   #  ##  #    #     #   #   #  #   #  #      #  #',
    '#####  #   #  #####  # # #    #     #   ####   #####  #      ###',
    '#   #   # #   #   #  #  ##    #     #   #      #   #  #      #  #',
    '#   #    #    #   #  #   #    #    ###  #      #   #   ####  #   #'
)

function Get-Codigo([string]$k) {
    switch ($k.ToUpper()) { 'F' { 120 } 'R' { 121 } 'U' { 130 } default { 100 + [int]$k } }
}
function Split-Texto([string]$t, [int]$w) {
    $out = @(); $l = ''
    foreach ($p in $t.Split(' ')) {
        if (($l + ' ' + $p).Trim().Length -gt $w) { $out += $l.Trim(); $l = $p } else { $l = ($l + ' ' + $p) }
    }
    if ($l.Trim()) { $out += $l.Trim() }
    return $out
}

# ---------------- desenho ----------------
# Toda linha ocupa exatamente (largura da janela - 1): nunca quebra de linha,
# e sempre apaga o que estava antes.
$script:W = 80; $script:H = 25; $script:pad = ''; $script:util = 78
function Update-Medidas {
    $script:W = [Console]::WindowWidth; $script:H = [Console]::WindowHeight
    $p = [math]::Max(0, [math]::Floor(($script:W - 84) / 2))
    $script:pad = ' ' * $p
    $script:util = [math]::Max(20, $script:W - 1 - $p)
}
function Write-L([string]$txt, [string]$fg = 'Gray', [string]$bg = $null, [int]$barra = 0) {
    $t = $txt
    if ($barra -gt 0 -and $t.Length -lt $barra) { $t = $t.PadRight([math]::Min($barra, $script:util)) }
    if ($t.Length -gt $script:util) { $t = $t.Substring(0, $script:util) }
    Write-Host $script:pad -NoNewline
    if ($bg) { Write-Host $t -ForegroundColor $fg -BackgroundColor $bg -NoNewline } else { Write-Host $t -ForegroundColor $fg -NoNewline }
    $resto = $script:W - 1 - $script:pad.Length - $t.Length
    if ($resto -gt 0) { Write-Host (' ' * $resto) -NoNewline }
    Write-Host ''
}
function Write-Banner {
    $cores = @('Blue', 'Blue', 'DarkCyan', 'Cyan')
    foreach ($row in $BANNER) {
        $linha = '      ' + $row
        Write-Host $script:pad -NoNewline
        $n = [math]::Min($linha.Length, $script:util)
        # agrupa trechos da mesma cor (bem mais rapido que caractere por caractere)
        $i = 0
        while ($i -lt $n) {
            $cor = if ($linha[$i] -eq '#') { $cores[[math]::Min(3, [math]::Floor(4 * $i / $linha.Length))] } else { '' }
            $j = $i
            $buf = New-Object System.Text.StringBuilder
            while ($j -lt $n) {
                $c2 = if ($linha[$j] -eq '#') { $cores[[math]::Min(3, [math]::Floor(4 * $j / $linha.Length))] } else { '' }
                if ($c2 -ne $cor) { break }
                [void]$buf.Append($(if ($linha[$j] -eq '#') { $BLOCO } else { ' ' }))
                $j++
            }
            if ($cor) { Write-Host $buf.ToString() -ForegroundColor $cor -NoNewline } else { Write-Host $buf.ToString() -NoNewline }
            $i = $j
        }
        $resto = $script:W - 1 - $script:pad.Length - $n
        if ($resto -gt 0) { Write-Host (' ' * $resto) -NoNewline }
        Write-Host ''
    }
}

function Get-Avisos {
    $a = @()
    if ($hw['ATUALIZACAO']) { $a += @{ T = " NOVA VERSAO $($hw['ATUALIZACAO']) DO AVANTIPACK DISPONIVEL - aperte U para atualizar "; F = 'Black'; B = 'Green' } }
    if ($hw['REAPLICAR'])   { $a += @{ T = ' O WINDOWS FOI ATUALIZADO - use a opcao 1 e depois Reaplicar '; F = 'Black'; B = 'Yellow' } }
    if ($hw['AVISO'])       { $a += @{ T = " $($hw['AVISO']) "; F = 'Black'; B = 'Yellow' } }
    return $a
}

# Escolhe o tamanho do layout pelo espaco da janela
function Get-Modo {
    $temDesc = @($itens | Where-Object { $_.D }).Count -gt 0
    $grupos = @($itens | Where-Object { $_.G }).Count
    $menuLinhas = $itens.Count + @($itens | Where-Object { $_.G -and $_.G.Trim() }).Count
    $cab = if ($Tela -eq 'avancado') { 3 } else { 4 + @(Get-Avisos).Count + $(if ([int]$hw['AJUSTES'] -gt 0) { 1 } else { 0 }) }
    foreach ($m in @(
        @{ Banner = $true;  Espaco = $true;  Caixa = $true },
        @{ Banner = $false; Espaco = $true;  Caixa = $true },
        @{ Banner = $false; Espaco = $false; Caixa = $true },
        @{ Banner = $false; Espaco = $false; Caixa = $false })) {
        $h = $cab + $menuLinhas + 1
        if ($m.Banner) { $h += 7 } else { $h += 1 }
        if ($m.Espaco) { $h += [math]::Max(0, $grupos - 1) }
        if ($m.Caixa -and $temDesc) { $h += 4 }
        $h += 2
        if ($h -le $script:H - 1) { return $m }
    }
    return @{ Banner = $false; Espaco = $false; Caixa = $false }
}

function Show-Tela([switch]$Limpar) {
    Update-Medidas
    if ($Limpar) { [Console]::Clear() }
    $m = Get-Modo
    [Console]::SetCursorPosition(0, 0)
    # ----- cabecalho
    if ($m.Banner) {
        Write-L ''
        Write-Banner
        Write-L ("      Otimizacao para jogos   |   v$ver   |   rode sempre como administrador") 'Gray'
    } else {
        Write-L ("  AVANTIPACK  v$ver   -   otimizacao para jogos") 'Cyan'
    }
    Write-L ''
    if ($Tela -eq 'avancado') {
        Write-L '  MODO AVANCADO  -  cada ajuste separado, com explicacao antes.' 'White'
    } else {
        Write-L ("  Seu PC:  " + $hw['CPU'] + "  +  " + $hw['GPU']) 'White'
        Write-L ("           " + $hw['RAM_GB'] + " GB de RAM   -   disco " + $hw['DISK'] + "   -   " + $hw['WIN']) 'Gray'
        if ([int]$hw['AJUSTES'] -gt 0) { Write-L ("           " + $hw['AJUSTES'] + " ajustes do AVANTIPACK ativos neste PC") 'Green' }
        foreach ($a in @(Get-Avisos)) { Write-L ('  ' + $a.T) $a.F $a.B ($a.T.Length + 2) }
    }
    Write-L ('  ' + ([string]$BH * [math]::Min(76, $script:util - 4))) 'DarkGray'
    # ----- opcoes
    for ($i = 0; $i -lt $itens.Count; $i++) {
        $it = $itens[$i]
        if ($it.G) {
            if ($i -gt 0 -and $m.Espaco) { Write-L '' }
            if ($it.G.Trim()) { Write-L ('   ' + $it.G) 'DarkCyan' }
        }
        $c = if ($it.C) { $it.C } else { 'Cyan' }
        $tag = ('[' + $it.K + ']').PadRight(5)
        $novo = if ($it.N) { '   NOVO' } else { '' }
        if ($i -eq $script:sel) { Write-L ("   $SETA $tag $($it.T)$($it.X)$novo") 'White' 'DarkBlue' 72 }
        else { Write-L ("     $tag $($it.T)$($it.X)$novo") $c }
    }
    Write-L ''
    # ----- rodape
    if ($m.Caixa -and @($itens | Where-Object { $_.D }).Count) {
        $lw = [math]::Max(20, [math]::Min(72, $script:util - 8))
        $ls = @(Split-Texto ([string]$itens[$script:sel].D) $lw)
        while ($ls.Count -lt 2) { $ls += '' }
        Write-L ("  $BTL" + ([string]$BH * ($lw + 2)) + $BTR) 'DarkGray'
        foreach ($x in $ls[0..1]) { Write-L ("  $BV " + $x.PadRight($lw) + " $BV") 'White' }
        Write-L ("  $BBL" + ([string]$BH * ($lw + 2)) + $BBR) 'DarkGray'
    }
    $dica = "  $CIMA $BAIXO escolher     ENTER confirmar     ou digite o numero"
    if ($Tela -ne 'avancado') { $dica += ' (F, R)' } else { $dica += '     ESC volta' }
    Write-L $dica 'DarkCyan'
    Write-L $(if ($script:digitado) { "  Opcao: $($script:digitado)_" } else { '' }) 'White'
    $script:ultW = $script:W; $script:ultH = $script:H
}

$sel = 0
$digitado = ''
try { [Console]::CursorVisible = $false } catch {}
try {
    Show-Tela -Limpar
    while ($true) {
        # espera a tecla; se a janela mudar de tamanho, redesenha
        while (-not [Console]::KeyAvailable) {
            Start-Sleep -Milliseconds 60
            if ([Console]::WindowWidth -ne $script:ultW -or [Console]::WindowHeight -ne $script:ultH) {
                Start-Sleep -Milliseconds 150
                Show-Tela -Limpar
            }
        }
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
        $mudou = ([Console]::WindowWidth -ne $script:ultW -or [Console]::WindowHeight -ne $script:ultH)
        Show-Tela -Limpar:$mudou
    }
} finally {
    try { [Console]::CursorVisible = $true } catch {}
    try { [Console]::Clear() } catch {}
}
