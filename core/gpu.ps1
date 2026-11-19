# =====================================================================
#  AVANTIPACK - modulo de placa de video
#  - Verificacao: driver, PCIe, Resizable BAR, VRAM, monitor/Hz
#  - Auto-otimizacao do painel NVIDIA (perfil global via Profile Inspector)
#  - Auto-otimizacao AMD (chaves do driver, melhor esforco)
#  Carregado por avanti.ps1 (dot-source). Sem acentos de proposito.
#
#  IDs NVIDIA conferidos em NvApiDriverSettings.h (repositorio oficial
#  github.com/NVIDIA/nvapi). Valores gravados em decimal no .nip.
# =====================================================================

$NV = @{
    VSYNCMODE        = 11041231     # 0x00A879CF  Vertical Sync
    VSYNC_FORCEOFF   = 138504007    # 0x08416747
    VSYNC_FORCEON    = 1199655232   # 0x47814940
    PSTATE           = 274197361    # 0x1057EB71  Power management mode
    PSTATE_PREFERMAX = 1
    PRERENDER        = 8102046      # 0x007BA09E  Max pre-rendered frames (Low Latency Mode = On)
    QUALITY          = 13510289     # 0x00CE2691  Texture filtering - Quality
    QUALITY_HIGHPERF = 20           # 0x14 High performance
    ANISO_OPTS2      = 15151633     # 0x00E73211  Anisotropic sample optimization
    SHADERCACHE      = 1675263      # 0x00198FFF  Shader cache on/off
    SHADERCACHE_MAX  = 11306135     # 0x00AC8497  Shader cache size (MB)
    FRL_FPS          = 277041154    # 0x10835002  Max frame rate
}

# ---------------------------------------------------------------------
#  Monitor / taxa de atualizacao (Win32 EnumDisplaySettings)
# ---------------------------------------------------------------------
function Initialize-DisplayApi {
    if ('AvDisplay' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class AvDisplay {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion; public short dmDriverVersion; public short dmSize; public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX; public int dmPositionY; public int dmDisplayOrientation; public int dmDisplayFixedOutput;
        public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels; public int dmBitsPerPel; public int dmPelsWidth; public int dmPelsHeight;
        public int dmDisplayFlags; public int dmDisplayFrequency;
        public int dmICMMethod; public int dmICMIntent; public int dmMediaType; public int dmDitherType;
        public int dmReserved1; public int dmReserved2; public int dmPanningWidth; public int dmPanningHeight;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DISPLAY_DEVICE {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]  public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool EnumDisplaySettings(string dev, int mode, ref DEVMODE dm);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int ChangeDisplaySettingsEx(string dev, ref DEVMODE dm, IntPtr hwnd, int flags, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool EnumDisplayDevices(string dev, int i, ref DISPLAY_DEVICE dd, int flags);

    public static DEVMODE NewMode() { DEVMODE d = new DEVMODE(); d.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE)); return d; }
    public static DISPLAY_DEVICE NewDevice() { DISPLAY_DEVICE d = new DISPLAY_DEVICE(); d.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE)); return d; }
}
'@
}

# Lista os monitores ativos: nome, placa que controla, Hz atual e Hz maximo na resolucao atual
function Get-Monitors {
    Initialize-DisplayApi
    $out = @()
    for ($i = 0; $i -lt 16; $i++) {
        $dd = [AvDisplay]::NewDevice()
        if (-not [AvDisplay]::EnumDisplayDevices($null, $i, [ref]$dd, 0)) { break }
        if (($dd.StateFlags -band 1) -eq 0) { continue }       # nao esta na area de trabalho
        $cur = [AvDisplay]::NewMode()
        if (-not [AvDisplay]::EnumDisplaySettings($dd.DeviceName, -1, [ref]$cur)) { continue }
        $max = $cur.dmDisplayFrequency
        $m = 0
        while ($true) {
            $dm = [AvDisplay]::NewMode()
            if (-not [AvDisplay]::EnumDisplaySettings($dd.DeviceName, $m, [ref]$dm)) { break }
            if ($dm.dmPelsWidth -eq $cur.dmPelsWidth -and $dm.dmPelsHeight -eq $cur.dmPelsHeight -and
                $dm.dmBitsPerPel -eq $cur.dmBitsPerPel -and $dm.dmDisplayFrequency -gt $max) { $max = $dm.dmDisplayFrequency }
            $m++
            if ($m -gt 2000) { break }
        }
        $out += [pscustomobject]@{
            Device = $dd.DeviceName; Placa = $dd.DeviceString
            Largura = $cur.dmPelsWidth; Altura = $cur.dmPelsHeight
            HzAtual = $cur.dmDisplayFrequency; HzMax = $max
            Primario = (($dd.StateFlags -band 4) -ne 0)
        }
    }
    return $out
}

