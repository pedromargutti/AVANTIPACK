# =====================================================================
#  AVANTIPACK - funcoes do pack GRATIS
#   - Nota do PC      : uma nota de 0 a 100 com o que esta segurando o PC
#   - Limpeza rapida  : temporarios, caches e downloads velhos do Windows
#   - Preparar p/ jogar: fecha o que esta pesando antes da partida
#  Carregado por avanti.ps1 (dot-source). Sem acentos de proposito.
# =====================================================================

function Write-Barra([int]$Nota) {
    $cor = if ($Nota -ge 80) { 'Green' } elseif ($Nota -ge 55) { 'Yellow' } else { 'Red' }
    $cheio = [int][math]::Round($Nota / 2.5)
    Write-Host '  [' -NoNewline
    for ($i = 0; $i -lt 40; $i++) {
        if ($i -lt $cheio) { Write-Host ([char]0x2588) -NoNewline -ForegroundColor $cor; Start-Sleep -Milliseconds 12 }
        else { Write-Host ([char]0x2591) -NoNewline -ForegroundColor DarkGray }
    }
    Write-Host ']  ' -NoNewline
    Write-Host ("{0}/100" -f $Nota) -ForegroundColor $cor
}

function Get-TempTamanhoMB {
    $t = 0
    foreach ($d in @($env:TEMP, "$env:SystemRoot\Temp", "$env:SystemRoot\SoftwareDistribution\Download")) {
        if (Test-Path $d) { $t += (Get-ChildItem $d -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum }
    }
    return [math]::Round($t / 1MB)
}

function Mod-Nota([switch]$SemTitulo) {
    $script:CurMod = 'nota'
    if (-not $SemTitulo) { Write-Title 'NOTA DO PC PARA JOGOS' }
    Write-Info 'Analisando o seu PC (uns 10 segundos)...'
    $hw = Load-HW
    $itens = New-Object System.Collections.ArrayList
    function Add-N($nome, $pts, $max, $dica) { [void]$itens.Add([pscustomobject]@{ Nome = $nome; Pts = $pts; Max = $max; Dica = $dica }) }

    # Pecas
    $ram = [int]$hw.RAM_GB
    Add-N 'Memoria RAM' $(if ($ram -ge 16) { 12 } elseif ($ram -ge 12) { 7 } else { 3 }) 12 $(if ($ram -lt 16) { "So $ram GB: 16 GB ou mais evita travadas em jogos atuais." })
    Add-N 'Disco do Windows' $(switch ($hw.DISK) { 'NVME' { 12 } 'SSD' { 10 } default { 2 } }) 12 $(if ($hw.DISK -eq 'HDD') { 'Windows em HD mecanico: trocar por SSD e o maior ganho possivel.' })
    $al = @(Get-Alerts $hw)
    $mem = @($al | Where-Object { $_ -match 'XMP|EXPO|pente|SINGLE' })
    Add-N 'Memoria na velocidade certa (XMP / dual channel)' $(if ($mem.Count -eq 0) { 10 } else { 3 }) 10 $(if ($mem.Count) { 'Veja os alertas de memoria em Verificar e o Guia de BIOS.' })

    # Video e monitor
    $mons = @(); try { $mons = @(Get-Monitors) } catch {}
    $baixo = @($mons | Where-Object { $_.HzMax -gt ($_.HzAtual + 1) })
    Add-N 'Monitor na taxa maxima (Hz)' $(if ($baixo.Count -eq 0) { 10 } else { 0 }) 10 $(if ($baixo.Count) { "Monitor em $($baixo[0].HzAtual) Hz mas aceita $($baixo[0].HzMax) Hz: o Otimizar corrige." })
    $dias = $null
    $vc = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'NVIDIA|Radeon|Arc' -and $_.DriverDate } | Select-Object -First 1
    if ($vc) { $dias = [int]((Get-Date) - $vc.DriverDate).TotalDays }
    Add-N 'Driver de video atualizado' $(if ($dias -eq $null) { 6 } elseif ($dias -le 180) { 10 } elseif ($dias -le 365) { 5 } else { 1 }) 10 $(if ($dias -gt 180) { "Driver com $dias dias: atualize em Programas uteis." })

    # Windows
    $livreC = 100
    try { $dr = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')); $livreC = [math]::Round(100 * $dr.Free / ($dr.Used + $dr.Free)) } catch {}
    Add-N 'Espaco livre no disco C:' $(if ($livreC -ge 20) { 10 } elseif ($livreC -ge 10) { 5 } else { 0 }) 10 $(if ($livreC -lt 20) { "So $livreC% livre: abaixo de 15% o Windows e os jogos ficam lentos. Use a Limpeza rapida." })
    $tmp = Get-TempTamanhoMB
    Add-N 'Lixo de arquivos temporarios' $(if ($tmp -lt 1024) { 6 } elseif ($tmp -lt 4096) { 3 } else { 0 }) 6 $(if ($tmp -ge 1024) { "$tmp MB de temporarios: use a Limpeza rapida." })
    $run = 0
    foreach ($k in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run') {
        $i = Get-Item $k -ErrorAction SilentlyContinue; if ($i) { $run += @($i.GetValueNames() | Where-Object { $_ }).Count }
    }
    Add-N 'Programas que abrem com o Windows' $(if ($run -le 6) { 8 } elseif ($run -le 12) { 4 } else { 1 }) 8 $(if ($run -gt 6) { "$run programas abrem junto com o Windows: deixa o PC lento para ligar e pesa no jogo." })
    $gm = (Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -ErrorAction SilentlyContinue).AutoGameModeEnabled
    Add-N 'Modo de Jogo do Windows' $(if ($gm -ne 0) { 6 } else { 0 }) 6 $(if ($gm -eq 0) { 'Modo de Jogo desligado: o Otimizar liga.' })
    $plano = ((& powercfg.exe /getactivescheme) -join ' ')
    $economia = $plano -match 'a1841308-3541-4fab-bc81-f71556f20b4a'
    Add-N 'Plano de energia' $(if ($economia) { 0 } else { 8 }) 8 $(if ($economia) { 'Plano "Economia de energia" ativo: o PC fica bem mais lento. O Otimizar arruma.' })
    $hf = Get-HotFix -ErrorAction SilentlyContinue | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
    $upd = if ($hf) { [int]((Get-Date) - $hf.InstalledOn).TotalDays } else { $null }
    Add-N 'Windows atualizado' $(if ($upd -eq $null -or $upd -le 60) { 8 } else { 3 }) 8 $(if ($upd -gt 60) { "Ultima atualizacao ha $upd dias: rode o Windows Update (corrige bugs e seguranca)." })

    $total = [int](($itens | Measure-Object Pts -Sum).Sum)
    $max = [int](($itens | Measure-Object Max -Sum).Sum)
    $nota = [int][math]::Round(100 * $total / $max)
    Write-Host ''
    Write-Barra $nota
    $frase = if ($nota -ge 90) { 'PC redondo para jogar!' } elseif ($nota -ge 75) { 'Bom, com alguns pontos para melhorar.' } elseif ($nota -ge 55) { 'Da para ganhar bastante desempenho.' } else { 'O PC esta bem travado: siga as dicas abaixo.' }
    Write-Host ("  $frase") -ForegroundColor White
    Write-Host ''
    foreach ($i in $itens) {
        $ok = $i.Pts -ge $i.Max
        $c = if ($ok) { 'Green' } elseif ($i.Pts -gt 0) { 'Yellow' } else { 'Red' }
        Write-Host ("  {0} {1,-48} {2,2}/{3}" -f $(if ($ok) { '[OK]' } else { '[!] ' }), $i.Nome, $i.Pts, $i.Max) -ForegroundColor $c
        if ($i.Dica) { Write-Note ("     " + $i.Dica) }
    }
    $hist = Join-Path $DataDir 'notas.csv'
    $ant = $null
    if (Test-Path $hist) { $ant = @(Import-Csv $hist) | Select-Object -Last 1 }
    [pscustomobject]@{ Data = (Get-Date -Format 'dd/MM/yyyy HH:mm'); Nota = $nota } | Export-Csv $hist -Append -NoTypeInformation -Encoding UTF8
    if ($ant) {
        $dif = $nota - [int]$ant.Nota
        Write-Host ''
        Write-Host ("  Ultima nota: {0} em {1}  ({2}{3})" -f $ant.Nota, $ant.Data, $(if ($dif -ge 0) { '+' } else { '' }), $dif) -ForegroundColor $(if ($dif -ge 0) { 'Cyan' } else { 'Yellow' })
    }
    Write-Host ''
    Write-Note 'No AVANTIPACK Pro: teste de FPS, input lag, temperatura e internet entram na analise.'
}

function Mod-Limpeza {
    $script:CurMod = 'limpeza'
    Write-Title 'LIMPEZA RAPIDA'
    Write-Note 'Apaga temporarios, relatorios de erro antigos, cache de shader e downloads velhos do Windows Update.'
    Write-Note 'Seus arquivos (documentos, fotos, jogos, saves) NAO sao tocados.'
    Write-Host ''
    $antes = 0
    try { $antes = (Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))).Free } catch {}
    $sel = @{ G5 = $true }
    $script:Selecao = $sel; $script:AutoMode = $false
    try { Mod-Armazenamento } finally { $script:Selecao = $null }
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    try {
        $depois = (Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))).Free
        $mb = [math]::Round(($depois - $antes) / 1MB)
        if ($mb -gt 0) { Write-Host ''; Write-Host ("  Espaco liberado no C:  {0:N0} MB" -f $mb) -ForegroundColor Green }
    } catch {}
    $script:NeedReboot = $false
}

