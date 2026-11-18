# =====================================================================
#  AVANTIPACK - interface: tela centralizada e menus com setas
#
#  - Write-Host / Read-Host ganham uma margem a esquerda para a tela
#    ficar no MEIO quando a janela e grande (tela cheia).
#  - Select-Opcao : lista com setas (ENTER escolhe, ESC volta).
#  - Select-Varios: lista de marcar com setas (ESPACO/ENTER marca,
#                   "CONCLUIR" confirma, ESC cancela).
#  - Select-SimNao: Sim / Nao com setas (usado pelo Confirm-Step).
#  Se o console nao aceitar teclas (ex.: saida redirecionada), tudo
#  volta sozinho para o modo de digitar.
# =====================================================================

$script:UiLarg = 84                     # largura do conteudo do pack
$script:UiInicioLinha = $true
$script:UiSeta = [char]0x25BA
$script:UiCima = [char]0x2191; $script:UiBaixo = [char]0x2193
$script:UiEsq = [char]0x2190;  $script:UiDir = [char]0x2192

$script:UiBH = [char]0x2500; $script:UiBV = [char]0x2502
$script:UiBTL = [char]0x250C; $script:UiBTR = [char]0x2510; $script:UiBBL = [char]0x2514; $script:UiBBR = [char]0x2518

function Split-UiTexto([string]$t, [int]$w) {
    $out = @(); $l = ''
    foreach ($p in ([string]$t).Split(' ')) {
        if (($l + ' ' + $p).Trim().Length -gt $w) { $out += $l.Trim(); $l = $p } else { $l = ($l + ' ' + $p) }
    }
    if ($l.Trim()) { $out += $l.Trim() }
    return $out
}
function Get-UiPad {
    try { $w = [Console]::WindowWidth } catch { return '' }
    $p = [math]::Floor(($w - $script:UiLarg) / 2)
    if ($p -lt 1) { return '' }
    return (' ' * $p)
}
function Test-UiTeclas {
    try { [void][Console]::KeyAvailable; return (-not [Console]::IsInputRedirected) } catch { return $false }
}

# Write-Host com margem (so no comeco de cada linha)
function Write-Host {
    param([Parameter(Position = 0, ValueFromRemainingArguments = $true)]$Object,
          [switch]$NoNewline, [System.ConsoleColor]$ForegroundColor, [System.ConsoleColor]$BackgroundColor, $Separator = ' ')
    $txt = if ($null -eq $Object) { '' } else { (@($Object) | ForEach-Object { "$_" }) -join $Separator }
    if ($script:UiInicioLinha) {
        $pad = Get-UiPad
        if ($pad) { Microsoft.PowerShell.Utility\Write-Host $pad -NoNewline }
    }
    $p = @{ Object = $txt; NoNewline = $NoNewline }
    if ($PSBoundParameters.ContainsKey('ForegroundColor')) { $p.ForegroundColor = $ForegroundColor }
    if ($PSBoundParameters.ContainsKey('BackgroundColor')) { $p.BackgroundColor = $BackgroundColor }
    Microsoft.PowerShell.Utility\Write-Host @p
    $script:UiInicioLinha = -not $NoNewline
}
function Read-Host {
    param([Parameter(Position = 0)]$Prompt)
    $script:UiInicioLinha = $true
    if ($null -eq $Prompt) { return (Microsoft.PowerShell.Utility\Read-Host) }
    return (Microsoft.PowerShell.Utility\Read-Host ((Get-UiPad) + $Prompt))
}

