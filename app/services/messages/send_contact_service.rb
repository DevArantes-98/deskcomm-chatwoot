# Shares a Chatwoot contact (as a WhatsApp vCard) inside a conversation.
#
# The vCard is sent through Evolution Go first; the Chatwoot message is only recorded once WhatsApp
# accepted it. It is stored as a `contact` attachment - the same shape received vCards have - so the
# existing contact bubble renders it.
class Messages::SendContactService
  pattr_initialize [:conversation!, :contact!, :user!]

  def perform
    ensure_sendable!
    whatsapp_id = push_to_whatsapp
    record_message(whatsapp_id)
  end

  private

  def ensure_sendable!
    raise EvolutionGo::Refused, :inbox_not_supported unless evolution_go_config
    raise EvolutionGo::Refused, :no_chat_jid if chat_jid.blank?
    raise EvolutionGo::Refused, :contact_without_phone if phone.blank?
  end

  def evolution_go_config
    channel = conversation.inbox.channel
    channel.evolution_go_config if channel.is_a?(Channel::Api)
  end

  def chat_jid
    @chat_jid ||= EvolutionGo::ChatJid.for(conversation.contact)
  end

  def phone
    @phone ||= contact.phone_number.to_s.delete('^0-9').presence || phone_from_identifier
  end

  def phone_from_identifier
    identifier = contact.identifier.to_s
    identifier.delete_suffix('@s.whatsapp.net').delete('^0-9') if identifier.end_with?('@s.whatsapp.net')
  end

  def push_to_whatsapp
    config = evolution_go_config
    EvolutionGo::Client.new(url: config['url'], token: config['token']).send_contact(
      number: chat_jid,
      full_name: contact.name,
      phone: phone,
      organization: contact.additional_attributes.to_h['company_name']
    )
  end

  def record_message(whatsapp_id)
    message = conversation.messages.new(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      sender: user,
      content_attributes: { delivered_by: 'evolution_go' },
      source_id: whatsapp_id.present? ? EvolutionGo::WhatsappId.to_source_id(whatsapp_id) : nil
    )
    message.attachments.new(
      account_id: conversation.account_id,
      file_type: :contact,
      fallback_title: phone,
      meta: { firstName: contact.name, lastName: '' }
    )
    message.save!
    message
  end
end