function Mod-PreJogo {
    $script:CurMod = 'prejogo'
    Write-Title 'PREPARAR PARA JOGAR'
    Write-Note 'Mostra os programas que estao gastando memoria agora e fecha os que voce marcar.'
    Write-Note 'Salve o que estiver aberto antes (documentos, abas). Nada e desinstalado.'
    Write-Host ''
    $manter = 'explorer|dwm|csrss|winlogon|lsass|services|svchost|System|Idle|Registry|smss|wininit|fontdrvhost|sihost|ctfmon|ShellExperienceHost|StartMenuExperienceHost|SearchHost|TextInputHost|RuntimeBroker|SecurityHealth|MsMpEng|NisSrv|audiodg|conhost|powershell|pwsh|cmd|WindowsTerminal|OpenConsole|AVANTIPACK|nvcontainer|NVDisplay|amdow|RadeonSoftware|atiesrxx|atieclxx|Discord|steam|steamwebhelper|EpicGamesLauncher|RiotClientServices|Battle\.net|vgc|vgtray|EasyAntiCheat|BEService|FACEIT'
    $lista = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -notmatch "^($manter)$" -and $_.SessionId -ne 0 } |
               Group-Object ProcessName | ForEach-Object { [pscustomobject]@{ Nome = $_.Name; MB = [math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum) / 1MB); Qtd = $_.Count } } |
               Where-Object { $_.MB -ge 150 } | Sort-Object MB -Descending | Select-Object -First 12)
    $os = Get-CimInstance Win32_OperatingSystem
    $livre = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    Write-Host ("  Memoria livre agora: {0} GB de {1} GB" -f $livre, [math]::Round($os.TotalVisibleMemorySize / 1MB)) -ForegroundColor White
    if ($lista.Count -eq 0) { Write-Host ''; Write-Ok 'Nada pesado aberto. Pode jogar!'; return }
    Write-Host ''
    $navegadores = 'chrome|msedge|firefox|opera|brave|vivaldi'
    $r = Select-Varios @($lista | ForEach-Object {
            @{ K = $_.Nome; T = ("{0,-28} {1,6:N0} MB" -f $_.Nome, $_.MB); On = ($_.Nome -match "^($navegadores|OneDrive|Teams|ms-teams|Spotify|EpicWebHelper|Adobe.*|Creative Cloud)$") }
         }) -Concluir 'FECHAR os marcados' -SemTodos
    if ($null -eq $r -or @($r).Count -eq 0) { return }
    foreach ($n in @($r)) {
        $ps = @(Get-Process -Name $n -ErrorAction SilentlyContinue)
        foreach ($p in $ps) { try { [void]$p.CloseMainWindow() } catch {} }
        Start-Sleep -Milliseconds 1500
        $ps = @(Get-Process -Name $n -ErrorAction SilentlyContinue)
        if ($ps.Count) { $ps | Stop-Process -Force -ErrorAction SilentlyContinue }
        Write-Ok "$n fechado."
    }
    Start-Sleep -Seconds 1
    $os = Get-CimInstance Win32_OperatingSystem
    $agora = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    Write-Host ''
    Write-Host ("  Memoria livre: {0} GB  ->  {1} GB" -f $livre, $agora) -ForegroundColor Green
    Write-Note 'Bom jogo! No AVANTIPACK Pro, o Modo Jogo faz isso e coloca a energia no maximo sozinho.'
}