# Escreve uma linha "crua" (sem passar pelo Write-Host acima), do tamanho certo
function Get-UiUtil {
    $pad = Get-UiPad
    $w = 80; try { $w = [Console]::WindowWidth } catch {}
    return @{ Pad = $pad; Util = [math]::Max(20, [math]::Min($script:UiLarg - 2, $w - 1 - $pad.Length)); Resto = $w - 1 - $pad.Length }
}
function Write-UiLinha([string]$txt, [string]$fg = 'Gray', [string]$bg = $null) {
    $u = Get-UiUtil
    if ($txt.Length -gt $u.Util) { $txt = $txt.Substring(0, $u.Util) }
    if ($u.Pad) { Microsoft.PowerShell.Utility\Write-Host $u.Pad -NoNewline }
    if ($bg) { Microsoft.PowerShell.Utility\Write-Host $txt -ForegroundColor $fg -BackgroundColor $bg -NoNewline }
    else { Microsoft.PowerShell.Utility\Write-Host $txt -ForegroundColor $fg -NoNewline }
    $r = $u.Resto - $txt.Length
    if ($r -gt 0) { Microsoft.PowerShell.Utility\Write-Host (' ' * $r) -NoNewline }
    Microsoft.PowerShell.Utility\Write-Host ''
    $script:UiInicioLinha = $true
}
function Write-UiLinhaSel([string]$txt) {
    $u = Get-UiUtil
    $t = $txt.PadRight([math]::Min(72, $u.Util))
    if ($t.Length -gt $u.Util) { $t = $t.Substring(0, $u.Util) }
    if ($u.Pad) { Microsoft.PowerShell.Utility\Write-Host $u.Pad -NoNewline }
    Microsoft.PowerShell.Utility\Write-Host $t -ForegroundColor White -BackgroundColor DarkBlue -NoNewline
    $r = $u.Resto - $t.Length
    if ($r -gt 0) { Microsoft.PowerShell.Utility\Write-Host (' ' * $r) -NoNewline }
    Microsoft.PowerShell.Utility\Write-Host ''
    $script:UiInicioLinha = $true
}

# Antes de desenhar uma lista: se ela nao cabe embaixo do que ja esta na tela,
# limpa a tela e comeca do topo (repetindo o titulo da tela). Devolve a linha inicial.
$script:UiUltimoTitulo = ''
function Get-UiTopo([int]$altura, [switch]$Forcar) {
    $topo = [Console]::CursorTop
    $fim = [Console]::WindowTop + [Console]::WindowHeight - 1
    if ($Forcar -or ($topo + $altura -gt $fim)) {
        [Console]::Clear()
        if ($script:UiUltimoTitulo) { Write-Title $script:UiUltimoTitulo }
        $topo = [Console]::CursorTop
    }
    return $topo
}
# espera uma tecla; devolve $null se a janela mudou de tamanho (para redesenhar)
function Read-UiTecla {
    $w = [Console]::WindowWidth; $h = [Console]::WindowHeight
    while (-not [Console]::KeyAvailable) {
        Start-Sleep -Milliseconds 60
        if ([Console]::WindowWidth -ne $w -or [Console]::WindowHeight -ne $h) { Start-Sleep -Milliseconds 150; return $null }
    }
    return [Console]::ReadKey($true)
}
# caixa com a explicacao do item selecionado (sempre 4 linhas)
function Write-UiCaixaDesc([string]$d) {
    $u = Get-UiUtil
    $lw = [math]::Max(20, [math]::Min(72, $u.Util - 6))
    $ls = @(Split-UiTexto $d $lw)
    while ($ls.Count -lt 2) { $ls += '' }
    Write-UiLinha ("  " + $script:UiBTL + ([string]$script:UiBH * ($lw + 2)) + $script:UiBTR) 'DarkGray'
    foreach ($x in $ls[0..1]) { Write-UiLinha ("  " + $script:UiBV + ' ' + $x.PadRight($lw) + ' ' + $script:UiBV) 'White' }
    Write-UiLinha ("  " + $script:UiBBL + ([string]$script:UiBH * ($lw + 2)) + $script:UiBBR) 'DarkGray'
}

