# =====================================================================
#  AVANTIPACK - apps: lista, tutoriais e download automatico
#  Fontes (coluna 6 do apps\apps.txt):
#    incluso                  -> ja vem dentro do pack (licenca permite)
#    winget:<Id>              -> instala pelo winget (repositorio oficial MS)
#    zip:<url>                -> baixa o ZIP oficial e extrai na pasta do app
#    github:<dono>/<repo>     -> baixa o ZIP da ultima versao no GitHub
#    site                     -> so abre o site oficial (drivers)
#  Ids do winget conferidos em github.com/microsoft/winget-pkgs.
# =====================================================================

function Test-AppMatch([string]$para, $hw) {
    switch ($para) {
        'TODOS'      { return $true }
        'GPU-NVIDIA' { return $hw.GPU_VENDOR -eq 'NVIDIA' }
        'GPU-AMD'    { return $hw.GPU_VENDOR -like 'AMD*' }
        'GPU-INTEL'  { return $hw.GPU_VENDOR -like 'INTEL*' }
        'CPU-AMD'    { return $hw.CPU_VENDOR -eq 'AMD' }
        'CPU-INTEL'  { return $hw.CPU_VENDOR -eq 'INTEL' }
        default      { return $true }
    }
}

function Get-AppList {
    $listFile = Join-Path $Root 'apps\apps.txt'
    if (-not (Test-Path $listFile)) { return @() }
    return @(Get-Content $listFile | Where-Object { $_.Trim() -and $_ -notmatch '^\s*#' } | ForEach-Object {
        $f = @($_.Split('|') | ForEach-Object { $_.Trim() })
        while ($f.Count -lt 8) { $f += '' }
        [pscustomobject]@{ Nome = $f[0]; Para = $f[1]; Pasta = $f[2]; Exe = $f[3]; Url = $f[4]; Fonte = $f[5]; Auto = ($f[6] -eq 'auto')
                           Padrao = @($f[7].Split(';') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    })
}

# Procura o executavel: pasta do app > Arquivos de Programas > AppData\Programs
function Resolve-AppExe($app) {
    if (-not $app.Exe) { return $null }
    $e = [Environment]::ExpandEnvironmentVariables($app.Exe)
    if ([System.IO.Path]::IsPathRooted($e)) {
        $f = Get-Item -Path $e -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { return $f.FullName }
        $e = Split-Path $e -Leaf
    }
    $dir = Join-Path $Root ('apps\' + $app.Pasta)
    if (Test-Path $dir) {
        $f = Get-ChildItem -Path $dir -Recurse -Filter $e -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    $bases = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs')) | Where-Object { $_ -and (Test-Path $_) }
    foreach ($b in $bases) {
        foreach ($pat in @("$b\*\$e", "$b\*\*\$e")) {
            $f = Get-Item -Path $pat -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($f) { return $f.FullName }
        }
    }
    return $null
}

function Initialize-Web {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
}

function Test-Winget {
    return [bool](Get-Command winget.exe -ErrorAction SilentlyContinue)
}

# Baixa/instala UM app. Retorna $true se ficou pronto.
function Install-App($app) {
    $dir = Join-Path $Root ('apps\' + $app.Pasta)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $fonte = $app.Fonte
    try {
        if ($fonte -like 'winget:*') {
            if (-not (Test-Winget)) { Write-Warn 'winget nao encontrado (instale o "Instalador de Aplicativo" pela Microsoft Store).'; return $false }
            $id = $fonte.Substring(7)
            Write-Info "Instalando $($app.Nome) pelo winget ($id)..."
            & winget.exe install --id $id -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 |
                Where-Object { $_ -match 'Successfully|instalado|Found|Encontrado|already|ja' } | ForEach-Object { Write-Note $_ }
        }
        elseif ($fonte -like 'zip:*' -or $fonte -like 'github:*') {
            Initialize-Web
            if ($fonte -like 'github:*') {
                $repo = $fonte.Substring(7)
                $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'AVANTIPACK' } -UseBasicParsing
                $asset = $rel.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
                if (-not $asset) { Write-Warn "Nenhum ZIP na ultima versao de $repo."; return $false }
                $url = $asset.browser_download_url
            } else { $url = $fonte.Substring(4) }
            $tmp = Join-Path $env:TEMP ('avanti_' + [IO.Path]::GetRandomFileName() + '.zip')
            Write-Info "Baixando $($app.Nome)..."
            Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -Headers @{ 'User-Agent' = 'AVANTIPACK' }
            Expand-Archive -Path $tmp -DestinationPath $dir -Force
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
        elseif ($fonte -eq 'incluso') { }
        else { return $false }
    } catch {
        Write-Warn "Falha ao obter $($app.Nome): $($_.Exception.Message)"
        return $false
    }
    $exe = Resolve-AppExe $app
    if ($exe) { Write-Ok "$($app.Nome) pronto: $exe"; Write-Log "APP pronto $($app.Nome) $exe"; return $true }
    Write-Warn "$($app.Nome): instalado, mas o executavel nao foi localizado automaticamente."
    return $false
}

function Install-RecommendedApps($hw) {
    Write-Title 'BAIXAR / INSTALAR APPS RECOMENDADOS PARA ESTE PC'
    $apps = Get-AppList | Where-Object { $_.Auto -and (Test-AppMatch $_.Para $hw) }
    $faltam = @($apps | Where-Object { -not (Resolve-AppExe $_) })
    if ($faltam.Count -eq 0) { Write-Ok 'Todos os apps recomendados ja estao prontos.'; return }
    Write-Note 'Vai baixar SEMPRE das fontes oficiais (winget da Microsoft, GitHub e sites dos autores):'
    foreach ($a in $faltam) { Write-Note "  - $($a.Nome)" }
    if (-not (Confirm-Step 'Continuar?')) { return }
    $ok = 0
    foreach ($a in $faltam) { if (Install-App $a) { $ok++ } }
    Write-Ok "$ok de $($faltam.Count) app(s) prontos."
}

# Instalador que ja esta DENTRO da pasta do app (baixado pela opcao T)
function Resolve-AppInstaller($app) {
    $dir = Join-Path $Root ('apps\' + $app.Pasta)
    if (-not (Test-Path $dir)) { return $null }
    $f = Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue |
         Where-Object { $_.Extension -in '.exe', '.msi', '.msix', '.msixbundle', '.appxbundle' } |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($f) { return $f.FullName }
    return $null
}

# Baixa TODOS os apps para dentro de apps\<pasta> (para levar o pack completo).
# winget download = baixa o instalador oficial sem instalar (winget 1.8+).
function Save-AllAppsToFolders {
    Write-Title 'BAIXAR TODOS OS APPS PARA DENTRO DO PACK'
    Write-Note 'Baixa os arquivos oficiais para as pastas apps\<app>, SEM instalar no seu PC.'
    Write-Note 'Depois e so zipar a pasta AVANTIPACK e mandar: os apps ja vao junto.'
    Write-Note 'Lembrete: DDU, HWiNFO, Process Lasso e Autoruns pedem para nao redistribuir.'
    if (-not (Confirm-Step 'Comecar o download de todos?')) { return }
    $temWg = Test-Winget
    if ($temWg) {
        $v = [string](& winget.exe --version 2>$null)
        $m = [regex]::Match($v, '(\d+)\.(\d+)')
        if ($m.Success -and [int]$m.Groups[1].Value -le 1 -and [int]$m.Groups[2].Value -lt 8) {
            $temWg = $false
            Write-Warn "winget $v e antigo (precisa 1.8+). Atualize o 'Instalador de Aplicativo' na Microsoft Store."
        }
    } else { Write-Warn 'winget nao encontrado: os apps do winget serao pulados.' }
    $ok = 0; $falha = @()
    foreach ($a in Get-AppList) {
        $dir = Join-Path $Root ('apps\' + $a.Pasta)
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        if ($a.Fonte -eq 'incluso') { Write-Skip "$($a.Nome): ja vem no pack."; continue }
        if ($a.Fonte -eq 'site' -or -not $a.Fonte) { Write-Skip "$($a.Nome): driver, baixe na hora pelo site (muda toda semana)."; continue }
        if ((Resolve-AppInstaller $a) -or ($a.Exe -and (Get-ChildItem $dir -Recurse -Filter ([IO.Path]::GetFileName([Environment]::ExpandEnvironmentVariables($a.Exe))) -ErrorAction SilentlyContinue | Select-Object -First 1))) {
            Write-Skip "$($a.Nome): ja esta na pasta."; $ok++; continue
        }
        try {
            if ($a.Fonte -like 'winget:*') {
                if (-not $temWg) { $falha += $a.Nome; continue }
                $id = $a.Fonte.Substring(7)
                Write-Info "Baixando $($a.Nome) ($id)..."
                $out = & winget.exe download --id $id -e -d $dir --accept-package-agreements --accept-source-agreements --disable-interactivity --skip-dependencies 2>&1 | Out-String
                Write-Log $out
                Get-ChildItem $dir -Filter '*.yaml' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                if (Resolve-AppInstaller $a) { Write-Ok "$($a.Nome): salvo em apps\$($a.Pasta)"; $ok++ } else { $falha += $a.Nome }
            } elseif ($a.Fonte -like 'zip:*' -or $a.Fonte -like 'github:*') {
                if (Install-App $a) { $ok++ } else { $falha += $a.Nome }
            }
        } catch { Write-Warn "$($a.Nome): $($_.Exception.Message)"; $falha += $a.Nome }
    }
    Write-Host ''
    Write-Ok "$ok app(s) prontos dentro do pack."
    if ($falha.Count) { Write-Warn ('Nao baixados: ' + ($falha -join ', ') + '. Use os sites oficiais do menu.') }
}

# ---------------------------------------------------------------------
#  Captura automatica do download (site oficial -> pasta Downloads -> apps\<Pasta>)
# ---------------------------------------------------------------------
function Get-DownloadsFolder {
    try {
        $p = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
        if ($p -and (Test-Path $p)) { return $p }
    } catch {}
    $k = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction SilentlyContinue).'{374DE290-123F-4565-9164-39C4925E467B}'
    if ($k) { $k = [Environment]::ExpandEnvironmentVariables($k); if (Test-Path $k) { return $k } }
    return (Join-Path $env:USERPROFILE 'Downloads')
}

function Test-ArquivoPronto([string]$Path) {
    try {
        $a = (Get-Item -LiteralPath $Path -ErrorAction Stop).Length
        Start-Sleep -Milliseconds 1200
        $b = (Get-Item -LiteralPath $Path -ErrorAction Stop).Length
        if ($a -ne $b -or $b -eq 0) { return $false }
        $fs = [System.IO.File]::Open($Path, 'Open', 'Read', 'None'); $fs.Close()
        return $true
    } catch { return $false }
}

function Move-ParaPastaApp($app, [string]$Arquivo) {
    $dir = Join-Path $Root ('apps\' + $app.Pasta)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $dest = Join-Path $dir ([IO.Path]::GetFileName($Arquivo))
    Move-Item -LiteralPath $Arquivo -Destination $dest -Force
    $ext = [IO.Path]::GetExtension($dest).ToLower()
    if ($ext -eq '.zip') {
        try { Expand-Archive -LiteralPath $dest -DestinationPath $dir -Force; Remove-Item -LiteralPath $dest -Force; Write-Ok 'ZIP extraido na pasta do app.' }
        catch { Write-Warn "Nao consegui extrair o ZIP: $($_.Exception.Message)" }
    } elseif ($ext -in '.7z', '.rar') {
        # Windows 11 23H2+ abre 7z/rar com o tar nativo
        & tar.exe -xf $dest -C $dir 2>$null
        if ($LASTEXITCODE -eq 0) { Remove-Item -LiteralPath $dest -Force; Write-Ok 'Arquivo extraido na pasta do app.' }
        else { Write-Note 'Extraia esse arquivo com o 7-Zip/WinRAR dentro da propria pasta.' }
    }
    return $dir
}

function Wait-AppDownload($app, [int]$Minutos = 15) {
    $dl = Get-DownloadsFolder
    $inicio = Get-Date
    $antes = @{}
    foreach ($f in Get-ChildItem -LiteralPath $dl -File -ErrorAction SilentlyContinue) { $antes[$f.FullName] = $f.LastWriteTime }
    $temp = '\.(crdownload|part|partial|download|tmp|opdownload)$'
    $okExt = '\.(exe|msi|zip|7z|rar|msix|msixbundle)$'
    Write-Host ''
    Write-Host '  AGUARDANDO O DOWNLOAD...' -ForegroundColor Cyan
    Write-Note "Baixe o arquivo no site que abriu. Assim que terminar, o pack pega ele sozinho da pasta:"
    Write-Note "  $dl"
    Write-Note "e coloca em apps\$($app.Pasta).   (ESC cancela a espera)"
    $spin = '|/-\'; $i = 0
    while (((Get-Date) - $inicio).TotalMinutes -lt $Minutos) {
        $esc = $false
        try { if ([Console]::KeyAvailable) { $k = [Console]::ReadKey($true); if ($k.Key -eq 'Escape') { $esc = $true } } } catch {}
        if ($esc) { Write-Host ''; Write-Skip 'Espera cancelada.'; return $null }
        $novos = @(Get-ChildItem -LiteralPath $dl -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -notmatch $temp -and $_.Name -match $okExt -and
            ((-not $antes.ContainsKey($_.FullName)) -or $antes[$_.FullName] -ne $_.LastWriteTime) })
        $baixando = @(Get-ChildItem -LiteralPath $dl -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $temp -and $_.LastWriteTime -gt $inicio }).Count
        foreach ($n in $novos) {
            $bate = $true
            if ($app.Padrao.Count) { $bate = $false; foreach ($pt in $app.Padrao) { if ($n.Name -like $pt) { $bate = $true } } }
            if (-not $bate) {
                Write-Host ''
                if (-not (Confirm-Step "Chegou o arquivo '$($n.Name)'. E o $($app.Nome)?")) { $antes[$n.FullName] = $n.LastWriteTime; continue }
            }
            if (Test-ArquivoPronto $n.FullName) {
                Write-Host ''
                $dir = Move-ParaPastaApp $app $n.FullName
                Write-Ok "Pronto! O arquivo ja esta na pasta: apps\$($app.Pasta)"
                return $dir
            }
        }
        $msg = if ($baixando) { 'baixando' } else { 'esperando' }
        Write-Host ("`r  {0} {1}...   " -f $spin[$i % 4], $msg) -NoNewline -ForegroundColor DarkCyan
        $i++
        Start-Sleep -Milliseconds 700
    }
    Write-Host ''
    Write-Warn 'Tempo de espera acabou. Se ja baixou, arraste o arquivo para a pasta do app que esta aberta.'
    return $null
}

function Show-AppDicas($app) {
    $dir = Join-Path $Root ('apps\' + $app.Pasta)
    $tut = Join-Path $dir 'LEIA-ME.txt'
    Write-Host ''
    Write-Host "  $($app.Nome)" -ForegroundColor White
    Write-Note "Pasta do app: apps\$($app.Pasta)"
    if (Test-Path $tut) {
        Write-Note 'As MELHORES CONFIGURACOES e o passo a passo deste app estao no LEIA-ME.txt dessa pasta.'
        Write-Note '(abrindo agora no Bloco de Notas)'
        Start-Process notepad.exe $tut
    }
}

function Start-AppFlow($app) {
    Show-AppDicas $app
    $dir = Join-Path $Root ('apps\' + $app.Pasta)
    $exe = Resolve-AppExe $app
    $ins = if (-not $exe) { Resolve-AppInstaller $app } else { $null }
    if ($exe) {
        if (Confirm-Step "O app ja esta pronto. Abrir $($app.Nome) agora?") { Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) }
        return
    }
    if ($ins) {
        Write-Ok "O instalador ja esta na pasta: $([IO.Path]::GetFileName($ins))"
        if (Confirm-Step 'Instalar agora?') { Start-Process -FilePath $ins -Wait; if (Resolve-AppExe $app) { Write-Ok 'Instalado.' } }
        return
    }
    Write-Host ''
    Write-Host '  Como voce quer pegar este app?' -ForegroundColor White
    $podeAuto = $app.Fonte -and $app.Fonte -notin @('site', 'incluso')
    if ($podeAuto) { Write-Host '  [1] Baixar automatico pelo pack (fonte oficial)' }
    Write-Host '  [2] Abrir o SITE OFICIAL e eu baixo (o pack pega o arquivo sozinho e coloca na pasta)'
    Write-Host '  [0] Voltar'
    $op = Read-Host '  Escolha'
    if ($op -eq '1' -and $podeAuto) { if (Install-App $app) { Write-Ok "Pronto. Siga o LEIA-ME (aberto) para configurar." }; return }
    if ($op -eq '2' -and $app.Url) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Start-Process $app.Url
        Start-Process explorer.exe $dir
        $ok = Wait-AppDownload $app
        if ($ok) {
            Start-Process explorer.exe $ok
            Write-Note 'Agora e so seguir o passo a passo do LEIA-ME (aberto no Bloco de Notas).'
            $ins = Resolve-AppInstaller $app
            $exe = Resolve-AppExe $app
            if ($exe -and (Confirm-Step "Abrir $($app.Nome) agora?")) { Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) }
            elseif ($ins -and (Confirm-Step 'Rodar o instalador agora?')) { Start-Process -FilePath $ins -Wait }
        }
    }
}

function Mod-Apps {
    $script:CurMod = 'apps'
    $hw = Load-HW
    $apps = Get-AppList
    if ($apps.Count -eq 0) { Write-Warn 'apps\apps.txt nao encontrado.'; return }
    while ($true) {
        Write-Title 'APPS E TUTORIAIS'
        Write-Note 'Branco = recomendado para o SEU hardware   Cinza = para outro hardware'
        Write-Host ''
        for ($i = 0; $i -lt $apps.Count; $i++) {
            $a   = $apps[$i]
            $exe = Resolve-AppExe $a
            $st  = if ($exe) { '[pronto]' } elseif (Resolve-AppInstaller $a) { '[instalador]' } elseif ($a.Fonte -eq 'site') { '[site]' } else { '[baixar]' }
            $cor = if (Test-AppMatch $a.Para $hw) { 'White' } else { 'DarkGray' }
            Write-Host ("  [{0,2}] {1,-34} {2,-11} {3}" -f ($i + 1), $a.Nome, $a.Para, $st) -ForegroundColor $cor
        }
        Write-Host ''
        Write-Host '  [B]  Baixar/instalar TODOS os recomendados para este PC' -ForegroundColor Green
        Write-Host '  [T]  Baixar TODOS os apps para DENTRO do pack (para mandar com tudo junto)' -ForegroundColor Cyan
        Write-Host ''
        $op = Read-Host '  Numero do app para ver o tutorial, B ou T (ENTER volta)'
        if (-not $op) { return }
        if ($op -match '^[bB]$') { Install-RecommendedApps $hw; continue }
        if ($op -match '^[tT]$') { Save-AllAppsToFolders; continue }
        if ($op -notmatch '^\d+$' -or [int]$op -lt 1 -or [int]$op -gt $apps.Count) { continue }
        Start-AppFlow $apps[[int]$op - 1]
        Write-Host ''
        Read-Host '  ENTER para voltar a lista' | Out-Null
    }
}
