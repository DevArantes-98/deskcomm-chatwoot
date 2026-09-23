# frozen_string_literal: true
#
# Links an API inbox to its Evolution Go instance, which turns on (for that inbox only):
#   - editing sent messages        (#3)
#   - sending contact cards        (#4)
#   - creating/managing WhatsApp groups (#5)
#
# The url/token are stored on the inbox channel (additional_attributes.evolution_go).
# The token is the INSTANCE token (the same value the bridge sends in the `apikey` header).
# It is never returned by the inbox API, only `evolution_go_enabled: true` is.
#
# Safe to re-run: it just overwrites the link. To REMOVE the link, run with REMOVE=1.
#
# HOW TO RUN ON PRODUCTION (after the new image is deployed)
# -------------------------------------------------------------------------
# 1) Copy this file to the VPS:
#      scp -P 61785 scripts/production/2026-09-23_evolution_go_config.rb root@177.39.20.182:/root/
#
# 2) Copy it into the running Chatwoot app container and list the API inboxes first:
#      CONTAINER=$(docker ps --filter "name=chatwoot_app_chatwoot_app" --format "{{.Names}}" | head -1)
#      docker cp /root/2026-09-23_evolution_go_config.rb "$CONTAINER":/tmp/
#      docker exec -it "$CONTAINER" bundle exec rails runner /tmp/2026-09-23_evolution_go_config.rb
#
# 3) Then link one inbox (url = address of Evolution Go as seen FROM the Chatwoot container):
#      docker exec -it \
#        -e INBOX_NAME="Nome exato da caixa" \
#        -e EVOLUTION_GO_URL="http://10.10.100.5:4000" \
#        -e EVOLUTION_GO_TOKEN="token-da-instancia" \
#        -e CHECK=1 \
#        "$CONTAINER" bundle exec rails runner /tmp/2026-09-23_evolution_go_config.rb
#
#    CHECK=1 makes one read-only call (GET /group/list) to confirm url + token work.
#
# If you have more than one account on this installation, change `Account.first`
# below to `Account.find(ID)` for the right one.

require 'net/http'
require 'uri'

account = Account.first
raise 'No account found - check Account.first / Account.find(ID)' unless account

api_inboxes = account.inboxes.select { |inbox| inbox.channel.is_a?(Channel::Api) }

name = ENV.fetch('INBOX_NAME', nil)
if name.blank?
  puts '== API inboxes (set INBOX_NAME to pick one) =='
  api_inboxes.each do |inbox|
    linked = inbox.channel.evolution_go_config.present? ? 'LINKED' : 'not linked'
    puts "- #{inbox.name}  [#{linked}]  webhook: #{inbox.channel.webhook_url}"
  end
  exit
end

inbox = api_inboxes.find { |candidate| candidate.name == name }
raise "API inbox not found: #{name.inspect}" unless inbox

channel = inbox.channel

if ENV['REMOVE'] == '1'
  channel.update!(additional_attributes: { 'evolution_go' => nil })
  puts "OK: Evolution Go link removed from #{inbox.name}"
  exit
end

url = ENV.fetch('EVOLUTION_GO_URL', '').strip.chomp('/')
token = ENV.fetch('EVOLUTION_GO_TOKEN', '').strip
raise 'Set EVOLUTION_GO_URL and EVOLUTION_GO_TOKEN' if url.blank? || token.blank?

if ENV['CHECK'] == '1'
  uri = URI("#{url}/group/list")
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 15) do |http|
    http.request(Net::HTTP::Get.new(uri, 'apikey' => token))
  end
  raise "Evolution Go answered #{response.code} - check url/token before saving" unless response.is_a?(Net::HTTPSuccess)

  puts "OK: Evolution Go reachable (#{response.code})"
end

channel.update!(additional_attributes: channel.additional_attributes.to_h.merge('evolution_go' => { 'url' => url, 'token' => token }))
puts "OK: #{inbox.name} linked to #{url} (evolution_go_enabled=#{channel.reload.evolution_go_config.present?})"
puts "\nDone."
