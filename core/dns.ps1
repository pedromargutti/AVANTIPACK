# =====================================================================
#  AVANTIPACK - DNS mais rapido
#  Mede no PROPRIO PC o tempo de resposta do DNS atual e dos publicos
#  (Cloudflare, Google, Quad9) e aplica o mais rapido, com Desfazer.
#  Substitui a ideia de levar o DnsJumper.exe dentro do pack.
#  Obs honesta: DNS acelera abrir sites, launchers e o "encontrar
#  servidor"; ele NAO muda o ping dentro da partida.
#  Carregado por avanti.ps1 (dot-source). Sem acentos de proposito.
# =====================================================================

$DNS_OPCOES = @(
    @{ Nome = 'Cloudflare'; Ips = @('1.1.1.1', '1.0.0.1') },
    @{ Nome = 'Google';     Ips = @('8.8.8.8', '8.8.4.4') },
    @{ Nome = 'Quad9';      Ips = @('9.9.9.9', '149.112.112.112') }
)
$DNS_DOMINIOS = @('google.com', 'youtube.com', 'discord.com', 'steampowered.com', 'riotgames.com', 'epicgames.com', 'microsoft.com')

function Measure-Dns([string]$Server, [int]$Rodadas = 3) {
    $tempos = New-Object System.Collections.Generic.List[double]
    $falhas = 0
    for ($r = 0; $r -lt $Rodadas; $r++) {
        foreach ($d in $DNS_DOMINIOS) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                [void](Resolve-DnsName -Name $d -Server $Server -Type A -DnsOnly -NoHostsFile -QuickTimeout -ErrorAction Stop)
                $sw.Stop(); $tempos.Add($sw.Elapsed.TotalMilliseconds)
            } catch { $sw.Stop(); $falhas++; $tempos.Add(1000) }
        }
    }
    $ord = @($tempos | Sort-Object)
    $med = $ord[[int][math]::Floor($ord.Count / 2)]
    return [pscustomobject]@{ Servidor = $Server; Mediana = [math]::Round($med, 1); Falhas = $falhas }
}

function Get-ActiveAdapters {
    return @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
}

function Mod-DNS {
    $script:CurMod = 'dns'
    Write-Title 'DNS MAIS RAPIDO PARA O SEU PC'
    $ads = Get-ActiveAdapters
    if ($ads.Count -eq 0) { Write-Warn 'Nenhuma placa de rede conectada.'; return }

    # DNS atual
    $atuais = @()
    foreach ($a in $ads) {
        $s = (Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
        foreach ($x in $s) { if ($atuais -notcontains $x) { $atuais += $x } }
        Write-Note ("{0}: DNS atual = {1}" -f $a.Name, $(if ($s) { $s -join ', ' } else { 'automatico' }))
    }

    Write-Info 'Medindo (cerca de 20 segundos)...'
    $res = @()
    if ($atuais.Count -gt 0) {
        $m = Measure-Dns $atuais[0]
        $res += [pscustomobject]@{ Nome = 'Atual (provedor/roteador)'; Ips = $atuais; Mediana = $m.Mediana; Falhas = $m.Falhas; Atual = $true }
    }
    foreach ($o in $DNS_OPCOES) {
        $m = Measure-Dns $o.Ips[0]
        $res += [pscustomobject]@{ Nome = $o.Nome; Ips = $o.Ips; Mediana = $m.Mediana; Falhas = $m.Falhas; Atual = $false }
    }
    Write-Host ''
    foreach ($r in ($res | Sort-Object Mediana)) {
        $cor = if ($r.Falhas -gt 0) { 'Yellow' } elseif ($r.Atual) { 'Gray' } else { 'White' }
        Write-Host ("  {0,-28} {1,7} ms   {2}" -f $r.Nome, $r.Mediana, $(if ($r.Falhas) { "($($r.Falhas) falhas)" } else { '' })) -ForegroundColor $cor
    }
    Write-Host ''

    $melhor = $res | Where-Object { $_.Falhas -eq 0 } | Sort-Object Mediana | Select-Object -First 1
    $atual  = $res | Where-Object { $_.Atual } | Select-Object -First 1
    if (-not $melhor) { Write-Warn 'Todos os DNS falharam. Verifique a conexao (opcao 3 (Consertar um problema) > Internet).'; return }
    if ($melhor.Atual) { Write-Ok 'O seu DNS atual ja e o mais rapido. Nada a mudar.'; return }
    if ($atual -and $atual.Falhas -eq 0 -and ($atual.Mediana - $melhor.Mediana) -lt 3) {
        Write-Ok "Diferenca menor que 3 ms para o $($melhor.Nome). Nao vale a pena trocar."
        if (-not (Confirm-Step "Trocar para $($melhor.Nome) mesmo assim?" $false)) { return }
    } elseif (-not (Confirm-Step "Aplicar $($melhor.Nome) ($($melhor.Ips -join ' / ')) nas placas de rede conectadas?" $true)) { return }

    foreach ($a in $ads) {
        # Backup: DNS fixo (NameServer no registro) ou automatico (DHCP)
        $guid = $a.InterfaceGuid
        $ns = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid" -Name NameServer -ErrorAction SilentlyContinue).NameServer
        if ($ns) {
            $lista = ($ns -split '[ ,]' | Where-Object { $_ } | ForEach-Object { "'$_'" }) -join ','
            $undo = "Set-DnsClientServerAddress -InterfaceAlias '$($a.Name)' -ServerAddresses @($lista)"
        } else {
            $undo = "Set-DnsClientServerAddress -InterfaceAlias '$($a.Name)' -ResetServerAddresses"
        }
        Add-Backup 'PS' "dns_$guid" '' '1' '' $undo
        try {
            Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $melhor.Ips -ErrorAction Stop
            Write-Ok "$($a.Name): DNS agora e $($melhor.Nome)."
            $script:Applied++
        } catch { Write-Warn "$($a.Name): $($_.Exception.Message)" }
    }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Note 'Para voltar ao DNS anterior: opcao 6 (Desfazer) > dns.'
}
