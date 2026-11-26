# =====================================================================
#  AVANTIPACK - modo app
#  Quando o AVANTIPACK Pro roda uma funcao, ele abre um canal (named pipe)
#  e passa o nome em AVP_CANAL. Aqui o motor troca a "tela de console"
#  por mensagens (titulo, OK, aviso, pergunta, lista de marcar...) que o
#  app desenha com os proprios cartoes e botoes. As respostas voltam pelo
#  mesmo canal. Sem o canal (versao antiga do app ou janela normal), nada
#  muda: tudo continua no console como antes.
#  Carregado por avanti.ps1 (dot-source), DEPOIS de ui.ps1. Sem acentos.
# =====================================================================

$script:AppW = $null; $script:AppR = $null
$script:AppLinha = New-Object System.Collections.ArrayList

function Connect-App {
    $nome = [Environment]::GetEnvironmentVariable('AVP_CANAL')
    # so este processo usa o canal (programas abertos daqui nao herdam)
    [Environment]::SetEnvironmentVariable('AVP_CANAL', $null)
    if (-not $nome -or $nome -notmatch '^avp_[0-9a-f]{32}$') { return $false }
    try {
        $p = New-Object IO.Pipes.NamedPipeClientStream('.', $nome, [IO.Pipes.PipeDirection]::InOut)
        $p.Connect(4000)
        $enc = New-Object Text.UTF8Encoding($false)
        $script:AppW = New-Object IO.StreamWriter($p, $enc)
        $script:AppW.AutoFlush = $true
        $script:AppR = New-Object IO.StreamReader($p, $enc)
        return $true
    } catch { $script:AppW = $null; return $false }
}

function Send-App($obj) {
    if (-not $script:AppW) { return }
    try { $script:AppW.WriteLine(($obj | ConvertTo-Json -Compress -Depth 6)) } catch {}
}
function Read-App {
    try { $r = $script:AppR.ReadLine(); if ($null -eq $r) { exit 1 }; return $r } catch { exit 1 }
}

if (Connect-App) {
    # --- textos
    function Write-Host {
        param([Parameter(Position = 0, ValueFromRemainingArguments = $true)]$Object,
              [switch]$NoNewline, [System.ConsoleColor]$ForegroundColor, [System.ConsoleColor]$BackgroundColor, $Separator = ' ')
        $txt = if ($null -eq $Object) { '' } else { (@($Object) | ForEach-Object { "$_" }) -join $Separator }
        $cor = if ($PSBoundParameters.ContainsKey('ForegroundColor')) { [string]$ForegroundColor } else { '' }
        if ($txt.Length) { [void]$script:AppLinha.Add(@{ t = $txt; c = $cor }) }
        if (-not $NoNewline) {
            Send-App @{ e = 'linha'; s = @($script:AppLinha) }
            $script:AppLinha.Clear()
        }
    }
    function Clear-Host { Send-App @{ e = 'limpar' } }
    function Write-Title([string]$m) { $script:UiUltimoTitulo = $m; Send-App @{ e = 'titulo'; t = $m }; Write-Log "== $m ==" }
    function Write-Info([string]$m) { Send-App @{ e = 'info'; t = $m }; Write-Log $m }
    function Write-Ok([string]$m)   { Send-App @{ e = 'ok'; t = $m }; Write-Log "OK $m" }
    function Write-Warn([string]$m) { Send-App @{ e = 'aviso'; t = $m }; Write-Log "AVISO $m"; $script:Avisos++ }
    function Write-Skip([string]$m) { Send-App @{ e = 'pulado'; t = $m }; Write-Log "PULADO $m" }
    function Write-Note([string]$m) { Send-App @{ e = 'nota'; t = $m.Trim() } }
    function Write-Caixa([string[]]$linhas, [string]$cor = 'Green') { Send-App @{ e = 'caixa'; l = @($linhas); cor = $cor } }
    function Write-Etapa([int]$n, [int]$total, [string]$nome) { Send-App @{ e = 'etapa'; n = $n; total = $total; t = $nome } }
    function Write-Cabecalho { }

    # --- perguntas (a resposta volta pelo canal)
    function Confirm-Step([string]$q, $Auto = $null) {
        if ($script:AutoMode -and $Auto -ne $null) {
            Send-App @{ e = 'auto'; t = $q; r = [bool]$Auto }
            Write-Log "AUTO $q -> $Auto"
            return [bool]$Auto
        }
        return (Select-SimNao $q ($Auto -ne $false))
    }
    function Select-SimNao([string]$Pergunta, [bool]$Padrao = $true) {
        Send-App @{ e = 'sn'; q = $Pergunta; padrao = $Padrao }
        $r = Read-App
        Write-Log "PERGUNTA $Pergunta -> $r"
        return ($r -eq 's')
    }
    function Select-Opcao {
        param([array]$Itens, [string]$Voltar = 'Voltar', [int]$Inicio = 0, [string]$Dica = '')
        $l = @($Itens | ForEach-Object { @{ k = [string]$_.K; t = [string]$_.T; d = [string]$_.D; c = [string]$_.C } })
        Send-App @{ e = 'opcoes'; titulo = [string]$script:UiUltimoTitulo; itens = $l; voltar = $Voltar; inicio = $Inicio }
        $r = Read-App
        if (-not $r) { return '0' }
        return $r
    }
    function Select-Varios {
        param([array]$Itens, [string]$Concluir = 'CONCLUIR', [switch]$SemTodos)
        $l = @($Itens | ForEach-Object { @{ k = [string]$_.K; t = [string]$_.T; d = [string]$_.D; on = [bool]$_.On } })
        Send-App @{ e = 'marcar'; itens = $l; concluir = $Concluir }
        $r = Read-App
        if ($r -eq '<cancelar>') { return $null }
        if (-not $r) { return @() }
        return @($r.Split([char]0x1F) | Where-Object { $_ -ne '' })
    }
    function Read-Host {
        param([Parameter(Position = 0)]$Prompt)
        $q = if ($null -eq $Prompt) { '' } else { ([string]$Prompt).Trim() }
        # "ENTER para continuar": vira um botao Continuar
        if ($q -match 'ENTER para') { Send-App @{ e = 'continuar'; q = $q }; [void](Read-App); return '' }
        Send-App @{ e = 'texto'; q = $q }
        return (Read-App)
    }
    Send-App @{ e = 'pronto' }
}
