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

1. **Backup** do Postgres antes de mexer (`pg_dump`), como você já faz.
2. **Build da imagem** a partir do fork (na VPS ou onde você tiver registry):
   ```bash
   git clone -b kanban-nativo https://github.com/DevArantes-98/deskcomm-chatwoot.git
   cd deskcomm-chatwoot
   docker build -f docker/Dockerfile -t chatwoot-custom:kanban-nativo .
   ```
3. **Trocar a imagem** dos serviços `rails` e `sidekiq` no stack (Portainer > Stack > editar > `image:`)
   e atualizar. Rollback = voltar a tag anterior.
4. **Scripts de configuração** (idempotentes, sem downtime): siga o cabeçalho de cada um.
   - `2026-09-23_motivo_fechamento_e_labels.rb`
   - `2026-09-23_evolution_go_config.rb` (liga a caixa da Evolution Go: sem isso os itens 3, 4 e 5 não aparecem)

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