function Set-MonitorHz([string]$Device, [int]$Hz) {
    Initialize-DisplayApi
    $dm = [AvDisplay]::NewMode()
    if (-not [AvDisplay]::EnumDisplaySettings($Device, -1, [ref]$dm)) { return $false }
    $dm.dmDisplayFrequency = $Hz
    $dm.dmFields = 0x400000                                # DM_DISPLAYFREQUENCY
    $r = [AvDisplay]::ChangeDisplaySettingsEx($Device, [ref]$dm, [IntPtr]::Zero, 1, [IntPtr]::Zero)  # CDS_UPDATEREGISTRY
    return ($r -eq 0)
}

# ---------------------------------------------------------------------
#  Verificacao da placa de video
# ---------------------------------------------------------------------
function Get-NvidiaSmi {
    $c = @("$env:SystemRoot\System32\nvidia-smi.exe", "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe")
    foreach ($p in $c) { if (Test-Path $p) { return $p } }
    return $null
}

function Test-GPU($hw) {
    Write-Title 'VERIFICACAO DA PLACA DE VIDEO'
    $problemas = 0

    # --- Driver
    $vcs = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -and $_.Name -notmatch 'Basic Display|Remote|Virtual|Parsec|Mirror|Meta' })
    foreach ($v in $vcs) {
        $idade = $null
        if ($v.DriverDate) { $idade = [int]((Get-Date) - $v.DriverDate).TotalDays }
        Write-Host ("  {0}" -f $v.Name) -ForegroundColor White
        Write-Note ("Driver {0}  ({1})" -f $v.DriverVersion, $(if ($v.DriverDate) { $v.DriverDate.ToString('dd/MM/yyyy') } else { 'data desconhecida' }))
        if ($v.Name -match 'Basic Display' -or $v.DriverVersion -eq $null) {
            Write-Warn 'Sem driver de video instalado! Instale o driver oficial (menu "Programas uteis" (opcao 4)).'; $problemas++
        } elseif ($idade -ne $null -and $idade -gt 240) {
            Write-Warn "Driver com $idade dias. Vale atualizar (driver novo traz otimizacao para jogos recentes)."; $problemas++
        } else { Write-Ok 'Driver recente.' }
    }

    # --- NVIDIA: PCIe, Resizable BAR, VRAM, temperatura (via nvidia-smi oficial)
    if ($hw.GPU_VENDOR -eq 'NVIDIA') {
        $smi = Get-NvidiaSmi
        if ($smi) {
            $q = & $smi --query-gpu=name,memory.total,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max,temperature.gpu --format=csv,noheader,nounits 2>$null | Select-Object -First 1
            if ($q) {
                $f = $q.Split(',') | ForEach-Object { $_.Trim() }
                Write-Note ("VRAM {0} MB  |  PCIe Gen {1} x{2} (maximo x{3})  |  {4} C" -f $f[1], $f[2], $f[3], $f[4], $f[5])
                if ($hw.LAPTOP -ne '1' -and [int]$f[3] -lt [int]$f[4]) {
                    Write-Warn "Placa rodando em x$($f[3]) mas suporta x$($f[4]): confira se esta no 1o slot PCIe x16 e bem encaixada."
                    $problemas++
                }
                $mem = & $smi -q -d MEMORY 2>$null
                $bar = $null; $inBar = $false
                foreach ($l in $mem) {
                    if ($l -match 'BAR1') { $inBar = $true; continue }
                    if ($inBar -and $l -match 'Total\s*:\s*(\d+)\s*MiB') { $bar = [int]$Matches[1]; break }
                }
                if ($bar -ne $null) {
                    if ($bar -gt 256) { Write-Ok "Resizable BAR ATIVO (BAR1 = $bar MiB)." }
                    else {
                        Write-Warn 'Resizable BAR DESLIGADO (BAR1 = 256 MiB). Ligue na BIOS: Guia de BIOS, item 2.'
                        Write-Note '(Placas GTX 10/16 e mais antigas nao suportam - ignore se for o caso.)'
                        $problemas++
                    }
                }
            }
        } else { Write-Skip 'nvidia-smi nao encontrado (vem com o driver NVIDIA).' }
    }

    # --- Monitores: Hz e placa certa
    Write-Host ''
    $mons = @()
    try { $mons = @(Get-Monitors) } catch { Write-Skip 'Nao foi possivel ler os monitores.' }
    $temDedicada = @('NVIDIA', 'AMD', 'INTEL_ARC') -contains $hw.GPU_VENDOR
    foreach ($m in $mons) {
        $tag = if ($m.Primario) { ' (principal)' } else { '' }
        Write-Host ("  Monitor {0}{1}: {2}x{3} @ {4} Hz  -  ligado em: {5}" -f $m.Device.Replace('\\.\', ''), $tag, $m.Largura, $m.Altura, $m.HzAtual, $m.Placa)
        if ($temDedicada -and $hw.LAPTOP -ne '1' -and $m.Placa -notmatch 'NVIDIA|Radeon.*(RX|Pro)|Arc.*[AB]\d{3}') {
            Write-Warn 'Este monitor esta ligado no video da PLACA-MAE, nao na placa de video! Mude o cabo para a placa de video.'
            $problemas++
        }
        if ($m.HzMax -gt ($m.HzAtual + 1)) {
            Write-Warn "Monitor suporta $($m.HzMax) Hz mas esta rodando a $($m.HzAtual) Hz."
            $problemas++
            if (Want 'E1' "Mudar para $($m.HzMax) Hz agora?" $true) {
                Add-Backup 'DISPLAY' $m.Device 'Hz' '1' '' ([string]$m.HzAtual)
                if (Set-MonitorHz $m.Device $m.HzMax) { Write-Ok "Monitor agora em $($m.HzMax) Hz."; $m.HzAtual = $m.HzMax }   # o limite de FPS do G-SYNC usa o Hz novo
                else { Write-Warn 'O Windows nao aceitou a mudanca. Ajuste em Configuracoes > Tela > Tela avancada.' }
            }
        } else { Write-Ok "Taxa de atualizacao no maximo ($($m.HzAtual) Hz)." }
    }
    Write-Host ''
    if ($problemas -eq 0) { Write-Ok 'Placa de video verificada: nenhum problema encontrado.' }
    else { Write-Warn "$problemas ponto(s) de atencao encontrado(s) acima." }
    return $mons
}

# ---------------------------------------------------------------------
#  NVIDIA: perfil global automatico
# ---------------------------------------------------------------------
function Get-NpiExe {
    $p = Join-Path $Root 'apps\NVIDIAProfileInspector\nvidiaProfileInspector.exe'
    if (Test-Path $p) { return $p }
    return $null
}

function Invoke-Npi([string]$Exe, [string[]]$ArgList, [int]$Timeout = 90) {
    $p = Start-Process -FilePath $Exe -ArgumentList $ArgList -WorkingDirectory (Split-Path $Exe) -PassThru -WindowStyle Hidden
    if (-not $p.WaitForExit($Timeout * 1000)) {
        try { $p.Kill() } catch {}
        return $false
    }
    return $true
}

function New-NipXml([array]$Settings) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-16"?>')
    [void]$sb.AppendLine('<ArrayOfProfile>')
    [void]$sb.AppendLine('  <Profile>')
    [void]$sb.AppendLine('    <ProfileName>Base Profile</ProfileName>')
    [void]$sb.AppendLine('    <Executeables />')
    if ($Settings.Count -eq 0) { [void]$sb.AppendLine('    <Settings />') }
    else {
        [void]$sb.AppendLine('    <Settings>')
        foreach ($s in $Settings) {
            [void]$sb.AppendLine('      <ProfileSetting>')
            [void]$sb.AppendLine("        <SettingNameInfo>$($s.Nome)</SettingNameInfo>")
            [void]$sb.AppendLine("        <SettingID>$($s.Id)</SettingID>")
            [void]$sb.AppendLine("        <SettingValue>$($s.Valor)</SettingValue>")
            [void]$sb.AppendLine('        <ValueType>Dword</ValueType>')
            [void]$sb.AppendLine('      </ProfileSetting>')
        }
        [void]$sb.AppendLine('    </Settings>')
    }
    [void]$sb.AppendLine('  </Profile>')
    [void]$sb.AppendLine('</ArrayOfProfile>')
    return $sb.ToString()
}

