# Edits the text of an outgoing WhatsApp message, both in Chatwoot and on WhatsApp itself.
#
# Editing only in Chatwoot would leave the customer seeing something different from the agent,
# so this is deliberately limited to inboxes linked to an Evolution Go instance
# (Channel::Api#evolution_go_config) and WhatsApp is updated *first*: if it refuses, nothing changes here.
class Messages::EditService
  EDIT_WINDOW = 15.minutes # WhatsApp only allows editing shortly after sending
  WHATSAPP_ID_PREFIX = 'WAID:'.freeze

  class NotEditable < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(reason.to_s)
    end
  end

  pattr_initialize [:message!, :content!, :user!]

  def perform
    message.with_lock do
      ensure_editable!
      push_to_whatsapp
      save_locally
    end
    message
  end

  private

  def ensure_editable!
    reason = not_editable_reason
    raise NotEditable, reason if reason
  end

  def not_editable_reason
    message_state_reason || permission_reason || content_reason
  end

  def message_state_reason
    return :not_outgoing unless message.outgoing?
    return :private_note if message.private?
    return :not_text unless message.text? && message.attachments.blank?

    :deleted if message.content_attributes.to_h['deleted']
  end

  def permission_reason
    return :forbidden unless message.sender == user || Current.account_user&.administrator?
    return :inbox_not_supported unless evolution_go_config

    :no_source_id unless message.source_id.to_s.start_with?(WHATSAPP_ID_PREFIX)
  end

  def content_reason
    return :window_expired if Time.current - message.created_at > EDIT_WINDOW
    return :blank_content if new_content.blank?
    return :unchanged if new_content == message.content

    :no_chat_jid if chat_jid.blank?
  end

  def new_content
    @new_content ||= content.to_s.strip
  end

  def evolution_go_config
    channel = message.inbox.channel
    channel.evolution_go_config if channel.is_a?(Channel::Api)
  end

  def chat_jid
    @chat_jid ||= EvolutionGo::ChatJid.for(message.conversation.contact)
  end

  def push_to_whatsapp
    config = evolution_go_config
    EvolutionGo::Client.new(url: config['url'], token: config['token']).edit_message(
      chat: chat_jid,
      message_id: message.source_id.delete_prefix(WHATSAPP_ID_PREFIX),
      text: new_content
    )
  end

  def save_locally
    attributes = message.content_attributes.to_h
    message.update!(
      content: new_content,
      content_attributes: attributes.merge(
        'edited' => true,
        'edited_at' => Time.current.to_i,
        'original_content' => attributes['original_content'] || message.content
      )
    )
  end
end
