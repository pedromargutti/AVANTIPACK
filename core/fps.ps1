# =====================================================================
#  AVANTIPACK - teste de FPS (antes e depois)
#  Usa o PresentMon (Intel, codigo aberto, MIT), baixado do GitHub oficial
#  na primeira vez. Mede 60 s de jogo e calcula:
#    - FPS medio
#    - 1% low  (o FPS nos piores momentos: e o que voce sente como travada)
#    - travadas (quadros que demoraram mais que 2,5x o normal)
#  Guarda o historico em core\dados\data\fps_historico.csv para comparar.
# =====================================================================

$FpsHist = Join-Path $DataDir 'fps_historico.csv'

function Get-PresentMon {
    $dir = Join-Path $Root 'apps\PresentMon'
    $exe = Join-Path $dir 'PresentMon.exe'
    if (Test-Path $exe) { return $exe }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Info 'Baixando o PresentMon (Intel, oficial, gratuito) - so na primeira vez...'
    try {
        Initialize-Web
        $rels = Invoke-RestMethod -Uri 'https://api.github.com/repos/GameTechDev/PresentMon/releases?per_page=8' -Headers @{ 'User-Agent' = 'AVANTIPACK' } -UseBasicParsing
        $asset = $null
        foreach ($r in $rels) {
            if ($r.prerelease) { continue }
            $asset = $r.assets | Where-Object { $_.name -match '^PresentMon-[\d\.]+-x64\.exe$' } | Select-Object -First 1
            if ($asset) { break }
        }
        if (-not $asset) { throw 'nao achei o PresentMon de 64 bits nas versoes do GitHub' }
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exe -UseBasicParsing -Headers @{ 'User-Agent' = 'AVANTIPACK' }
        Write-Ok "PresentMon $($asset.name) salvo em apps\PresentMon"
        return $exe
    } catch {
        Write-Warn "Nao consegui baixar o PresentMon: $($_.Exception.Message)"
        Write-Note 'Baixe "PresentMon-...-x64.exe" em github.com/GameTechDev/PresentMon/releases,'
        Write-Note 'renomeie para PresentMon.exe e coloque em apps\PresentMon.'
        return $null
    }
}

# Jogo aberto agora: procura pelos .exe conhecidos (core\jogos.txt)
function Find-JogoAberto {
    $db = Get-GameDb
    $nomes = @{}
    foreach ($g in $db) { foreach ($e in $g.Exes) { $nomes[[IO.Path]::GetFileNameWithoutExtension($e).ToLower()] = $g.Nome } }
    $abertos = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $nomes.ContainsKey($_.ProcessName.ToLower()) } |
                 Sort-Object ProcessName -Unique | ForEach-Object { [pscustomobject]@{ Nome = $nomes[$_.ProcessName.ToLower()]; Exe = $_.ProcessName + '.exe' } })
    return $abertos
}

# Lista de programas com janela, mais pesados primeiro (para jogo que nao esta na lista)
function Get-JanelasAbertas {
    $ign = 'explorer|ApplicationFrameHost|TextInputHost|SystemSettings|cmd|powershell|conhost|WindowsTerminal|Discord|chrome|msedge|firefox|opera|brave|steam|steamwebhelper|EpicGamesLauncher|RiotClientServices|Battle.net|Spotify|Taskmgr|notepad'
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 -and $_.ProcessName -notmatch "^($ign)$" } |
             Sort-Object WorkingSet64 -Descending | Select-Object -First 6)
}

