# =====================================================================
#  AVANTIPACK - Prioridade de jogos
#  Procura os jogos INSTALADOS (Steam, Epic, Riot, Battle.net, EA,
#  Ubisoft, GOG, Xbox, Roblox e pastas comuns) e grava prioridade ALTA
#  de CPU no registro (Image File Execution Options\<exe>\PerfOptions).
#  Toda alteracao passa por Set-Reg -> entra no backup -> Desfazer.
#  Carregado por avanti.ps1 (dot-source). Sem acentos de proposito.
# =====================================================================

# Jogos competitivos (recebem o perfil NVIDIA turbo - item H2)
$COMPETITIVOS = @('Counter-Strike 2', 'Valorant', 'Fortnite', 'Apex Legends', 'Call of Duty (Black Ops 6/7, Warzone)',
                  'Rainbow Six Siege', 'Overwatch 2', 'League of Legends', 'PUBG', 'Rocket League', 'Deadlock',
                  'Marvel Rivals', 'THE FINALS', 'Dota 2', 'Delta Force', 'Blood Strike', 'Brawlhalla',
                  'Arena Breakout Infinite', 'Team Fortress 2', 'Escape from Tarkov', 'Street Fighter 6')

$IFEO = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'

function Get-GameDb {
    $f = Join-Path $PSScriptRoot 'jogos.txt'
    $db = @()
    foreach ($l in Get-Content $f -ErrorAction SilentlyContinue) {
        if (-not $l.Trim() -or $l -match '^\s*#') { continue }
        $p = $l.Split('|')
        if ($p.Count -lt 2) { continue }
        $db += [pscustomobject]@{ Nome = $p[0].Trim(); Exes = @($p[1].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    }
    return $db
}

# Pastas onde costumam ficar jogos
function Get-GameRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    # Steam (todas as bibliotecas)
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { $steam = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath }
    if ($steam) {
        $steam = $steam -replace '/', '\'
        $roots.Add("$steam\steamapps\common")
        $vdf = "$steam\steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $roots.Add((($m.Groups[1].Value -replace '\\\\', '\') + '\steamapps\common'))
            }
        }
    }
    # Epic Games (manifestos)
    $man = "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
    foreach ($it in Get-ChildItem $man -Filter '*.item' -ErrorAction SilentlyContinue) {
        try { $j = Get-Content $it.FullName -Raw | ConvertFrom-Json; if ($j.InstallLocation) { $roots.Add($j.InstallLocation) } } catch {}
    }
    # Pastas conhecidas em cada disco
    $pf86 = ${env:ProgramFiles(x86)}
    $fixas = @("$env:ProgramFiles\EA Games", "$env:ProgramFiles\Electronic Arts", "$pf86\Origin Games",
               "$pf86\Ubisoft\Ubisoft Game Launcher\games", "$pf86\GOG Galaxy\Games", "$env:ProgramFiles\Epic Games",
               "$pf86\Overwatch", "$pf86\Diablo IV", "$pf86\Call of Duty", "$env:ProgramFiles\Call of Duty",
               "$pf86\Steam\steamapps\common", "$env:LOCALAPPDATA\Roblox\Versions", "$pf86\Roblox\Versions",
               "$env:ProgramFiles\BlueStacks_nxt", "$pf86\Garena", "$env:ProgramFiles\Rockstar Games",
               "$env:LOCALAPPDATA\FiveM", "$pf86\MTA San Andreas 1.6", "$env:ProgramFiles\Mojang")
    foreach ($x in $fixas) { $roots.Add($x) }
    foreach ($d in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue) {
        if (-not $d.Root -or $d.Free -eq $null) { continue }
        foreach ($sub in 'Riot Games', 'XboxGames', 'Games', 'Jogos', 'SteamLibrary\steamapps\common', 'Epic Games', 'Program Files\Epic Games', 'EA Games', 'Battle.net') {
            $roots.Add((Join-Path $d.Root $sub))
        }
    }
    return @($roots | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Sort-Object -Unique)
}

