# Deploy do fork (branch `kanban-nativo`)

Nada aqui altera o banco: **sem migrations e sem dependências novas**. É trocar a imagem do
Chatwoot e rodar dois scripts de configuração. Conversas e contatos continuam intactos.

## O que vai junto

| # | Recurso | Depende de |
|---|---------|------------|
| 2 | Kanban por gestor de conta (= responsável da conversa) | só a imagem |
| 6/7 | Painel de links e busca em arquivos compartilhados | só a imagem |
| 8 | Termômetro de tempo de resposta na lista de conversas | só a imagem |
| 10/11 | Motivo de fechamento + labels `integracao`/`gestao-cs` | script `2026-09-23_motivo_fechamento_e_labels.rb` |
| 3 | Editar mensagem enviada | Evolution Go ligado à caixa + item "ponte" abaixo |
| 4 | Enviar contato (vCard) | Evolution Go ligado à caixa |
| 5 | Criar/gerenciar grupos | Evolution Go ligado à caixa |
| 9 | Busca global com Grupos e Arquivos | só a imagem |
| 12 | Painel CS (Relatórios > Painel CS) | só a imagem (+ motivo de fechamento preenchido) |

## Passo a passo

O código de produção fica na branch `producao` do fork (Chatwoot 4.17.1 + nossas mudanças). A imagem é
construída pelo próprio GitHub (workflow `Build custom image`) e publicada no GHCR, então o Portainer
só precisa **puxar** `ghcr.io/devarantes-98/deskcomm-chatwoot:<tag>`.

**Publicar uma versão nova** (na `producao`, depois de mergear as mudanças):
```bash
git tag cs-4.17.1-2 && git push origin cs-4.17.1-2
```
Use tags que começam com `cs-` (tags `v...` disparam os workflows do Chatwoot oficial, que falham no fork).
Acompanhe em GitHub > Actions > "Build custom image"; leva de 15 a 30 minutos.

**Só na primeira vez:** o pacote nasce privado. Em GitHub > seu perfil > Packages > `deskcomm-chatwoot` >
Package settings > Change visibility > **Public** (a imagem não contém senhas; elas ficam no stack).
Se preferir manter privado, cadastre o registry `ghcr.io` no Portainer com um token do GitHub com
permissão `read:packages`.

1. **Backup** do Postgres antes de mexer (`pg_dump`), como você já faz.
2. **Trocar o stack no Portainer:** Stacks > (stack do Chatwoot) > Editor > cole o conteúdo do seu stack
   (`portainer-stack.example.yml` é o modelo sem senhas) > marque "Re-pull image" > Update the stack.
   A única diferença para o stack antigo é `image:` nos serviços `chatwoot_app` **e** `chatwoot_sidekiq`.
   O `rails db:prepare` do comando do app roda sozinho na subida (esta versão não tem migrations novas).
3. **Scripts de configuração** (idempotentes, sem downtime): siga o cabeçalho de cada um.
   - `2026-09-23_motivo_fechamento_e_labels.rb`
   - `2026-09-23_evolution_go_config.rb` (liga a caixa da Evolution Go: sem isso os itens 3, 4 e 5 não aparecem)

**Rollback:** no Portainer, volte `image:` para `chatwoot/chatwoot:v4.17.1` nos dois serviços e atualize.

## Ajustes na sua ponte (bridge)

- **ID da mensagem no WhatsApp (necessário para editar).** Depois de enviar uma mensagem digitada no
  Chatwoot, a ponte deve avisar o ID dela:
  `PATCH /api/v1/accounts/:account_id/conversations/:display_id/messages/:id` com
  `{ "source_id": "<id da mensagem no WhatsApp>" }` (pode ir junto com `"status": "delivered"`).
  Vale o ID puro (`3EB0...`) ou com prefixo `WAID:`. Sem isso o Chatwoot não sabe qual mensagem editar
  e a opção "Editar" simplesmente não aparece nessas mensagens.
- **Edição gera `message_updated`** no webhook da caixa (`content_attributes.edited = true`). A ponte
  deve ignorar esse evento (não reenviar).
- **Contato enviado pelo Chatwoot (#4)** já sai pelo Evolution Go. Para não duplicar nem marcar como
  "falhou", o Chatwoot **não** manda esses eventos ao webhook da caixa. Os webhooks de conta
  (ex.: apiv3) continuam recebendo, com `content_attributes.delivered_by = "evolution_go"`.

## Riscos conhecidos

- **Evolution Go 0.7.x, rota `/group/participant`:** no código dessa versão o middleware
  `ValidateJIDFields("number", "participants")` parece recusar `participants` em formato de lista, o que
  faria *adicionar/remover participante* responder 400. Criar grupo, listar e link de convite usam outros
  middlewares e não têm esse problema. **Teste adicionar/remover num grupo de teste**; se falhar, é
  bug da Evolution Go (atualizar a versão ou corrigir o middleware), não do Chatwoot.
- A edição só funciona até ~15 minutos depois do envio (regra do WhatsApp) e só para texto enviado
  pela própria instância.
- A Evolution Go é chamada direto do Chatwoot: a URL configurada precisa ser alcançável **de dentro** do
  container do Chatwoot.

## Conferência rápida depois do deploy

1. Kanban carrega e agrupa por responsável.
2. Lista de conversas mostra o termômetro em conversa aguardando resposta.
3. Relatórios > Painel CS abre (só administrador).
4. Depois de ligar a caixa: botão de contato na caixa de resposta, "Criar grupo do WhatsApp" no menu
   ⋮ de Contatos, painel "Grupo do WhatsApp" em conversa de grupo, "Editar" no menu de uma mensagem recente.
