# WhatsApp group operations for an inbox linked to Evolution Go (Channel::Api#evolution_go_config).
#
# Evolution Go returns whatsmeow structs serialised as-is (capitalised keys), so everything that
# comes back is normalised here and the rest of Chatwoot only sees plain lowercase hashes.
class EvolutionGo::Groups
  GROUP_SUFFIX = '@g.us'.freeze
  INDIVIDUAL_SUFFIX = '@s.whatsapp.net'.freeze

  pattr_initialize [:inbox!]

  def self.group_jid?(jid)
    jid.to_s.end_with?(GROUP_SUFFIX)
  end

  def self.phones_of(contacts)
    contacts.filter_map { |contact| contact.phone_number.to_s.delete('^0-9').presence }
  end

  def info(group_jid)
    ensure_group!(group_jid)
    normalise_info(client.group_info(group_jid: group_jid))
  end

  def create(name:, phones:)
    raise EvolutionGo::Refused, :blank_name if name.to_s.strip.blank?
    raise EvolutionGo::Refused, :no_participants if phones.blank?

    created = client.create_group(name: name.to_s.strip, participants: phones)
    { jid: created['jid'].to_s, name: created['name'].presence || name.to_s.strip, failed: Array(created['failed']) }
  end

  def add_participants(group_jid, phones)
    update_participants(group_jid, phones, 'add')
  end

  def remove_participants(group_jid, participants)
    update_participants(group_jid, participants, 'remove')
  end

  def invite_link(group_jid)
    ensure_group!(group_jid)
    code = client.group_invite_link(group_jid: group_jid).to_s
    code.start_with?('http') ? code : "https://chat.whatsapp.com/#{code}"
  end

  private

  def update_participants(group_jid, participants, action)
    ensure_group!(group_jid)
    raise EvolutionGo::Refused, :no_participants if participants.blank?

    client.update_group_participants(group_jid: group_jid, participants: participants, action: action)
  end

  def ensure_group!(group_jid)
    raise EvolutionGo::Refused, :not_a_group unless self.class.group_jid?(group_jid)
  end

  def client
    @client ||= begin
      channel = inbox.channel
      config = channel.evolution_go_config if channel.is_a?(Channel::Api)
      raise EvolutionGo::Refused, :inbox_not_supported unless config

      EvolutionGo::Client.new(url: config['url'], token: config['token'])
    end
  end

  def normalise_info(raw)
    raw = {} unless raw.is_a?(Hash)
    {
      jid: raw['JID'].to_s,
      name: raw.dig('GroupName', 'Name').to_s,
      description: raw.dig('GroupTopic', 'Topic').to_s,
      participants: match_contacts(Array(raw['Participants']).map { |participant| normalise_participant(participant) })
    }
  end

  # Newer WhatsApp versions identify members by a "LID" and expose the phone number separately.
  def normalise_participant(participant)
    jid = participant['JID'].to_s
    phone_jid = [participant['PhoneNumber'].to_s, jid].find { |candidate| candidate.end_with?(INDIVIDUAL_SUFFIX) }
    {
      jid: jid,
      phone: phone_jid.to_s.split('@').first.to_s.split(/[:.]/).first.to_s.delete('^0-9').presence,
      admin: participant['IsAdmin'] == true || participant['IsSuperAdmin'] == true,
      display_name: participant['DisplayName'].to_s.presence
    }
  end

  def match_contacts(participants)
    phones = participants.filter_map { |participant| participant[:phone] }
    matches = inbox.account.contacts.where(phone_number: phones.map { |phone| "+#{phone}" })
    contacts = matches.index_by { |contact| contact.phone_number.delete('^0-9') }
    participants.map do |participant|
      contact = contacts[participant[:phone]]
      participant.merge(contact_id: contact&.id, name: contact&.name || participant[:display_name])
    end
  end
end