function Measure-FpsCsv([string]$csv) {
    $rows = @(Import-Csv $csv)
    if ($rows.Count -lt 30) { return $null }
    $col = @('MsBetweenPresents', 'FrameTime', 'msBetweenPresents') | Where-Object { $rows[0].PSObject.Properties.Name -contains $_ } | Select-Object -First 1
    if (-not $col) { return $null }
    $ft = New-Object System.Collections.Generic.List[double]
    foreach ($r in $rows) {
        $v = 0.0
        if ([double]::TryParse([string]$r.$col, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$v) -and $v -gt 0 -and $v -lt 1000) { $ft.Add($v) }
    }
    if ($ft.Count -lt 30) { return $null }
    $soma = 0.0; foreach ($v in $ft) { $soma += $v }
    $ord = @($ft | Sort-Object)
    $p99 = $ord[[math]::Min($ord.Count - 1, [math]::Ceiling($ord.Count * 0.99) - 1)]
    $med = $ord[[math]::Floor($ord.Count / 2)]
    $trav = @($ft | Where-Object { $_ -gt ($med * 2.5) -and $_ -gt 20 }).Count
    return [pscustomobject]@{
        Media    = [math]::Round(1000 * $ft.Count / $soma)
        Low1     = [math]::Round(1000 / $p99)
        Travadas = $trav
        Quadros  = $ft.Count
    }
}

function Show-FpsHistorico([string]$exe) {
    if (-not (Test-Path $FpsHist)) { return }
    $h = @(Import-Csv $FpsHist | Where-Object { $_.Exe -eq $exe })
    if ($h.Count -lt 1) { return }
    Write-Host ''
    Write-Host '  HISTORICO DESTE JOGO' -ForegroundColor White
    Write-Host ('  {0,-17} {1,-22} {2,9} {3,9} {4,9}' -f 'Data', 'Situacao', 'FPS med.', '1% low', 'Travadas') -ForegroundColor DarkGray
    foreach ($x in $h) {
        Write-Host ('  {0,-17} {1,-22} {2,9} {3,9} {4,9}' -f $x.Data, $x.Situacao, $x.Media, $x.Low1, $x.Travadas)
    }
    if ($h.Count -ge 2) {
        $a = $h[0]; $b = $h[-1]
        $dm = [int]$b.Media - [int]$a.Media; $dl = [int]$b.Low1 - [int]$a.Low1
        $pm = if ([int]$a.Media) { [math]::Round(100 * $dm / [int]$a.Media) } else { 0 }
        $pl = if ([int]$a.Low1) { [math]::Round(100 * $dl / [int]$a.Low1) } else { 0 }
        Write-Host ''
        $cor = if ($dl -ge 0) { 'Green' } else { 'Yellow' }
        Write-Host ("  Do primeiro teste para o ultimo:  FPS medio {0:+#;-#;0} ({1:+#;-#;0}%)   1% low {2:+#;-#;0} ({3:+#;-#;0}%)" -f $dm, $pm, $dl, $pl) -ForegroundColor $cor
        Write-Note 'Diferencas de ate 3% sao normais entre um teste e outro (variacao do proprio jogo).'
    }
}

