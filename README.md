<div align="center">

<img src="docs/img/banner.svg" alt="AVANTIPACK" width="100%">

<br>

<a href="../../releases/latest"><img src="https://img.shields.io/github/v/release/pedromargutti/AVANTIPACK?style=for-the-badge&color=1d43ff&label=vers%C3%A3o&cacheSeconds=600" alt="versão"></a>
<a href="../../releases"><img src="https://img.shields.io/github/downloads/pedromargutti/AVANTIPACK/total?style=for-the-badge&color=008cff&label=downloads&cacheSeconds=600" alt="downloads"></a>
<img src="https://img.shields.io/badge/Windows-10%20%7C%2011-00b4ff?style=for-the-badge&logo=windows&logoColor=white" alt="Windows 10 e 11">
<img src="https://img.shields.io/badge/PowerShell-5.1-00e1ff?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell">
<img src="https://img.shields.io/badge/100%25-revers%C3%ADvel-16c60c?style=for-the-badge" alt="100% reversível">

<br><br>

**Otimização do Windows para jogos que se adapta às peças do seu PC.**<br>
Menos input lag, FPS mais estável, Windows mais leve, e **tudo pode ser desfeito com um clique**.

<br>

<a href="../../releases/latest"><img src="https://img.shields.io/badge/⬇%20BAIXAR%20A%20ÚLTIMA%20VERSÃO-1d43ff?style=for-the-badge" alt="Baixar" height="42"></a>

</div>

<br>

## 🆕 Novidades

> **Versão mais nova:** [veja o que mudou](../../releases/latest) · [histórico completo](core/NOVIDADES.md)

<details open>
<summary><b>v0.7.6</b> — setas em todas as telas, teste de FPS e jogos atualizados</summary>

- ⌨️ **Setas do teclado em todas as telas** e listas de marcar com ESPAÇO
- 🖥️ Tela **no meio**, letra maior e menu **estável** (aguenta tela cheia)
- 📊 **Teste de FPS antes e depois**: FPS médio, 1% low e travadinhas
- 🧠 **Dual channel** e 💻 **placa dedicada no notebook**
- 🆘 **Relatório para ajuda** pronto para mandar
- 🎮 Configurações de **19 jogos atualizadas** (nov/2026)

</details>

<details>
<summary><b>v0.7.5</b> — pasta organizada e AVANTIPACK.exe com a logo</summary>

- 🧹 Na pasta só ficam o **AVANTIPACK.exe**, o LEIA-ME e as pastas `apps`, `core` e `guias`
- 🔵 **AVANTIPACK.exe com a logo**: dois cliques e pronto
- 📁 Dados do seu PC juntos em `core\dados` (migra sozinho, sem perder nada)

</details>

<details>
<summary><b>v0.7.4</b> — programas instalados sozinhos</summary>

- 📦 **[A] INSTALAR TUDO**: baixa e instala os programas certos para o seu PC, cada um na sua pasta
- 🌐 **Drivers**: abre o site, você clica em BAIXAR e o pack faz o resto
- 🔠 Letra maior e atalho com a logo

</details>

<br>

## 🎬 Veja funcionando

<div align="center">
<img src="docs/img/demo.gif" alt="Otimização automática em ação" width="780">
<br><sub>Modo <b>Automático</b>: o pack escolhe só o que é seguro para <i>este</i> PC e mostra cada etapa.</sub>
</div>

<br>

## ✨ Por que o AVANTIPACK é diferente

<table>
<tr>
<td width="50%" valign="top">

### 🔍 Lê o seu hardware
Detecta processador, placa de vídeo, RAM, disco e versão do Windows. Ajuste de NVIDIA não roda em placa AMD. Ajuste de SSD não roda em HD.

</td>
<td width="50%" valign="top">

### ↩️ Tudo é reversível
Cria ponto de restauração e guarda **o valor original de cada ajuste**. Desfaça tudo ou recoloque só a função que você usa.

</td>
</tr>
<tr>
<td valign="top">

### 🎯 Feito para competitivo
Foco em input lag: Reflex/Anti-Lag no driver, monitor no Hz máximo, mouse 1:1, dispositivos sem economia de energia, teste com pontuação.