function Optimize-NvidiaPanel($hw, $mons) {
    Write-Title 'AUTO-OTIMIZACAO DO PAINEL NVIDIA'
    $npi = Get-NpiExe
    if (-not $npi) { Write-Warn 'NVIDIA Profile Inspector nao encontrado em apps\NVIDIAProfileInspector.'; return }

    $prim = $mons | Where-Object { $_.Primario } | Select-Object -First 1
    $hz = if ($prim) { [int]$prim.HzAtual } else { 0 }

    Write-Host ''
    Write-Host '  PERGUNTA RAPIDA SOBRE O SEU MONITOR' -ForegroundColor White
    Write-Note 'O monitor tem G-SYNC ou FreeSync? (costuma vir escrito na caixa ou na etiqueta atras dele)'
    Write-Note 'Nao sabe? Monitor gamer de 144 Hz ou mais: responda S.  Monitor comum de 60 Hz: responda N.'
    if ($hz -ge 120) { Write-Note "O seu monitor principal esta em $hz Hz." }
    $vrr = Confirm-Step 'Tem G-SYNC/FreeSync?'

    $set = @()
    $set += @{ Nome = 'Maximum pre-rendered frames'; Id = $NV.PRERENDER; Valor = 1
               Desc = 'Modo de baixa latencia: Ativado' }
    $set += @{ Nome = 'Texture filtering - Quality'; Id = $NV.QUALITY; Valor = $NV.QUALITY_HIGHPERF
               Desc = 'Filtragem de textura - Qualidade: Alto desempenho' }
    $set += @{ Nome = 'Anisotropic sample optimization'; Id = $NV.ANISO_OPTS2; Valor = 1
               Desc = 'Otimizacao de amostra anisotropica: Ativada' }
    $set += @{ Nome = 'Shader Cache'; Id = $NV.SHADERCACHE; Valor = 1
               Desc = 'Cache de sombreador: Ativado' }
    $livreGB = [math]::Round((Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))).Free / 1GB)
    if ($livreGB -ge 60) { $cache = 4294967295; $cdesc = 'Ilimitado' } else { $cache = 10240; $cdesc = '10 GB (pouco espaco livre no disco)' }
    $set += @{ Nome = 'Shader disk cache maximum size'; Id = $NV.SHADERCACHE_MAX; Valor = $cache
               Desc = "Tamanho do cache de sombreador: $cdesc" }
    if ($hw.LAPTOP -ne '1') {
        $set += @{ Nome = 'Power management mode'; Id = $NV.PSTATE; Valor = $NV.PSTATE_PREFERMAX
                   Desc = 'Gerenciamento de energia: Preferir desempenho maximo' }
    }
    if ($vrr) {
        $set += @{ Nome = 'Vertical Sync'; Id = $NV.VSYNCMODE; Valor = $NV.VSYNC_FORCEON
                   Desc = 'Sincronizacao vertical: Ativada (correto com G-SYNC)' }
        if ($hz -ge 60) {
            $cap = $hz - [math]::Max(3, [math]::Round($hz * 0.03))
            $set += @{ Nome = 'Frame Rate Limiter'; Id = $NV.FRL_FPS; Valor = $cap
                       Desc = "Taxa maxima de quadros: $cap FPS (abaixo dos $hz Hz para o G-SYNC sempre agir)" }
        }
    } else {
        $set += @{ Nome = 'Vertical Sync'; Id = $NV.VSYNCMODE; Valor = $NV.VSYNC_FORCEOFF
                   Desc = 'Sincronizacao vertical: Desativada' }
    }

    # 1) Backup do perfil global atual (para o Desfazer)
    $nvBak = Join-Path $BackupDir 'nvidia_base_backup.nip'
    if (-not (Test-Backed 'NVIDIA' 'Base Profile' 'nip')) {
        Write-Info 'Salvando as configuracoes atuais do painel NVIDIA...'
        $dir = Split-Path $npi
        $antes = @(Get-ChildItem $dir -Filter 'CustomProfiles_*.nip' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        [void](Invoke-Npi $npi @('-exportCustomized') 60)
        $novo = Get-ChildItem $dir -Filter 'CustomProfiles_*.nip' -ErrorAction SilentlyContinue |
                Where-Object { $antes -notcontains $_.FullName } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $baseXml = $null
        if ($novo) {
            try {
                [xml]$x = Get-Content $novo.FullName -Raw
                $bp = $x.ArrayOfProfile.Profile | Where-Object { $_.ProfileName -eq 'Base Profile' } | Select-Object -First 1
                if ($bp) {
                    $baseXml = '<?xml version="1.0" encoding="utf-16"?>' + "`r`n<ArrayOfProfile>`r`n" + $bp.OuterXml + "`r`n</ArrayOfProfile>"
                }
            } catch {}
            Move-Item $novo.FullName (Join-Path $BackupDir ('nvidia_todos_perfis_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.nip')) -Force
        }
        if (-not $baseXml) { $baseXml = New-NipXml @() }   # nao havia ajustes globais: o undo volta ao padrao do driver
        Set-Content -Path $nvBak -Value $baseXml -Encoding Unicode
        $undo = "Start-Process -FilePath '$npi' -ArgumentList @('-silentImport','-replaceImport','`"$nvBak`"') -Wait"
        Add-Backup 'NVIDIA' 'Base Profile' 'nip' '1' '' $undo
        Write-Ok 'Backup salvo em core\dados\backup\nvidia_base_backup.nip'
    }

    # 2) Importa o perfil AVANTIPACK (merge: so muda o que esta na lista)
    $nip = Join-Path $DataDir 'avantipack_nvidia.nip'
    Set-Content -Path $nip -Value (New-NipXml $set) -Encoding Unicode
    Write-Info 'Aplicando o perfil AVANTIPACK no driver NVIDIA...'
    $ok = Invoke-Npi $npi @('-silentImport', '-mergeImport', "`"$nip`"") 90
    if ($ok) {
        Write-Ok 'Painel NVIDIA configurado:'
        foreach ($s in $set) { Write-Note "  - $($s.Desc)" }
        Write-Log ('NVIDIA perfil aplicado: ' + (($set | ForEach-Object { "$($_.Nome)=$($_.Valor)" }) -join '; '))
        Write-Note 'Confira em: Painel de Controle NVIDIA > Gerenciar configuracoes 3D > Configuracoes globais.'
        if ($vrr) { Write-Note 'Nos jogos com NVIDIA Reflex: ligue o Reflex (ele substitui o modo de baixa latencia).' }
    } else {
        Write-Warn 'O Profile Inspector nao terminou a tempo. Abra o Painel NVIDIA e siga o guia visual (menu principal > opcao 5, Guias).'
    }
}

# ---------------------------------------------------------------------
#  AMD: chaves do driver (melhor esforco)
#  A AMD nao tem formato oficial de importacao; o caminho suportado e o
#  SDK ADLX. Gravamos so chaves conhecidas e inofensivas, com backup.
# ---------------------------------------------------------------------
function Optimize-AmdPanel($hw) {
    Write-Title 'AUTO-OTIMIZACAO AMD RADEON'
    $cls = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    $n = 0
    foreach ($k in Get-ChildItem $cls -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }) {
        $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
        if ($p.ProviderName -notmatch 'Advanced Micro Devices|AMD|ATI' -or $p.DriverDesc -notmatch 'Radeon') { continue }
        $path = "$cls\$($k.PSChildName)"
        Write-Info "Ajustando: $($p.DriverDesc)"
        Set-Reg $path 'KMD_DeLagEnabled'  1 | Out-Null     # Radeon Anti-Lag ligado
        Set-Reg $path 'KMD_ChillEnabled'  0 | Out-Null     # Radeon Chill desligado (incompativel com Anti-Lag)
        if ($hw.LAPTOP -ne '1') { Set-Reg $path 'EnableUlps' 0 | Out-Null }   # sem estado de ultra baixo consumo (desktop)
        $n++
    }
    if ($n -eq 0) { Write-Skip 'Nenhuma placa Radeon encontrada no registro.'; return }
    Write-Ok "Anti-Lag ligado e Chill desligado em $n adaptador(es) (vale apos reiniciar)."
    Write-Host ''
    Write-Warn 'A AMD nao permite importar todas as opcoes do Adrenalin. Confira e complete em 2 minutos:'
    Write-Note 'AMD Software > Jogos > Graficos > Perfil: Personalizado'
    Write-Note '  HYPR-RX: Desligado | Radeon Boost: Desligado | Enhanced Sync: Desligado'
    Write-Note '  Avancado > Qualidade de filtragem de textura: Desempenho'
    Write-Note 'O guia visual (menu principal > opcao 5, Guias) mostra cada tela.'
    $script:NeedReboot = $true
}

