# AVANTIPACK

Otimização do Windows 10 e 11 para jogos, adaptada ao hardware de cada PC.

Menu simples no CMD, em português, feito para quem não entende de computador, sem tirar o controle de quem entende. Tudo o que o pack muda tem backup e pode ser desfeito.

⚠️ Projeto em desenvolvimento (v0.7). Otimizações de sistema e de BIOS são por conta e risco de quem usa: cada PC responde de um jeito.

✨ O que ele faz
Detecta as peças do PC (processador, placa de vídeo, RAM, disco e versão do Windows) e só aplica o que serve para aquela máquina.
Menos input lag e FPS mais estável, sem promessas milagrosas: só ajustes que têm efeito comprovado. Os placebos comuns em outros packs ficam de fora.
Backup de cada alteração: cria um ponto de restauração e guarda o valor original de cada ajuste antes de mudar qualquer coisa.
Atualização automática pelo GitHub: quando sai versão nova, o menu avisa.
📋 Menu
Opção	O que faz
[1] Otimizar meu PC	Automático (só o que é seguro), Personalizado (você marca por categoria) ou Reaplicar (refaz suas escolhas depois de uma atualização do Windows)
[2] Verificar meu PC	Mostra as peças e aponta problemas (RAM sem XMP, monitor em 60 Hz, driver antigo...), faz o teste de input lag com pontuação e testa a internet
[3] Consertar um problema	19 reparos: sem internet, sem som, microfone, Loja, Windows Update, Alt+Tab no 24H2...
[4] Programas úteis	16 programas com tutorial para AMD e Intel. Instala pelo winget ou abre o site oficial e move o download para a pasta certa sozinho
[5] Guias	Painéis NVIDIA/AMD/Intel ilustrados, BIOS por fabricante, limite de FPS e configurações dentro dos jogos
[6] Desfazer / recolocar	Desfaz tudo ou só uma função (impressora, clipes do Xbox...), reinstala apps removidos e religa funções do Windows
[7] Modo avançado	Cada módulo separado, com explicação antes de aplicar
[U] Atualizar	Aparece quando há versão nova
⚙️ Ajustes (45, em 9 categorias)
Limpeza (debloat): remove apps inúteis e telemetria, e desliga serviços e tarefas desnecessários
Sistema: Modo de Jogo, prioridade para o jogo, menos efeitos visuais, mouse sem aceleração
Energia: plano de alto desempenho conforme o processador e sem economia de energia nos dispositivos
Placa de vídeo:
NVIDIA: painel configurado pelo NVIDIA Profile Inspector e perfil por jogo competitivo (Reflex Ultra no driver, pré-renderização 1, clock máximo)
AMD: Anti-Lag ligado, Chill desligado, ULPS desligado
Monitor: colocado na maior taxa de atualização (Hz)
Internet: ajustes conservadores, teste e troca de DNS pelo mais rápido, diagnóstico de ping/jitter/perda (roteador × internet)
Armazenamento: TRIM, limpeza e ajustes para SSD/HD
Jogos: detecta mais de 110 jogos (Steam, Epic, Riot...) e dá prioridade alta a eles
Inicialização: escolha o que abre junto com o Windows
Avançado (com risco, nunca no automático): Integridade de memória, modo MSI, FSO e hypervisor, com aviso sobre anti-cheats (Vanguard/FACEIT)
🔁 Manutenção
Aviso após atualização do Windows: o menu avisa quando um update grande desfez ajustes. Um clique reaplica.
Manutenção semanal (opcional): limpeza leve e TRIM, todo domingo.
Aviso de driver de vídeo antigo.
💻 Requisitos
Windows 10 (21H2 ou mais novo) ou Windows 11
Executar como administrador
winget 1.8+ para baixar programas automaticamente (já vem no Windows 11)
🚀 Como usar
Baixe o .zip da versão mais recente em Releases.
Extraia a pasta (não rode de dentro do zip).
Clique com o botão direito em AVANTIPACK.bat > Executar como administrador.
Comece pela opção [1] Otimizar meu PC e reinicie no final.

Para voltar atrás: opção [6].

📁 Estrutura
AVANTIPACK.bat     menu principal
core\              motor do pack (PowerShell)
guias\             guias de BIOS, painéis (com imagens) e jogos
apps\              uma pasta por programa, cada uma com LEIA-ME.txt
ferramentas\       GERAR_RELEASE.bat (para publicar versões novas)
backup\ logs\ data\   criadas no uso; são do seu PC (não suba no Git)
❌ O que NÃO fazemos

Sem "ganho de 200 FPS com um regedit". Ficam de fora ajustes sem efeito comprovado ou que podem prejudicar o sistema: desligar o repouso da CPU, mexer em interrupt moderation às cegas, MouseDataQueueSize, timer global forçado e similares. Os detalhes estão em guias\O_QUE_NAO_FAZEMOS.txt.

📜 Créditos e licenças
NVIDIA Profile Inspector: licença MIT, incluído no pack
Os demais programas (DDU, HWiNFO, CPU-Z etc.) não são distribuídos aqui: o pack baixa do site oficial de cada um

Feito por Avanti 🎮 · Projeto sem fins comerciais
