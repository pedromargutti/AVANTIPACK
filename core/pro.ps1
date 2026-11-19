# =====================================================================
#  AVANTIPACK - o que e GRATIS e o que e do AVANTIPACK Pro
#  O AVANTIPACK Pro e um programa separado (AVANTIPACK Pro.exe). Este
#  pack gratis nao tem o codigo do Pro: as opcoes do Pro so mostram o aviso.
#  Carregado por avanti.ps1 (dot-source). Sem acentos de proposito.
# =====================================================================

# Opcoes que so existem no AVANTIPACK Pro (o codigo delas NAO esta neste pack)
$MODULOS_PRO = @('fps', 'cfgjogos', 'termico', 'modojogo', 'relatorio', 'inputlag', 'internet', 'inicializacao',
                 'agendar', 'perfisjogos', 'jogos', 'dns', 'avancado', 'recomendado', 'pro',
                 'debloat', 'sistema', 'energia', 'gpu', 'rede', 'armazenamento')

function Test-SoPro([string]$Modulo) { return ($MODULOS_PRO -contains $Modulo) }

function Show-SoPro {
    Write-Title 'FUNCAO DO AVANTIPACK PRO'
    Write-Host ''
    Write-Host '  Esta opcao faz parte do AVANTIPACK Pro.' -ForegroundColor Yellow
    Write-Host ''
    Write-Note 'No GRATIS voce tem: Otimizar automatico, Verificar + Nota do PC, Limpeza rapida,'
    Write-Note 'Preparar para jogar, Consertar, Programas uteis, Guias e Desfazer.'
    Write-Host ''
    Write-Note 'O Pro libera: teste de FPS e de temperatura, configurar os jogos sozinho, Modo Jogo,'
    Write-Note 'Personalizado (escolher cada ajuste), prioridade dos jogos, perfil NVIDIA, DNS,'
    Write-Note 'ajustes avancados, input lag, relatorio e manutencao semanal.'
    Write-Host ''
    Write-Note 'O Pro e um app proprio, com visual novo: baixe o "AVANTIPACK Pro.exe" e ative a sua chave.'
    $cfg = $null; try { $cfg = Get-PackConfig } catch {}
    if ($cfg -and $cfg.LOJA_PRO) { Write-Note ("Para comprar: " + $cfg.LOJA_PRO) }
}

# Desfazer do Modo Jogo funciona mesmo no modo gratis
if (-not (Get-Command Disable-ModoJogo -ErrorAction SilentlyContinue)) {
    function Disable-ModoJogo {
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -match 'modojogo_vigia' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Unregister-ScheduledTask -TaskName 'AVANTIPACK Modo Jogo' -Confirm:$false -ErrorAction SilentlyContinue
        Write-Ok 'Modo Jogo automatico DESLIGADO.'
    }
}
