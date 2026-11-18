# Regras do projeto AVANTIPACK (para o Claude)

O dono do projeto (pedromargutti) pediu: **toda mudança feita no pack em uma conversa deve ser enviada e publicada com as novidades atualizadas**, sem ele precisar pedir.

## A cada atualização do pack
1. **Versão:** aumente o último número em `core/VERSION.txt` (ex.: 0.7.3 -> 0.7.4). Mudanças grandes aumentam o do meio.
2. **core/NOVIDADES.md:** adicione no topo `## vX.Y.Z — DD/MM/AAAA` com a lista do que mudou, em português simples e com um emoji por linha (`- 🎮 **Destaque** explicação`).
3. **README.md:** na seção "🆕 Novidades", coloque a versão nova em `<details open>` e tire o `open` da anterior. Deixe só as 2 ou 3 mais recentes no README; o histórico completo fica no core/NOVIDADES.md.
4. **Validação:** os `.ps1` precisam ser só ASCII e todos os `.bat`/`.ps1`/`.txt` com CRLF; rode o parser do PowerShell em todos os `.ps1` antes de enviar.
5. **Envio:** commit e push na `main` deste repositório.
6. **Zip:** gere `AVANTIPACK_vX.Y.Z.zip` com `git archive --prefix=AVANTIPACK/` e mande para o usuário.
7. **Release:** esta sessão não consegue criar Releases no GitHub. Mande ao usuário o link `https://github.com/pedromargutti/AVANTIPACK/releases/new`, a tag `vX.Y.Z` e o texto da descrição pronto para colar (o mesmo do core/NOVIDADES.md).

## Cuidados
- Nunca enviar `core/dados/` nem `core/AVANTIPACK.lnk` (são do PC de cada pessoa).
- **Pasta principal limpa:** no pack só ficam `AVANTIPACK.exe`, `LEIA-ME.txt`, `apps/`, `core/` e `guias/`. Arquivos só do GitHub (README, docs, ferramentas, CLAUDE.md) têm `export-ignore` no `.gitattributes`.
- O `AVANTIPACK.exe` é compilado de `ferramentas/launcher/` (veja COMO_COMPILAR.txt); ao mudar a versão, atualize também `res.rc` e recompile.
- `core/config.txt` deve manter `GITHUB_REPO=pedromargutti/AVANTIPACK`.
- Não incluir programas que proíbem redistribuição (DDU, HWiNFO, Process Lasso, Autoruns). O NVIDIA Profile Inspector (MIT) pode ir.
- Mudanças que só mexem neste arquivo ou em coisas fora do pack não precisam de versão nova.