</td>
<td valign="top">

### 🚫 Sem placebo
Nada de "+200 FPS com um regedit". Só ajustes com efeito comprovado. O que não funciona (ou faz mal) fica de fora e é [explicado por quê](guias/O_QUE_NAO_FAZEMOS.txt).

</td>
</tr>
<tr>
<td valign="top">

### 👶 Fácil para leigo
Menu em português com explicação em cada opção. Guias com telas ilustradas mostrando **onde clicar**.

</td>
<td valign="top">

### 🔄 Sempre atualizado
Avisa quando sai versão nova e atualiza sozinho. Avisa também quando um update do Windows desfez seus ajustes.

</td>
</tr>
</table>

<br>

## 🖥️ O menu

<div align="center">
<img src="docs/img/menu.png" alt="Menu principal do AVANTIPACK" width="760">
<br><sub>As faixas coloridas só aparecem quando há algo a avisar.</sub>
</div>

<br>

| | Opção | O que faz |
|:-:|---|---|
| 🟢 | **Otimizar meu PC** | **Automático**, **Personalizado** (você escolhe por categoria) ou **Reaplicar** depois de update do Windows |
| 📊 | **Teste de FPS** (F) | Mede FPS médio, 1% low e travadinhas jogando, antes e depois de otimizar |
| 🔵 | **Verificar meu PC** | Peças, problemas (RAM sem XMP, monitor em 60 Hz, driver velho), **teste de input lag com nota** e teste da internet |
| 🔧 | **Consertar um problema** | 19 reparos: sem internet, sem som, microfone, Loja, Windows Update, Alt+Tab no 24H2... |
| 📦 | **Programas úteis** | **[A] Instalar tudo automático**: programas e drivers certos para o seu PC, cada um na sua pasta, com o passo a passo |
| 📖 | **Guias** | Painéis NVIDIA/AMD/Intel ilustrados, BIOS por fabricante, limite de FPS, config dentro dos jogos |
| 🔴 | **Desfazer / recolocar** | Desfaz tudo ou só uma função, reinstala apps, religa funções do Windows |
| 🆘 | **Relatório para ajuda** (R) | Arquivo com tudo do PC para mandar a quem te ajuda, sem dados pessoais |

<br>

## 🎛️ Você no controle

Prefere escolher? No modo **Personalizado** cada ajuste tem explicação, e você marca ou desmarca o que quiser.

<div align="center">
<img src="docs/img/personalizado.gif" alt="Modo personalizado" width="760">
</div>

<details>
<summary><b>📋 Ver as 9 categorias e os 45 ajustes</b></summary>

<br>

| Categoria | O que entra |
|---|---|
| 🛡️ **Segurança** | Ponto de restauração e backup de cada valor original |
| 🧹 **Limpeza e privacidade** | Apps inúteis, telemetria, anúncios, Widgets/Copilot/Recall, serviços e tarefas desnecessários |
| ⚡ **Sistema e input lag** | Mouse 1:1, Modo de Jogo, MMCSS, prioridade do jogo, visual leve, HPET, USB sem economia |
| 🔋 **Energia e processador** | Plano de alto desempenho conforme a CPU (AMD/Intel, desktop/notebook) |
| 🎮 **Placa de vídeo e monitor** | Painel NVIDIA automático, AMD Anti-Lag/Chill/ULPS, monitor no Hz máximo, agendamento da GPU |
| 🌐 **Internet** | Ajustes conservadores de TCP, DNS mais rápido (testado), diagnóstico de ping/jitter/perda |
| 💾 **SSD/HD e memória** | TRIM, limpeza, ajustes por tipo de disco |
| 🕹️ **Jogos** | Detecta 110+ jogos (Steam, Epic, Riot...), prioridade alta e perfil NVIDIA por jogo competitivo |
| ⚠️ **Avançado (com risco)** | Integridade de memória, modo MSI, FSO, hypervisor. **Nunca entra no automático** |

A lista completa, com o que cada um faz, está em [`guias/LISTA_DE_AJUSTES.txt`](guias/LISTA_DE_AJUSTES.txt).

</details>

<br>