function Mod-TesteFps {
    $script:CurMod = 'fps'
    Write-Title 'TESTE DE FPS (ANTES E DEPOIS)'
    Write-Note 'Mede o FPS de verdade enquanto voce joga. Faca o teste ANTES de otimizar e de novo DEPOIS,'
    Write-Note 'sempre no MESMO lugar do jogo e com as MESMAS configuracoes, para comparar.'
    Write-Host ''
    $pm = Get-PresentMon
    if (-not $pm) { return }

    # 1. qual jogo
    $jogo = $null
    while (-not $jogo) {
        $ab = @(Find-JogoAberto)
        if ($ab.Count -eq 1) { $jogo = $ab[0]; break }
        if ($ab.Count -gt 1) {
            for ($i = 0; $i -lt $ab.Count; $i++) { Write-Host ("  [{0}] {1}" -f ($i + 1), $ab[$i].Nome) }
            $op = Read-Host '  Qual jogo testar'
            if ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $ab.Count) { $jogo = $ab[[int]$op - 1] }
            continue
        }
        Write-Caixa @(
            'Abra o jogo e entre numa partida, treino ou mapa.',
            'Depois volte aqui (Alt+Tab) e aperte ENTER.',
            '',
            'Dica: no CS2/Valorant/Fortnite use o modo treino, sempre no',
            'mesmo lugar. Assim o antes e o depois ficam comparaveis.'
        ) 'Cyan'
        $r = Read-Host '  ENTER quando o jogo estiver aberto (ou digite o nome do .exe, ou 0 para sair)'
        if ($r -eq '0') { return }
        if ($r) {
            $e = if ($r -like '*.exe') { $r } else { "$r.exe" }
            $jogo = [pscustomobject]@{ Nome = [IO.Path]::GetFileNameWithoutExtension($e); Exe = $e }; break
        }
        if (-not @(Find-JogoAberto).Count) {
            $jan = @(Get-JanelasAbertas)
            if ($jan.Count) {
                Write-Note 'Nao reconheci o jogo. Programas abertos agora:'
                for ($i = 0; $i -lt $jan.Count; $i++) { Write-Host ("  [{0}] {1}  ({2})" -f ($i + 1), $jan[$i].MainWindowTitle, $jan[$i].ProcessName) }
                $op = Read-Host '  Numero do jogo (ENTER tenta de novo)'
                if ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $jan.Count) {
                    $p = $jan[[int]$op - 1]; $jogo = [pscustomobject]@{ Nome = $p.ProcessName; Exe = $p.ProcessName + '.exe' }
                }
            }
        }
    }
    Write-Ok "Jogo: $($jogo.Nome)  ($($jogo.Exe))"

    # 2. medir
    $seg = 60
    Write-Host ''
    Write-Host '  Volte para o jogo AGORA e jogue normalmente.' -ForegroundColor Black -BackgroundColor Yellow
    Write-Note "O teste comeca em 10 segundos (BIP) e dura $seg segundos (BIP BIP no fim)."
    Start-Sleep -Seconds 10
    try { [Console]::Beep(880, 250) } catch {}
    $csv = Join-Path $env:TEMP ('avanti_fps_' + [IO.Path]::GetRandomFileName() + '.csv')
    $args2 = @('--process_name', $jogo.Exe, '--output_file', $csv, '--timed', $seg, '--terminate_after_timed',
               '--no_console_stats', '--stop_existing_session', '--session_name', 'AVANTIPACK')
    Write-Info "Medindo por $seg segundos..."
    $p = Start-Process -FilePath $pm -ArgumentList $args2 -WindowStyle Hidden -PassThru
    if (-not $p.WaitForExit(($seg + 30) * 1000)) { try { $p.Kill() } catch {} }
    try { [Console]::Beep(880, 200); Start-Sleep -Milliseconds 120; [Console]::Beep(1100, 300) } catch {}

    # 3. resultado
    $res = $null
    if (Test-Path $csv) { $res = Measure-FpsCsv $csv; Remove-Item $csv -Force -ErrorAction SilentlyContinue }
    if (-not $res) {
        Write-Warn 'Nao recebi quadros do jogo. Confira se ele ficou na tela durante o teste (nao minimizado).'
        Write-Note 'Alguns anti-cheats bloqueiam a medicao; nesse caso use o contador de FPS do proprio jogo.'
        return
    }
    $sit = if (@($script:BackupCache).Count -gt 0) { 'COM o AVANTIPACK' } else { 'ANTES (Windows normal)' }
    Write-Host ''
    Write-Caixa @(
        "$($jogo.Nome) - $sit",
        '',
        ("FPS medio ............ {0}" -f $res.Media),
        ("1% low (piores) ...... {0}" -f $res.Low1),
        ("Travadas ............. {0}" -f $res.Travadas),
        '',
        '1% low perto do FPS medio = jogo liso. Muito abaixo = travadinhas.'
    ) 'Green'
    $linha = [pscustomobject]@{ Data = (Get-Date -Format 'dd/MM/yyyy HH:mm'); Jogo = $jogo.Nome; Exe = $jogo.Exe; Situacao = $sit
                                Media = $res.Media; Low1 = $res.Low1; Travadas = $res.Travadas; Ajustes = @($script:BackupCache).Count }
    $linha | Export-Csv -Path $FpsHist -Append -NoTypeInformation -Encoding UTF8
    Write-Log "FPS $($jogo.Exe) media=$($res.Media) low1=$($res.Low1) travadas=$($res.Travadas) ($sit)"
    Show-FpsHistorico $jogo.Exe
    if ($sit -like 'ANTES*') {
        Write-Host ''
        Write-Note 'Proximo passo: use a opcao 1 (Otimizar), reinicie e faca este teste de novo para comparar.'
    }
}
