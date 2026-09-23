# Resolves the WhatsApp JID Evolution Go expects for a Chatwoot contact:
# groups and contacts imported by a bridge carry it in `identifier`
# (e.g. 1203630...@g.us), everyone else falls back to their phone number.
class EvolutionGo::ChatJid
  def self.for(contact)
    return contact.identifier if contact.identifier.to_s.include?('@')

    digits = contact.phone_number.to_s.delete('^0-9')
    "#{digits}@s.whatsapp.net" if digits.present?
  end
end