# ---------------------------------------------------------------------
#  Lista com setas.  $Itens = @( @{K='1'; T='Texto'; D='descricao'; C='Cyan'} , ... )
#  Devolve a chave (K) escolhida; '0' = voltar.
# ---------------------------------------------------------------------
function Select-Opcao {
    param([array]$Itens, [string]$Voltar = 'Voltar', [int]$Inicio = 0, [string]$Dica = '')
    $lista = @($Itens)
    if ($Voltar) { $lista += @{ K = '0'; T = $Voltar; C = 'DarkGray' } }
    if (-not (Test-UiTeclas)) {
        foreach ($it in $lista) { Write-Host ("  [{0}] {1}" -f $it.K, $it.T) }
        $r = Read-Host '  Escolha'
        if (-not $r) { return '0' }
        return $r.Trim()
    }
    $sel = [math]::Max(0, [math]::Min($Inicio, $lista.Count - 1))
    $dig = ''
    $temDesc = @($lista | Where-Object { $_.D }).Count -gt 0
    $extra = 4 + $(if ($temDesc) { 4 } else { 0 })          # setas de "mais", espaco, dica, opcao (+ caixa)
    $topo = -1
    try { [Console]::CursorVisible = $false } catch {}
    try {
        while ($true) {
            # medidas da janela (refeitas a cada volta: aguenta mudar de tamanho)
            $wh = [Console]::WindowHeight
            $espaco = if ($topo -lt 0) { $wh - 1 - ([Console]::CursorTop - [Console]::WindowTop) } else { $wh - 1 - ($topo - [Console]::WindowTop) }
            $maxLin = [math]::Max(6, $wh - 4)                  # o que cabe numa tela limpa (com titulo)
            $porItem = if (($lista.Count * 2 + $extra) -le [math]::Min($espaco, $maxLin) -and $lista.Count -le 12) { 2 } else { 1 }
            $cabe = [math]::Min($lista.Count, [math]::Max(3, [math]::Floor(($maxLin - $extra - 3) / $porItem)))
            $altura = $cabe * $porItem + $extra
            if ($topo -lt 0) { $topo = Get-UiTopo $altura }
            [Console]::SetCursorPosition(0, $topo)
            if ($cabe -ge $lista.Count) { $ini = 0 }
            else { $ini = [math]::Max(0, [math]::Min($sel - [math]::Floor($cabe / 2), $lista.Count - $cabe)) }
            Write-UiLinha $(if ($ini -gt 0) { "     $($script:UiCima) mais opcoes acima" } else { '' }) 'DarkGray'
            for ($i = $ini; $i -lt $ini + $cabe; $i++) {
                $it = $lista[$i]
                $c = if ($it.C) { $it.C } else { 'Cyan' }
                $tag = ('[' + $it.K + ']').PadRight(5)
                if ($i -eq $sel) { Write-UiLinhaSel ("   $($script:UiSeta) $tag $($it.T)") }
                else { Write-UiLinha ("     $tag $($it.T)") $c }
                if ($porItem -eq 2) { Write-UiLinha '' }
            }
            Write-UiLinha $(if ($ini + $cabe -lt $lista.Count) { "     $($script:UiBaixo) mais opcoes abaixo" } else { '' }) 'DarkGray'
            if ($temDesc) { Write-UiCaixaDesc ([string]$lista[$sel].D) }
            $h = "  $($script:UiCima) $($script:UiBaixo) escolher     ENTER confirmar     ESC voltar     (ou digite o numero)"
            if ($Dica) { $h = "  $Dica" }
            Write-UiLinha $h 'DarkCyan'
            Write-UiLinha $(if ($dig) { "  Opcao: $dig" + '_' } else { '' }) 'White'
            $k = Read-UiTecla
            if ($null -eq $k) { $topo = Get-UiTopo 0 -Forcar; continue }     # mudou o tamanho da janela
            switch ($k.Key) {
                'UpArrow'   { $sel = ($sel - 1 + $lista.Count) % $lista.Count; $dig = '' }
                'DownArrow' { $sel = ($sel + 1) % $lista.Count; $dig = '' }
                'PageUp'    { $sel = [math]::Max(0, $sel - 10); $dig = '' }
                'PageDown'  { $sel = [math]::Min($lista.Count - 1, $sel + 10); $dig = '' }
                'Home'      { $sel = 0; $dig = '' }
                'End'       { $sel = $lista.Count - 1; $dig = '' }
                'Escape'    { return '0' }
                'Backspace' { if ($dig.Length) { $dig = $dig.Substring(0, $dig.Length - 1) } }
                'Enter'     {
                    if ($dig) { $m = @($lista | Where-Object { $_.K -eq $dig }); if ($m.Count) { return $dig }; $dig = ''; break }
                    return [string]$lista[$sel].K
                }
                default {
                    $ch = ([string]$k.KeyChar).ToUpper()
                    if ($ch -match '^\d$') {
                        $dig += $ch; if ($dig.Length -gt 3) { $dig = $ch }
                        for ($i = 0; $i -lt $lista.Count; $i++) { if ($lista[$i].K -eq $dig) { $sel = $i } }
                    } elseif ($ch -match '^[A-Z]$') {
                        $m = @($lista | Where-Object { ([string]$_.K).ToUpper() -eq $ch })
                        if ($m.Count) { return [string]$m[0].K }
                    }
                }
            }
        }
    } finally {
        try { [Console]::CursorVisible = $true } catch {}
        $script:UiInicioLinha = $true
    }
}

