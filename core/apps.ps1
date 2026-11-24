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
    $bases = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs'),
               (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages')) | Where-Object { $_ -and (Test-Path $_) }
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

# winget: no PowerShell de administrador ele as vezes nao esta no PATH
function Get-Winget {
    if ($script:WgExe) { return $script:WgExe }
    $c = Get-Command winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { $script:WgExe = $c.Source; return $script:WgExe }
    $cands = @("$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe") +
             @(Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | ForEach-Object { $_.FullName })
    foreach ($x in $cands) { if ($x -and (Test-Path -LiteralPath $x)) { $script:WgExe = $x; break } }
    return $script:WgExe
}
function Test-Winget { return [bool](Get-Winget) }
# --disable-interactivity so existe a partir do winget 1.4 (Windows 10 antigo tem o 1.2)
function Get-WingetExtra {
    if ($null -ne $script:WgExtra) { return $script:WgExtra }
    $script:WgExtra = @()
    try {
        $v = [string](& (Get-Winget) --version 2>$null)
        $m = [regex]::Match($v, '(\d+)\.(\d+)')
        if ($m.Success -and ([int]$m.Groups[1].Value -gt 1 -or [int]$m.Groups[2].Value -ge 4)) { $script:WgExtra = @('--disable-interactivity') }
    } catch {}
    return $script:WgExtra
}

# ---------------------------------------------------------------------
#  Depois de pronto: atalho na pasta do app + configuracao automatica
# ---------------------------------------------------------------------
function New-AppAtalho($app, [string]$exe) {
    $dir = Join-Path $Root ('apps\' + $app.Pasta)
    if ($exe -like "$dir*") { return }          # ja esta dentro da pasta
    try {
        $lnk = Join-Path $dir ("ABRIR " + $app.Pasta + ".lnk")
        $s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
        $s.TargetPath = $exe; $s.WorkingDirectory = (Split-Path $exe); $s.Save()
    } catch {}
}
function Set-AppConfig($app, [string]$exe) {
    $pasta = Split-Path $exe
    switch -Wildcard ($app.Pasta) {
        'HWiNFO' {
            # abre direto na tela de sensores (temperaturas), que e o que importa
            $ini = Join-Path $pasta 'HWiNFO64.INI'
            if (-not (Test-Path $ini)) {
                try { Set-Content -Path $ini -Encoding ASCII -Value "[Settings]`r`nSensorsOnly=1`r`nSummaryOnly=0`r`nShowWelcomeAndProgress=0" ; Write-Ok 'HWiNFO configurado para abrir direto nos sensores.' } catch {}
            }
        }
    }
}

function Get-WingetOk {
    if (-not (Test-Winget)) {
        Write-Warn 'O winget (instalador oficial da Microsoft) nao esta neste PC.'
        Write-Note 'Abra a Microsoft Store, procure "Instalador de Aplicativo" e clique em Atualizar/Obter.'
        return $false
    }
    return $true
}

# Abre o site oficial, espera o download, coloca na pasta e ja roda o instalador
function Get-AppPeloSite($app) {
    $dir = Join-Path $Root ('apps\' + $app.Pasta)
    Write-Host ''
    Write-Caixa @(
        "$($app.Nome): este precisa ser baixado no site oficial.",
        '',
        '1. O site vai abrir agora no seu navegador.',
        '2. Escolha o modelo da sua peca (se pedir) e clique em BAIXAR.',
        '3. NAO precisa fazer mais nada: o pack pega o arquivo da pasta',
        "   Downloads, coloca em apps\$($app.Pasta) e abre o instalador."
    ) 'Cyan'
    Start-Process $app.Url
    $ok = Wait-AppDownload $app
    if (-not $ok) { return $false }
    $ins = Resolve-AppInstaller $app
    if ($ins) {
        Write-Info 'Abrindo o instalador... siga as telas dele (normalmente: Avancar > Instalar).'
        Write-Note 'O pack espera o instalador fechar para continuar.'
        Start-Process -FilePath $ins -WorkingDirectory $dir -Wait
        Write-Ok "Instalacao de $($app.Nome) concluida."
    }
    return $true
}

# Deixa UM app pronto, de forma automatica:
#  1) ja instalado -> so cria o atalho na pasta do app
#  2) instalador ja na pasta -> roda
#  3) winget -> instala DENTRO de apps\<Pasta> (quando o instalador aceita)
#  4) zip/github -> extrai em apps\<Pasta>
#  5) site (drivers) -> abre o site, pega o download e roda o instalador
function Install-App($app) {
    $dir = Join-Path $Root ('apps\' + $app.Pasta)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $fonte = $app.Fonte
    $exe = Resolve-AppExe $app
    if (-not $exe) {
        try {
            $ins = Resolve-AppInstaller $app
            if ($ins -and $fonte -ne 'site') {
                Write-Info "Instalando $($app.Nome) com o instalador que ja esta na pasta..."
                Start-Process -FilePath $ins -WorkingDirectory $dir -Wait
            }
            elseif ($fonte -like 'winget:*') {
                if (-not (Get-WingetOk)) { return $false }
                $id = $fonte.Substring(7)
                Write-Info "Baixando e instalando $($app.Nome) (oficial, pelo winget)..."
                $comum = @('-e', '--silent', '--accept-package-agreements', '--accept-source-agreements') + @(Get-WingetExtra)
                $out = & (Get-Winget) install --id $id --location $dir @comum 2>&1 | Out-String
                Write-Log $out
                if (-not (Resolve-AppExe $app)) {
                    # alguns instaladores nao aceitam escolher a pasta: instala no lugar padrao
                    $out = & (Get-Winget) install --id $id @comum 2>&1 | Out-String
                    Write-Log $out
                }
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
            elseif ($fonte -eq 'site') {
                return (Get-AppPeloSite $app)      # drivers: nao tem .exe para conferir
            }
        } catch {
            Write-Warn "Falha ao obter $($app.Nome): $($_.Exception.Message)"
            return $false
        }
        $exe = Resolve-AppExe $app
    }
    if ($exe) {
        New-AppAtalho $app $exe
        Set-AppConfig $app $exe
        $onde = if ($exe -like "$dir*") { "apps\$($app.Pasta)" } else { "instalado no Windows (atalho em apps\$($app.Pasta))" }
        Write-Ok "$($app.Nome) pronto - $onde"
        Write-Log "APP pronto $($app.Nome) $exe"
        return $true
    }
    Write-Warn "$($app.Nome): nao consegui deixar pronto automaticamente. Use o site oficial: $($app.Url)"
    return $false
}

function Install-RecommendedApps($hw) {
    Write-Title 'INSTALAR TUDO AUTOMATICO (recomendado para este PC)'
    $lista = @(Get-AppList | Where-Object { (Test-AppMatch $_.Para $hw) -and ($_.Auto -or $_.Fonte -eq 'site') })
    $apps = @($lista | Where-Object { $_.Fonte -ne 'site' })
    $drv  = @($lista | Where-Object { $_.Fonte -eq 'site' })
    Write-Note 'Programas (baixa e instala sozinho, das fontes oficiais):'
    foreach ($a in $apps) { $st = if (Resolve-AppExe $a) { '(ja pronto)' } else { '' }; Write-Note "  - $($a.Nome) $st" }
    if ($drv.Count) {
        Write-Note 'Drivers (o pack abre o site, voce so clica em BAIXAR, ele faz o resto):'
        foreach ($a in $drv) { Write-Note "  - $($a.Nome)" }
    }
    if (-not (Confirm-Step 'Comecar?' $true)) { return }
    $ok = 0; $n = 0
    foreach ($a in $apps) {
        $n++; Write-Etapa $n ($apps.Count + $drv.Count) $a.Nome
        if (Install-App $a) { $ok++ }
    }
    foreach ($a in $drv) {
        $n++; Write-Etapa $n ($apps.Count + $drv.Count) $a.Nome
        if (Confirm-Step "Baixar e instalar agora o $($a.Nome)?" $true) { if (Install-App $a) { $ok++ } }
    }
    Write-Host ''
    Write-Caixa @("$ok de $($apps.Count + $drv.Count) item(ns) prontos.", 'Cada pasta em apps\ tem o app (ou o atalho ABRIR) e o LEIA-ME', 'com as melhores configuracoes.') 'Green'
    Start-Process explorer.exe (Join-Path $Root 'apps')
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
        $v = [string](& (Get-Winget) --version 2>$null)
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
                $out = & (Get-Winget) download --id $id -e -d $dir --accept-package-agreements --accept-source-agreements @(Get-WingetExtra) --skip-dependencies 2>&1 | Out-String
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
    $dir = Join-Path $Root ('apps\' + $app.Pasta)
    $tut = Join-Path $dir 'LEIA-ME.txt'
    Write-Host ''
    Write-Host "  $($app.Nome)" -ForegroundColor White
    $exe = Resolve-AppExe $app
    if (-not $exe -and $app.Fonte -ne 'site') {
        if (-not (Install-App $app)) { return }
        $exe = Resolve-AppExe $app
    } elseif ($app.Fonte -eq 'site') {
        if (-not (Install-App $app)) { return }
    }
    Start-Process explorer.exe $dir
    if (Test-Path $tut) {
        Write-Note 'As MELHORES CONFIGURACOES deste app estao no LEIA-ME.txt (abrindo no Bloco de Notas).'
        Start-Process notepad.exe $tut
    }
    if ($exe -and (Confirm-Step "Abrir o $($app.Nome) agora?" $true)) { Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) }
}

function Mod-Apps {
    $script:CurMod = 'apps'
    $hw = Load-HW
    $apps = Get-AppList
    if ($apps.Count -eq 0) { Write-Warn 'apps\apps.txt nao encontrado.'; return }
    while ($true) {
        Write-Title 'PROGRAMAS UTEIS'
        Write-Note 'Cinza = feito para outra peca (nao e do seu PC).'
        Write-Host ''
        $itens = @(@{ K = 'A'; T = 'INSTALAR TUDO AUTOMATICO (o que serve para este PC)'; C = 'Green' })
        for ($i = 0; $i -lt $apps.Count; $i++) {
            $a   = $apps[$i]
            $meu = Test-AppMatch $a.Para $hw
            if ($a.Fonte -eq 'site') { $st = 'site oficial' }
            elseif (Resolve-AppExe $a) { $st = 'PRONTO' }
            else { $st = 'instalar' }
            $cor = if (-not $meu) { 'DarkGray' } elseif ($st -eq 'PRONTO') { 'Green' } else { 'White' }
            $itens += @{ K = "$($i + 1)"; T = ("{0,-38} {1}" -f $a.Nome, $st); C = $cor }
        }
        $itens += @{ K = 'T'; T = 'Baixar todos para DENTRO do pack, sem instalar (para mandar junto)'; C = 'DarkCyan' }
        $op = Select-Opcao $itens -Inicio $(if ($op -match '^\d+$') { [int]$op } else { 0 })
        if ($op -eq '0') { return }

        if ($op -match '^[aAbB]$') { Install-RecommendedApps $hw; Read-Host '  ENTER para voltar a lista' | Out-Null; continue }
        if ($op -match '^[tT]$') { Save-AllAppsToFolders; continue }
        if ($op -notmatch '^\d+$' -or [int]$op -lt 1 -or [int]$op -gt $apps.Count) { continue }
        Start-AppFlow $apps[[int]$op - 1]
        Write-Host ''
        Read-Host '  ENTER para voltar a lista' | Out-Null
    }
}
