# =====================================================================
#  AVANTIPACK - reaplicar apos atualizacao do Windows, manutencao
#  semanal (tarefa agendada) e atualizacao automatica pelo GitHub.
#  Carregado por avanti.ps1 (dot-source). Sem acentos de proposito.
# =====================================================================

$SelFile    = Join-Path $DataDir 'ultima_selecao.txt'
$BuildFile  = Join-Path $DataDir 'build_aplicado.txt'
$UpdFile    = Join-Path $DataDir 'checagem_atualizacao.txt'
$TaskName   = 'AVANTIPACK Manutencao'

function Get-PackVersion {
    $f = Join-Path $PSScriptRoot 'VERSION.txt'
    if (Test-Path $f) { return ((Get-Content $f -TotalCount 1) -replace '[^\d\.]', '') }
    return '0.0.0'
}

function Get-PackConfig {
    $cfg = @{ GITHUB_REPO = ''; CHECAR_ATUALIZACAO = '1' }
    $f = Join-Path $PSScriptRoot 'config.txt'
    foreach ($l in Get-Content $f -ErrorAction SilentlyContinue) {
        if ($l -match '^\s*#' -or $l -notmatch '=') { continue }
        $i = $l.IndexOf('='); $cfg[$l.Substring(0, $i).Trim()] = $l.Substring($i + 1).Trim()
    }
    return $cfg
}

function Get-WinBuild {
    $k = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Build = [string]$k.CurrentBuild; Completo = ("{0}.{1}" -f $k.CurrentBuild, $k.UBR) }
}

# ---------------------------------------------------------------------
#  Reaplicar depois de atualizacao do Windows
# ---------------------------------------------------------------------
function Save-UltimaSelecao($sel) {
    $ids = @($sel.Keys | Where-Object { $sel[$_] } | Sort-Object)
    Set-Content -Path $SelFile -Value ($ids -join ',') -Encoding ASCII
    Set-Content -Path $BuildFile -Value (Get-WinBuild).Build -Encoding ASCII
}

function Get-UltimaSelecao {
    if (-not (Test-Path $SelFile)) { return $null }
    $sel = @{}
    foreach ($i in ((Get-Content $SelFile -TotalCount 1) -split ',')) { if ($i.Trim()) { $sel[$i.Trim()] = $true } }
    return $sel
}

function Test-PrecisaReaplicar {
    if (-not (Test-Path $SelFile) -or -not (Test-Path $BuildFile)) { return $false }
    $antes = (Get-Content $BuildFile -TotalCount 1).Trim()
    return ($antes -and $antes -ne (Get-WinBuild).Build)
}

function Mod-Reaplicar {
    $sel = Get-UltimaSelecao
    if (-not $sel) { Write-Skip 'Voce ainda nao otimizou este PC pelo pack (use a opcao 1).'; return }
    Write-Title 'REAPLICAR AS OTIMIZACOES'
    if (Test-PrecisaReaplicar) {
        Write-Warn 'O Windows foi atualizado desde a ultima otimizacao.'
        Write-Note 'Atualizacoes grandes do Windows desfazem parte dos ajustes e reinstalam apps.'
    }
    Write-Note 'Vai aplicar de novo exatamente o que voce escolheu da ultima vez:'
    Show-Resumo $sel
    Write-Host ''
    if (-not (Confirm-Step 'Reaplicar agora?')) { return }
    Invoke-Selecao $sel
    Save-UltimaSelecao $sel
    Write-Caixa @('Otimizacoes reaplicadas.', 'Reinicie o PC para concluir.') 'Green'
    $script:NeedReboot = $true
}