# ---------------------------------------------------------------------
#  Lista de marcar.  $Itens = @( @{K='B1'; T='Texto'; D='desc'; On=$true; Bloq=$false (n/a); C='Yellow'} )
#  Devolve as chaves marcadas (array) ou $null se cancelar (ESC).
# ---------------------------------------------------------------------
function Select-Varios {
    param([array]$Itens, [string]$Concluir = 'CONCLUIR', [switch]$SemTodos)
    $lista = @($Itens | ForEach-Object { @{ K = $_.K; T = $_.T; D = $_.D; On = [bool]$_.On; Bloq = [bool]$_.Bloq; C = $_.C } })
    if (-not (Test-UiTeclas)) {
        for ($i = 0; $i -lt $lista.Count; $i++) { Write-Host ("  {0,2}. [{1}] {2}" -f ($i + 1), $(if ($lista[$i].On) { 'X' } else { ' ' }), $lista[$i].T) }
        $r = Read-Host '  Numeros para marcar/desmarcar (ex: 1,3) e ENTER para concluir'
        foreach ($x in ([string]$r).Split(',')) { $x = $x.Trim(); if ($x -match '^\d+$' -and [int]$x -ge 1 -and [int]$x -le $lista.Count -and -not $lista[[int]$x - 1].Bloq) { $lista[[int]$x - 1].On = -not $lista[[int]$x - 1].On } }
        return @($lista | Where-Object { $_.On } | ForEach-Object { $_.K })
    }
    $n = $lista.Count            # posicao $n = botao CONCLUIR
    $sel = 0
    $temDesc = @($lista | Where-Object { $_.D }).Count -gt 0
    $extra = 6 + $(if ($temDesc) { 4 } else { 0 })
    $topo = -1
    try { [Console]::CursorVisible = $false } catch {}
    try {
        while ($true) {
            $wh = [Console]::WindowHeight
            $espaco = if ($topo -lt 0) { $wh - 1 - ([Console]::CursorTop - [Console]::WindowTop) } else { $wh - 1 - ($topo - [Console]::WindowTop) }
            $maxLin = [math]::Max(8, $wh - 4)
            $porItem = if (($n * 2 + $extra) -le [math]::Min($espaco, $maxLin) -and $n -le 12) { 2 } else { 1 }
            $cabe = [math]::Min($n, [math]::Max(3, [math]::Floor(($maxLin - $extra - 3) / $porItem)))
            $altura = $cabe * $porItem + $extra
            if ($topo -lt 0) { $topo = Get-UiTopo $altura }
            [Console]::SetCursorPosition(0, $topo)
            if ($cabe -ge $n) { $ini = 0 }
            else { $ini = [math]::Max(0, [math]::Min([math]::Min($sel, $n - 1) - [math]::Floor($cabe / 2), $n - $cabe)) }
            Write-UiLinha $(if ($ini -gt 0) { "     $($script:UiCima) mais itens acima" } else { '' }) 'DarkGray'
            for ($i = $ini; $i -lt $ini + $cabe; $i++) {
                $it = $lista[$i]
                $box = if ($it.Bloq) { '[n/a]' } elseif ($it.On) { '[ X ]' } else { '[   ]' }
                $c = if ($it.Bloq) { 'DarkGray' } elseif ($it.C) { $it.C } elseif ($it.On) { 'Green' } else { 'White' }
                if ($i -eq $sel) { Write-UiLinhaSel ("   $($script:UiSeta) $box $($it.T)") }
                else { Write-UiLinha ("     $box $($it.T)") $c }
                if ($porItem -eq 2) { Write-UiLinha '' }
            }
            Write-UiLinha $(if ($ini + $cabe -lt $n) { "     $($script:UiBaixo) mais itens abaixo" } else { '' }) 'DarkGray'
            $marc = @($lista | Where-Object { $_.On }).Count
            if ($sel -eq $n) { Write-UiLinha ("   $($script:UiSeta) >> $Concluir   ($marc marcado(s))").PadRight(72) 'Black' 'Green' }
            else { Write-UiLinha "     >> $Concluir   ($marc marcado(s))" 'Green' }
            Write-UiLinha ''
            if ($temDesc) {
                $dd = if ($sel -lt $n) { [string]$lista[$sel].D } else { 'Confirma as escolhas e continua.' }
                Write-UiCaixaDesc $dd
            }
            $dica = "  $($script:UiCima) $($script:UiBaixo) mover   ESPACO/ENTER marcar   ESC cancelar"
            if (-not $SemTodos) { $dica += '   T todos   N nenhum' }
            Write-UiLinha $dica 'DarkCyan'
            Write-UiLinha ''
            $k = Read-UiTecla
            if ($null -eq $k) { $topo = Get-UiTopo 0 -Forcar; continue }
            switch ($k.Key) {
                'UpArrow'   { $sel = ($sel - 1 + $n + 1) % ($n + 1) }
                'DownArrow' { $sel = ($sel + 1) % ($n + 1) }
                'PageUp'    { $sel = [math]::Max(0, $sel - 10) }
                'PageDown'  { $sel = [math]::Min($n, $sel + 10) }
                'Home'      { $sel = 0 }
                'End'       { $sel = $n }
                'Escape'    { return $null }
                'Spacebar'  { if ($sel -lt $n -and -not $lista[$sel].Bloq) { $lista[$sel].On = -not $lista[$sel].On } }
                'Enter'     {
                    if ($sel -eq $n) { return @($lista | Where-Object { $_.On } | ForEach-Object { $_.K }) }
                    if (-not $lista[$sel].Bloq) { $lista[$sel].On = -not $lista[$sel].On }
                }
                default {
                    $ch = ([string]$k.KeyChar).ToUpper()
                    if (-not $SemTodos -and $ch -eq 'T') { foreach ($x in $lista) { if (-not $x.Bloq) { $x.On = $true } } }
                    if (-not $SemTodos -and $ch -eq 'N') { foreach ($x in $lista) { $x.On = $false } }
                }
            }
        }
    } finally {
        try { [Console]::CursorVisible = $true } catch {}
        $script:UiInicioLinha = $true
    }
}

