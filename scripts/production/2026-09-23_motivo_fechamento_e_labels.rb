# frozen_string_literal: true
#
# Config-only changes, no code deploy needed. Safe to re-run (idempotent):
# updates existing records instead of erroring if you run it twice.
#
#   1) Conversation custom attributes for closing reason (item #10)
#   2) The two allowed labels for tag-based filtering (item #11)
#
# HOW TO RUN ON PRODUCTION
# -------------------------------------------------------------------------
# 1) Copy this file to the VPS, e.g.:
#      scp -P 61785 scripts/production/2026-09-23_motivo_fechamento_e_labels.rb \
#        root@177.39.20.182:/root/
#
# 2) Find the running Chatwoot app container (Swarm task):
#      docker ps --filter "name=chatwoot_app_chatwoot_app" --format "{{.Names}}"
#
# 3) Copy the script into that container and run it:
#      CONTAINER=$(docker ps --filter "name=chatwoot_app_chatwoot_app" --format "{{.Names}}" | head -1)
#      docker cp /root/2026-09-23_motivo_fechamento_e_labels.rb "$CONTAINER":/tmp/
#      docker exec -it "$CONTAINER" bundle exec rails runner /tmp/2026-09-23_motivo_fechamento_e_labels.rb
#
# If you have more than one account on this installation, change
# `Account.first` below to `Account.find(ID)` for the right one.
# -------------------------------------------------------------------------

account = Account.first
raise "No account found - check Account.first / Account.find(ID)" unless account

puts "== Account =="
puts "id=#{account.id} name=#{account.name}"

puts "\n== #10: Motivo do Fechamento (conversation custom attributes) =="

motivo = CustomAttributeDefinition.find_or_initialize_by(
  attribute_key: 'motivo_fechamento',
  attribute_model: :conversation_attribute,
  account_id: account.id
)
motivo.attribute_display_name = 'Motivo do Fechamento'
motivo.attribute_display_type = :list
motivo.attribute_values = [
  'Ativar/desativar cadência',
  'Integração',
  'Financeiro/plano',
  'Problemas técnicos',
  'Marcar reunião',
  'Cancelamento',
  'Dúvidas sobre a ferramenta',
  'Outros'
]
motivo.save!
puts "OK: #{motivo.attribute_display_name} (id=#{motivo.id})"

detalhe = CustomAttributeDefinition.find_or_initialize_by(
  attribute_key: 'motivo_detalhe',
  attribute_model: :conversation_attribute,
  account_id: account.id
)
detalhe.attribute_display_name = 'Detalhe do Motivo'
detalhe.attribute_display_type = :text
detalhe.attribute_description = "Preencha ao escolher 'Dúvidas sobre a ferramenta' ou 'Outros'"
detalhe.save!
puts "OK: #{detalhe.attribute_display_name} (id=#{detalhe.id})"

puts "\n== #11: Labels restritas (Integração / Gestão CS) =="
puts "Nota: título de label não aceita espaço/maiúscula (o Chatwoot já força" \
     " minúsculas e barra espaços); por isso 'gestao-cs' em vez de 'Gestão CS'." \
     " Criar labels já exige administrador no Chatwoot (LabelPolicy#create?)," \
     " então agentes/gestores comuns não conseguem criar novas por conta própria."

[
  { title: 'integracao', description: 'Clientes com dúvidas ou pendências de integração', color: '#1f93ff' },
  { title: 'gestao-cs',  description: 'Clientes em gestão de CS (upsell, churn, inadimplência)', color: '#8b46ff' }
].each do |attrs|
  label = account.labels.find_or_initialize_by(title: attrs[:title])
  label.description = attrs[:description]
  label.color = attrs[:color]
  label.save!
  puts "OK: #{label.title} (id=#{label.id})"
end

puts "\nDone."
