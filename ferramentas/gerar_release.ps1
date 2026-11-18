# =====================================================================
#  AVANTIPACK - gera o ZIP de uma nova versao para publicar no GitHub
#  (so para quem mantem o pack; nao precisa ser administrador)
# =====================================================================
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$verFile = Join-Path $Root 'VERSION.txt'
$atual = (Get-Content $verFile -TotalCount 1).Trim()
$p = $atual.Split('.')
$sugestao = "{0}.{1}.{2}" -f $p[0], $p[1], ([int]$p[2] + 1)

Write-Host ''
Write-Host '  GERAR NOVA VERSAO DO AVANTIPACK' -ForegroundColor Cyan
Write-Host "  Versao atual: $atual"
$nova = Read-Host "  Numero da nova versao (ENTER = $sugestao)"
if (-not $nova) { $nova = $sugestao }
if ($nova -notmatch '^\d+\.\d+\.\d+$') { Write-Host '  Use o formato 1.2.3' -ForegroundColor Red; exit 1 }

$cfg = Get-Content (Join-Path $Root 'core\config.txt') -Raw
if ($cfg -notmatch '(?m)^GITHUB_REPO=\S+') {
    Write-Host '  ATENCAO: core\config.txt esta sem GITHUB_REPO. Sem isso, quem receber o pack nao recebe atualizacoes.' -ForegroundColor Yellow
    if ((Read-Host '  Continuar mesmo assim? (S/N)') -notmatch '^[sS]') { exit 1 }
}

Set-Content -Path $verFile -Value $nova -Encoding ASCII

# Copia limpa (sem backups, logs e dados do SEU PC)
$saida = Join-Path $PSScriptRoot 'saida'
$stage = Join-Path $env:TEMP ('avanti_release_' + [IO.Path]::GetRandomFileName())
$dest = Join-Path $stage 'AVANTIPACK'
New-Item -ItemType Directory -Path $dest -Force | Out-Null
foreach ($it in Get-ChildItem $Root -Force) {
    if (@('backup', 'logs', 'data', '.git') -contains $it.Name) { continue }
    Copy-Item -Path $it.FullName -Destination $dest -Recurse -Force
}
$lixo = Join-Path $dest 'ferramentas\saida'
if (Test-Path $lixo) { Remove-Item $lixo -Recurse -Force }
New-Item -ItemType Directory -Path $saida -Force | Out-Null
$zip = Join-Path $saida ("AVANTIPACK_v{0}.zip" -f $nova)
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $dest -DestinationPath $zip
Remove-Item $stage -Recurse -Force

Write-Host ''
Write-Host "  PRONTO: $zip" -ForegroundColor Green
Write-Host ''
Write-Host '  Agora no GitHub:' -ForegroundColor White
Write-Host '   1. Abra o seu repositorio > Releases > "Draft a new release"'
Write-Host "   2. Em 'Choose a tag' digite  v$nova  e clique em 'Create new tag'"
Write-Host "   3. Titulo: AVANTIPACK v$nova  | escreva o que mudou"
Write-Host "   4. Arraste o arquivo AVANTIPACK_v$nova.zip para a area de anexos"
Write-Host '   5. Clique em "Publish release"'
Write-Host ''
Write-Host '  Quem tem o pack vai ver "Nova versao disponivel" no menu e atualizar com a tecla U.'
Start-Process explorer.exe $saida
Read-Host '  ENTER para fechar' | Out-Null