# ---------------------------------------------------------------------
#  Manutencao semanal (roda escondida pela tarefa agendada)
# ---------------------------------------------------------------------
# ---------------------------------------------------------------------
#  Atualizacao automatica pelo GitHub (Releases)
# ---------------------------------------------------------------------
function Get-UltimaVersaoGitHub([switch]$UsarCache) {
    $cfg = Get-PackConfig
    if (-not $cfg.GITHUB_REPO -or $cfg.CHECAR_ATUALIZACAO -eq '0') { return $null }
    if ($UsarCache -and (Test-Path $UpdFile)) {
        $c = (Get-Content $UpdFile -TotalCount 1) -split '\|'
        if ($c.Count -ge 2) {
            $quando = [datetime]::MinValue
            if ([datetime]::TryParse($c[0], [ref]$quando) -and ((Get-Date) - $quando).TotalHours -lt 12) { return $c[1] }
        }
    }
    try {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
        $rel = Invoke-RestMethod -Uri ("https://api.github.com/repos/{0}/releases/latest" -f $cfg.GITHUB_REPO) -Headers @{ 'User-Agent' = 'AVANTIPACK' } -TimeoutSec 4 -UseBasicParsing
        $tag = ([string]$rel.tag_name) -replace '[^\d\.]', ''
        Set-Content -Path $UpdFile -Value ((Get-Date -Format s) + '|' + $tag) -Encoding ASCII
        return $tag
    } catch { return $null }
}

function Test-VersaoMaior([string]$a, [string]$b) {
    try { return ([version]($a + '.0.0' -replace '^(\d+\.\d+\.\d+).*', '$1')) -gt ([version]($b + '.0.0' -replace '^(\d+\.\d+\.\d+).*', '$1')) } catch { return $false }
}

function Start-AvantiPack {
    foreach ($c in @((Join-Path $Root 'AVANTIPACK.exe'), (Join-Path $PSScriptRoot 'AVANTIPACK.bat'), (Join-Path $Root 'AVANTIPACK.bat'))) {
        if (Test-Path $c) { Start-Process $c; return }
    }
}

function Mod-Atualizar {
    $script:CurMod = 'atualizar'
    Start-Sleep -Seconds 2   # espera o menu (AVANTIPACK.bat) fechar
    $cfg = Get-PackConfig
    Write-Title 'ATUALIZAR O AVANTIPACK'
    if (-not $cfg.GITHUB_REPO) {
        Write-Warn 'A atualizacao automatica ainda nao foi configurada neste pack.'
        Write-Note 'Quem distribui o pack precisa colocar o repositorio em core\config.txt (veja guias\GITHUB_PASSO_A_PASSO.txt).'
        Read-Host '  ENTER para voltar ao menu' | Out-Null
        Start-AvantiPack; return
    }
    $atual = Get-PackVersion
    $nova = Get-UltimaVersaoGitHub
    if (-not $nova) { Write-Warn 'Nao consegui falar com o GitHub (sem internet?).'; Read-Host '  ENTER' | Out-Null; Start-AvantiPack; return }
    if (-not (Test-VersaoMaior $nova $atual)) {
        Write-Ok "Voce ja tem a versao mais nova ($atual)."
        Read-Host '  ENTER para voltar ao menu' | Out-Null
        Start-AvantiPack; return
    }
    Write-Info "Versao instalada: $atual   ->   nova: $nova"
    Write-Note 'Seus backups, logs e configuracoes NAO sao apagados.'
    if (-not (Confirm-Step 'Atualizar agora?')) { Start-AvantiPack; return }
    try {
        $rel = Invoke-RestMethod -Uri ("https://api.github.com/repos/{0}/releases/latest" -f $cfg.GITHUB_REPO) -Headers @{ 'User-Agent' = 'AVANTIPACK' } -UseBasicParsing
        $asset = $rel.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
        $url = if ($asset) { $asset.browser_download_url } else { $rel.zipball_url }
        $tmp = Join-Path $env:TEMP ('avanti_upd_' + [IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $zip = Join-Path $tmp 'nova.zip'
        Write-Info 'Baixando a nova versao...'
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -Headers @{ 'User-Agent' = 'AVANTIPACK' }
        Expand-Archive -Path $zip -DestinationPath (Join-Path $tmp 'x') -Force
        $bat = Get-ChildItem (Join-Path $tmp 'x') -Recurse -Filter 'avanti.ps1' | Where-Object { $_.Directory.Name -eq 'core' } | Select-Object -First 1
        if (-not $bat) { throw 'o arquivo baixado nao parece ser o AVANTIPACK' }
        $src = $bat.Directory.Parent.FullName
        $cfgPath = Join-Path $PSScriptRoot 'config.txt'
        $cfgLocal = if (Test-Path $cfgPath) { Get-Content $cfgPath -Raw } else { $null }
        foreach ($it in Get-ChildItem $src -Force) {
            if (@('backup', 'logs', 'data', 'dados', '.git', 'docs', 'ferramentas', 'README.md', 'CLAUDE.md', '.gitignore', '.gitattributes', 'AVANTIPACK.lnk', 'ABRIR AVANTIPACK.lnk') -contains $it.Name) { continue }
            Copy-Item -Path $it.FullName -Destination $Root -Recurse -Force
        }
        # mantem a configuracao local (repositorio etc.)
        if ($cfgLocal) { Set-Content -Path $cfgPath -Value $cfgLocal -NoNewline -Encoding ASCII }
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $UpdFile -Force -ErrorAction SilentlyContinue
        Write-Caixa @("AVANTIPACK atualizado para a versao $nova!", 'O menu vai abrir de novo.') 'Green'
        Write-Log "Atualizado de $atual para $nova"
    } catch {
        Write-Warn "Falha na atualizacao: $($_.Exception.Message)"
        Write-Note 'Nada foi perdido. Baixe a versao nova manualmente no GitHub do pack.'
    }
    Start-Sleep -Seconds 2
    Start-AvantiPack
}

# Informacoes rapidas para o topo do menu
function Get-StatusExtra($hw) {
    if (Test-PrecisaReaplicar) { $hw.REAPLICAR = '1' }
    $vcs = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'NVIDIA|Radeon|Arc' -and $_.DriverDate })
    foreach ($v in $vcs) {
        $dias = [int]((Get-Date) - $v.DriverDate).TotalDays
        if ($dias -gt 240) { $hw.AVISO = "Driver de video com $dias dias: atualize (opcao 4, Programas uteis)" }
    }
    $nova = Get-UltimaVersaoGitHub -UsarCache
    if ($nova -and (Test-VersaoMaior $nova (Get-PackVersion))) { $hw.ATUALIZACAO = $nova }
    $hw.VERSAO = Get-PackVersion
}