# Sim / Nao com setas. Devolve $true ou $false.
function Select-SimNao([string]$Pergunta, [bool]$Padrao = $true) {
    if (-not (Test-UiTeclas)) {
        $r = Read-Host "  $Pergunta (S/N)"
        return ($r -match '^[sSyY]')
    }
    $sim = $Padrao
    $topo = Get-UiTopo 3
    Write-UiLinha ''
    Write-UiLinha "  $Pergunta" 'White'
    $topo = [Console]::CursorTop
    try { [Console]::CursorVisible = $false } catch {}
    try {
        while ($true) {
            [Console]::SetCursorPosition(0, $topo)
            $u = Get-UiUtil
            if ($u.Pad) { Microsoft.PowerShell.Utility\Write-Host $u.Pad -NoNewline }
            Microsoft.PowerShell.Utility\Write-Host '     ' -NoNewline
            if ($sim) { Microsoft.PowerShell.Utility\Write-Host '   SIM   ' -ForegroundColor Black -BackgroundColor Green -NoNewline }
            else { Microsoft.PowerShell.Utility\Write-Host '   Sim   ' -ForegroundColor Gray -NoNewline }
            Microsoft.PowerShell.Utility\Write-Host '    ' -NoNewline
            if (-not $sim) { Microsoft.PowerShell.Utility\Write-Host '   NAO   ' -ForegroundColor White -BackgroundColor DarkRed -NoNewline }
            else { Microsoft.PowerShell.Utility\Write-Host '   Nao   ' -ForegroundColor Gray -NoNewline }
            $txt = "     $($script:UiEsq) $($script:UiDir) e ENTER   (ou S / N)"
            $r = $u.Resto - 27 - $txt.Length
            Microsoft.PowerShell.Utility\Write-Host $txt -ForegroundColor DarkCyan -NoNewline
            if ($r -gt 0) { Microsoft.PowerShell.Utility\Write-Host (' ' * $r) -NoNewline }
            Microsoft.PowerShell.Utility\Write-Host ''
            $k = Read-UiTecla
            if ($null -eq $k) { $topo = Get-UiTopo 0 -Forcar; Write-UiLinha "  $Pergunta" 'White'; $topo = [Console]::CursorTop; continue }
            switch ($k.Key) {
                'LeftArrow'  { $sim = -not $sim }
                'RightArrow' { $sim = -not $sim }
                'UpArrow'    { $sim = -not $sim }
                'DownArrow'  { $sim = -not $sim }
                'Tab'        { $sim = -not $sim }
                'Enter'      { return $sim }
                'Escape'     { return $false }
                default {
                    $ch = ([string]$k.KeyChar).ToUpper()
                    if ($ch -eq 'S' -or $ch -eq 'Y') { return $true }
                    if ($ch -eq 'N') { return $false }
                }
            }
        }
    } finally {
        try { [Console]::CursorVisible = $true } catch {}
        $script:UiInicioLinha = $true
    }
}
