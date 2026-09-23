# Bridges store the WhatsApp message id of outgoing messages as `source_id`, some with a "WAID:" prefix
# (the convention of Evolution API's Chatwoot integration) and some without.
module EvolutionGo::WhatsappId
  PREFIX = 'WAID:'.freeze

  def self.to_source_id(whatsapp_id)
    "#{PREFIX}#{whatsapp_id}"
  end

  def self.from_source_id(source_id)
    source_id.to_s.delete_prefix(PREFIX)
  end
end