# ---------------------------------------------------------------------
#  Novidades (NOVIDADES.md): mostra a parte da versao atual
# ---------------------------------------------------------------------
$NovFile = Join-Path $DataDir 'novidades_vistas.txt'
function Show-Novidades([int]$Versoes = 1) {
    $arq = Join-Path $PSScriptRoot 'NOVIDADES.md'
    if (-not (Test-Path $arq)) { Write-Skip 'Arquivo NOVIDADES.md nao encontrado.'; return }
    $n = 0
    foreach ($l in (Get-Content $arq -Encoding UTF8)) {
        if ($l -match '^##\s+(.+)$') {
            $n++; if ($n -gt $Versoes) { break }
            Write-Host ''
            Write-Host ('  ' + $Matches[1] + '  ') -ForegroundColor Black -BackgroundColor Cyan
        } elseif ($n -ge 1 -and $l -match '^\s*-\s+(.+)$') {
            $t = $Matches[1] -replace '\*\*', ''
            $t = ($t -replace '^[^\p{L}\p{N}"(]+', '')    # tira o emoji do comeco (o CMD nao mostra bem)
            Write-Host '   > ' -ForegroundColor Cyan -NoNewline; Write-Host $t
        }
    }
}
function Mod-Novidades([switch]$Auto) {
    $v = Get-PackVersion
    if ($Auto) {
        $visto = if (Test-Path $NovFile) { (Get-Content $NovFile -TotalCount 1) } else { $null }
        if ($visto -eq $v) { return }
        # primeira vez num pack novo (nunca usado): so marca, sem mostrar
        $usado = (Test-Path $BackupFile) -or @(Get-ChildItem $LogDir -ErrorAction SilentlyContinue).Count -gt 1
        New-Item -ItemType Directory -Path (Split-Path $NovFile) -Force | Out-Null
        Set-Content -Path $NovFile -Value $v -Encoding ASCII
        if (-not $visto -and -not $usado) { return }
        Clear-Host
        Write-Title "NOVIDADES: O AVANTIPACK FOI ATUALIZADO PARA A v$v"
        Show-Novidades 1
    } else {
        Write-Title 'NOVIDADES DO AVANTIPACK'
        Show-Novidades 3
    }
    Write-Host ''
    Write-Note 'Lista completa: core\NOVIDADES.md'
    Write-Host ''
    Read-Host '  ENTER para continuar' | Out-Null
}