# ---------------------------------------------------------------------
#  Modulo principal
# ---------------------------------------------------------------------
function Mod-GPU {
    if (-not (WantAny @('E1','E2','E3','E4'))) { return }
    $script:CurMod = 'gpu'
    $hw = Load-HW
    $mons = Test-GPU $hw

    Write-Title 'AJUSTES DO WINDOWS PARA A PLACA DE VIDEO'
    $gk = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    if (@('NVIDIA', 'AMD', 'INTEL_ARC') -contains $hw.GPU_VENDOR -and [int]$hw.WIN_BUILD -ge 19041) {
        if (Want 'E2') {
            Set-Reg $gk 'HwSchMode' 2 | Out-Null
            Write-Ok 'Agendamento de GPU acelerado por hardware (HAGS) ligado.'
            $script:NeedReboot = $true
        }
    } else { Write-Skip 'HAGS: nao se aplica a este video/Windows.' }

    if ($hw.LAPTOP -eq '1' -and @('NVIDIA', 'AMD') -contains $hw.GPU_VENDOR) {
        Write-Note 'Notebook com placa dedicada: jogos devem usar a placa dedicada, nao o video integrado.'
        Write-Note 'Configuracoes > Sistema > Tela > Graficos > (jogo) > Opcoes > Alto desempenho.'
    }

    if ($script:Selecao -eq $null) {
        Write-Host ''
        Write-Note 'MPO: desligar so serve para quem tem tela PISCANDO, flicker ou travada ao dar alt+tab.'
        Write-Note 'Desligar tambem tira a "otimizacao de jogos em janela" do Windows 11. Sem problema? Responda N.'
    }
    if (Want 'E4' 'Desativar MPO?' $false) {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode' 5 | Out-Null
        Write-Ok 'MPO desativado.'
        $script:NeedReboot = $true
    }

    switch -Wildcard ($hw.GPU_VENDOR) {
        'NVIDIA' { if (Want 'E3' 'Configurar o PAINEL NVIDIA automaticamente (recomendado)?' $true) { Optimize-NvidiaPanel $hw $mons } }
        'AMD*'   { if (Want 'E3' 'Aplicar a otimizacao automatica da AMD?' $true) { Optimize-AmdPanel $hw } }
        'INTEL*' { Write-Note 'Intel: as poucas opcoes do Intel Graphics Software estao no guia com imagens (opcao 5).' }
    }
    if ($script:Selecao -eq $null -and (Confirm-Step 'Abrir o guia com imagens do painel da sua placa?' $false)) {
        Start-Process (Join-Path $Root 'guias\PAINEIS_VISUAL.html')
    }
}
