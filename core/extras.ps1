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

# Dias desde a ultima atualizacao instalada. Usa o historico do Windows Update
# (o Get-HotFix le a data errado em Windows que nao sao em ingles).
function Get-DiasSemAtualizar {
    try {
        $s = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
        $n = $s.GetTotalHistoryCount()
        if ($n -gt 0) {
            $ok = @($s.QueryHistory(0, [math]::Min($n, 50)) | Where-Object { $_.ResultCode -eq 2 -and $_.Date })
            if ($ok.Count) { $ult = @($ok | ForEach-Object { [datetime]$_.Date } | Sort-Object -Descending)[0]; return [int]((Get-Date).ToUniversalTime() - $ult).TotalDays }
        }
    } catch {}
    try {
        $d = @(Get-CimInstance Win32_QuickFixEngineering -ErrorAction Stop | ForEach-Object {
                $x = [datetime]::MinValue
                if ([datetime]::TryParse([string]$_.InstalledOn, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$x)) { $x } })
        $d = @($d | Where-Object { $_ -le (Get-Date) })
        if ($d.Count) { return [int]((Get-Date) - @($d | Sort-Object -Descending)[0]).TotalDays }
    } catch {}
    return $null
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
    Add-N 'Disco do Windows' $(switch ($hw.DISK) { 'NVME' { 12 } 'SSD' { 10 } 'HDD' { 2 } default { 8 } }) 12 $(if ($hw.DISK -eq 'HDD') { 'Windows em HD mecanico: trocar por SSD e o maior ganho possivel.' })
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
    $upd = Get-DiasSemAtualizar
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

# ---------------------------------------------------------------------
#  Cache de shaders (NVIDIA, AMD, Intel e DirectX)
# ---------------------------------------------------------------------
function Get-PastasShader {
    $la = $env:LOCALAPPDATA; $ll = Join-Path $env:USERPROFILE 'AppData\LocalLow'
    return @(
        "$la\NVIDIA\DXCache", "$la\NVIDIA\GLCache", "$la\NVIDIA Corporation\NV_Cache", "$env:ProgramData\NVIDIA Corporation\NV_Cache",
        "$ll\NVIDIA\PerDriverVersion\DXCache",
        "$la\AMD\DxCache", "$la\AMD\DxcCache", "$la\AMD\VkCache", "$la\AMD\GLCache", "$la\AMD\OglCache",
        "$ll\Intel\ShaderCache", "$la\Intel\ShaderCache",
        "$la\D3DSCache"
    ) | Where-Object { Test-Path -LiteralPath $_ }
}
function Get-TamanhoMB([string[]]$Caminhos) {
    $s = 0L
    foreach ($c in $Caminhos) { try { $s += [long](Get-ChildItem -LiteralPath $c -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum } catch {} }
    return [math]::Round($s / 1MB)
}
function Get-JogoAberto {
    $exes = @{}
    foreach ($l in Get-Content (Join-Path $PSScriptRoot 'jogos.txt') -ErrorAction SilentlyContinue) {
        if (-not $l.Trim() -or $l -match '^\s*#') { continue }
        $p = $l.Split('|'); if ($p.Count -lt 2) { continue }
        foreach ($e in $p[1].Split(',')) { $n = [IO.Path]::GetFileNameWithoutExtension($e.Trim()).ToLower(); if ($n) { $exes[$n] = $p[0].Trim() } }
    }
    foreach ($pr in @(Get-Process -ErrorAction SilentlyContinue)) { $n = $pr.ProcessName.ToLower(); if ($exes.ContainsKey($n)) { return $exes[$n] } }
    return ''
}

function Mod-Shaders {
    $script:CurMod = 'limpeza'
    Write-Title 'CACHE DE SHADERS'
    Write-Note 'Os jogos guardam os shaders ja compilados para nao compilar de novo a cada partida.'
    Write-Note 'Quando esse cache corrompe, ou sobra de um driver antigo, aparecem travadinhas e stutter.'
    Write-Host ''
    $jogo = Get-JogoAberto
    if ($jogo) { Write-Warn ("Feche o $jogo antes: com o jogo aberto, parte do cache esta em uso e nao sai."); return }
    $pastas = @(Get-PastasShader)
    if ($pastas.Count -eq 0) { Write-Ok 'Nao achei cache de shaders neste PC: nada para limpar.'; return }
    foreach ($p in $pastas) { Write-Host ("  {0,-62} {1,7:N0} MB" -f ($p -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%'), (Get-TamanhoMB @($p))) }
    $mb = Get-TamanhoMB $pastas
    Write-Host ''
    Write-Info ("Total: {0:N0} MB" -f $mb)
    Write-Warn 'Depois de limpar, a primeira partida de cada jogo recompila os shaders: pode engasgar no primeiro minuto (ou mostrar "compilando shaders"). Na segunda partida ja fica liso.'
    Write-Note 'Vale a pena: depois de trocar o driver de video, quando um jogo comeca a travar sem motivo, ou com graficos bugados.'
    Write-Host ''
    if (-not (Confirm-Step 'Limpar o cache de shaders agora?')) { Write-Skip 'Nada foi limpo.'; return }
    foreach ($p in $pastas) { Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
    $saiu = [math]::Max(0, $mb - (Get-TamanhoMB $pastas))
    Write-Ok ("Cache de shaders limpo: {0:N0} MB liberados." -f $saiu)
    Write-Note 'Arquivos que estavam em uso (algum programa usando a placa de video) ficaram: sem problema.'
    Write-Note 'No AVANTIPACK Pro, a manutencao semanal faz isso sozinha quando o driver de video muda.'
}

# ---------------------------------------------------------------------
#  Modo eficiencia (EcoQoS, o mesmo do Gerenciador de Tarefas)
#  O Windows roda o app nos nucleos e clocks economicos. Vale ate o
#  app fechar. O Discord fica de fora de proposito (voz).
# ---------------------------------------------------------------------
function Set-ModoEficiencia($Processo) {
    if (-not ('AvEco' -as [type])) {
        Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices;
public static class AvEco {
  [StructLayout(LayoutKind.Sequential)] struct PPTS { public uint Versao, Controle, Estado; }
  [DllImport("kernel32.dll", SetLastError = true)] static extern bool SetProcessInformation(IntPtr h, int classe, ref PPTS info, int tam);
  public static bool Ligar(IntPtr h) { PPTS s = new PPTS(); s.Versao = 1; s.Controle = 1; s.Estado = 1; return SetProcessInformation(h, 4, ref s, 12); }
}'
    }
    try {
        $ok = [AvEco]::Ligar($Processo.Handle)
        if ($Processo.PriorityClass -eq 'Normal') { $Processo.PriorityClass = 'BelowNormal' }
        return $ok
    } catch { return $false }
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
    if ($lista.Count -eq 0) { Write-Host ''; Write-Ok 'Nada pesado aberto. Pode jogar!'; Invoke-EficienciaFundo; return }
    Write-Host ''
    $navegadores = 'chrome|msedge|firefox|opera|brave|vivaldi'
    $r = Select-Varios @($lista | ForEach-Object {
            @{ K = $_.Nome; T = ("{0,-28} {1,6:N0} MB" -f $_.Nome, $_.MB); On = ($_.Nome -match "^($navegadores|OneDrive|Teams|ms-teams|Spotify|EpicWebHelper|Adobe.*|Creative Cloud)$") }
         }) -Concluir 'FECHAR os marcados' -SemTodos
    if ($null -eq $r -or @($r).Count -eq 0) { Invoke-EficienciaFundo; return }
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
    Invoke-EficienciaFundo
    Write-Note 'Bom jogo! No AVANTIPACK Pro, o Modo Jogo faz isso e coloca a energia no maximo sozinho.'
}

# O que continua aberto em segundo plano (navegador, launcher, RGB...) vai para o modo eficiencia
function Invoke-EficienciaFundo {
    $fundo = '^(chrome|msedge|firefox|opera|brave|vivaldi|OneDrive|Teams|ms-teams|Spotify|EpicGamesLauncher|EpicWebHelper|Dropbox|GoogleDriveFS|AdobeIPCBroker|CCXProcess|wallpaper32|wallpaper64|iCUE|ArmouryCrate|SignalRgb|lghub|WhatsApp|Telegram|Battle\.net|EADesktop|upc|GalaxyClient|Overwolf|Medal)$'
    $ps = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match $fundo })
    if ($ps.Count -eq 0) { return }
    $nomes = @($ps | Select-Object -ExpandProperty ProcessName -Unique | Sort-Object)
    Write-Host ''
    Write-Info ('Ainda abertos em segundo plano: ' + ($nomes -join ', '))
    Write-Note 'Modo eficiencia: o Windows roda esses apps nos nucleos economicos e sobra mais processador para o jogo.'
    Write-Note 'Vale ate fechar o app. O Discord fica de fora (para a voz nao cortar).'
    if (-not (Confirm-Step 'Colocar esses apps em modo eficiencia?')) { return }
    $n = 0
    foreach ($p in $ps) { if (Set-ModoEficiencia $p) { $n++ } }
    Write-Ok ("{0} processo(s) em modo eficiencia ({1})." -f $n, ($nomes -join ', '))
}
