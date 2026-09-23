# Bridges store the WhatsApp message id of outgoing messages as `source_id` with a "WAID:" prefix.
module EvolutionGo::WhatsappId
  PREFIX = 'WAID:'.freeze

  def self.to_source_id(whatsapp_id)
    "#{PREFIX}#{whatsapp_id}"
  end

  def self.from_source_id(source_id)
    source_id.to_s.delete_prefix(PREFIX)
  end

  def self.source_id?(source_id)
    source_id.to_s.start_with?(PREFIX)
  end
end