## ↩️ Desfazer sem medo

Precisa da impressora de volta? Quer gravar clipes no Xbox Game Bar? Recoloque **só aquilo**, sem desfazer o resto.

<div align="center">
<img src="docs/img/desfazer.gif" alt="Desfazer e recolocar funções" width="760">
</div>

<br>

## 📖 Guias que mostram onde clicar

Telas ilustradas no estilo de cada painel, com números indicando o caminho e a explicação de cada opção para quem nunca mexeu.

<table>
<tr>
<td width="50%"><img src="docs/img/painel_nvidia.png" alt="Guia do Painel NVIDIA"></td>
<td width="50%"><img src="docs/img/painel_amd.png" alt="Guia do AMD Adrenalin"></td>
</tr>
<tr>
<td align="center"><sub><b>Painel de Controle NVIDIA</b></sub></td>
<td align="center"><sub><b>AMD Adrenalin</b></sub></td>
</tr>
</table>

Também tem: **BIOS** (XMP/EXPO, Resizable BAR... com o nome em cada fabricante), **limite de FPS**, **processador AMD/Intel** e **configurações dentro dos jogos** (CS2, Valorant, Fortnite, Warzone, LoL, Free Fire e mais).

<br>

## 🚀 Como usar

```text
1. Baixe o .zip em Releases e EXTRAIA a pasta (não rode de dentro do zip)
2. Dê dois cliques em  AVANTIPACK.exe  (o ícone com a logo)
3. Escolha  [1] OTIMIZAR MEU PC  >  [1] Automático
4. Reinicie o PC no final
```

> [!TIP]
> Depois de uma atualização grande do Windows, o menu mostra uma faixa amarela. Use **Otimizar > Reaplicar** para refazer suas escolhas.

> [!NOTE]
> Se o Windows mostrar "O Windows protegeu o computador", clique em **Mais informações > Executar assim mesmo**. O pack é código aberto: dá para ler tudo neste repositório.

<br>

## 💻 Requisitos

| | |
|---|---|
| **Sistema** | Windows 10 (21H2+) ou Windows 11 |
| **Permissão** | Administrador |
| **Downloads automáticos** | winget 1.8+ (já vem no Windows 11) |

<br>

<details>
<summary><b>📁 Estrutura das pastas</b></summary>

```text
AVANTIPACK.exe     abre o pack (ícone com a logo)
LEIA-ME.txt        instruções
core\              motor do pack (menu .bat, PowerShell, versão e novidades)
guias\             BIOS, painéis ilustrados, jogos, limite de FPS
apps\              uma pasta por programa, cada uma com LEIA-ME.txt
ferramentas\       só no GitHub: launcher do .exe e GERAR_RELEASE
docs\              só no GitHub: imagens deste README
core\dados\        criada no uso: backups e dados do seu PC (não vai pro Git)
```

</details>

<details>
<summary><b>🔄 Como funciona a atualização automática</b></summary>

<br>

O pack consulta a última **Release** deste repositório (no máximo a cada 12 h). Se houver versão maior que a do `core/VERSION.txt`, aparece a faixa verde no menu. Ao apertar **U**, ele baixa, troca os arquivos e reabre. **Backups, logs e configuração são mantidos.**

Para quem publica: [`guias/GITHUB_PASSO_A_PASSO.txt`](guias/GITHUB_PASSO_A_PASSO.txt).

</details>

<br>

## ⚠️ Aviso

Otimizações de sistema e de BIOS são **por conta e risco de quem usa**: cada PC responde de um jeito. O AVANTIPACK cria ponto de restauração e permite desfazer cada ajuste, mas recomendamos ler as explicações antes de aplicar o que está marcado como risco.

## 📜 Créditos

- [NVIDIA Profile Inspector](https://github.com/Orbmu2k/nvidiaProfileInspector) (MIT), incluído no pack
- DDU, HWiNFO, CPU-Z e os demais programas **não são redistribuídos**: o pack baixa do site oficial de cada um

<div align="center">
<br>
<sub>Feito por <b>Avanti</b> 🎮 · projeto sem fins comerciais · se ajudou, deixe uma ⭐</sub>
</div>