# Varredura sem travar em pasta protegida (pilha manual, profundidade limitada)
function Find-GameExes([string[]]$Roots, [hashtable]$Wanted, [int]$MaxDepth = 7) {
    $achados = @{}
    foreach ($r in $Roots) {
        $stack = New-Object System.Collections.Stack
        $stack.Push(@($r, 0))
        while ($stack.Count -gt 0) {
            $item = $stack.Pop(); $dir = $item[0]; $dep = $item[1]
            try {
                foreach ($f in [System.IO.Directory]::EnumerateFiles($dir, '*.exe')) {
                    $n = [System.IO.Path]::GetFileName($f).ToLower()
                    if ($Wanted.ContainsKey($n) -and -not $achados.ContainsKey($n)) { $achados[$n] = $f }
                }
                if ($dep -lt $MaxDepth) {
                    foreach ($sd in [System.IO.Directory]::EnumerateDirectories($dir)) {
                        $leaf = [System.IO.Path]::GetFileName($sd)
                        if ($leaf -match '^(\$|_CommonRedist|DirectX|redist|vcredist|Engine\\Extras|__Installer|shadercache|compatdata)') { continue }
                        $stack.Push(@($sd, ($dep + 1)))
                    }
                }
            } catch {}
        }
    }
    return $achados
}

function Get-Prioritized {
    $out = @()
    foreach ($k in Get-ChildItem $IFEO -ErrorAction SilentlyContinue) {
        $v = (Get-ItemProperty -Path "$($k.PSPath)\PerfOptions" -Name CpuPriorityClass -ErrorAction SilentlyContinue).CpuPriorityClass
        if ($v -eq 3) { $out += $k.PSChildName }
    }
    return $out
}

function Set-GamePriority([string]$Exe) {
    if (Set-Reg "$IFEO\$Exe\PerfOptions" 'CpuPriorityClass' 3) { return $true }
    return $false
}

function Invoke-AutoGames {
    $script:CurMod = 'jogos'
    $script:CurItem = 'H1'
    Write-Title 'PRIORIDADE DOS JOGOS INSTALADOS'
    $db = Get-GameDb
    $wanted = @{}
    foreach ($g in $db) { foreach ($e in $g.Exes) { $wanted[$e.ToLower()] = $g.Nome } }
    Write-Info 'Procurando jogos instalados...'
    $found = Find-GameExes (Get-GameRoots) $wanted
    if ($found.Count -eq 0) { Write-Skip 'Nenhum jogo conhecido encontrado (adicione pelo menu avancado > Jogos).'; return }
    foreach ($e in ($found.Keys | Sort-Object { $wanted[$_] })) {
        $real = [System.IO.Path]::GetFileName($found[$e])
        if (Set-GamePriority $real) { Write-Ok "$($wanted[$e]): prioridade ALTA" }
    }
}

# Notebook com 2 placas: manda cada jogo para a placa DEDICADA (mesma opcao de
# Configuracoes > Sistema > Tela > Elementos graficos > "Alto desempenho").
function Invoke-GpuDedicada {
    $script:CurMod = 'jogos'
    $script:CurItem = 'H3'
    $hw = Load-HW
    if ($hw.GPU_HIBRIDA -ne '1') { Write-Skip 'Este PC tem uma placa de video so: nada a fazer.'; return }
    Write-Title 'JOGOS NA PLACA DE VIDEO DEDICADA'
    Write-Note "Placas encontradas: $($hw.GPU)"
    $db = Get-GameDb
    $wanted = @{}
    foreach ($g in $db) { foreach ($e in $g.Exes) { $wanted[$e.ToLower()] = $g.Nome } }
    Write-Info 'Procurando jogos instalados...'
    $found = Find-GameExes (Get-GameRoots) $wanted
    if ($found.Count -eq 0) { Write-Skip 'Nenhum jogo conhecido encontrado.'; return }
    $k = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    foreach ($e in ($found.Keys | Sort-Object { $wanted[$_] })) {
        Set-Reg $k $found[$e] 'GpuPreference=2;' 'String'
        Write-Ok "$($wanted[$e]): placa dedicada (alto desempenho)"
    }
    Write-Note 'Vale a partir da proxima vez que o jogo abrir.'
}

function Mod-Jogos {
    $script:CurMod = 'jogos'
    $script:CurItem = 'H1'
    $db = Get-GameDb
    while ($true) {
        Write-Title 'PRIORIDADE DE JOGOS'
        Write-Note 'Da prioridade ALTA de processador ao jogo sempre que ele abrir (fica salvo no Windows).'
        Write-Note 'Ajuda em PCs com muita coisa aberta junto (Discord, navegador, OBS). Em PC limpo o ganho e pequeno.'
        Write-Note 'Se o audio do Discord comecar a falhar durante o jogo, remova pelo opcao 6 (Desfazer) > jogos.'
        Write-Host ''
        Write-Host '  [1] Procurar jogos instalados e priorizar (recomendado)'
        Write-Host '  [2] Escolher da lista de jogos conhecidos'
        Write-Host '  [3] Adicionar um jogo pelo nome do .exe'
        Write-Host '  [4] Ver jogos ja priorizados'
        Write-Host '  [5] Perfil NVIDIA turbo nos jogos competitivos (so NVIDIA)'
        Write-Host '  [6] Configuracoes recomendadas DENTRO dos jogos (guia)'
        Write-Host '  [7] Notebook: jogos sempre na placa de video DEDICADA'
        Write-Host ''
        $op = Read-Host '  Escolha (ENTER volta ao menu)'
        switch ($op) {
            '1' {
                Write-Info 'Procurando pastas de jogos (Steam, Epic, Riot, Xbox, EA, Ubisoft, Battle.net, GOG)...'
                $roots = Get-GameRoots
                foreach ($r in $roots) { Write-Note "  $r" }
                $wanted = @{}
                foreach ($g in $db) { foreach ($e in $g.Exes) { $wanted[$e.ToLower()] = $g.Nome } }
                Write-Info 'Procurando os executaveis (pode levar ate 1 minuto em HD)...'
                $found = Find-GameExes $roots $wanted
                if ($found.Count -eq 0) { Write-Warn 'Nenhum jogo da lista foi encontrado. Use a opcao 3 desta tela para adicionar pelo nome do .exe.'; break }
                $lista = @($found.Keys | Sort-Object { $wanted[$_] })
                Write-Host ''
                for ($i = 0; $i -lt $lista.Count; $i++) {
                    Write-Host ("  [{0,2}] {1,-38} {2}" -f ($i + 1), $wanted[$lista[$i]], $lista[$i])
                }
                Write-Host ''
                $sel = Read-Host '  ENTER = priorizar TODOS  |  ou digite os numeros separados por virgula  |  0 = cancelar'
                if ($sel -eq '0') { break }
                $alvo = if (-not $sel) { $lista } else { @($sel.Split(',') | ForEach-Object { $n = $_.Trim(); if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $lista.Count) { $lista[[int]$n - 1] } }) }
                $ok = 0
                foreach ($e in $alvo) {
                    $real = [System.IO.Path]::GetFileName($found[$e])
                    if (Set-GamePriority $real) { Write-Ok "$($wanted[$e]) ($real): prioridade ALTA"; $ok++ }
                }
                Write-Ok "$ok jogo(s) priorizado(s). Vale na proxima vez que o jogo abrir."
            }
            '2' {
                for ($i = 0; $i -lt $db.Count; $i++) { Write-Host ("  [{0,3}] {1}" -f ($i + 1), $db[$i].Nome) }
                $sel = Read-Host '  Numeros separados por virgula (ENTER cancela)'
                if (-not $sel) { break }
                foreach ($n in $sel.Split(',')) {
                    $n = $n.Trim()
                    if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $db.Count) {
                        $g = $db[[int]$n - 1]
                        foreach ($e in $g.Exes) { if (Set-GamePriority $e) { Write-Ok "$($g.Nome) ($e): prioridade ALTA" } }
                    }
                }
            }
            '3' {
                Write-Note 'Dica: abra o jogo, depois o Gerenciador de Tarefas > Detalhes, e veja o nome do .exe.'
                $e = (Read-Host '  Nome do executavel (ex: jogo.exe)').Trim().Trim('"')
                if ($e) {
                    $e = [System.IO.Path]::GetFileName($e)
                    if ($e -notmatch '\.exe$') { $e += '.exe' }
                    if ($e -match '^(explorer|svchost|csrss|dwm|lsass|winlogon|services|system|audiodg|javaw|java|game|launcher|steam|discord)\.exe$') {
                        Write-Warn "$e e um nome generico ou do sistema. Nao vou alterar."
                    } elseif (Set-GamePriority $e) { Write-Ok "${e}: prioridade ALTA" }
                }
            }
            '4' {
                $p = Get-Prioritized
                if ($p.Count -eq 0) { Write-Skip 'Nenhum jogo priorizado.' } else { foreach ($x in $p) { Write-Note "  $x" } }
                Write-Note 'Para remover: menu principal > opcao 6 (Desfazer) > jogos.'
            }
            '5' { Optimize-NvidiaGameProfiles (Load-HW); $script:CurItem = 'H1' }
            '6' { Start-Process notepad.exe (Join-Path $Root 'guias\CONFIG_DOS_JOGOS.txt') }
            '7' { Invoke-GpuDedicada }
            default { return }
        }
        Write-Host ''
        Read-Host '  ENTER para continuar' | Out-Null
    }
}
